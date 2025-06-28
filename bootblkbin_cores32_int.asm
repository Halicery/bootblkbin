;nasm bootblkbin_cores32_int.asm -fbin -obin.vfd -lbootblkbin.l

; Wake up other cores (AP-s). Switch APs to 32-bit, PE=1, LIDT and test the APIC Timer interrupt on each core. 
;
; This is a 3 sector boot file so the 3rd sector, AP boot code ends up at 8000 (4K aligned address: no need to copy)
; Floppy boot uses BIOS (VM-s). PXE loads the whole file anyway and just bails out on the BIOS call (no floppy in my real pc-s). 


; My Lenovo E130 4 cores OK (GenuineIntel 000306A9) i3
; My Latitude E4200 2 cores OK (GenuineIntel 0001067A)
; My Haswell 8 cores OK (GenuineIntel 000306C3)
; Hy, VBox on AMD Ryzen ok

;  
;  BSP:
;  1. switch to p-mode 32-bit 4GB linear
;  2. wake up AP cores: send INIT and STARTUP APIC message
;  3. HLT 
;  4. or HLT and loop: on keypress write TSC
;
;  AP-s:
;  1. Start execute in Real mode: CS=VV00 (Hy/VBox) IP=0..
;  2. increment core count on screen
;  3. switch to p-mode 32-bit (PE=1 we use IDT interrupts)
;  4. write some diag stuff
;  5. set up Local APIC Timer interrupt, which just issues EIO then IRET
;  6. LIDT
;  7. main loop: HLT and write APIC Timer
;
; https://github.com/Halicery/Bootblkbin


APSTARTADDR equ 0x8000    ; any 4K addr below 1M as 000VV000H --> CS=VV00 IP=0 (Hy). We need scalar value not symbol. 

org 0x7C00    ; bin (Hy/VBox: CS=0 -> IP=7C00)

[BITS 16]
     
  ; Load 2 more sectors with BIOS   
  CLD   
  MOV AX, 0x0202   ; AH: int13h function 2    AL: number of sectors to read (1-128 dec.) 
  MOV CX, 0x0002   ; CH: from cylinder number 0   CL: the sector number 2 - second sector (starts from 1, not 0)
  MOV DH, 0        ; head number 0
  PUSH CS    
  POP ES           ; es should be 0
  MOV BX, 7E00h    ; address
  INT 13h
  
  
%include "inc.prologue.asm"  
  
  ; mask 8259 master PIC in case
  mov al, 0xff     ; OCW1 MASTER: mask all 
  out 0x21, al

  ; No need for PXE
  ;jmp short start    ; floppy: HyV not needed, VBox not needed Standard start of boot sector
  ;times 0x3c nop     ; floppy: HyV not needed, VBbox not needed
  ; CS -> DS (DS can be anything, 9FC0 on Hy) xlat uses DS
  ;push cs
  ;pop ds
  
  ; kicks in 32-bit mode (called by APs too) - so we do not use push (little longer)
  ; make sure DS=0
    
Kick32:

  MOV EAX, CR0        ; set PE=1
  INC AX
  MOV CR0, EAX  
  LGDT [GDTABLELOAD]  ; make sure DS=0. 16-bit LGDT: GDTR upper 8-bits zeroed (here it works, we are below 16M)
  PUSH GD_DATA32      ; set DS/ES data- and stack segment SS to 4GB linear
  POP DS              ; one-byte opcodes
  PUSH DS
  POP ES
  PUSH DS
  POP SS
  JMP GD_CODE32:BSP32   ; param to call Kick32 by APs
  
FARP32 equ $ - 4      ; writing here is nasty but we save codebytes
  
GDTABLELOAD:   
  dw -1
  dd GDTABLE
    
GDTABLE EQU $ - 8
  GD_CODE32  EQU $-GDTABLE
  dq 0x00CF9A000000FFFF 
  GD_DATA32  EQU $-GDTABLE
  dq 0x00CF92000000FFFF
    
;JMP FAR [FARP32]   ; absolute jump: CS:IP replaced (upper EIP zeroed: here ok)  
;FARP32:
;DW BSP32, CODE32  ; param to call Kick32 by APs
;ASMFILEW: dw __utf16__("")


ASMFILENAME: db __FILE__, 0 

