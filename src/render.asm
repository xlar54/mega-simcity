;=======================================================================================
; Framed FCM renderer.
;=======================================================================================

; The map and chrome occupy non-overlapping screen rows: render_viewport skips
; the tile rows hidden under the top chrome (FIRST_VISIBLE_TILE_ROW), so the map
; never draws into the chrome. The chrome is therefore drawn once at init and not
; redrawn on scroll -- redrawing it every scroll frame is what made the bar
; flicker (real HW) and let the map bleed into it (Xemu).
render_init:
        jsr render_ui
        jsr render_viewport
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

        ; Title at the top-left of the menu bar (cols 1..8); the FUNDS readout
        ; takes the rest of the bar starting at col 18 (cost-management.asm).
        lda #UI_TEXT_M
        ldx #1
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_E
        ldx #2
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_G
        ldx #3
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_A
        ldx #4
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_C
        ldx #5
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_I
        ldx #6
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_T
        ldx #7
        ldy #0
        jsr set_fcm_char
        lda #UI_TEXT_Y
        ldx #8
        ldy #0
        jsr set_fcm_char
        jsr funds_render            ; FUNDS: $xxx,xxx at cols 18+

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
        lda #FIRST_VISIBLE_TILE_ROW  ; skip tile rows hidden under the top chrome
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

; Draw a 16x16 tile as its four 8x8 cells. MAP_PTR = the tile's top-left cell in
; Attic; each cell maps to a char via cell_to_char (type quadrant, literal char,
; or road). Cells are read with 32-bit indirect addressing ([MAP_PTR],z),
; z = 0/1/CELL_COLS/CELL_COLS+1.
; MAP_PTR ($F6-$F9) survives set_fcm_char, which only touches PTR ($FC-$FF).
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

        ldz #0                      ; TL cell, parity 0
        lda [MAP_PTR],z
        ldx #0
        jsr cell_to_char
        ldx render_screen_col
        ldy render_screen_row
        jsr set_fcm_char

        ldz #1                      ; TR cell, parity 1
        lda [MAP_PTR],z
        ldx #1
        jsr cell_to_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        jsr set_fcm_char

        ldz #CELL_COLS              ; BL cell, parity 2
        lda [MAP_PTR],z
        ldx #2
        jsr cell_to_char
        ldx render_screen_col
        ldy render_screen_row
        iny
        jsr set_fcm_char

        ldz #CELL_COLS+1           ; BR cell, parity 3
        lda [MAP_PTR],z
        ldx #3
        jsr cell_to_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        iny
        jsr set_fcm_char
        rts

; A = cell value, X = parity (0-3) -> A = char to draw.
;   bit 7 set       -> literal char (low 7 bits)
;   ROAD_CELL_FIRST..LAST -> road; the value IS the char (no arithmetic)
;   otherwise       -> 2x2 tile type: char = type*4 + parity (water/ground/power)
cell_to_char:
        cmp #$80                    ; bit 7 set -> literal char (N flag from the
        bcs _ctc_literal            ; caller's ldx is unreliable, so test via cmp)
        cmp #ROAD_CELL_FIRST
        bcc _ctc_type
        cmp #ROAD_CELL_LAST+1
        bcc _ctc_done               ; road: A already holds the char
        cmp #POWERLINE_CELL_FIRST
        bcc _ctc_type
        cmp #POWERLINE_CELL_LAST+1
        bcc _ctc_done               ; power line: A already holds the char
        cmp #COALPP_CELL_FIRST
        bcc _ctc_type
        cmp #COALPP_CELL_LAST+1
        bcs _ctc_type
        ; coal plant cell: char = (value - COALPP_CELL_FIRST) + COALPP_CHAR_BASE
        sec
        sbc #COALPP_CELL_FIRST
        clc
        adc #COALPP_CHAR_BASE
        rts
_ctc_type:
        ; water / ground / power: 2x2 tile, char = type*4 + parity. Zones never
        ; appear as a base type here -- they are painted/seeded as literal chars.
        asl
        asl
        sta render_char_base
        txa
        clc
        adc render_char_base
_ctc_done:
        rts
_ctc_literal:
        and #$7F
        rts

; Redraw the single viewport tile containing cell (city_ptr_x, city_ptr_y), if
; that tile is currently visible; otherwise do nothing. Paint paths use this so
; dropping a tile redraws only the affected tile -- a full render_viewport every
; paint frame races the raster and flashes map content through the chrome at the
; top. The painted tile is always below the chrome (cursor Y is clamped), so a
; targeted redraw never touches the overlap rows.
render_redraw_cell_tile:
        lda city_ptr_x
        lsr                         ; map tile x = cell x / 2
        sec
        sbc view_x                  ; viewport-relative tile x
        bcc _rrct_skip              ; left of viewport
        cmp #MAIN_TILE_COLS
        bcs _rrct_skip              ; right of viewport
        sta render_tile_x

        lda city_ptr_y
        lsr                         ; map tile y = cell y / 2
        sec
        sbc view_y                  ; viewport-relative tile y
        bcc _rrct_skip              ; above viewport
        cmp #MAIN_TILE_ROWS
        bcs _rrct_skip              ; below viewport
        sta render_tile_y

        clc                         ; cell ptr = (view + tile) * 2 (tile top-left)
        lda view_x
        adc render_tile_x
        asl
        sta city_ptr_x
        clc
        lda view_y
        adc render_tile_y
        asl
        sta city_ptr_y
        jsr city_cell_ptr
        jmp render_draw_tile
_rrct_skip:
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
