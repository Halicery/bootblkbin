;nasm bootblkbin_vesa_text.asm -fbin -obin.vfd -lbootblkbin.l
;
; Good ol' VESA still supported in many PC BIOS 
;
;  We can get a pointer to the character ROM with INT 10h
;  Example of 8 x 16 char boxes:
;   ______ 
;  |______| byte 0  
;  |______| byte 1  
;  |______| ..          16 height
;  |______| ..      
;  |______| ..      
;  |______| byte 15 
;
;  Storage:
;  
;  16 bytes of char 0                    16 bytes of char 1                        
;  |______|______|______|______|______|  |______|______|______...   256 x 16 = 4KB
;  
; 
; My Lenovo E130 4 cores OK (GenuineIntel 000306A9) i3
; My Latitude E4200 2 cores OK (GenuineIntel 0001067A) VESA 0300
; My Haswell 8 cores OK (GenuineIntel 000306C3) VESA 0300
; Hy, VBox on AMD Ryzen VESA 0200
;
; https://github.com/Halicery/Bootblkbin


%include "inc.prologue.asm"

VESAMODE EQU 111h      ; 111h 640x480 16 600KB
VESAWIDTH  EQU 640
VESAHEIGHT EQU 480

;VESAMODE  EQU 117h      ; 117h 1024x768 16 1536KB 
;VESAWIDTH  EQU 1024
;VESAHEIGHT EQU 768

;VESAMODE  EQU 11Ah      ; 11Ah 1280x1024 16 2560KB (Haswell works)
;VESAWIDTH  EQU 1280
;VESAHEIGHT EQU 1024

;VESAMODE  EQU 114h      ; 114h 800x600 16 938KB
;VESAWIDTH  EQU 800
;VESAHEIGHT EQU 600

; E4200 laptop with 1280x800 panel. No other recognises this mode. 
;VESAMODE  EQU 162h      ; 161h 1280x800 16 Holy crap works on my E4200 laptop! Wiki mentions 160h for 8-bit.. so I tried 161h.
;VESAWIDTH  EQU 1280     ; 162h 1280x800 32-bpp!!! cool
;VESAHEIGHT EQU 800      ; 

[BITS 16]

  ; Character ROM. Get address before mode switch
  ; 4K character patterns: probably in Video BIOS
  ; AH = 11 - Character Generator Routine (EGA/VGA)
  ; AL = 30  get current character generator information
  ; BH =  6  ROM 8x16 character 
  ; --> ES:BP table pointer
  ; --> CX = bytes per character (=16 here), DL = rows (less 1, here=24 ie. 25 rows)
  ; https://stanislavs.org/helppc/int_10-11.html
  PUSH ES            ; save ES=0xB800
  MOV  AX, 1130H
  MOV  BH, 6
  INT  10H         
    ; ES:BP -> to linear address (Hy: C000:4322, E4200: C000:ABD1.. C-block: 64K Video BIOS)
    MOV [FONTADDR], BP   ; LO
    XOR EAX, EAX
    MOV AX, ES  
    SHL EAX, 4
    ADD [FONTADDR], EAX      
  POP ES            ; restore ES=0xB800
  
  ; Get LFB address (for mode)
  ; Function 01h - Return VBE Mode Information. 256 bytes. 
  ; CX = Mode number
  ; ES:DI = Pointer to ModeInfoBlock structure   
  MOV AX, 4F01h
  XOR DI, DI          ; <-- ES is char screen, put it there
  MOV CX, VESAMODE 
  INT 10h
  ; Get and keep LFB Address in EBP (copy before mode switch call)
  ES MOV EBP, [ModeInfoBlock.PhysBasePtr]

  ; Function 02h - Set VBE Mode    
  MOV AX, 4F02h             ; VESA super VGA mode function call
  MOV BX, VESAMODE | 0xc000 ; 0x4000 Use linear/flat frame buffer model. 0x8000 Don't clear display memory.
  INT 10h

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "inc.go32.asm"  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

VESABPP   EQU 2                     ; testing 16-bpp modes here
VESAPITCH EQU VESAWIDTH * VESABPP

GREEN565    EQU  0000_0111_1110_0000b
BLUE565     EQU  0000_0000_0001_1111b
YELLOW565   EQU  ~BLUE565     
  
FONTADDR: dd 0
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[BITS 32]
GO32:
  
  ; Keep LFB Address, PhysBasePtr in EBP
  ;mov ebp, [PhysBasePtr]
  
  ; Fill pixel screen
  cld            
  mov edi, ebp
  or eax, -1
  stosd                 ; first 2 pixels white
  mov ecx, ( VESAPITCH * VESAHEIGHT - 8 ) / 4   ; fill 4 pixels less with DWORDS
  mov eax, 0x55555555   ; fill some test color
  rep stosd
  or eax, -1            ; last 2 pixels white
  stosd
  
  ; draw a horizontal line   
  ;xor eax, eax                            ; color black
  ;mov ax,  0000_0111_1110_0000b           ; color green    5:6:5
  ;mov ax,  0000_0000_0001_1111b           ; color blue     5:6:5
  ;mov ax, ~0000_0000_0001_1111b           ; color yellow   5:6:5
  mov ax, YELLOW565
  lea edi, [ebp + (VESAWIDTH*100+50) * VESABPP ]     ; pos 50;100
  mov ecx, ( 400 * VESABPP ) / 2       ; pixel width
  rep stosw

    
  ; CHAR STUFF TEST: print text with ROM char patterns
   
  ; Print out out file name
  ;mov edx, 0011_1000_0000_0111b ;[FG_COL]
  mov dx, BLUE565   
  lea edi, [ebp + (VESAWIDTH*82+70) * VESABPP ] 
  mov esi, ASMFILENAME
  call TextString 
  
  ; wait key
  call in60
  
  ; RESET
  MOV AL, 1
  OUT 0x92, AL
  
  hlt 
  
