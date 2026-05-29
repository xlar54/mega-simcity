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
        ; While a popup overlay is open, freeze the map: the popup chars sit on
        ; top of the viewport region and a full render_viewport would scrub
        ; them off. Chrome (row 0 menu / FUNDS / DATE / top buttons) is still
        ; allowed to redraw because none of those overlap the popup rect.
        ; overlay_close marks the view dirty so it catches up here on the next
        ; frame after the player clicks OK.
        lda overlay_active
        bne _rf_ui
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
        jsr clock_render            ; DATE: MMM YYYY on row 1, cols 18+

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
        jsr render_top_buttons      ; on top of the panel + status fills (toolbar.asm)
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
        jsr _rdt_stamp_char         ; common 16-bit write with snc_char_hi
        ldx render_screen_col
        ldy render_screen_row
        jsr set_fcm_char16

        ldz #1                      ; TR cell, parity 1
        lda [MAP_PTR],z
        ldx #1
        jsr cell_to_char
        jsr _rdt_stamp_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        jsr set_fcm_char16

        ldz #CELL_COLS              ; BL cell, parity 2
        lda [MAP_PTR],z
        ldx #2
        jsr cell_to_char
        jsr _rdt_stamp_char
        ldx render_screen_col
        ldy render_screen_row
        iny
        jsr set_fcm_char16

        ldz #CELL_COLS+1           ; BR cell, parity 3
        lda [MAP_PTR],z
        ldx #3
        jsr cell_to_char
        jsr _rdt_stamp_char
        ldx render_screen_col
        inx
        ldy render_screen_row
        iny
        jsr set_fcm_char16
        rts

; Helper: cell_to_char's outputs are A = char low and ctc_char_hi = char high;
; set_fcm_char16 takes A as its low byte too, but reads its high byte from
; snc_char_hi. Copy the high byte across and leave A untouched.
_rdt_stamp_char:
        pha
        lda ctc_char_hi
        sta snc_char_hi
        pla
        rts

; A = cell value, X = parity (0-3) -> A = char-id low byte, ctc_char_hi = high byte.
;   ROAD_CELL_FIRST..LAST       -> road; the value IS the char (no arithmetic)
;   POWERLINE_CELL_FIRST..LAST  -> power line; the value IS the char
;   TREE_CELL_FIRST..LAST       -> tree;        char = TREE_CHAR_BASE + (value - TREE_CELL_FIRST)
;   WATER_SHORE_CELL_FIRST..LAST -> shoreline;  char = WATER_SHORE_CHAR_BASE + (value - WATER_SHORE_CELL_FIRST)
;   ZONE_CELL_FIRST..LAST       -> zone;        char = ZONE_GEN_BASE + (value - ZONE_CELL_FIRST)
;   POWER_BRIDGE_CELL_FIRST..LAST -> bridge;    char = POWER_BRIDGE_CHAR_BASE + (value - POWER_BRIDGE_CELL_FIRST)
;   RAIL_CELL_FIRST..LAST       -> rail;        char = RAIL_CHAR_BASE + (value - RAIL_CELL_FIRST)
;   DEBRIS_CELL_FIRST..LAST     -> debris;      char = DEBRIS_CHAR_BASE + (value - DEBRIS_CELL_FIRST)
;   COALPP_CELL_FIRST..LAST / NUCLEARPP_CELL_FIRST..LAST -> structure table
;   otherwise (water/ground/power base types) -> 2x2 tile, char = type*4 + parity
;
; The translated ranges (tree, water-shore, zone, power-bridge) and the
; structure-table path all carry into ctc_char_hi: low byte add carry + the hi
; half of the base = the full 16-bit char id. ctc_char_hi defaults to 0 (cleared
; at entry) for the no-translate paths (road, power line, base-type), which
; encode their char id in the 8-bit cell value itself -- those ranges are
; capped at 255 by the cell-encoding budget. Any future 1x1 paint tool whose
; art may live above char 255 should use a translated range
; (FIRST..LAST -> CHAR_BASE + offset) the same way trees/zones do, NOT the
; road/powerline "value is the char" shortcut.
cell_to_char:
        pha
        lda #0
        sta ctc_char_hi
        pla
        cmp #ROAD_CELL_FIRST
        bcc _ctc_type
        cmp #ROAD_CELL_LAST+1
        bcc _ctc_done               ; road: A already holds the char
        cmp #POWERLINE_CELL_FIRST
        bcc _ctc_type
        cmp #POWERLINE_CELL_LAST+1
        bcc _ctc_done               ; power line: A already holds the char
        cmp #TREE_CELL_FIRST
        bcc _ctc_struct_scan        ; below trees -> fall through to structure table
        cmp #TREE_CELL_LAST+1
        bcs _ctc_check_water_shore
        sec                         ; tree: char = (value - TREE_CELL_FIRST) + TREE_CHAR_BASE
        sbc #TREE_CELL_FIRST
        clc
        adc #<TREE_CHAR_BASE
        pha                         ; A=char_lo with carry pending into hi
        lda #>TREE_CHAR_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_check_water_shore:
        cmp #WATER_SHORE_CELL_FIRST
        bcc _ctc_struct_scan
        cmp #WATER_SHORE_CELL_LAST+1
        bcs _ctc_check_zone
        sec                         ; shore: char = (value - WATER_SHORE_CELL_FIRST) + WATER_SHORE_CHAR_BASE
        sbc #WATER_SHORE_CELL_FIRST
        clc
        adc #<WATER_SHORE_CHAR_BASE
        pha
        lda #>WATER_SHORE_CHAR_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_check_zone:
        cmp #ZONE_CELL_FIRST
        bcc _ctc_struct_scan
        cmp #ZONE_CELL_LAST+1
        bcs _ctc_check_power_bridge
        sec                         ; zone: char = (value - ZONE_CELL_FIRST) + ZONE_GEN_BASE
        sbc #ZONE_CELL_FIRST
        clc
        adc #<ZONE_GEN_BASE
        pha
        lda #>ZONE_GEN_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_check_power_bridge:
        cmp #POWER_BRIDGE_CELL_FIRST
        bcc _ctc_struct_scan
        cmp #POWER_BRIDGE_CELL_LAST+1
        bcs _ctc_check_rail
        sec                         ; power bridge: (value - FIRST) + CHAR_BASE
        sbc #POWER_BRIDGE_CELL_FIRST
        clc
        adc #<POWER_BRIDGE_CHAR_BASE
        pha
        lda #>POWER_BRIDGE_CHAR_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_check_rail:
        cmp #RAIL_CELL_FIRST
        bcc _ctc_struct_scan
        cmp #RAIL_CELL_LAST+1
        bcs _ctc_check_debris
        sec                         ; rail: (value - FIRST) + RAIL_CHAR_BASE
        sbc #RAIL_CELL_FIRST
        clc
        adc #<RAIL_CHAR_BASE
        pha
        lda #>RAIL_CHAR_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_check_debris:
        cmp #DEBRIS_CELL_FIRST
        bcc _ctc_struct_scan
        cmp #DEBRIS_CELL_LAST+1
        bcs _ctc_struct_scan        ; above LAST -> unallocated today
        sec                         ; debris: (value - FIRST) + DEBRIS_CHAR_BASE
        sbc #DEBRIS_CELL_FIRST
        clc
        adc #<DEBRIS_CHAR_BASE
        pha
        lda #>DEBRIS_CHAR_BASE
        adc #0
        sta ctc_char_hi
        pla
        rts
