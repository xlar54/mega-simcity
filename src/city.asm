;=======================================================================================
; City state and coarse viewport scrolling.
;
; The map is stored at 8x8-cell resolution in city_cells (CELL_COLS x CELL_ROWS,
; one tile-type byte per cell). Tools currently place 16x16 tiles, which are 2x2
; blocks of same-type cells: tile (tx,ty) maps to cell (tx*2, ty*2). cursor_x/y
; and view_x/y stay in 16x16 tile units.
;=======================================================================================

; Stamp a 16x16 tile (2x2 same-type cell block). Args: type, tile_x, tile_y.
SEED_TILE .macro type, tx, ty
        lda #\type
        ldx #\tx
        ldy #\ty
        jsr city_stamp_tile
.endmacro

city_init:
        lda #8
        sta view_x
        lda #8
        sta view_y
        lda #20
        sta cursor_x
        lda #14
        sta cursor_y
        lda #0
        sta selected_tool           ; bulldozer (slot 0) is the starting tool
        lda #TILE_GROUND
        sta selected_tile
        lda #0
        sta sim_tick
        sta sim_tick+1

        jsr city_fill_ground
        jsr city_seed_terrain
        jsr city_clamp_view_to_cursor
        rts

; Fill every cell with TILE_GROUND (CELL_MAP_SIZE bytes via a page loop).
city_fill_ground:
        lda #<city_cells
        sta PTR
        lda #>city_cells
        sta PTR+1
        ldx #(>CELL_MAP_SIZE)       ; whole pages to fill
        ldy #0
        lda #TILE_GROUND
_cfg_byte:
        sta (PTR),y
        iny
        bne _cfg_byte
        inc PTR+1
        dex
        bne _cfg_byte
        rts

city_seed_terrain:
        ; Coastal water band (tile rows 0-4).
        lda #0
        sta seed_y
_cst_water_rows:
        lda seed_y
        cmp #5
        bcs _cst_roads
        lda #0
        sta seed_x
_cst_water_cols:
        lda seed_x
        cmp #CITY_COLS
        beq _cst_next_water_row
        lda #TILE_WATER
        jsr city_set_seed_tile
        inc seed_x
        jmp _cst_water_cols
_cst_next_water_row:
        inc seed_y
        jmp _cst_water_rows

_cst_roads:
        lda #0
        sta seed_x
        lda #14
        sta seed_y
_cst_road_h:
        lda seed_x
        cmp #CITY_COLS
        beq _cst_road_v_setup
        lda #TILE_ROAD
        jsr city_set_seed_tile
        inc seed_x
        jmp _cst_road_h

_cst_road_v_setup:
        lda #0
        sta seed_y
        lda #22
        sta seed_x
_cst_road_v:
        lda seed_y
        cmp #CITY_ROWS
        beq _cst_zones
        lda #TILE_ROAD
        jsr city_set_seed_tile
        inc seed_y
        jmp _cst_road_v

_cst_zones:
        #SEED_TILE TILE_RESIDENTIAL, 15, 10
        #SEED_TILE TILE_RESIDENTIAL, 16, 10
        #SEED_TILE TILE_RESIDENTIAL, 15, 11
        #SEED_TILE TILE_RESIDENTIAL, 16, 11
        #SEED_TILE TILE_RESIDENTIAL, 18, 12
        #SEED_TILE TILE_RESIDENTIAL, 18, 13

        #SEED_TILE TILE_COMMERCIAL, 25, 16
        #SEED_TILE TILE_COMMERCIAL, 26, 16
        #SEED_TILE TILE_COMMERCIAL, 25, 17
        #SEED_TILE TILE_COMMERCIAL, 28, 18

        #SEED_TILE TILE_INDUSTRIAL, 16, 21
        #SEED_TILE TILE_INDUSTRIAL, 17, 21
        #SEED_TILE TILE_INDUSTRIAL, 16, 22
        #SEED_TILE TILE_INDUSTRIAL, 17, 23

        #SEED_TILE TILE_POWER, 28, 8

        #SEED_TILE TILE_WATER, 47, 6
        #SEED_TILE TILE_WATER, 48, 6
        #SEED_TILE TILE_WATER, 48, 7
        #SEED_TILE TILE_WATER, 49, 8
        rts

