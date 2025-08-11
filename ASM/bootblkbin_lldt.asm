;nasm bootblkbin_lldt.asm -fbin -obin.vfd -lbootblkbin.l
;  
;  Test how to load segment descriptors from a Local Descriptor TABLE
;
;  Has not much meaning, only to see how LLDT and T=1 selectors work. 
;
;  LLDT has different operand syntax from LGDT:
;   loads a 16-bit *selector* into the on-chip LDT Register: LLDT r16/m16
;  
;  Haswell ok. Hy, VBox ok.
;  
; https://github.com/Halicery/Bootblkbin


%include "inc.prologue.asm" 

[BITS 16]
  
  LGDT [GDTABLELOAD] ; 16-bit LGDT: loads 24-bit linear address
  
  SMSW CX            ; Set PE.. then load LDTR and load SEG DESCRIPTORS from LD TABLE
  INC  CX
  LMSW CX
  
  MOV  AX, GD_LDT    ; Load selector of LDT Descriptor from GD TABLE 
  LLDT AX            ; LLDT r/m16 is #UD not recognized in Real Address Mode. Moves WORD only. 
                     
  PUSH LD_DATA32     ; Load T=1 selectors, from Local Table
  POP  DS
  PUSH DS
  POP  ES
  JMP LD_CODE32:GO32 ; Load CS with D=1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; LD TABLE: 4GB FLAT DATA/CODE DESCRIPTORS here -------------------
; NO null selector in LDT
;

LDTABLE:

LD_DATA32 EQU $ - LDTABLE | 4        ; + 4: set Table Indicator TI=1

	dw 0xFFFF       ; limit 4GB
	dd 0x92000000   ; | P |  DPL  |S=1| X |C/E|R/W| A |  BASE 23..0   
	dw 0x00CF       ; | G |D/B| 0 | 0 | LIMIT 19..16  |  BASE 31..24 

LD_CODE32 EQU $ - LDTABLE | 4

	dd 0x0000FFFF   ;  base | limit
	dd 0x00CF9A00   ;  D=1
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; GD TABLE
; Define only one descriptor: LDT DESCRIPTOR (S = 0, TYPE = 2)
; Points to LD TABLE

GDTABLE   EQU $ - 8         ; We do not allocate space for GDT null-selector. Save space
GD_LDT    EQU $ - GDTABLE   ; -- LDT DESCRIPTOR: linear memory address of LDTABLE

	dw -1                      ; set some limit
	dd 0x82000000 + LDTABLE    ; P |  DPL  |S=0| x   x   x   x |  TYPE=0010 LDT, BASE 23..0 we are below 16M (plus + is allowed with reloc values NASM)
	dw 0                       ; G | 0 | 0 | 0 | LIMIT 19..16  |  BASE 31..24    <-- 286-style all zero

GDTABLELOAD:
	dw -1       ; just max limit
	dw GDTABLE  ; 24-bit linear address of GDT table - save one byte 
	db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
  
[BITS 32]
  GO32:

  ; test outhex32
  mov esi, 28*1024*1024  ; put something high up to 28 MB.. and print it out
  mov [esi], dword 0x0123beef
  mov edi, 0xB8000 + 160*5  ; line 5 
  mov ecx, 4
  call outhex32

  ; test outs in 32-bit mode  
  mov edi, 0xB8000 + 160*6  ; line 6 pos 0
  mov esi, TESTSTRING
  call outs  
   
  inc byte [0xb8000]    ; give some life-sign on the screen
  
  hlt  
  
TESTSTRING: db "LLDT 32-bit outs", 0 



; -----------------------------------------------------------------------
;C_LDTABLE equ LDTABLE - $$ + 0x7c00  ; make constant


ASMFILENAME: db __FILE__, 0 

%include "inc.outhex.asm" ; 16/32-bit only. Uses BCD instructions


times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 


	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
