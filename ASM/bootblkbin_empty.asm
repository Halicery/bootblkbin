;nasm bootblkbin_empty.asm -fbin -obin.vfd -lbootblkbin.l
;
;   Our skeleton:
;   Write code between prologue and outhex subroutines 
;   Still in 16-bit mode after prologue
;   ASMFILENAME should be defined: prologue prints it
;
; https://github.com/Halicery/Bootblkbin

%include "inc.prologue.asm"

[BITS 16]

  HLT













%include "inc.outhex.asm"

ASMFILENAME: db __FILE__, 0 

times (510 + $$ - $) db 0
db 0x55, 0xAA                       ; No need for Hyper-V or VirtualBox or PXE boot 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy. PXE has no such thing
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
