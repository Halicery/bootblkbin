;nasm bootblkbin_vesainfo.asm -fbin -obin.vfd -lbootblkbin.l
; 

; Use good ol' VESA still supported in many PC box to get a Direct Color mode with linear frame buffer
; My favourite for testing: 16-bpp, some standard like 640x480, 800x600 or 1024x768. 
; So no VBE query here but set mode right away - and hope for the best. 

; My Lenovo E130 4 cores OK (GenuineIntel 000306A9) i3
; My Latitude E4200 2 cores OK (GenuineIntel 0001067A) VESA 0300
; My Haswell 8 cores OK (GenuineIntel 000306C3) VESA 0300
; Hy, VBox on AMD Ryzen VESA 0200

; Tested on Hy and Haswell. Same results

org 0x7C00

%include "inc.vesa_prologue.asm" 

%define TESTFB       ; 1=switch also to mode and fill FB     0=print info only

[BITS 16]

VESABPP EQU 2   ; testing 16-bpp modes here

; good ol' modes
    VESAMODE EQU 111h      ; 111h 640x480 16 600KB
    VESAWIDTH  EQU 640
    VESAHEIGHT EQU 480
    ;_VESAMODE  EQU 117h      ; 117h 1024x768 16 1536KB 
    ;VESAWIDTH  EQU 1024
    ;VESAHEIGHT EQU 768
    ;_VESAMODE  EQU 11Ah      ; 11Ah 1280x1024 16 2560KB (Haswell works)
    ;VESAWIDTH  EQU 1280
    ;VESAHEIGHT EQU 1024
    ;_VESAMODE  EQU 114h      ; 114h 800x600 16 938KB
    ;VESAWIDTH  EQU 800
    ;VESAHEIGHT EQU 600
    
%ifdef TESTFB

    ; With two VESA calls get important parameters:
    ; - LFB address
    ; - total installed video memory (optional)

    ; Function 00h - Return VBE Controller Information
    ; ES:DI = Pointer to VbeInfoBlock structure
    MOV AX, 4F00h
    XOR DI, DI
    INT 10h
    MOV AX, [ES:VbeInfoBlock.TotalMemory]
    MOV [TotalMemory+2], AX    ; in 64K blocks -> in bytes, write HI

    ; To get LFB address (for mode)
    ; Function 01h - Return VBE Mode Information. 256 bytes. 
    ; CX = Mode number
    ; ES:DI = Pointer to ModeInfoBlock structure   
    MOV AX, 4F01h
    XOR DI, DI          ; <-- ES is char screen, put it there
    MOV CX, _VESAMODE 
    INT 10h
    MOV EAX, [ES:ModeInfoBlock.PhysBasePtr]
    MOV [PhysBasePtr], EAX

    ; Function 02h - Set VBE Mode    
    MOV AX, 4F02h             ; VESA super VGA mode function call
    MOV BX,_VESAMODE | 0xc000 ; 0x4000 Use linear/flat frame buffer model. 0x8000 Don't clear display memory.
    INT 10h

%else
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;
  ; Print out some VESA info and for mode
  ;
  
  PUSH ES
  POP DS       ; make vesa put data on screen
  
  ; Function 01h - Return VBE Mode Information. 256 bytes. 
  ; CX = Mode number
  ; ES:DI = Pointer to ModeInfoBlock structure   
  MOV AX, 4f01h
  XOR DI, DI          ; <-- ES is char screen, put it there
  MOV CX, _VESAMODE 
  INT 10h
  
    ; ModeAttributes
    ; bit7: Linear frame buffer mode is available 
    MOV CX, 2  
    XOR SI, SI
    MOV DI, 10*160   ; line 10
    CALL outhex16
    
    
    ;FINIT
    MOV SI, ModeInfoBlock_size
    FILD WORD [ModeInfoBlock.XResolution]  ; DS=0xB000
    FBSTP TWORD [SI]   
    MOV CX, 10 
    MOV DI, 11*160 
    CALL outhex16nz
    
    MOV SI, ModeInfoBlock_size
    FILD WORD [ModeInfoBlock.YResolution]  ; DS=0xB000
    FBSTP TWORD [SI]   
    mov dword [SI], 0
    MOV CX, 4 
    MOV DI, 12*160
    CALL outhex16nz
    
    
    
    
    
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
    
ttt: dw 0

    
    ; YResolution XResolution (eg. 0258_0320 = 600 x 800)
    MOV CX, 4  
    MOV SI, ModeInfoBlock.XResolution     ; 18
    MOV DI, 11*160 
    CALL outhex16
    
    ; BitsPerPixel
    MOV CX, 1  
    MOV SI, ModeInfoBlock.BitsPerPixel
    MOV DI, 12*160  
    CALL outhex16
    
    ; PhysBasePtr = linear 32-bit address
    MOV CX, 4  
    MOV SI, ModeInfoBlock.PhysBasePtr
    MOV DI, 13*160
    CALL outhex16
  
  ; Function 00h - Return VBE Controller Information (256 bytes for VBE 1.x, and 512 bytes for VBE 2.0)
  MOV AX, 4F00h
  XOR DI, DI          ; <-- ES is char screen, put it there (512 bytes: 3.2 lines)
  INT 10h
      
    ; VbeSignature
    MOV DI, 4*160  ; line 4
    XOR SI, SI 
    CALL outs 
    
    ; VbeVersion
    MOV CX, 2  
    MOV SI, VbeInfoBlock.VbeVersion 
    MOV DI, 5*160
    CALL outhex16

    ; TotalMemory
    MOV CX, 2 
    MOV SI, VbeInfoBlock.TotalMemory   ; in 64K blocks
    MOV DI, 6*160
    CALL outhex16     ; EG. 0040 -> 0040_0000 = 4MB

    HLT
%endif


%include "inc.go32.asm"   ;   JMP to GO32
  
[BITS 32]
GO32:
  
  ;call FindPCIDEVCLASS  ; Base Class 03h: Display controller
  ;or al, 0x18    ; shit: works for all Intel Graphics!
  ;call rPCIreg32
  
  ; G.PCIBASE = rPCIreg32(bdf|0x10) & 0xfff00000;
  
  
%ifdef TESTFB

  ; Keep ebp for LFB Address, PhysBasePtr  
  mov ebp, [PhysBasePtr]
  
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
  
  ; draw a line 
  ;mov ax,  0000_0111_1110_0000b           ; color green    5:6:5
  ;mov ax,  0000_0000_0001_1111b           ; color blue     5:6:5
  mov ax, ~0000_0000_0001_1111b           ; color yellow   5:6:5
  ;xor eax, eax                             ; color black
  lea edi, [ebp + (VESAWIDTH*100+50) * VESABPP ]     ; pos 50;100
  mov ecx, ( 400 * VESABPP ) / 4       ; 400 pixel width
  rep stosd
  
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
  
  PhysBasePtr: dd 0 
  TotalMemory: dd 0 
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
