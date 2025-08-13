;nasm bootblkbin_nasm-64-abs-to-rip-rel-trick.asm -fbin -obin.vfd -lbootblkbin.l
; 
; 
; https://github.com/Halicery/Bootblkbin


%include "inc.prologue.asm" 
  
%include "inc.go64.asm"

[BITS 64]
GO64:

  ; test 64-bit QWORD move to screen: 4 chars should be written at once (8 bytes)
  mov rax, 'G_O_6_4_'   
  mov [rel Z + 0xb8000 + 100], rax  ; Test our absolute-to-relative NASM-trick (to save on byte with RIP-REL)
  
  ; compare codebytes for these:
  ; - absolute offset uses one more byte (redundant SIB Direct Memory)
  ; - the 'old' Direct Memory is the new 64-bit RIP REL
  ; BOTH encodes a 32-bit value sign-extended to 64-bit before used in address calculation:
  
    ;inc byte [rel 0xb8000]      ; <-- NASM WARNING: encoded as absolute offset
    inc byte [0xb8000]          ; <-- 32-bit signed absolute offset
    inc byte [rel Z + 0xb8000]  ; <-- absolute-to-relative NASM-trick (to save on byte with RIP-REL)
    
    hlt

    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  

 
%include "inc.outhex64.asm"

ASMFILENAME: db __FILE__, 0 

  
	times (510 + $$ - $) db 0         ; No need for Hy or VB 
	db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
; absolute-to-relative NASM-trick: our paging maps virtual to physical addresses
;
; inc byte [rel 0xb8000] <-- NASM: absolute address can not be RIP-relative
;
; IT JUST IRRITATED ME THAT NASM CANNOT MAKE RIP-REL FROM AN ABSOLUTE VALUE (I KNOW WHAT I'M CODING)
;
; SIB-DIRECT-MEMORY USES SIB BYTE - WHILE RIP-REL DOES NOT
; THAT IS ONE EXTRA BYTE PER EVERY ABSOLUTE ADDRESS (SHOULD HAVE BEEN OPPOSITE DESIGN IMHO)
;
; NASM needs a symbol for RIP-REL. 
; So make a noprogbits section with start=0 and one symbol, Z. Then use [rel Z + abs]
; NB!!! RIP-REL IS STILL SIGNED 32-BIT, SO WILL NOT WORK FOR EG. LAPIC EOI! 
; WE CANNOT ADDRESS ABOVE 2GB FROM CURRENT CODE LOCATION.
; Or maybe make one page for APIC? FS/GS? Just complicated.

;section .bss start=0                       ; into default nobits bss
section .abs-to-rel-trick nobits start=0    ; or.. make some nobits section. 
Z resd 1

; and look at the map file
;[map all bootblkbin.map]
