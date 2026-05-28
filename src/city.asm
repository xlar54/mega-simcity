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
        jsr funds_init
        jsr clock_init
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
        ; Mouse edge-scroll handles upward movement; ignore stray queued
        ; INPUT_MOVE_UP events.
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
        cmp #TILE_POWER
        beq _cps_power              ; power lines are 1x1 (8x8), like roads
        jsr structure_find_by_tool  ; preserves A; X = row idx if carry set
        bcs _cps_struct
        cmp #TILE_RESIDENTIAL
        bcc _cps_2x2                ; water -> 2x2
        jmp cps_zone                ; residential / commercial / industrial
_cps_struct:
        txa                         ; cps_structure takes A = row index
        jmp cps_structure

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
        ; bulldozer: clear anything but water; skip already-clear ground so a
        ; held/dragged bulldozer only booms when it actually demolishes something.
        cmp #TILE_WATER
        beq _cps_road_skip
        cmp #TILE_GROUND
        beq _cps_road_skip
        lda #<COST_BULLDOZE             ; charge $1 per demolished cell
        sta cost_amount
        lda #>COST_BULLDOZE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_road_skip
        jsr funds_subtract
        lda #TILE_GROUND
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty            ; demolition may break the power network
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr render_redraw_cell_tile
        jsr audio_explosion             ; demolished a built tile -> boom
        jsr road_refresh_neighbors      ; roads above/below may re-orient
        lda road_cx                     ; ...and power lines around the cell
        sta powerline_cx
        lda road_cy
        sta powerline_cy
        jmp powerline_refresh_neighbors
_cps_road_build:
        sta road_cross_save         ; save the existing cell value (re-used below)
        lda #<COST_ROAD             ; check road affordability up front
        sta cost_amount
        lda #>COST_ROAD
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_road_skip
        lda road_cross_save
        cmp #TILE_GROUND
        beq _cps_road_place         ; ground: place normally
        ; Not ground. A road may still CROSS an existing power line, but only
        ; perpendicularly. Tentatively drop a road and let road_refresh decide;
        ; keep it only if it became a crossing tile, else restore the power line.
        jsr is_powerline_value
        bcc _cps_road_skip          ; occupied by a road/zone/water -> can't build
        lda #ROAD_CELL_H
        ldz #0
        sta [MAP_PTR],z
        jsr road_refresh            ; sets H/V + the *_POWER tile if it crosses
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #ROAD_CELL_H_POWER
        beq _cps_road_crossed
        cmp #ROAD_CELL_V_POWER
        beq _cps_road_crossed
        ; not a perpendicular crossing -> undo, leave the power line intact
        lda road_cross_save
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_* still = (road_cx, road_cy)
_cps_road_crossed:
        jsr funds_subtract              ; committed crossing -> deduct road cost
        jsr audio_road_build
        jsr road_refresh_neighbors      ; roads around may re-orient
        lda road_cx                     ; ...and the power line on both sides
        sta powerline_cx
        lda road_cy
        sta powerline_cy
        jmp powerline_refresh_neighbors
_cps_road_place:
        lda #ROAD_CELL_H
        ldz #0
        sta [MAP_PTR],z
        jsr funds_subtract              ; committed -> deduct road cost
        jsr audio_road_build            ; new road placed -> build blip
        jsr road_refresh                ; pick this cell's orientation + redraw
        jmp road_refresh_neighbors      ; roads above/below may re-orient
_cps_road_skip:
        rts

; Power-line paint path (1x1, like roads). Places a wire/pole on ground only,
; then lets powerlines.asm pick the orientation and re-orient the neighbours.
; A running counter makes every POWERLINE_POLE_EVERY-th placed line a pole.
_cps_power:
        lda view_x
        asl
        clc
        adc mouse_cell_x
        sta city_ptr_x
        sta powerline_cx
        lda view_y
        asl
        clc
        adc mouse_cell_y
        sta city_ptr_y
        sta powerline_cy
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z             ; A = existing cell
        cmp #TILE_GROUND
        bne _cps_power_skip         ; only build on ground (skip water/road/zones)
        lda #<COST_POWERLINE        ; check + deduct power-line cost
        sta cost_amount
        lda #>COST_POWERLINE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_power_skip
        jsr funds_subtract
        inc powerline_count
        lda powerline_count
        cmp #POWERLINE_POLE_EVERY
        bcc _cps_power_line
        lda #0
        sta powerline_count
        lda #POWERLINE_CELL_POLE_H  ; pole intent (powerline_refresh sets orient.)
        bra _cps_power_write