; Stamp a 16x16 tile as a 2x2 same-type cell block. A=type, X=tile_x, Y=tile_y.
city_stamp_tile:
        sta stamp_type
        txa
        asl
        sta city_ptr_x              ; cell_x = tile_x * 2
        tya
        asl
        sta city_ptr_y              ; cell_y = tile_y * 2
        jsr city_cell_ptr
        lda stamp_type
        jmp city_stamp_2x2

; Stamp a 2x2 same-type block from seed_x/seed_y (tile coords). A=type.
city_set_seed_tile:
        pha
        lda seed_x
        asl
        sta city_ptr_x
        lda seed_y
        asl
        sta city_ptr_y
        jsr city_cell_ptr
        pla
; Write A into the 2x2 cell block whose top-left is PTR2.
city_stamp_2x2:
        ldy #0
        sta (PTR2),y
        ldy #1
        sta (PTR2),y
        ldy #CELL_COLS
        sta (PTR2),y
        ldy #CELL_COLS+1
        sta (PTR2),y
        rts

game_apply_input:
        lda input_action
        beq _gai_done
        ; Keyboard cursor scrolling is disabled; mouse edge-scroll handles
        ; upward movement directly. Ignore stray queued INPUT_MOVE_UP events
        ; so they cannot fight test/down scrolling.
        cmp #INPUT_MOVE_UP
        beq _gai_done
        cmp #INPUT_MOVE_DOWN
        beq _gai_down
        cmp #INPUT_MOVE_LEFT
        beq _gai_left
        cmp #INPUT_MOVE_RIGHT
        beq _gai_right
        cmp #INPUT_PAINT
        beq city_paint_selected
_gai_done:
        rts

_gai_up:
        lda view_y
        beq _gai_done
        dec view_y
        jmp render_mark_view_dirty

_gai_down:
        lda view_y
        cmp #CITY_VIEW_MAX_Y
        bcs _gai_done
        inc view_y
        jmp render_mark_view_dirty

_gai_left:
        lda view_x
        beq _gai_done
        dec view_x
        jmp render_mark_view_dirty

_gai_right:
        lda view_x
        cmp #CITY_VIEW_MAX_X
        bcs _gai_done
        inc view_x
        jmp render_mark_view_dirty

game_tick:
        inc sim_tick
        bne +
        inc sim_tick+1
+       rts

city_paint_selected:
        lda selected_tile
        cmp #TILE_ROAD
        beq _cps_road
        cmp #TILE_GROUND
        beq _cps_road               ; bulldozer is also a 1x1 (8x8) tool
        cmp #TILE_RESIDENTIAL
        bcc _cps_2x2                ; water -> 2x2
        cmp #TILE_POWER
        bcs _cps_2x2                ; power and above
        jmp _cps_zone               ; residential / commercial / industrial

_cps_2x2:
        ; 16x16 tool: stamp the 2x2 cell block at the cursor tile.
        lda cursor_x
        asl
        sta city_ptr_x              ; cell_x = cursor_x * 2
        lda cursor_y
        asl
        sta city_ptr_y              ; cell_y = cursor_y * 2
        jsr city_cell_ptr
        lda selected_tile
        jsr city_stamp_2x2
        jmp render_mark_view_dirty

_cps_road:
        ; 1x1: absolute cell = view (tiles)*2 + cell-within-view.
        lda view_x
        asl
        clc
        adc mouse_cell_x
        sta city_ptr_x
        lda view_y
        asl
        clc
        adc mouse_cell_y
        sta city_ptr_y
        jsr city_cell_ptr
        lda selected_tile
        ldy #0
        sta (PTR2),y
        jmp render_mark_view_dirty

_cps_zone:
        ; 3x3: origin = view*2 + cell-within-view, clamped so the block fits.
        lda view_x
        asl
        clc
        adc mouse_cell_x
        cmp #(CELL_COLS - ZONE_SIZE + 1)
        bcc _cps_zone_setx
        lda #(CELL_COLS - ZONE_SIZE)
