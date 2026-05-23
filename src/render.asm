;=======================================================================================
; Framed NCM renderer.
;=======================================================================================

render_init:
        jsr render_ui
        jsr render_viewport
        stz render_ui_dirty
        stz render_view_dirty
        rts

render_frame:
        lda render_ui_dirty
        beq _rf_view
        jsr render_ui
        stz render_ui_dirty
        lda #1
        sta render_view_dirty

_rf_view:
        lda render_view_dirty
        beq _rf_done
        jsr render_viewport
        stz render_view_dirty
_rf_done:
        rts

render_mark_ui_dirty:
        lda #1
        sta render_ui_dirty
        rts

render_mark_view_dirty:
        lda #1
        sta render_view_dirty
        rts

render_ui:
        ; Menu and city/status strips.
        lda #VIEW_COLS
        sta render_fill_w
        lda #1
        sta render_fill_h

        lda #UI_TILE_MENU
        ldx #0
        ldy #0
        jsr render_fill_rect

        lda #UI_TILE_STATUS_LIGHT
        ldx #0
        ldy #1
        jsr render_fill_rect

        lda #UI_TILE_STATUS_LIGHT
        ldx #0
        ldy #2
        jsr render_fill_rect

        lda #UI_TILE_FRAME
        ldx #0
        ldy #3
        jsr render_fill_rect

        lda #UI_TILE_FRAME
        ldx #0
        ldy #4
        jsr render_fill_rect

        ; Centered title on the top menu bar.
        lda #UI_TEXT_M
        ldx #16
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_E
        ldx #17
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_G
        ldx #18
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_A
        ldx #19
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_C
        ldx #20
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_I
        ldx #21
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_T
        ldx #22
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_Y
        ldx #23
        ldy #0
        jsr set_ncm_char

        ; Left toolbar and right window edge.
        lda #UI_LEFT_COLS
        sta render_fill_w
        lda #MAIN_NCM_ROWS
        sta render_fill_h
        lda #UI_TILE_PANEL
        ldx #0
        ldy #MAIN_ROW
        jsr render_fill_rect

        lda #UI_RIGHT_COLS
        sta render_fill_w
        lda #VIEW_ROWS-UI_TOP_ROWS
        sta render_fill_h
        lda #UI_TILE_FRAME
        ldx #VIEW_COLS-UI_RIGHT_COLS
        ldy #UI_TOP_ROWS
        jsr render_fill_rect

        jsr render_toolbar
        rts

; Draw the 16 toolbar buttons (UI_BTN_* block) in a 2x8 grid of 2x2 icons.
; Slot i: tile = UI_BTN_BASE + i*4, column = LEFT/RIGHT by i's low bit,
; row = ROW_TOP + (i & ~1).
render_toolbar:
        stz render_btn_slot
_rt_loop:
        lda render_btn_slot
        and #$FE
        clc
        adc #UI_TOOL_ROW_TOP
        sta render_btn_row
        lda render_btn_slot
        and #1
        beq _rt_left
        ldx #UI_TOOL_COL_RIGHT
        bra _rt_col_done
_rt_left:
        ldx #UI_TOOL_COL_LEFT
_rt_col_done:
        lda render_btn_slot
        asl
        asl
        clc
        adc #UI_BTN_BASE
        ldy render_btn_row
        jsr render_draw_2x2_icon
        inc render_btn_slot
        lda render_btn_slot
        cmp #UI_BTN_COUNT
        bne _rt_loop

        ; The very first icon drawn in this loop (slot 0) does not persist on
        ; screen once later slots are drawn after it; its cells stay the panel
        ; fill. The cause is unresolved, but redrawing slot 0 here (after the
        ; rest of the grid) makes it stick. All other slots render correctly.
        lda #UI_BTN_BASE
        ldx #UI_TOOL_COL_LEFT
        ldy #UI_TOOL_ROW_TOP
        jsr render_draw_2x2_icon
        rts

