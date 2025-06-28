;nasm bootblkbin_lfb_vesa.asm -fbin -obin.vfd -lbootblkbin.l
; 

; Use good ol' VESA still supported in many PC box to get a Direct Color mode with linear frame buffer
; My favourite for testing: 16-bpp, some standard like 640x480, 800x600 or 1024x768. 
; No space for VBE queries here, error handling, just set mode right away - and hope for the best. 

; My Lenovo E130 4 cores OK (GenuineIntel 000306A9) i3
; My Latitude E4200 2 cores OK (GenuineIntel 0001067A) VESA 0300
; My Haswell 8 cores OK (GenuineIntel 000306C3) VESA 0300
; Hy, VBox on AMD Ryzen VESA 0200

; Tested on Hy and Haswell. Same results

org 0x7C00

; Two versions in one file: 
;   - either switch vesa mode and test FB 
;   - or just print out vesa and mode info (comment out)
;

;    %define TESTFB


VESAMODE EQU 111h      ; 111h 640x480 16 600KB
;VESAMODE EQU 114h      ; 114h 800x600 16 938KB
;VESAMODE EQU 112h      ; 112h 640x480 16.8M (8:8:8)   <-- Hy, D430 reports back 32-bpp
;VESAMODE EQU 117h      ; 117h 1024x768 16 1536KB 
;VESAMODE EQU 118h      ; 118h 1024x768 16.8M (8:8:8)  <-- Hy, D430 reports back 32-bpp
;VESAMODE EQU 11Ah      ; 11Ah 1280x1024 64K (5:6:5)   16 2560KB (Haswell works)
;VESAMODE EQU 11Bh      ; 11Bh 1280x1024 32        (Haswell ok)
;VESAMODE EQU 110h      ; 110h 640x480 15
 
; Old D430 with the same panel does NOT support this 
; E4200 laptop with 1280x800 panel. No other recognises this mode. 
;VESAMODE  EQU 162h      ; 161h 1280x800 16 <-- works on my E4200 laptop! Wiki mentions 160h for 8-bit.. so I tried 161h.
;VESAWIDTH  EQU 1280     ; 162h 1280x800 32-bpp!!! cool
;VESAHEIGHT EQU 800      ; 
 
%if VESAMODE = 11Ah || VESAMODE = 11Bh || VESAMODE = 119h
    VESAWIDTH  EQU 1280
    VESAHEIGHT EQU 1024
%endif
%if VESAMODE = 111h || VESAMODE = 110h || VESAMODE = 112h
    VESAWIDTH  EQU 640
    VESAHEIGHT EQU 480
%endif
%if VESAMODE =  114h
    VESAWIDTH  EQU 800
    VESAHEIGHT EQU 600
%endif
%if VESAMODE = 117h || VESAMODE = 118h
    VESAWIDTH  EQU 1024
    VESAHEIGHT EQU 768
%endif

VESABPP EQU 2   ; testing 16-bpp modes
   
    

%include "inc.prologue.asm" 

%ifndef TESTFB

%define NEED.dumphex  
%define NEED.outhexnz
                     
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;
  ; Print out some VESA info and for the mode
  ;
  
  PUSH ES
  POP DS       ; make vesa put data on screen
  
  ; Function 00h - Return VBE Controller Information (256 bytes for VBE 1.x, and 512 bytes for VBE 2.0 <-- 'VBE2' not set so we get 256)
  MOV AX, 4F00h
  XOR DI, DI      ; <-- ES is char screen, put it there (512 bytes: 3.2 lines)
  INT 10h
  
    ; VbeSignature
    XCHG SI,DI
    MOV DI, 4*160  ; line 4
    CALL outs 
    
    ; VbeVersion
    MOV CX, 2  
    MOV SI, VbeInfoBlock.VbeVersion
    MOV DI, 5*160
    CALL outhex16

    ; TotalMemory
    MOV SI, VbeInfoBlock.TotalMemory
    MOV CL, 2 
    MOV DI, 6*160
    CALL outhex16     ; EG. 0040 -> 0040_0000 = 4MB
      
  
  ; Function 01h - Return VBE Mode Information. 256 bytes. 
  ; CX = Mode number
  ; ES:DI = Pointer to ModeInfoBlock structure   
  MOV AX, 4f01h
  XOR DI, DI          ; <-- ES is char screen, put it there
  MOV CX, VESAMODE 
  INT 10h
  
    ; VESAMODE
    MOV CX, 2  
    MOV SI, ModeInfoBlock_size             ; after struct
    MOV WORD [SI], VESAMODE
    MOV DI, 9*160   ; line 10
    CALL outhex16  
    
    ; XResolution, YResolution, BitsPerPixel: CONVERT TO DECIMAL
    ;FINIT ?
    MOV SI, ModeInfoBlock_size             ; after struct
    FILD WORD [ModeInfoBlock.XResolution]  ; DS=0xB000
    FBSTP TWORD [SI]                       ; TWORD=TBYTE an NASM thing
    MOV DI, 10*160 
    MOV CX, 9  ; 9 bytes, not sign byte
    CALL outhex16nz
    
    MOV SI, ModeInfoBlock_size             ; after struct
    FILD WORD [ModeInfoBlock.YResolution]  ; DS=0xB000
    FBSTP TWORD [SI]
    MOV DI, 11*160 
    MOV CX, 9  
    CALL outhex16nz
    
    ; BitsPerPixel
    MOV SI, ModeInfoBlock_size             ; after struct
    ; zero test
       mov word [Si], 0  ; destroy this make it word to load
    ;mov byte [ModeInfoBlock.NumberOfBanks], 0  ; destroy this make it word to load
    ;FILD WORD [ModeInfoBlock.BitsPerPixel]
    ;FBSTP TWORD [SI]
    MOV DI, 12*160  
    MOV CX, 9  
    CALL outhex16nz 
    
    ; ModeAttributes
    ; bit7: Linear frame buffer mode is available should be set 
    MOV CX, 2  
    MOV SI, ModeInfoBlock.ModeAttributes
    MOV DI, 13*160   ; line 10
    CALL outhex16  
    
    ; RGB masks
    MOV CX, 6 
    MOV SI, .RedMaskSize
    MOV DI, 14*160   ; line 10
    CALL dumphex16  
    
    ; PhysBasePtr = linear 32-bit address
    MOV CX, 4  
    MOV SI, ModeInfoBlock.PhysBasePtr
    MOV DI, 15*160
    CALL outhex16
    
    
  PUSH CS  ; zero DS
  POP  DS
    
