;=======================================================================================
; Road auto-tiling.
;
; Thin wrapper over linear_net.asm. The shared engine handles the 8-neighbour
; scan, mask refinement, orientation choice and sticky power crossings; this
; module just publishes the road descriptor (which cell values to use) and the
; road_cx/cy / road_refresh / road_refresh_neighbors / is_road_value /
; road_at_ptr public API that city.asm and friends already call.
;
; Adding a parallel network (rails, ...) means copy this file and substitute
; the constants; no autotile logic gets duplicated.
;=======================================================================================

; Carry SET if cell value A is a road (any orientation, including rail+road
; crossings whose road segment is on this network). Loads the road descriptor
; as a side effect so a subsequent road_refresh in the same chain uses the
; road constants. Preserves A. Uses is_net_neighbor (range + ln_extra_a/b)
; so a road south of a RAIL_*_ROAD cell still sees a road on its N.
is_road_value:
        jsr road_descriptor_load
        jmp is_net_neighbor

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is a road.
road_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_road_value

; Re-orient and redraw the road cell at (road_cx, road_cy). No-op if not a road.
road_refresh:
        jsr road_descriptor_load
        lda road_cx
        sta net_cx
        lda road_cy
        sta net_cy
        jmp net_refresh

; Re-orient the 8 cells around (road_cx, road_cy).
road_refresh_neighbors:
        jsr road_descriptor_load
        lda road_cx
        sta net_cx
        lda road_cy
        sta net_cy
        jmp net_refresh_neighbors

; Publish the road descriptor: which cell values the linear-net engine should
; use when this network is active. Called by the public entries above and
; latched until another network's descriptor-load overwrites it.
road_descriptor_load:
        lda #ROAD_CELL_FIRST
        sta ln_first
        lda #ROAD_CELL_LAST+1
        sta ln_last_p1
        lda #ROAD_CELL_H
        sta ln_h
        lda #ROAD_CELL_V
        sta ln_v
        lda #ROAD_CELL_4WAY
        sta ln_4way
        lda #ROAD_CELL_CURVE_NW
        sta ln_curve_nw
        lda #ROAD_CELL_CURVE_NE
        sta ln_curve_ne
        lda #ROAD_CELL_CURVE_SW
        sta ln_curve_sw
        lda #ROAD_CELL_CURVE_SE
        sta ln_curve_se
        lda #ROAD_CELL_T_N
        sta ln_t_n
        lda #ROAD_CELL_T_S
        sta ln_t_s
        lda #ROAD_CELL_T_E
        sta ln_t_e
        lda #ROAD_CELL_T_W
        sta ln_t_w
        lda #ROAD_CELL_BRIDGE_H
        sta ln_bridge_h
        lda #ROAD_CELL_BRIDGE_V
        sta ln_bridge_v
        lda #ROAD_CELL_H_POWER
        sta ln_h_power
        lda #ROAD_CELL_V_POWER
        sta ln_v_power
        ; Roads have no cross-network crossings owned by them (rail+road
        ; crossings live in the rail range). Disable the sticky skip.
        lda #$FF
        sta ln_xnet_h
        sta ln_xnet_v
        ; Accept rail+road crossings as road neighbours so a road south of a
        ; RAIL_H_ROAD still detects a road on its N. Axis-naive (same
        ; sloppiness the existing road+power crossings have), but visible
        ; oddities are rare in practice.
        lda #RAIL_CELL_H_ROAD
        sta ln_extra_a
        lda #RAIL_CELL_V_ROAD
        sta ln_extra_b
        rts

; --- public coord state (set by callers before road_refresh*) ---
road_cx:                .byte 0
road_cy:                .byte 0
