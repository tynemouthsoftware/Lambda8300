; Disassembly of the Lambda 8300 ROM
; Dave Curran 2026-06-12

; Where functions are identical to ZX81, only the function names are commented
; Refer to the ZX81 assembly listing by Geoff Wearmouth for further comments
; https://web.archive.org/web/20111004151617/http://www.wearmouth.demon.co.uk/zx81.htm

; assemble with TASM
; TASM.EXE -t80 -fff -b Lambda8300.asm Lambda8300.bin

; Z80 @ 3.25MHz
; 8K of ROM
; 2K of RAM
; expandable to 32k of RAM

; Memory Map
; $0000-1FFF        - ROM
; $2000-3FFF        - Option ROM
; $4000     ERR.NR  - Current report code -1
; $4001     FLAGS   - Some flags
; $4002/03  ERR.SP  - Address of top of GOSUB stack
; $4004/05  RAMTOP  - Address of reserved area
; $4006     MODE    - Cursor mode
; $4007/08  PPC     - Line number being executed
; $4009     VERSN   - Version (from tape $00 = ZX81, $FF = Lambda)
; $400A/0B  NXTLIN  - Address of next line to be executed (ZX81 has E.PPC here)
; $400C/0D  PRGRM   - Start of user program = $4396 (ZX81 has DFILE here)
; $400E/0F  DF.CC   - Display file current character
; $4010/11  VARS    - Start of variable area
; $4012/13  DEST    - Address of variable being assigned
; $4014/15  E.LINE  - Address of edit line
; $4016/17  CH.ADD  - Next character to interpret
; $4018/19  X.PTR   - Addess of character before syntax error
; $401A/1B  STKBOT  - Address of calculator stack
; $401C/1D  STKEND  - End of calculator stack
; $401E     BREG    - Floating point B register
; $401F/20  MEM     - Address of calc memory area = MEMBOT
; $4021     TEMPO   - Setting of music tempo (was SPARE1)
; $4022     DF.SZ   - Size of editor part of screen
; $4023/24  S.TOP   - Line number at top of screen
; $4025/26  LAST.K  - Last keyboard scan
; $4027     DB.ST   - Keyboard debounce status
; $4028     MARGIN  - Number of lines in margin
; $4029/2A  E.PPC   - Line number of line with cursor (ZX81 has NXTLIN here)
; $402B/2C  OLDPPC  - Address of line where CONT jumps
; $402D     FLAGX   - Some more flags
; $402E/F   STRLEN  - String length
; $4030/31  T.ADDR  - Next item in syntax table
; $4032/33  SEED    - Seed for RND
; $4034/35  FRAMES  - Frame counter
; $4035/37  COORDS  - Last point plotted (to add for DRAW?)
; $4038     PR.CC   - Address of LPRINT position
; $4039/3A  S.POSN  - Current PRINT position
; $403B     CDFLAG  - Compute Display Flags for FAST/SLOW mode (Bit 7 = 1 for SLOW, Bit 6 = 1 to request SLOW mode)
; $403C-5C  PRBUFF  - Printer buffer
; $405D-7A  MEMBOT  - Calculator memory
; $407B-7C  BLINK   - Cursor blink
; $407D-$4395       - Display file
; $4396-RAMTOP      - User Program memory

; no DFILE variable - Location of display file, that is hard coded at $407D
DFILE .equ 0407dh

.org    00000h

; -----------
; THE 'START'
; -----------

; START
l0000h:
    out (0fdh),a            ; turn off NMI
    ld a,0bfh
    in a,(0feh)             ; keyboard read (hold down key for ROM at $2000?)
    jr l0025h               ; Jump to START-3 via START-2

; -------------------
; THE 'ERROR' RESTART
; -------------------

; ERROR-1
l0008h:
    ld hl,(04016h)          ; CH.ADD - Address of next character to interpret
    ld (04018h),hl          ; X.PTR - Address of character before error
    jr l0057h               ;

; -------------------------------
; THE 'PRINT A CHARACTER' RESTART
; -------------------------------

; PRINT-A
l0010h:
    and a
l0011h:
    jp nz,l0992h
    jp l0996h

    .byte $FF               ; unused

; ---------------------------------
; THE 'COLLECT A CHARACTER' RESTART
; ---------------------------------

; GET-CHAR
l0018h:
    ld hl,(04016h)
    ld a,(hl)
l001ch:
    and a
    ret nz
    nop
    nop

; ------------------------------------
; THE 'COLLECT NEXT CHARACTER' RESTART
; ------------------------------------

; NEXT-CHAR
l0020h:
    call sub_004ah
    jr l001ch

; start continued

; START-2
l0025h:
    jp l046eh

; ---------------------------------------
; THE 'FLOATING POINT CALCULATOR' RESTART
; ---------------------------------------

; FP-CALC
l0028h:
    jp l1b94h

; end-calc
sub_002bh:
    pop af
    exx
    ex (sp),hl
    exx
    ret

; -----------------------------
; THE 'MAKE BC SPACES'  RESTART
; -----------------------------

; BC-SPACES
l0030h:
    push bc
    ld hl,(04014h)
    push hl
    jp l167dh

; -----------------------
; THE 'INTERRUPT' RESTART
; -----------------------

; INTERRUPT
l0038h:
    dec c
    jr nz,l0045h
    pop hl
    dec b
    ret z
    ret z                   ; extra delay? not in ZX81
    ld c,008h               ; faster than SET 3,C (but is that a good thing here?)

; WAIT-INT
l0041h:
    ld r,a
    ei
    jp (hl)                 ; jump into display file mirror

; SCAN-LINE
l0045h:
    pop de
    nop                     ; different timing to ZX81
    jr l0041h

    .byte $00               ; unused (which moved $004A-$0065 1 byte away from ZX81)

; ---------------------------------
; THE 'INCREMENT CH-ADD' SUBROUTINE
; ---------------------------------

; CH-ADD+1
sub_004ah:
    ld hl,(04016h)

; TEMP-PTR1
l004dh:
    inc hl

; TEMP-PTR2
sub_004eh:
    ld (04016h),hl
    ld a,(hl)
    cp 07fh
    ret nz
    jr l004dh

; --------------------
; THE 'ERROR-2' BRANCH
; --------------------

; ERROR-2
l0057h:
    pop hl                  ; get error code
    ld l,(hl)               ; extract error byte

; ERROR-3
l0059h:
    ld (iy+000h),l          ; set ERR_NR, system error number
    ld sp,(04002h)          ; reset stack pointer to top of GOSUB stack
    call sub_0285h          ; SLOW mode
    jp l16b4h               ; exit via SET_MIN to clear calculator stack

; ------------------------------------
; THE 'NON MASKABLE INTERRUPT' ROUTINE
; ------------------------------------

; NMI
l0066h:
    ex af,af'               ; NMI uses the alternate A&F
    inc a                   ; Incrememnt line count
    jp z,l006eh             ; Jump if line count has reached 0
    nop                     ; NMI test removed (ROM will not run on ZX80 hardware)

; NMI-RET
    ex af,af'               ; Return to normal A&F
    ret                     ; Return to user code

; NMI-CONT
l006eh:
    ex af,af'               ; Return to normal A&F
    push af                 ; Save the main registers
    push bc                 ;
    push de                 ;
    push hl                 ;
    ld hl,$407D + $8000     ; Set HL to fixed DFILE mirror location (not ($400C) with bit 7 set)
    halt                    ; sync with NMI

    out (0fdh),a            ; stop the NMI generator
    jp (ix)                 ; forward to R-IX-1 (after top) or R-IX-2


; ****************
; ** KEY TABLES **
; ****************

; -------------------------------
; THE 'UNSHIFTED' CHARACTER CODES
; -------------------------------

; K-UNSHIFT
L007bh:

    .byte    $3F            ; Z
    .byte    $3D            ; X
    .byte    $28            ; C
    .byte    $3B            ; V

    .byte    $26            ; A
    .byte    $38            ; S
    .byte    $29            ; D
    .byte    $2B            ; F
    .byte    $2C            ; G

    .byte    $36            ; Q
    .byte    $3C            ; W
    .byte    $2A            ; E
    .byte    $37            ; R
    .byte    $39            ; T

    .byte    $1D            ; 1
    .byte    $1E            ; 2
    .byte    $1F            ; 3
    .byte    $20            ; 4
    .byte    $21            ; 5

    .byte    $1C            ; 0
    .byte    $25            ; 9
    .byte    $24            ; 8
    .byte    $23            ; 7
    .byte    $22            ; 6

    .byte    $35            ; P
    .byte    $34            ; O
    .byte    $2E            ; I
    .byte    $3A            ; U
    .byte    $3E            ; Y

    .byte    $76            ; NEWLINE
    .byte    $31            ; L
    .byte    $30            ; K
    .byte    $2F            ; J
    .byte    $2D            ; H

    .byte    $00            ; SPACE
    .byte    $1B            ; .
    .byte    $32            ; M
    .byte    $33            ; N
    .byte    $27            ; B

; -----------------------------
; THE 'SHIFTED' CHARACTER CODES
; -----------------------------

