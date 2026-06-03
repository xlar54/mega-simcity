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
        jsr population_init
        ; Filename for ovr-disk -- starts empty (no save/load yet this session).
        lda #0
        sta current_city_filename_len
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

; The initial map is just water + ground + trees -- no demo roads, zones or
; structures. Generation lives in world_gen.asm so this file can stay focused
; on cell I/O and tool dispatch.
city_seed_terrain:
        jmp world_gen_run

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
        cmp #TILE_INSPECT
        beq _cps_inspect            ; inspect mode: read cell + open popup
        cmp #TILE_DISK
        beq _cps_no_paint           ; disk options is a menu action, not a paint tool
        bra _cps_not_inspect
_cps_no_paint:
        rts

; Inspect tool: read the cell under the cursor, look up its label, open the
; popup. The popup is modal so subsequent clicks route to overlay_handle_click.
;
; Edge-only: paint tools (road / power / zone / ...) intentionally drag-paint
; while the button is held; inspect must NOT. Without this guard the same
; left-click that closed the popup keeps INPUT_PAINT asserted on subsequent
; frames (the button is still down for a frame or two after the OK hit), so
; the popup re-opens on the cell underneath OK. mouse_left_click is the one-
; frame debounced edge, so checking it here keeps inspect to one fire per
; press-release cycle.
_cps_inspect:
        lda mouse_left_click
        beq _cps_no_paint
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
        jsr city_cell_ptr               ; MAP_PTR -> the inspected cell
        jmp ovr_inspect_invoke          ; tail-call: DMA + jmp the overlay
                                        ;   (overlay does the cell read,
                                        ;   name lookup, popup_open)
_cps_not_inspect:
        cmp #TILE_ROAD
        beq _cps_road
        cmp #TILE_GROUND
        beq _cps_road               ; bulldozer is also a 1x1 (8x8) tool
        cmp #TILE_POWER
        beq _cps_power              ; power lines are 1x1 (8x8), like roads
        cmp #TILE_RAIL
        beq _cps_rail               ; rail is 1x1 (8x8), like roads
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
        jsr render_redraw_cell_tile     ; city_ptr_* still = cursor cell
        ; If we just painted water, re-tile shorelines on the 4 placed cells
        ; (each call also touches that cell's 4 neighbors, so the outer ring of
        ; ground cells gets covered too).
        lda selected_tile
        cmp #TILE_WATER
        bne _cps_2x2_done
        ; (city_ptr_x, city_ptr_y) is still the TL cell of the 2x2 block.
        lda city_ptr_x
        sta cps_2x2_orig_x
        lda city_ptr_y
        sta cps_2x2_orig_y
        ; TL
        jsr water_shore_refresh_neighbors
        ; TR (TL_x + 1, TL_y)
        lda cps_2x2_orig_x
        clc
        adc #1
        sta city_ptr_x
        lda cps_2x2_orig_y
        sta city_ptr_y
        jsr water_shore_refresh_neighbors
        ; BL (TL_x, TL_y + 1)
        lda cps_2x2_orig_x
        sta city_ptr_x
        lda cps_2x2_orig_y
        clc
        adc #1
        sta city_ptr_y
        jsr water_shore_refresh_neighbors
        ; BR (TL_x + 1, TL_y + 1)
        lda cps_2x2_orig_x
        clc
        adc #1
        sta city_ptr_x
        lda cps_2x2_orig_y
        clc
        adc #1
        sta city_ptr_y
        jsr water_shore_refresh_neighbors
_cps_2x2_done:
        rts

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
        ; bulldozer: clear built tiles only. Water and shore are part of the
        ; terrain and stay protected (bridges accept shore as a placement
        ; anchor, so nothing to bulldoze to "free up" the shore). Already-
        ; clear ground is also a no-op so a held/dragged bulldozer only booms
        ; when it actually demolishes something.
        jsr is_water_value              ; matches TILE_WATER and every shore variant
        bcs _cps_road_skip
        cmp #TILE_GROUND
        beq _cps_road_skip
        ; Debris cells require an edge-triggered click (no held drag) so the
        ; same bulldoze action that demolished a plant doesn't immediately
        ; scrub the cursor's resulting debris back to ground on the next
        ; frame. mouse_left_click is edge-only (mouse_update_click sets it
        ; just once per confirmed press), so dragging through debris no-ops.
        cmp #DEBRIS_CELL
        bne _cps_road_save_cell
        ldx mouse_left_click            ; X = 1 only on the press-edge frame
        beq _cps_road_skip              ; held frame -> leave debris alone
