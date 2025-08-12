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
;   Another first thing is to write strings. So outs is also here and can be called from all 16/32/64-code.
;   Writes chars of a zero-terminated string (SI).
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
; outsn 16/32/64
;   
;   Write eCX characters of strings.
;   Just %define NEED.outsn to include. This is for keeping bootblock small if not required. 
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
    MOV DX, outhex.hexdigit
    
    outhex:       ; written using the same 16/32 opcodes
    DEC SI         
    ADD SI, CX    ; last byte
    .nextbyte:    
        STD
        LODSB
        CLD               ; AH AL       AH AL
        AAM 16            ; .. ab  -->  0a 0b
        CALL DX                             
        CALL DX                                        
        LOOP .nextbyte                                 
        RET                                            
    .hexdigit: ; 12 bytes                                    
        XCHG AL, AH
        CMP AL, 0         ; AAM effect on AF/CY is undefined: So clear both for DAA - and after SBB (INC does not affect CF and CLC is not enough)
        DAA               ; AL = 08 -> 08   AL = 0B -> 11 (AF=1..) CY=0 for all. We need to translate to ascii digits or letters: would need add '0' with AF..
        CMP AL, 0x10      ; CMP to set/clear carry: '0'=30 CY=1 but 'A'=41 CY=0 
        SBB AL, ~'0'      ; just opposite CY so use sub with carry (instead of CMC and ADC)
        STOSB
        INC DI
        RET
        
[BITS 32]
; 32-BIT ENTRY POINT
; ESI: pointer to source mem first byte
; ECX: n of bytes
; EDI: screen address pos
outhex32:
    mov edx, outhex.hexdigit  ;  indirect call for the same 16/32 opcodes
    jmp outhex
;%endif

%elifdef NEED.64
; ======================================================================================================
; The 16/32/64-bit HEX WRITER VERSION
; Here without BCD instructions (illegal). A little longer
;
[BITS 16]
outhex16:
    MOV DX, outhex.hexdigit 
    
    outhex:       ; written using the same 16/32/64 opcodes
     [BITS 64] 
     DEC ESI       ; force r/m form of DEC SI, 2 bytes: db 0xFF db 0xCE
     [BITS 16]
     ADD SI, CX    ; SI: last byte 
    .nextbyte:
        STD 
        LODSB
        CLD
        MOV AH, AL    ; AAM 16
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
        SBB AL, ~'0'
        STOSB
        SCASB         ; one-byte opcode, substitute for inc EDI (CLD set)
        RET
        
[BITS 32]  
outhex64: 
outhex32:
    mov edx, outhex.hexdigit
    jmp outhex
%endif

%ifdef NEED.dumphex  
; ======================================================================================================
; Same as 16/32/64-bit HEX WRITER but big-endian VERSION i.e. hexdump 
; beautiful polymorhism and code reuse in assembly
; 
; wastes only one byte if not used for 64-bit code (forced r/m form INC SI)
; 
[BITS 16]
dumphex16:
      MOV DX, hexdigitdump     ; our callback for .outhex
      JMP outhex.nextbyte     ; jump in with first byte of [SI]
      
      hexdigitdump:            ; 2x call = adds 2: adjust back SI to next byte
      [BITS 64] 
      INC ESI                   ; force r/m form of INC SI, 2 bytes: db 0xFF db 0xC6
      JMP outhex.hexdigit     ; make sure it is short jump for same opcode
          
[BITS 32]
dumphex32:
dumphex64:
      mov edx, hexdigitdump  ;  indirect call for the same 16/32 opcodes
      jmp outhex.nextbyte    ; NB. short jmp only: same opcode in 16/32/64 (so keep these routines tight)
%endif

; pull in outhexnz if only NEED.outdec defined
%ifdef NEED.outdec
%define NEED.outhexnz
%endif 

