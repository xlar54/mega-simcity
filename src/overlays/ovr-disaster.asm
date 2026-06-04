;=======================================================================================
; Disaster selector overlay (PRG, compiles to $A000).
;
; Loaded from Attic by disaster_invoke from the top-strip fire button. The
; overlay opens a compact modal popup, installs a body-click hook inside the
; shared $A000 window, and returns to the main loop. The selected value itself
; lives in resident main memory as disaster_selected.
;=======================================================================================

        .cpu "45gs02"
        .include "../../target/mega-simcity.lbl"

        * = OVR_WINDOW_ADDR

DISASTER_POPUP_W        = 16
DISASTER_POPUP_H        = 11
DISASTER_POPUP_L        = (VIEW_COLS - DISASTER_POPUP_W) / 2
DISASTER_POPUP_T        = (VIEW_ROWS - DISASTER_POPUP_H) / 2
DISASTER_ROW_COUNT      = 6
DISASTER_ROW_TOP_LOCAL  = 2
DISASTER_CHECKBOX_COL_LOCAL = 2
DISASTER_LABEL_COL_LOCAL = 4

ovr_disaster_main:
        lda #DISASTER_POPUP_W
        sta popup_w
        lda #DISASTER_POPUP_H
        sta popup_h
        lda #DISASTER_POPUP_L
        sta popup_l
        lda #DISASTER_POPUP_T
        sta popup_t

        lda #<disaster_body_click
        sta popup_body_click_hook
        lda #>disaster_body_click
        sta popup_body_click_hook+1

        lda #<str_disaster_title
        ldx #>str_disaster_title
        ldy #STR_DISASTER_TITLE_LEN
        jsr overlay_open
        jsr disaster_render_rows
        rts

;---------------------------------------------------------------------------------------
; Render rows
;---------------------------------------------------------------------------------------
disaster_render_rows:
        lda #0
        sta disaster_row_idx
_drr_loop:
        ldx disaster_row_idx
        cpx #DISASTER_ROW_COUNT
        bcs _drr_done
        jsr disaster_render_one_row
        inc disaster_row_idx
        bra _drr_loop
_drr_done:
        rts

disaster_render_one_row:
        stx disaster_row_idx
        inx
        stx disaster_option_id

        lda disaster_selected
        cmp disaster_option_id
        beq _dror_checked
        lda #<CHECKBOX_EMPTY_CHAR
        sta disaster_box_lo
        lda #>CHECKBOX_EMPTY_CHAR
        sta disaster_box_hi
        bra _dror_have_box
_dror_checked:
        lda #<CHECKBOX_CHECKED_CHAR
        sta disaster_box_lo
        lda #>CHECKBOX_CHECKED_CHAR
        sta disaster_box_hi
_dror_have_box:
        clc
        lda popup_t
        adc #DISASTER_ROW_TOP_LOCAL
        clc
        adc disaster_row_idx
        sta disaster_screen_row

        lda disaster_box_hi
        sta snc_char_hi
        clc
        lda popup_l
        adc #DISASTER_CHECKBOX_COL_LOCAL
        tax
        ldy disaster_screen_row
        lda disaster_box_lo
        jsr set_fcm_char16

        ldx disaster_row_idx
        lda disaster_label_lo,x
        sta PTR2
        lda disaster_label_hi,x
        sta PTR2+1
        lda disaster_label_len,x
        sta disaster_label_remaining
        lda #0
        sta disaster_label_offset
_dror_label_loop:
        lda disaster_label_offset
        cmp disaster_label_remaining
        bcs _dror_done
        ldy disaster_label_offset
        lda (PTR2),y
        pha
        clc
        lda popup_l
        adc #DISASTER_LABEL_COL_LOCAL
        clc
        adc disaster_label_offset
        tax
        ldy disaster_screen_row
        pla
        jsr set_fcm_char
        inc disaster_label_offset
        bra _dror_label_loop
_dror_done:
        rts

