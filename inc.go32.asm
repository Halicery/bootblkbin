;***********************************************************************************
;
;  Switch to 32-bit 4GB
;
;  Loads 32-bit FLAT descriptors into DS/ES/SS (B=1, has no meaning for other SR)
;  Loads 32-bit FLAT CODE descriptor
;  Jumps to defined label GO32 with D=1
;  make sure DS=0 - or use CS LGDT [...] and stuff

[BITS 16]
  MOV EAX, CR0        ; Set PE
  INC AX
  MOV CR0, EAX 
  LGDT [GDTABLELOAD]    
  PUSH GD_DATA32     ; DS/ES/SS 4GB FLAT
  POP  DS            ; one-byte opcodes
  PUSH DS
  POP  ES
  PUSH DS
  POP  SS
  
  ;mov esp, 0x450000    ; Test. Put stack really high
  
  mov byte [GDTABLE + GD_CODE32 + 5], 0x9A   ; save 3 bytes, make it CODE32
  JMP GD_CODE32:GO32  ; Load CS with D=1
  
GDTABLELOAD:
  dw -1         ; just max limit 
  dd GDTABLE    ; linear address of GDT table 
  
GDTABLE   EQU $ - 8
GD_CODE32 EQU $ - GDTABLE   ; defined IDT etc.
GD_DATA32 EQU $ - GDTABLE   ; define only one descriptor
  dw -1                     
  dd 0x92000000             
  dw 0x00CF