_cps_zone_setx:
        sta zone_org_x
        lda view_y
        asl
        clc
        adc mouse_cell_y
        cmp #(CELL_ROWS - ZONE_SIZE + 1)
        bcc _cps_zone_sety
        lda #(CELL_ROWS - ZONE_SIZE)
_cps_zone_sety:
        sta zone_org_y

        ; First zone-cell char = ZONE_GEN_BASE + (selected_tile - first zone)*9.
        lda selected_tile
        sec
        sbc #TILE_RESIDENTIAL
        sta zone_tmp
        asl
        asl
        asl                         ; index * 8
        clc
        adc zone_tmp                ; index * 9
        clc
        adc #ZONE_GEN_BASE
        sta zone_char_base

        lda #0
        sta zone_dy
_cps_zone_row:
        lda #0
        sta zone_dx
_cps_zone_col:
        clc
        lda zone_org_x
        adc zone_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc zone_dy
        sta city_ptr_y
        jsr city_cell_ptr
        ; literal char = zone_char_base + position(dy*3 + dx), bit 7 set.
        lda zone_dy
        asl
        clc
        adc zone_dy                 ; dy * 3
        clc
        adc zone_dx                 ; + dx = position 0..8
        clc
        adc zone_char_base
        ora #ZONE_CELL_LITERAL
        ldy #0
        sta (PTR2),y
        inc zone_dx
        lda zone_dx
        cmp #ZONE_SIZE
        bne _cps_zone_col
        inc zone_dy
        lda zone_dy
        cmp #ZONE_SIZE
        bne _cps_zone_row
        jmp render_mark_view_dirty

city_clamp_view_to_cursor:
        lda cursor_x
        cmp view_x
        bcs _ccvt_right_check
        sta view_x

_ccvt_right_check:
        clc
        lda view_x
        adc #MAIN_TILE_COLS
        sta view_limit
        lda cursor_x
        cmp view_limit
        bcc _ccvt_y_check
        sec
        lda cursor_x
        sbc #MAIN_TILE_COLS-1
        sta view_x

_ccvt_y_check:
        lda cursor_y
        cmp view_y
        bcs _ccvt_bottom_check
        sta view_y

_ccvt_bottom_check:
        clc
        lda view_y
        adc #MAIN_TILE_ROWS
        sta view_limit
        lda cursor_y
        cmp view_limit
        bcc _ccvt_max_check
        sec
        lda cursor_y
        sbc #MAIN_TILE_ROWS-1
        sta view_y

_ccvt_max_check:
        lda view_x
        cmp #CITY_VIEW_MAX_X+1
        bcc +
        lda #CITY_VIEW_MAX_X
        sta view_x
+       lda view_y
        cmp #CITY_VIEW_MAX_Y+1
        bcc +
        lda #CITY_VIEW_MAX_Y
        sta view_y
+       rts

; PTR2 = city_cells + city_ptr_y*CELL_COLS + city_ptr_x  (cell coordinates).
city_cell_ptr:
        lda city_ptr_y
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3

        lda #CELL_COLS
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3

        clc
        lda MULTOUT
        adc city_ptr_x
        sta city_ptr_lo
        lda MULTOUT+1
        adc #0
        sta city_ptr_hi

        clc
        lda #<city_cells
        adc city_ptr_lo
        sta PTR2
        lda #>city_cells
        adc city_ptr_hi
        sta PTR2+1
        rts

cursor_x:
        .byte 0
cursor_y:
        .byte 0
view_x:
        .byte 0
view_y:
        .byte 0
selected_tile:
        .byte 0
selected_tool:
        .byte 0
sim_tick:
        .word 0

seed_x:
        .byte 0
seed_y:
        .byte 0
view_limit:
        .byte 0
city_ptr_x:
        .byte 0
city_ptr_y:
        .byte 0
city_ptr_lo:
        .byte 0
city_ptr_hi:
        .byte 0
stamp_type:
        .byte 0
zone_org_x:
        .byte 0
zone_org_y:
        .byte 0
zone_dx:
        .byte 0
zone_dy:
        .byte 0
zone_char_base:
        .byte 0
zone_tmp:
        .byte 0

; city_cells (the 8KB cell map) is defined at the very end of main.asm so it
; sits above all code; see the note there.