; Render string 
; esi: ptr to string to print
; edi: pixel address
; edx: FG_COL
TextString: 
  CLD
  .next: 
    xor eax,eax
    lodsb
    test al, al
    jnz .out
     ret
    .out:
    push edi
    push esi
    call OneChar
    pop esi
    pop edi
    add edi, 13 * 2  ; next char pos
    ;add edi, (13 + 3*VESAWIDTH) * VESABPP   ; vector (13;3)
    jmp .next
  
; Render one char: transparent mono expand 
; eax: ascii
; edi: pixel address
; edx: FG_COL
OneChar:  
  mov esi, [FONTADDR]
  shl eax, 4
  add esi, eax     ; byte address ascii * 16
  push 16          ; 16 lines of char box
  pop ecx
  .nextcharline:
    lodsb          ; ROM consequitive bytes for one char
    xchg eax, ebx  ; char pattern in bl
    push edi
    push ecx
    mov cl, 8
    .onebyte:
      shl bl,1
      mov eax, [edi]  ; read pixel
      cmovc eax, edx  ; FG_COL
      stosw           ; write pixel
      loop .onebyte
    pop ecx
    pop edi
    add edi, VESAPITCH ; * 2  ; next pixel line
  loop .nextcharline
ret
  
  
  in60:
    in al, 0x64   ; poll OBF
    test al,1
    jz in60
    ;inc byte [0xb8012] 
    in al, 0x60   ; get scan code
    ret
  

    
ASMFILENAME: db __FILE__, 0 

%include "inc.outhex.asm"  

  

  times (510 + $$ - $) db 0         ; No need for Hy or VB 
  db 0x55, 0xAA                     ; No need for Hy or VB 

  times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
  ; 1.44M  80*2*18*512
  ; 1.2M   80*2*15*512
  ; 720K   40*2*18*512
  ; 360K   40*2*9*512



; VESA structures used for offsets

struc ModeInfoBlock 
  ; Mandatory information for all VBE revisions
  .ModeAttributes resw 1 ; mode attributes
  .WinAAttributes resb 1 ; window A attributes
  .WinBAttributes resb 1 ; window B attributes
  .WinGranularity resw 1 ; window granularity
  .WinSize resw 1 ; window size
  .WinASegment resw 1 ; window A start segment
  .WinBSegment resw 1 ; window B start segment
  .WinFuncPtr resd 1 ; pointer to window function
  .BytesPerScanLine resw 1 ; bytes per scan line
  ; Mandatory information for VBE 1.2 and above
  .XResolution resw 1 ; horizontal resolution in pixels or characters3
  .YResolution resw 1 ; vertical resolution in pixels or characters
  .XCharSize resb 1 ; character cell width in pixels
  .YCharSize resb 1 ; character cell height in pixels
  .NumberOfPlanes resb 1 ; number of memory planes
  .BitsPerPixel resb 1 ; bits per pixel
  .NumberOfBanks resb 1 ; number of banks
  .MemoryModel resb 1 ; memory model type
  .BankSize resb 1 ; bank size in KB
  .NumberOfImagePages resb 1 ; number of images
  .Reserved resb 1 ; reserved for page function
  ; Direct Color fields (required for direct/6 and YUV/7 memory models)
  .RedMaskSize resb 1 ; size of direct color red mask in bits
  .RedFieldPosition resb 1 ; bit position of lsb of red mask
  .GreenMaskSize resb 1 ; size of direct color green mask in bits
  .GreenFieldPosition resb 1 ; bit position of lsb of green mask
  .BlueMaskSize resb 1 ; size of direct color blue mask in bits
  .BlueFieldPosition resb 1 ; bit position of lsb of blue mask
  .RsvdMaskSize resb 1 ; size of direct color reserved mask in bits
  .RsvdFieldPosition resb 1 ; bit position of lsb of reserved mask
  .DirectColorModeInfo resb 1 ; direct color mode attributes
  ; Mandatory information for VBE 2.0 and above
  .PhysBasePtr resd 1 ; physical address for flat memory frame buffer
  .OffScreenMemOffset resd 1 ; pointer to start of off screen memory
  .OffScreenMemSize resw 1 ; amount of off screen memory in 1k units
  ;Reserved db 206 dup (?) ; remainder of ModeInfoBlock
endstruc