; K-SHIFT
l00a2h:
    .byte    $F5            ; Shift + Z = PRINT
    .byte    $7A            ; Shift + X = Line no
    .byte    $70            ; Shift + C = cursor-up
    .byte    $71            ; Shift + V = cursor-down

    .byte    $C6            ; Shift + A = ASN
    .byte    $C7            ; Shift + S = ACS
    .byte    $C8            ; Shift + D = ATN
    .byte    $CA            ; Shift + F = EXP
    .byte    $CE            ; Shift + G = ABS

    .byte    $C3            ; Shift + Q = SIN
    .byte    $C4            ; Shift + W = COS
    .byte    $C5            ; Shift + E = TAN
    .byte    $C9            ; Shift + R = LOG
    .byte    $CD            ; Shift + T = SGN

    .byte    $0F            ; Shift + 1 = ?
    .byte    $0C            ; Shift + 2 = £
    .byte    $0E            ; Shift + 3 = :
    .byte    $0D            ; Shift + 4 = $
    .byte    $0B            ; Shift + 5 = "

    .byte    $14            ; Shift + 0 = =
    .byte    $11            ; Shift + 9 = )
    .byte    $10            ; Shift + 8 = (
    .byte    $1A            ; Shift + 7 = ,
    .byte    $19            ; Shift + 6 = ;

    .byte    $12            ; Shift + P = >
    .byte    $13            ; Shift + O = <
    .byte    $45            ; Shift + I = PI
    .byte    $43            ; Shift + U = RND
    .byte    $CC            ; Shift + Y = SQR

    .byte    $74            ; Shift + N/L = GRAPHICS
    .byte    $15            ; Shift + L = +
    .byte    $16            ; Shift + K = -
    .byte    $17            ; Shift + J = *
    .byte    $18            ; Shift + H = /

    .byte    $79            ; Shift + SPACE = FUNCTION
    .byte    $77            ; Shift + . = RUBOUT
    .byte    $75            ; Shift + M = EDIT
    .byte    $73            ; Shift + N = cursor-right
    .byte    $72            ; Shift + B = cursor-left


; -----------------------------
; THE 'GRAPHIC' CHARACTER CODES
; -----------------------------

; K-GRAPH
; 00c9
    .byte    $83            ; Graphics + Z = graphic
    .byte    $03            ; Graphics + X = graphic
    .byte    $05            ; Graphics + C = graphic
    .byte    $85            ; Graphics + V = graphic

    .byte    $08            ; Graphics + A = graphic
    .byte    $0A            ; Graphics + S = graphic
    .byte    $09            ; Graphics + D = graphic
    .byte    $8A            ; Graphics + F = graphic
    .byte    $89            ; Graphics + G = graphic

    .byte    $01            ; Graphics + Q = graphic
    .byte    $02            ; Graphics + W = graphic
    .byte    $04            ; Graphics + E = graphic
    .byte    $87            ; Graphics + R = graphic
    .byte    $81            ; Graphics + T = graphic

    .byte    $8F            ; Graphics + 1 = graphic
    .byte    $8C            ; Graphics + 2 = graphic
    .byte    $8E            ; Graphics + 3 = graphic
    .byte    $8D            ; Graphics + 4 = inverse $
    .byte    $8B            ; Graphics + 5 = inverse "

    .byte    $94            ; Graphics + 0 = inverse =
    .byte    $91            ; Graphics + 9 = inverse )
    .byte    $90            ; Graphics + 8 = inverse (
    .byte    $9A            ; Graphics + 7 = inverse ,
    .byte    $99            ; Graphics + 6 = inverse ;

    .byte    $92            ; Graphics + P = inverse >
    .byte    $93            ; Graphics + O = inverse <
    .byte    $07            ; Graphics + I = graphic
    .byte    $84            ; Graphics + U = graphic
    .byte    $82            ; Graphics + Y = graphic

    .byte    $78            ; Graphics + N/L = KL
    .byte    $95            ; Graphics + L = inverse +
    .byte    $96            ; Graphics + K = inverse -
    .byte    $97            ; Graphics + J = inverse *
    .byte    $98            ; Graphics + H = inverse /

    .byte    $78            ; Graphics + SPACE =
    .byte    $77            ; Graphics + . = RUBOUT
    .byte    $78            ; Graphics + M = KL
    .byte    $86            ; Graphics + N = graphic
    .byte    $06            ; Graphics + B = graphic

; ------------------
; THE 'TOKEN' TABLES
; ------------------

; TOKENS
l00f0h:
    .byte   $1B+$80                         ; '.' + $80 ?
l00f1h:
    .byte   $28,$34,$29,$2A+$80             ; CODE
    .byte   $3B,$26,$31+$80                 ; VAL
    .byte   $31,$2A,$33+$80                 ; LEN
    .byte   $38,$2E,$33+$80                 ; SIN
    .byte   $28,$34,$38+$80                 ; COS
    .byte   $39,$26,$33+$80                 ; TAN
    .byte   $26,$38,$33+$80                 ; ASN
    .byte   $26,$28,$38+$80                 ; ACS
    .byte   $26,$39,$33+$80                 ; ATN
    .byte   $31,$34,$2C+$80                 ; LOG
    .byte   $2A,$3D,$35+$80                 ; EXP
    .byte   $2E,$33,$39+$80                 ; INT
    .byte   $38,$36,$37+$80                 ; SQR
    .byte   $38,$2C,$33+$80                 ; SGN
    .byte   $26,$27,$38+$80                 ; ABS
    .byte   $35,$2A,$2A,$30+$80             ; PEEK
    .byte   $3A,$38,$37+$80                 ; USR
    .byte   $38,$39,$37,$0D+$80             ; STR$
    .byte   $28,$2D,$37,$0D+$80             ; CHR$
    .byte   $33,$34,$39+$80                 ; NOT
    .byte   $26,$39+$80                     ; AT
    .byte   $39,$26,$27+$80                 ; TAB
    .byte   $17,$17+$80                     ; **
    .byte   $34,$37+$80                     ; OR
    .byte   $26,$33,$29+$80                 ; AND
    .byte   $13,$14+$80                     ; <=
    .byte   $12,$14+$80                     ; >=
    .byte   $13,$12+$80                     ; <>

    .byte   $39,$2A,$32,$35,$34+$80         ; TEMPO
    .byte   $32,$3A,$38,$2E,$28+$80         ; MUSIC
    .byte   $38,$34,$3A,$33,$29+$80         ; SOUND
    .byte   $27,$2A,$2A,$35+$80             ; BEEP
    .byte   $33,$34,$27,$2A,$2A,$35+$80     ; NOBEEP
    .byte   $31,$35,$37,$2E,$33,$39+$80     ; LPRINT
    .byte   $31,$31,$2E,$38,$39+$80         ; LLIST
    .byte   $38,$39,$34,$35+$80             ; STOP
    .byte   $38,$31,$34,$3C+$80             ; SLOW
    .byte   $2B,$26,$38,$39+$80             ; FAST
    .byte   $33,$2A,$3C+$80                 ; NEW
    .byte   $38,$28,$37,$34,$31,$31+$80     ; SCROLL
    .byte   $28,$34,$33,$39+$80             ; CONT
    .byte   $29,$2E,$32+$80                 ; DIM
    .byte   $37,$2A,$32+$80                 ; REM
    .byte   $2B,$34,$37+$80                 ; FOR
    .byte   $2C,$34,$39,$34+$80             ; GOTO
    .byte   $2C,$34,$38,$3A,$27+$80         ; GOSUB
    .byte   $2E,$33,$35,$3A,$39+$80         ; INPUT
    .byte   $31,$34,$26,$29+$80             ; LOAD
    .byte   $31,$2E,$38,$39+$80             ; LIST
    .byte   $31,$2A,$39+$80                 ; LET
    .byte   $35,$26,$3A,$38,$2A+$80         ; PAUSE
    .byte   $33,$2A,$3D,$39+$80             ; NEXT
    .byte   $35,$34,$30,$2A+$80             ; POKE
    .byte   $35,$37,$2E,$33,$39+$80         ; PRINT
    .byte   $35,$31,$34,$39+$80             ; PLOT
    .byte   $37,$3A,$33+$80                 ; RUN
    .byte   $38,$26,$3B,$2A+$80             ; SAVE
    .byte   $37,$26,$33,$29+$80             ; RAND
    .byte   $2E,$2B+$80                     ; IF
    .byte   $28,$31,$38+$80                 ; CLS
    .byte   $3A,$33,$35,$31,$34,$39+$80     ; UNPLOT
    .byte   $28,$31,$2A,$26,$37+$80         ; CLEAR
    .byte   $37,$2A,$39,$3A,$37,$33+$80     ; RETURN
    .byte   $28,$34,$35,$3E+$80             ; COPY

    .byte   $39,$2D,$2A,$33+$80             ; THEN
    .byte   $39,$34+$80                     ; TO
    .byte   $38,$39,$2A,$35+$80             ; STEP
    .byte   $37,$33,$29+$80                 ; RND
    .byte   $2E,$33,$30,$2A,$3E,$0D+$80     ; INKEY$
    .byte   $35,$2E+$80                     ; PI

; ---------------------------
; THE 'ERROR MESSAGES' TABLES
; ---------------------------

; table of error messages, used by function at $07E1
l01f2h:
    .byte    $34,$30        ; FF = OK - OK
    .byte    $33,$2B        ; 00 = NF - NEXT without FOR
    .byte    $3A,$3B        ; 01 = UV - Unidentified Variable
    .byte    $27,$38        ; 02 = BS - Bad Subscript
    .byte    $34,$32        ; 03 = OM - Out of Memory
    .byte    $38,$2B        ; 04 = SF - Screen Full
    .byte    $34,$3B        ; 05 = OV - OVerflow
    .byte    $37,$2C        ; 06 = RG - RETURN without GOSUB
    .byte    $2E,$2E        ; 07 = II - Illegal INPUT
    .byte    $38,$39        ; 08 = ST - STop
    .byte    $26,$2C        ; 09 = AG - invalid ArGument
    .byte    $2E,$37        ; 0A = IR - Integer out of Range
    .byte    $2E,$2A        ; 0B = IE - Invalid Expression
    .byte    $27,$30        ; 0C = BK - BreaK
    .byte    $33,$26        ; 0D = NA - No program NAme
    .byte    $32,$2B        ; 0E = MF - Music Format incorrect

; the " IN " message
l0212h:
    .byte    $00,$2E,$33,$00    ; " IN " ("OK IN 10")


; ------------------------------
; THE 'LOAD-SAVE UPDATE' ROUTINE
; ------------------------------

; LOAD/SAVE
sub_0216h:
    inc hl                  ; Step destination
    ex de,hl                ; Backup to DE
    ld hl,(04014h)          ; Get E-LINE
    scf                     ; Check if they match
    sbc hl,de               ; Is the last byte the end of the file?
    ex de,hl                ; Restore destination
    ret nc                  ; return if the end has not been reached
    pop hl                  ; drop the return address and continue
; ZX81 drops to SLOW here

; LOAD/SAVE-COMPLETE
l0221h:
    inc (iy+009h)           ; increment version (from tape Lambda = $FF, ZX81 = $00. normal Lambda = $00, ZX81 = $01)
    jr z,sub_0285h          ; if it was $FF, a Lambda program, go straight to FAST/SLOW

; This code converts a ZX81 program to the Lambda 8300
    ld hl,(0400ch)          ; Location of the ZX81 DFILE (loaded with program)
    inc hl                  ; +1
    ld (04010h),hl          ; Store this as
    ld hl,DFILE             ; Hard coded DFILE location
    ld bc,00319h            ; Length of DFILE + 1 extra blank row to make SCROLL a block copy
    call sub_0b30h          ; MAKE-ROOM for BC bytes at location in HL
    ex de,hl                ; HL is now at the program location
; ZX81-CONV-1
l0237h:
    inc hl                  ; Step through memory
    ld a,0c0h
    and (hl)                ; Mask off the top two bits
    inc hl
    inc hl
    inc hl
    jr z,l0248h             ; If it was <$30, skip to ZX81-CONV-4
    ld hl,04396h            ; Hard coded number we worked out before (start of program)
    jp l04ach               ; Re-initialise after loading and clear screen etc.

; ZX81-CONV-2
l0246h:
    add a,b                 ; modify the command token from ZX81 to Lambda tokens

; ZX81-CONV-3
l0247h:
    ld (hl),a               ; update the token in the copde

; ZX81-CONV-4
l0248h:
    inc hl                  ; step through program
    ld a,(hl)
    call sub_0955h          ; routine NUMBER
    jr z,l0248h             ; skip through numbers

    cp 076h                 ; is it a newline?
    jr z,l0237h             ; skip back for next line number
    cp 0e1h                 ; is it a command over $E1?
    jr nc,l0248h            ; continue scanning
    cp 040h                 ; is it a number character below $40?
    jr c,l0248h             ; continue scanning
    ld b,003h
    cp 043h                 ; is it a command below $43?
    jr c,l0246h             ; add 3
    ld b,062h
    cp 0deh                 ; is it a command above $DE?
    jr nc,l0246h            ; add $62
    ld b,0feh
    cp 0d8h                 ; is it cpmmand $D8?
    jr nc,l0246h            ; add $FE
    ld b,0fch
    cp 0c4h                 ; is it above $C4?
    jr nc,l0246h            ; add $FC
    ld b,013h
    cp 0c1h                 ; is it above $C1?
    jr nc,l0246h            ; add $13
    cp 0c0h
    jr nz,l0248h            ; is it not $C0?
    ld a,017h               ; replace with dummy command
    jr l0247h               ; loop back to write the new value

; --------------------------
; THE 'SLOW' COMMAND ROUTINE
; --------------------------

; SLOW
sub_0281h:
    set 6,(iy+03bh)         ; Request slow mode ()

; SLOW/FAST
sub_0285h:
    ld hl,0403bh            ; load the CDFLAG
    ld a,(hl)
    rla                     ; bit 6 (request) -> bit 7 (current state)
    xor (hl)                ; XOR with actual current state
    rla                     ; result -> carry
    ret nc                  ; return if already in requested mode

    set 7,(hl)              ; set slow mode - compute and display
    push af
    push bc
    push de
    push hl

; Called where DISPLAY-1 usually was
; PRE-DISPLAY-1
sub_0293h:
    xor a                   ; clear the line counter
    ex af,af'
    out (0feh),a            ; enable NMI generator
    halt                    ; wait for interrupt
    out (0fdh),a            ; disable NMI generator
    ld a,(hl)               ; waste cycles
    ld a,(hl)
    nop

; -----------------------
; THE 'MAIN DISPLAY' LOOP
; -----------------------
; This routine is executed once for every frame displayed.

;; DISPLAY-1
l029dh:
    ld hl,(04034h)          ; Get the frame count from FRAMES
    dec hl
    ld a,07fh               ; Mask bit 7
    and h                   ; of H
    or l                    ; and OR with L
    ld a,h                  ;
    jr nz,l02abh            ; Jump if frame counter bits 0-14 are zero
    rla                     ; bit 15 of frame counter (1 if paused) to carry
    jr l02adh               ; skip

; ANOTHER
l02abh:
    ld b,(hl)               ; Dummy timing
    scf                     ; set carry

; OVER-NC
l02adh:
    ld h,a
    ld (04034h),hl          ; Save the new frame count to FRAMES
    ret nc                  ; Return if FRAMES is in use by PAUSE command

; ZX81 goes string to ; DISPLAY-2

; Bit 7 of the cursor character is inverted every 16 frames
; That makes it flashe approximately 2 times a second
; BLINK-CURSOR
    ld a,l                  ; A = LSB of FRAMES
    ld hl,(0407bh)          ; Address of blinking cursor
    sla (hl)                ; rotate cursor character
    rla                     ;
    rla                     ;
    rla                     ;
    rla                     ; rotate A bit 4 into carry
    rr (hl)                 ; rotate carry back into character

; DISPLAY-2
    call sub_033dh          ; KEYBOARD - scan keyboard and start VSYNC
    ld bc,(04025h)          ; get LAST_K
    ld (04025h),hl          ; update LAST_K
    ld a,b
    add a,002h
    sbc hl,bc
    ld a,(04027h)           ; Check DEBOUNCE
    or h
    or l
    ld e,b
    ld b,009h               ; ZX81 used $0B
    ld hl,0403bh            ; Get CDFLAG
    res 0,(hl)
    jr nz,l02e4h
    bit 7,(hl)
    set 0,(hl)
    ret z                   ; return if in FAST mode
    dec b
    dec b                   ; extra DEC B, ZX81 was NOP
    scf

; NO-KEY
l02e4h:
    rl b                    ; Reordered from ZX81

; LOOP-B
l02e6h:
    djnz l02e6h
    ld hl,04027h
    ld b,(hl)               ; Get DEBOUCE
    ld a,e
    cp 0feh
    sbc a,a
    ld b,00fh               ; ZX81 has $1F
    or (hl)
    and b
    rra
    ld (hl),a
l02f6h:
    add hl,hl
    inc hl
    out (0ffh),a            ; End VSYNC pulse

    ld hl,$407D + $8000     ; Hard coded DFILE location
    call sub_0314h

; ---------------------
; THE 'VIDEO-1' ROUTINE
; ---------------------

; R-IX-1 (timing altered)
    ld bc,01901h            ; B=25 lines, C=1 scanline
    ld a,(00000h)           ; wasting cycles
    ld a,0f5h               ; Preset value to go into R to cause trigger at correct time
    call sub_0337h          ; DISPLAY-5, border complete, generate text display
    nop
    nop
    dec hl                  ; back to the previous HALT character
    call sub_0314h          ; DISPLAY-3, bottom border
    jp l029dh               ; Back to DISPLAY-1

; ---------------------------------
; THE 'DISPLAY BLANK LINES' ROUTINE
; ---------------------------------

; DISPLAY-3
sub_0314h:
    pop ix
    ld c,(iy+028h)          ; Load C with MARGIN value
    bit 7,(iy+03bh)         ; Check CDFLAG
    jr z,l032bh             ; To DISPLAY-4 in FAST mode

    ld a,c                  ; A = 31 (NTSC) or 55 (PAL)
    neg
    inc a
    ex af,af'               ; Set NMI's A register to $FF-MARGIN

    out (0feh),a            ; Enable the NMI generator

    pop hl                  ; Restore main registers
    pop de
    pop bc
    pop af
    ret                     ; return to users code until interrupted

; ------------------------
; THE 'FAST MODE' ROUTINES
; ------------------------

; DISPLAY-4
l032bh:
    ld a,0fch               ; Set delay
    ld b,001h               ; For 1 row
    call sub_0337h          ; To DISPLAY-5
    dec hl                  ; Back to previous HALT
    ex (sp),hl              ; Waste cycles
    ex (sp),hl
    jp (ix)                 ; Back to R-IX-1 or R-IX-2

; --------------------------
; THE 'DISPLAY-5' SUBROUTINE
; --------------------------

; DISPLAY-5
sub_0337h:
    ld r,a                  ; R= $FC (SLOW mode) or $FC (FAST mode)
    ld a,0ddh               ; Preload next R
    ei                      ; Enable interrupts at the end of lines
    jp (hl)                 ; Jump into the echo display file

; ----------------------------------
; THE 'KEYBOARD SCANNING' SUBROUTINE
; ----------------------------------

; KEYBOARD
sub_033dh:
    ld hl,0ffffh
    ld bc,0fefeh
    in a,(c)                ; Read port $FE, starts VSync pulse
    or 001h                 ; Ignore shift

; EACH-LINE
l0347h:
    or 0e0h
    ld d,a
    cpl
    cp 001h
    sbc a,a
    or b
    and l
    ld l,a
    ld a,h
    and d
    ld h,a
    rlc b
    in a,(c)
    jr c,l0347h
    rra
    rl h

; GET_REGION
    ld a,0ffh               ; Read port $7E
    in a,(07eh)             ; Will return the same as $FE unless there is something different in the Lambda
    rra                     ; Bit 7 => carry (Bit 7 that is the tape input???)
    ccf                     ; carry = !carry
    sbc a,a                 ; A = $FF (PAL) or $00 (NTSC)
    and 018h                ; A = $18       or $00
    add a,01fh              ; A = $37       or $1F
    ld (04028h),a           ; Save this as MARGIN
    ret

; --------------------------
; THE 'FAST' COMMAND ROUTINE
; --------------------------
; FAST
sub_036ch:
    res 6,(iy+03bh)         ; Request FAST mode

; ------------------------------
; THE 'SET FAST MODE' SUBROUTINE
; ------------------------------

; SET-FAST
sub_0370h:
    bit 7,(iy+03bh)         ; Test FAST mode
    ret z                   ; Already in Fast mode
    halt                    ; Synchronise with interrupt

    out (0fdh),a            ; Disable NMI generator (value of A unimportant)
    res 7,(iy+03bh)         ; Set FAST mode
    ret

; --------------
; THE 'REPORT-F'
; --------------

;; REPORT-F
l037dh:
    rst 08h                 ; ERROR-1
    .byte $0D               ; NA - po program NAme supplied.

; --------------------------
; THE 'SAVE COMMAND' ROUTINE
; --------------------------

; SAVE
sub_037fh:
    call sub_0435h
    jr c,l037dh
    ld (iy+009h),0ffh       ; Set version to $FF, indicating Lambda 8300 program
    ex de,hl
    ld de,012cbh            ; five seconds timing value

; HEADER
l038ch:
    call sub_113bh
    jr nc,l03bfh

; DELAY-1
l0391h:
    djnz l0391h
    dec de
    ld a,d
    or e
    jr nz,l038ch

; OUT-NAME
l0398h:
    call sub_03abh
    bit 7,(hl)
    inc hl
    jr z,l0398h
    ld hl,04009h            ; Set HL to first address to go, VERSN

; OUT-PROG
l03a3h:
    call sub_03abh
    call sub_0216h
    jr l03a3h

; -------------------------
; THE 'OUT-BYTE' SUBROUTINE
; -------------------------

; OUT-BYTE
sub_03abh:
    ld e,(hl)
    scf

; EACH-BIT
l03adh:
    rl e
    ret z
    sbc a,a
    and 005h
    add a,004h
    ld c,a

; PULSES
l03b6h:
    out (0ffh),a
    ld b,023h

; DELAY-2
l03bah:
    djnz l03bah
    call sub_113bh

; BREAK-2
l03bfh:
    jr nc,l0433h
    ld b,01eh

; DELAY-3
l03c3h:
    djnz l03c3h
    dec c
    jr nz,l03b6h

; DELAY-4
l03c8h:
    and a
    djnz l03c8h
    jr l03adh

; --------------------------
; THE 'LOAD COMMAND' ROUTINE
; --------------------------

; LOAD
sub_03cdh:
    call sub_0435h          ; Routine NAME
                            ; DE points to start of name in RAM
    rl d                    ; Pick up carry
    rrc d                   ; Carry now in bit 7

; NEXT-PROG
l03d4h:
    call sub_03d9h          ; routine IN-BYTE
    jr l03d4h               ; loop to NEXT-PROG

; ------------------------
; THE 'IN-BYTE' SUBROUTINE
; ------------------------

; IN-BYTE
sub_03d9h:
    ld c,001h               ; Byte counter

; NEXT-BIT
l03dbh:
    ld b,000h               ; Loop 256 times

; BREAK-3
l03ddh:
    ld a,07fh               ; Check the space key
    in a,(0feh)             ;
    out (0ffh),a            ; IO Write triggers VYsnc pulses on screen
    rra                     ; check for space pressed (bit 0->Carry)
    jr nc,l042fh            ; to BREAK-4 if so
    rla                     ; Carry->bit 0
    rla                     ; bit 7->Carry
    jr c,l0412h             ; Forward to GET-BIT if there is data
    djnz l03ddh             ; Loop back and keep checking
    pop af                  ; Drop return address
    cp d                    ; But A holds the value from port FE?

; RESTART
l03eeh:
    jp nc,l04a3h
    ld h,d
    ld l,e

; IN-NAME
l03f3h:
    call sub_03d9h
    bit 7,d
    ld a,c
    jr nz,l03feh
    cp (hl)
    jr nz,l03d4h

; MATCHING
l03feh:
    inc hl
    rla
    jr nc,l03f3h
    inc (iy+015h)
    ld hl,04009h

; IN-PROG
l0408h:
    ld d,b
    call sub_03d9h
    ld (hl),c
    call sub_0216h
    jr l0408h

; GET-BIT
l0412h:
    push de
    ld e,094h

; TRAILER
l0415h:
    ld b,01ah

; COUNTER
l0417h:
    dec e
    in a,(0feh)
    rla
    bit 7,e
    ld a,e
    jr c,l0415h
    djnz l0417h
    pop de
    jr nz,l0429h
    cp 056h
    jr nc,l03dbh

; BIT-DONE
l0429h:
    ccf
    rl c
    jr nc,l03dbh
    ret

; BREAK-4
l042fh:
    ld a,d                  ; Get D
    and a                   ; Test it
    jr z,l03eeh             ; If there has been data, then restart

; REPORT-D
l0433h:
    rst 08h                 ; ERROR-1
    .byte $0C               ; Error Report: BREAK - CONT repeats

; -----------------------------
; THE 'PROGRAM NAME' SUBROUTINE
; -----------------------------

; NAME
sub_0435h:
    call sub_114ah          ; routine SCANNING
    ld a,(04001h)
    add a,a
    jp m,l0f17h             ; to REPORT-C - Invalid Expression
    pop hl
    ret nc
    push hl
    call sub_0370h          ; routine SET-FAST
    call sub_15edh          ; routine STK-FETCH
    ld h,d
    ld l,e
    dec c
    ret m
    add hl,bc
    set 7,(hl)
    ret

; --------------------------
; THE 'MAKE A NOISE' ROUTINE
; --------------------------

; MAKE-NOISE
sub_0450h:
    ld e,020h               ; note = 32500/32 = 1.02KHz
    ld bc,01800h            ; duration = 6144/65 = 94ms
    jr l0460h               ; Routine PLAY-NOTE

; ----------------------------
; THE 'SOUND' COMMAND ROUTINE
; ----------------------------

; SOUND
sub_0457h:
    call sub_1088h          ; routine FIND-INT => BC
    push bc
    call sub_1083h          ; routine FIND-SHORT => A
    pop bc
    ld e,a                  ; INT => E

; PLAY-NOTE
; E = note, defined as 32500Hz/E, so (0=256=>127Hz) to (1=>32.5KHz)
; BC = duration, defined as BC/65ms, so (1=>15ms) to (0=65536=>1 second)
; Appox 4 times slower in SLOW mode
l0460h:
    in a,(0f5h)             ; Toggle beeper on read of $F5
    ld d,e                  ; Note
; PLAY-NOTE-2
l0463h:
    dec bc                  ; Duration
    ld a,b
    or c
    ret z                   ; Return when BC=0
    dec d
    jr z,l0460h             ; Toggle speaker when note countdown complete
    nop
    nop
    jr l0463h               ; Loop until complete


; ---------------
; START CONTINUED
; ---------------

; START-3
l046eh:
    rra                     ; A was read from FE, column 0 -> C
    cpl
    ld (04006h),a           ; set mode
    ld bc,0bfffh            ; top of possible RAM, making max RAM 32K
    jr nc,l0489h            ; skip RAM test if key in column 0 held? autostart expansion ROM?
    ld a,(DFILE)            ; check of there is a DFILE
    cp 076h                 ; should start with a NL/HALT
    jr nz,l0489h            ; no DFILE, so do a cold start
    jr z,l04c0h             ; DFILE present, warm start, skip RAM test

; -------------------------
; THE 'NEW' COMMAND ROUTINE
; -------------------------

; NEW
sub_0481h:
    call sub_0370h          ; Set FAST mode
    ld bc,(04004h)          ; RAMTOP top of detected / protected RAM
    dec bc

; -----------------------
; THE 'RAM CHECK' ROUTINE
; -----------------------

; RAM-CHECK
l0489h:
    ld h,b                  ; HL = BC = last byte to test
    ld l,c
    ld a,03fh               ; stop point, check RAM down to $4000

; RAM-FILL
l048dh:
    ld (hl),002h            ; write 2 to every address in RAM.
    dec hl
    cp h                    ; stop when H=A=$3F
    jr nz,l048dh

; RAM-READ
l0493h:
    and a                   ; reset carry flag
    sbc hl,bc               ; Compare HL and BC
    add hl,bc               ;
    inc hl                  ; HL = 4000 - what was the point in all that?
    jr nc,l04a0h            ; if HL=BC, we're finished?
    dec (hl)                ; Decrement RAM
    jr z,l04a0h             ; Test if RAM was 1, but it would be picked up by the next test anyway?
                            ; I wonder if this was original a test for mirrors? but it doesn't do that now
    dec (hl)                ; Decrement RAM
    jr z,l0493h             ; It was 2 previously, zero now, good RAM, keep checking

; SET-TOP
l04a0h:
    ld (04004h),hl          ; Set RAMTOP, top of usable RAM

; ----------------------------------
; THE 'DFILE INITIALIZATION' ROUTINE
; ----------------------------------

; INIT-DFILE
l04a3h:
    ld hl,04397h            ; Set VARS, starts of variable area
    ld (04010h),hl          ; VARS = $4397 - fixed location after DFILE
    dec hl                  ; HL = 4396, start of program
    ld (hl),0ffh
l04ach:
    ld (0400ch),hl          ; Set PRGRM

; CREATE-DFILE
    ld c,019h               ; 24 lines + 1 extra NL
    xor a                   ; A = 0 = Space

; NEXT-LINE
l04b2h:
    dec hl
    ld (hl),076h            ; start / end with newline / halt
    dec c                   ; line counter
    jr z,l04c0h             ; finished?

; FILL-LINE
    ld b,020h               ; fill line with 32 spaces
l04bah:
    dec hl                  ; step backwards
    ld (hl),a               ; write a space
    djnz l04bah             ; loop until done
    jr l04b2h               ; back for more

; ----------------------------
; THE 'INITIALIZATION' ROUTINE
; ----------------------------

; INITIAL
l04c0h:
    ld hl,(04004h)          ; Get RAMTOP
    dec hl                  ; Move to last system byte
    ld (hl),03eh            ; Set GOSUB end marker
    dec hl                  ; Move down again
    ld sp,hl                ; Set stack here
    dec hl                  ; Move to first location in stack
    dec hl                  ;
    ld (04002h),hl          ; Set error stack pointer ERR_SP
    ; I register is setup here on ZX81, not used on the Lambda,
    ; The character ROM is inside the ULA
    im 1                    ; Z80 interrupt mode 1
    ld iy,04000h            ; Set IY to start of SYS VARS to make access easier
    ld (iy+03bh),040h       ; CDFLAG - compute and display mode requested
    ld (iy+021h),019h       ; Set TEMPO to 25 (25*3.94ms = ~ 100ms)
    xor a                   ; Clear more flags
    ld (04019h),a           ; X_PTR_lo = 0
    ld (0402dh),a           ; FLAGX = 0
    ld (04001h),a           ; FLAGS = 0
    ld (0407ch),a           ; SPARE3 = 0
    dec a                   ; A now $FF
    ld (04035h),a           ; FRAMES_lo = $FF
    call sub_1692h          ; CLEAR
    call sub_0450h          ; MAKE-NOISE
    call sub_0285h          ; SLOW-FAST to set SLOW mode
    ld a,(04006h)           ; check mode
    rra
    jp c,02000h             ; autostart expansion ROM?

l04fch:
    call sub_16a5h          ; CURSOR-IN, set cursor on edit line

; ---------------------------
; THE 'BASIC LISTING' SECTION
; ---------------------------

; UPPER
l04ffh:
    call sub_0bd0h          ; CLS
    ld hl,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    ld de,(04023h)
    and a
    sbc hl,de
    ex de,hl
    jr nc,l0513h
    add hl,de
    ld (04023h),hl

; ADDR-TOP
l0513h:
    call sub_0b6ah
    jr z,l0519h
    ex de,hl

; LIST-TOP
l0519h:
    call sub_08cdh
    dec (iy+01eh)
    jr nz,l0558h            ; routine LOWER
    ld hl,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    call sub_0b6ah
    ld hl,(04016h)
    scf
    sbc hl,de
    ld hl,04023h
    jr nc,l053dh
    ex de,hl
    ld a,(hl)
    inc hl
    ldi
    ld (de),a
    jr l04ffh

; DOWN-KEY
sub_053ah:
    ld hl,04029h            ; E.PPC line number with cursor on (was $400A on ZX81)

; INC-LINE
l053dh:
    ld e,(hl)
    inc hl
    ld d,(hl)
    push hl
    ex de,hl
    inc hl
    call sub_0b6ah
    call sub_0677h
    pop hl

; KEY-INPUT
l054ah:
    bit 5,(iy+02dh)
    jr nz,l0558h            ; routine LOWER
    ld (hl),d
    dec hl
    ld (hl),e
    jr l04ffh

; ----------------------------
; THE 'EDIT LINE COPY' SECTION
; ----------------------------

; EDIT-INP
l0555h:
    call sub_16a5h          ; CURSOR-IN, set cursor on edit line

; LOWER
l0558h:
    ld hl,(04014h)

; EACH-CHAR
l055bh:
    ld a,(hl)
    cp 07eh
    jr nz,l0568h
    ld bc,00006h
    call sub_0bf5h          ; routine RECLAIM-2
    jr l055bh

; END-LINE
l0568h:
    cp 076h
    inc hl
    jr nz,l055bh

; EDIT-LINE
    ; ZX81 sets K or L here - we don't have that

; EDIT-ROOM
l056dh:
    call sub_0bc2h          ; routine LINE-ENDS
    ld hl,(04014h)          ; Get E.LINE, the address of edit line
    ld (iy+000h),0ffh       ; Set error to $FF (OK)
    call sub_08fch          ; routine COPY-LINE
    bit 7,(iy+000h)         ; Check if there was an error
    jr nz,l058dh            ; to DISPLAY-6 if OK
    ld a,(04022h)           ; check DF.SZ, size of editor section
    cp 018h                 ; is it >24 lines
    jr nc,l058dh            ; to DISPLAY-6
    inc a                   ; add a line
    ld (04022h),a           ; update value
    jr l056dh               ; simplified loop back compared to ZX81

; --------------------------
; THE 'WAIT FOR KEY' SECTION
; --------------------------

; DISPLAY-6
l058dh:
    ld hl,00000h            ; clear X.PTR   - Addess of character before syntax error
    ld (04018h),hl          ;
    ld hl,0403bh            ; get CDFLAGS
    bit 7,(hl)              ; check FAST/SLOW mode
    call z,sub_0293h        ; routine PRE-DISPLAY-1 if FAST

; SLOW-DISP
l059bh:
    bit 0,(hl)
    jr z,l059bh             ; Loop unti bit 0 of (HL) is 1
    ld bc,(04025h)
    call sub_1140h          ; routine DEBOUNCE
    call sub_095eh          ; routine DECODE
    jr nc,l0558h            ; routine LOWER
    bit 5,(iy+03bh)         ; Check if we should beep
    jr nz,l05ceh

; KEY-BEEP
    push de                 ; Save DE and HL
    push hl
    call sub_0370h          ; routine SET-FAST
    add a,014h              ; add $14 to the key value
    ld e,a                  ; set the note to that
    ld bc,004ceh            ; set the duration to 18.9ms
    bit 5,(iy+028h)         ; test bit 5 of MARGIN to check region
    jr nz,l05c5h            ; skip if PAL
    ld bc,00406h            ; change duration to 15.9ms
l05c5h:
    call l0460h             ; Routine PLAY-NOTE
    call sub_0285h          ; FAST/SLOW
    pop hl                  ; restore DE and HL
    pop de
    ld a,e                  ; and A is restored to what it was + $14 (is that intentional?)

; variation on FETCH-2
l05ceh:
    bit 2,(iy+001h)         ; Check FLAG K mode = 0, L = 1
    jr z,l05dch             ; skip for K mode
    cp 028h                 ; check for ?
    jr c,l05f2h             ; skip
    ld hl,000a1h
    add hl,de

; FETCH-3
l05dch:
    ld a,(hl)

; TEST-CURS
l05ddh:
    cp 0f0h
    jp pe,l05fbh            ; routine KEY-SORT

; ENTER
    ld e,a
    call sub_0605h          ; routine CURSOR
    ld a,e
    call sub_05edh          ; routine ADD-CHAR

; BACK-NEXT
l05eah:
    jp l0558h               ; back to LOWER

; ------------------------------
; THE 'ADD CHARACTER' SUBROUTINE
; ------------------------------

; ADD-CHAR
sub_05edh:
    call sub_0b2dh
    ld (de),a
    ret

; more variation on FETCH-2
l05f2h:
    ld a,(hl)
    cp 076h                 ; check for NEWLINE
    set 7,a
    jr nz,l05ddh            ; routine TEST-CURS
    ld a,078h

; KEY-SORT
l05fbh:
    ld e,a                  ; DE = key
    ld hl,l0618h - $E0      ; reference to ED-KEYS table
    add hl,de               ; HL = table base - $E0 + 2x key
    add hl,de
    ld c,(hl)               ; BC = function address
    inc hl
    ld b,(hl)
    push bc                 ; push handler function onto stack

; CURSOR
sub_0605h:
    ld hl,(04014h)

; cut down version of TEST-CHAR
l0608h:
    ld a,(hl)
    cp 07fh
    ret z
    inc hl
    call sub_0955h
    jr l0608h

; --------------------------
; THE 'CLEAR-ONE' SUBROUTINE
; --------------------------

; CLEAR-ONE
sub_0612h:
    ld bc,$0001
    jp sub_0bf5h            ; routine RECLAIM-2

; ------------------------
; THE 'EDITING KEYS' TABLE
; ------------------------

; ED-KEYS
l0618h:
    .word sub_0657h         ; UP_KEY
    .word sub_053ah         ; DOWN-KEY
    .word sub_062eh         ; LEFT-KEY
    .word sub_0637h         ; RIGHT-KEY
    .word sub_0667h         ; SET-L-MODE
    .word sub_0680h         ; EDIT-KEY
    .word sub_0713h         ; NEWLINE-KEY
    .word sub_0643h         ; RUBOUT
    .word sub_066dh         ; SET-K-MODE
    .word sub_0700h         ; FUNCTION
    .word sub_06c8h         ; FUNCTION

; -------------------------
; THE 'CURSOR LEFT' ROUTINE
; -------------------------

; LEFT-KEY
sub_062eh:
    call sub_064bh          ; routine LEFT-EDGE
    ld a,(hl)
    ld (hl),07fh
    inc hl
    jr l0640h

; --------------------------
; THE 'CURSOR RIGHT' ROUTINE
; --------------------------

; RIGHT-KEY
sub_0637h:
    inc hl
    ld a,(hl)
    cp 076h
    jr z,l0655h             ; routine ENDED-2
    ld (hl),07fh
    dec hl

; GET-CODE
l0640h:
    ld (hl),a

; ENDED-1
l0641h:
    jr l05eah

; --------------------
; THE 'RUBOUT' ROUTINE
; --------------------

; RUBOUT
sub_0643h:
    call sub_064bh
    call sub_0612h
    jr l0641h

; ------------------------
; THE 'ED-EDGE' SUBROUTINE
; ------------------------

; LEFT-EDGE
sub_064bh:
    dec hl
    ld de,(04014h)
    ld a,(de)
    cp 07fh
    ret nz
    pop de

; ENDED-2
l0655h:
    jr l0641h

; -----------------------
; THE 'CURSOR UP' ROUTINE
; -----------------------

; UP-KEY
sub_0657h:
    ld hl,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    call sub_0b6ah
    ex de,hl
    call sub_0677h
    ld hl,0402ah
    jp l054ah


; --------------------------
; THE 'FUNCTION KEY' ROUTINE
; --------------------------

; Alternatives to the FUNCTION key routine

; SET-L-MODE
sub_0667h:
    set 2,(iy+001h)         ; Enter L mode
    jr l0655h

; SET-K-MODE
sub_066dh:
    res 2,(iy+001h)         ; Enter K mode
    jr l0655h

; ------------------------------------
; THE 'COLLECT LINE NUMBER' SUBROUTINE
; ------------------------------------

; ZERO-DE
l0673h:
    ex de,hl
    ld de,l058dh+1

; LINE-NO
sub_0677h:
    ld a,(hl)
    and 0c0h
    jr nz,l0673h
    ld d,(hl)
    inc hl
    ld e,(hl)
    ret

; ----------------------
; THE 'EDIT KEY' ROUTINE
; ----------------------

; EDIT-KEY
sub_0680h:
    call sub_0bc2h          ; routine LINE-ENDS
    ld hl,l0555h
    push hl
    bit 5,(iy+02dh)
    ret nz
    ld hl,(04014h)
    ld (0400eh),hl
    ld hl,01821h
    ld (04039h),hl
    ld hl,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    call sub_0b6ah
    call sub_0677h
    ld a,d
    or e
    ret z
    dec hl
    call sub_0c35h
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    ld de,(0400eh)
    ld a,07fh
    ld (de),a
    inc de
    push hl
    ld hl,0001dh
    add hl,de
    add hl,bc
    sbc hl,sp
    pop hl
    ret nc
    ldir
    ex de,hl
l06c2h:
    pop de
    call sub_169eh
l06c6h:
    jr l0655h
    ; ZX81 dropped through to N/L-KEY here

; ----------------------
; THE 'EDIT KEY' ROUTINE
; ----------------------

; variation on EDIT-KEY
sub_06c8h:
    bit 5,(iy+02dh)         ; test FLAGX
    jr nz,l06c6h            ; jump back if in INPUT mode

    ld hl,l0555h            ; address of EDIT-INP routine
    push hl                 ; pushed onto stack

    ld hl,(04014h)          ; fetch E-LINE
    ld (0400eh),hl          ; update cursor DF-CC

    ld hl,01821h            ; line 0, column 0
    ld (04039h),hl          ; update S-POSN

    ld hl,(04029h)          ; fetch E.PPC line number with cursor on (was $400A on ZX81)
    ld bc,000Ah
    add hl,bc
    ld b,h
    ld c,l
    ld hl,0270fh
    and a
    sbc hl,bc
    jr nc,l06f2h
    ld bc,0270fh
l06f2h:
    call sub_0c2dh          ; OUT-NUM, print line number
    ld hl,(0400eh)
    ld (hl),07fh
    inc hl
    ld (hl),076h
    inc hl
    jr l06c2h

; ?
sub_0700h:
    ld hl,0402dh            ; FLAGX
    bit 5,(hl)              ; check bit 5
    jp z,l04fch
    res 5,(hl)
    call sub_0bc2h          ; routine LINE-ENDS
    ld hl,04000h
    jp l07bch

; -------------------------
; THE 'NEWLINE KEY' ROUTINE
; -------------------------

; sort of N/L-KEY
sub_0713h:
    call sub_0bc2h          ; routine LINE-ENDS
    ld hl,l0558h            ; routine LOWER
    bit 5,(iy+02dh)         ; check FLAGS
    jr nz,l0722h
    ld hl,l04ffh

l0722h:
    push hl
    call sub_084ah
    bit 5,(iy+02dh)
    jr nz,l073ah
    ld hl,(04014h)
    ld a,(hl)
    cp 0ffh
    jr z,l073ah
    call sub_0a81h
    call sub_0bd0h          ; CLS

; Similar to NOW_SCAN
l073ah:
    call sub_0e3bh
    pop hl
    call sub_0605h
    call sub_0612h
    call sub_0c08h
    jr nz,l075dh
    ld a,b
    or c
    jp nz,l0809h
    dec bc
    dec bc
    ld (04007h),bc
    ld (iy+022h),002h
    ld de,DFILE             ; Hard coded DFILE location
    jr l0770h

; N/L-INP
l075dh:
    cp 076h
    jr z,l0773h
    ld bc,(04030h)
    call sub_0ab7h          ; routine LOC-ADDR
    ld de,(0400ah)
    ld (iy+022h),002h

; TEST-NULL
l0770h:
    rst 18h
    cp 076h

; N/L-NULL
l0773h:
    jp z,l04fch
    ld (iy+001h),081h
    ex de,hl

; NEXT-LINE
l077bh:
    ld (0400ah),hl          ; NXTLIN - Address of next line to be executed (ZX81 was $4029)
    ex de,hl
    call sub_004eh
    call sub_0e42h
    res 1,(iy+001h)
    ld a,0c0h
    ld (iy+019h),000h
    call sub_169bh
    res 5,(iy+02dh)
    bit 7,(iy+000h)
    jr z,l07beh
    ld hl,(0400ah)          ; NXTLIN - Address of next line to be executed (ZX81 was $4029)
    and (hl)
    jr nz,l07beh
    ld d,(hl)
    inc hl
    ld e,(hl)
    ld (04007h),de
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ex de,hl
    add hl,de
    call sub_113bh
    jr c,l077bh
    ld hl,04000h
    bit 7,(hl)
    jr z,l07beh
l07bch:
    ld (hl),00ch

; STOP-LINE
l07beh:
    bit 7,(iy+038h)
    call z,sub_0a11h
    ld bc,00121h
    call sub_0ab7h          ; routine LOC-ADDR
    ld a,(04000h)
    ld bc,(04007h)
    inc a
    jr z,l07e1h
    cp 009h
    jr nz,l07dah
    inc bc

; CONTINUE
l07dah:
    ld (0402bh),bc          ; Set OLDPPC
    jr nz,l07e1h
    dec bc

; REPORT (different to ZX81)
l07e1h:
    rlca                    ; a = 2 * error code
    ld e,a
    ld d,000h
    ld hl,l01f2h            ; address of error code table
    add hl,de               ; HL = table + 2 * error code

    ld a,(hl)               ; print the first letter of the error code
    rst 10h

    inc hl                  ; print the second letter of the error code
    ld a,(hl)
    rst 10h

    bit 7,b                 ; check bit 7 of return address (check for immediate mode?)
    jr nz,l0800h

; IN_LINE
    ld e,004h               ; 4 characters
    ld hl,l0212h            ; table containing " IN "
l07f7h:
    ld a,(hl)               ; get character
    inc hl
    rst 10h                 ; print character
    dec e
    jr nz,l07f7h            ; loop until all done

    call sub_0c2dh          ; OUT-NUM, print line number
l0800h:
    call sub_16a5h          ; CURSOR-IN, set cursor on edit line
    call sub_1140h          ; routine DEBOUNCE
    jp l058dh

; N/L-LINE (sort of)
l0809h:
    ld (04029h),bc          ; E.PPC line number with cursor on (was $400A on ZX81)
    ld hl,(04016h)
    ex de,hl
    ld hl,l04fch
    push hl
    ld hl,(0401ah)
    sbc hl,de
    push hl
    ld h,b
    ld l,c
    call sub_0b6ah
    jr nz,l0828h
    call sub_0b84h
    call sub_0bf5h          ; routine RECLAIM-2

; COPY-OVER
l0828h:
    pop bc
    ld a,c
    dec a
    or b
    ret z
    push bc
    inc bc
    inc bc
    inc bc
    inc bc
    call sub_0b30h          ; MAKE-ROOM
    pop bc
    push bc
    ld hl,(0401ah)
    dec hl
    lddr
    ld hl,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    ex de,hl
    pop bc
    ld (hl),b
    dec hl
    ld (hl),c
    dec hl
    ld (hl),e
    dec hl
    ld (hl),d
    ret

; Not LLIST ?
sub_084ah:
    ld hl,(04014h)
l084dh:
    ld (04016h),hl
    rst 18h
l0851h:
    cp 00bh
    jr nz,l085fh
l0855h:
    rst 20h
    cp 00bh
    jr z,l0875h
    cp 076h
    ret z
    jr l0855h
l085fh:
    cp 076h
    ret z
    ld de,l00f1h            ; token table
    ld c,000h
    jr l0878h
l0869h:
    ld a,(de)
    bit 7,a
    inc de
    jr z,l0869h
    inc c
    ld a,045h
    cp c
    jr nc,l0878h
l0875h:
    rst 20h
    jr l0851h
l0878h:
    ld hl,(04016h)
l087bh:
    ld a,(de)
    ld b,a
    and 07fh
    cp (hl)
    jr nz,l0869h
    inc hl
    inc de
    bit 7,b
    jr z,l087bh
l0888h:
    ld a,(hl)
    and a
    jr nz,l088fh
    inc hl
    jr l0888h
l088fh:
    ld de,(04016h)
    ld (04016h),hl
    ld hl,(04014h)
    and a
l089ah:
    sbc hl,de
    add hl,de
    jr nc,l08a5h
    dec de
    ld a,(de)
    and a
    jr z,l089ah
    inc de
l08a5h:
    ld a,c
    bit 6,a
    jr nz,l08ach
    or 0c0h
l08ach:
    ld (de),a
    inc de
    ld hl,(04016h)
    push af
    call sub_0bf2h
    pop af
    cp 0eah
    ret z
    jr l084dh

; ---------------------------------------
; THE 'LIST' AND 'LLIST' COMMAND ROUTINES
; ---------------------------------------

; LLIST
sub_08bbh:
    set 1,(iy+001h)

; LIST
sub_08bfh:
    call sub_1088h
    ld a,b
    and 03fh
    ld h,a
    ld l,c
    ld (04029h),hl          ; E.PPC line number with cursor on (was $400A on ZX81)
    call sub_0b6ah

; LIST-PROG
sub_08cdh:
    ld e,000h

; UNTIL-END
l08cfh:
    call sub_08d4h
    jr l08cfh

; -----------------------------------
; THE 'PRINT A BASIC LINE' SUBROUTINE
; -----------------------------------

; OUT-LINE
sub_08d4h:
    ld bc,(04029h)          ; E.PPC line number with cursor on (was $400A on ZX81)
    call sub_0b7ch
    ld d,097h
    jr z,l08e4h
    ld de,00000h
    rl e

; TEST-END
l08e4h:
    ld (iy+01eh),e
    ld a,(hl)
    cp 040h
    pop bc
    ret nc
    push bc                 ; rest of function different to ZX81
    ld (04016h),hl          ; CH.ADD - Address of next character to interpret
    call sub_0c35h
    ld a,d
    rst 10h
    ld hl,(04016h)
    inc hl
    inc hl
    inc hl
    inc hl

; COPY-LINE
sub_08fch:
    ld (04016h),hl
    set 0,(iy+001h)

; MORE-LINE
l0903h:
    ld bc,(04018h)
    ld hl,(04016h)
    and a
    sbc hl,bc
    jr nz,l0918h
    ld a,0aah               ; Inverse E
    rst 10h                 ; print character

    call sub_094dh          ; SET-CURSOR
    call sub_0450h          ; MAKE-NOISE

; TEST-NUM
l0918h:
    ld hl,(04016h)
    ld a,(hl)
    inc hl
    call sub_0955h
    ld (04016h),hl
    jr z,l0903h
    cp 07fh
    jr z,l0939h
    cp 076h
    jr z,l098fh
    bit 6,a
    jr z,l0936h
    call sub_0ad7h
    jr l0903h

; NOT-TOKEN
l0936h:
    rst 10h
    jr l0903h

; different to ZX81 from here
l0939h:
    ld a,080h
    bit 2,(iy+001h)
    jr z,l0943h
    ld a,0ach
l0943h:
    dec b
    inc b
    call z,sub_094ah
    jr l0903h
sub_094ah:
    call l0996h

; SET-CURSOR
sub_094dh:
    ld hl,(0400eh)          ; get current character address
    dec hl                  ; move one before that
    ld (0407bh),hl          ; set the blinking cursor to that address
    ret

; -----------------------
; THE 'NUMBER' SUBROUTINE
; -----------------------

; NUMBER
sub_0955h:
    cp 07eh
    ret nz
    inc hl
    inc hl
    inc hl
    inc hl
    inc hl
    ret

; --------------------------------
; THE 'KEYBOARD DECODE' SUBROUTINE
; --------------------------------

; DECODE
sub_095eh:
    ld d,000h
    sra b
    sbc a,a
    or 026h
    ld l,005h
    sub l

; KEY-LINE
l0968h:
    add a,l
    scf
    rr c
    jr c,l0968h
    inc c
    ret nz
    ld c,b
    dec l
    ld l,001h
    jr nz,l0968h
    ld hl,0007ah
    ld e,a
    add hl,de
    scf
    ret

; -------------------------
; THE 'PRINTING' SUBROUTINE
; -------------------------

; LEAD-SP
l097dh:
    ld a,e
    and a
    ret m
    jr l0992h

; OUT-DIGIT
sub_0982h:
    xor a

; DIGIT-INC
l0983h:
    add hl,bc
    inc a
    jr c,l0983h
    sbc hl,bc
    dec a
    jr z,l097dh

; OUT-CODE
sub_098ch:
    ld e,01ch
    add a,e

; OUT-CH
l098fh:
    and a
    jr z,l0996h

; PRINT-CH
l0992h:
    res 0,(iy+001h)

; PRINT-SP
l0996h:
    exx
    push hl
    bit 1,(iy+001h)
    jr nz,l09a3h
    call sub_09a9h
    jr l09a6h

; LPRINT-A
l09a3h:
    call sub_09f2h

; PRINT-EXX
l09a6h:
    pop hl
    exx
    ret

; ENTER-CH
sub_09a9h:
    ld d,a
    ld bc,(04039h)
    ld a,c
    cp 021h
    jr z,l09cdh

; TEST-N/L
l09b3h:
    ld a,076h
    cp d
    jr z,l09e8h
    ld hl,(0400eh)
    cp (hl)
    ld a,d
    jr nz,l09dfh
    dec c
    jr nz,l09dbh
    inc hl
    ld (0400eh),hl
    ld c,021h
    dec b
    ld (04039h),bc

; TEST-LOW
l09cdh:
    ld a,b
    cp (iy+022h)
    jr z,l09d6h
    and a
    jr nz,l09b3h

; REPORT-5
l09d6h:
    ld l,004h
    jp l0059h

; EXPAND-1
l09dbh:
    call sub_0b2dh
    ex de,hl

; WRITE-CH
l09dfh:
    ld (hl),a
    inc hl
    ld (0400eh),hl
    dec (iy+039h)
    ret

; WRITE-N/L
l09e8h:
    ld c,021h
    dec b
    set 0,(iy+001h)
    jp sub_0ab7h            ; routine LOC-ADDR

; --------------------------
; THE 'LPRINT-CH' SUBROUTINE
; --------------------------

; LPRINT-CH
sub_09f2h:
    cp 076h
    jr z,sub_0a11h
    ld c,a
    ld a,(04038h)
    and 07fh
    cp 05ch
    ld l,a
    ld h,040h
    call z,sub_0a11h
    ld (hl),c
    inc l
    ld (iy+038h),l
    ret

; --------------------------
; THE 'COPY' COMMAND ROUTINE
; --------------------------

; COPY
sub_0101h:
    ld d,016h
    ld hl,0407eh
    jr l0a16h

; COPY-BUFF
sub_0a11h:
    ld d,001h
    ld hl,0403ch

; COPY*D
l0a16h:
    call sub_0370h          ; routine SET-FAST
    push bc

; COPY-LOOP
l0a1ah:
    push hl
    xor a
    ld e,a

; COPY-TIME
l0a1dh:
    out (0fbh),a
    pop hl

; COPY-BRK
l0a20h:
    call sub_113bh
    jr c,l0a2ah
    rra
    out (0fbh),a
; REPORT-D2
    rst 08h                 ; ERROR-1
    .byte $0C               ; BK - BreaK

; COPY-CONT
l0a2ah:
    in a,(0fbh)
    add a,a
    jp m,l0a7dh
    jr nc,l0a20h
    push hl
    push de
    ld a,d
    cp 002h
    sbc a,a
    and e
    rlca
    and e
    ld d,a

; COPY-NEXT
l0a3ch:
    ld c,(hl)               ; load character from screen or buffer
    ld a,c                  ; save a copy in C for later test
    inc hl                  ; update pointer for next time
    cp 076h                 ; is this a newline?
    jr z,l0a66h             ; forward to COPY-N/L if it is
    push hl                 ; no NL, so preserve the counter
; different to ZX81 from here
    out (0f6h),a            ; write character code to $F6
    ld a,e                  ; get byte offset (0-7)
    out (0f5h),a            ; write byte offset to F5
    in a,(0f6h)             ; read character data from ULA? (or custom printer?)
    rl c                    ; test backup character code
    jr nc,l0a51h            ; skip if bit 7 was not set
    xor 0ffh                ; bit7 set, invert bits

; back to ZX81 code from here
l0a51h:
    ld c,a
    ld b,008h

; COPY-BITS
l0a54h:
    ld a,d
    rlc c
    rra
    ld h,a

; COPY-WAIT
l0a59h:
    in a,(0fbh)
    rra
    jr nc,l0a59h
    ld a,h
    out (0fbh),a
    djnz l0a54h
    pop hl
    jr l0a3ch

; COPY-N/L
l0a66h:
    in a,(0fbh)
    rra
    jr nc,l0a66h
    ld a,d
    rrca
    out (0fbh),a
    pop de
    inc e
    bit 3,e
    jr z,l0a1dh
    pop bc
    dec d
    jr nz,l0a1ah
    ld a,004h
    out (0fbh),a

; COPY-END
l0a7dh:
    call sub_0285h          ; FAST/SLOW
    pop bc

; -------------------------------------
; THE 'CLEAR PRINTER BUFFER' SUBROUTINE
; -------------------------------------

; CLEAR-PRB
sub_0a81h:
    ld hl,0405ch
    ld (hl),076h
    ld b,020h

; PRB-BYTES
l0a88h:
    dec hl
    ld (hl),000h
    djnz l0a88h
    ld a,l
    set 7,a
    ld (04038h),a
    ret

; -------------------------
; THE 'PRINT AT' SUBROUTINE
; -------------------------

; PRINT-AT
sub_0a94h:
    ld a,017h
    sub b
    jr c,l0aa4h

; TEST-VAL
sub_0a99h:
    cp (iy+022h)
    jp c,l09d6h
    inc a
    ld b,a
    ld a,01fh
    sub c

; WRONG-VAL
l0aa4h:
    jp c,l108eh
    add a,002h
    ld c,a

; SET-FIELD
sub_0aaah:
    bit 1,(iy+001h)
    jr z,sub_0ab7h          ; routine LOC-ADDR
    ld a,05dh
    sub c
    ld (04038h),a
    ret

; ----------------------------
; THE 'LOCATE ADDRESS' ROUTINE
; ----------------------------

; LOC-ADDR  different to ZX81
sub_0ab7h:
    ld (04039h),bc          ; Set S.POSN - Current PRINT position
    ld a,021h
    sub c
    ld c,a
    ld a,018h
    sub b
    ld l,a
    ld h,000h
    ld b,005h
l0ac7h:
    add hl,hl
    djnz l0ac7h
    add hl,bc
    ld c,a
    add hl,bc
    ld bc,0407eh            ; position of top left character (fixed DFILE location)
    add hl,bc               ; add offset to get address of character
    ld (0400eh),hl          ; Set DF.CC - Display file current character
    ld b,000h
    ret

; ------------------------------
; THE 'EXPAND TOKENS' SUBROUTINE
; ------------------------------

; TOKENS
sub_0ad7h:
    push af
    call sub_0b07h
    jr nc,l0ae5h
    bit 0,(iy+001h)
    jr nz,l0ae5h
    xor a
    rst 10h

; ALL-CHARS - different to ZX81
l0ae5h:
    ld a,(bc)
    and 03fh
    rst 10h
    ld a,(bc)
    inc bc
    add a,a
    jr nc,l0ae5h
    ld c,a
    pop af
    cp 0c0h
    jr nc,l0af7h
    cp 043h
    ret nc
l0af7h:
    ld a,c
    cp 01ah
    jr z,l0affh
    cp 038h
    ret c

; TRAIL-SP
l0affh:
    xor a
    set 0,(iy+001h)
    jp l0996h

; TOKEN-ADD
sub_0b07h:
    push hl
    ld hl,l00f0h            ; Tokens table
    bit 7,a
    jr z,l0b11h
    and 03fh

; TEST-HIGH
l0b11h:
    cp 046h                 ; $46 tokens in table
    jr nc,l0b25h
    ld b,a
    inc b

; WORDS
l0b17h:
    bit 7,(hl)
    inc hl
    jr z,l0b17h
    djnz l0b17h
    cp 043h                 ; different offsets here
    jr nc,l0b25h
    cp 016h                 ; and here

; COMP-FLAG
    ccf

; FOUND
l0b25h:
    ld b,h
    ld c,l
    pop hl
    ret nc
    ld a,(bc)
    add a,0e4h
    ret

; --------------------------
; THE 'ONE SPACE' SUBROUTINE
; --------------------------

; ONE-SPACE
sub_0b2dh:
    ld bc,00001h

; --------------------------
; THE 'MAKE ROOM' SUBROUTINE
; --------------------------

; Make room for DE bytes at HL

; MAKE-ROOM
sub_0b30h:
    push hl                 ; Save HL
    call sub_10a0h          ; Routine TEST-ROOM
    pop hl                  ; Restore HL
    call sub_0b3fh          ; Routine POINTERS
    ld hl,(0401ch)          ; STKEND - End of calculator stack
    ex de,hl                ; DE=STKEND, HL=Location of bytes to be moved, BC=number of bytes to move
    lddr                    ; Move bytes
    ret

; -------------------------
; THE 'POINTERS' SUBROUTINE
; -------------------------

; POINTERS
sub_0b3fh:
    push af                 ; Save the Carry from the result of TEST-ROM
    push hl                 ; Save HL, the destination
    ld hl,0400ah            ; NXTLIN - Address of next line to be executed (ZX81 was $4029)
    ld a,00ah               ; Number of pointers to test

; NEXT-PTR
l0b46h:
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex (sp),hl              ; Get destination from stack
    and a                   ; Clear carry flag
    sbc hl,de               ; Subtract and restore to set flags
    add hl,de               ;
    ex (sp),hl              ; Restore destination to stack
    jr nc,l0b5ah            ; skip to PTR-DONE if pointer below destination
; pointer is after point of insertion, so update pointer
    push de                 ; Save DE
    ex de,hl
    add hl,bc               ; move pointer up by BC bytes
    ex de,hl
    ld (hl),d               ; Update the pointer
    dec hl
    ld (hl),e
    inc hl
    pop de                  ; Restore DE

; PTR-DONE
l0b5ah:
    inc hl                  ; Next pointer
    dec a                   ; Reduce number of pointers left to test
    jr nz,l0b46h            ; Back to NEXT-PTR if there are more to do

; all pointers updated
    ex de,hl                ; HL now contains the end of the space to add + overheads
    pop de                  ; DE contains the location of the new space
    pop af
    and a
    sbc hl,de               ; HL now contains the number of bytes required
    ld b,h                  ; BC=HL
    ld c,l
    inc bc                  ; +1
    add hl,de               ; Add back
    ex de,hl                ; Finally DE=End of space, HL=Start of space, BC=Size of space
    ret

; -----------------------------
; THE 'LINE ADDRESS' SUBROUTINE
; -----------------------------

; LINE-ADDR
sub_0b6ah:
    push hl
    ld hl,(0400ch)          ; PRGRM, start of user program
    ld d,h
    ld e,l

; NEXT-TEST
l0b70h:
    pop bc
    call sub_0b7ch
    ret nc
    push bc
    call sub_0b84h
    ex de,hl
    jr l0b70h

; -------------------------------------
; THE 'COMPARE LINE NUMBERS' SUBROUTINE
; -------------------------------------

; CP-LINES
sub_0b7ch:
    ld a,(hl)
    cp b
    ret nz
    inc hl
    ld a,(hl)
    dec hl
    cp c
    ret

; --------------------------------------
; THE 'NEXT LINE OR VARIABLE' SUBROUTINE
; --------------------------------------

; NEXT-ONE
sub_0b84h:
    push hl
    ld a,(hl)
    cp 040h
    jr c,l0ba1h
    bit 5,a
    jr z,l0ba2h
    add a,a
    jp m,l0b93h
    ccf

; NEXT+FIVE
l0b93h:
    ld bc,00005h
    jr nc,l0b9ah
    ld c,011h

; NEXT-LETT
l0b9ah:
    rla
    inc hl
    ld a,(hl)
    jr nc,l0b9ah
    jr l0ba7h

; LINES
l0ba1h:
    inc hl

; NEXT-O-4
l0ba2h:
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl

; NEXT-ADD
l0ba7h:
    add hl,bc
    pop de

; ---------------------------
; THE 'DIFFERENCE' SUBROUTINE
; ---------------------------

; DIFFER
sub_0ba9h:
    and a
    sbc hl,de
    ld b,h
    ld c,l
    add hl,de
    ex de,hl
    ret

; -------------------------------
; THE 'SCROLL COMMAND' SUBROUTINE
; -------------------------------

; scrolling is easy with a fully expanded DFILE
; copy lines 2-24 to 1-23

; SCROLL
sub_0bb1h:
    ld hl,DFILE+022h        ; Source, start of line 2
    ld de,DFILE+1           ; Destination, start of line 1
    ld bc,l02f6h            ; 23*33-1, 23 lines to copy
    ldir                    ; copy
    ld b,(iy+022h)          ; get DF.SZ - Size of editor part of screen
    inc b                   ; increase by 1 row
    jr l0bd2h               ; routine B-LINES, clear the editor lines

; --------------------------
; THE 'LINE-ENDS' SUBROUTINE
; --------------------------

; LINE-ENDS
sub_0bc2h:
    ld b,(iy+022h)
    push bc
    call l0bd2h
    pop bc
    dec b
    ld c,021h
    jp sub_0ab7h            ; routine LOC-ADDR

; -------------------------
; THE 'CLS' COMMAND ROUTINE
; -------------------------

; Different as there is no collapsed display file

; CLS
sub_0bd0h:
    ld b,018h               ; 24 lines

; B-LINES
l0bd2h:
    res 1,(iy+001h)         ; Clear FLAG - printer not in use
    ld (iy+07ch),000h       ; Clear address of blinking curosr
    set 0,(iy+001h)         ; Set FLAG  - Suppress leading space
    ld c,021h
    push bc
    call sub_0ab7h          ; routine LOC-ADDR
    pop bc
    ld c,b

; CLEAR-SCREEN
    xor a                   ; A = 0 = SPACE
l0be7h:
    ld b,020h               ; 32 characters
l0be9h:
    ld (hl),a               ; clear character
    inc hl
    djnz l0be9h             ; loop until EOL
    inc hl                  ; skip over NEWLINE
    dec c                   ; line counter
    jr nz,l0be7h            ; loop back until complete
    ret

; ----------------------------
; THE 'RECLAIMING' SUBROUTINES
; ----------------------------

; RECLAIM-1
sub_0bf2h:
    call sub_0ba9h

; RECLAIM-2
sub_0bf5h:
    push bc
    ld a,b
    cpl
    ld b,a
    ld a,c
    cpl
    ld c,a
    inc bc
    call sub_0b3fh
    ex de,hl
    pop hl
    add hl,de
    push de
    ldir
    pop hl
    ret

; ------------------------------
; THE 'E-LINE NUMBER' SUBROUTINE
; ------------------------------

; E-LINE-NO
sub_0c08h:
    ld hl,(04014h)
    call sub_004eh
    rst 18h
;sub_0c0fh:
    bit 5,(iy+02dh)
    ret nz
    ld hl,0405dh
    ld (0401ch),hl
    call sub_1740h
    call sub_1782h
    jr c,l0c26h
    ld hl,0d8f0h
    add hl,bc

; NO-NUMBER
l0c26h:
    jp c,l0f17h             ; to REPORT-C - Invalid Expression
    cp a
    jp l16b4h

; -------------------------------------------------
; THE 'REPORT AND LINE NUMBER' PRINTING SUBROUTINES
; -------------------------------------------------

; OUT-NUM
sub_0c2dh:
    push de
    push hl
    ; missing call to UNITS here
    ld h,b
    ld l,c
    ld e,0ffh
    jr l0c3dh

; OUT-NO
sub_0c35h:
    push de
    ld d,(hl)
    inc hl
    ld e,(hl)
    push hl
    ex de,hl
    ld e,000h

; THOUSAND
l0c3dh:
    ld bc,0fc18h
    call sub_0982h
    ld bc,0ff9ch
    call sub_0982h
    ld c,0f6h
    call sub_0982h
    ld a,l

; UNITS
    call sub_098ch
    pop hl
    pop de
    ret

; --------------------------
; THE 'UNSTACK-Z' SUBROUTINE
; --------------------------

; UNSTACK-Z
sub_0c55h:
    call sub_0f23h
    pop hl
    ret z
    jp (hl)

; ----------------------------
; THE 'LPRINT' COMMAND ROUTINE
; ----------------------------

; LPRINT
sub_0c5bh:
    set 1,(iy+001h)

; ---------------------------
; THE 'PRINT' COMMAND ROUTINE
; ---------------------------

; PRINT
sub_0c5fh:
    ld a,(hl)
    cp 076h
    jp z,l0d0bh

; PRINT-1
l0c65h:
    sub 01ah
    adc a,000h
    jr z,l0cd1h
    cp 0bah
    jr nz,l0c8ah
    rst 20h
    call sub_0f0fh
    cp 01ah
    jp nz,l0f17h            ; to REPORT-C - Invalid Expression
    rst 20h
    call sub_0f0fh
    call sub_0cdbh
    rst 28h                 ; FP-CALC
    .byte $01               ;;exchange
    .byte $34               ;;end-calc
    call sub_0d7ah
    call sub_0a94h
    jr l0cc4h

; NOT-AT
l0c8ah:
    cp 0bbh                 ; different token on ZX81
    jr nz,l0cbeh
    rst 20h
    call sub_0f0fh
    call sub_0cdbh
    call sub_1083h
    and 01fh
    ld c,a
    bit 1,(iy+001h)
    jr z,l0cabh
    sub (iy+038h)
    set 7,a
    add a,03ch
    call nc,sub_0a11h

; TAB-TEST
l0cabh:
    add a,(iy+039h)
    cp 021h
    ld a,(0403ah)
    sbc a,001h
    call sub_0a99h
    set 0,(iy+001h)
    jr l0cc4h

; NOT-TAB
l0cbeh:
    call sub_114ah          ; routine SCANNING
    call sub_0ce2h

; PRINT-ON
l0cc4h:
    rst 18h
    sub 01ah
    adc a,000h
    jr z,l0cd1h
    call sub_0e9ah          ; routine CHECK-END
    jp l0d0bh

; SPACING
l0cd1h:
    call nc,sub_0d12h
    rst 20h
    cp 076h
    ret z
    jp l0c65h

; SYNTAX-ON
sub_0cdbh:
    call sub_0f23h
    ret nz
    pop hl
    jr l0cc4h

; PRINT-STK
sub_0ce2h:
    call sub_0c55h
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    call z,sub_15edh        ; routine STK-FETCH
    jr z,l0cf6h
    jp l17d3h

; PR-STR-1
; missing ?

; PR-STR-2
l0cf1h:
    rst 10h

; PR-STR-3
l0cf2h:
    ld de,(04018h)

; PR-STR-4
l0cf6h:
    ld a,b
    or c
    dec bc
    ret z
    ld a,(de)
    inc de
    ld (04018h),de
    bit 6,a
    jr z,l0cf1h
    push bc
    call sub_0ad7h
    pop bc
    jr l0cf2h

; PRINT-END
l0d0bh:
    call sub_0c55h
    ld a,076h
    rst 10h
    ret

; FIELD
sub_0d12h:
    call sub_0c55h
    set 0,(iy+001h)
    xor a
    rst 10h
    ld bc,(04039h)
    ld a,c
    bit 1,(iy+001h)
    jr z,l0d2bh
    ld a,05dh
    sub (iy+038h)

; CENTRE
l0d2bh:
    ld c,011h
    cp c
    jr nc,l0d32h
    ld c,001h

; RIGHT
l0d32h:
    call sub_0aaah
    ret

; --------------------------------------
; THE 'PLOT AND UNPLOT' COMMAND ROUTINES
; --------------------------------------

; PLOT/UNP
sub_0d36h:
    call sub_0d7ah
    ld (04036h),bc
    ld a,02bh
    sub b
    jp c,l108eh
    ld b,a
    ld a,001h
    sra b
    jr nc,l0d4ch
    ld a,004h

; COLUMNS
l0d4ch:
    sra c
    jr nc,l0d51h
    rlca

; FIND-ADDR
l0d51h:
    push af
    call sub_0a94h
    ld a,(hl)
    rlca
    cp 010h
    jr nc,l0d61h
    rrca
    jr nc,l0d60h
    xor 08fh

; SQ-SAVED
l0d60h:
    ld b,a

; TABLE-PTR
l0d61h:
    ld de,l0e12h            ; Address: P-UNPLOT
    ld a,(04030h)
    sub e
    jp m,l0d70h
    pop af
    cpl
    and b
    jr l0d72h

; PLOT
l0d70h:
    pop af
    or b

; UNPLOT
l0d72h:
    cp 008h
    jr c,l0d78h
    xor 08fh

; PLOT-END
l0d78h:
    ; Missing EXX before and after RST 10H
    rst 10h
    ;
    ret

; ----------------------------
; THE 'STACK-TO-BC' SUBROUTINE
; ----------------------------

; STK-TO-BC
sub_0d7ah:
    call sub_1083h
    ld b,a
    push bc
    call sub_1083h
    pop bc                  ; missing setting E and D to previous values of C
    ld c,a
    ret

; -------------------
; THE 'SYNTAX' TABLES
; -------------------

; i) The Offset table

