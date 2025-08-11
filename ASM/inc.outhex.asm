; ******************************************************************************************************
; outhex16/32
; 
;   The first thing is to write hex values on the character screen in bootblock. 
;   To save code space, it would be nice to have routines that work for both 16/32 calls. 
;   DECIMAL instructions comes handy here and code is also shorter. Re-entrant - can be used by AP cores concurrently.
;   Principle: write from mem (SI) and not from reg, so we can write as many bytes (CX) as needed. 
;   
; outs
;
;   Another first thing is to write strings. So outs is also here and can be called from both 16/32-code.
;   
; >>> This file grew a little from a simple outhex of fix length n bytes. Also for 64-bit code. 
;   
; outhex16/32/64
;
;   The 16/32/64-bit HEX WRITER VERSION for 64-bit code tests. No BCD instructions here. 
;   Just %define NEED.64 to switch to include. 
;
; dumphex16/32/64
;   
;   For memory dump i.e. the big-endian VERSION of outhex. 
;   Just %define NEED.dumphex to include. This is for keeping bootblock small if not required. 
;   
; outhexnz16/32/64
;   
;   Same but writes values without leading zeroes. I made this to write decimal TBYTE numbers out. 
;   Just %define NEED.outhexnz to include. This is for keeping bootblock small if not required. 
;   
; https://github.com/Halicery/Bootblkbin


%ifndef NEED.64
; ======================================================================================================
; 16/32-bit HEX WRITER without branch (for fun) or lookup-table (save space) using DECIMAL instructions (prints A-F only)
; Prints N bytes little-endian hex, onto character screen from memory pointed by SI. 

; 16-BIT ENTRY POINT
; SI: source mem address
; CX: n of bytes
; DI: screen position
; ES: SHOULD BE 0xB800
; clobbers: AX, DX, changes SI, DI, exits with CX=0
[BITS 16]
outhex16:
    MOV DX, .hexdigit
    .outhex:           ; written using the same 16/32 opcodes
    DEC SI         
    ADD SI, CX     ; last byte
    .nextbyte:    
        STD
        LODSB
        CLD               ; AH AL       AH AL
        AAM 16            ; .. ab  -->  0a 0b (The SF, ZF, and PF flags are set according to the resulting binary value in the AL register.)
        CALL DX                                        
        CALL DX                                        
        LOOP .nextbyte                                 
        RET                                            
    .hexdigit: ; 12 bytes                                    
        XCHG AL, AH
        CMP AL, 0         ; AAM effect on AF/CY is undefined: So clear both - and after SBB (inc doesnt affect CY)
        DAA               ; AL = 08 -> 08   AL = 0B -> 11 (AF=1..) CY=0 for all (The SF, ZF, and PF flags are set according to the result)         
        CMP AL, 0x10      ; CMPA i to set/clear carry  '0'=30 but 'A'=41 need AF.. just opposite CY set by this cmp      
        SBB AL, ~'0'      ; SBBA i   sub with carry                                      
        STOSB
        INC DI
        RET
        
[BITS 32]
; 32-BIT ENTRY POINT
; ESI: pointer to source mem first byte
; ECX: n of bytes
; EDI: screen address pos
outhex32:
    mov edx, outhex16.hexdigit  ;  indirect call for the same 16/32 opcodes
    jmp outhex16.outhex
%endif


%ifdef NEED.64
; ======================================================================================================
; The 16/32/64-bit HEX WRITER VERSION
; Here without BCD instructions (illegal). A little longer
;
[BITS 16]
outhex16:
    MOV DX, .hexdigit 
    .outhex:
     [BITS 64] 
     DEC ESI       ; force r/m form of DEC SI, 2 bytes: db 0xFF db 0xCE
     [BITS 16]
     ADD SI, CX    ; SI: last byte 
    .nextbyte:
        STD 
        LODSB
        CLD
        MOV AH, AL       ; AAM 16
        SHR AH, 4
        AND AL, 0x0F
        CALL DX
        CALL DX
        LOOP .nextbyte                                 
        RET 
     .hexdigit:  ; 13 bytes                                  
        XCHG AL, AH
        CMP AL, 10
        JB .dig
         ADD AL, 6    ; oh I miss adjust instructions too in 64-bit
        .dig: 
        SBB AL, ~'0'  ; SBBA i   sub with carry                                      
        STOSB
        SCASB         ; one-byte opcode, substitute for inc EDI (in CLD)
        RET
        
[BITS 32]  
outhex64: 
outhex32:
    mov edx, outhex16.hexdigit
    jmp outhex16.outhex
%endif


%ifdef NEED.dumphex  
; ======================================================================================================
; Same as 16/32/64-bit HEX WRITER but big-endian VERSION i.e. hexdump 
; beautiful polymorhism in assembly
; 
; wastes only one byte if not used for 64-bit code (forced r/m form INC DI)
; 
[BITS 16]
dumphex16:
      MOV DX, .hexdigitdump     ; our callback for .outhex
      JMP outhex16.nextbyte     ; jump in with first byte of [SI]
      
      .hexdigitdump:            ; 2x call = adds 2: adjust back SI to next byte
      [BITS 64] 
      INC ESI                   ; force r/m form of INC SI, 2 bytes: db 0xFF db 0xC6
      JMP outhex16.hexdigit     
          
[BITS 32]
dumphex32:
dumphex64:
      mov edx, dumphex16.hexdigitdump ;  indirect call for the same 16/32 opcodes
      jmp outhex16.nextbyte  ; NB. short jmp only: same opcode in 16/32/64 (so keep these routines tight)
%endif


%ifdef NEED.outhexnz
; ======================================================================================================
; 16/32/64-bit HEX WRITER VERSION without leading zeroes 
; can be used to write packed BCD TBYTE for decimals written by FPU FBSTP
; beautiful polymorhism in assembly
;
; Two things here:
;   - how to skip leading zeroes
;   - how to detect all zero at the end
; BX is used and also clobbered
[BITS 16]
outhex16nz:
      MOV DX, .hexdigitnz   ; our callback for .outhex
      
      .outhexnz:
      MOV BX, CX   ; ment for numbers, max 128 digits BUT sum is also max 255 ( so works for ~ 28 digits max)
      SHL BL, 1    ; BH=0 (sum of digits) BL = # of digits - 1 (digit counter)
      DEC BL       ; 64-bit conform
      JMP outhex16.outhex 
      
      .hexdigitnz:        ; Filters out zeroes:
         ADD BH, AH            ; non null digit: write
         JNZ outhex16.hexdigit
         DEC BL                ; last null digit? 
         JS outhex16.hexdigit  ; sum zero: write '0'
         XCHG AL, AH 
         RET                   ; else skip leading zeroes         
  
[BITS 32]
outhex32nz:
outhex64nz:
      mov edx, outhex16nz.hexdigitnz   ; our callback for .outhex
      jmp outhex16nz.outhexnz
%endif

; ======================================================================================================
[BITS 16]
; Print zero-terminated string to CGA
; 16/32/64-BIT VERSION
; DS:SI string
; ES:DI screen address (ES must be B800)
; Simply ESI,EDI for 32-bit
outs:        ; written for same 16/32 opcodes
     CLD
     .next: LODSB
      TEST AL,AL
      JNZ .nonzero
      RET
      .nonzero STOSB 
      SCASB ; one-byte opcode. dummy for INC DI (for 64-bit mode)
      ;INC DI
     JMP .next
     
     