%ifdef NEED.outhexnz
; ======================================================================================================
; 16/32/64-bit HEX WRITER VERSION without leading zeroes 
; can be used to write packed BCD TBYTE for decimals written by FPU FBSTP
; beautiful polymorhism and code reuse in assembly
;
; Two things here:
;   - how to skip leading zeroes
;   - how to detect all zero at the end and write '0'
; rBX is used for that and is also clobbered
[BITS 16]
outhex16nz:
      MOV DX, outhexnz.hexdigit   ; our callback for .outhex
      
      outhexnz:   ; written using the same 16/32/64 opcodes
      MOV BX, CX   ; ment for numbers, max 128 digits BUT sum is also max 255 ( so works for ~ 28 digits max)
      SHL BL, 1    ; BH=0 (sum of digits) BL = # of digits (digit counter)
      JMP outhex 
      
      .hexdigit:        ; Filters out zeroes:
         ADD BH, AH            ; non null digit: write
         JNZ outhex.hexdigit
         DEC BL                ; last null digit? 
         JZ outhex.hexdigit  ; sum zero: write '0'
         XCHG AL, AH 
         RET                   ; else skip leading zeroes         
  
[BITS 32]
outhex32nz:
outhex64nz:
      mov edx, outhexnz.hexdigit   ; our callback for .outhex
      jmp outhexnz
%endif

%ifdef NEED.outdec

%ifempty NEED.outdec
%define NEED.outdec -1
%endif
; ======================================================================================================
; 16/32/64-bit writes 16-bit WORD values from SI as decimal.
; Uses 10 bytes temp
; 
; Just makes life easier: for other sizes write own
;
; 
[BITS 16]
%if NEED.outdec & 16
outdec16:
      FILD WORD [SI] 
      MOV SI, $$              ; 10 bytes temp
      FBSTP TWORD [SI]        ; TWORD=TBYTE an NASM thing
      MOV CX, 9                  ; 9 bytes, not sign byte
      JMP outhex16nz
%endif
      
[BITS 32]
%if NEED.outdec & (64|32)
outdec32:
outdec64:
      fild word [esi]    
      ;mov esi, $$              ; 10 bytes temp
      fbstp tword [esi]        ; TWORD=TBYTE an NASM thing
      push 9
      pop ecx                  ; 9 bytes, not sign byte
      jmp outhex32nz
%endif
%endif

; ======================================================================================================
[BITS 16]
; Print zero-terminated string to CGA
; 16/32/64-BIT VERSION
; DS:SI string
; ES:DI screen address (ES must be B800)
; Simply ESI,EDI for 32-bit
outs:        ; written for same 16/32/64 opcodes
     CLD
     .next: LODSB
      TEST AL,AL
      JNZ .nonzero
       RET
      .nonzero STOSB 
      SCASB ; one-byte 'dummy' opcode for INC DI (for 64-bit mode)
     JMP .next
     
%ifdef NEED.outsn
; ======================================================================================================
[BITS 16]
; Print string of n characters (rCX) to CGA
outsn:       ; written for same 16/32/64 opcodes
     CLD
     .next: LODSB
      STOSB 
      SCASB ; one-byte opcode. dummy for INC DI (for 64-bit mode)
      LOOP .next
      RET
%endif

%ifdef NEED.coloroutsn
; ======================================================================================================
[BITS 16]
; Print string of n characters (CX) to CGA
; AH=ATTR and is also written
coloroutsn:       ; written for same 16/32/64 opcodes
     CLD
     .next: LODSB
      STOSB 
      MOV AL, AH
      STOSB 
      LOOP .next
      RET
%endif

%ifdef NEED.colorouts
; ======================================================================================================
[BITS 16]
; Print zero-terminated string to CGA
; AH=ATTR and is also written
colorouts:       ; written for same 16/32/64 opcodes
     CLD
     .next: LODSB
      TEST AL,AL
      JNZ .nonzero
       RET
      .nonzero STOSB 
      MOV AL, AH
      STOSB 
     JMP .next
%endif