; offset-t
l0d85h:
    .byte    l0da9h - $     ; offset of $24 for TEMPO
    .byte    l0dadh - $     ; offset of $27 for MUSIC
    .byte    l0db0h - $     ; offset of $29 for SOUND
    .byte    l0db6h - $     ; offset of $2E for BEEP
    .byte    l0db9h - $     ; offset of $30 for NOBEEP
    .byte    l0e28h - $     ; offset of $9E for LPRINT
    .byte    l0e2bh - $     ; offset of $A0 for LLIST
    .byte    l0dcch - $     ; offset of $40 for STOP
    .byte    l0e1fh - $     ; offset of $92 for SLOW
    .byte    l0e22h - $     ; offset of $94 for FAST
    .byte    l0debh - $     ; offset of $5C for NEW
    .byte    l0e18h - $     ; offset of $88 for SCROLL
    .byte    l0e03h - $     ; offset of $72 for CONT
    .byte    l0de5h - $     ; offset of $53 for DIM
    .byte    l0de8h - $     ; offset of $55 for REM
    .byte    l0dd2h - $     ; offset of $3E for FOR
    .byte    l0dbfh - $     ; offset of $2A for GOTO
    .byte    l0dc8h - $     ; offset of $32 for GOSUB
    .byte    l0de1h - $     ; offset of $4A for INPUT
    .byte    l0dfdh - $     ; offset of $65 for LOAD
    .byte    l0df1h - $     ; offset of $58 for LIST
    .byte    l0dbch - $     ; offset of $22 for LET
    .byte    l0e1bh - $     ; offset of $80 for PAUSE
    .byte    l0ddah - $     ; offset of $3E for NEXT
    .byte    l0df4h - $     ; offset of $57 for POKE
    .byte    l0ddeh - $     ; offset of $40 for PRINT
    .byte    l0e0ch - $     ; offset of $6D for PLOT
    .byte    l0deeh - $     ; offset of $4E for RUN
    .byte    l0e00h - $     ; offset of $5F for SAVE
    .byte    l0dfah - $     ; offset of $58 for RAND
    .byte    l0dc3h - $     ; offset of $20 for IF
    .byte    l0e09h - $     ; offset of $65 for CLS
    .byte    l0e12h - $     ; offset of $6D for UNPLOT
    .byte    l0e06h - $     ; offset of $60 for CLEAR
    .byte    l0dcfh - $     ; offset of $28 for RETURN
    .byte    l0e25h - $     ; offset of $7D for COPY

