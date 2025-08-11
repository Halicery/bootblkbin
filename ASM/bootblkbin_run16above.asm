;nasm bootblkbin_run16above.asm -fbin -obin.vfd -lbootblkbin.l
;
;  
;  Run 16-bit code way above 1MB
;  Needs 16-bit extended limit code segment for code fetch
;  Tests far call, far ret, call at high address etc.
;  We do not change data segments (except extend ES limit to write to 28MB)
;  First call up to 28MB from 16-bit code, write signatures, then from 32-bit code. 
;
;  Hy, VBox on AMD ok. 
;  Haswell ok.
;
; https://github.com/Halicery/Bootblkbin

; I was wondering how to execute D=0 16-bit code way above 1MB high in memory. CPU always uses full EIP for code fetch so this should work. CS segment limit should be extended first. Because of 8086-emulation, every jump, call, ret should use 32-bit operand size to work (otherwise EIP HI zeroed). Interestingly, CPU even honors the 66h prefix for short jump and works correctly in high memory. 

HITARGET16 equ 28 * 1024 * 1024  ; 16-bit code will run up 28MB


%include "inc.prologue.asm"
 
[BITS 16]
 
  LGDT [GDTABLELOAD]   ; 16-bit LGDT instr: GDTR upper byte zeroed (here ok we are under 16M)
  MOV ECX, CR0         
  INC CX               ; Set PE
  MOV CR0, ECX
  
  ; 4GB ES limit for movs (cannot write code-seg)
  ; BASE=0xB8000 from prologue, leave it for 16-bit code to write to screen
  PUSH GD_ES
  POP  ES
  
  ; copy 16-bit code up to 28MB
  CLD
  MOV EDI, HITARGET16 - 0xB8000
  MOV ESI, TARGET16
  MOV ECX, ENDTARGET16 - TARGET16  
  A32 REP MOVSB                     ; Need address-size=32
  
  ;JMP GD_CODE16:GO16   ; load CS descriptor
  JMP GD_CODE16:GO16_PE0   ; another test with PE=0
  ;JMP GD_CODE32:GO32   ; load CS descriptor
  
 
; ==================================================================================================================
[BITS 16]
GO16:
; From 16-bit code and test near/far call transfer to 28MB
  
  MOV DI, 5*160      ; line 4

  CALL GD_CODE16:DWORD HITARGET16   ; FAR CALL. Need operand-size=32 for full EIP. Make sure returns with 32-bit far ret
  ;CALL DWORD HITARGET16            ; NEAR CALL. Need operand-size=32 for full EIP. Make sure returns with 32-bit near ret

  ; on successful return print 16
  ES MOV DWORD [160*7], '1!6!'         ; 16-bit "colors"
  
  ; Transfer to 32-bit code
  JMP GD_CODE32:GO32   ; load CS descriptor

; ==================================================================================================================
[BITS 16]
GO16_PE0:

  ; Test with PE=0
  MOV ECX, CR0         
  DEC CX               ; Clear PE
  MOV CR0, ECX
  JMP 0:.FIXCS         ; set CS=0 again
  .FIXCS:
  
  MOV DI, 5*160      ; line 4

  CALL 0:DWORD HITARGET16   ; 8086-style FAR CALL. Need operand-size=32 for full EIP. Make sure returns with 32-bit far ret

  ; on successful return print 16
  ES MOV DWORD [160*7], '1!6!'         ; 16-bit "colors"
  
  ; Transfer to 32-bit code
  MOV ECX, CR0         
  INC CX               ; Set PE
  MOV CR0, ECX
  JMP GD_CODE32:GO32   ; load CS descriptor

  NOP 
; ==================================================================================================================
[BITS 32]
GO32: 
; From 32-bit code and test 
; - far call transfer to 28MB
; - indirect far call transfer to 28MB

  mov esp, 0x9001   ; Test. NO problem with un-aligned stack

  ; copy 16-bit code up to 28MB
  cld
  mov edi, HITARGET16 - 0xB8000
  mov esi, TARGET16
  mov ecx, ENDTARGET16 - TARGET16
  rep movsb
  
  mov di, 11*160      ; line 9
  
  ; Different jumps into 16-bit target 
  ;call far dword [DPTR_TARGET16]   ; PE=1 direct control transfer
  call GC_HITARGET16: word -1    ; gate  (The offset from the target operand is ignored when a call gate is used.)
  ;call GD_CODE16:HITARGET16      ; operand-size=32: dword push and full EIP replace
  
  ; on successful return print 32
  es mov dword [160*13], '3/2/'    ; my signature
  
  hlt  
  
  ;    waitkey:
  ;    in60:
  ;      in al, 0x64   ; poll OBF
  ;      test al,1
  ;      jz in60
  ;    
  ;    ; RESET
  ;    MOV AL, 1
  ;    OUT 0x92, AL
     
  

