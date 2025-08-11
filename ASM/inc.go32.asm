;***********************************************************************************
;
;  Switch to 32-bit 4GB
;
;  Most compact include to kick in 32-bit mode to run simple tests
;  Loads 4GB FLAT descriptors into DS/ES/SS (B=1 for SS, has no meaning for other SR)
;  Loads D=1 32-bit 4GB FLAT CODE descriptor
;  Jumps to defined label GO32 with D=1
;  make sure DS=0
;
; https://github.com/Halicery/Bootblkbin

[BITS 16]
  LGDT [GDTABLELOAD]  ; 286-style LGDT, GDTR HI zero (here ok, <16M)   
  SMSW CX             ; set PE=1
  INC  CX
  LMSW CX
  PUSH GD_DATA32
  POP  DS             ; one-byte opcodes
  PUSH DS
  POP  ES
  PUSH DS
  POP  SS                     
 ;MOV ESP, 0x450000           ; Test. Put stack really high
  MOV BYTE [GDTABLE+13], 0x9A ; save 3 bytes, make it CODE32
  JMP GD_CODE32:GO32          ; Load CS with D=1
  
GDTABLE     EQU $ - 8         ; We do not allocate space for GDT null-selector. Save space
GD_CODE32   EQU $ - GDTABLE   ; define sym for IDT etc.
GD_DATA32   EQU $ - GDTABLE   ; 
  dw -1                       ; define only one 4GB descriptor to save space
  dd 0x92000000               ; | P |  DPL  |S=1| X |C/E|R/W| A |
  dw 0x00CF                   ; | G |D/B| L | V | LIMIT 19..16  |   
  
GDTABLELOAD EQU $ - 2         ; *** USE PREVIOUS WORD 0x00CF FOR LIMIT *** to save 2 bytes    >>> Only in bootblk <<<
  ;dw -1
  dw GDTABLE                  ; 24-bit linear address of GDT table
  db 0                        ; HI <64K 