; P-TEMPO
l0da9h:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_105ch      ; TEMPO

; P-MUSIC
l0dadh:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0f4dh      ; MUSIC

; P-SOUND
l0db0h:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $1A            ; Separator:  ','
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word   sub_0457h       ; SOUND

l0db6h:
; P-BEEP
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1131h      ; BEEP

; P-NOBEEP
l0db9h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1136h      ; NOBEEP

; P-LET
l0dbch:
    .byte    $01            ; Class-01 - A variable is required.
    .byte    $14            ; Separator:  '='
    .byte    $02            ; Class-02 - An expression, numeric or string, must follow.
                            ; no function to call
; P-GOTO
l0dbfh:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1068h      ; GOTO

; P-IF
l0dc3h:
    .byte    $06            ; Class-06 - A numeric expression must follow.          ;
    .byte    $40            ; Separator:  'THEN' ($DE on ZX81)
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0e2eh      ; IF

; P-GOSUB
l0dc8h:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1090h      ; GOSUB

; P-STOP
l0dcch:
    .byte    $00            ; Class-00 - No further operands.;
    .word    sub_0e91h      ; STOP

; P-RETURN
l0dcfh:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_10b3h      ; RETURN

; P-FOR
l0dd2h:
    .byte    $04            ; Class-04 - A single character variable must follow.
    .byte    $14            ; Separator:  '='
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $41            ; Separator:  'TO' (was $DF on ZX81)
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0fc9h      ; FOR

; P-NEXT
l0ddah:
    .byte    $04            ; Class-04 - A single character variable must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_100eh      ; NEXT

; P-PRINT
l0ddeh:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0c5fh      ; PRINT

; P-INPUT
l0de1h:
    .byte    $01            ; Class-01 - A variable is required.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_10c4h      ; INPUT

; P-DIM
l0de5h:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_15feh      ;

; P-REM
l0de8h:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0ee7h      ; REM

; P-NEW
l0debh:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0481h      ; NEW

; P-RUN
l0deeh:
    .byte    $03            ; Class-03 - A numeric expression may follow else default to zero.
    .word    sub_168fh      ; RUN

; P-LIST
l0df1h:
    .byte    $03            ; Class-03 - A numeric expression may follow else default to zero.
    .word    sub_08bfh      ; LIST

; P-POKE
l0df4h:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $1A            ; Separator:  ','
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1079h      ; POKE

; P-RAND
l0dfah:
    .byte    $03            ; Class-03 - A numeric expression may follow else default to zero.
    .word    sub_104Ch      ; RAND

; P-LOAD
l0dfdh:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_03cdh      ; LOAD

; P-SAVE
l0e00h:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_037fh      ; SAVE

; P-CONT
l0e03h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1063h      ; CONT

; P-CLEAR
l0e06h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_1692h      ; CLEAR

; P-CLS
l0e09h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0bd0h      ; CLS

; P-PLOT
l0e0ch:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $1A            ; Separator:  ','
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0d36h      ; PLOT/UNPLOT

; P-UNPLOT
l0e12h:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $1A            ; Separator:  ','
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0d36h      ; PLOT/UNPLOT

; P-SCROLL
l0e18h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0bb1h      ; SCROLL

; P-PAUSE
l0e1bh:
    .byte    $06            ; Class-06 - A numeric expression must follow.
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_10feh      ; PAUSE

; P-SLOW
l0e1fh:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0281h      ; SLOW

; P-FAST
l0e22h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_036ch      ; FAST

; P-COPY
l0e25h:
    .byte    $00            ; Class-00 - No further operands.
    .word    sub_0101h      ; COPY

; P-LPRINT
l0e28h:
    .byte    $05            ; Class-05 - Variable syntax checked entirely by routine.
    .word    sub_0c5bh      ; LPRINT

; P-LLIST
l0e2bh:
    .byte    $03            ; Class-03 - A numeric expression may follow else default to zero.
    .word    sub_08bbh      ; LLIST

; ------------------------
; THE 'IF' COMMAND ROUTINE
; ------------------------

; IF
sub_0e2eh
    call sub_0f23h
    jr z,l0e39h
    rst 28h                 ; FP-CALC
    .byte    $02            ;;delete
    .byte    $34            ;;end-calc
    ld a,(de)
    and a
    ret z

; IF-END
l0e39h:
    jr l0e53h

; ---------------------------
; THE 'LINE SCANNING' ROUTINE
; ---------------------------

; LINE-SCAN
sub_0e3bh:
    ld (iy+001h),001h
    call sub_0c08h
sub_0e42h:
    call l16b4h
    ld hl,04000h
    ld (hl),0ffh
    ld hl,0402dh
    bit 5,(hl)
    ld a,(hl)
    jp nz,l0eech
l0e53h:
    rst 18h
    ld b,000h
    cp 076h
    ret z
    ld c,a
    cp 040h
    ld a,0f1h
    jr c,l0e62h
    rst 20h
    ld a,c
l0e62h:
    sub 0dch
    jr c,l0ea3h
    ld c,a
    ld hl,l0d85h
    add hl,bc
    ld c,(hl)
    add hl,bc
    jr l0e72h
l0e6fh:
    ld hl,(04030h)
l0e72h:
    ld a,(hl)
    inc hl
    ld (04030h),hl
    ld bc,l0e6fh
    push bc
    ld c,a
    cp 00bh
    jr nc,l0e8bh
    ld hl,l0e93h
    ld b,000h
    add hl,bc
    ld c,(hl)
    add hl,bc
    push hl
    rst 18h
    ret
l0e8bh:
    rst 18h
    cp c
    jr nz,l0ea3h
    rst 20h
    ret

; --------------------------
; THE 'STOP' COMMAND ROUTINE
; --------------------------

; STOP
sub_0e91h:
    rst 08h                 ; ERROR-1
    .byte $08               ; ST - STopped

; -------------------------
; THE 'COMMAND CLASS' TABLE
; -------------------------

; class-tbl
l0e93h:
    .byte sub_0eaah - $     ; offset of $17 to CLASS-0
    .byte sub_0eb9h - $     ; offset of $25 to CLASS-1
    .byte sub_0ee8h - $     ; offset of $53 to CLASS-2
    .byte sub_0ea5h - $     ; offset of $0F to CLASS-3
    .byte sub_0f02h - $     ; offset of $6B to CLASS-4
    .byte sub_0eabh - $     ; offset of $13 to CLASS-5
    .byte sub_0f0fh - $     ; offset of $76 to CLASS-6

; --------------------------
; THE 'CHECK END' SUBROUTINE
; --------------------------

; CHECK-END
sub_0e9ah:
    call sub_0f23h
    ret nz
    pop bc

; CHECK-2
l0e9fh:
    ld a,(hl)
    cp 076h
    ret z

; REPORT-C2
l0ea3h:
    jr l0f17h               ; to REPORT-C - Invalid Expression

; --------------------------
; COMMAND CLASSES 03, 00, 05
; --------------------------

; CLASS-3
sub_0ea5h:
    cp 076h
    call sub_0f19h

; CLASS-0
sub_0eaah:
    cp a

; CLASS-5
sub_0eabh:
    pop bc
    call z,sub_0e9ah        ; routine CHECK-END
    ex de,hl
    ld hl,(04030h)
    ld c,(hl)
    inc hl
    ld b,(hl)
    ex de,hl

; CLASS-END
l0eb7h:
    push bc
    ret

; ------------------------------
; COMMAND CLASSES 01, 02, 04, 06
; ------------------------------

; CLASS-1
sub_0eb9h:
    call 01311h

; CLASS-4-2
l0ebch:
    ld (iy+02dh),000h
    jr nc,$+10
    set 1,(iy+02dh)
    jr nz,l0ee0h


; REPORT-2
l0ec8h:
    rst 08h                 ; ERROR-1
    .byte $01               ; UV - Unidentified Variable

; SET-STK
    call z,sub_139ch
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    jr nz,l0ee0h
    xor a
    call sub_0f23h
    call nz,sub_15edh       ; routine STK-FETCH
    ld hl,0402dh
    or (hl)
    ld (hl),a
    ex de,hl

; SET-STRLN
l0ee0h:
    ld (0402eh),bc
    ld (04012h),hl
    ; drops through

; THE 'REM' COMMAND ROUTINE

; REM
sub_0ee7h:
    ret

; CLASS-2
sub_0ee8h:
    pop bc
    ld a,(04001h)

; INPUT-REP
l0eech:
    push af
    call sub_114ah          ; routine SCANNING
    pop af
    ld bc,l1516h
    ld d,(iy+001h)
    xor d
    and 040h
    jr nz,l0f17h            ; to REPORT-C - Invalid Expression
    bit 7,d
    jr nz,l0eb7h
    jr l0e9fh

; CLASS-4
sub_0f02h:
    call 01311h
    push af
    ld a,c
    or 09fh
    inc a
    jr nz,l0f17h            ; to REPORT-C - Invalid Expression
    pop af
    jr l0ebch

; CLASS-6
sub_0f0fh:
    call sub_114ah          ; routine SCANNING
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    ret nz

; REPORT-C
l0f17h:
    rst 08h                 ; ERROR-1
    .byte $0B               ; IE - Invalid Expression

; --------------------------------
; THE 'NUMBER TO STACK' SUBROUTINE
; --------------------------------

; NO-TO-STK
sub_0f19h:
    jr nz,sub_0f0fh
    call sub_0f23h
    ret z
    rst 28h                 ; FP-CALC
    .byte $A0               ;;stk-zero
    .byte $34               ;;end-calc
    ret

; -------------------------
; THE 'SYNTAX-Z' SUBROUTINE
; -------------------------

; SYNTAX-Z
sub_0f23h:
    bit 7,(iy+001h)
    ret

; ---------------------
; MORE 'MUSIC' ROUTINES
; ---------------------

; MUSIC-TABLE
l0f28h:
    .byte $94               ; A
    .byte $8B               ; A#
    .byte $84               ; B
    .byte $7C               ; B#
    .byte $F8               ; C
    .byte $EB               ; C#
    .byte $DD               ; D
    .byte $D1               ; D#
    .byte $C5               ; E
    .byte $BA               ; (=F)
    .byte $BA               ; F
    .byte $B0               ; F#
    .byte $A6               ; G
    .byte $9D               ; G#

; MUSIC-9
sub_0f36h:
    cp 026h
    ret nc
    sub 01ch
    ccf
    ret

; MUSIC-10
l0f3dh:
    ld a,b
    or c
    ret z                   ; return if A and B are 0
    ld a,(hl)               ; get character
    inc hl                  ; step pointer
    dec bc                  ; decrement length
    and a                   ; check character
    ret nz                  ; return if not a space
    jr l0f3dh               ; to MUSIC-10

; MUSIC-11
sub_0f47h:
    call l0f3dh             ; to MUSIC-10
    ret nz

; REPORT-MF
l0f4bh:
    rst 08h                 ; ERROR-1
    .byte $0E               ; MF - Music Format incorrect

; ---------------------------
; THE 'MUSIC' COMMAND ROUTINE
; ---------------------------

; MUSIC
sub_0f4dh:
    call sub_114ah          ; routine SCANNING
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    jr nz,l0f17h            ; to REPORT-C - Invalid Expression
    call sub_0e9ah          ; routine CHECK-END
    call sub_15edh          ; routine STK-FETCH
    ex de,hl                ; DE now start address, HL string length
    call sub_0370h          ; routine SET-FAST

; MUSIC-1
l0f60h:
    call l0f3dh             ; routine MUSIC-10 (get next character)
    jp z,sub_0285h          ; check in FAST mode
    cp 01bh                 ; is character '"'
    ld e,001h
    jr z,l0f8eh             ; to MUSIC-2 if it is
    rlca                    ; character x2
    cp 05ah                 ; Before the rotate, A would have been $2D, 'H', so checking A-G
    jr nc,l0f4bh            ; to REPORT, Music Format incorrect
    sub 04ch
    jr c,l0f4bh             ; to REPORT, Music Format incorrect

; get note
    push hl
    ld d,000h
    ld e,a
    ld hl,l0f28h            ; address of MUSIC-TABLE
    add hl,de               ; offset by 2x letter - 4C
    ld e,(hl)               ; get note
    pop hl

    call sub_0f47h          ; routine MUSIC-11
    cp 013h                 ; is character '<'
    jr z,l0f8eh             ; to MUSIC-2 if it is
    srl e                   ; down an octave
    cp 012h                 ; is character '>'
    jr nz,l0f91h            ; to MUSIC-3 if it isn't
    srl e                   ; down an octave

; MUSIC-2
l0f8eh:
    call sub_0f47h          ; routine MUSIC-11

; MUSIC-3 - get duration
l0f91h:
    call sub_0f36h          ; routine MUSIC-9
    jr nc,l0f4bh            ; to REPORT, Music Format incorrect
    ld d,a
    call l0f3dh             ; routine MUSIC-10
    jr z,l0faeh             ; to MUSIC-5
    call sub_0f36h          ; routine MUSIC-9
    jr c,l0fa5h
    dec hl
    inc bc
    jr l0faeh               ; to MUSIC-5

