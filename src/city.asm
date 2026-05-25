;=======================================================================================
; City state and coarse viewport scrolling.
;
; The map is stored at 8x8-cell resolution in Attic RAM (ATTIC_MAP_PHYS,
; CELL_COLS x CELL_ROWS = 240x200, one tile-type byte per cell). Cells are read
; and written with 45GS02 32-bit indirect addressing via MAP_PTR ([MAP_PTR],z),
; set up by city_cell_ptr. Tools currently place 16x16 tiles, which are 2x2
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

; Stamp a 3x3 bordered zone at a CELL origin. Args: type, cell_x, cell_y.
SEED_ZONE .macro type, cx, cy
        lda #\cx
        sta zone_org_x
        lda #\cy
        sta zone_org_y
        lda #\type
        jsr city_stamp_zone
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

; Fill every cell in the Attic world map with TILE_GROUND via one DMA fill.
; (FILL command $03: the fill byte is the low byte of the source address field.)
city_fill_ground:
        lda #$00
        sta $D707
        .byte $80, $00              ; src MB (unused by fill)
        .byte $81, ATTIC_MAP_MB     ; dst MB = $82
        .byte $00                    ; end of option list
        .byte $03                    ; FILL
        .word CELL_MAP_SIZE          ; 48,000 bytes
        .byte TILE_GROUND, $00       ; src addr lo = fill byte (TILE_GROUND)
        .byte $00                    ; src bank
        .word ATTIC_MAP_ADDR         ; dst addr $0000
        .byte ATTIC_MAP_BANK         ; dst bank $00
        .byte $00                    ; command high byte
        .word $0000                  ; modulo
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
        lda #ROAD_CELL_H
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
        lda #ROAD_CELL_V            ; vertical road segment
        jsr city_set_seed_tile
        inc seed_y
        jmp _cst_road_v

_cst_zones:
        ; Demo 3x3 bordered zones (cell origins): one of each type, two rows.
        #SEED_ZONE TILE_RESIDENTIAL, 20, 18
        #SEED_ZONE TILE_RESIDENTIAL, 20, 24
        #SEED_ZONE TILE_COMMERCIAL, 28, 18
        #SEED_ZONE TILE_COMMERCIAL, 28, 24
        #SEED_ZONE TILE_INDUSTRIAL, 36, 18
        #SEED_ZONE TILE_INDUSTRIAL, 36, 24

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
; Write A into the 2x2 cell block whose top-left cell is MAP_PTR (in Attic).
city_stamp_2x2:
        ldz #0
        sta [MAP_PTR],z
        ldz #1
        sta [MAP_PTR],z
        ldz #CELL_COLS
        sta [MAP_PTR],z
        ldz #CELL_COLS+1
        sta [MAP_PTR],z
        rts

; Carry SET if all four cells of the 2x2 block at MAP_PTR are TILE_GROUND, so a
; 16x16 tile (water/power) may be placed there; carry CLEAR if any is occupied.
city_2x2_all_ground:
        ldz #0
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _c2g_no
        ldz #1
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _c2g_no
        ldz #CELL_COLS
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _c2g_no
        ldz #CELL_COLS+1
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _c2g_no
        sec
        rts
_c2g_no:
        clc
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
        jmp cps_zone                ; residential / commercial / industrial

_cps_2x2:
        ; 16x16 tool (water/power): stamp the 2x2 block only on all-ground cells.
        lda cursor_x
        asl
        sta city_ptr_x              ; cell_x = cursor_x * 2
        lda cursor_y
        asl
        sta city_ptr_y              ; cell_y = cursor_y * 2
        jsr city_cell_ptr
        jsr city_2x2_all_ground
        bcs _cps_2x2_write
        rts
_cps_2x2_write:
        lda selected_tile
        jsr city_stamp_2x2
        jmp render_redraw_cell_tile     ; city_ptr_* still = cursor cell

