;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Most compact include to kick in 64-bit mode to run simple tests
;
;  Switch to 64-bit (Lower 4GB memory linearly mapped)
;
;  Jumps to defined label GO64 with L=1 D=0
;  make sure DS=0
;
; https://github.com/Halicery/Bootblkbin

%include "inc.EnableLongModePML4E16.asm"       ; 64-bit mode requires paging. PAE with new PML4E 
 
[BITS 16]
  LGDT [GDTABLELOAD]   ; 16-bit LGDT instr: GDTR upper byte zeroed (here ok we are under 16M)
  MOV EAX, CR0         ; Set PE and PG-bit: works together with PE
  OR  EAX, 0x80000001   
  MOV CR0, EAX
  JMP GD_CODE64:GO64   ; Load L=1 CS     

; ==================================================================================================================
; No segmentation in 64-bit
;
; Data-Segments: EVERYTHING ignored in 64-bit mode except P (present) bit. That is already set in RM
; No need to do anything.
;
; Only a 64-bit code segment.
; Basically code can jump between D=0 L=1 (64) and L=0 (16/32) code segments with PE=1
; ==================================================================================================================

;align 4  do not waste bytes 
  
GDTABLE   EQU $ - 12         ; We do not allocate space for GDT null-selector. Save space

GD_CODE64 EQU $ - GDTABLE - 4
  ;dd 0         *** USE PREVIOUS DWORD FOR BASE|LIMIT (don't care in 64-bit - but loaded) to save 4 bytes   >>> Only in bootblk <<<
  dw 0x9A00          ; | P |  DPL  |S=1| X |C/E|R/W| A |
  dw 0x0020          ; | G |D/B| L | V | LIMIT 19..16  |  D=0 L=1
  
GDTABLELOAD EQU $ - 2                
  ;dw -1        *** USE PREVIOUS WORD 0x0020 FOR LIMIT *** to save 2 bytes   >>> Only in bootblk <<<
  dw GDTABLE    ; 24-bit linear address of GDT table
  db 0          ; HI <64K 
