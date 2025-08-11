;nasm bootblkbin_just64.asm -fbin -obin.vfd -lbootblkbin.l
;
; Test to kick in 64-bit mode right from 16-bit RM. 
;
; Haswell ok (GenuineIntel 000306C3)
; Hy, VBox ok!
;
; 
; PE=1 and PG set in one write: Haswell made it too.
;
; https://github.com/Halicery/Bootblkbin


org 0x7C00            ; suppose 0000:7C00 CS:IP

; Testing some routines
%define NEED.dumphex  
%define NEED.outhexnz
%define NEED.64


%include "inc.prologue.asm" 

  ; Test outhex16nz in top of outhex64
  mov cx, 4
  push dword 0x800
  mov di, 160*15
  mov si, sp
  call outhex16nz


%include "inc.go64.asm"
 
 
[BITS 64]
GO64:

  ; DEFAULT DATA: 32
  ; DEFAULT ADDR: 64
  ; 32-reg move zeroes REG HI 
    
  ; test 64-bit QWORD move to screen: 4 chars should be written at once (8 bytes)
  mov rax, 'G_O_6_4_'  ; 48 is a REX instruction prefix that specifies a 64-bit operand size
  mov  [0xb8000 + 150], rax   ; There is no instruction mov m64, imm64
  
  ; test outhex64: write 8 bytes
  mov ecx, 8
  mov rax, 0xabcdef0123456789 ; prints --> ABCDEEFF02345679
  push rax   ; qword push
  mov edi, 0xb8000 + 160*8  ; line 8
  mov esi, esp
  ;call outhex64
  call dumphex64
  
  hlt
  
  ; test outhex64nz
  mov ecx, 8
  push 0x640   ; dword -> sign-extended qword push
  mov edi, 0xb8000 + 160*9
  mov esi, esp
  ;call outhex64nz
  call dumphex64
  
  ;When software enables paging while long mode is enabled, the processor activates long mode, 
  ;which the processor indicates by setting the longmode-active status bit (EFER.LMA) to 1.
  ; Print EFER --> 00000500 something like this
  mov ecx, 0xC0000080   ; EFER reg
  RDMSR
  push rax
  mov edi, 0xb8000+160*4  ; line 4
  mov ecx, 4
  mov esi, esp
  call outhex64
  
  ; Test outs in 64-bit 
  mov edi, 0xb8000 + 13*160
  mov esi, TESTSTRING
  call outs  
    
  inc byte [0xb8000]    ; give some life-sign on the screen on return
  hlt  
  
TESTSTRING: db "Test outs in 64-bit mode", 0     
                    


ASMFILENAME: db __FILE__, 0 

%include "inc.outhex.asm"

  
times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