_cps_road:
        ; 1x1: absolute cell = view (tiles)*2 + cell-within-view.
        lda view_x
        asl
        clc
        adc mouse_cell_x
        sta city_ptr_x
        sta road_cx
        lda view_y
        asl
        clc
        adc mouse_cell_y
        sta city_ptr_y
        sta road_cy
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z             ; A = existing cell
        ; The bulldozer (TILE_GROUND tool) clears anything but water; every other
        ; 1x1 tool may only build on ground.
        ldx selected_tile
        cpx #TILE_GROUND
        bne _cps_road_build
        ; bulldozer: clear anything but water
        cmp #TILE_WATER
        beq _cps_road_skip
        lda #TILE_GROUND
        ldz #0
        sta [MAP_PTR],z
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr render_redraw_cell_tile
        jmp road_refresh_neighbors      ; roads above/below may re-orient
_cps_road_build:
        cmp #TILE_GROUND
        bne _cps_road_skip          ; only on ground
        lda #ROAD_CELL_H
        ldz #0
        sta [MAP_PTR],z
        jsr road_refresh                ; pick this cell's orientation + redraw
        jmp road_refresh_neighbors      ; roads above/below may re-orient
_cps_road_skip:
        rts

; --- Road orientation -----------------------------------------------------
; A road cell renders per its road neighbours, chosen by road_refresh and stored
; in the cell value (ROAD_CELL_*):
;   4 sides         -> ROAD_CELL_4WAY (plain asphalt square)
;   3 sides         -> a T-junction (T_N/T_S/T_E/T_W; closed side gets a black border)
;   2 perpendicular -> a curve (NW/NE/SW/SE) connecting those two sides
;   north or south  -> ROAD_CELL_V (vertical)
;   otherwise       -> ROAD_CELL_H (horizontal)
; A perpendicular neighbour that is merely a parallel road running alongside is
; ignored (detected via the diagonals), so two adjacent parallel roads stay
; straight instead of forming junctions. Because orientation now depends on the
; diagonals too, a paint/bulldoze recomputes the cell and ALL eight surrounding
; cells (road_refresh_neighbors).

; Carry SET if cell value A is a road (any orientation).
is_road_value:
        cmp #ROAD_CELL_FIRST
        bcc _irv_no
        cmp #ROAD_CELL_LAST+1
        bcs _irv_no
        sec
        rts
_irv_no:
        clc
        rts

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is a road.
road_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_road_value

; Offsets for the 8 surrounding cells, order NW,N,NE,W,E,SW,S,SE. Shared by
; road_refresh's neighbour scan and road_refresh_neighbors. (dx/dy are signed;
; cmp against CELL_COLS/ROWS rejects both underflow and overflow at the edges.)
road_dx:  .byte $FF,$00,$01,$FF,$01,$FF,$00,$01
road_dy:  .byte $FF,$FF,$FF,$00,$00,$01,$01,$01
road_bit: .byte ROAD_BIT_NW,ROAD_BIT_N,ROAD_BIT_NE,ROAD_BIT_W,ROAD_BIT_E,ROAD_BIT_SW,ROAD_BIT_S,ROAD_BIT_SE

; Re-orient and redraw the road cell at (road_cx, road_cy). No-op if not a road.
; Scans all 8 neighbours into road_raw, then drops a perpendicular connection
; that is only a parallel road alongside (this cell and the neighbour are both
; straight runs on the same axis -- revealed when the diagonal is a road too), so
; adjacent parallel roads stay straight instead of forming junctions.
road_refresh:
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr road_at_ptr
        bcc _rr_done
        lda #0
        sta road_raw
        ldx #0
_rr_gather:
        clc
        lda road_cx
        adc road_dx,x
        cmp #CELL_COLS
        bcs _rr_gnext               ; off map (under/overflow)
        sta city_ptr_x
        clc
        lda road_cy
        adc road_dy,x
        cmp #CELL_ROWS
        bcs _rr_gnext
        sta city_ptr_y
        jsr road_at_ptr             ; preserves X
        bcc _rr_gnext
        lda road_raw
        ora road_bit,x
        sta road_raw