_cps_road_save_cell:
        sta bulldoze_cell               ; save what we're demolishing for the
                                        ; bridge-vs-everything-else decision below
        ; Multi-cell structures (coal/nuclear plants) demolish as a unit. A
        ; partial demolition would leave power_sum_capacity granting the
        ; plant's full output for the one-cell remnant -- a half-bulldozed coal
        ; plant would still produce 40 zones of power. structure_demolish_at_cell
        ; handles the whole job (full cost, stamp, redraw, audio, mark dirty,
        ; border refresh) so we just tail-call it.
        jsr is_structure_cell           ; preserves A; carry SET if A is a struct cell
        bcc _cps_road_single
        lda bulldoze_cell               ; restore A in case is_structure_cell mutated
        jmp structure_demolish_at_cell
_cps_road_single:
        lda #<COST_BULLDOZE             ; charge $1 per demolished cell
        sta cost_amount
        lda #>COST_BULLDOZE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_road_skip
        jsr funds_subtract
        ; Population: dispatch zone-origin bulldoze. Residential origin cell
        ; unregisters the zone (drops its pop to 0 and re-sums); C/I origin
        ; cell decrements the global has-jobs counter. Partial demolitions
        ; (non-origin cells of a 3x3 zone) don't fire here -- the zone stays
        ; registered but its power state will recompute via the existing
        ; power_mark_dirty path further down.
        lda bulldoze_cell
        cmp #ZONE_CELL_FIRST                ; empty residential origin
        beq _pop_demo_res
        cmp #RES_HOUSE_CELL_FIRST           ; evolved residential origin (houses)
        beq _pop_demo_res
        cmp #APT_CELL_FIRST                 ; evolved residential origin (apartments)
        beq _pop_demo_res
        cmp #ZONE_CELL_FIRST + 9            ; commercial origin (empty)
        beq _pop_demo_com
        cmp #COM_HEAVY_CELL_FIRST           ; evolved commercial origin
        beq _pop_demo_com
        cmp #ZONE_CELL_FIRST + 18           ; industrial origin (empty)
        beq _pop_demo_ind
        cmp #IND_HEAVY_CELL_FIRST           ; evolved industrial origin
        beq _pop_demo_ind
        bra _pop_demo_done
_pop_demo_res:
        jsr population_unregister_residential
        bra _pop_demo_done
_pop_demo_com:
        jsr population_unregister_commercial
        bra _pop_demo_done
_pop_demo_ind:
        jsr population_unregister_industrial
_pop_demo_done:

        ; Pick the replacement cell value. Bridges restore the water that was
        ; underneath; everything else (roads, zones, structures, trees, shore)
        ; leaves bare ground.
        lda bulldoze_cell
        cmp #ROAD_CELL_BRIDGE_H
        beq _cps_road_bulldoze_water
        cmp #ROAD_CELL_BRIDGE_V
        beq _cps_road_bulldoze_water
        cmp #RAIL_CELL_BRIDGE_H
        beq _cps_road_bulldoze_water
        cmp #RAIL_CELL_BRIDGE_V
        beq _cps_road_bulldoze_water
        cmp #POWER_BRIDGE_CELL_FIRST
        bcc _cps_road_bulldoze_ground
        cmp #POWER_BRIDGE_CELL_LAST+1
        bcs _cps_road_bulldoze_ground
_cps_road_bulldoze_water:
        lda #TILE_WATER
        bra _cps_road_bulldoze_stamp
_cps_road_bulldoze_ground:
        lda #TILE_GROUND
