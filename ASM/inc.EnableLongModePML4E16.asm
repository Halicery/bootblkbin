; ******************************************************************************************************
;   Include file for 64-bit kick in. What's left is set PG and PE in CR0.
; 
;   64-bit mode requires PAE=1 with new paging: PML4E 
;
;   Here we set up the simplest possible paging using 2MB page entries to map 4GB linear memory:
;   
;   - 4 x 4K PS=1 2MB page entries at 0x1000-0x4FFF
;   - 4 entries at 0x5000 for each GB
;   - one PML4E entry at 0x6000
;   - all PAE entries are 64-bit, 8-bytes
;
; https://github.com/Halicery/Bootblkbin

; 47.....39              38..30                     29..21          20..0
; (9 bit)                (9 bit)                    (9 bit)         (21 bit)   
;                                                   
; <-------------------><----------------------><------------------><----------->
; 
;  1 x                    4 x                       4 x 512          2M OFFS
;  8-byte entry           8-byte entry              8-byte entry
;
;   0x6000                0x5000                     0x1000-0x4FFF
;
; +-----------+          +-----------+    0x1000    +-----------+
; |  PML4E    |  ----->  |    1GB    |   -------->  |    2MB    |          
; +-----------+          +-----------+              +-----------+
; |    ^      |          |    1GB    |  ---+        |    2MB    |
;      |                 +-----------+     |        +-----------+
;     CR3                |    1GB    |     |        |    ...    |
;                        +-----------+     |       
;                        |    1GB    |     +--->    +-----------+
;                        +-----------+     0x2000   |    2MB    |
;                        |           |              +-----------+
;                                                   |    ...    |
;
;   Page-Map             Page-Directory              Page     
;   Level-4              Pointer                     Directory
;   Table                Table                       Table    
;   4K-aligned           4K-aligned                  4K-aligned       

[BITS 16]

MakePML4E16:
    ; Try to do this with the most compact code possible. Every byte matters in bootblock. 
    ;
    ; There are two auto-inc/dec thing in 8086: stos and push. 
    ; Here we use push with its auto-decrement. So tables are filled from top to bottom.
    ; PUSH can sign-extend bytes so code is more compact (we write many zeroes, now from DX instead) 
    ; PUSH reg is one-byte opcode, make this code compact
    ; SS=0 from prologue
    
    ; Set only one PML4E and set CR3 point here: 0x6000
    MOV AX, 0x5000 | 1    ; address 4K, present 
    CWD                   ; DX=0
    MOV SP, 0x6000 + 8    ; write 1 entry
    PUSH DX               ; HI
    PUSH DX               ; HI
    PUSH DX               ; HI
    PUSH AX               ; write LO to 0x6000 
    MOV CR3, ESP          ; 6th page. ESP HI=0 from prologue
    
    ; AX: sub 4K.. Fill only 4 PDP 64-bit entries, linear mapping of whole 4GB
    ; right after PDTABLE, that will be 0x5000
    ; Divides 4G into 4 x 1GB spaces
    MOV SP, 0x5000 + 4 * 8   ; 0x5000 + 4 entry
    MOV CX, 4     
    .5: PUSH DX
    PUSH DX
    PUSH DX
    SUB  AX, 4096       ; sub 4K, next PDE page (4001.. 3001.. 2001.. 1001)
    PUSH AX      
    LOOP .5       
    
    ; Fill 4 x 4K PD with 4x512 64-bit entries, linear mapping of whole 4GB
    XOR AX, AX
    MOV CH, 8           ; save one byte. CX = 4*512 = 0800h
    .4: PUSH DX       
    PUSH DX           
    SUB  AX, 0x20       ; sub 2MB (AX=HI)
    PUSH AX           
    PUSH 1<<7 | 1       ; LO: set PS-bit (2MB page size), present. PAE: Writable is ignored in CPL=0 and CR0.WP=0  
    LOOP .4      
    
    ; Enable PAE
    MOV EAX, CR4  
    OR AL, 1<<5         ; set PAE-bit (PSE is ignored by PAE paging)
    MOV CR4, EAX     
    
    ; Enable Long Mode 
    ; RDMSR: reg specified in the ECX register -> into registers EDX:EAX
    MOV ECX, 0xC0000080 ; EFER reg
    RDMSR   
    INC AH              ; save one byte for OR AX, 1<<8       ; Set LME Long Mode Enable: bit 8  
    WRMSR               ; my VBox 6.1 sometimes die here(?)
    
    ;MOV SP, $$         ; or just leave it at 0x1000 (4K) No IVT here.  