; A = base char id of a 2x2 icon (uses base..base+3), X = left col, Y = top row.
render_draw_2x2_icon:
        sta render_icon_base
        stx render_icon_left
        sty render_icon_top

        lda render_icon_base
        ldx render_icon_left
        ldy render_icon_top
        jsr set_ncm_char

        lda render_icon_base
        clc
        adc #1
        ldx render_icon_left
        inx
        ldy render_icon_top
        jsr set_ncm_char

        lda render_icon_base
        clc
        adc #2
        ldx render_icon_left
        ldy render_icon_top
        iny
        jsr set_ncm_char

        lda render_icon_base
        clc
        adc #3
        ldx render_icon_left
        inx
        ldy render_icon_top
        iny
        jsr set_ncm_char
        rts

render_fill_rect:
        sta render_fill_tile
        stx render_fill_left
        sty render_fill_top
        lda render_fill_w
        beq _rfr_done
        lda render_fill_h
        beq _rfr_done
        lda render_fill_h
        sta render_fill_rows
        lda render_fill_top
        sta render_row

_rfr_row:
        lda render_fill_left
        sta render_col
        lda render_fill_w
        sta render_fill_cols

_rfr_col:
        lda render_fill_tile
        ldx render_col
        ldy render_row
        jsr set_ncm_char
        inc render_col
        dec render_fill_cols
        bne _rfr_col

        inc render_row
        dec render_fill_rows
        bne _rfr_row
_rfr_done:
        rts

render_viewport:
        stz render_tile_y
_rv_row:
        stz render_tile_x
_rv_col:
        clc
        lda view_x
        adc render_tile_x
        sta city_ptr_x
        clc
        lda view_y
        adc render_tile_y
        sta city_ptr_y
        jsr city_ptr_for_xy

        ldy #0
        lda (PTR2),y
        jsr render_draw_16x16_tile

        inc render_tile_x
        lda render_tile_x
        cmp #MAIN_TILE_COLS
        bne _rv_col

        inc render_tile_y
        lda render_tile_y
        cmp #MAIN_TILE_ROWS
        bne _rv_row
        rts

render_draw_16x16_tile:
        sta render_tile_id
        asl
        asl
        sta render_char_base

        lda render_tile_x
        asl
        clc
        adc #MAIN_COL
        sta render_screen_col

        lda render_tile_y
        asl
        clc
        adc #MAIN_ROW
        sta render_screen_row

        lda render_char_base
        ldx render_screen_col
        ldy render_screen_row
        jsr set_ncm_char

        lda render_char_base
        clc
        adc #1
        ldx render_screen_col
        inx
        ldy render_screen_row
        jsr set_ncm_char

        lda render_char_base
        clc
        adc #2
        ldx render_screen_col
        ldy render_screen_row
        iny
        jsr set_ncm_char

        lda render_char_base
        clc
        adc #3
        ldx render_screen_col
        inx
        ldy render_screen_row
        iny
        jsr set_ncm_char
        rts

render_col:
        .byte 0
render_row:
        .byte 0
render_tile_x:
        .byte 0
render_tile_y:
        .byte 0
render_tile_id:
        .byte 0
render_char_base:
        .byte 0
render_screen_col:
        .byte 0
render_screen_row:
        .byte 0
render_fill_tile:
        .byte 0
render_icon_base:
        .byte 0
render_btn_slot:
        .byte 0
render_btn_row:
        .byte 0
render_icon_left:
        .byte 0
render_icon_top:
        .byte 0
render_icon_col:
        .byte 0
render_icon_row:
        .byte 0
render_icon_tile:
        .byte 0
render_fill_left:
        .byte 0
render_fill_top:
        .byte 0
render_fill_w:
        .byte 0
render_fill_h:
        .byte 0
render_fill_cols:
        .byte 0
render_fill_rows:
        .byte 0
render_ui_dirty:
        .byte 0
render_view_dirty:
        .byte 0