_cps_road_bulldoze_stamp:
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty            ; demolition may break the power network
        ; First: water-shore refresh on this cell + its neighbors. If the cell
        ; is now TILE_WATER (bridge demo), water_shore_refresh_at picks the
        ; right shore variant from the current neighbours -- so a bridge that
        ; sat over open water becomes TILE_WATER again, and one that sat over a
        ; shoreline cell becomes that shore variant again. Doing this BEFORE
        ; the road/powerline/tree refreshes keeps MAP_PTR in a clean state for
        ; the water pass and avoids any interaction with downstream refreshes.
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr water_shore_refresh_neighbors
        ; Now the other refreshes (these all skip non-matching cells, so the
        ; just-written water cell is a no-op for them).
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr render_redraw_cell_tile
        jsr audio_explosion             ; demolished a built tile -> boom
        jsr road_refresh_neighbors      ; roads above/below may re-orient
        lda road_cx                     ; ...and rails around may re-orient
        sta rail_cx
        lda road_cy
        sta rail_cy
        jsr rail_refresh_neighbors
        lda road_cx                     ; ...and power lines around the cell
        sta powerline_cx
        lda road_cy
        sta powerline_cy
        jsr powerline_refresh_neighbors
        lda road_cx                     ; ...and adjacent trees re-pick edge/corner art
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jmp tree_refresh_neighbors
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
        jsr is_water_value          ; water or shore -> try a bridge
        bcs _cps_road_try_bridge
        lda road_cross_save
        cmp #RAIL_CELL_H            ; H rail -> RAIL_H_ROAD crossing
        beq _cps_road_on_rail_h
        cmp #RAIL_CELL_V            ; V rail -> RAIL_V_ROAD crossing
        beq _cps_road_on_rail_v
        ; Not ground / not water / not straight rail. A road may still CROSS an
        ; existing power line, but only perpendicularly. Tentatively drop a
        ; road+power crossing variant and let road_refresh decide; keep it only
        ; if it stayed a crossing tile, else restore the power line.
        ;
        ; The tentative drop is ROAD_CELL_V_POWER (not plain ROAD_CELL_H) so
        ; road_refresh sees net_was_cross=1. That matters when the cell being
        ; converted is the only power-line cell between two zones (Z P Z): the
        ; "NEW crossing needs >=1 actual power-line side" rule in net_power_ns
        ; /ew would otherwise reject the placement because both sides are
        ; zones (class 1), not lines (class 2). The retain rule (any non-bare
        ; side) accepts the conversion, which is correct here -- the
        ; converted cell IS the wire that connected the two zones; V_POWER
        ; carries the same horizontal wires straight through.
        ;
        ; The variant choice (V_POWER vs H_POWER) is irrelevant: the
        ; orientation decision in _nr_vertical / _nr_h still runs net_power_*
        ; against the actual neighbours and may flip H<->V. We pre-write
        ; V_POWER for both axes; refresh corrects on a vertical power line.
        jsr is_powerline_value
        bcc _cps_road_skip          ; occupied by a road/zone/water -> can't build
        lda #ROAD_CELL_V_POWER
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

; Road over straight rail: create the sticky rail+road crossing. Affordability
; already checked at _cps_road_build entry; rail_refresh / road_refresh both
; recognise the cell so adjacent rails and roads pick up the right neighbour
; bit and re-tile around the crossing.
_cps_road_on_rail_h:
        lda #RAIL_CELL_H_ROAD       ; H rail + V road (we're placing the V road)
        bra _cps_road_on_rail_commit
_cps_road_on_rail_v:
        lda #RAIL_CELL_V_ROAD       ; V rail + H road
_cps_road_on_rail_commit:
        sta cps_bridge_value        ; reuse scratch byte for the cell value
        jsr funds_subtract
        jsr audio_road_build
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda cps_bridge_value
        ldz #0
        sta [MAP_PTR],z
        jsr render_redraw_cell_tile
        jsr road_refresh_neighbors  ; roads see the crossing as a road
        lda road_cx
        sta rail_cx
        lda road_cy
        sta rail_cy
        jmp rail_refresh_neighbors  ; rails see it as a rail
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

