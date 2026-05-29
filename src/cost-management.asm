;=======================================================================================
; Funds / cost management.
;
; The player starts with FUNDS_INITIAL ($500,000) and each successful placement
; deducts the per-tile cost from docs/TILE_RULES.md. Each placement path calls
; funds_can_afford up front (skips silently if too poor) and funds_subtract after
; commit. Setting funds_dirty asks funds_update (called from the game loop) to
; redraw the FUNDS readout on the top menu bar.
;
; The readout is "$XXXXXXX" rendered at row 0 starting at column 30, right-
; aligned with leading-zero suppression (so $500,000 reads as "  500000" in the
; 7-digit field). The DATE field sits to the left at cols 20..27.
;=======================================================================================

; --- per-tile costs (dollars, 16-bit) ---
COST_BULLDOZE   = 1
COST_ROAD       = 10
COST_POWERLINE  = 5
COST_RAIL       = 20            ; land rail per tile
COST_RAIL_BRIDGE = 100          ; rail bridge per tile (straight only over water)
COST_ZONE       = 100
COST_COALPP     = 3000
COST_NUCLEARPP  = 5000

FUNDS_INITIAL   = 500000

; Menu-bar layout (row 0) for the "$XXXXXXX" field. No commas; leading zeros
; are blanked so a value below 1,000,000 doesn't look like it has padding zeros.
FUNDS_ROW       = 0
FUNDS_COL_DOL   = 30
FUNDS_COL_MIL   = 31    ; millions digit       (blank if value < 1,000,000)
FUNDS_COL_HT    = 32    ; hundred-thousands    (blank if value < 100,000)
FUNDS_COL_TT    = 33    ; ten-thousands        (blank if value < 10,000)
FUNDS_COL_T     = 34    ; thousands            (blank if value < 1,000)
FUNDS_COL_H     = 35    ; hundreds             (blank if value < 100)
FUNDS_COL_TE    = 36    ; tens                 (blank if value < 10)
FUNDS_COL_U     = 37    ; units                (always shown)

;---------------------------------------------------------------------------------------
; Public API
;---------------------------------------------------------------------------------------

funds_init:
        lda #<FUNDS_INITIAL
        sta funds
        lda #>FUNDS_INITIAL
        sta funds+1
        lda #`FUNDS_INITIAL
        sta funds+2
        lda #0
        sta funds+3
        lda #1
        sta funds_dirty
        rts

; Carry SET if funds >= cost_amount (16-bit; caller must load cost_amount first).
; Does not modify funds. Preserves nothing else.
funds_can_afford:
        lda funds
        cmp cost_amount
        lda funds+1
        sbc cost_amount+1
        lda funds+2
        sbc #0
        lda funds+3
        sbc #0
        rts

; funds -= cost_amount; mark the readout dirty. Caller should have verified
; funds_can_afford first.
funds_subtract:
        sec
        lda funds
        sbc cost_amount
        sta funds
        lda funds+1
        sbc cost_amount+1
        sta funds+1
        lda funds+2
        sbc #0
        sta funds+2
        lda funds+3
        sbc #0
        sta funds+3
        lda #1
        sta funds_dirty
        rts

; Called once per frame from the game loop. Redraws the FUNDS readout iff dirty.
funds_update:
        lda funds_dirty
        beq _fu_done
        lda #0
        sta funds_dirty
        jmp funds_render
_fu_done:
        rts

;---------------------------------------------------------------------------------------
; Internal: convert funds to 7 decimal digits via repeated subtraction of each
; power of ten. fd_digits[0..6] = millions..units.
;---------------------------------------------------------------------------------------

funds_to_digits:
        lda funds
        sta fd_work
        lda funds+1
        sta fd_work+1
        lda funds+2
        sta fd_work+2
        lda funds+3
        sta fd_work+3
        ldx #0
_ftd_loop:
        lda #0
        sta fd_count
