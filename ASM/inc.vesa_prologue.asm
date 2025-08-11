; ******************************************************************************************************
;   
;   A little shorter startup for vesa graphics to save bytes in bootblock. 
;   Meant to be for 32/64-bit code that will follow.
;   The first instructions executed
;   
;   Switches to given VESAMODE 
;
;   Returns with EDI --> to ModeInfoBlock (<64K)
;   and LFB in EBP for more convenience
;
; https://github.com/Halicery/Bootblkbin

ModeInfoBlockAddr EQU 0xb000       ; any addr <64K

org 0x7C00

[BITS 16]
  CLI
  
  PUSH CS  ; zero DS
  POP  DS
  PUSH CS  ; zero SS  
  POP  SS
  MOV  ESP, $$  ; Haswell needed proper stack. Just make sure ESP HI zero. 
  
  ; For VBox on my AMD: set FAST_PASS_A20 (Hy NO NEED but no harm)
  MOV AL, 2
  OUT 0x92, AL

  ; zero ES
  PUSH CS     
  POP ES 

  ; Function 01h - Return VBE Mode Information. 
  ; CX = Mode number
  ; ES:DI = Pointer to ModeInfoBlock structure   
  MOV AX, 4F01h
  MOV EDI, ModeInfoBlockAddr
  MOV CX, VESAMODE 
  INT 10h  
  ; Get and keep LFB Address in EBP (copy before mode switch call)
  MOV EBP, [DI + ModeInfoBlock.PhysBasePtr]
  
  ; "If the VBE function completed successfully, 00h is returned in the AH register"
  ;cmp AH, 0
  ;jnz .ret

  ; Function 02h - Set VBE Mode    
  MOV AX, 4F02h             ; VESA super VGA mode function call
  MOV BX, VESAMODE | 0xc000 ; 0x4000 Use linear/flat frame buffer model. 0x8000 Don't clear display memory.
  INT 10h
 
; OLD METHOD:
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
; Hyper-V VESA MODES
; 20Ah 1152 864 16 
; 122h 1600 1200 16 
%if VESAMODE = 20Ah     
    VESAWIDTH  EQU 1152
    VESAHEIGHT EQU 864
%endif
%if VESAMODE = 122h
    VESAWIDTH  EQU 1600
    VESAHEIGHT EQU 1200
%endif

    
; Struct for offsets:

;struc VbeInfoBlock  
;  .VbeSignature resb 4 ; 'VESA' VBE Signature
;  .VbeVersion resw 1   ; VBE Version
;  .OemStringPtr resd 1 ; Pointer to OEM String
;  .Capabilities resd 1 ; Capabilities of graphics controller
;  .VideoModePtr resd 1 ; Pointer to VideoModeList
;  .TotalMemory resw 1 ; Number of 64kb memory blocks
;   ; Added for VBE 2.0 (don't care, we do not even set VbeSignature to 'VBE2')
;   ;OemSoftwareRev dw ? ; VBE implementation Software revision
;   ;OemVendorNamePtr dd ? ; Pointer to Vendor Name String
;   ;OemProductNamePtr dd ? ; Pointer to Product Name String
;   ;OemProductRevPtr dd ? ; Pointer to Product Revision String
;   ;Reserved db 222 dup (?) ; Reserved for VBE implementation scratch area
;   ;OemData db 256 dup (?) ; Data Area for OEM Strings
;endstruc  


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
	.XResolution resw 1 ; horizontal resolution in pixels or characters
	.YResolution resw 1 ; vertical resolution in pixels or characters
	.XCharSize resb 1 ; character cell width in pixels
	.YCharSize resb 1 ; character cell height in pixels
	.NumberOfPlanes resb 1 ; number of memory planes
	.BitsPerPixel resb 1 ; bits per pixel
	.NumberOfBanks resb 1 ; number of banks
	.MemoryModel resb 1 ; memory model type
	.BankSize resb 1 ; bank size in KB
	.NumberOfImagePages resb 1 ; number of images
	 resb 1 ; reserved for page function
	 
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
	.OffScreenMemOffset resd 1 ; pointer to start of off screen memory <-- VBE3.0 Reserved - always set to 0
	.OffScreenMemSize resw 1 ; amount of off screen memory in 1k units <-- VBE3.0 Reserved - always set to 0
	 resb 206 ;Reserved db 206 dup (?) ; remainder of ModeInfoBlock <-- pad to 256 bytes
	 
	; Mandatory information for VBE 3.0 and above
	.LinBytesPerScanLine resw 1 ; bytes per scan line for linear modes
	.BnkNumberOfImagePages resb 1 ; number of images for banked modes
	.LinNumberOfImagePages resb 1 ; number of images for linear modes
	.LinRedMaskSize resb 1 ; size of direct color red mask (linear modes)
	.LinRedFieldPosition resb 1 ; bit position of lsb of red mask (linear modes)
	.LinGreenMaskSize resb 1 ; size of direct color green mask (linear modes)
	.LinGreenFieldPosition resb 1 ; bit position of lsb of green mask (linear modes)
	.LinBlueMaskSize resb 1 ; size of direct color blue mask (linear modes)
	.LinBlueFieldPosition resb 1 ; bit position of lsb of blue mask (linear modes)
	.LinRsvdMaskSize resb 1 ; size of direct color reserved mask (linear modes)
	.LinRsvdFieldPosition resb 1 ; bit position of lsb of reserved mask (linear modes)
	.MaxPixelClock resd 1  ; maximum pixel clock (in Hz) for graphics mode
	; resb 189; Reserved db 189 dup (?) ; remainder of ModeInfoBlock <-- not 512....
endstruc


;VBE 2.0 Fourth implementation: Added Flat Frame Buffer support in Function 02h (D14)

; and look at the map file
;[map all bootblkbin.map]