; ----------------------------------------------------------------------------
; Bridge placement. Existing cell is water (TILE_WATER or shore) and the road
; tool is active. Check the 4 cardinal neighbors; if there's a road or bridge
; in either horizontal direction, place ROAD_CELL_BRIDGE_H; else if vertical,
; ROAD_CELL_BRIDGE_V; else silent reject. This single rule enforces the
; Amiga-style constraints implicitly:
;   * "Straight only" -- we only pick H or V, never any curve/T/4-way.
;   * "No intersections over water" -- a bridge can't grow from another bridge
;     on the perpendicular axis (the anchor check returns the wrong axis), so
;     two bridges crossing at a single water cell is impossible.
;   * "Must connect to land" -- the first bridge cell needs a road neighbor,
;     which only exists on land (roads can't sit on water otherwise).
; The bridge counts as water for water_shore's neighbor scan, so adjacent
; water cells' shore masks don't change -- the shoreline flows under the span.
; ----------------------------------------------------------------------------
_cps_road_try_bridge:
        ; E neighbor (road_cx+1, road_cy)
        lda road_cx
        cmp #CELL_COLS-1
        bcs _cpsrtb_e_done
        clc
        adc #1
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr road_at_ptr
        bcs _cps_road_bridge_h
_cpsrtb_e_done:
        ; W neighbor (road_cx-1, road_cy)
        lda road_cx
        beq _cpsrtb_w_done
        sec
        sbc #1
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr road_at_ptr
        bcs _cps_road_bridge_h
_cpsrtb_w_done:
        ; N neighbor (road_cx, road_cy-1)
        lda road_cy
        beq _cpsrtb_n_done
        sec
        sbc #1
        sta city_ptr_y
        lda road_cx
        sta city_ptr_x
        jsr road_at_ptr
        bcs _cps_road_bridge_v
_cpsrtb_n_done:
        ; S neighbor (road_cx, road_cy+1)
        lda road_cy
        cmp #CELL_ROWS-1
        bcs _cps_road_skip
        clc
        adc #1
        sta city_ptr_y
        lda road_cx
        sta city_ptr_x
        jsr road_at_ptr
        bcs _cps_road_bridge_v
        rts                              ; no anchor in any direction

_cps_road_bridge_h:
        lda #ROAD_CELL_BRIDGE_H
        bra _cps_road_bridge_commit
_cps_road_bridge_v:
        lda #ROAD_CELL_BRIDGE_V
_cps_road_bridge_commit:
        sta cps_bridge_value
        jsr funds_subtract               ; charge the normal road cost
        jsr audio_road_build
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda cps_bridge_value
        ldz #0
        sta [MAP_PTR],z
        jsr render_redraw_cell_tile
        ; The bridge is not a power source. Adjacent water cells' shoreline
        ; masks are unchanged because is_water_or_bridge counts the bridge as
        ; water. Only adjacent roads need to re-check their orientation.
        jmp road_refresh_neighbors

;-----------------------------------------------------------------------------
; Rail paint path (1x1, mirrors _cps_road). Places rail on ground; on water
; tries a straight-only bridge; on a power line drops a tentative rail to test
; for a perpendicular *_POWER crossing -- otherwise restores the wire. Rail+
; road cross-network crossings are NOT supported in this branch (see TODO.md)
; -- placing rail on a road, or vice versa, silently rejects.
;-----------------------------------------------------------------------------
_cps_rail:
        lda view_x
        asl
        clc
        adc mouse_cell_x
        sta city_ptr_x
        sta rail_cx
        lda view_y
        asl
        clc
        adc mouse_cell_y
        sta city_ptr_y
        sta rail_cy
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z             ; A = existing cell
        sta rail_cross_save         ; for the power-line crossing tentative path
        cmp #TILE_GROUND
        beq _cps_rail_place
        jsr is_water_value          ; water/shore -> try bridge (water_shore
        bcs _cps_rail_try_bridge    ;   cells live above ground in is_water_value)
        lda rail_cross_save
        cmp #ROAD_CELL_H            ; H road -> RAIL_V_ROAD (V rail crosses)
        beq _cps_rail_on_road_h
        cmp #ROAD_CELL_V            ; V road -> RAIL_H_ROAD (H rail crosses)
        beq _cps_rail_on_road_v
        jsr is_powerline_value      ; on a power line -> try perpendicular cross
        bcc _cps_rail_skip          ; anything else (road curve/T/4-way / zone /
                                    ; structure / tree / existing rail / bridges)
                                    ; -> skip silently
        ; Power line under the cursor. Check affordability first, then drop a
        ; tentative rail and let rail_refresh decide H/V/CROSS. Keep only if
        ; it became a *_POWER tile; else restore the wire.
        lda #<COST_RAIL
        sta cost_amount
        lda #>COST_RAIL
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_rail_skip
        lda #RAIL_CELL_H            ; placeholder; rail_refresh decides axis
        ldz #0
        sta [MAP_PTR],z
        jsr rail_refresh
        lda rail_cx
        sta city_ptr_x
        lda rail_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #RAIL_CELL_H_POWER
        beq _cps_rail_crossed
        cmp #RAIL_CELL_V_POWER
        beq _cps_rail_crossed
        ; Not a perpendicular crossing -> undo, leave the power line intact.
        lda rail_cross_save
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile
_cps_rail_crossed:
        jsr funds_subtract
        jsr audio_road_build        ; reuse road-build sfx until we have rail sfx
        jsr rail_refresh_neighbors  ; let neighboring rails re-check
        lda rail_cx                 ; ...and adjacent power lines learn about the cross
        sta powerline_cx
        lda rail_cy
        sta powerline_cy
        jmp powerline_refresh_neighbors

_cps_rail_place:
        lda #<COST_RAIL
        sta cost_amount
        lda #>COST_RAIL
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_rail_skip
        jsr funds_subtract
        lda #RAIL_CELL_H            ; placeholder; rail_refresh decides H/V
        ldz #0
        sta [MAP_PTR],z
        jsr audio_road_build        ; (until a dedicated rail sfx exists)
        jsr rail_refresh
        jmp rail_refresh_neighbors

; Rail over a straight road: charge COST_RAIL, stamp the sticky crossing cell,
; refresh both networks' neighbours.
_cps_rail_on_road_h:
        lda #RAIL_CELL_V_ROAD       ; H road + V rail (we're placing the V rail)
        bra _cps_rail_on_road_commit
_cps_rail_on_road_v:
        lda #RAIL_CELL_H_ROAD       ; V road + H rail
_cps_rail_on_road_commit:
        sta cps_bridge_value        ; reuse scratch byte for the cell value
        lda #<COST_RAIL
        sta cost_amount
        lda #>COST_RAIL
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_rail_skip
        jsr funds_subtract
        jsr audio_road_build
        lda rail_cx
        sta city_ptr_x
        lda rail_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda cps_bridge_value
        ldz #0
        sta [MAP_PTR],z
        jsr render_redraw_cell_tile
        jsr rail_refresh_neighbors
        lda rail_cx
        sta road_cx
        lda rail_cy
        sta road_cy
        jmp road_refresh_neighbors

_cps_rail_skip:
        rts

;-----------------------------------------------------------------------------
; Rail bridge placement: existing cell is water/shore and rail tool is active.
; Same Amiga-style anchor rule as road bridges: pick H if a rail/rail-bridge
; sits E or W, else V if one sits N or S; reject otherwise.
;-----------------------------------------------------------------------------
_cps_rail_try_bridge:
        lda #<COST_RAIL_BRIDGE      ; bridges cost more than land rail
        sta cost_amount
        lda #>COST_RAIL_BRIDGE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_rail_skip
        ; E neighbour (rail_cx+1, rail_cy)
        lda rail_cx
        cmp #CELL_COLS-1
        bcs _cpsrtb_rail_e_done
        clc
        adc #1
        sta city_ptr_x
        lda rail_cy
        sta city_ptr_y
        jsr rail_at_ptr
        bcs _cps_rail_bridge_h
_cpsrtb_rail_e_done:
        ; W neighbour
        lda rail_cx
        beq _cpsrtb_rail_w_done
        sec
        sbc #1
        sta city_ptr_x
        lda rail_cy
        sta city_ptr_y
        jsr rail_at_ptr
        bcs _cps_rail_bridge_h
_cpsrtb_rail_w_done:
        ; N neighbour
        lda rail_cy
        beq _cpsrtb_rail_n_done
        sec
        sbc #1
        sta city_ptr_y
        lda rail_cx
        sta city_ptr_x
        jsr rail_at_ptr
        bcs _cps_rail_bridge_v
_cpsrtb_rail_n_done:
        ; S neighbour
        lda rail_cy
        cmp #CELL_ROWS-1
        bcs _cps_rail_skip
        clc
        adc #1
        sta city_ptr_y
        lda rail_cx
        sta city_ptr_x
        jsr rail_at_ptr
        bcs _cps_rail_bridge_v
        rts                          ; no anchor in any cardinal -> reject

_cps_rail_bridge_h:
        lda #RAIL_CELL_BRIDGE_H
        bra _cps_rail_bridge_commit
_cps_rail_bridge_v:
        lda #RAIL_CELL_BRIDGE_V
_cps_rail_bridge_commit:
        sta cps_bridge_value
        jsr funds_subtract
        jsr audio_road_build
        lda rail_cx
        sta city_ptr_x
        lda rail_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda cps_bridge_value
        ldz #0
        sta [MAP_PTR],z
        jsr render_redraw_cell_tile
        ; Bridge counts as water for shoreline masks (is_water_or_bridge),
        ; so adjacent shores don't change. Only adjacent rails re-tile.
        jmp rail_refresh_neighbors

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
        beq _cps_power_on_ground
        cmp #ROAD_CELL_H
        beq _cps_power_cross_road   ; H road -> H_POWER (vertical power across)
        cmp #ROAD_CELL_V
        beq _cps_power_cross_road   ; V road -> V_POWER (horizontal power across)
        cmp #RAIL_CELL_H
        beq _cps_power_cross_rail   ; same idea on a straight rail
        cmp #RAIL_CELL_V
        beq _cps_power_cross_rail
        jsr is_water_value
        bcs _cps_power_try_bridge   ; water or shore -> try a power bridge
        rts                         ; everything else (curves/Ts/4-way, existing
                                    ; crossings, zones, structures, trees,
                                    ; existing power lines, road bridges) -> skip

; Crossing paths: A is ROAD_CELL_H/V or RAIL_CELL_H/V on entry. The crossing
; variant for each is exactly +11 in both networks (H->H_POWER, V->V_POWER --
; ROAD_CELL_H_POWER - ROAD_CELL_H == 11 == RAIL_CELL_H_POWER - RAIL_CELL_H),
; so the same adc constant converts. We split the post-write refresh because
; only the network we crossed needs neighbour re-tile -- the *_POWER tile is
; sticky on its own engine.
_cps_power_cross_road:
        ldx #0                       ; 0 = road network
        bra _cps_power_cross_with_net
_cps_power_cross_rail:
        ldx #1                       ; 1 = rail network
_cps_power_cross_with_net:
        stx cps_power_cross_net
        clc
        adc #(ROAD_CELL_H_POWER - ROAD_CELL_H)
        pha                          ; save the crossing cell value across funds calls
        lda #<COST_POWERLINE
        sta cost_amount
        lda #>COST_POWERLINE
        sta cost_amount+1
        jsr funds_can_afford
        bcs _cps_power_cross_pay
        pla
        rts
_cps_power_cross_pay:
        jsr funds_subtract
        pla
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty
        lda cps_power_cross_net
        bne _cps_pcc_rail
        lda powerline_cx
        sta road_cx
        lda powerline_cy
        sta road_cy
        jsr road_refresh_neighbors
        jmp powerline_refresh_neighbors
_cps_pcc_rail:
        lda powerline_cx
        sta rail_cx
        lda powerline_cy
        sta rail_cy
        jsr rail_refresh_neighbors
        jmp powerline_refresh_neighbors

_cps_power_on_ground:
        lda #<COST_POWERLINE        ; check + deduct power-line cost
        sta cost_amount
        lda #>COST_POWERLINE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_power_skip
        jsr funds_subtract
        ; Drop a plain line; powerline_refresh decides H/V from neighbours and
        ; promotes to POLE only when this cell is actually a 4-way intersection.
        ; The old "every Nth placement is a cosmetic pole" cadence is gone.
        lda #POWERLINE_CELL_H
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty        ; the power network changed
        ; First let adjacent straight roads / rails detect a new crossing (they
        ; read the raw power placeholder just written). Then orient this line and
        ; its power neighbours, which now see any crossing tile as an on-axis
        ; connection.
        lda powerline_cx
        sta road_cx
        lda powerline_cy
        sta road_cy
        jsr road_refresh_neighbors
        lda powerline_cx
        sta rail_cx
        lda powerline_cy
        sta rail_cy
        jsr rail_refresh_neighbors
        jsr powerline_refresh
        jmp powerline_refresh_neighbors
_cps_power_skip:
        rts

; ----------------------------------------------------------------------------
; Power bridge placement. Existing cell is water (TILE_WATER or shore) and the
; power tool is active. Same Amiga-style rule as road bridges, but using
; power-line/bridge cells as the anchor: if there's a power line (or another
; power bridge) E or W -> POWER_BRIDGE_CELL_H; else if N or S ->
; POWER_BRIDGE_CELL_V; else silent reject. Constrained to a single direction
; per cell, so curves / Ts / 4-ways over water are structurally impossible.
; ----------------------------------------------------------------------------
_cps_power_try_bridge:
        lda #<COST_POWERLINE
        sta cost_amount
        lda #>COST_POWERLINE
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cps_power_skip

        ; E neighbor (powerline_cx+1, powerline_cy)
        lda powerline_cx
        cmp #CELL_COLS-1
        bcs _cpsptb_e_done
        clc
        adc #1
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_power_line_or_bridge
        bcs _cps_power_bridge_h
