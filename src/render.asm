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
        ldx #36
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_E
        ldx #37
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_G
        ldx #38
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_A
        ldx #39
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_C
        ldx #40
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_I
        ldx #41
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_T
        ldx #42
        ldy #0
        jsr set_ncm_char
        lda #UI_TEXT_Y
        ldx #43
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

        ; RCI meter stub in the lower left rail.
        lda #UI_LEFT_COLS
        sta render_fill_w
        lda #4
        sta render_fill_h
        lda #UI_TILE_RCI_PANEL
        ldx #0
        ldy #18
        jsr render_fill_rect

        ; Tool buttons.
        lda #UI_TILE_TOOL_ROAD
        ldx #0
        ldy #5
        jsr set_ncm_char
        lda #UI_TILE_TOOL_RES
        ldx #2
        ldy #5
        jsr set_ncm_char
        lda #UI_TILE_TOOL_COM
        ldx #0
        ldy #7
        jsr set_ncm_char
        lda #UI_TILE_TOOL_IND
        ldx #2
        ldy #7
        jsr set_ncm_char
        lda #UI_TILE_TOOL_POWER
        ldx #0
        ldy #9
        jsr set_ncm_char
        lda #UI_TILE_TOOL_WATER
        ldx #2
        ldy #9
        jsr set_ncm_char
        lda #UI_TILE_HELP
        ldx #2
        ldy #22
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

render_cursor:
        lda cursor_x
        cmp view_x
        bcc _rc_done
        sec
        sbc view_x
        cmp #MAIN_TILE_COLS
        bcs _rc_done
        sta render_tile_x

        lda cursor_y
        cmp view_y
        bcc _rc_done
        sec
        sbc view_y
        cmp #MAIN_TILE_ROWS
        bcs _rc_done
        sta render_tile_y

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

        lda #CITY_CHAR_CURSOR
        ldx render_screen_col
        ldy render_screen_row
        jsr set_ncm_char

        lda #CITY_CHAR_CURSOR+1
        ldx render_screen_col
        inx
        ldy render_screen_row
        jsr set_ncm_char

        lda #CITY_CHAR_CURSOR+2
        ldx render_screen_col
        ldy render_screen_row
        iny
        jsr set_ncm_char

        lda #CITY_CHAR_CURSOR+3
        ldx render_screen_col
        inx
        ldy render_screen_row
        iny
        jsr set_ncm_char
_rc_done:
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