%include "inc.outhex.asm"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  BSP 32-bit code
;
;  Wakes up all APs
;  waits for key press.. restart 

[BITS 32]
BSP32:
  
  ; PREPARE far jmp for AP Kick32
  mov word [FARP32], AP32

  mov byte [0xb8002], '1'  ; core count = 1
  
  call get_lapic_base    ; eax = lapic_base
  
  ; Wake up AP-s: write ICR Register 0x300
  mov dword [eax + 0x300], TGM_LEVEL_ASSERT | DSH_AllexcludingSelf | MT_INIT                 ; INIT: Hy needs level (assert or deassert both works). VBox, NUC: no need, edge!
  mov dword [eax + 0x300], DSH_AllexcludingSelf | MT_STARTUP | (APSTARTADDR>>12)  ; STARTUP  ....VV (addr 000VV000H 1MB) 
  
  ; ---- Here all APs start executing concurrently ----
  ;
  ; we just halt in CLI
  ;hlt

  ; print BSP APIC ID   
  call get_apic_id      ; -> EAX is 8-bit APICID
  mov ecx, 1            ; 4 byte
  mov edi, 0xb8000 + 2*160
  push eax
  mov esi, esp        ; data
  call outhex32

  hlt  

  ; write TSC and wait key
  .wtsc:
  push 0           ; col
  push 2           ; row 
  call printtsc    ; ret 8: cleans passed parameters
  call in60 
  jmp .wtsc
  
  times (512 + $$ - $) db 0         ; pad first sector
  
  ;times (510 + $$ - $) db 0         ; No need for Hy or VB 
  ;db 0x55, 0xAA                     ; No need for Hy or VB 


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; SECTOR 2 at 7e00
;
; Put some routines here
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

USE32      ; synonym
[BITS 32]

%include "inc.apic32.asm" 


  
  xytopos:     ; row,col --> edi
  mov edi, [esp+4]
  imul edi, 80
  add edi, [esp+8]
  lea edi, [0xb8000 + edi*2]
  ret 8
  
  Hexr:       ;  push data, push cx, line, pos  ( ECX=bytes. BH=line BL=pos)
  push ebp
  mov ebp,esp
  lea esi, [ebp+8]   ; store as param on stack so re-entrant by caller
  mov ecx, [ebp+12]
  push dword [ebp+20]
  push dword [ebp+16]
  call xytopos
  call outhex32
  pop ebp
  ret 16
  
  printtsc:     ; row, col
    push ebp
    mov  ebp, esp
    push dword [ebp+12]
    push dword [ebp+8]
    call xytopos
    push 8          ; write 8 bytes
    pop ecx
    RDTSC           ; Read time-stamp counter into EDX:EAX
    push edx
    push eax
    mov  esi, esp
    call outhex32
    pop ebp
    pop ebp
    pop ebp
    ret 8           ; = pop esp, then add N
  
  in60:
    in al, 0x64   ; poll OBF
    test al,1
    jz in60
    ;inc byte [0xb8012] 
    in al, 0x60   ; get scan code
    ret
    


  ;DD $,$$
  ; "$ evaluates to the assembly position" <-- RELOCATABLE VALUE
  ; "$$ evaluates to the beginning of the current section" <-- RELOCATABLE VALUE
  ; "so you can tell how far into the section you are by using ($-$$)"
  ; JMP $ <-- INFINITE LOOP
  
  ;RESB 512*2 + $$ - $
  times (512*2 + $$ - $) db 0         ; No need for Hy or VB 
  ;times 512*2 db 0         ; No need for Hy or VB 








;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; SECTOR 3 at 8000       16-bit AP boot code
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ; Now this is a really fresh cpu start!
  
  ; All seg cache has default values similar to RESET. 
  ; 
  ; At 1M Physical address VV000 
  ; we assume nothing about SREGS
  ; Hy:
  ; CS=VV00 -> IP=0
  ; SS=0
  ; DS=0
  ; sp=0 (probably esp=0)
  ; flags= 0002
  ;
  ; The challenge is that every core start executing concurrently!

[BITS 16]

  ; set up different stack for each AP
  mov  ax, -0x200         ; 512 mini stacks  ; amount to add
  lock xadd [APSP], ax    ; atomically add, return previous value
  mov  sp, ax  
  
  ; increase core count on screen
  ; do not use stack yet
  ;mov ax, 0xb800
  ;mov es, ax
    
  push 0xb800
  pop es
  nop
  lock inc byte [es:2]  ; core count (<-- why is this on VBox unstable? 3 or 4.. write order? lock prefix should work)
  nop
  nop
  
  jmp 0:Kick32
  