_cpsptb_e_done:
        ; W neighbor (powerline_cx-1, powerline_cy)
        lda powerline_cx
        beq _cpsptb_w_done
        sec
        sbc #1
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_power_line_or_bridge
        bcs _cps_power_bridge_h
_cpsptb_w_done:
        ; N neighbor (powerline_cx, powerline_cy-1)
        lda powerline_cy
        beq _cpsptb_n_done
        sec
        sbc #1
        sta city_ptr_y
        lda powerline_cx
        sta city_ptr_x
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_power_line_or_bridge
        bcs _cps_power_bridge_v
_cpsptb_n_done:
        ; S neighbor (powerline_cx, powerline_cy+1)
        lda powerline_cy
        cmp #CELL_ROWS-1
        bcs _cps_power_skip
        clc
        adc #1
        sta city_ptr_y
        lda powerline_cx
        sta city_ptr_x
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_power_line_or_bridge
        bcs _cps_power_bridge_v
        rts                              ; no anchor in any direction

_cps_power_bridge_h:
        lda #POWER_BRIDGE_CELL_H
        bra _cps_power_bridge_commit
_cps_power_bridge_v:
        lda #POWER_BRIDGE_CELL_V
_cps_power_bridge_commit:
        sta cps_bridge_value
        jsr funds_subtract
        lda powerline_cx
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda cps_bridge_value
        ldz #0
        sta [MAP_PTR],z
        jsr power_mark_dirty
        jsr render_redraw_cell_tile
        ; Adjacent water masks unchanged (is_water_or_bridge counts the bridge
        ; as water). Refresh adjacent power lines so they see the new wire.
        jmp powerline_refresh_neighbors