; MUSIC-4
l0fa5h:
    sla d
    add a,d
    sla d
    sla d
    add a,d
    ld d,a

; MUSIC-5 - play note
l0faeh:
    push hl
    push bc
    ld h,d                  ; prepare note
    ld l,(iy+021h)          ; TEMPO
    ld c,000h
    ld d,e

; MUSIC-6
l0fb7h:
    ld b,l
; by this point E = note (adjusted from table), BC = duration (from TEMPO)
    call l0463h             ; routine PLAY-NOTE-2
    dec h
    jr nz,l0fb7h            ; loop back to MUSIC-6
    ld b,005h

; MUSIC-7
l0fc0h:
    dec bc
    ld a,b
    or c
    jr nz,l0fc0h            ; loop until BC = 0
    pop bc
    pop hl
    jr l0f60h               ; back to MUSIC-1


; -------------------------
; THE 'FOR' COMMAND ROUTINE
; -------------------------

; FOR
sub_0fc9h:
    cp 042h                 ; STEP ($E0 on ZX81)
    jr nz,l0fd6h
    rst 20h
    call sub_0f0fh
    call sub_0e9ah          ; routine CHECK-END
    jr l0fdch

; F-USE-ONE
l0fd6h:
    call sub_0e9ah          ; routine CHECK-END
    rst 28h                 ; FP-CALC
    .byte $A1               ;;stk-one
    .byte $34               ;;end-calc

; F-REORDER
l0fdch:
    rst 28h                 ; FP-CALC      v, l, s.
    .byte $C0               ;;st-mem-0      v, l, s.
    .byte $02               ;;delete        v, l.
    .byte $01               ;;exchange      l, v.
    .byte $E0               ;;get-mem-0     l, v, s.
    .byte $01               ;;exchange      l, s, v.
    .byte $34               ;;end-calc      l, s, v.
    call l1516h
    ld (0401fh),hl
    dec hl
    ld a,(hl)
    set 7,(hl)
    ld bc,00006h
    add hl,bc
    rlca
    jr c,l0ffah
    sla c
    call sub_0b30h          ; MAKE-ROOM
    inc hl

; F-LMT-STP
l0ffah:
    push hl
    rst 28h                 ; FP-CALC
    .byte $02               ;;delete
    .byte $02               ;;delete
    .byte $34               ;;end-calc
    pop hl
    ex de,hl
    ld c,00ah
    ldir
    ld hl,(04007h)
    ex de,hl
    inc de
    ld (hl),e
    inc hl
    ld (hl),d
    ret                     ; skips call to NEXT-LOOP

; --------------------------
; THE 'NEXT' COMMAND ROUTINE
; --------------------------

; NEXT
sub_100eh:
    bit 1,(iy+02dh)
    jp nz,l0ec8h
    ld hl,(04012h)
    bit 7,(hl)
    jr z,l1038h
    inc hl
    ld (0401fh),hl
    rst 28h                 ; FP-CALC
    .byte $E0               ;;get-mem-0
    .byte $E2               ;;get-mem-2
    .byte $0F               ;;addition
    .byte $C0               ;;st-mem-0
    .byte $02               ;;delete
    .byte $34               ;;end-calc
    call sub_103ah
    ret c
    ld hl,(0401fh)
    ld de,0000fh
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl
    jr l106dh

; REPORT-1
l1038h:
    rst 08h                 ; ERROR-1
    .byte $00               ; NF - Next without For

; --------------------------
; THE 'NEXT-LOOP' SUBROUTINE
; --------------------------

; NEXT-LOOP
sub_103ah:
    rst 28h                 ; FP-CALC
    .byte $E1               ;;get-mem-1
    .byte $E0               ;;get-mem-0
    .byte $E2               ;;get-mem-2
    .byte $32               ;;less-0
    .byte $00               ;;jump-true
    .byte $02               ;;to LMT-V-VAL
    .byte $01               ;;exchange
; LMT-V-VAL
    .byte $03               ;;subtract
    .byte $33               ;;greater-0
    .byte $00               ;;jump-true
    .byte $04               ;;to L0E69, IMPOSS
    .byte $34               ;;end-calc

    and a
    ret

; ?
    inc (hl)
    scf
    ret

; --------------------------
; THE 'RAND' COMMAND ROUTINE
; --------------------------

; RAND
sub_104Ch:
    call sub_1088h
    ld a,b
    or c
    jr nz,l1057h
    ld bc,(04034h)          ; If 0, use FRAMES value

; SET-SEED
l1057h:
    ld (04032h),bc          ; Store SEED
    ret


; ---------------------------
; THE 'TEMPO' COMMAND ROUTINE
; ---------------------------

; TEMPO
sub_105ch:
    call sub_1083h
    ld (04021h),a
    ret

; --------------------------
; THE 'CONT' COMMAND ROUTINE
; --------------------------

; CONT
sub_1063h:
    ld hl,(0402bh)
    jr l106dh

; --------------------------
; THE 'GOTO' COMMAND ROUTINE
; --------------------------

; GOTO
sub_1068h:
    call sub_1088h
    ld h,b
    ld l,c

; GOTO-2
l106dh:
    ld a,h
    cp 028h
    jr nc,l108eh
    call sub_0b6ah
    ld (0400ah),hl          ; NXTLIN - Address of next line to be executed (ZX81 was $4029)
    ret

; --------------------------
; THE 'POKE' COMMAND ROUTINE
; --------------------------
; POKE
sub_1079h
    call sub_1083h
    ; missing negative checks
    push af
    call sub_1088h
    pop af
    ; missing code that was in the ZX81 ROM, left over from the ZX80 and not requried
    ld (bc),a
    ret

; FIND-SHORT
sub_1083h:
    call sub_17c5h          ; routine FP-TO-A
    jr l108bh

; -----------------------------
; THE 'FIND INTEGER' SUBROUTINE
; -----------------------------

; FIND-INT
sub_1088h:
    call sub_1782h          ; routine FP-TO-BC
l108bh:
    jr c,l108eh             ; error
    ret z                   ; Return if valid (0-65535)

; REPORT-B
l108eh:
    rst 08h                 ; ERROR-1
    .byte $0A               ; IR - Integer out of Range

; ---------------------------
; THE 'GOSUB' COMMAND ROUTINE
; ---------------------------

; GOSUB
sub_1090h:
    ld hl,(04007h)
    inc hl
    ex (sp),hl
    push hl
    ld (04002h),sp
    call sub_1068h
    ld bc,00006h

; --------------------------
; THE 'TEST ROOM' SUBROUTINE
; --------------------------

; TEST-ROOM
sub_10a0h:
    ld hl,(0401ch)          ; Get STKEND - End of calculator stack
    add hl,bc               ; Add the number of bytes space needed
    jr c,l10aeh             ; to REPORT-4
    ex de,hl                ; Save HL
    ld hl,00024h            ; Safety margin past the end of stack?
    add hl,de               ; Add this margin to the bytes required
    sbc hl,sp               ; Subtract the she stack pointer from the new total
    ret c                   ; Return with carry set if there is room, if not OM error

; REPORT-4
l10aeh:
    ld l,003h               ; Raise OM - Out of Memory
    jp l0059h               ; to ERROR-3

; ----------------------------
; THE 'RETURN' COMMAND ROUTINE
; ----------------------------

; RETURN
sub_10b3h:
    pop hl
    ex (sp),hl
    ld a,h
    cp 03eh
    jr z,l10c0h
    ld (04002h),sp
    jr l106dh

; REPORT-7
l10c0h:
    ex (sp),hl
    push hl
    rst 08h                 ; ERROR-1
    .byte   $06             ; RG - RETURN without GOSUB

; ---------------------------
; THE 'INPUT' COMMAND ROUTINE
; ---------------------------

; INPUT
sub_10c4h:
    bit 7,(iy+008h)
    jr nz,l10fch
    call sub_169bh
    ld hl,0402dh
    set 5,(hl)
    res 6,(hl)
    ld a,(04001h)
    and 040h
    ld bc,00002h
    jr nz,l10e0h
    ld c,004h
l10e0h:
    or (hl)
    ld (hl),a
    rst 30h
    ld (hl),076h
    ld a,c
    rrca
l10e7h:
    rrca
    jr c,l10efh
    ld a,00bh
    ld (de),a
    dec hl
    ld (hl),a
l10efh:
    dec hl
    ld (hl),07fh
    ld hl,(04039h)
    ld (04030h),hl
    pop hl
    jp l0558h               ; routine LOWER

l10fch:
    rst 08h                 ; ERROR-1
    .byte $07               ; II - Illegal Input

; ---------------------------
; THE 'PAUSE' COMMAND ROUTINE
; ---------------------------

; PAUSE
sub_10feh:
    call sub_1088h          ; routine FIND-INT => BC
    ld hl,0403bh            ; CDFLAG
    bit 7,(hl)              ; check FAST mode
    jr nz,l1116h            ; skip to PAUSE-3 if slow
    inc bc                  ; Pause value++
    ld (04034h),bc          ; Store this in the frame counter
    call sub_0293h          ; Routine PRE-DISPLAY-1

; PAUSE-2
l1110h:
    ld (iy+035h),0ffh       ; COORDS - Last point plotted?
    jr sub_1140h            ; routine DEBOUNCE

; PAUSE-3
l1116h:
    ld a,b                  ; A = bit 7 of B
    and 080h
    ld d,a                  ; D = old bit 7 of B
    set 7,b                 ; Set bit 7, indicatin PAUSE mode
    ld (04034h),bc          ; Alternate value in frame counter

; PAUSE-4
l1120h:
    ld bc,(04034h)          ; Get frame counter
    res 7,b                 ; ignore bit 7
    ld a,b                  ; check if MSB
    or c                    ; LSB
    or d                    ; and old bit 7 are all zero (i.e. we have waited long enough)
    jr z,l1110h             ; finished, back to PAUSE-2
    ld a,(hl)               ; get CDFLAG
    rra                     ; test bit 7 for fast mode
    jr c,l1110h             ; finished, back to PAUSE-2
    jr l1120h               ; loop back to PAUSE-4

; ---------------------------------
; THE 'BEEP' AND 'NOBEEP' FUNCTIONS
; ---------------------------------

; These functions use bit 5 of the CDFLAG to control the keyboard sounds
; 0 to make sounds, 1 for silence

; BEEP
sub_1131h:
    res 5,(iy+03bh)         ; Clear bit 5 of CDFLAG
    ret

; NOBEEP
sub_1136h:
    set 5,(iy+03bh)         ; Set bit 5 of CDFLAG
    ret

; ----------------------
; THE 'BREAK' SUBROUTINE
; ----------------------

; BREAK-1
sub_113bh:
    ld a,07fh
    in a,(0feh)
    rra

; -------------------------
; THE 'DEBOUNCE' SUBROUTINE
; -------------------------

; DEBOUNCE
sub_1140h:
    res 0,(iy+03bh)
    ld a,0ffh
    ld (04027h),a
    ret

; -------------------------
; THE 'SCANNING' SUBROUTINE
; -------------------------

; SCANNING
sub_114ah:
    rst 18h
    ld b,000h
    push bc

; S-LOOP-1
l114eh:
    cp 043h
    jr nz,l1181h

; ------------------
; THE 'RND' FUNCTION
; ------------------
    call sub_0f23h
    jr z,l117fh
    ld bc,(04032h)
    call sub_1718h
    rst 28h                 ; FP-CALC
    .byte    $A1            ;;stk-one
    .byte    $0F            ;;addition
    .byte    $30            ;;stk-data
    .byte    $37            ;;Exponent: $87, Bytes: 1
    .byte    $16            ;;(+00,+00,+00)
    .byte    $04            ;;multiply
    .byte    $30            ;;stk-data
    .byte    $80            ;;Bytes: 3
    .byte    $41            ;;Exponent $91
    .byte    $00,$00,$80    ;;(+00)
    .byte    $2E            ;;n-mod-m
    .byte    $02            ;;delete
    .byte    $A1            ;;stk-one
    .byte    $03            ;;subtract
    .byte    $2D            ;;duplicate
    .byte    $34            ;;end-calc
    call sub_1782h
    ld (04032h),bc
    ld a,(hl)
    and a
    jr z,l117fh
    sub 010h
    ld (hl),a
l117fh:
    jr l118eh

; S-TEST-PI
l1181h:
    cp 045h
    jr nz,l1192h

; -------------------
; THE 'PI' EVALUATION
; -------------------

    call sub_0f23h
    jr z,l118eh
    rst 28h                 ; FP-CALC
    .byte $A3               ;;stk-pi/2
    .byte $34               ;;end-calc
    inc (hl)

; S-PI-END
l118eh:
    rst 20h
    jp l1278h


; not S-TST-INK
l1192h:
    cp 044h
    jr nz,l11a7h
    call sub_033dh
    ld b,h
l119ah:
    ld c,l
    ld d,c
    inc d
    call nz,sub_095eh       ; routine DECODE
    ld a,d
    adc a,d
    ld b,d
    ld c,a
    ex de,hl
    jr l11e2h

; S-ALPHANUM
l11a7h:
    call sub_16cah
    jr c,l121ah
    cp 01bh
    jp z,l123ch
    ld bc,009d8h
    cp 016h
    jr z,l1215h
    cp 010h
    jr nz,l11cbh
    call sub_004ah
    call sub_114ah          ; routine SCANNING
    cp 011h
    jr nz,l11f4h
    call sub_004ah
    jr l11edh

; S-QUOTE
l11cbh:
    cp 00bh
    jr nz,l11f7h
    call sub_004ah
    push hl
    jr l11d8h

; S-Q-AGAIN
l11d5h:
    call sub_004ah

; S-QUOTE-S
l11d8h:
    cp 00bh
    jr nz,l11f0h
    pop de
    and a
    sbc hl,de
    ld b,h
    ld c,l

; S-STRING
l11e2h:
    ld hl,04001h
    res 6,(hl)
    bit 7,(hl)
    call nz,sub_14b8h
    rst 20h

; S-J-CONT-3
l11edh:
    jp l127dh

; S-Q-NL
l11f0h:
    cp 076h
    jr nz,l11d5h

; S-RPT-C
l11f4h:
    jp l0f17h               ; to REPORT-C - Invalid Expression

; S-FUNCTION
l11f7h:
    sub 0c0h
    jr c,l11f4h
    ld bc,004ech
    cp 013h
    jr z,l1215h
    jr nc,l11f4h
    ld b,010h
    add a,0d9h
    ld c,a
    cp 0dch
    jr nc,l120fh
    res 6,c

; S-NO-TO-$
l120fh:
    cp 0eah
    jr c,l1215h
    res 7,c

; S-PUSH-PO
l1215h:
    push bc
    rst 20h
    jp l114eh

; S-LTR-DGT
l121ah:
    cp 026h
    jr c,l123ch
    call 01311h
    jp c,l0ec8h
    call z,sub_139ch
    ld a,(04001h)
    cp 0c0h
    jr c,l127ch
    inc hl
    ld de,(0401ch)
    call sub_1bedh
    ex de,hl
    ld (0401ch),hl
    jr l127ch

; S-DECIMAL
l123ch:
    call sub_0f23h
    jr nz,l1264h
    call sub_16d1h
    rst 18h
    ld bc,00006h
    call sub_0b30h          ; MAKE-ROOM
    inc hl
    ld (hl),07eh
    inc hl
    ex de,hl
    ld hl,(0401ch)
    ld c,005h
    and a
    sbc hl,bc
    ld (0401ch),hl
    ldir
    ex de,hl
    dec hl
    call l004dh
    jr l1278h

; S-STK-DEC
l1264h:
    rst 20h
    cp 07eh
    jr nz,l1264h
    inc hl
    ld de,(0401ch)
    call sub_1bedh
    ld (0401ch),de
    ld (04016h),hl          ; CH.ADD - Address of next character to interpret

; S-NUMERIC
l1278h:
    set 6,(iy+001h)         ; set FLAGS  - 1 = Numeric result

; S-CONT-2
l127ch:
    rst 18h

; S-CONT-3
l127dh:
    cp 010h
    jr nz,l128dh
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    jr nz,l12b1h
    call sub_1458h
    rst 20h
    jr l127dh

; S-OPERTR
l128dh:
    ld bc,000c3h
    cp 012h
    jr c,l12b1h
    sub 016h
    jr nc,l129ch
    add a,00dh
    jr l12aah

; SUBMLTDIV
l129ch:
    cp 003h
    jr c,l12aah
    sub 0c0h
    jr c,l12b1h
    cp 006h
    jr nc,l12b1h
    add a,003h

; GET-PRIO
l12aah:
    add a,c
    ld c,a
    ld hl, l1304h - $C3     ; offset to base of the priorities table (=$1241)
    add hl,bc
    ld b,(hl)

; S-LOOP
l12b1h:
    pop de
    ld a,d
    cp b
    jr c,l12e2h
    and a
    jp z,l0018h
    push bc
    push de
    call sub_0f23h
    jr z,l12cah
    ld a,e
    and 03fh
    ld b,a
    rst 28h
    scf
    inc (hl)
    jr l12d3h

; S-SYNTEST
l12cah:
    ld a,e
    xor (iy+001h)
    and 040h

; S-RPORT-C
l12d0h:
    jp nz,l0f17h            ; to REPORT-C - Invalid Expression

; S-RUNTEST
l12d3h:
    pop de
    ld hl,04001h
    set 6,(hl)
    bit 7,e
    jr nz,l12dfh
    res 6,(hl)

; S-LOOPEND
l12dfh:
    pop bc
    jr l12b1h

; S-TIGHTER
l12e2h:
    push de
    ld a,c
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    jr nz,l12ffh
    and 03fh
    add a,008h
    ld c,a
    cp 010h
    jr nz,l12f7h
    set 6,c
    jr l12ffh

; S-NOT-AND
l12f7h:
    jr c,l12d0h
    cp 017h
    jr z,l12ffh
    set 7,c

; S-NEXT
l12ffh:
    push bc
    rst 20h
    jp l114eh

; -------------------------
; THE 'TABLE OF PRIORITIES'
; -------------------------

; tbl-pri
l1304h:
    .byte    $06            ;       '-'
    .byte    $08            ;       '*'
    .byte    $08            ;       '/'
    .byte    $0A            ;       '**'
    .byte    $02            ;       'OR'
    .byte    $03            ;       'AND'
    .byte    $05            ;       '<='
    .byte    $05            ;       '>='
    .byte    $05            ;       '<>'
    .byte    $05            ;       '>'
    .byte    $05            ;       '<'
    .byte    $05            ;       '='
    .byte    $06            ;       '+'


; --------------------------
; THE 'LOOK-VARS' SUBROUTINE
; --------------------------

; LOOK-VARS
sub_1311h:
    set 6,(iy+001h)         ; set FLAGS - 1 = numeric result
    rst 18h
    call sub_16c6h
    jp nc,l0f17h            ; to REPORT-C - Invalid Expression
    push hl
    ld c,a
    rst 20h
    push hl
    res 5,c
    cp 010h
    jr z,l133dh
    set 6,c
    cp 00dh
    jr z,l1338h
    set 5,c

; V-CHAR
l132eh:
    call sub_16cah
    jr nc,l133dh
    res 6,c
    rst 20h
    jr l132eh

; V-STR-VAR
l1338h:
    rst 20h
    res 6,(iy+001h)         ; set FLAGS - 0 = string result

; V-RUN/SYN
l133dh:
    ld b,c
    call sub_0f23h
    jr nz,l134bh
    ld a,c
    and 0e0h
    set 7,a
    ld c,a
    jr l137fh

; V-RUN
l134bh:
    ld hl,(04010h)

; V-EACH
l134eh:
    ld a,(hl)
    and 07fh
    jr z,l137dh
    cp c
    jr nz,l1375h
    rla
    add a,a
    jp p,l138ah
    jr c,l138ah
    pop de
    push de
    push hl

; V-MATCHES
l1360h:
    inc hl

; V-SPACES
l1361h:
    ld a,(de)
    inc de
    and a
    jr z,l1361h
    cp (hl)
    jr z,l1360h
    or 080h
    cp (hl)
    jr nz,l1374h
    ld a,(de)
    call sub_16cah
    jr nc,l1389h

; V-GET-PTR
l1374h:
    pop hl

; V-NEXT
l1375h:
    push bc
    call sub_0b84h
    ex de,hl
    pop bc
    jr l134eh

; V-80-BYTE
l137dh:
    set 7,b

; V-SYNTAX
l137fh:
    pop de
    rst 18h
    cp 010h
    jr z,l138eh
    set 5,b
    jr l1396h

; V-FOUND-1
l1389h:
    pop de

; V-FOUND-2
l138ah:
    pop de
    pop de
    push hl
    rst 18h

; V-PASS
l138eh:
    call sub_16cah
    jr nc,l1396h
    rst 20h
    jr l138eh

; V-END
l1396h:
    pop hl
    rl b
    bit 6,b
    ret

; ------------------------
; THE 'STK-VAR' SUBROUTINE
; ------------------------

; STK-VAR
sub_139ch:
    xor a
    ld b,a
    bit 7,c
    jr nz,l13edh
    bit 7,(hl)
    jr nz,l13b4h
    inc a

; SV-SIMPLE$
l13a7h:
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    inc hl
    ex de,hl
    call sub_14b8h
    rst 18h
    jp l144fh

; SV-ARRAYS
l13b4h:
    inc hl
    inc hl
    inc hl
    ld b,(hl)
    bit 6,c
    jr z,l13c6h
    dec b
    jr z,l13a7h
    ex de,hl
    rst 18h
    cp 010h
    jr nz,l1426h
    ex de,hl

; SV-PTR
l13c6h:
    ex de,hl
    jr l13edh

; SV-COMMA
l13c9h:
    push hl
    rst 18h
    pop hl
    cp 01ah
    jr z,l13f0h
    bit 7,c
    jr z,l1426h
    bit 6,c
    jr nz,l13deh
    cp 011h
    jr nz,l1418h
    rst 20h
    ret

; SV-CLOSE
l13deh:
    cp 011h
    jr z,l144eh
    cp 041h
    jr nz,l1418h

; SV-CH-ADD
l13e6h:
    rst 18h
    dec hl
    ld (04016h),hl          ; CH.ADD - Address of next character to interpret
    jr l144bh

; SV-COUNT
l13edh:
    ld hl,00000h

; SV-LOOP
l13f0h:
    push hl
    rst 20h
    pop hl
    ld a,c
    cp 0c0h
    jr nz,l1401h
    rst 18h
    cp 011h
    jr z,l144eh
    cp 041h
    jr z,l13e6h

; SV-MULT
l1401h:
    push bc
    push hl
    call sub_14f4h
    ex (sp),hl
    ex de,hl
    call sub_14d2h
    jr c,l1426h
    dec bc
    call sub_14fah
    add hl,bc
    pop de
    pop bc
    djnz l13c9h
    bit 7,c

; SV-RPT-C
l1418h:
    jr nz,l1480h
    push hl
    bit 6,c
    jr nz,l1432h
    ld b,d
    ld c,e
    rst 18h
    cp 011h
    jr z,l1428h

; REPORT-3
l1426h:
    rst 08h                 ; ERROR-1
    .byte $02               ; BS - Bad Subscript

; SV-NUMBER
l1428h:
    rst 20h
    pop hl
    ld de,00005h
    call sub_14fah
    add hl,bc
    ret

; SV-ELEM$
l1432h:
    call sub_14f4h
    ex (sp),hl
    call sub_14fah
    pop bc
    add hl,bc
    inc hl
    ld b,d
    ld c,e
    ex de,hl
    call sub_14b7h
    rst 18h
    cp 011h
    jr z,l144eh
    cp 01ah
    jr nz,l1426h

; SV-SLICE
l144bh:
    call sub_1458h

; SV-DIM
l144eh:
    rst 20h

; SV-SLICE?
l144fh:
    cp 010h
    jr z,l144bh
    res 6,(iy+001h)         ; set FLAGS - 0 = string result
    ret

; ------------------------
; THE 'SLICING' SUBROUTINE
; ------------------------

; SLICING
sub_1458h:
    call sub_0f23h
    call nz,sub_15edh       ; routine STK-FETCH
    rst 20h
    cp 011h
    jr z,l14b3h
    push de
    xor a
    push af
    push bc
    ld de,00001h
    rst 18h
    pop hl
    cp 041h
    jr z,l1487h
    pop af
    call sub_14d3h
    push af
    ld d,b
    ld e,c
    push hl
    rst 18h
    pop hl
    cp 041h
    jr z,l1487h
    cp 011h

