;=======================================================================================
; Rail auto-tiling.
;
; Thin wrapper over linear_net.asm, mirroring roads.asm. Rail is the second
; instance of the shared 1x1 autotile engine: same orientation/curve/T/4-way
; logic, same sticky bridges (straight-only over water), same sticky
; perpendicular power crossing. Rail+road cross-network crossings are NOT in
; this branch -- see TODO.md.
;=======================================================================================

; Carry SET if cell value A is a rail (any orientation). Loads the rail
; descriptor as a side effect so a subsequent rail_refresh in the same chain
; uses the rail constants. Preserves A.
is_rail_value:
        jsr rail_descriptor_load
        jmp is_net_value

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is a rail.
rail_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_rail_value

; Re-orient and redraw the rail cell at (rail_cx, rail_cy). No-op if not a rail.
rail_refresh:
        jsr rail_descriptor_load
        lda rail_cx
        sta net_cx
        lda rail_cy
        sta net_cy
        jmp net_refresh

; Re-orient the 8 cells around (rail_cx, rail_cy).
rail_refresh_neighbors:
        jsr rail_descriptor_load
        lda rail_cx
        sta net_cx
        lda rail_cy
        sta net_cy
        jmp net_refresh_neighbors

; Publish the rail descriptor.
rail_descriptor_load:
        lda #<RAIL_CELL_FIRST
        sta ln_first
        lda #<(RAIL_CELL_LAST+1)
        sta ln_last_p1
        lda #<RAIL_CELL_H
        sta ln_h
        lda #<RAIL_CELL_V
        sta ln_v
        lda #<RAIL_CELL_4WAY
        sta ln_4way
        lda #<RAIL_CELL_CURVE_NW
        sta ln_curve_nw
        lda #<RAIL_CELL_CURVE_NE
        sta ln_curve_ne
        lda #<RAIL_CELL_CURVE_SW
        sta ln_curve_sw
        lda #<RAIL_CELL_CURVE_SE
        sta ln_curve_se
        lda #<RAIL_CELL_T_N
        sta ln_t_n
        lda #<RAIL_CELL_T_S
        sta ln_t_s
        lda #<RAIL_CELL_T_E
        sta ln_t_e
        lda #<RAIL_CELL_T_W
        sta ln_t_w
        lda #<RAIL_CELL_BRIDGE_H
        sta ln_bridge_h
        lda #<RAIL_CELL_BRIDGE_V
        sta ln_bridge_v
        lda #<RAIL_CELL_H_POWER
        sta ln_h_power
        lda #<RAIL_CELL_V_POWER
        sta ln_v_power
        ; Rail+road crossings are rail-owned (cell value in rail range), so
        ; the engine's sticky skip-list catches them and prevents net_refresh
        ; from rewriting them.
        lda #<RAIL_CELL_H_ROAD
        sta ln_xnet_h
        lda #<RAIL_CELL_V_ROAD
        sta ln_xnet_v
        ; Rails' own range already includes the crossings, so no extra
        ; neighbour acceptances needed -- leave both at $FF (never match).
        lda #$FF
        sta ln_extra_a
        sta ln_extra_b
        rts

; --- public coord state (set by callers before rail_refresh*) ---
rail_cx:                .byte 0
rail_cy:                .byte 0