; Origin compute + clamp for the 3x3 zone footprint, shared by the paint path
; and the cursor-color predicate. Reads view + mouse, writes zone_org_x/y.
zone_setup_origin:
        lda view_x
        asl
        clc
        adc mouse_cell_x
        cmp #(CELL_COLS - ZONE_SIZE + 1)
        bcc _zso_setx
        lda #(CELL_COLS - ZONE_SIZE)
_zso_setx:
        sta zone_org_x
        lda view_y
        asl
        clc
        adc mouse_cell_y
        cmp #(CELL_ROWS - ZONE_SIZE + 1)
        bcc _zso_sety
        lda #(CELL_ROWS - ZONE_SIZE)
_zso_sety:
        sta zone_org_y
        rts

; Zone paint path.
cps_zone:
        jsr zone_setup_origin
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
        ; Population: dispatch zone-placement to the registry. Residential
        ; zones get a per-zone slot (zone_pop[X] grows monthly). Commercial /
        ; industrial bump global counters for the "any jobs anywhere?" check
        ; that gates residential growth.
        lda selected_tile
        cmp #TILE_RESIDENTIAL
        bne _pop_check_com_place
        jsr population_register_residential
        bra _pop_place_done
_pop_check_com_place:
        cmp #TILE_COMMERCIAL
        bne _pop_check_ind_place
        jsr population_register_commercial
        bra _pop_place_done
