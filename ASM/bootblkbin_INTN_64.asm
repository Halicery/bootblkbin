;nasm bootblkbin_INTN_64.asm -fbin -obin.vfd -lbootblkbin.l
;
;  INT N in long-mode: mixed 16/32/64-code
; 
;  1. go 64-bit mode
;  2. far call into 16-bit code: execute INT N and far return
;  3. far call into 32-bit code: execute INT N and far return
;  4. back in 64-bit code execute INT N and HALT
;
;
;  Conformance test for when LME=1, CPU uses 64-bit IDT and qword-stack-frame mechanism
;  regardless of what 16/32/64-code is running when interrupts occur.  
;
;  16-bit              32-bit              64-bit    
;    |                   |                   |                 
;    |                   |                   |                 
;    |---> 64-bit gate   |---> 64-bit gate   |---> 64-bit gate 
;    |<--- iretq         |<--- iretq         |<--- iretq       
;    |                   |                   |                 
;    |                   |                   |                 
;
;  Note. HANDLER MUST BE 64-BIT: 16/32 CANNOT EXECUTE IRETQ. THATS WHY.
;  Note. CPU will push 5 qwords, including SS:RSP
;
;  pushq SS
;  pushq RSP
;     |
;     |
;     |
;     |
;  popq RSP      iret
;  popq SS     <------ null or fetch 
;                     
;  popq SS: allowed to be null or cpu will fetch descriptor
;           For 16/32 must be proper legacy stack descriptor (iret will pop it and check limit etc)
;           For 64 can be null OR minimal but proper descr (P, S, R set)
;
;
; Hy ok (GenuineIntel 000906E9)  Dell Precision i7
;
; https://github.com/Halicery/Bootblkbin


%include "inc.prologue.asm"

%include "inc.EnableLongModePML4E16.asm" 
 
[BITS 16]
; Go 64-bit

  LGDT [GDTABLELOAD]   ; 16-bit LGDT instr: GDTR upper byte zeroed (here ok we are under 16M)
  MOV ECX, CR0         
  INC CX               ; Set PE
  BTS ECX, 31          ; set PG-bit
  MOV CR0, ECX
  JMP GD_CODE64:GO64   ; Load L=1 CS     

  
%include "inc.outhex64.asm"

ASMFILENAME: db __FILE__, 0 
 
; ==================================================================================================================

[BITS 64]
GO64: 

  ;mov esp, 0x9011   ; Test. NO problem with un-aligned stack
  
  ; test 64-bit QWORD move to screen: 4 chars should be written at once (8 bytes)
  mov rax, 'G_O_6_4_'
  mov [0xb8000 + 100], rax
  

[BITS 64]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; rdi shared between targets for screen write position, make sure rdi HI zero
  xor edi, edi

  ; Jump into 16-bit target: execute INT N to 64-bit handler and return with 66 retf
  mov eax, '1!6!'
  call far dword [rel DPTR_TARGET16]

  ; Jump into 32-bit target: execute INT N to 64-bit handler and return with 66 retf
  mov eax, '3/2/'
  call far word [rel WPTR_TARGET32]
  
  ; 64-bit: set to proper (but no base/limit matters) or null-SS-descriptor
  ;mov ax, GD_SS
  xor eax, eax
  mov ss, ax
  
  ; test INT N handler from 64-bit mode  

  ; print my signature
  mov edi, 0xb8000 + 160*9
  mov eax,  '6_4_'
  stosd
    
  ; LIDT: loads 64-bit linear address
  lidt [rel IDTLOAD64]    ; <-- loading from 10-byte structure indeed (need DQ for address)
  int VectorNumber 
  
  ; print my return signature
  stosd
  
      ; wait key
      in60:
        in al, 0x64   ; poll OBF
        test al,1
        jz in60
      
      ; RESET
      MOV AL, 1
      OUT 0x92, AL
      
  
  
[BITS 64]
HANDLER64:
  ; Prints 'INTN' with 64-bit 'colors' 
  scasd     ; add 4
  push rdi
  push rax
  mov rax, 'I_N_T_N_'
  or edi, 0xB8000
  stosq
  pop rax
  pop rdi
  add edi, 12
  iretq
  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
;
; With intentionally mixing target code-size 
; and far call operand-size: 
;  
;  - dword far call to 16-bit code: then use retfd
;  - word far call to 32-bit code: then use retfw

WPTR_TARGET32: 
  dw TARGET32
  dw GD_CODE32
 
DPTR_TARGET16: 
  dd TARGET16
  dw GD_CODE16

    