;align 4
  APSP:    DW 0x7000    ; mini 512 byte stacks for AP-s: from 7000, 6e00, 6d00.. downward
  ;APSP:    DD 19*1024*1024   ; 20M test

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   
; 32-bit AP boot code continue
;
;


[BITS 32]

  AP32: 
  
  ; for each AP we write stuff at different row. 
  ; this comes from APICID (01, 02 ... normally)
  ; 
  ; store some vars on local stacks:
  ; pull stack... EBP is base
  
  enter 8, 0
  
; EBP           <-- push EBP
; ----    -4    apic_id
; ----    -8    row memory address   <-- ESP
  
  call get_apic_id      ; -> EAX is 8-bit APICID
  
  mov [ebp-4], eax   ; store apic_id (01, 02 ... normally)
  imul eax, 160*2  
  add eax, 0xb8000 + 5*160  ; start row
  mov [ebp-8], eax          ; store screen row memory address 
    
  ; print apic_id
  mov ecx, 1          ; one byte
  lea esi, [ebp-4]    ; data
  mov edi, [ebp-8]    ; row memory address
  call outhex32
  
  ; print my stack frame pointer
  mov ecx, 4          ; 4 byte
  mov edi, [ebp-8]    ; row memory address
  lea edi, [edi + 3*2]  ; col 3
  push ebp    
  mov esi, esp        ; data
  call outhex32
  pop eax
  
  ;hlt
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; 
  ; Set up one handler for APICTimer
  
  APICTimerVectorNumber equ 51          ; chose one
  
  call get_lapic_base
  mov dword [ eax + 0xF0 ], 0x1FF   ; APIC Software Enable/Disable bit8. Spurious-Interrupt Vector Register (SVR) 000000FF <-- all AP on Hy, NUC (Hy still works! NUC: SHOULD BE ENABLED)
  
  mov dword [ eax + 0x320 ], 1<<17 | APICTimerVectorNumber     ; Timer LVT
  mov dword [ eax + 0x3e0 ], 0xa                               ; div=128 slowest
  mov edx, [ebp-4]                 ; different count based on apic_id: 01 is fastest etc.
  shl edx, 4                       ; 8 really slow on Hy
  imul edx, 1000
  mov dword [ eax + 0x380 ], edx   ; write initial value
  
  ; Enable interrupts and loop..
  lidt [IDTLOAD]
  sti
  
  .loop: hlt
  
    ; print Apic Timer: we can also see the latency changing..
    call get_lapic_base
    push dword [ eax + 0x390 ]   ; APIC Timer Current Count
    mov ecx, 4          ; 4 byte
    mov edi, [ebp-8]    ; screen row memory address
    lea edi, [edi + 13*2]  ; col 13
    mov esi, esp        ; data
    call outhex32
    pop eax
    jmp .loop

    
  
; Interrupt handler: issue APIC EOI and iret
;
APICTimerHandler:
  pusha
  xor edx, edx
  call get_lapic_base
  mov al, 0xB0          ; save some bytes
  mov dword [eax], edx  ; write LAPIC EOI
  popa
  iret

; Define only one interrupt gate in the IDTABLE:

;align 8  do not waste bytes now

IDTABLE:                   ; 8-byte structures
  dw APICTimerHandler      ; Target Offset[15:0]  <-- this works assembly-time
  dw GD_CODE32             ; Target Selector
  db 0x00                  ; Reserved
  db 0x8E                  ; P DPL S=0 | Type 
  dw 0                     ; Target Offset[31:16] <-- we are < 64K
  
  ;dw (APICTimerHandler - $$ + 0x7c00) >> 16        ; Target Offset[31:16] <-- NB: must be scalar for assembly-time

IDTLOAD: 
  dw -1
  dd IDTABLE - 8 * APICTimerVectorNumber     ; shoot N x 8 bytes below with LIDT


  times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
  ; 1.44M  80*2*18*512
  ; 1.2M   80*2*15*512
  ; 720K   40*2*18*512
  ; 360K   40*2*9*512
  