_ctc_struct_scan:
        ; Structure table: scan rows for a value in [base, base + count). For each
        ; match: char = (value - base) + (char_base_hi * 256 + char_base_lo). The
        ; high byte goes to ctc_char_hi -- including any carry from the low-byte
        ; add -- so structures whose art lives above char id 255 render correctly.
        sta ctc_value
        ldy #0
_ctc_struct_loop:
        cpy #struct_count
        bcs _ctc_no_struct
        lda ctc_value
        cmp struct_cell_base,y
        bcc _ctc_struct_next
        sec
        sbc struct_cell_base,y
        cmp struct_cell_count,y
        bcc _ctc_struct_hit
_ctc_struct_next:
        iny
        bra _ctc_struct_loop
_ctc_struct_hit:
        clc
        adc struct_char_base_lo,y   ; A = char low (with carry to hi below)
        pha                          ; save char low across the high-byte compute
        lda struct_char_base_hi,y
        adc #0                       ; + carry from the low add
        sta ctc_char_hi
        pla                          ; restore char low for the return
        rts
_ctc_no_struct:
        lda ctc_value               ; restore original cell value for type path
_ctc_type:
        ; Base-type render: char = value*4 + parity. Valid only for TILE_WATER
        ; (0) and TILE_GROUND (1); every other map cell goes through one of the
        ; range translations above. Trap anything else here (unallocated values
        ; in 153..255 reach this via the no-struct fall-through; gaps like
        ; 21..23 reach it via the road/powerline bcc) so an accidental write
        ; doesn't render as `value*4` wrapped into an arbitrary char.
        cmp #2
        bcs _ctc_unknown
        asl
        asl
        sta render_char_base
        txa
        clc
        adc render_char_base
_ctc_done:
        rts
_ctc_unknown:
        ; Sentinel: render water-TL (char 0). A blue square showing up on land
        ; is a clear "this cell value didn't map to anything" signal in xemu.
        lda #0
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
        cmp #FIRST_VISIBLE_TILE_ROW
        bcc _rrct_skip              ; hidden under top chrome (overlap rows)
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
ctc_value:                  ; cell_to_char: saved cell value across the struct loop
        .byte 0
ctc_char_hi:                ; cell_to_char: high byte of the 16-bit char id (A holds low)
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
