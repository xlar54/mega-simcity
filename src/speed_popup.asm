;=======================================================================================
; Speed popup (inline, lives in main.prg).
;
; A small 3-radio-button popup for picking the game speed. Opened by clicking
; the SPEED button on the top strip; closed by the OK button (overlay
; framework handles that). While open, clicks on the body rows update
; sim_speed and re-stamp the checkmark on the new row -- the popup stays open
; so the user can see the selection before dismissing.
;
; Body layout in a default 16x8 popup (popup_l=12, popup_t=8, popup_w=16,
; popup_h=8). Title row 0 holds "SPEED". OK button is at popup-local rows
; 5-6. Body rows 2-4 are the three checkbox lines:
;
;   col:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
;   row2: .  .  []  .  S  L  O  W  .  .  .  .  .  .  .  .
;   row3: .  .  []  .  N  O  R  M  A  L  .  .  .  .  .  .
;   row4: .  .  []  .  F  A  S  T  .  .  .  .  .  .  .  .
;
; (Checkbox occupies popup_l + 2; label starts at popup_l + 4 with a single
; space between.) The whole row is the click target -- not just the
; checkbox -- so the user has a comfortably-sized hit zone.
;
; popup_body_click_hook (popup.asm) is registered in speed_invoke and
; auto-cleared by overlay_close on the next OK click.
;=======================================================================================

SPEED_ROW_TOP_LOCAL     = 2     ; popup-local row of the SLOW checkbox
SPEED_CHECKBOX_COL_LOCAL = 2     ; popup-local col of the checkboxes (all 3 rows)
SPEED_LABEL_COL_LOCAL   = 4     ; popup-local col where the label starts

;---------------------------------------------------------------------------------------
; speed_invoke
; Toolbar dispatch jumps here on a SPEED-button click. Sets up the default
; popup geometry, opens with "SPEED" title, registers the body-click hook,
; and renders the 3 radio rows with a checkmark on the active row.
;---------------------------------------------------------------------------------------
speed_invoke:
        jsr overlay_set_default_geometry
        ; Register the body-click handler before overlay_open so any frame
        ; that races between open and our render still routes clicks
        ; correctly. overlay_close (on OK) clears the hook for us.
        lda #<speed_body_click
        sta popup_body_click_hook
        lda #>speed_body_click
        sta popup_body_click_hook+1
        ; A:X = title pointer, Y = title length.
        lda #<str_speed_title
        ldx #>str_speed_title
        ldy #STR_SPEED_TITLE_LEN
        jsr overlay_open
        ; Stamp the 3 rows: checkbox + label. Active row gets the checked
        ; glyph; the other two get the empty glyph.
        jsr speed_render_rows
        rts

;---------------------------------------------------------------------------------------
; speed_render_rows
; Stamp all 3 rows. For each row i (0..2), the checkbox char is CHECKBOX_
; CHECKED_CHAR if sim_speed == i else CHECKBOX_EMPTY_CHAR, and the label
; comes from the per-row table.
;---------------------------------------------------------------------------------------
speed_render_rows:
        lda #0
        sta speed_row_idx
_srr_loop:
        ldx speed_row_idx
        cpx #3
        bcs _srr_done
        jsr speed_render_one_row
        inc speed_row_idx
        bra _srr_loop
_srr_done:
        rts

;---------------------------------------------------------------------------------------
; speed_render_one_row(X = row index)
; Stamps the checkbox glyph + the label characters for row X. Preserves X
; across set_fcm_char calls by reloading from speed_row_idx where needed.
;---------------------------------------------------------------------------------------
speed_render_one_row:
        stx speed_row_idx
        ; Checkbox glyph: pick CHECKED if sim_speed == X, else EMPTY.
        ; Both chars live above char id 255, so set_fcm_char16 + snc_char_hi
        ; is required (the 8-bit set_fcm_char would lose the high bit).
        lda sim_speed
        cmp speed_row_idx
        beq _sror_checked
        lda #<CHECKBOX_EMPTY_CHAR
        sta speed_box_lo
        lda #>CHECKBOX_EMPTY_CHAR
        sta speed_box_hi
        bra _sror_have_box
_sror_checked:
        lda #<CHECKBOX_CHECKED_CHAR
        sta speed_box_lo
        lda #>CHECKBOX_CHECKED_CHAR
        sta speed_box_hi
_sror_have_box:
        ; Compute screen-row = popup_t + SPEED_ROW_TOP_LOCAL + row_idx.
        clc
        lda popup_t
        adc #SPEED_ROW_TOP_LOCAL
        clc
        adc speed_row_idx
        sta speed_screen_row
        ; Stamp the checkbox at col = popup_l + SPEED_CHECKBOX_COL_LOCAL.
        lda speed_box_hi
        sta snc_char_hi
        clc
        lda popup_l
        adc #SPEED_CHECKBOX_COL_LOCAL
        tax
        ldy speed_screen_row
        lda speed_box_lo
        jsr set_fcm_char16
        ; Stamp the label string char-by-char from the per-row table.
        ldx speed_row_idx
        lda speed_label_lo,x
        sta PTR2
        lda speed_label_hi,x
        sta PTR2+1
        lda speed_label_len,x
        sta speed_label_remaining
        lda #0
        sta speed_label_offset