_pop_check_ind_place:
        cmp #TILE_INDUSTRIAL
        bne _pop_place_done
        jsr population_register_industrial
_pop_place_done:

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

; Stamp a 3x3 zone whose top-left cell is (zone_org_x, zone_org_y).
; A = zone type (TILE_RESIDENTIAL / COMMERCIAL / INDUSTRIAL). Writes the 9
; cells as ZONE_CELL_FIRST + type_index*9 + position; cell_to_char translates
; them to chars ZONE_GEN_BASE+offset at render time. Does not redraw -- callers
; handle that (paint redraws the covered tiles; the seed runs before the first
; full render).
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
        adc #ZONE_CELL_FIRST
        sta zone_char_base          ; (mis-named for history; now a cell-value base)

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
        ; cell value = zone_char_base + position(dy*3 + dx).
        lda zone_dy
        asl
        clc
        adc zone_dy                 ; dy * 3
        clc
        adc zone_dx                 ; + dx = position 0..8
        clc
        adc zone_char_base
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
;---------------------------------------------------------------------------------------
; Zone predicates (used by render, sprites, power, powerlines, roads, etc.).
;
;   is_zone_value         -- carry SET if A is any of the 27 zone cells.
;                            Use this for "is this cell occupied / a building /
;                            a power node?" checks and adjacency logic.
;
;   is_zone_origin_value  -- carry SET only for the 3 top-left zone cells
;                            (residential / commercial / industrial origins).
;                            Use this when scanning for zones to count or
;                            decorate the WHOLE zone exactly once (power
;                            capacity, unpowered-bolt placement, etc.).
;
; Both preserve A.
;---------------------------------------------------------------------------------------
is_zone_value:
        cmp #ZONE_CELL_FIRST
        bcc _izv_check_evolved
        cmp #ZONE_CELL_LAST+1
        bcc _izv_yes
_izv_check_evolved:
        ; Evolved zones occupy a single contiguous range:
        ; RES_HOUSE..APT..IND_HEAVY..COM_HEAVY = 198..233.
        cmp #RES_HOUSE_CELL_FIRST
        bcc _izv_no
        cmp #COM_HEAVY_CELL_LAST+1
        bcs _izv_no
_izv_yes:
        sec
        rts
_izv_no:
        clc
        rts

is_zone_origin_value:
        cmp #ZONE_CELL_FIRST                ; R origin (offset 0)
        beq _izov_yes
        cmp #(ZONE_CELL_FIRST + 9)          ; C origin (offset 9)
        beq _izov_yes
        cmp #(ZONE_CELL_FIRST + 18)         ; I origin (offset 18)
        beq _izov_yes
        cmp #RES_HOUSE_CELL_FIRST           ; evolved R origin (houses)
        beq _izov_yes
        cmp #APT_CELL_FIRST                 ; evolved R origin (apartments)
        beq _izov_yes
        cmp #IND_HEAVY_CELL_FIRST           ; evolved I origin (heavy)
        beq _izov_yes
        cmp #COM_HEAVY_CELL_FIRST           ; evolved C origin (heavy)
        beq _izov_yes
        clc
        rts
_izov_yes:
        sec
        rts

; Read the cell value under the current cursor. Returns A = cell value;
; clobbers MAP_PTR, city_ptr_x/y, Z. Used by cursor_placement_valid for the
; 1x1 tools, mirroring the (view*2 + mouse_cell) + city_cell_ptr + [MAP_PTR],z
; sequence at the head of _cps_road / _cps_rail / _cps_power.
cursor_read_cell:
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
        ldz #0
        lda [MAP_PTR],z
        rts