_rr_gnext:
        inx
        cpx #8
        bne _rr_gather

        ; refined connections start from the raw N/S/E/W
        lda road_raw
        and #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        sta road_mask
        ; horizontal run (E&W)? drop a N/S neighbour that is itself horizontal
        ; (its own E and W are roads -> our diagonals NE/NW or SE/SW)
        lda road_raw
        and #(ROAD_BIT_E|ROAD_BIT_W)
        cmp #(ROAD_BIT_E|ROAD_BIT_W)
        bne _rr_chk_vert
        lda road_raw
        and #(ROAD_BIT_NE|ROAD_BIT_NW)
        cmp #(ROAD_BIT_NE|ROAD_BIT_NW)
        bne _rr_chk_drops
        lda road_mask
        and #(255-ROAD_BIT_N)
        sta road_mask
_rr_chk_drops:
        lda road_raw
        and #(ROAD_BIT_SE|ROAD_BIT_SW)
        cmp #(ROAD_BIT_SE|ROAD_BIT_SW)
        bne _rr_chk_vert
        lda road_mask
        and #(255-ROAD_BIT_S)
        sta road_mask
_rr_chk_vert:
        ; vertical run (N&S)? drop an E/W neighbour that is itself vertical
        lda road_raw
        and #(ROAD_BIT_N|ROAD_BIT_S)
        cmp #(ROAD_BIT_N|ROAD_BIT_S)
        bne _rr_decide
        lda road_raw
        and #(ROAD_BIT_NE|ROAD_BIT_SE)
        cmp #(ROAD_BIT_NE|ROAD_BIT_SE)
        bne _rr_chk_dropw
        lda road_mask
        and #(255-ROAD_BIT_E)
        sta road_mask
_rr_chk_dropw:
        lda road_raw
        and #(ROAD_BIT_NW|ROAD_BIT_SW)
        cmp #(ROAD_BIT_NW|ROAD_BIT_SW)
        bne _rr_decide
        lda road_mask
        and #(255-ROAD_BIT_W)
        sta road_mask
_rr_decide:
        lda road_mask
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        beq _rr_4way
        cmp #(ROAD_BIT_N|ROAD_BIT_W)
        beq _rr_nw
        cmp #(ROAD_BIT_N|ROAD_BIT_E)
        beq _rr_ne
        cmp #(ROAD_BIT_S|ROAD_BIT_W)
        beq _rr_sw
        cmp #(ROAD_BIT_S|ROAD_BIT_E)
        beq _rr_se
        cmp #(ROAD_BIT_N|ROAD_BIT_E|ROAD_BIT_W)
        beq _rr_tn
        cmp #(ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        beq _rr_ts
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E)
        beq _rr_te
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_W)
        beq _rr_tw
        and #(ROAD_BIT_N|ROAD_BIT_S)   ; A still = road_mask
        bne _rr_vertical
        lda #ROAD_CELL_H
        bra _rr_store
_rr_4way:
        lda #ROAD_CELL_4WAY
        bra _rr_store
_rr_nw:
        lda #ROAD_CELL_CURVE_NW
        bra _rr_store
_rr_ne:
        lda #ROAD_CELL_CURVE_NE
        bra _rr_store
_rr_sw:
        lda #ROAD_CELL_CURVE_SW
        bra _rr_store
_rr_se:
        lda #ROAD_CELL_CURVE_SE
        bra _rr_store
_rr_tn:
        lda #ROAD_CELL_T_N
        bra _rr_store
_rr_ts:
        lda #ROAD_CELL_T_S
        bra _rr_store
_rr_te:
        lda #ROAD_CELL_T_E
        bra _rr_store
_rr_tw:
        lda #ROAD_CELL_T_W
        bra _rr_store
_rr_vertical:
        lda #ROAD_CELL_V
_rr_store:
        sta road_tmp
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda road_tmp
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_* = (road_cx, road_cy)
_rr_done:
        rts

; Re-orient the 8 cells around (road_cx, road_cy). All 8 because a cell's
; orientation now depends on its diagonal neighbours too (the parallel-road test
; reads them). road_refresh clobbers X, so the loop index lives in road_nidx.
road_refresh_neighbors:
        lda road_cx
        sta road_cx_save
        lda road_cy
        sta road_cy_save
        lda #0
        sta road_nidx
