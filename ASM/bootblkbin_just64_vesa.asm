;nasm bootblkbin_just64_vesa.asm -fbin -obin.vfd -lbootblkbin.l
;
; Test to kick in 64-bit mode and use 64-bit writes to set some pixels.
;
; 4 x 2BPP pixels written at once.
; Also useful to test high mem where frame buffer is (is our paging ok?)
;
; Haswell ok (GenuineIntel 000306C3)  4th Generation Intel Core. Model 3C
; E4200 ok (GenuineIntel 0001067A)    Family 06 Model 17 Stepping A     Core 2 Duo Mobile SU9300
; Hy, VBox ok!
;
;
; https://github.com/Halicery/Bootblkbin


VESAMODE EQU 111h      ; 111h 640x480 16 600KB
;VESAMODE EQU 112h      ; 112h 640x480 16.8M (8:8:8)   <-- Hy, D430 reports back 32-bpp
;VESAMODE EQU 114h      ; 114h 800x600 16 938KB
;VESAMODE EQU 117h      ; 117h 1024x768 16 1536KB 
;VESAMODE EQU 118h      ; 118h 1024x768 16.8M (8:8:8)  <-- Hy, D430 reports back 32-bpp
;VESAMODE EQU 11Ah      ; 11Ah 1280x1024 64K (5:6:5)   16 2560KB (Haswell works)
;VESAMODE EQU 11Bh      ; 11Bh 1280x1024 32        (Haswell ok)
;VESAMODE EQU 110h      ; 110h 640x480 15
 
; Old D430 with the same panel does NOT support this 
; E4200 laptop with 1280x800 panel. No other recognises this mode. 
;VESAMODE   EQU 161h     ; 161h 1280x800 16 <-- works on my E4200 laptop! Wiki mentions 160h for 8-bit.. so I tried 161h.
;VESAWIDTH  EQU 1280     ; 162h 1280x800 32-bpp!!! cool
;VESAHEIGHT EQU 800      ; 


%include "inc.vesa_prologue.asm" 


VESABPP   EQU 2         ; testing 16-bpp modes here
VESAPITCH EQU VESAWIDTH*VESABPP

%include "inc.go64.asm" 
 
[BITS 64]
GO64:

  ; LFB address from vesa_prologue: EBP

  ; Fill screen
  mov edi, ebp 
  mov ecx, ( ( VESAWIDTH * VESAHEIGHT - 8 ) * VESABPP ) / 8   ; fill 8 pixels less with qwords
  cld            
  or rax, -1
  stosq                         ; first 4 pixels white
  mov rax, 0xaaaaaaaaaaaaaaaa   ; fill some background color
  rep stosq 
  or rax, -1                    ; last 4 pixels white
  stosq
  
  
  ; draw a horizontal line across screen using rep stosq  
  ;or rax, -1                                         ; color white
  mov rax, ~0x001F001F001F001F                       ; color yellow 5:6:5 for 4 pixels
  lea edi, [ebp + (VESAWIDTH*50) * VESABPP ]     ; pos 50;100
  mov ecx, VESAWIDTH * VESABPP / 8               ; pixel width
  rep stosq
    
  
  ; fill a rectangle with solid color
  W equ 128
  H equ 39
  
  lea edi, [ebp + (VESAPITCH*VESAHEIGHT + VESAWIDTH*VESABPP) / 2 ] ; at pos center of screen  
  or rax, -1                                                       ; color white
  mov ecx, H                                                       ; pixel height = 39
  .pitch:
    push rdi
    push rcx
    mov ecx, ( W * VESABPP ) / 8                                 ; pixel width = 128 in qwords
    rep stosq
    pop rcx
    pop rdi
    add edi, VESAPITCH
  loop .pitch    
  
  ; wait key
  call in60
  ; RESET
  MOV AL, 1
  OUT 0x92, AL
 
in60:
    in al, 0x64   ; poll OBF
    test al,1
    jz in60
    ;inc byte [0xb8012] 
    in al, 0x60   ; get scan code
    ret    
  

  
times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