_ftd_sub:
        lda fd_work                 ; compare fd_work vs powers[X] (24-bit)
        cmp fd_powers_lo,x
        lda fd_work+1
        sbc fd_powers_hi,x
        lda fd_work+2
        sbc fd_powers_up,x
        lda fd_work+3
        sbc #0
        bcc _ftd_next               ; fd_work < power -> next digit
        sec                         ; fd_work -= power
        lda fd_work
        sbc fd_powers_lo,x
        sta fd_work
        lda fd_work+1
        sbc fd_powers_hi,x
        sta fd_work+1
        lda fd_work+2
        sbc fd_powers_up,x
        sta fd_work+2
        lda fd_work+3
        sbc #0
        sta fd_work+3
        inc fd_count
        jmp _ftd_sub
_ftd_next:
        lda fd_count
        sta fd_digits,x
        inx
        cpx #7
        bne _ftd_loop
        rts

; Powers of ten: 1,000,000 / 100,000 / 10,000 / 1,000 / 100 / 10 / 1 (24-bit).
fd_powers_lo:  .byte $40,$A0,$10,$E8,$64,$0A,$01
fd_powers_hi:  .byte $42,$86,$27,$03,$00,$00,$00
fd_powers_up:  .byte $0F,$01,$00,$00,$00,$00,$00

;---------------------------------------------------------------------------------------
; Render the "$XXXXXXX" field on the menu bar (row 0). Idempotent: redraws
; both the $ glyph and the 7 digits each call. Leading-zero blanking keeps
; smaller numbers from looking padded.
;---------------------------------------------------------------------------------------

funds_render:
        jsr funds_to_digits

        ; $ glyph (col 20)
        lda #UI_TEXT_DOLLAR
        ldx #FUNDS_COL_DOL
        ldy #FUNDS_ROW
        jsr set_fcm_char

        ; --- digits 0..6 = millions..units, with leading-zero blanking ---
        lda #0
        sta fd_seen

        ; millions (col 21)
        lda fd_digits
        beq _fr_d0_blank
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_MIL
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d1
_fr_d0_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_MIL
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d1:
        ; hundred-thousands (col 22)
        lda fd_digits+1
        ora fd_seen
        beq _fr_d1_blank
        lda fd_digits+1
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_HT
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d2
_fr_d1_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_HT
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d2:
        ; ten-thousands (col 23)
        lda fd_digits+2
        ora fd_seen
        beq _fr_d2_blank
        lda fd_digits+2
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_TT
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d3
_fr_d2_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_TT
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d3:
        ; thousands (col 24)
        lda fd_digits+3
        ora fd_seen
        beq _fr_d3_blank
        lda fd_digits+3
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_T
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d4
_fr_d3_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_T
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d4:
        ; hundreds (col 25)
        lda fd_digits+4
        ora fd_seen
        beq _fr_d4_blank
        lda fd_digits+4
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_H
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d5
_fr_d4_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_H
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d5:
        ; tens (col 26)
        lda fd_digits+5
        ora fd_seen
        beq _fr_d5_blank
        lda fd_digits+5
        jsr fr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_TE
        ldy #FUNDS_ROW
        jsr set_fcm_char
        bra _fr_d6
_fr_d5_blank:
        lda #UI_TILE_MENU
        ldx #FUNDS_COL_TE
        ldy #FUNDS_ROW
        jsr set_fcm_char

_fr_d6:
        ; units (col 27) -- always shown, even if value is zero
        lda fd_digits+6
        clc
        adc #UI_TEXT_0
        ldx #FUNDS_COL_U
        ldy #FUNDS_ROW
        jsr set_fcm_char
        rts

; Helper: mark "non-zero digit seen". Preserves A.
fr_set_seen:
        pha
        lda #1
        sta fd_seen
        pla
        rts

; --- state ---
funds:                          ; current funds, 32-bit
        .byte 0, 0, 0, 0
funds_dirty:                    ; nonzero -> redraw the readout next frame
        .byte 0
cost_amount:                    ; 16-bit cost set by callers before
        .word 0                 ; funds_can_afford / funds_subtract

; digit-conversion scratch
fd_work:                        ; 32-bit working copy of funds
        .byte 0, 0, 0, 0
fd_count:                       ; current digit accumulator
        .byte 0
fd_digits:                      ; the 7 decoded digits (millions..units)
        .fill 7, 0
fd_seen:                        ; 1 once a non-zero digit has been rendered
        .byte 0
