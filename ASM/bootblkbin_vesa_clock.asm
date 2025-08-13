;nasm bootblkbin_vesa_clock.asm -fbin -obin.vfd -lbootblkbin.l
; 
;  This is just for fun: test our LineTo draw algorithm by drawing a clock going 'round.. 
;  Moves by keypress.
;
;  FPU programming: computes sin/cos for LineTo
;
;
; My Haswell 8 cores OK (GenuineIntel 000306C3) VESA 0300
; Hy ok
;
; https://github.com/Halicery/Bootblkbin


VESABPP EQU 2      ; testing 16-bpp modes here
VESAPITCH EQU VESAWIDTH*VESABPP

VESAMODE EQU 111h      ; 111h 640x480 16 600KB
;VESAMODE  EQU 114h      ; 114h 800x600 16 938KB
;VESAMODE  EQU 117h      ; 117h 1024x768 16 1536KB 
;VESAMODE  EQU 11Ah      ; 11Ah 1280x1024 16 2560KB (Haswell works)
;VESAMODE  EQU 11Ah      ; 11Ah 1280x1024 16 2560KB 
; try haswell in 32bpp
;VESAMODE   EQU 11Bh      ; 11Bh 1280x1024 32-bit (Haswell ok)
; Old D430 with the same panel does NOT support this 
; E4200 laptop with 1280x800 panel. No other recognises this mode. 
;VESAMODE   EQU 161h     ; 161h 1280x800 16 <-- works on my E4200 laptop! Wiki mentions 160h for 8-bit.. so I tried 161h.
;VESAWIDTH  EQU 1280     ; 162h 1280x800 32-bpp!!! cool
;VESAHEIGHT EQU 800      ;  
    

%include "inc.vesa_prologue.asm"   ; ES:(E)DI points to --> ModeInfoBlock + EBP=LFB

%include "inc.go32.asm"

BG_COL EQU 0x55555555   ; fill some background color
;BG_COL EQU 0xAAAAAAAA ; fill some background color
  
[BITS 32]
GO32:

  ; LFB Address: keep it in ebp
  ;mov ebp, [edi + ModeInfoBlock.PhysBasePtr]
  ;pop ebp

  ; Fill pixel screen
  cld            
  mov edi, ebp
  mov ecx, VESAWIDTH * VESAHEIGHT * VESABPP / 4
  mov eax, BG_COL
  rep stosd
  
  ; We just rely on FPU: 
  ;  radian = sec * 2PI/60
  ;  sincos
  ;  mul by radius and store
  FNINIT              
  FLDPI 
  fidiv word [i30]    ; 2PI/60
  fild  word [radius] ; keep these two on fpu stack
  
.nextsecond: 
    
    mov al, [sec]
    inc al
    aam 60          ; Modulo60, AL=REMAINDER
    mov [sec], al     

    fild word [sec]
    fmul st2             ; sec * 2PI/60
    fsincos
    fmul st2             ; radius
    fchs                 ; neg y
    fistp dword [enddy]
    fmul st1             ; radius
    fistp dword [enddx]

    call Draw  
    
    .nobreakcode: call in60   ; waitkey
    test al, al
    js .nobreakcode
    
    ;call Draw  ; OR clear it, uses XOR: second call clears
    
jmp .nextsecond

align 4    
enddx:  dd 0
enddy:  dd 0
radius: dw VESAHEIGHT/3
i30:    dw 30
sec:    dw 0
  
Draw:
  lea edi, [ebp + (VESAWIDTH * VESAHEIGHT/2 + VESAWIDTH/2) * VESABPP ]     ; center of screen  
  push dword [enddx] 
  push dword [enddy]
  call LineTo
  ret
 
in60:
    in al, 0x64   ; poll OBF
    test al,1
    jz in60
    in al, 0x60   ; get scan code
    ret    




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; Draw line to (dx;dy) = delta x,y
; 
;   Computes the 4 parameters for Line1 based on octet.
;   Essentially abs(dx), abs(dy) and the two steps with +/- direction pushed in the correct order
;   
;   Note. No opt for H/V-lines, we're little tight in 512-bytes code space. 
;   Opt for code size here.
;
; Quartets: XDIR/YDIR
; Octets: xmajor/ymajor
;
;     \    |    /
;      \   |   /    
;       \  |  /
;        \ | /
;         \|/    
;     -------------    
;         /|\     
;        / | \   
;       /  |  \  
;      /   |   \ 
;     /    |    \
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; edi: pixel address (updates edi)
; pushed..
; dx    +8
; dy    +4 
; RET         <-- esp
   
LineTo:
  
  push VESABPP  
  pop ecx
  mov ebx, VESAPITCH                           
    
  xor eax, eax      ; zero EDX:EAX
  cdq
  
  ; Quartets: XDIR/YDIR
  or eax, [esp + 8]       ; dx
  jns .dxpos
  neg eax   ; abs(dx)
  neg ecx   ; -xdir
  .dxpos:
  or edx, [esp + 4]       ; dy
  jns .dypos
  neg edx   ; abs(dy)
  neg ebx   ; -ydir
  .dypos:             
  
  ; Octets: xmajor/ymajor
  cmp eax, edx   ; abs(dx) <= abs(dy) ?
  jnb .xmajor
  xchg eax, edx
  xchg ecx, ebx
  .xmajor:  
  
  push eax      ;dx
  push edx      ;dy
  push ecx      ;VESABPP 
  push ebx      ;VESAPITCH  
  call Line     ; full-length line 
  ;call Line1   ; polyline
  ret 8  ; we clean up

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; Core line draw algorithm (c) A. Tarpai 
; 
;   To speed up things this routine draws one pixel less: 
;   but moves drawing position to the last pixel on trajectory
;   This is how it is used in polyline draw (do not draw last pel)
;   A full line routine has to plot the last pixel after calling this one
;   Two reasons: performance and we opt for polylines. This should fly.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Line1:

; edi: pixel address (updates edi)
; pushed..
.major_delta equ +20    
.minor_delta equ +16
.major_step equ +12
.minor_step equ +8
; RET
; ebp               <-- esp = ebp ([esp] uses sib - longer)

  push ebp
  mov ebp, esp
  mov ecx, [ebp + .major_delta]    ; ecx <- our counter. Same as major (# of pixels on trajectory minus one)
  jecxz .done                      ; can be zero, done
  mov eax, ecx                     ; eax <- e (Err term major/2)
  shr eax, 1 
  .pix: call WritePixel            ; plot (call, can be complex ROP, 4BPP, TODO)
    add edi, [ebp + .major_step]   ; add major_step
    sub eax, [ebp + .minor_delta]  ; e -= minor: <0?
    jns .eplus                           
    add eax, [ebp + .major_delta]  ; e += major
    add edi, [ebp + .minor_step]   ; add minor_step
    .eplus: loop .pix
  .done: leave
  ret 4 * 4                        ; we clean up
 
WritePixel:
  xor word [edi], ~(BG_COL & 0xFFFF) ;0xaaaa    ; make it white
  ; plot
  ;mov [edi], word -1 ;0000_0000_0001_1111b ;  5:6:5 blue
  ret
   
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 
; Draw line and also set the last pixel. 
;
; same parameters as for Line1
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Line:
  ; This is a nasty delegation (welcome to assembly)
  ; passing parameters on stack push-ed by *my* caller   
  pop ebx          ; RET: ebx not used
  call Line1
  call WritePixel
  jmp ebx


    

; 1-sector break
	times (510 + $$ - $) db 0         ; No need for Hy or VB 
	db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