[BITS 32]                            
TARGET32:
  ; NB. PE=1 so do not change any SEGREG
  ; DS.BASE=0000_0000 and ES.BASE=000B_8000 from prologue        
  ; LIMIT not extended AND IS CHECKED DURING EXECUTION (TESTED) 

  DAA   ; check indeed not running in 64-bit mode
  
  ; print my signature
  mov edi, 160*7
  stosd               ; ES base= B8000 from prologue so using es 
  
  ; LIDT: loads 32-bit linear address
  lidt [IDTLOAD64]        ; <-- i.e. 32-bit operation of this instruction in 32-bit code with LME set
  
  push GD_SS       ; need proper selector: INT N will push it -- and iretq will pop it, causing descriptor fetch, check and cache
  pop ss           ; being in non-64 code a null-selector is not valid (first stack reference will EXC)
  
  ; OOPS. CPU scaled vector x16 in 32-bit code <-- LME decided!
  ; OOPS. CPU makes QWORD frame with possible ALIGN
  ; ALSO PUSHES SS:RSP 
  int VectorNumber        ; <-- i.e. full 64-bit operation of this instruction in 32-bit code with LME set

  ; print my return signature
  stosd
    
  retfw
  
  
[BITS 16]
TARGET16: 
  ; NB. PE=1 so do not change any SEGREG
  ; DS=0 and ES=B800 from prologue        
  ; LIMIT not extended AND IS CHECKED DURING EXECUTION (TESTED)
  
  ; print my signature
  MOV DI, 160*5     
  STOSD
  ; LIDT: loads 24-bit linear address
  LIDT [IDTLOAD64]
  ; need proper selector: INT N will push it -- and iretq will pop it, causing descriptor fetch, check and cache
  PUSH GD_SS
  POP SS 
  INT VectorNumber
  ; print my return signature
  STOSD
  RETFD
  
                                     
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
VectorNumber equ 51     ; chose one
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  

; works for both 64/32
IDTABLE64:                                ; 64-bit Gate-s are 16-byte structures
	dw HANDLER64                            ; Target Offset[15:0]
	dw GD_CODE64                            ; Target Selector
	db 0x00                                 ; Reserved, IGN, IST
	db 0x8E                                 ; P DPL 0 Type 
	dw 0                                    ; Target Offset[31:16]
	dd 0                                    ; Target Offset[63:32]
	dd 0                                    ; Reserved, IGN

IDTLOAD64: 
	dw -1                            ; max limit
	dq IDTABLE64 - 16 * VectorNumber ; just shoot N x 16 bytes below with LIDT

; for 16/32-load: note still 16x scaling 
;IDTLOAD: 
;	dw -1                            ; max limit
;	dd IDTABLE64 - 16 * VectorNumber ; just shoot N x 16 bytes below with LIDT




  
;align 8 ; just waste bytes, no peformance issue here, cpu happy anyway

GDTABLE   EQU $ - 8       ; We do not allocate space for the GDT null-selector. Save space

GD_CODE16 equ $-GDTABLE

  dw -1          ;   limit
  dd 0x9A000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  db 0 ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  db 0           ;   base HI

GD_SS  equ $-GDTABLE  

  ; Long-mode OR Legacy type?? Base/Limit matters for IRET? <-- NO! 64-bit mode pops and don't care
  ; MINIMAL 64-BIT FOR POP SS: 
  ; P, S=1, R should be one. AND NOT executable. Kinda proper without base/limit. E-bit does not matter either (reverse limit)
  ;dw 0          ;   limit
  ;dd 0x92000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  ;db 0000_0000b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  ;db 0           ;   base HI

  ; Legacy 64K
  dw -1          ;   limit
  dd 0x92000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  db 0           ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  db 0           ;   base HI

  ; Legacy 4GB
  ;dw -1          ;   limit
  ;dd 0x92000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  ;db 1100_1111b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  ;db 0           ;   base HI

GD_CODE64 equ $-GDTABLE
  ; Long-mode type. base, limit: don't care
  dw 0
  dd 0x9A000000  ;   | P |  DPL  | S | X | c | . | . |
  db 0010_0000b  ;   | . | D | L | . | . . . . . . . |  D=0 L=1   
  db 0           ;   

GD_CODE32 equ $-GDTABLE

  ; Long-mode OR Legacy type?? Base/Limit matters? <-- YES! When executing 32-bit with LME, the code needs Legacy (limit check etc. activated)
  ;dw -1          ;   limit
  ;dd 0x9A000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  ;db 1100_1111b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  ;db 0           ;   base HI

  ; Long-mode?
  dw -1           ;  1. test limit=0 or 1 CRASH <-- 
  dd 0x9A000000  ;   | P |  DPL  | 1 | 1 | C | . | . |
  db 0100_0000b  ;   | . | D | L | . | . . . . . . . | 
  db 0 
            ;   
GDTABLELOAD EQU $ 
  dw -1          ; just max limit 
  dw GDTABLE     ; 24-bit linear address of GDT table (we use 16-bit lidt - save one byte)
  db 0


times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