_sror_label_loop:
        lda speed_label_offset
        cmp speed_label_remaining
        bcs _sror_done
        ldy speed_label_offset
        lda (PTR2),y
        pha
        clc
        lda popup_l
        adc #SPEED_LABEL_COL_LOCAL
        clc
        adc speed_label_offset
        tax
        ldy speed_screen_row
        pla
        jsr set_fcm_char
        inc speed_label_offset
        bra _sror_label_loop
_sror_done:
        rts

;---------------------------------------------------------------------------------------
; speed_body_click
; Registered as popup_body_click_hook in speed_invoke. Fired by overlay_
; handle_click when a click lands anywhere outside the OK rect while the
; speed popup is open. If the click is on one of the 3 rows (vertically),
; update sim_speed to that row's index and re-render. Other coords are
; swallowed (popup stays open, no state change). Popup closes only on OK.
;---------------------------------------------------------------------------------------
speed_body_click:
        ; mouse_y must be in [(popup_t + SPEED_ROW_TOP_LOCAL) * 8,
        ;                     (popup_t + SPEED_ROW_TOP_LOCAL + 3) * 8) for
        ; ANY row to match.
        clc
        lda popup_t
        adc #SPEED_ROW_TOP_LOCAL
        asl
        asl
        asl
        sta speed_y_band_top
        lda mouse_y
        cmp speed_y_band_top
        bcc _sbc_done
        sec
        sbc speed_y_band_top
        ; A = mouse_y - band_top (0..23 spans the 3 rows). Row index = A / 8.
        cmp #24
        bcs _sbc_done
        lsr
        lsr
        lsr
        ; X axis: require a click within the popup horizontal extent. (X is
        ; <256 because the popup is fully on-screen at default geometry; we
        ; rejected X >= 256 in overlay_handle_click already via mouse_x+1.)
        sta speed_clicked_row
        lda popup_l
        asl
        asl
        asl
        sta speed_x_left
        lda mouse_x
        cmp speed_x_left
        bcc _sbc_done
        sec
        sbc speed_x_left
        cmp #(POPUP_DEFAULT_W * 8)
        bcs _sbc_done
        ; Confirmed: clicked row = speed_clicked_row, update sim_speed and
        ; redraw the three rows.
        lda sim_speed
        cmp speed_clicked_row
        beq _sbc_done                   ; no change -> skip audio + redraw
        lda speed_clicked_row
        sta sim_speed
        jsr audio_click
        jsr speed_render_rows
_sbc_done:
        rts

;---------------------------------------------------------------------------------------
; Strings + per-row label table
;---------------------------------------------------------------------------------------
str_speed_title:
        .byte UI_TEXT_S, UI_TEXT_P, UI_TEXT_E, UI_TEXT_E, UI_TEXT_D
STR_SPEED_TITLE_LEN = * - str_speed_title

str_speed_slow:
        .byte UI_TEXT_S, UI_TEXT_L, UI_TEXT_O, UI_TEXT_W
STR_SPEED_SLOW_LEN = * - str_speed_slow

str_speed_normal:
        .byte UI_TEXT_N, UI_TEXT_O, UI_TEXT_R, UI_TEXT_M, UI_TEXT_A, UI_TEXT_L
STR_SPEED_NORMAL_LEN = * - str_speed_normal

str_speed_fast:
        .byte UI_TEXT_F, UI_TEXT_A, UI_TEXT_S, UI_TEXT_T
STR_SPEED_FAST_LEN = * - str_speed_fast

; Parallel arrays indexed by sim_speed (0..2) -> pointer to the row label.
speed_label_lo:  .byte <str_speed_slow, <str_speed_normal, <str_speed_fast
speed_label_hi:  .byte >str_speed_slow, >str_speed_normal, >str_speed_fast
speed_label_len: .byte STR_SPEED_SLOW_LEN, STR_SPEED_NORMAL_LEN, STR_SPEED_FAST_LEN

;---------------------------------------------------------------------------------------
; Scratch
;---------------------------------------------------------------------------------------
speed_row_idx:          .byte 0
speed_box_lo:           .byte 0
speed_box_hi:           .byte 0
speed_screen_row:       .byte 0
speed_label_offset:     .byte 0
speed_label_remaining:  .byte 0
speed_clicked_row:      .byte 0
speed_y_band_top:       .byte 0
speed_x_left:           .byte 0