_cps_power_line:
        lda #POWERLINE_CELL_H       ; line intent (powerline_refresh sets orient.)
_cps_power_write:
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty        ; the power network changed
        ; First let adjacent straight roads detect a new crossing (they read the
        ; raw power placeholder just written). Then orient this line and its power
        ; neighbours, which now see any crossing tile as an on-axis connection.
        lda powerline_cx
        sta road_cx
        lda powerline_cy
        sta road_cy
        jsr road_refresh_neighbors
        jsr powerline_refresh
        jmp powerline_refresh_neighbors
_cps_power_skip:
        rts

; Zone paint path.
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

        jsr city_zone_can_place     ; ground or power lines (zones overwrite power)
        bcc _cps_zone_no
        lda #<COST_ZONE             ; check + deduct zone cost
        sta cost_amount
        lda #>COST_ZONE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_zone_no
        jsr funds_subtract
        bra _cps_zone_do
_cps_zone_no:
        rts
_cps_zone_do:
        lda selected_tile
        jsr city_stamp_zone
        jsr power_mark_dirty            ; a new zone changes the power network
        jsr audio_construct             ; zone placed -> construction sound

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
        jsr render_redraw_cell_tile
        lda #ZONE_SIZE+2                 ; 5x5 ring around the 3x3 zone
        sta zrb_w
        sta zrb_h
        jmp city_zone_refresh_border    ; re-tile power lines/roads bordering it

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

; Carry SET if every cell of the 3x3 zone at (zone_org_x, zone_org_y) is buildable
; -- TILE_GROUND or a power line (zones overwrite power lines) -- so a zone may be
; placed there; carry CLEAR if any cell is water/road/another zone. Clobbers
; zone_dx/dy and city_ptr_* (re-set by city_stamp_zone on the way in).
city_zone_can_place:
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
        beq _czg_ok
        jsr is_powerline_value      ; zones may also overwrite power lines
        bcc _czg_no
_czg_ok:
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

; Re-tile the roads and power lines in the 5x5 area around the just-placed 3x3
; zone, so a power line that ran into the zone (now removed) re-orients and a road
; crossing that lost its power reverts to a plain road. Two passes: roads first
; (crossings revert based on power presence), then power lines (which then see the
; settled roads). Both refreshes no-op on the zone's own literal cells.
city_zone_refresh_border:
        lda #0
        sta zone_rdy
_czrb_r_row:
        lda #0
        sta zone_rdx
_czrb_r_col:
        lda zone_org_x
        clc
        adc zone_rdx
        sec
        sbc #1                      ; cell_x = zone_org_x - 1 + rdx
        cmp #CELL_COLS              ; (underflow wraps to >=CELL_COLS too)
        bcs _czrb_r_next
        sta road_cx
        lda zone_org_y
        clc
        adc zone_rdy
        sec
        sbc #1
        cmp #CELL_ROWS
        bcs _czrb_r_next
        sta road_cy
        jsr road_refresh
_czrb_r_next:
        inc zone_rdx
        lda zone_rdx
        cmp zrb_w
        bne _czrb_r_col
        inc zone_rdy
        lda zone_rdy
        cmp zrb_h
        bne _czrb_r_row

        lda #0
        sta zone_rdy
_czrb_p_row:
        lda #0
        sta zone_rdx
_czrb_p_col:
        lda zone_org_x
        clc
        adc zone_rdx
        sec
        sbc #1
        cmp #CELL_COLS
        bcs _czrb_p_next
        sta powerline_cx
        lda zone_org_y
        clc
        adc zone_rdy
        sec
        sbc #1
        cmp #CELL_ROWS
        bcs _czrb_p_next
        sta powerline_cy
        jsr powerline_refresh
_czrb_p_next:
        inc zone_rdx
        lda zone_rdx
        cmp zrb_w
        bne _czrb_p_col
        inc zone_rdy
        lda zone_rdy
        cmp zrb_h
        bne _czrb_p_row
        rts

; (The coal-plant placement path used to live here. It now goes through the
; generic cps_structure in structures.asm via the dispatch above.)

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
road_cross_save:                ; cell overwritten while testing a road/power cross
        .byte 0
zone_org_x:
        .byte 0
zone_org_y:
        .byte 0
zone_dx:
        .byte 0
zone_dy:
        .byte 0
zone_rdx:                       ; city_zone_refresh_border loop counters
        .byte 0
zone_rdy:
        .byte 0
zrb_w:                          ; border-refresh scan size (footprint + 2)
        .byte 0
zrb_h:
        .byte 0
zone_char_base:
        .byte 0
zone_tmp:
        .byte 0
