;nasm bootblkbin_cores32_apic.asm -fbin -obin.vfd -lbootblkbin.l

; Wake up cores, AP-s
; Switch APs to 32-bit, PE=1, LIDT and test the APIC Timer interrupt on each core. 
;
; Every core prints APIC Timer count on interrupt: we can see the latency changing..
; Every core prints its stack pointer: we can see the random wake-up order..
;
; We are tight in 512 bytes so with some ugly addressing
;
;
; https://github.com/Halicery/Bootblkbin


; My NUC (GenuineIntel 000406E3) i3 - 4 cores OK
; My Samsung NC10 Intel Atom (000106C2) OK - 2 cores 
; My Lenovo E130 (GenuineIntel 000306A9) i3 - 4 cores OK
; My Latitude E4200 2 cores OK (GenuineIntel 0001067A)
; My Haswell 8 cores OK (GenuineIntel 000306C3)
; Hy, VBox* on AMD Ryzen (00810F10) ok
;
;   *Vbox 6.1 NOTE
;   Got the turtle, Hyper-V is also installed so my VirtualBox runs in nested virtualization.
;   Multi-core tests are unstable, LOCK prefix, random Guru and crash happens. 
;   ; VBox NOT OK!!! TRiple fault, eip=00000003 ????
;   Maybe without Hyper-V it works perfect. 


APSTARTADDR equ 0x1000    ; any 4K addr below 1M as 000VV000H --> CS=VV00 IP=0 (Hy). We need scalar value not symbol. We use <64K now

%include "inc.prologue.asm"  

  
[BITS 16]
  ; mask 8259 master PIC in case
  MOV AL, 0xFF     ; OCW1 MASTER: mask all 
  OUT 0x21, AL  
  
  ; Write far jmp 5 bytes   EA[1601]0000 
  MOV BYTE [APSTARTADDR], 0xEA
  MOV DWORD [APSTARTADDR + 1], AP16  ; CS=0
  
  ; kick in 32-bit mode (called by APs too, make sure different stacks set up)
  ; make sure DS=0
    
Kick32:
  LIDT [IDTLOAD]     ; load in RM to save code bytes

  LGDT [GDTABLELOAD] ; 16-bit LGDT: GDTR upper 8-bits zeroed (here it works, we are below 16M)
  SMSW AX            ; set PE=1
  INC  AX
  LMSW AX
  PUSH GD_DATA32     ; set DS/ES data- and stack segment SS to 4GB linear
  POP  DS            ; one-byte opcodes
  PUSH DS
  POP  ES
  PUSH DS
  POP  SS
  JMP  GD_CODE32:BSP32   ; param to call Kick32 by APs
  FARP32 EQU $ - 4       ; modifying code, nasty, but save codebytes
    
GDTABLE EQU $ - 8
  GD_CODE32  EQU $-GDTABLE
  dq 0x00CF9A000000FFFF 
  GD_DATA32  EQU $-GDTABLE
  dq 0x00CF92000000FFFF
    
GDTABLELOAD EQU $-2                
  ; *** USE PREVIOUS WORD 0x00CF FOR LIMIT *** save 2 bytes    >>> Only in bootblk <<<
  dw GDTABLE    ; 24-bit linear address of GD TABLE
  db 0          ; <64K
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  BSP 32-bit code
;
;  Wakes up APs
;  Prints APICID
;  Start APIC Timer interrupt
;  Prints APIC Timer
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[BITS 32]
BSP32:
  
  ; PREPARE far jmp for AP Kick32
  mov word [word FARP32], AP32      ; 67h save one byte <64K

  mov byte [0xb8002], '1'           ; core count = 1
  
  mov ebp, 0xb8000 + 3*160          ; start row
  call get_apic_id                  ; -> EAX is 8-bit APICID
  call printApicID
  
  call get_lapic_base               ; eax = lapic_base
  
  ; Software Enable Local APIC bit8 in Spurious-Interrupt Vector Register (SVR) 
  ; Some BIOS defaults to 000000FF <-- as all AP on Hy, NUC (Hy still works! NUC: SHOULD BE ENABLED)
  mov al, 0xF0
  or dword [eax], 1<<8
   
  ; Wake up AP-s: write ICR Register 0x300
  mov ax, 0x300
  mov dword [eax], TGM_LEVEL_ASSERT | DSH_AllexcludingSelf | MT_INIT      ; INIT: Hy needs level (assert or deassert both works). VBox, NUC: no need, edge
  mov dword [eax], DSH_AllexcludingSelf | MT_STARTUP | (APSTARTADDR>>12)  ; STARTUP  ....VV (addr 000VV000H 1MB) 
  
  ; ---- Here all APs start executing concurrently ----
  ;
  ;hlt  
  
  
  
  ; AP-s jump here too
  ; eax: 0xFEE0xxxx or lapic_base HI 
  ; ebp: start row 
  loopApicTimer:  

  ; start Apic Timer
  mov ax, 0x320                                    ; save codebytes
  mov dword [ eax ], TMD_Periodic | VectorNumber   ; Timer LVT
  mov al, 0xe0
  mov dword [ eax ], TIMER_DIV2                    ; div=128 slowest
  mov al, 0x80
  mov dword [ eax ], 10000 * 8 ;* 1000             ; write some initial value 
   
  ;mov dword [ eax + 0x320 ], TMD_Periodic | VectorNumber     ; Timer LVT
  ;mov dword [ eax + 0x3e0 ], TIMER_DIV128                    ; div=128 slowest
  ;mov dword [ eax + 0x380 ], 10000 * 8 ;* 1000                ; write initial value  

  ; Enable interrupts and loop.. Keep eax = 0xFEE0xxxx or lapic_base HI

  sti
  .loop: hlt
    
    ; print Apic Timer: we can also see the latency changing..
    ; ebp: screen row address
    ; eax: 0xFEE0xxxx
    ;call get_lapic_base
    ;mov eax, 0xFEE00000
    push 4
    pop ecx                      ; 4 bytes (get_lapic_base loaded 0x1b into ecx, CL)
    lea edi, [ebp + 13*2]        ; row memory address + 13 columns
    mov ax, 0x390                ; APIC Timer Current Count 
    push dword [eax]             ; APIC Timer Current Count (32-bit read ok)
    mov esi, esp                 ; data
    call outhex32
    pop ebx                      ; keep eax
    
    jmp .loop

    