;---------------------------------------------------------------------------------------
; Body click
;---------------------------------------------------------------------------------------
disaster_body_click:
        clc
        lda popup_t
        adc #DISASTER_ROW_TOP_LOCAL
        asl
        asl
        asl
        sta disaster_y_band_top

        lda mouse_y
        cmp disaster_y_band_top
        bcc _dbc_done
        sec
        sbc disaster_y_band_top
        cmp #(DISASTER_ROW_COUNT * 8)
        bcs _dbc_done
        lsr
        lsr
        lsr
        sta disaster_clicked_row

        lda popup_l
        asl
        asl
        asl
        sta disaster_x_left
        lda mouse_x
        cmp disaster_x_left
        bcc _dbc_done
        sec
        sbc disaster_x_left
        cmp #(DISASTER_POPUP_W * 8)
        bcs _dbc_done

        ldx disaster_clicked_row
        inx
        stx disaster_option_id
        lda disaster_selected
        cmp disaster_option_id
        beq _dbc_deselect
        lda disaster_option_id
        sta disaster_selected
        bra _dbc_changed
_dbc_deselect:
        lda #DISASTER_NONE
        sta disaster_selected
_dbc_changed:
        jsr audio_click
        jsr disaster_render_rows
_dbc_done:
        rts

;---------------------------------------------------------------------------------------
; Strings + row label table
;---------------------------------------------------------------------------------------
str_disaster_title:
        .byte UI_TEXT_D, UI_TEXT_I, UI_TEXT_S, UI_TEXT_A, UI_TEXT_S, UI_TEXT_T, UI_TEXT_E, UI_TEXT_R
STR_DISASTER_TITLE_LEN = * - str_disaster_title

str_disaster_fire:
        .byte UI_TEXT_F, UI_TEXT_I, UI_TEXT_R, UI_TEXT_E
STR_DISASTER_FIRE_LEN = * - str_disaster_fire

str_disaster_tornado:
        .byte UI_TEXT_T, UI_TEXT_O, UI_TEXT_R, UI_TEXT_N, UI_TEXT_A, UI_TEXT_D, UI_TEXT_O
STR_DISASTER_TORNADO_LEN = * - str_disaster_tornado

str_disaster_earthquake:
        .byte UI_TEXT_E, UI_TEXT_A, UI_TEXT_R, UI_TEXT_T, UI_TEXT_H, UI_TEXT_Q, UI_TEXT_U, UI_TEXT_A, UI_TEXT_K, UI_TEXT_E
STR_DISASTER_EARTHQUAKE_LEN = * - str_disaster_earthquake

str_disaster_flood:
        .byte UI_TEXT_F, UI_TEXT_L, UI_TEXT_O, UI_TEXT_O, UI_TEXT_D
STR_DISASTER_FLOOD_LEN = * - str_disaster_flood

str_disaster_riot:
        .byte UI_TEXT_R, UI_TEXT_I, UI_TEXT_O, UI_TEXT_T
STR_DISASTER_RIOT_LEN = * - str_disaster_riot

str_disaster_monster:
        .byte UI_TEXT_M, UI_TEXT_O, UI_TEXT_N, UI_TEXT_S, UI_TEXT_T, UI_TEXT_E, UI_TEXT_R
STR_DISASTER_MONSTER_LEN = * - str_disaster_monster

disaster_label_lo:
        .byte <str_disaster_fire, <str_disaster_tornado, <str_disaster_earthquake
        .byte <str_disaster_flood, <str_disaster_riot, <str_disaster_monster
disaster_label_hi:
        .byte >str_disaster_fire, >str_disaster_tornado, >str_disaster_earthquake
        .byte >str_disaster_flood, >str_disaster_riot, >str_disaster_monster
disaster_label_len:
        .byte STR_DISASTER_FIRE_LEN, STR_DISASTER_TORNADO_LEN, STR_DISASTER_EARTHQUAKE_LEN
        .byte STR_DISASTER_FLOOD_LEN, STR_DISASTER_RIOT_LEN, STR_DISASTER_MONSTER_LEN

;---------------------------------------------------------------------------------------
; Scratch
;---------------------------------------------------------------------------------------
disaster_row_idx:              .byte 0
disaster_option_id:            .byte 0
disaster_box_lo:               .byte 0
disaster_box_hi:               .byte 0
disaster_screen_row:           .byte 0
disaster_label_offset:         .byte 0
disaster_label_remaining:      .byte 0
disaster_clicked_row:          .byte 0
disaster_y_band_top:           .byte 0
disaster_x_left:               .byte 0

        .cerror * > OVR_WINDOW_ADDR + OVR_WINDOW_SIZE, "disaster overlay exceeds OVR_WINDOW_SIZE"
