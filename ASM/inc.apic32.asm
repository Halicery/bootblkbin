; APIC constants and some routines
; 
; https://github.com/Halicery/Bootblkbin


[BITS 64] 
; same opcodes work also for 64-bit:
; Read MSR specified by ECX into EDX:EAX.
; "On processors that support the Intel 64 architecture, the high-order 32 bits of each of RAX and RDX are cleared."

[BITS 32] 

get_lapic_base:
  push 0x1B
  pop ecx
  RDMSR
  and ax, 0xF000   ; save one byte
  ret
  
get_apic_id:
  call get_lapic_base
  mov eax, [eax + 0x20] ; in 64-bit mode these opcodes mean mov eax, [rax + 0x20]. RDMSR zeroed rax HI, ok
  shr eax, 24           ; eax= 8-bit apicid
  ret

  
  
; Local Vector Table (LVT)


; LVT Timer Register

; Timer Mode
TMD_OneShot    equ 0<<17
TMD_Periodic   equ 1<<17
TMD_TSC        equ 2<<17

TIMER_DIV2     equ 0_0_00b
TIMER_DIV4     equ 0_0_01b
TIMER_DIV8     equ 0_0_10b
TIMER_DIV16    equ 0_0_11b
TIMER_DIV32    equ 1_0_00b
TIMER_DIV64    equ 1_0_01b
TIMER_DIV128   equ 1_0_10b
TIMER_DIV1     equ 1_0_11b

; Interrupt Command Register (ICR)
; ISSUING INTERPROCESSOR INTERRUPTS
; 300H Interrupt Command Register (ICR); bits 0-31 Read/Write.
; 310H Interrupt Command Register (ICR); bits 32-63 Read/Write.

ICR_DeliveryStatus    equ 1<<12      ;  0: Idle 1: Send Pending

;Delivery Mode (Message Types)
MT_FixedVector        equ 0<<8
MT_LowestPri          equ 1<<8
MT_SMI                equ 2<<8
MT_RemoteRead         equ 3<<8
MT_NMI                equ 4<<8
MT_INIT               equ 5<<8
MT_STARTUP            equ 6<<8
MT_ExternalInt        equ 7<<8

; Destination Shorthand
DSH_Dest                 equ 0<<18    ; The destination is specified in the destination field (310H bits 31..24)
DSH_Self                 equ 1<<18
DSH_AllincludingSelf     equ 2<<18
DSH_AllexcludingSelf     equ 3<<18

; Destination Mode
DST_PhysicalDestination  equ 0<<11
DST_LogicalDestination   equ 1<<11

; Trigger Mode
TGM_EDGE                 equ 0<<15
;TGM_LEVEL equ 1<<15   
TGM_LEVEL_ASSERT         equ 3<<14
TGM_LEVEL_DEASSERT       equ 2<<14









