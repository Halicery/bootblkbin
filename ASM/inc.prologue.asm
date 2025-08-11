; ******************************************************************************************************
;   
;   Just a common 16-bit startup: the first instruction executed
;   
;   - disable interrupts
;   - zero segregs DS ES (suppose CS=0)
;   - set up stack right below bootblock
;   - clrscr
;   - write our CPUID info
;   - write current filename in last row (ASMFILENAME should be defined)
;   
;   Calls outhex16 and outs
;   Leaves ES=0xB800 for character screen base
;
; https://github.com/Halicery/Bootblkbin

[BITS 16]
  CLI
  
  ; hide the blinking cursor
  MOV AH, 2
  MOV BH, 0
  MOV DH,-1
  INT 10H
  
  PUSH CS  ; zero DS
  POP  DS
  PUSH CS  ; zero SS  
  POP  SS
  MOV  ESP, $$ ; Haswell needed proper stack. Just make sure ESP HI zero for 32? ($$ beginnig of section. We have only on .text in bin)

  ; fun: put stack at screen
  ;push 0xb800
  ;pop ss
  ;MOV  ESP, 2*(25*80-80)

  ; clrscr
  PUSH 0xB800    ; Set ES to char screen and keep it for all print routines
  POP ES 
  XOR DI, DI     
  MOV AX, 0x0A20 ; light green 
  MOV CX, 25*80  
  CLD            
  REP STOSW
  
  ; For VBox on my AMD: set FAST_PASS_A20 (Hy NO NEED but no harm)
  MOV AL, 2
  OUT 0x92, AL
  
  ; print CPUID 0 ("GenuineIntel")  12 char string in ebx-edx-ecx. Use pusha to write regs into mem. SI is SP+16 then after pushad
  XOR EAX, EAX   ; Returns EAX= Maximum Input Value for Basic CPUID Information: Hy AMD= 0000000D
  CPUID       
  MOV AL, ' '     ; here AH=0 from CPUID. Adds a space and trailing zero
  PUSHAD
  MOV SI, SP  
  ADD SI, 16      ; si: points to ebx
  MOV DI, 1*160   ; line1 col0
  CALL outs       ; returns when AL=0 so EAX=0  
  ;POPAD           ; We dont bother and wasting bytes for restoring the stack, leaving soon
  
  ; print CPUID 1 Family, Stepping.. right after
  INC AX     
  CPUID            ;MOV DI, 160*1 + 15*2     ; di continues
  MOV CX, 4  
  PUSH EAX         ; data 
  MOV SI, SP 
  CALL outhex16  
  
  ;Print Filename to last screen line
  MOV DI, 24*160
  MOV SI, ASMFILENAME
  CALL outs  
  
; and look at the map file
;[map all bootblkbin.map]
