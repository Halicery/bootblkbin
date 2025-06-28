; ******************************************************************************************************
;   
;   A little shorter startup for vesa graphics mode to save bytes in bootblock. 
;   
;   - switches to given VESAMODE
;   - EBP <- LFB address 
;   
;
; https://github.com/Halicery/Bootblkbin

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

  ; VESA
  PUSH 0xB800    ; Use screen for vesa calls - and leave it 
  POP ES 

  ; Get LFB address (for mode)
  ; Function 01h - Return VBE Mode Information. 256 bytes. 
  ; CX = Mode number
  ; ES:DI = Pointer to ModeInfoBlock structure   
  MOV AX, 4F01h
  XOR DI, DI          ; <-- ES is char screen, put it there
  MOV CX, VESAMODE 
  INT 10h
  ; Keep EBP for LFB Address, PhysBasePtr  
  MOV EBP, [ES:ModeInfoBlock.PhysBasePtr]

  ; Function 02h - Set VBE Mode    
  MOV AX, 4F02h             ; VESA super VGA mode function call
  MOV BX, VESAMODE | 0xc000 ; 0x4000 Use linear/flat frame buffer model. 0x8000 Don't clear display memory.
  INT 10h
  

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
    
; Struct for offsets:
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
