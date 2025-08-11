;nasm bootblkbin_just64.asm -fbin -obin.vfd -lbootblkbin.l
;
; Test to kick in 64-bit mode right from 16-bit RM. 
;
; Haswell ok (GenuineIntel 000306C3)
; Hy, VBox on AMD Ryzen ok
; 
; PE=1 and PG set in one write: Haswell made it too.
;
; https://github.com/Halicery/Bootblkbin


; Testing some outhex routines 
%define NEED.dumphex  
%define NEED.outhexnz


%include "inc.prologue.asm" 

[BITS 16]

  ; Test outhex16nz in top of outhex64
  MOV CX, 4
  ;PUSH DWORD 0x800
  PUSH DWORD 0      ; test proper zero-detection
  MOV DI, 160*3
  MOV SI, SP
  CALL outhex16nz   ; we do not bother restoring stack


%include "inc.go64.asm"
 
[BITS 64]
GO64:

  ; DEFAULT DATA: 32
  ; DEFAULT ADDR: 64
  ; 32-reg move zeroes REG HI 
    
  ; test 64-bit QWORD move to screen: 4 chars should be written at once (8 bytes)
  mov rax, 'G_O_6_4_'  ; 48 is a REX instruction prefix that specifies a 64-bit operand size
  mov  [0xb8000 + 100], rax   
  
  ; test outhex64: write 8 bytes
  mov ecx, 8
  mov rax, 0xabcdef0123456789 ; prints --> ABCDEEFF02345679
  push rax                    ; qword push
  mov edi, 0xb8000 + 160*8    ; line 8
  mov esi, esp
  ;call outhex64    ; we do not bother restoring stack
  call dumphex64   ; we do not bother restoring stack
  
  
  ; test outhex64nz 
  mov ecx, 8
  push 0x640   ; dword -> sign-extended qword push
  mov edi, 0xb8000 + 160*9
  mov esi, esp
  call outhex64nz   ; we do not bother restoring stack
  ;call dumphex64    ; we do not bother restoring stack
  
    
  ;When software enables paging while long mode is enabled, the processor activates long mode, 
  ;which the processor indicates by setting the longmode-active status bit (EFER.LMA) to 1.
  ; Print EFER --> 00000500 something like this
  or rax, -1            ; to verify RDMSR zeroes reg HI in 64-bit mode
  mov ecx, 0xC0000080   ; EFER reg
  RDMSR
  push rax
  mov edi, 0xb8000+160*10
  mov ecx, 8      ; 64-bit rax: verifying RDMSR zeroes HI
  mov esi, esp
  call outhex64   ; we do not bother restoring stack
  
  ; Test outs in 64-bit 
  mov edi, 0xb8000 + 11*160
  mov esi, TESTSTRING
  call outs  
    
  ;inc byte [0xb8000]    ; give some life-sign on the screen on return
  hlt  
  
TESTSTRING: db "outs 64-bit mode", 0     
                    


ASMFILENAME: db __FILE__, 0 

%include "inc.outhex64.asm"

  
times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
