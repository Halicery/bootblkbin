;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Switch to 64-bit (Lower 4GB mapped)
;
;  Jumps to defined label GO64 with L=1 D=0

%include "inc.EnableLongModePML4E16.asm"       ; 64-bit mode requires paging. PAE with new PML4E 
 
[BITS 16]
LGDT [GDTABLELOAD]
MOV ECX, CR0         ; Set PE
INC CX
BTS ECX, 31          ; set PG-bit: works together with PE
MOV CR0, ECX
JMP GD_CODE64:GO64   ; Load L=1 CS     

; ==================================================================================================================
; No segmentation in 64-bit
;
; Data-Segment: EVERYTHING ignored in 64-bit mode except P (present) bit. That is already set in RM
; No need to do anything.
;
; Only a 64-bit code segment.
; Basically code can jump between D=0 L=1 (64) and L=0 (16/32) code segments with PE=1
; ==================================================================================================================

;align 4  do not waste bytes 
GDTABLELOAD:
  dw -1         ; just max limit 
  dd GDTABLE    ; linear address of GDT table 
  
GDTABLE   EQU $ - 8
GD_CODE64 EQU $ - GDTABLE   ; defined for IDT etc.
dd 0            ;  base | limit: don't care
dd 0x00209A00   ;  G |D/B| L | V | LIMIT 19..16  |   D=0 L=1