; Cursor-color predicate: returns carry SET if selected_tile placement at the
; current cursor cell would succeed, CLEAR otherwise. Called every frame from
; sprites_refresh to pick the cursor color (yellow vs red).
;
; Tools handled (per-tool rules mirror the matching _cps_* paint paths in
; city.asm so a green/red cursor matches click-time behaviour):
;   * Bulldoze (TILE_GROUND) -> RED on ground/water (nothing to demolish),
;                               YELLOW on anything built
;   * Road  -> YELLOW on ground / water (bridge candidate) / straight rail /
;              power line (cross candidate); RED on everything else
;   * Rail  -> YELLOW on ground / water / straight road / power line; RED else
;   * Power -> YELLOW on ground / water / straight road / straight rail; RED
;              else (existing power lines reject -- no self-overlay)
;   * Zones (R/C/I)                            -> zone_setup_origin +
;                                                  city_zone_can_place
;   * Structures (coal, nuclear, park, police) -> structure_setup_origin +
;                                                  structure_can_place
;   * Non-paint tools (INSPECT/LOAD/SAVE) and the 2x2 water tool -> YELLOW
;     (the inspect/load/save cursors are hidden by sprites_refresh; the 2x2
;     water tool uses sprite 1 whose color isn't yet wired to this predicate)
;
; Approximation: water is reported VALID for road/rail/power tools even though
; the actual click only succeeds if there's a perpendicular anchor (road/rail
; on the other side). The cursor stays yellow over water; the click silently
; no-ops if there's no anchor. Tighten only if it shows up as a usability
; problem.
cursor_placement_valid:
        lda selected_tile
        cmp #TILE_GROUND
        beq _cpv_bulldoze
        cmp #TILE_ROAD
        beq _cpv_road
        cmp #TILE_POWER
        beq _cpv_power
        cmp #TILE_RAIL
        beq _cpv_rail
        jsr structure_find_by_tool  ; preserves A; carry SET = matched, X = idx
        bcs _cpv_structure
        cmp #TILE_RESIDENTIAL
        bcc _cpv_yes
        cmp #TILE_INDUSTRIAL+1
        bcs _cpv_yes                ; > industrial: non-paint tool, no check
        jsr zone_setup_origin
        jmp city_zone_can_place
_cpv_structure:
        txa
        jsr structure_setup_origin
        ldx struct_idx
        jmp structure_can_place
_cpv_bulldoze:
        jsr cursor_read_cell
        cmp #TILE_GROUND
        beq _cpv_no                 ; already cleared -> no-op
        jsr is_water_value          ; preserves A; SET if water/shore
        bcs _cpv_no                 ; terrain is protected
        sec
        rts
_cpv_road:
        jsr cursor_read_cell
        cmp #TILE_GROUND
        beq _cpv_yes
        jsr is_water_value
        bcs _cpv_yes
        cmp #RAIL_CELL_H
        beq _cpv_yes
        cmp #RAIL_CELL_V
        beq _cpv_yes
        jmp is_powerline_value      ; tail-call: SET if power-line crossing OK
_cpv_rail:
        jsr cursor_read_cell
        cmp #TILE_GROUND
        beq _cpv_yes
        jsr is_water_value
        bcs _cpv_yes
        cmp #ROAD_CELL_H
        beq _cpv_yes
        cmp #ROAD_CELL_V
        beq _cpv_yes
        jmp is_powerline_value
_cpv_power:
        jsr cursor_read_cell
        cmp #TILE_GROUND
        beq _cpv_yes
        jsr is_water_value
        bcs _cpv_yes
        cmp #ROAD_CELL_H
        beq _cpv_yes
        cmp #ROAD_CELL_V
        beq _cpv_yes
        cmp #RAIL_CELL_H
        beq _cpv_yes
        cmp #RAIL_CELL_V
        beq _cpv_yes
        clc
        rts
_cpv_yes:
        sec
        rts
_cpv_no:
        clc
        rts

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

; The filename of the city last loaded or saved (if any). Used by the disk
; overlay to pre-populate the Save panel's filename field. Maintained by the
; disk overlay -- ovr-disk writes both buffer + length on a successful save or
; load. ASCII uppercase chars, 0..CITY_FILENAME_MAX chars long.
CITY_FILENAME_MAX        = 12
current_city_filename_len:
        .byte 0
current_city_filename:
        .fill CITY_FILENAME_MAX, 0

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
cps_2x2_orig_x:                 ; saved 2x2 origin across the 4 shoreline refreshes
        .byte 0
cps_2x2_orig_y:
        .byte 0
cps_bridge_value:               ; bridge cell value picked by the anchor scan
        .byte 0
bulldoze_cell:                  ; saved existing-cell value for bridge detection
        .byte 0
road_cross_save:                ; cell overwritten while testing a road/power cross
        .byte 0
rail_cross_save:                ; same idea for the rail+power crossing tentative path
        .byte 0
cps_power_cross_net:            ; 0=road,1=rail -- picks the right refresh after a power cross
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