%include "inc.go32.asm"   
[BITS 32]
GO32:

    ; TEST 32nz
    ; XResolution, YResolution, BitsPerPixel: CONVERT TO DECIMAL
    ;FINIT ?
    ;MOV ESI, 0xb8000 + ModeInfoBlock_size             ; after struct
    ;FILD WORD [0xb8000 + ModeInfoBlock.XResolution]  ; DS=0xB000
    ;FBSTP TWORD [ESI]
    ;MOV EDI, 0xb8000 + 10*160 
    ;MOV ECX, 9  ; 9 bytes, not sign byte
    ;CALL outhex32nz
    
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
    ;in al, 0x60   ; get scan code
    ret    

%else

;*****************************************************
;
;   switch vesa mode and test FB 
    
    [BITS 16]
    ; With two VESA calls get important parameters:
    ; - LFB address
    ; - total installed video memory (optional)

    ; Function 00h - Return VBE Controller Information
    ; ES:DI = Pointer to VbeInfoBlock structure
    ;MOV AX, 4F00h
    ;XOR DI, DI
    ;INT 10h
    ;MOV AX, [ES:VbeInfoBlock.TotalMemory]
    ;MOV [TotalMemory+2], AX    ; in 64K blocks -> in bytes, write HI

    ; To get LFB address (for mode)
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

          
  %include "inc.go32.asm"
  
  [BITS 32]
  GO32: 
      ;call FindPCIDEVCLASS  ; Base Class 03h: Display controller
      ;or al, 0x18    ; shit: works for all Intel Graphics!
      ;call rPCIreg32      
      
      ; Fill pixel screen
      cld            
      mov edi, ebp
      mov ecx, ( ( VESAWIDTH * VESAHEIGHT - 4 ) * VESABPP ) / 4   ; fill 4 pixels less with DWORDS
      or eax, -1
      stosd                 ; first 2 pixels white
      mov eax, 0xaaaaaaaa   ; fill some test color
      rep stosd
      or eax, -1            ; last 2 pixels white
      stosd
      
      ; draw a yellow line across the screen 
      ;xor eax, eax                               ; color black
      ;mov ax,  0000_0111_1110_0000b              ; color green    5:6:5
      ;mov ax,  0000_0000_0001_1111b              ; color blue     5:6:5
      mov ax, ~0000_0000_0001_1111b               ; color yellow   5:6:5
      lea edi, [ebp + (VESAWIDTH*50) * VESABPP ]  ; vertical pos 50
      mov ecx, ( VESAWIDTH * VESABPP ) / 2        ; width
      rep stosw
      
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

%endif
   
  
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

struc VbeInfoBlock  
	.VbeSignature resb 4 ; 'VESA' VBE Signature
	.VbeVersion resw 1   ; VBE Version
	.OemStringPtr resd 1 ; Pointer to OEM String
	.Capabilities resd 1 ; Capabilities of graphics controller
	.VideoModePtr resd 1 ; Pointer to VideoModeList
	.TotalMemory resw 1 ; Number of 64kb memory blocks
	 ; Added for VBE 2.0 (don't care, we do not even set VbeSignature to 'VBE2')
	 ;OemSoftwareRev dw ? ; VBE implementation Software revision
	 ;OemVendorNamePtr dd ? ; Pointer to Vendor Name String
	 ;OemProductNamePtr dd ? ; Pointer to Product Name String
	 ;OemProductRevPtr dd ? ; Pointer to Product Revision String
	 ;Reserved db 222 dup (?) ; Reserved for VBE implementation scratch area
	 ;OemData db 256 dup (?) ; Data Area for OEM Strings
endstruc  

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
