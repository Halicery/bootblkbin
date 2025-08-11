;nasm bootblkbin_lgdt.asm -fbin -obin.vfd -lbootblkbin.l

;;;;;;;;;;;;;;;;;;;;;; Test LGDT/SGDT and operand size
;  
;  There is a little detail when simply executing LGDT in RM
;  (More precisely LGDT and operand size = 16)
;  The last byte of BASE is ignored and GDTR BASE HI byte zeroed
;  It is for 286 emulation: <16MB (24-bit address space)
;  Can be used to save one byte in bootblock
;

%include "inc.prologue.asm"  

[BITS 16]

  MOV DI, 4*160    ; line4
  CALL PRINTGDT    ; Prints 12345678FFFF
  
  ; TEST 32-BIT LGDT: load and store then print out mem
  o32 LGDT [TESTGDT]       ; 32-BIT LGDT (load 4-bytes BASE)
  or dword [TESTGDT+2], -1 ; 16-BIT SGDT: stores 3- or 4 bytes of BASE? Set BASE all one in mem
  SGDT [TESTGDT]           ; 16-BIT SGDT <-- stored 4 bytes
  MOV DI, 6*160            ; line6
  CALL PRINTGDT            ; Prints 12345678FFFF: 386 SGDT stores full base, 3 WORDS from GDTR regardless of 66h prefix
                           
  ; TEST 16-BIT LGDT: load and store then print out mem
  LGDT [TESTGDT]           ; 16-BIT LGDT
  or dword [TESTGDT+2], -1 ; 16-BIT SGDT
  SGDT [TESTGDT]           ; 16-BIT SGDT
  MOV DI, 7*160            ; line7
  CALL PRINTGDT            ; Prints 00345678FFFF: LGDT ZEROED HI BYTE
  
  HLT
  
  PRINTGDT:            ; print 6 BYTES
    ; SCREEN POS IN DI
    MOV SI, TESTGDT
    MOV CX, 6  
    CALL outhex16
    RET
    
  TESTGDT:
  dw -1          ; max limit 
  dd 0x12345678  ; 32-bit linear address of GDT table 

  
;;;;;;;;;;;;;;;;; END TEST ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ASMFILENAME: db __FILE__, 0 
  
%include "inc.outhex.asm"


	times (510 + $$ - $) db 0         ; No need for Hy or VB 
	db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
