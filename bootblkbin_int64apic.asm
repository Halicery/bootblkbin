;nasm bootblkbin_int64apic.asm -fbin -obin.vfd -lbootblkbin.l
; 
; 64-bit mode interrupts using the APIC Timer
; 
; - 16-byte entries in IDTABLE
; - LIDT loads 64-bit address (10-byte structure)
; - IRET should be prefixed for QWORD pops
;
; Also tests 64-bit direct memory and sign-extension addressing (we shoot high at FEE0_0000 for APIC)
;
;
; Haswell ok (GenuineIntel 000306C3)
; Hy, VBox ok (AuthenticAMD 00810F10)
; Hy  ok (GenuineIntel 000906E9)  Dell Precision i7
; 
; https://github.com/Halicery/Bootblkbin


org 0x7C00            ; suppose 0000:7C00 CS:IP

%include "inc.prologue.asm" 

[BITS 16]

  ; mask 8259 master PIC in case
  mov al, 0xff     ; OCW1 MASTER: mask all 
  out 0x21, al
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;

; we can load this in RM. Shorter code:

  lidt [IDTLOAD64]

%include "inc.go64.asm"       ; 64-bit mode requires paging. PAE with new PML4E 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
VectorNumber equ 51     ; chose one
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Define only one 64-bit interrupt gate in IDTABLE
;
;align 8  
IDTABLE64:                                ; 64-bit Gate-s are 16-byte structures
	dw APICTimerHandler                     ; Target Offset[15:0]
	dw GD_CODE64                            ; Target Selector
	db 0x00                                 ; Reserved, IGN, IST
	db 0x8E                                 ; P DPL 0 Type 
	dw 0                                    ; Target Offset[31:16]
	dd 0                                    ; Target Offset[63:32]
	dd 0                                    ; Reserved, IGN

IDTLOAD64: 
	dw -1                            ; max limit
	dd IDTABLE64 - 16 * VectorNumber ; just shoot N x 16 bytes below with LIDT
;dd 0                             ; we can save a few bytes by loading in RM. How to test if HI zeroed? TODO, but works

  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
[BITS 64]
GO64:

  ;lidt [rel IDTLOAD64]   ; save 1 byte rip-rel
   
  ; test 64-bit QWORD move to screen: 4 chars should be written at once (8 bytes)
  mov rax, 'G_O_6_4_'   
  mov  [rel Z + 0xb8000 + 100], rax  ; Test our absolute-to-relative NASM-trick (to save on byte with RIP-REL)
  
  call get_lapic_base
  
  ; test outhex64 and write 8 bytes rax lapic_base: make sure RDMSR zeroes HI in 64-bit mode
  mov ecx, 8
  push rax   ; qword push
  mov edi, 0xb8000 + 160*8  ; line 8
  mov esi, esp
  call outhex64
  ;call outhex64nz  ; test without leading zeroes
  pop rax  ; lapic_base
  
  ; Test these as absolute:
  ; Load eax, rax HI zero, use rax-base to save byte for 67h, write default dwords
  ; mov eax, 0xFEE00000
  
  mov dword [ rax + 0xF0 ], 0x1FF   ; APIC Software Enable/Disable bit8. Spurious-Interrupt Vector Register (SVR) 000000FF <-- all AP on Hy, NUC (Hy still works! NUC: SHOULD BE ENABLED)
  
  mov dword [ rax + 0x320 ], TMD_Periodic | VectorNumber     ; Timer LVT
  mov dword [ rax + 0x3e0 ], TIMER_DIV128                    ; div=128 slowest
  mov dword [ rax + 0x380 ], 1000 * 8 ;* 1000                ; write initial value

  sti
  
  ;f up descr for fetch-test: yes, fetched each time of interrupt from memory
  ;mov [GDTABLE + GD_CODE64], rax
  
  .loop:   
    ;inc byte [0xb8000]    ; give some life-sign on the screen 
    inc byte [rel Z + 0xb8000 + 3*160]    ; Test our absolute-to-relative NASM-trick (to save on byte with RIP-REL)
    hlt
    jmp .loop
    
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
; TEST disp32 sign-extension and 67h 
; SIB Direct Memory addressing mode
;
;      mov [0xFEE000B0], edx    ; CRASH. Writes to FFFFFFFF_FEE000B0
;  a32 mov [0xFEE000B0], edx    ; WORKS: 67h to prevent sign-extension
;
 
  ; Notes. SS:RSP is unconditionally pushed by hw in 64-bit mode. 
  ; Align stack to 16-byte and pushes 5 qwords. 
  ; SS = 0 from prologue. 64-bit also allows loading null-selector to SS on iret.
  ; SS is don't care for 64-bit mode - kept to legacy and TSS switch (?)
  ; CS pushed and popped during transfer. Must be valid descriptor: cpu fetches from memory each time

[BITS 64]
APICTimerHandler:
  a32 mov dword [0xFEE000B0], 0    ; 67h to prevent sign-extension of disp32. write LAPIC EOI
  iretq
   
  ;; alternatively move 0xFEE000B0 to 32-bit reg (zeros HI) and use [reg64] addressing
  ;mov eax, 0xFEE000B0
  ;mov dword [rax], 0    ; LAPIC EOI
  ;
  ;; alternatively use opcode A0..A3 (the only one) with 64-bit displacement
  ;xor eax, eax
  ;mov [qword 0xFEE000B0], eax    ; LAPIC EOI
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
 
   
%include "inc.apic32.asm" 

%define NEED.64              ; we need 64-versions
%define NEED.outhexnz        ; include this one also
%include "inc.outhex.asm"

ASMFILENAME: db __FILE__, 0 

  
	times (510 + $$ - $) db 0         ; No need for Hy or VB 
	db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
; absolute-to-relative NASM-trick: our paging maps virtual to physical address
;
; inc byte [rel 0xb8000] <-- NASM: absolute address can not be RIP-relative
;
; IT JUST IRRITATED ME THAT NASM CANNOT MAKE RIP-REL FROM AN ABSOLUTE VALUE (I KNOW WHAT I'M CODING)
;
; SIB-DIRECT-MEMORY USES SIB BYTE - WHILE RIP-REL DOES NOT
; THAT IS ONE EXTRA BYTE PER EVERY ABSOLUTE ADDRESS (SHOULD HAVE BEEN OPPOSITE DESIGN IMHO)
;
; NASM needs a symbol for RIP-REL. 
; So make a noprogbits section with start=0 and one symbol. Then use [rel Z + abs]
; NB!!! RIP-REL IS STILL SIGNED 32-BIT, SO WILL NOT WORK FOR EG. LAPIC EIO! WE CANNOT ADDRESS ABOVE 2GB FROM CURRENT CODE LOCATION.
; Or maybe make one page for APIC? FS/GS? Just complicated.

;section .bss start=0                       ; into default nobits bss
section .abs-to-rel-trick nobits start=0    ; or.. make some nobits section. 
Z resd 1

; and look at the map file
[map all bootblkbin.map]
