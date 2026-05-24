;=======================================================================================
; City state and coarse viewport scrolling.
;=======================================================================================

city_init:
        lda #8
        sta view_x
        lda #8
        sta view_y
        lda #20
        sta cursor_x
        lda #14
        sta cursor_y
        stz selected_tool           ; bulldozer (slot 0) is the starting tool
        lda #TILE_GRASS
        sta selected_tile
        stz sim_tick
        stz sim_tick+1

        jsr city_fill_grass
        jsr city_seed_terrain
        jsr city_clamp_view_to_cursor
        rts

city_fill_grass:
        ldx #0
_cfg_loop:
        lda #TILE_GRASS
        sta city_map+$000,x
        sta city_map+$100,x
        sta city_map+$200,x
        sta city_map+$300,x
        sta city_map+$400,x
        sta city_map+$500,x
        sta city_map+$600,x
        sta city_map+$700,x
        inx
        bne _cfg_loop
        rts

city_seed_terrain:
        ; Coastal water band.
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
        lda #TILE_RESIDENTIAL
        sta city_map+(10*CITY_COLS)+15
        sta city_map+(10*CITY_COLS)+16
        sta city_map+(11*CITY_COLS)+15
        sta city_map+(11*CITY_COLS)+16
        sta city_map+(12*CITY_COLS)+18
        sta city_map+(13*CITY_COLS)+18

        lda #TILE_COMMERCIAL
        sta city_map+(16*CITY_COLS)+25
        sta city_map+(16*CITY_COLS)+26
        sta city_map+(17*CITY_COLS)+25
        sta city_map+(18*CITY_COLS)+28

        lda #TILE_INDUSTRIAL
        sta city_map+(21*CITY_COLS)+16
        sta city_map+(21*CITY_COLS)+17
        sta city_map+(22*CITY_COLS)+16
        sta city_map+(23*CITY_COLS)+17

        lda #TILE_POWER
        sta city_map+(8*CITY_COLS)+28

        lda #TILE_WATER
        sta city_map+(6*CITY_COLS)+47
        sta city_map+(6*CITY_COLS)+48
        sta city_map+(7*CITY_COLS)+48
        sta city_map+(8*CITY_COLS)+49
        rts

city_set_seed_tile:
        pha
        lda seed_y
        sta city_ptr_y
        lda seed_x
        sta city_ptr_x
        jsr city_ptr_for_xy
        pla
        ldy #0
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
        lda cursor_x
        sta city_ptr_x
        lda cursor_y
        sta city_ptr_y
        jsr city_ptr_for_xy
        ldy #0
        lda selected_tile
        sta (PTR2),y
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

city_ptr_for_xy:
        lda city_ptr_y
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3

        lda #CITY_COLS
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
        lda #<city_map
        adc city_ptr_lo
        sta PTR2
        lda #>city_map
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

city_map:
        .fill CITY_MAP_SIZE, TILE_GRASS