; SL-RPT-C
l1480h:
    jp nz,l0f17h            ; to REPORT-C - Invalid Expression
    ld h,d
    ld l,e
    jr l149ah

; SL-SECOND
l1487h:
    push hl
    rst 20h
    pop hl
    cp 011h
    jr z,l149ah
    pop af
    call sub_14d3h
    push af
    rst 18h
    ld h,b
    ld l,c
    cp 011h
    jr nz,l1480h

; SL-DEFINE
l149ah:
    pop af
    ex (sp),hl
    add hl,de
    dec hl
    ex (sp),hl
    and a
    sbc hl,de
    ld bc,00000h
    jr c,l14aeh
    inc hl
    and a
    jp m,l1426h
    ld b,h
    ld c,l

; SL-OVER
l14aeh:
    pop de
    res 6,(iy+001h)         ; set FLAGS - 0 = string result

; SL-STORE
l14b3h:
    call sub_0f23h
    ret z

; --------------------------
; THE 'STK-STORE' SUBROUTINE
; --------------------------

; STK-ST-0
sub_14b7h:
    xor a

; STK-STO-$
sub_14b8h:
    push bc
    call sub_1be2h
    pop bc
    ld hl,(0401ch)
    ld (hl),a
    inc hl
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ld (hl),c
    inc hl
    ld (hl),b
    inc hl
    ld (0401ch),hl
    res 6,(iy+001h)         ; set FLAGS - 0 = string result
    ret

; -------------------------
; THE 'INT EXP' SUBROUTINES
; -------------------------

; INT-EXP1
sub_14d2h:
    xor a

; INT-EXP2
sub_14d3h:
    push de
    push hl
    push af
    call sub_0f0fh
    pop af
    call sub_0f23h
    jr z,l14f1h
    push af
    call sub_1088h
    pop de
    ld a,b
    or c
    scf
    jr z,l14eeh
    pop hl
    push hl
    and a
    sbc hl,bc

; I-CARRY
l14eeh:
    ld a,d
    sbc a,000h

; I-RESTORE
l14f1h:
    pop hl
    pop de
    ret

; --------------------------
; THE 'DE,(DE+1)' SUBROUTINE
; --------------------------

; DE,(DE+1)
sub_14f4h:
    ex de,hl
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ret

; --------------------------
; THE 'GET-HL*DE' SUBROUTINE
; --------------------------

; GET-HL*DE
sub_14fah:
    call sub_0f23h
    ret z
    push bc
    ld b,010h
    ld a,h
    ld c,l
    ld hl,00000h

; HL-LOOP
l1506h:
    add hl,hl
    jr c,l150fh
    rl c
    rla
    jr nc,l1512h
    add hl,de

; HL-END
l150fh:
    jp c,l10aeh

; HL-AGAIN
l1512h:
    djnz l1506h
    pop bc
    ret

; --------------------
; THE 'LET' SUBROUTINE
; --------------------

; LET
l1516h:
    ld hl,(04012h)
    bit 1,(iy+02dh)
    jr z,l1563h
    ld bc,00005h

; L-EACH-CH
l1522h:
    inc bc

; L-NO-SP
l1523h:
    inc hl
    ld a,(hl)
    and a
    jr z,l1523h
    call sub_16cah
    jr c,l1522h
    cp 00dh
    jp z,l15bdh
    rst 30h
    push de
    ld hl,(04012h)
    dec de
    ld a,c
    sub 006h
    ld b,a
    ld a,040h
    jr z,l154eh

; L-CHAR
l1540h:
    inc hl
    ld a,(hl)
    and a
    jr z,l1540h
    inc de
    ld (de),a
    djnz l1540h
    or 080h
    ld (de),a
    ld a,080h

; L-SINGLE
l154eh:
    ld hl,(04012h)
    xor (hl)
    pop hl
    call sub_15dch

; L-NUMERIC
l1556h:
    push hl
    rst 28h
    ld (bc),a
    inc (hl)
    pop hl
    ld bc,00005h
    and a
    sbc hl,bc
    jr l15a3h

; L-EXISTS
l1563h:
    bit 6,(iy+001h)         ; check FLAGS - 0 = string or 1 = numeric result
    jr z,l156fh
    ld de,00006h
    add hl,de
    jr l1556h

; L-DELETE$
l156fh:
    ld hl,(04012h)
    ld bc,(0402eh)
    bit 0,(iy+02dh)
    jr nz,l15ach
    ld a,b
    or c
    ret z
    push hl
    rst 30h
    push de
    push bc
    ld d,h
    ld e,l
    inc hl
    ld (hl),000h
    lddr
    push hl
    call sub_15edh          ; routine STK-FETCH
    pop hl
    ex (sp),hl
    and a
    sbc hl,bc
    add hl,bc
    jr nc,l1598h
    ld b,h
    ld c,l

; L-LENGTH
l1598h:
    ex (sp),hl
    ex de,hl
    ld a,b
    or c
    jr z,l15a0h
    ldir

; L-IN-W/S
l15a0h:
    pop bc
    pop de
    pop hl

; L-ENTER
l15a3h:
    ex de,hl
    ld a,b
    or c
    ret z
    push de
    ldir
    pop hl
    ret

; L-ADD$
l15ach:
    dec hl
    dec hl
    dec hl
    ld a,(hl)
    push hl
    push bc
    call sub_15c3h
    pop bc
    pop hl
    inc bc
    inc bc
    inc bc
    jp sub_0bf5h            ; routine RECLAIM-2

; L-NEWS
l15bdh:
    ld a,060h
    ld hl,(04012h)
    xor (hl)

; L-STRING
sub_15c3h:
    push af
    call sub_15edh          ; routine STK-FETCH
    ex de,hl
    add hl,bc
    push hl
    inc bc
    inc bc
    inc bc
    rst 30h
    ex de,hl
    pop hl
    dec bc
    dec bc
    push bc
    lddr
    ex de,hl
    pop bc
    dec bc
    ld (hl),b
    dec hl
    ld (hl),c
    pop af

; L-FIRST
sub_15dch:
    push af
    call sub_16bfh
    pop af
    dec hl
    ld (hl),a
    ld hl,(0401ah)
    ld (04014h),hl
    dec hl
    ld (hl),080h
    ret

; --------------------------
; THE 'STK-FETCH' SUBROUTINE
; --------------------------
; For a floating-point number the exponent is in A and the mantissa
; is the thirty-two bits EDCB.
; For strings, the start of the string is in DE and the length in BC.
; A is unused.

; STK-FETCH
sub_15edh:
    ld hl,(0401ch)
    dec hl
    ld b,(hl)
    dec hl
    ld c,(hl)
    dec hl
    ld d,(hl)
    dec hl
    ld e,(hl)
    dec hl
    ld a,(hl)
    ld (0401ch),hl
    ret

; -------------------------
; THE 'DIM' COMMAND ROUTINE
; -------------------------

; DIM
sub_15feh
    call sub_1311h          ; LOOK-VARS

; D-RPORT-C
l1601h:
    jp nz,l0f17h            ; to REPORT-C - Invalid Expression
    call sub_0f23h
    jr nz,l1611h
    res 6,c
    call sub_139ch
    call sub_0e9ah          ; routine CHECK-END

; D-RUN
l1611h:
    jr c,l161bh
    push bc
    call sub_0b84h
    call sub_0bf5h          ; routine RECLAIM-2
    pop bc

; D-LETTER
l161bh:
    set 7,c
    ld b,000h
    push bc
    ld hl,00001h
    bit 6,c
    jr nz,l1629h
    ld l,005h

; D-SIZE
l1629h:
    ex de,hl

; D-NO-LOOP
l162ah:
    rst 20h
    ld h,040h
    call sub_14d2h
    jp c,l1426h
    pop hl
    push bc
    inc h
    push hl
    ld h,b
    ld l,c
    call sub_14fah
    ex de,hl
    rst 18h
    cp 01ah
    jr z,l162ah
    cp 011h
    jr nz,l1601h
    rst 20h
    pop bc
    ld a,c
    ld l,b
    ld h,000h
    inc hl
    inc hl
    add hl,hl
    add hl,de
    jp c,l10aeh
    push de
    push bc
    push hl
    ld b,h
    ld c,l
    ld hl,(04014h)
    dec hl
    call sub_0b30h
    inc hl
    ld (hl),a
    pop bc
    dec bc
    dec bc
    dec bc
    inc hl
    ld (hl),c
    inc hl
    ld (hl),b
    pop af
    inc hl
    ld (hl),a
    ld h,d
    ld l,e
    dec de
    ld (hl),000h
    pop bc
    lddr

; DIM-SIZES
l1674h:
    pop bc
    ld (hl),b
    dec hl
    ld (hl),c
    dec hl
    dec a
    jr nz,l1674h
    ret

; RESERVE
l167dh:
    ld hl,(0401ah)          ; address STKBOT
    dec hl
    call sub_0b30h          ; routine MAKE-ROOM
    inc hl
    inc hl
    pop bc
    ld (04014h),bc
    pop bc
    ex de,hl
    inc hl
    ret


; -------------------------
; THE 'RUN' COMMAND ROUTINE
; -------------------------

; RUN
sub_168fh:
    call sub_1068h          ; GOTO with implied 0

; ---------------------------
; THE 'CLEAR' COMMAND ROUTINE
; ---------------------------

; CLEAR
sub_1692h:
    ld hl,(04010h)
    ld (hl),080h
    inc hl
    ld (04014h),hl

; X-TEMP
sub_169bh:
    ld hl,(04014h)          ; save E_LINE_lo

; set STK-B
sub_169eh:
    ld (0401ah),hl          ; save STKBOT

; set STK-E
l16a1h:
    ld (0401ch),hl          ; save STKEND
    ret

; -----------------------
; THE 'CURSOR-IN' ROUTINE
; -----------------------

; CURSOR-IN
sub_16a5h:
    ld hl,(04014h)
    ld (hl),07fh
    inc hl
    ld (hl),076h
    inc hl
    ld (iy+022h),002h
    jr sub_169eh

; ------------------------
; THE 'SET-MIN' SUBROUTINE
; ------------------------

; SET-MIN
l16b4h:
    ld hl,0405dh
    ld (0401fh),hl
    ld hl,(0401ah)
    jr l16a1h

; ------------------------------------
; THE 'RECLAIM THE END-MARKER' ROUTINE
; ------------------------------------

; REC-V80
sub_16bfh:
    ld de,(04014h)
    jp sub_0bf2h

; ----------------------
; THE 'ALPHA' SUBROUTINE
; ----------------------

; ALPHA
sub_16c6h:
    cp 026h
    jr l16cch

; -------------------------
; THE 'ALPHANUM' SUBROUTINE
; -------------------------

; ALPHANUM
sub_16cah:
    cp 01ch

; ALPHA-2
l16cch:
    ccf
    ret nc
    cp 040h
    ret

; ------------------------------------------
; THE 'DECIMAL TO FLOATING POINT' SUBROUTINE
; ------------------------------------------

; DEC-TO-FP
sub_16d1h:
    call sub_1740h
    cp 01bh
    jr nz,l16edh
    rst 28h                 ; FP-CALC
    .byte    $A1            ;;stk-one
    .byte    $C0            ;;st-mem-0
    .byte    $02            ;;delete
    .byte    $34            ;;end-calc

; NXT-DGT-1
l16ddh:
    rst 20h
    call sub_170ch
    jr c,l16edh
    rst 28h                 ; FP-CALC
    .byte    $E0            ;;get-mem-0
    .byte    $A4            ;;stk-ten
    .byte    $05            ;;division
    .byte    $C0            ;;st-mem-0
    .byte    $04            ;;multiply
    .byte    $0F            ;;addition
    .byte    $34            ;;end-calc
    jr l16ddh

; E-FORMAT
l16edh:
    cp 02ah
    ret nz
    ld (iy+05dh),0ffh
    rst 20h
    cp 015h
    jr z,l1700h
    cp 016h
    jr nz,l1701h
    inc (iy+05dh)

; SIGN-DONE
l1700h:
    rst 20h

; ST-E-PART
l1701h:
    call sub_1740h
    rst 28h                 ; FP-CALC              m, e.
    .byte    $E0            ;;get-mem-0             m, e, (1/0) TRUE/FALSE
    .byte    $00            ;;jump-true
    .byte    $02            ;;to L1511, E-POSTVE
    .byte    $18            ;;neg                   m, -e
;; E-POSTVE
    .byte    $38            ;;e-to-fp               x.
    .byte    $34            ;;end-calc              x.
    ret

; --------------------------
; THE 'STK-DIGIT' SUBROUTINE
; --------------------------

; STK-DIGIT
sub_170ch:
    cp 01ch
    ret c
    cp 026h
    ccf
    ret c
    sub 01ch

; ------------------------
; THE 'STACK-A' SUBROUTINE
; ------------------------

; STACK-A
sub_1715h:
    ld c,a
    ld b,000h

; -------------------------
; THE 'STACK-BC' SUBROUTINE
; -------------------------

; STACK-BC
sub_1718h:
    ld iy,04000h
    push bc
    rst 28h                 ; FP-CALC
    .byte    $A0            ;;stk-zero                      0.
    .byte    $34            ;;end-calc
    pop bc
    ld (hl),091h
    ld a,b
    and a
    jr nz,l172eh
    ld (hl),a
    or c
    ret z
    ld b,c
    ld c,(hl)
    ld (hl),089h

; STK-BC-2
l172eh:
    dec (hl)
    sla c
    rl b
    jr nc,l172eh
    srl b
    rr c
    inc hl
    ld (hl),b
    inc hl
    ld (hl),c
    dec hl
    dec hl
    ret

; ------------------------------------------
; THE 'INTEGER TO FLOATING POINT' SUBROUTINE
; ------------------------------------------

; INT-TO-FP
sub_1740h:
    push af
    rst 28h                 ; FP-CALC
    .byte    $A0            ;;stk-zero
    .byte    $34            ;;end-calc
    pop af

; NXT-DGT-2
l1745h:
    call sub_170ch
    ret c
    rst 28h                 ; FP-CALC
    .byte    $01            ;;exchange
    .byte    $A4            ;;stk-ten
    .byte    $04            ;;multiply
    .byte    $0F            ;;addition
    .byte    $34            ;;end-calc
    rst 20h
    jr l1745h

; ------------------------------------------------
; THE 'E-FORMAT TO FLOATING POINT' SUBROUTINE (38)
; ------------------------------------------------
sub_1752h:
    rst 28h                 ; FP-CALC              x, m.
    .byte    $2D            ;;duplicate             x, m, m.
    .byte    $32            ;;less-0                x, m, (1/0).
    .byte    $C0            ;;st-mem-0              x, m, (1/0).
    .byte    $02            ;;delete                x, m.
    .byte    $27            ;;abs                   x, +m.

;; E-LOOP
    .byte    $A1            ;;stk-one               x, m,1.
    .byte    $03            ;;subtract              x, m-1.
    .byte    $2D            ;;duplicate             x, m-1,m-1.
    .byte    $32            ;;less-0                x, m-1, (1/0).
    .byte    $00            ;;jump-true             x, m-1.
    .byte    $22            ;;to L1587, E-END       x, m-1.

    .byte    $2D            ;;duplicate             x, m-1, m-1.
    .byte    $30            ;;stk-data
    .byte    $33            ;;Exponent: $83, Bytes: 1

    .byte    $40            ;;(+00,+00,+00)         x, m-1, m-1, 6.
    .byte    $03            ;;subtract              x, m-1, m-7.
    .byte    $2D            ;;duplicate             x, m-1, m-7, m-7.
    .byte    $32            ;;less-0                x, m-1, m-7, (1/0).
    .byte    $00            ;;jump-true             x, m-1, m-7.
    .byte    $0C            ;;to L157A, E-LOW

; but if exponent m is higher than 7 do a bigger chunk.
; multiplying (or dividing if negative) by 10 million - 1e7.

    .byte    $01            ;;exchange              x, m-7, m-1.
    .byte    $02            ;;delete                x, m-7.
    .byte    $01            ;;exchange              m-7, x.
    .byte    $30            ;;stk-data
    .byte    $80            ;;Bytes: 3
    .byte    $48            ;;Exponent $98
    .byte    $18,$96,$80    ;;(+00)                 m-7, x, 10,000,000 (=f)
    .byte    $2F            ;;jump
    .byte    $04            ;;to L157D, E-CHUNK

; ---

;; E-LOW
    .byte    $02            ;;delete                x, m-1.
    .byte    $01            ;;exchange              m-1, x.
    .byte    $A4            ;;stk-ten               m-1, x, 10 (=f).

;; E-CHUNK
    .byte    $E0            ;;get-mem-0             m-1, x, f, (1/0)
    .byte    $00            ;;jump-true             m-1, x, f
    .byte    $04            ;;to L1583, E-DIVSN

    .byte    $04            ;;multiply              m-1, x*f.
    .byte    $2F            ;;jump
    .byte    $02            ;;to L1584, E-SWAP

; ---

;; E-DIVSN
    .byte    $05            ;;division              m-1, x/f (= new x).

;; E-SWAP
    .byte    $01            ;;exchange              x, m-1 (= new m).
    .byte    $2F            ;;jump                  x, m.
    .byte    $DA            ;;to L1560, E-LOOP

; ---

;; E-END
    .byte    $02            ;;delete                x. (-1)
    .byte    $34            ;;end-calc              x.

    ret

; -------------------------------------
; THE 'FLOATING-POINT TO BC' SUBROUTINE
; -------------------------------------

; FP-TO-BC
sub_1782h:
    call sub_15edh          ; routine STK-FETCH
    and a
    jr nz,l178dh
    ld b,a
    ld c,a
    push af
    jr l17beh

; FPBC-NZRO
l178dh:
    ld b,e
    ld e,c
    ld c,d
    sub 091h
    ccf
    bit 7,b
    push af
    set 7,b
    jr c,l17beh
    inc a
    neg
    cp 008h
    jr c,l17a7h
    ld e,c
    ld c,b
    ld b,000h
    sub 008h

; BIG-INT
l17a7h:
    and a
    ld d,a
    ld a,e
    rlca
    jr z,l17b4h

; FPBC-NORM
l17adh:
    srl b
    rr c
    dec d
    jr nz,l17adh

; EXP-ZERO
l17b4h:
    jr nc,l17beh
    inc bc
    ld a,b
    or c
    jr nz,l17beh
    pop af
    scf
    push af

; FPBC-END
l17beh:
    push bc
    rst 28h                 ; FP-CALC
    .byte    $34            ;;end-calc
    pop bc
    pop af
    ld a,c
    ret

; ------------------------------------
; THE 'FLOATING-POINT TO A' SUBROUTINE
; ------------------------------------

; FP-TO-A
sub_17c5h:
    call sub_1782h
    ret c
    push af
    dec b
    inc b
    jr z,l17d1h
    pop af
    scf
    ret

; FP-A-END
l17d1h:
    pop af
    ret

; ----------------------------------------------
; THE 'PRINT A FLOATING-POINT NUMBER' SUBROUTINE
; ----------------------------------------------

; PRINT-FP
l17d3h:
    rst 28h                 ; FP-CALC              x.
    .byte    $2D            ;;duplicate             x, x.
    .byte    $32            ;;less-0                x, (1/0).
    .byte    $00            ;;jump-true
    .byte    $0B            ;;to L15EA, PF-NGTVE    x.

    .byte    $2D            ;;duplicate             x, x
    .byte    $33            ;;greater-0             x, (1/0).
    .byte    $00            ;;jump-true
    .byte    $0D            ;;to L15F0, PF-POSTVE   x.

    .byte    $02            ;;delete                .
    .byte    $34            ;;end-calc              .
    ld a,01ch
    rst 10h
    ret

; PF-NEGTVE
    .byte    $27            ; abs                   +x.
    .byte    $34            ;;end-calc              x.
    ld a,016h
    rst 10h
    rst 28h                 ; FP-CALC              x.

; PF-POSTVE
    .byte    $34            ;;end-calc              x.
    ld a,(hl)
    call sub_1715h
    rst 28h                 ; FP-CALC              x, e.
    .byte    $30            ;;stk-data
    .byte    $78            ;;Exponent: $88, Bytes: 2
    .byte    $00,$80        ;;(+00,+00)             x, e, 128.5.
    .byte    $03            ;;subtract              x, e -.5.
    .byte    $30            ;;stk-data
    .byte    $EF            ;;Exponent: $7F, Bytes: 4
    .byte    $1A,$20,$9A,$85                     ; .30103 (log10 2)
    .byte    $04            ;;multiply              x,
    .byte    $24            ;;int
    .byte    $C1            ;;st-mem-1              x, n.


    .byte    $30            ;;stk-data
    .byte    $34            ;;Exponent: $84, Bytes: 1
    .byte    $00            ;;(+00,+00,+00)         x, n, 8.

    .byte    $03            ;;subtract              x, n-8.
    .byte    $18            ;;neg                   x, 8-n.
    .byte    $38            ;;e-to-fp               x * (10^n)

    .byte    $A2            ;;stk-half
    .byte    $0F            ;;addition
    .byte    $24            ;;int                   i.
    .byte    $34            ;;end-calc
    ld hl,0406bh
    ld (hl),090h
    ld b,00ah

; PF-LOOP
l180dh:
    inc hl
    push hl
    push bc
    rst 28h                 ; FP-CALC              i.
    .byte    $A4            ;;stk-ten               i, 10.
    .byte    $2E            ;;n-mod-m               i mod 10, i/10
    .byte    $01            ;;exchange              i/10, remainder.
    .byte    $34            ;;end-calc
    call sub_17c5h
    or 090h
    pop bc
    pop hl
    ld (hl),a
    djnz l180dh
    inc hl
    ld bc,00008h
    push hl

; PF-NULL
l1824h:
    dec hl
    ld a,(hl)
    cp 090h
    jr z,l1824h
    sbc hl,bc
    push hl
    ld a,(hl)
    add a,06bh
    push af

; PF-RND-LP
l1831h:
    pop af
    inc hl
    ld a,(hl)
    adc a,000h
    daa
    push af
    and 00fh
    ld (hl),a
    set 7,(hl)
    jr z,l1831h
    pop af
    pop hl
    ld b,006h

; PF-ZERO-6
l1843h:
    ld (hl),080h
    dec hl
    djnz l1843h
    rst 28h
    ld (bc),a
    pop hl
    inc (hl)
    call sub_17c5h
    jr z,l1853h
    neg

; PF-POS
l1853h:
    ld e,a
    inc e
    inc e
    pop hl

; GET-FIRST
l1857h:
    dec hl
    dec e
    ld a,(hl)
    and 00fh
    jr z,l1857h
    ld a,e
    sub 005h
    cp 008h
    jp p,l187ah
    cp 0f6h
    jp m,l187ah
    add a,006h
    jr z,l18b6h
    jp m,l18a9h
    ld b,a

; PF-NIB-LP
l1873h:
    call sub_18c7h
    djnz l1873h
    jr l18b9h

; PF-E-FMT
l187ah:
    ld b,e
    call sub_18c7h
    call l18b9h
    ld a,02ah
    rst 10h
    ld a,b
    and a
    jp p,l1890h
    neg
    ld b,a
    ld a,016h
    jr l1892h

; PF-E-POS
l1890h:
    ld a,015h

; PF-E-SIGN
l1892h:
    rst 10h
    ld a,b
    ld b,0ffh

; PF-E-TENS
l1896h:
    inc b
    sub 00ah
    jr nc,l1896h
    add a,00ah
    ld c,a
    ld a,b
    and a
    jr z,l18a5h
    call sub_098ch

; PF-E-LOW
l18a5h:
    ld a,c
    jp sub_098ch

; PF-ZEROS
l18a9h:
    neg
    ld b,a
    ld a,01bh
    rst 10h
l18afh:
    ld a,01ch

; PF-ZRO-LP  - ZX81 jumped to line above?
    rst 10h
    djnz l18afh
    jr l18bfh

; PF-ZERO-1
l18b6h:
    ld a,01ch
    rst 10h

; PF-DC-OUT
l18b9h:
    dec (hl)
    inc (hl)
    ret pe
    ld a,01bh
    rst 10h

; PF-FRAC-LP
l18bfh:
    dec (hl)
    inc (hl)
    ret pe
    call sub_18c7h
    jr l18bfh

; PF-NIBBLE
sub_18c7h:
    ld a,(hl)
    and 00fh
    call sub_098ch
    dec hl
    ret

; -------------------------------
; THE 'PREPARE TO ADD' SUBROUTINE
; -------------------------------