; common with AP-s

APICTimerHandler:
  ; Interrupt handler: write zero to APIC EOI and iret 
  
  ; or use default address:
  ;push 0                    ; VBox OK
  ;pop dword [0xFEE000B0]
  
  ;call get_lapic_base      ; eax = lapic_base
  ; eax: 0xFEE0xxxx or lapic_base HI 
  mov ax, 0xB0
  push 0
  pop dword [eax]
  iret
  
  
printApicID:   
  ; eax: apicid
  ; ebp: screen row address
  push 1
  pop ecx            ; one byte
  push eax
  mov esi, esp       
  mov edi, ebp       ; row memory address
  call outhex32
  pop eax
  ret
 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; 16-bit AP boot code
;
;   jmp 0:AP16  <-- comes back here
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; Now this is a really fresh cpu start!
  ; All seg cache has default values similar to RESET. 
  ; 
  ; At 1M Physical address VV000 
  ; We rely on zero SREGS:
  ; Hy:
  ; CS=VV00 -> IP=0
  ; SS=0
  ; DS=0
  ; sp=0 (probably esp=0)
  ; flags= 0002
  ;
  ; The challenge is that every core start executing concurrently

  ;APJMP: jmp 0:AP16  ; EA[1601]0000  --> copy to VV000 to jump back here

align 2
APSP:  DW 0x7000    ; mini 512 byte stacks for AP-s: from 7000, 6e00, 6d00.. downward
  
[BITS 16]
AP16: 
    ; set up different stack for each AP 
    MOV  SP, -0x200         ; 512 mini stacks  ; amount to add
    LOCK XADD [APSP], SP    ; atomically add, return previous value
  
    ; increase core count on screen
    PUSH 0xB800
    POP  ES
    LOCK ES INC BYTE [2]  ; core count (<-- why is this on VBox unstable? Only. 3 or 4.. write order? lock prefix should work, LOCK XADD [APSP], SP is correct??)
    
    JMP Kick32

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   
; 32-bit AP code continue
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[BITS 32]
AP32: 
  
  ; for each AP we write stuff at different row. 
  ; this comes from APICID (01, 02 ... normally)
  
  call get_apic_id      ; -> EAX is 8-bit APICID
  
  ; compute row number from apicid
  ; store screen row memory address --> ebp
  mov ebp, eax
  imul bp, 160
  add ebp, 0xb8000 + 5*160   ; start row        
  
  ; print apic_id (eax)
  call printApicID
  
  ; print my stack pointer
  mov cl, 4             ; 4 byte
  lea edi, [ebp + 3*2]  ; row memory address + 3 columns
  push esp
  mov esi, esp          ; data
  call outhex32
  ;pop eax

  call get_lapic_base      ; eax = lapic_base
  
  mov al, 0xF0
  or  dword [ eax ], 0x100   ; APIC Software Enable/Disable bit8. Spurious-Interrupt Vector Register (SVR) 000000FF <-- all AP on Hy, NUC (Hy still works! NUC: SHOULD BE ENABLED)

  jmp loopApicTimer
    


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; IDT: Set up one handler for APICTimer
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  VectorNumber equ 51          ; chose one

  IDTABLE:                   ; 8-byte structures
    dw APICTimerHandler      ; Target Offset[15:0]  <-- this works assembly-time
    dw GD_CODE32             ; Target Selector
    db 0x00                  ; Reserved
    db 0x8E                  ; P DPL S=0 | Type 
    dw 0                     ; Target Offset[31:16] <-- we are <64K
    ;dw (APICTimerHandler - $$ + 0x7c00) >> 16        ; Target Offset[31:16] <-- NB: must be scalar for assembly-time
  
  IDTLOAD: 
    dw -1                          ; max limit
    dd IDTABLE - 8 * VectorNumber  ; shoot N x 8 bytes below


    
%include "inc.apic32.asm" 
  
%include "inc.outhex.asm"

ASMFILENAME: db __FILE__, 0 

times (510 + $$-$) db 0
db 0x55, 0xAA                     ; No need for Hy or VB 

  times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
  ; 1.44M  80*2*18*512
  ; 1.2M   80*2*15*512
  ; 720K   40*2*18*512
  ; 360K   40*2*9*512
  