DPTR_TARGET16: 
  dd HITARGET16
  dw GD_CODE16
  
  
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; THAT also means 16-bit code can run over 1MB
; If not using 16-bit jumps/calls/ret 
;
; Code copied up to 28MB:
     
align 4
  
[BITS 16]
TARGET16: 
  ; NB. PE=1 so do not change any SEGREG
  ; DS=0 and ES=B800 from prologue        
  ; LIMIT not extended AND IS CHECKED DURING EXECUTION (TESTED) 
  
  MOV EAX, '1!6!'    ; my signature with 16-bit "colors"
  
  ;JMP WORD .ide   ; CRASH: EIP = 0000_xxxx
  ;JMP SHORT .ide  ; CRASH: EIP = 0000_xxxx
  O32 JMP SHORT .ide  ; 66 EB 00: OK. EIP = xxxx_xxxx (operand-size=32)
  ;MOV EDX, HITARGET16 + (.ide - TARGET16)  ; OK. 66h EDX replaces EIP
  ;JMP EDX                                  ; OK. 66h EDX replaces EIP
  .ide:
  
  ; print my signature
  ES MOV DWORD [DI], EAX   ; my signature
  
  ; relative near call to other 16-bit code, need 32-bit for dword push return address and full EIP
  CALL DWORD HISUB16
  
  RETFD   ; 32-bit far ret
  RETD    ; 32-bit near ret
  
HISUB16: 
  
  ES MOV DWORD [DI + 8], EAX    ; my signature
  RETD
  ; we can return but need 32-bit: to pop 32-bit return address
                                     
ENDTARGET16: 
  
;===========================================================================================  
;align 8 ; just waste bytes, no peformance issue here, cpu happy anyway

GDTABLE   equ $ - 8       ; We do not allocate space for the GDT null-selector. Save space

GD_CODE32 equ $ - GDTABLE
  dw -1          ;   limit
  dd 0x9A000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  db 1100_1111b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=1
  db 0  

GD_ES equ $ - GDTABLE
  dw -1          ;   limit
  dd 0x920B8000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  db 1000_1111b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  
  db 0           ;   base HI
  
GC_HITARGET16 equ $ - GDTABLE    ; GC = global call gate

  dw HITARGET16 & 0xFFFF                  ; Target Offset[15:0]
  dw GD_CODE16                            ; Target Selector
  db 0x00                                 ; dword count
  db 1000_1100b                           ; P DPL 0 Type 
  dw HITARGET16 >> 16                     ; Target Offset[31:16]

; 4GB limit: EIP checked against on code fetch
GD_CODE16 equ $ - GDTABLE
  dw -1          ;   limit
  dd 0x9A000000  ;   | P |  DPL  |S=1| X |C/E|R/W| A |  base 23..0
  db 1000_1111b  ;   | G |D/B| 0 | V | LIMIT 19..16  |  D=0
  db 0           ;   base HI
  
GDTABLELOAD EQU $
  dw -1                 ; just max limit
  dw GDTABLE            ; 24-BIT linear address of GDT table 
  db 0                  ; HI <64K
  
  
  
  
  
  
  
  
  
  
  
  
%include "inc.outhex.asm"

ASMFILENAME: db __FILE__, 0 

times (510 + $$ - $) db 0         ; No need for Hy or VB 
db 0x55, 0xAA                     ; No need for Hy or VB 

	times (40*2*9*512 - $ + $$) db 0  ; Hy needs proper disk size here (invalid) VBox is happy with 512 bytes virtual floppy
	; 1.44M  80*2*18*512
	; 1.2M   80*2*15*512
	; 720K   40*2*18*512
	; 360K   40*2*9*512