; PREP-ADD
sub_18cfh:
    ld a,(hl)
    ld (hl),000h
    and a
    ret z
    inc hl
    bit 7,(hl)
    set 7,(hl)
    dec hl
    ret z
    push bc
    ld bc,00005h
    add hl,bc
    ld b,c
    ld c,a
    scf

; NEG-BYTE
l18e3h:
    dec hl
    ld a,(hl)
    cpl
    adc a,000h
    ld (hl),a
    djnz l18e3h
    ld a,c
    pop bc
    ret

; ----------------------------------
; THE 'FETCH TWO NUMBERS' SUBROUTINE
; ----------------------------------

; FETCH-TWO
sub_18eeh:
    push hl
    push af
    ld c,(hl)
    inc hl
    ld b,(hl)
    ld (hl),a
    inc hl
    ld a,c
    ld c,(hl)
    push bc
    inc hl
    ld c,(hl)
    inc hl
    ld b,(hl)
    ex de,hl
    ld d,a
    ld e,(hl)
    push de
    inc hl
    ld d,(hl)
    inc hl
    ld e,(hl)
    push de
    exx
    pop de
    pop hl
    pop bc
    exx
    inc hl
    ld d,(hl)
    inc hl
    ld e,(hl)
    pop af
    pop hl
    ret

; -----------------------------
; THE 'SHIFT ADDEND' SUBROUTINE
; -----------------------------

; SHIFT-FP
sub_1911h:
    and a
    ret z
    cp 021h
    jr nc,l192dh
    push bc
    ld b,a

; ONE-SHIFT
l1919h:
    exx
    sra l
    rr d
    rr e
    exx
    rr d
    rr e
    djnz l1919h
    pop bc
    ret nc
    call sub_1938h
    ret nz

; ADDEND-0
l192dh:
    exx
    xor a

; ZEROS-4/5
sub_192fh:
    ld l,000h
    ld d,a
    ld e,l
    exx
    ld de,00000h
    ret

; -------------------------
; THE 'ADD-BACK' SUBROUTINE
; -------------------------

; ADD-BACK
sub_1938h:
    inc e
    ret nz
    inc d
    ret nz
    exx
    inc e
    jr nz,l1941h
    inc d

; ALL-ADDED
l1941h:
    exx
    ret

; --------------------------------
; THE 'SUBTRACTION' OPERATION (03)
; --------------------------------

; subtract
sub_1943h:
    ld a,(de)
    and a
    ret z
    inc de
    ld a,(de)
    xor 080h
    ld (de),a
    dec de

; -----------------------------
; THE 'ADDITION' OPERATION (0F)
; -----------------------------

; addition
sub_194ch:
    exx
    push hl
    exx
    push de
    push hl
    call sub_18cfh
    ld b,a
    ex de,hl
    call sub_18cfh
    ld c,a
    cp b
    jr nc,l1960h
    ld a,b
    ld b,c
    ex de,hl

; SHIFT-LEN
l1960h:
    push af
    sub b
    call sub_18eeh
    call sub_1911h
    pop af
    pop hl
    ld (hl),a
    push hl
    ld l,b
    ld h,c
    add hl,de
    exx
    ex de,hl
    adc hl,bc
    ex de,hl
    ld a,h
    adc a,l
    ld l,a
    rra
    xor l
    exx
    ex de,hl
    pop hl
    rra
    jr nc,l1987h
    ld a,001h
    call sub_1911h
    inc (hl)
    jr z,l19aah

; TEST-NEG
l1987h:
    exx
    ld a,l
    and 080h
    exx
    inc hl
    ld (hl),a
    dec hl
    jr z,l19b0h
    ld a,e
    neg
    ccf
    ld e,a
    ld a,d
    cpl
    adc a,000h
    ld d,a
    exx
    ld a,e
    cpl
    adc a,000h
    ld e,a
    ld a,d
    cpl
    adc a,000h
    jr nc,l19aeh
    rra
    exx
    inc (hl)

; ADD-REP-6
l19aah:
    jp z,l1a77h
    exx

; END-COMPL
l19aeh:
    ld d,a
    exx

; GO-NC-MLT
l19b0h:
    xor a
    jr l1a1fh

; ----------------------------------------------
; THE 'PREPARE TO MULTIPLY OR DIVIDE' SUBROUTINE
; ----------------------------------------------

; PREP-M/D
sub_19b3h:
    scf
    dec (hl)
    inc (hl)
    ret z
    inc hl
    xor (hl)
    set 7,(hl)
    dec hl
    ret

; -----------------------------------
; THE 'MULTIPLICATION' OPERATION (04)
; -----------------------------------

; multiply
sub_19bdh:
    xor a
    call sub_19b3h
    ret c
    exx
    push hl
    exx
    push de
    ex de,hl
    call sub_19b3h
    ex de,hl
    jr c,l1a27h
    push hl
    call sub_18eeh
    ld a,b
    and a
    sbc hl,hl
    exx
    push hl
    sbc hl,hl
    exx
    ld b,021h
    jr l19efh

; MLT-LOOP
l19deh:
    jr nc,l19e5h
    add hl,de
    exx
    adc hl,de
    exx

; NO-ADD
l19e5h:
    exx
    rr h
    rr l
    exx
    rr h
    rr l

; STRT-MLT
l19efh:
    exx
    rr b
    rr c
    exx
    rr c
    rra
    djnz l19deh
    ex de,hl
    exx
    ex de,hl
    exx
    pop bc
    pop hl
    ld a,b
    add a,c
    jr nz,l1a05h
    and a

; MAKE-EXPT
l1a05h:
    dec a
    ccf

; DIVN-EXPT
l1a07h:
    rla
    ccf
    rra
    jp p,l1a10h
    jr nc,l1a77h
    and a

; OFLW1-CLR
l1a10h:
    inc a
    jr nz,l1a1bh
    jr c,l1a1bh
    exx
    bit 7,d
    exx
    jr nz,l1a77h

; OFLW2-CLR
l1a1bh:
    ld (hl),a
    exx
    ld a,b
    exx

; TEST-NORM
l1a1fh:
    jr nc,l1a36h
    ld a,(hl)
    and a

; NEAR-ZERO
l1a23h:
    ld a,080h
    jr z,l1a28h

; ZERO-RSLT
l1a27h:
    xor a

; SKIP-ZERO
l1a28h:
    exx
    and d
    call sub_192fh
    rlca
    ld (hl),a
    jr c,l1a5fh
    inc hl
    ld (hl),a
    dec hl
    jr l1a5fh

; NORMALIZE
l1a36h:
    ld b,020h

; SHIFT-ONE
l1a38h:
    exx
    bit 7,d
    exx
    jr nz,l1a50h
    rlca
    rl e
    rl d
    exx
    rl e
    rl d
    exx
    dec (hl)
    jr z,l1a23h
    djnz l1a38h
    jr l1a27h

; NORML-NOW
l1a50h:
    rla
    jr nc,l1a5fh
    call sub_1938h
    jr nz,l1a5fh
    exx
    ld d,080h
    exx
    inc (hl)
    jr z,l1a77h

; OFLOW-CLR
l1a5fh:
    push hl
    inc hl
    exx
    push de
    exx
    pop bc
    ld a,b
    rla
    rl (hl)
    rra
    ld (hl),a
    inc hl
    ld (hl),c
    inc hl
    ld (hl),d
    inc hl
    ld (hl),e
    pop hl
    pop de
    exx
    pop hl
    exx
    ret

; REPORT-6
l1a77h:
    rst 08h                 ; ERROR-1
    .byte $05               ; OV arithmetic OVerflow.

; -----------------------------
; THE 'DIVISION' OPERATION (05)
; -----------------------------

; division
sub_1a79h:
    ex de,hl
    xor a
    call sub_19b3h
    jr c,l1a77h
    ex de,hl
    call sub_19b3h
    ret c
    exx
    push hl
    exx
    push de
    push hl
    call sub_18eeh
    exx
    push hl
    ld h,b
    ld l,c
    exx
    ld h,c
    ld l,b
    xor a
    ld b,0dfh
    jr l1aa9h

; DIV-LOOP
l1a99h:
    rla
    rl c
    exx
    rl c
    rl b
    exx

; div-34th
l1aa2h:
    add hl,hl
    exx
    adc hl,hl
    exx
    jr c,l1ab9h

; DIV-START
l1aa9h:
    sbc hl,de
    exx
    sbc hl,de
    exx
    jr nc,l1ac0h
    add hl,de
    exx
    adc hl,de
    exx
    and a
    jr l1ac1h

; SUBN-ONLY
l1ab9h:
    and a
    sbc hl,de
    exx
    sbc hl,de
    exx

; NO-RSTORE
l1ac0h:
    scf

; COUNT-ONE
l1ac1h:
    inc b
    jp m,l1a99h
    push af
    jr z,l1aa2h             ; fix to ZX81 jumps to div-34th not DIV-START
    ld e,a
    ld d,c
    exx
    ld e,c
    ld d,b
    pop af
    rr b
    pop af
    rr b
    exx
    pop bc
    pop hl
    ld a,b
    sub c
    jp l1a07h

; -----------------------------------------------------
; THE 'INTEGER TRUNCATION TOWARDS ZERO' SUBROUTINE (36)
; -----------------------------------------------------

; truncate
sub_1adbh:
    ld a,(hl)
    cp 081h
    jr nc,l1ae6h
    ld (hl),000h
    ld a,020h
    jr l1aebh

; T-GR-ZERO
l1ae6h:
    sub 0a0h
    ret p
    neg

; NIL-BYTES
l1aebh:
    push de
    ex de,hl
    dec hl
    ld b,a
    srl b
    srl b
    srl b
    jr z,l1afch

; BYTE-ZERO
l1af7h:
    ld (hl),000h
    dec hl
    djnz l1af7h

; BITS-ZERO
l1afch:
    and 007h
    jr z,l1b09h
    ld b,a
    ld a,0ffh

; LESS-MASK
l1b03h:
    sla a
    djnz l1b03h
    and (hl)
    ld (hl),a

; IX-END
l1b09h:
    ex de,hl
    pop de
    ret

;********************************
;**  FLOATING-POINT CALCULATOR **
;********************************

; ------------------------
; THE 'TABLE OF CONSTANTS'
; ------------------------
l1b0ch:
; stk-zero                                                 00 00 00 00 00
    .byte    $00            ;;Bytes: 1
    .byte    $B0            ;;Exponent $00
    .byte    $00            ;;(+00,+00,+00)

; stk-one                                                  81 00 00 00 00
    .byte    $31            ;;Exponent $81, Bytes: 1
    .byte    $00            ;;(+00,+00,+00)


; stk-half                                                 80 00 00 00 00
    .byte    $30            ;;Exponent: $80, Bytes: 1
    .byte    $00            ;;(+00,+00,+00)


; stk-pi/2                                                 81 49 0F DA A2
    .byte    $F1            ;;Exponent: $81, Bytes: 4
    .byte    $49,$0F,$DA,$A2

; stk-ten                                                  84 20 00 00 00
    .byte    $34            ;;Exponent: $84, Bytes: 1
    .byte    $20            ;;(+00,+00,+00)

; ------------------------
; THE 'TABLE OF ADDRESSES'
; ------------------------
l1b1ah:
    .word sub_1e1eh         ; $00 - jump-true
    .word sub_1c67h         ; $01 - exchange
    .word sub_1bdah         ; $02 - delete
    .word sub_1943h         ; $03 - subtract
    .word sub_19bdh         ; $04 - multiply
    .word sub_1a79h         ; $05 - division
    .word sub_1fd1h         ; $06 - to-power
    .word sub_1ce2h         ; $07 - or
    .word sub_1ce8h         ; $08 - no-&-no
    .word sub_1cf8h         ; $09 - no-l-eql
    .word sub_1cf8h         ; $0A - no-gr-eql
    .word sub_1cf8h         ; $0B - nos-neql
    .word sub_1cf8h         ; $0C - no-grtr
    .word sub_1cf8h         ; $0D - no-less
    .word sub_1cf8h         ; $0E - nos-eql
    .word sub_194ch         ; $0F - addition
    .word sub_1cedh         ; $10 - str-&-no
    .word sub_1cf8h         ; $11 - str-l-eql
    .word sub_1cf8h         ; $12 - str-gr-eql
    .word sub_1cf8h         ; $13 - strs-neql
    .word sub_1cf8h         ; $14 - str-grtr
    .word sub_1cf8h         ; $15 - str-less
    .word sub_1cf8h         ; $16 - strs-eql
    .word sub_1d57h         ; $17 - strs-add
    .word sub_1c95h         ; $18 - neg
    .word sub_1df5h         ; $19 - code
    .word sub_1d93h         ; $1A - val
    .word sub_1e00h         ; $1B - len
    .word sub_1f38h         ; $1C - sin
    .word sub_1f2dh         ; $1D - cos
    .word sub_1f5dh         ; $1E - tan
    .word sub_1fb3h         ; $1F - asn
    .word sub_1fc3h         ; $20 - acs
    .word sub_1f65h         ; $21 - atn
    .word sub_1e98h         ; $22 - ln
    .word sub_1e4ah         ; $23 - exp
    .word sub_1e35h         ; $24 - int
    .word sub_1fcah         ; $25 - sqr
    .word sub_1ca4h         ; $26 - sgn
    .word sub_1c9fh         ; $27 - abs
    .word sub_1cb3h         ; $28 - peek
    .word sub_1cbah         ; $29 - usr-no
    .word sub_1dc4h         ; $2A - str$
    .word sub_1d84h         ; $2B - chrs
    .word sub_1ccah         ; $2C - not
    .word sub_1bedh         ; $2D - duplicate
    .word sub_1e26h         ; $2E - n-mod-m
    .word sub_1e12h         ; $2F - jump
    .word sub_1bf3h         ; $30 - stk-data
    .word sub_1e06h         ; $31 - dec-jr-nz
    .word sub_1cd0h         ; $32 - less-0
    .word sub_1cc3h         ; $33 - greater-0
    .word sub_002bh         ; $34 - end-calc
    .word sub_1f07h         ; $35 - get-argt
    .word sub_1adbh         ; $36 - truncate
    .word sub_1bdbh         ; $37 - fp-calc-2
    .word sub_1752h         ; $38 - e-to-fp
    .word sub_1c74h         ; $39 - series-xx    $80 - $9F.
    .word sub_1c39h         ; $3A - stk-const-xx $A0 - $BF.
    .word sub_1c58h         ; $3B - st-mem-xx    $C0 - $DF.
    .word sub_1c2dh         ; $3C - get-mem-xx   $E0 - $FF.

; -------------------------------
; THE 'FLOATING POINT CALCULATOR'
; -------------------------------

; CALCULATE
l1b94h:
    call sub_1d7ah

; GEN-ENT-1
sub_1b97h:
    ld a,b
    ld (0401eh),a

; GEN-ENT-2
sub_1b9bh:
    exx
    ex (sp),hl
    exx

; RE-ENTRY
l1b9eh:
    ld (0401ch),de
    exx
    ld a,(hl)
    inc hl

; SCAN-ENT
l1ba5h:
    push hl
    and a
    jp p,l1bb9h
    ld d,a
    and 060h
    rrca
    rrca
    rrca
    rrca
    add a,072h
    ld l,a
    ld a,d
    and 01fh
    jr l1bc7h

; FIRST-3D
l1bb9h:
    cp 018h
    jr nc,l1bc5h
    exx
    ld bc,0fffbh
    ld d,h
    ld e,l
    add hl,bc
    exx

; DOUBLE-A
l1bc5h:
    rlca
    ld l,a

; ENT-TABLE
l1bc7h:
    ld de,l1b1ah
    ld h,000h
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld hl,l1b9eh
    ex (sp),hl
    push de
    exx
    ld bc,(0401dh)

; -----------------------
; THE 'DELETE' SUBROUTINE
; -----------------------

; delete
sub_1bdah:
    ret

; ---------------------------------
; THE 'SINGLE OPERATION' SUBROUTINE
; ---------------------------------

; fp-calc-2
sub_1bdbh:
    pop af
    ld a,(0401eh)
    exx
    jr l1ba5h

; ------------------------------
; THE 'TEST 5 SPACES' SUBROUTINE
; ------------------------------

; TEST-5-SP
sub_1be2h:
    push de
    push hl
    ld bc,00005h
    call sub_10a0h
sub_1beah:
    pop hl
    pop de
    ret

; ---------------------------------------------
; THE 'MOVE A FLOATING POINT NUMBER' SUBROUTINE
; ---------------------------------------------

; MOVE-FP
sub_1bedh:
    call sub_1be2h
    ldir
    ret

; -------------------------------
; THE 'STACK LITERALS' SUBROUTINE
; -------------------------------

; stk-data
sub_1bf3h:
    ld h,d
    ld l,e

; STK-CONST
sub_1bf5h:
    call sub_1be2h
    exx
    push hl
    exx
    ex (sp),hl
    push bc
    ld a,(hl)
    and 0c0h
    rlca
    rlca
    ld c,a
    inc c
    ld a,(hl)
    and 03fh
    jr nz,l1c0bh
    inc hl
    ld a,(hl)

; FORM-EXP
l1c0bh:
    add a,050h
    ld (de),a
    ld a,005h
    sub c
    inc hl
    inc de
    ld b,000h
    ldir
    pop bc
    ex (sp),hl
    exx
    pop hl
    exx
    ld b,a
    xor a

; STK-ZEROS
l1c1eh:
    dec b
    ret z
    ld (de),a
    inc de
    jr l1c1eh

; --------------------------------
; THE 'MEMORY LOCATION' SUBROUTINE
; --------------------------------

; LOC-MEM (which came after SKIP-NEXT on the ZX81?)
sub_1c24h:
    ld c,a
    rlca
    rlca
    add a,c
    ld c,a
    ld b,000h
    add hl,bc
    ret

; -------------------------------------
; THE 'GET FROM MEMORY AREA' SUBROUTINE
; -------------------------------------

; get-mem-xx
sub_1c2dh:
    push de
    ld hl,(0401fh)
    call sub_1c24h
    call sub_1bedh
    pop hl
    ret

; ---------------------------------
; THE 'STACK A CONSTANT' SUBROUTINE
; ---------------------------------

; stk-const-xx
sub_1c39h:
    ld h,d
    ld l,e
    exx
    push hl
    ld hl,l1b0ch
    exx

; SKIP-CONS (ZX81 was a call rather than drop through)
    and a

; SKIP-NEXT (ZX81 version is RET Z)
    jr z,l1c51h

l1c44h:
    push af
    push de
    ld de,00000h
    call sub_1bf5h
    pop de
    pop af
    dec a
    jr nz,l1c44h
l1c51h:
    call sub_1bf5h
    exx
    pop hl
    exx
    ret

; ---------------------------------------
; THE 'STORE IN A MEMORY AREA' SUBROUTINE
; ---------------------------------------

; st-mem-xx
sub_1c58h:
    push hl
    ex de,hl
    ld hl,(0401fh)
    call sub_1c24h
    ex de,hl
    call sub_1bedh
    ex de,hl
    pop hl
    ret

; -------------------------
; THE 'EXCHANGE' SUBROUTINE
; -------------------------

; exchange
sub_1c67h:
    ld b,005h

; SWAP-BYTE
l1c69h:
    ld a,(de)
    ld c,(hl)
    ex de,hl
    ld (de),a
    ld (hl),c
    inc hl
    inc de
    djnz l1c69h
    ex de,hl
    ret

; ---------------------------------
; THE 'SERIES GENERATOR' SUBROUTINE
; ---------------------------------

; series-xx
sub_1c74h:
    ld b,a
    call sub_1b97h
    .byte    $2D            ;;duplicate       x,x
    .byte    $0F            ;;addition        x+x
    .byte    $C0            ;;st-mem-0        x+x
    .byte    $02            ;;delete          .
    .byte    $A0            ;;stk-zero        0
    .byte    $C2            ;;st-mem-2        0
;; G-LOOP
    .byte    $2D            ;;duplicate       v,v.
    .byte    $E0            ;;get-mem-0       v,v,x+2
    .byte    $04            ;;multiply        v,v*x+2
    .byte    $E2            ;;get-mem-2       v,v*x+2,v
    .byte    $C1            ;;st-mem-1
    .byte    $03            ;;subtract
    .byte    $34            ;;end-calc

    call sub_1bf3h
    call sub_1b9bh

    .byte    $0F            ;;addition
    .byte    $01            ;;exchange
    .byte    $C2            ;;st-mem-2
    .byte    $02            ;;delete
    .byte    $31            ;;dec-jr-nz
    .byte    $EE            ;;back to L1A89, G-LOOP
    .byte    $E1            ;;get-mem-1
    .byte    $03            ;;subtract
    .byte    $34            ;;end-calc
    ret

; -----------------------
; Handle unary minus (18)
; -----------------------

; negate
sub_1c95h:
    ld a,(hl)
    and a
    ret z
    inc hl
    ld a,(hl)
    xor 080h
    ld (hl),a
    dec hl
    ret

; -----------------------
; Absolute magnitude (27)
; -----------------------

; abs
sub_1c9fh:
    inc hl
    res 7,(hl)
    dec hl
    ret

; -----------
; Signum (26)
; -----------

; sgn
sub_1ca4h:
    inc hl
    ld a,(hl)
    dec hl
    dec (hl)
    inc (hl)
    scf
    call nz,sub_1cd5h
    inc hl
    rlca
    rr (hl)
    dec hl
    ret

; -------------------------
; Handle PEEK function (28)
; -------------------------

; peek
sub_1cb3h:
    call sub_1088h
    ld a,(bc)
    jp sub_1715h

; ---------------
; USR number (29)
; ---------------

; usr-no
sub_1cbah:
    call sub_1088h
    ld hl,sub_1718h
    push hl
    push bc
    ret

; -----------------------
; Greater than zero ($33)
; -----------------------

; greater-0
sub_1cc3h:
    ld a,(hl)
    and a
    ret z
    ld a,0ffh
    jr l1cd1h


; -------------------------
; Handle NOT operator ($2C)
; -------------------------

; not
sub_1ccah:
    ld a,(hl)
    neg
    ccf
    jr sub_1cd5h


; -------------------
; Less than zero (32)
; -------------------

; less-0
sub_1cd0h:
    xor a

; SIGN-TO-C
l1cd1h:
    inc hl
    xor (hl)
    dec hl
    rlca

; -----------
; Zero or one
; -----------

; FP-0/1
sub_1cd5h:
    push hl
    ld b,005h

; FP-loop
l1cd8h:
    ld (hl),000h
    inc hl
    djnz l1cd8h
    pop hl
    ret nc
    ld (hl),081h
    ret


; -----------------------
; Handle OR operator (07)
; -----------------------

; or
sub_1ce2h:
    ld a,(de)
    and a
    ret z
    scf
    jr sub_1cd5h


; -----------------------------
; Handle number AND number (08)
; -----------------------------

; no-&-no
sub_1ce8h:
    ld a,(de)
    and a
    ret nz
    jr sub_1cd5h

; -----------------------------
; Handle string AND number (10)
; -----------------------------

; str-&-no
sub_1cedh:
    ld a,(de)
    and a
    ret nz
    push de
    dec de
    xor a
    ld (de),a
    dec de
    ld (de),a
    pop de
    ret

; -------------------------------------
; Perform comparison ($09-$0E, $11-$16)
; -------------------------------------

; no-l-eql,etc.
sub_1cf8h:
    ld a,b
    sub 008h
    bit 2,a
    jr nz,l1d00h
    dec a

; EX-OR-NOT
l1d00h:
    rrca
    jr nc,l1d0bh
    push af
    push hl
    call sub_1c67h
    pop de
    ex de,hl
    pop af

; NU-OR-STR
l1d0bh:
    bit 2,a
    jr nz,l1d16h
    rrca
    push af
    call sub_1943h
    jr l1d49h

; STRINGS
l1d16h:
    rrca
    push af
    call sub_15edh          ; routine STK-FETCH
    push de
    push bc
    call sub_15edh          ; routine STK-FETCH
    pop hl

; BYTE-COMP
l1d21h:
    ld a,h
    or l
    ex (sp),hl
    ld a,b
    jr nz,l1d32h
    or c

; SECND-LOW
l1d28h:
    pop bc
    jr z,l1d2fh
    pop af
    ccf
    jr l1d45h

; BOTH-NULL
l1d2fh:
    pop af
    jr l1d45h

; SEC-PLUS
l1d32h:
    or c
    jr z,l1d42h
    ld a,(de)
    sub (hl)
    jr c,l1d42h
    jr nz,l1d28h
    dec bc
    inc de
    inc hl
    ex (sp),hl
    dec hl
    jr l1d21h

; FRST-LESS
l1d42h:
    pop bc
    pop af
    and a

