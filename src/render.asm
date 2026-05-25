;=======================================================================================
; Framed FCM renderer.
;=======================================================================================

; The map viewport underlaps the static chrome (MAP_OVERLAP_*), so the map must
; be drawn FIRST and the chrome (toolbar/menu/frame) drawn on top of it.
render_init:
        jsr render_viewport
        jsr render_ui
        lda #0
        sta render_ui_dirty
        sta render_view_dirty
        rts

render_frame:
        lda render_view_dirty
        beq _rf_ui
        jsr render_viewport
        lda #0
        sta render_view_dirty
        lda #1
        sta render_ui_dirty         ; chrome sits on top; redraw it over the map

_rf_ui:
        lda render_ui_dirty
        beq _rf_done
        jsr render_ui
        lda #0
        sta render_ui_dirty
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

        ; Centered title on the top menu bar.
        lda #UI_TEXT_M
        ldx #16
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_E
        ldx #17
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_G
        ldx #18
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_A
        ldx #19
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_C
        ldx #20
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_I
        ldx #21
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_T
        ldx #22
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_Y
        ldx #23
        ldy #0
        jsr set_fcm_char

        ; Left toolbar and right window edge.
        lda #UI_LEFT_COLS
        sta render_fill_w
        lda #MAIN_FCM_ROWS
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

        jsr toolbar_render
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
        jsr set_fcm_char
        inc render_col
        dec render_fill_cols
        bne _rfr_col

        inc render_row
        dec render_fill_rows
        bne _rfr_row
_rfr_done:
        rts

render_viewport:
        lda #0
        sta render_tile_y
_rv_row:
        lda #0
        sta render_tile_x
_rv_col:
        clc
        lda view_x
        adc render_tile_x
        asl                         ; cell_x = (view_x + tile_x) * 2
        sta city_ptr_x
        clc
        lda view_y
        adc render_tile_y
        asl                         ; cell_y = (view_y + tile_y) * 2
        sta city_ptr_y
        jsr city_cell_ptr
        jsr render_draw_tile

        inc render_tile_x
        lda render_tile_x
        cmp #MAIN_TILE_COLS
        bne _rv_col

        inc render_tile_y
        lda render_tile_y
        cmp #MAIN_TILE_ROWS
        bne _rv_row
        rts

; Draw a 16x16 tile as its four 8x8 cells. PTR2 = the tile's top-left cell;
; each cell renders its type's quadrant (type*4 + parity), except a road cell
; which always renders the single 8x8 ROAD_CELL_CHAR.
render_draw_tile:
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

        ldy #0                      ; TL cell, parity 0
        lda (PTR2),y
        ldx #0
        jsr cell_to_char
        ldx render_screen_col
        ldy render_screen_row
        jsr set_fcm_char

        ldy #1                      ; TR cell, parity 1
        lda (PTR2),y
        ldx #1
        jsr cell_to_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        jsr set_fcm_char

        ldy #CELL_COLS              ; BL cell, parity 2
        lda (PTR2),y
        ldx #2
        jsr cell_to_char
        ldx render_screen_col
        ldy render_screen_row
        iny
        jsr set_fcm_char

        ldy #CELL_COLS+1           ; BR cell, parity 3
        lda (PTR2),y
        ldx #3
        jsr cell_to_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        iny
        jsr set_fcm_char
        rts

; A = cell value, X = parity (0-3) -> A = char offset to draw. A cell byte with
; bit 7 set is a literal char (low 7 bits); otherwise it is a tile type.
cell_to_char:
        cmp #$80                    ; bit 7 set -> literal char (N flag from the
        bcs _ctc_literal            ; caller's ldx is unreliable, so test via cmp)
        cmp #TILE_ROAD
        beq _ctc_road
        cmp #TILE_RESIDENTIAL
        beq _ctc_res_box
        cmp #TILE_COMMERCIAL
        beq _ctc_com_box
        cmp #TILE_INDUSTRIAL
        beq _ctc_ind_box
        cmp #TILE_RES_CENTER
        beq _ctc_res_center
        cmp #TILE_COM_CENTER
        beq _ctc_com_center
        cmp #TILE_IND_CENTER
        beq _ctc_ind_center
        ; water / ground / power: 2x2 tile, char = type*4 + parity
        asl
        asl
        sta render_char_base
        txa
        clc
        adc render_char_base
        rts
_ctc_literal:
        and #$7F
        rts
_ctc_road:
        lda #ROAD_CELL_CHAR
        rts
_ctc_res_box:
        lda #ZONE_RES_BOX_CHAR
        rts
_ctc_com_box:
        lda #ZONE_COM_BOX_CHAR
        rts
_ctc_ind_box:
        lda #ZONE_IND_BOX_CHAR
        rts
_ctc_res_center:
        lda #ZONE_RES_CENTER_CHAR
        rts
_ctc_com_center:
        lda #ZONE_COM_CENTER_CHAR
        rts
_ctc_ind_center:
        lda #ZONE_IND_CENTER_CHAR
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