_rrn_loop:
        ldx road_nidx
        clc
        lda road_cx_save
        adc road_dx,x
        cmp #CELL_COLS
        bcs _rrn_next
        sta road_cx
        clc
        lda road_cy_save
        adc road_dy,x
        cmp #CELL_ROWS
        bcs _rrn_next
        sta road_cy
        jsr road_refresh
_rrn_next:
        inc road_nidx
        lda road_nidx
        cmp #8
        bne _rrn_loop
        lda road_cx_save
        sta road_cx
        lda road_cy_save
        sta road_cy
        rts

; Zone paint path (global label: it is reached past the road-orientation helpers
; above, which would otherwise break a cheap label's scope).
cps_zone:
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

        jsr city_zone_all_ground    ; a zone may only be placed on all-ground cells
        bcs _cps_zone_do
        rts
_cps_zone_do:
        lda selected_tile
        jsr city_stamp_zone

        ; Redraw the (up to) 2x2 tiles covering the 3x3 cell zone, by its four
        ; corner cells. render_redraw_cell_tile clobbers city_ptr_*, so re-seed
        ; from zone_org_x/y each time; off-viewport corners are skipped there.
        lda zone_org_x
        sta city_ptr_x
        lda zone_org_y
        sta city_ptr_y
        jsr render_redraw_cell_tile
        lda zone_org_x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda zone_org_y
        sta city_ptr_y
        jsr render_redraw_cell_tile
        lda zone_org_x
        sta city_ptr_x
        lda zone_org_y
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
        lda zone_org_x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda zone_org_y
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jmp render_redraw_cell_tile

; Stamp a 3x3 bordered zone whose top-left cell is (zone_org_x, zone_org_y).
; A = zone type (TILE_RESIDENTIAL / COMMERCIAL / INDUSTRIAL). Writes the 9
; position-specific literal chars (ZONE_GEN_BASE + type_index*9 + position) | $80
; into the map. Does not redraw -- callers handle that (paint redraws the covered
; tiles; the seed runs before the first full render).
city_stamp_zone:
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
_csz_row:
        lda #0
        sta zone_dx
_csz_col:
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
        ldz #0
        sta [MAP_PTR],z
        inc zone_dx
        lda zone_dx
        cmp #ZONE_SIZE
        bne _csz_col
        inc zone_dy
        lda zone_dy
        cmp #ZONE_SIZE
        bne _csz_row
        rts

; Carry SET if all nine cells of the 3x3 zone at (zone_org_x, zone_org_y) are
; TILE_GROUND, so a zone may be placed there; carry CLEAR if any is occupied.
; Clobbers zone_dx/dy and city_ptr_* (re-set by city_stamp_zone on the way in).
city_zone_all_ground:
        lda #0
        sta zone_dy
_czg_row:
        lda #0
        sta zone_dx
_czg_col:
        clc
        lda zone_org_x
        adc zone_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc zone_dy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _czg_no
        inc zone_dx
        lda zone_dx
        cmp #ZONE_SIZE
        bne _czg_col
        inc zone_dy
        lda zone_dy
        cmp #ZONE_SIZE
        bne _czg_row
        sec
        rts
_czg_no:
        clc
        rts

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

; MAP_PTR (28-bit) = ATTIC_MAP_PHYS + city_ptr_y*CELL_COLS + city_ptr_x.
; The cell offset is 16-bit (max 199*240+239 = 47,999); add it into the low two
; bytes of the Attic base and carry up so [MAP_PTR],z reaches the right cell.
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
        lda #<ATTIC_MAP_PHYS
        adc city_ptr_lo
        sta MAP_PTR
        lda #>ATTIC_MAP_PHYS
        adc city_ptr_hi
        sta MAP_PTR+1
        lda #`ATTIC_MAP_PHYS
        adc #0
        sta MAP_PTR+2
        lda #(ATTIC_MAP_PHYS >> 24)
        adc #0
        sta MAP_PTR+3
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
road_cx:
        .byte 0
road_cy:
        .byte 0
road_cx_save:
        .byte 0
road_cy_save:
        .byte 0
road_mask:
        .byte 0
road_raw:
        .byte 0
road_nidx:
        .byte 0
road_tmp:
        .byte 0