; STR-TEST
l1d45h:
    push af
    rst 28h                 ; FP-CALC
    .byte    $A0            ;;stk-zero      an initial false value.
    .byte    $34            ;;end-calc

; END-TESTS
l1d49h:
    pop af
    push af
    call c,sub_1ccah
    call sub_1cc3h
    pop af
    rrca
    call nc,sub_1ccah
    ret

; -------------------------
; String concatenation ($17)
; -------------------------

; strs-add
sub_1d57h:
    call sub_15edh          ; routine STK-FETCH
    push de
    push bc
    call sub_15edh          ; routine STK-FETCH
    pop hl
    push hl
    push de
    push bc
    add hl,bc
    ld b,h
    ld c,l
    rst 30h
    call sub_14b8h
    pop bc
    pop hl
    ld a,b
    or c
    jr z,l1d72h
    ldir

; OTHER-STR
l1d72h:
    pop bc
    pop hl
    ld a,b
    or c
    jr z,sub_1d7ah
    ldir

; --------------------
; Check stack pointers
; --------------------

; STK-PNTRS
sub_1d7ah:
    ld hl,(0401ch)
    ld de,0fffbh
    push hl
    add hl,de
    pop de
    ret

; ----------------
; Handle CHR$ (2B)
; ----------------

; chrs
sub_1d84h:
    call sub_1083h          ; modified from ZX81 to inline REPORT-Bd
    push af
    ld bc,00001h
    rst 30h
    pop af
    ld (de),a
    call sub_14b8h
    ex de,hl
    ret

; ----------------
; Handle VAL ($1A)
; ----------------

; val
sub_1d93h:
    ld hl,(04016h)          ; CH.ADD - Address of next character to interpret
    push hl
    call sub_15edh          ; routine STK-FETCH
    push de
    inc bc
    rst 30h
    pop hl
    ld (04016h),de          ; CH.ADD
    push de
    ldir
    ex de,hl
    dec hl
    ld (hl),076h
    res 7,(iy+001h)
    call sub_0f0fh
    call l0e9fh
    pop hl
    ld (04016h),hl          ; CH.ADD
    set 7,(iy+001h)
    call sub_114ah          ; routine SCANNING
    pop hl
    ld (04016h),hl          ; CH.ADD
    jr sub_1d7ah

; ----------------
; Handle STR$ (2A)
; ----------------

; str$
sub_1dc4h:
    ld bc,00001h
    rst 30h
    ld (hl),076h
    ld hl,(04039h)
    push hl
    ld l,0ffh
    ld (04039h),hl
    ld hl,(0400eh)
    push hl
    ld (0400eh),de
    push de
    call l17d3h
    pop de
    ld hl,(0400eh)
    and a
    sbc hl,de
    ld b,h
    ld c,l
    pop hl
    ld (0400eh),hl
    pop hl
    ld (04039h),hl
    call sub_14b8h
    ex de,hl
    ret

; ------------------------
; THE 'CODE' FUNCTION (19)
; ------------------------

; code
sub_1df5h:
    call sub_15edh          ; routine STK-FETCH
    ld a,b
    or c
    jr z,l1dfdh
    ld a,(de)

; STK-CODE
l1dfdh:
    jp sub_1715h

; -------------------------
; THE 'LEN' SUBROUTINE (1B)
; -------------------------

; len
sub_1e00h:
    call sub_15edh          ; routine STK-FETCH
    jp sub_1718h

; ------------------------------------------
; THE 'DECREASE THE COUNTER' SUBROUTINE (31)
; ------------------------------------------

; dec-jr-nz
sub_1e06h:
    exx
    push hl
    ld hl,0401eh
    dec (hl)
    pop hl
    jr nz,l1e13h
    inc hl
    exx
    ret

; --------------------------
; THE 'JUMP' SUBROUTINE (2F)
; --------------------------

; jump
sub_1e12h:
l1e12h:
    exx

; JUMP-2
l1e13h:
    ld e,(hl)
    xor a
    bit 7,e
    jr z,l1e1ah
    cpl

; JUMP-3
l1e1ah:
    ld d,a
    add hl,de
    exx
    ret

; ----------------------------------
; THE 'JUMP ON TRUE' SUBROUTINE (00)
; ----------------------------------

; jump-true
sub_1e1eh:
    ld a,(de)
    and a
    jr nz,l1e12h
    exx
    inc hl
    exx
    ret

; -----------------------------
; THE 'MODULUS' SUBROUTINE (2E)
; -----------------------------

; n-mod-m
sub_1e26h:
    rst 28h                 ; FP_CALC
    .byte    $C0            ;;st-mem-0          17, 3.
    .byte    $02            ;;delete            17.
    .byte    $2D            ;;duplicate         17, 17.
    .byte    $E0            ;;get-mem-0         17, 17, 3.
    .byte    $05            ;;division          17, 17/3.
    .byte    $24            ;;int               17, 5.
    .byte    $E0            ;;get-mem-0         17, 5, 3.
    .byte    $01            ;;exchange          17, 3, 5.
    .byte    $C0            ;;st-mem-0          17, 3, 5.
    .byte    $04            ;;multiply          17, 15.
    .byte    $03            ;;subtract          2.
    .byte    $E0            ;;get-mem-0         2, 5.
    .byte    $34            ;;end-calc          2, 5.
    ret

; ---------------------------
; THE 'INTEGER' FUNCTION (24)
; ---------------------------

; int
sub_1e35h:
    rst 28h                 ; FP-CALC              x.    (= 3.4 or -3.4).
    .byte    $2D            ;;duplicate             x, x.
    .byte    $32            ;;less-0                x, (1/0)
    .byte    $00            ;;jump-true             x, (1/0)
    .byte    $04            ;;to L1C46, X-NEG

    .byte    $36            ;;truncate              trunc 3.4 = 3.
    .byte    $34            ;;end-calc              3.
    ret

; X-NEG
    .byte    $2D            ;;duplicate             -3.4, -3.4.
    .byte    $36            ;;truncate              -3.4, -3.
    .byte    $C0            ;;st-mem-0              -3.4, -3.
    .byte    $03            ;;subtract              -.4
    .byte    $E0            ;;get-mem-0             -.4, -3.
    .byte    $01            ;;exchange              -3, -.4.
    .byte    $2C            ;;not                   -3, (0).
    .byte    $00            ;;jump-true             -3.
    .byte    $03            ;;to L1C59, EXIT        -3.

    .byte    $A1            ;;stk-one               -3, 1.
    .byte    $03            ;;subtract              -4.

;; EXIT
    .byte    $34            ;;end-calc              -4.
    ret

; ----------------
; Exponential (23)
; ----------------
; EXP
sub_1e4ah:
l1e4ah:
    rst 28h
    .byte    $30            ;;stk-data
    .byte    $F1            ;;Exponent: $81, Bytes: 4
    .byte    $38,$AA,$3B,$29
    .byte    $04            ;;multiply
    .byte    $2D            ;;duplicate
    .byte    $24            ;;int
    .byte    $C3            ;;st-mem-3
    .byte    $03            ;;subtract
    .byte    $2D            ;;duplicate
    .byte    $0F            ;;addition
    .byte    $A1            ;;stk-one
    .byte    $03            ;;subtract
    .byte    $88            ;;series-08
    .byte    $13            ;;Exponent: $63, Bytes: 1
    .byte    $36            ;;(+00,+00,+00)
    .byte    $58            ;;Exponent: $68, Bytes: 2
    .byte    $65,$66        ;;(+00,+00)
    .byte    $9D            ;;Exponent: $6D, Bytes: 3
    .byte    $78,$65,$40    ;;(+00)
    .byte    $A2            ;;Exponent: $72, Bytes: 3
    .byte    $60,$32,$C9    ;;(+00)
    .byte    $E7            ;;Exponent: $77, Bytes: 4
    .byte    $21,$F7,$AF,$24
    .byte    $EB            ;;Exponent: $7B, Bytes: 4
    .byte    $2F,$B0,$B0,$14
    .byte    $EE            ;;Exponent: $7E, Bytes: 4
    .byte    $7E,$BB,$94,$58
    .byte    $F1            ;;Exponent: $81, Bytes: 4
    .byte    $3A,$7E,$F8,$CF
    .byte    $E3            ;;get-mem-3
    .byte    $34            ;;end-calc

    call sub_17c5h
    jr nz,l1e8ah
    jr c,l1e88h
    add a,(hl)
    jr nc,l1e91h

; REPORT-6b
l1e88h:
    rst 08h                 ; ERROR-1
    .byte    $05            ; OV arithmetic OVerflow

; N-NEGTV
l1e8ah:
    jr c,l1e93h
    sub (hl)
    jr nc,l1e93h
    neg

; RESULT-OK
l1e91h:
    ld (hl),a
    ret

; RSLT-ZERO
l1e93h:
    rst 28h                 ; FP-CALC
    .byte    $02            ;;delete
    .byte    $A0            ;;stk-zero
    .byte    $34            ;;end-calc
    ret


; -------------------------------------
; THE 'NATURAL LOGARITHM' FUNCTION (22)
; -------------------------------------

; ln
sub_1e98h:
    rst 28h                 ; FP-CALC
    .byte    $2D            ;;duplicate
    .byte    $33            ;;greater-0
    .byte    $00            ;;jump-true
    .byte    $04            ;;to L1CB1, VALID
    .byte    $34            ;;end-calc

; REPORT-Ab
    rst 08h                 ; ERROR-1
    .byte    $09            ; AG invalid ArGument

; VALID
    .byte    $A0            ;;stk-zero              Note. not
    .byte    $02            ;;delete                necessary.
    .byte    $34            ;;end-calc
    ld a,(hl)
    ld (hl),080h
    call sub_1715h
    rst 28h                 ; FP-CALC
    .byte    $30            ;;stk-data
    .byte    $38            ;;Exponent: $88, Bytes: 1
    .byte    $00            ;;(+00,+00,+00)
    .byte    $03            ;;subtract
    .byte    $01            ;;exchange
    .byte    $2D            ;;duplicate
    .byte    $30            ;;stk-data
    .byte    $F0            ;;Exponent: $80, Bytes: 4
    .byte    $4C,$CC,$CC,$CD
    .byte    $03            ;;subtract
    .byte    $33            ;;greater-0
    .byte    $00            ;;jump-true
    .byte    $08            ;;to L1CD2, GRE.8

    .byte    $01            ;;exchange
    .byte    $A1            ;;stk-one
    .byte    $03            ;;subtract
    .byte    $01            ;;exchange
    .byte    $34            ;;end-calc
    inc (hl)

    rst 28h                 ; FP-CALC

;; GRE.8
    .byte    $01            ;;exchange
    .byte    $30            ;;stk-data
    .byte    $F0            ;;Exponent: $80, Bytes: 4
    .byte    $31,$72,$17,$F8
    .byte    $04            ;;multiply
    .byte    $01            ;;exchange
    .byte    $A2            ;;stk-half
    .byte    $03            ;;subtract
    .byte    $A2            ;;stk-half
    .byte    $03            ;;subtract
    .byte    $2D            ;;duplicate
    .byte    $30            ;;stk-data
    .byte    $32            ;;Exponent: $82, Bytes: 1
    .byte    $20            ;;(+00,+00,+00)
    .byte    $04            ;;multiply
    .byte    $A2            ;;stk-half
    .byte    $03            ;;subtract
    .byte    $8C            ;;series-0C
    .byte    $11            ;;Exponent: $61, Bytes: 1
    .byte    $AC            ;;(+00,+00,+00)
    .byte    $14            ;;Exponent: $64, Bytes: 1
    .byte    $09            ;;(+00,+00,+00)
    .byte    $56            ;;Exponent: $66, Bytes: 2
    .byte    $DA,$A5        ;;(+00,+00)
    .byte    $59            ;;Exponent: $69, Bytes: 2
    .byte    $30,$C5        ;;(+00,+00)
    .byte    $5C            ;;Exponent: $6C, Bytes: 2
    .byte    $90,$AA        ;;(+00,+00)
    .byte    $9E            ;;Exponent: $6E, Bytes: 3
    .byte    $70,$6F,$61    ;;(+00)
    .byte    $A1            ;;Exponent: $71, Bytes: 3
    .byte    $CB,$DA,$96    ;;(+00)
    .byte    $A4            ;;Exponent: $74, Bytes: 3
    .byte    $31,$9F,$B4    ;;(+00)
    .byte    $E7            ;;Exponent: $77, Bytes: 4
    .byte    $A0,$FE,$5C,$FC
    .byte    $EA            ;;Exponent: $7A, Bytes: 4
    .byte    $1B,$43,$CA,$36
    .byte    $ED            ;;Exponent: $7D, Bytes: 4
    .byte    $A7,$9C,$7E,$5E
    .byte    $F0            ;;Exponent: $80, Bytes: 4
    .byte    $6E,$23,$80,$93
    .byte    $04            ;;multiply
    .byte    $0F            ;;addition
    .byte    $34            ;;end-calc
    ret


; -----------------------------
; THE 'TRIGONOMETRIC' FUNCTIONS
; -----------------------------

;----- --------------------------------
; THE 'REDUCE ARGUMENT' SUBROUTINE (35)
; -------------------------------------

; get-argt
sub_1f07h:
    rst 28h                 ; FP-CALC         X.
    .byte    $30            ;;stk-data
    .byte    $EE            ;;Exponent: $7E,
                            ;;Bytes: 4
    .byte    $22,$F9,$83,$6E                ;  X, 1/(2*PI)
    .byte    $04            ;;multiply         X/(2*PI) = fraction

    .byte    $2D            ;;duplicate
    .byte    $A2            ;;stk-half
    .byte    $0F            ;;addition
    .byte    $24            ;;int

    .byte    $03            ;;subtract         now range -.5 to .5

    .byte    $2D            ;;duplicate
    .byte    $0F            ;;addition         now range -1 to 1.
    .byte    $2D            ;;duplicate
    .byte    $0F            ;;addition         now range -2 to 2.

    .byte    $2D            ;;duplicate        Y, Y.
    .byte    $27            ;;abs              Y, abs(Y).    range 1 to 2
    .byte    $A1            ;;stk-one          Y, abs(Y), 1.
    .byte    $03            ;;subtract         Y, abs(Y)-1.  range 0 to 1
    .byte    $2D            ;;duplicate        Y, Z, Z.
    .byte    $33            ;;greater-0        Y, Z, (1/0).

    .byte    $C0            ;;st-mem-0         store as possible sign for cosine function.

    .byte    $00            ;;jump-true
    .byte    $04            ;;to L1D35, ZPLUS  with quadrants II and III

    .byte    $02            ;;delete          Y    delete test value.
    .byte    $34            ;;end-calc        Y.

    ret

; ZPLUS
    .byte    $A1            ;;stk-one         Y, Z, 1
    .byte    $03            ;;subtract        Y, Z-1.       Q3 = 0 to -1
    .byte    $01            ;;exchange        Z-1, Y.
    .byte    $32            ;;less-0          Z-1, (1/0).
    .byte    $00            ;;jump-true       Z-1.
    .byte    $02            ;;to L1D3C, YNEG
    .byte    $18            ;;negate          range +1 to 0
;; YNEG
    .byte    $34            ;;end-calc        quadrants II and III correct.
    ret


; --------------------------
; THE 'COSINE' FUNCTION (1D)
; --------------------------

; cos
sub_1f2dh:
    rst 28h                 ; FP-CALC              angle in radians.
    .byte    $35            ;;get-argt              X       reduce -1 to +1
    .byte    $27            ;;abs                   ABS X   0 to 1
    .byte    $A1            ;;stk-one               ABS X, 1.
    .byte    $03            ;;subtract              now opposite angle
                            ;;                      though negative sign.
    .byte    $E0            ;;get-mem-0             fetch sign indicator.
    .byte    $00            ;;jump-true
    .byte    $06            ;;fwd to L1D4B, C-ENT
                            ;;forward to common code if in QII or QIII
    .byte    $18            ;;negate                else make positive.
    .byte    $2F            ;;jump
    .byte    $03            ;;fwd to L1D4B, C-ENT
                            ;;with quadrants QI and QIV

; ------------------------
; THE 'SINE' FUNCTION (1C)
; ------------------------

; sin
sub_1f38h:
    rst 28h                 ; FP-CALC      angle in radians
    .byte    $35            ;;get-argt      reduce - sign now correct.

;; C-ENT
    .byte    $2D            ;;duplicate
    .byte    $2D            ;;duplicate
    .byte    $04            ;;multiply
    .byte    $2D            ;;duplicate
    .byte    $0F            ;;addition
    .byte    $A1            ;;stk-one
    .byte    $03            ;;subtract

    .byte    $86            ;;series-06
    .byte    $14            ;;Exponent: $64, Bytes: 1
    .byte    $E6            ;;(+00,+00,+00)
    .byte    $5C            ;;Exponent: $6C, Bytes: 2
    .byte    $1F,$0B        ;;(+00,+00)
    .byte    $A3            ;;Exponent: $73, Bytes: 3
    .byte    $8F,$38,$EE    ;;(+00)
    .byte    $E9            ;;Exponent: $79, Bytes: 4
    .byte    $15,$63,$BB,$23
    .byte    $EE            ;;Exponent: $7E, Bytes: 4
    .byte    $92,$0D,$CD,$ED
    .byte    $F1            ;;Exponent: $81, Bytes: 4
    .byte    $23,$5D,$1B,$EA

    .byte    $04            ;;multiply
    .byte    $34            ;;end-calc
    ret

; ---------------------------
; THE 'TANGENT' FUNCTION (1E)
; ---------------------------

;; tan
sub_1f5dh:
    rst 28h                 ; FP-CALC          x.
    .byte    $2D            ;;duplicate         x, x.
    .byte    $1C            ;;sin               x, sin x.
    .byte    $01            ;;exchange          sin x, x.
    .byte    $1D            ;;cos               sin x, cos x.
    .byte    $05            ;;division          sin x/cos x (= tan x).
    .byte    $34            ;;end-calc          tan x.
    ret

; --------------------------
; THE 'ARCTAN' FUNCTION (21)
; --------------------------

; atn
sub_1f65h:
    ld a,(hl)
    cp 081h
    jr c,l1f78h
    rst 28h                 ; FP-CALC      X.
    .byte    $A1            ;;stk-one
    .byte    $18            ;;negate
    .byte    $01            ;;exchange
    .byte    $05            ;;division
    .byte    $2D            ;;duplicate
    .byte    $32            ;;less-0
    .byte    $A3            ;;stk-pi/2
    .byte    $01            ;;exchange
    .byte    $00            ;;jump-true
    .byte    $06            ;;to L1D8B, CASES

    .byte    $18            ;;negate
    .byte    $2F            ;;jump
    .byte    $03            ;;to L1D8B, CASES

l1f78h:
; SMALL
    rst 28h                 ; FP-CALC
    .byte    $A0            ;;stk-zero

;; CASES
    .byte    $01            ;;exchange
    .byte    $2D            ;;duplicate
    .byte    $2D            ;;duplicate
    .byte    $04            ;;multiply
    .byte    $2D            ;;duplicate
    .byte    $0F            ;;addition
    .byte    $A1            ;;stk-one
    .byte    $03            ;;subtract

    .byte    $8C            ;;series-0C
    .byte    $10            ;;Exponent: $60, Bytes: 1
    .byte    $B2            ;;(+00,+00,+00)
    .byte    $13            ;;Exponent: $63, Bytes: 1
    .byte    $0E            ;;(+00,+00,+00)
    .byte    $55            ;;Exponent: $65, Bytes: 2
    .byte    $E4,$8D        ;;(+00,+00)
    .byte    $58            ;;Exponent: $68, Bytes: 2
    .byte    $39,$BC        ;;(+00,+00)
    .byte    $5B            ;;Exponent: $6B, Bytes: 2
    .byte    $98,$FD        ;;(+00,+00)
    .byte    $9E            ;;Exponent: $6E, Bytes: 3
    .byte    $00,$36,$75    ;;(+00)
    .byte    $A0            ;;Exponent: $70, Bytes: 3
    .byte    $DB,$E8,$B4    ;;(+00)
    .byte    $63            ;;Exponent: $73, Bytes: 2
    .byte    $42,$C4        ;;(+00,+00)
    .byte    $E6            ;;Exponent: $76, Bytes: 4
    .byte    $B5,$09,$36,$BE
    .byte    $E9            ;;Exponent: $79, Bytes: 4
    .byte    $36,$73,$1B,$5D
    .byte    $EC            ;;Exponent: $7C, Bytes: 4
    .byte    $D8,$DE,$63,$BE
    .byte    $F0            ;;Exponent: $80, Bytes: 4
    .byte    $61,$A1,$B3,$0C

    .byte    $04            ;;multiply
    .byte    $0F            ;;addition
    .byte    $34            ;;end-calc
    ret

; --------------------------
; THE 'ARCSIN' FUNCTION (1F)
; --------------------------
;; asn
sub_1fb3h:
    rst 28h                 ; FP-CALC      x.
    .byte    $2D            ;;duplicate     x, x.
    .byte    $2D            ;;duplicate     x, x, x.
    .byte    $04            ;;multiply      x, x*x.
    .byte    $A1            ;;stk-one       x, x*x, 1.
    .byte    $03            ;;subtract      x, x*x-1.
    .byte    $18            ;;negate        x, 1-x*x.
    .byte    $25            ;;sqr           x, sqr(1-x*x) = y.
    .byte    $A1            ;;stk-one       x, y, 1.
    .byte    $0F            ;;addition      x, y+1.
    .byte    $05            ;;division      x/y+1.
    .byte    $21            ;;atn           a/2     (half the angle)
    .byte    $2D            ;;duplicate     a/2, a/2.
    .byte    $0F            ;;addition      a.
    .byte    $34            ;;end-calc      a.
    ret

; --------------------------
; THE 'ARCCOS' FUNCTION (20)
; --------------------------

;; acs
sub_1fc3h:
    rst 28h                 ; FP-CALC      x.
    .byte    $1F            ;;asn           asn(x).
    .byte    $A3            ;;stk-pi/2      asn(x), pi/2.
    .byte    $03            ;;subtract      asn(x) - pi/2.
    .byte    $18            ;;negate        pi/2 - asn(x) = acs(x).
    .byte    $34            ;;end-calc      acs(x)
    ret

; -------------------------------
; THE 'SQUARE ROOT' FUNCTION (25)
; -------------------------------

; sqr
sub_1fcah:
    rst 28h                 ; FP-CALC              x.
    .byte    $2D            ;;duplicate             x, x.
    .byte    $2C            ;;not                   x, 1/0
    .byte    $00            ;;jump-true             x, (1/0).
    .byte    $1E            ;;to L1DFD, LAST        exit if argument zero
    .byte    $A2            ;;stk-half              x, .5.
    .byte    $34            ;;end-calc              x, .5.

; -----------------------------------
; THE 'EXPONENTIATION' OPERATION (06)
; -----------------------------------

; to-power
sub_1fd1h:
    rst 28h                 ; FP-CALC              X,Y.
    .byte    $01            ;;exchange              Y,X.
    .byte    $2D            ;;duplicate             Y,X,X.
    .byte    $2C            ;;not                   Y,X,(1/0).
    .byte    $00            ;;jump-true
    .byte    $07            ;;forward to L1DEE, XISO if X is zero.

;   else X is non-zero. function 'ln' will catch a negative value of X.

    .byte    $22            ;;ln                    Y, LN X.
    .byte    $04            ;;multiply              Y * LN X
    .byte    $34            ;;end-calc
    jp l1e4ah

; XISO
    .byte    $02            ;;delete                Y.
    .byte    $2D            ;;duplicate             Y, Y.
    .byte    $2C            ;;not                   Y, (1/0).
    .byte    $00            ;;jump-true
    .byte    $09            ;;forward to L1DFB, ONE if Y is zero.
    .byte    $A0            ;;stk-zero              Y, 0.
    .byte    $01            ;;exchange              0, Y.
    .byte    $33            ;;greater-0             0, (1/0).
    .byte    $00            ;;jump-true             0
    .byte    $06            ;;to L1DFD, LAST        if Y was any positive number.
    .byte    $A1            ;;stk-one               0, 1.
    .byte    $01            ;;exchange              1, 0.
    .byte    $05            ;;division              1/0    >> error
; ONE
    .byte    $02            ;;delete                .
    .byte    $A1            ;;stk-one               1.

; LAST
    .byte    $34            ;;end-calc              last value 1 or 0.
    ret

; ---------------------
; THE 'SPARE LOCATIONS'
; ---------------------

; SPARE
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

.END
