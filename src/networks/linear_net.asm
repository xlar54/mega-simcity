;=======================================================================================
; Linear-network auto-tiling.
;
; Generic 1x1 auto-tile engine for road-like networks (roads, rails, ...). Each
; concrete network (roads.asm, rails.asm) is a thin wrapper that:
;   1. Loads its descriptor (ln_*) -- a 17-byte table of the cell values this
;      network uses for each orientation, bridges, and power crossings.
;   2. Writes the target cell coords into net_cx/net_cy.
;   3. Dispatches to net_refresh / net_refresh_neighbors here.
;
; The refresh logic is identical across road and rail: scan 8 neighbours, refine
; the connection mask (drop parallel runs), pick the orientation (4-way / curve /
; T-junction / straight). Straight runs additionally check for a perpendicular
; power-line crossing and switch to the *_POWER variant.
;
; State separation:
;   ln_*       -- "what cell values does the current network use"
;                 (loaded by the wrapper; survives until the next wrapper call)
;   net_cx/cy  -- the working cell, shared scratch across iterations
;   net_*      -- shared scratch (raw mask, refined mask, sticky-cross flag, ...)
; The wrappers keep their public coord vars (road_cx/cy, rail_cx/cy) so callers
; don't need to know which network they're on; the wrappers copy those into
; net_cx/cy before dispatching.
;=======================================================================================

; --- descriptor: cell values for the current network ---
; The wrapper sets these before calling into the engine. They survive across the
; whole refresh chain (net_refresh and net_refresh_neighbors loop internally).
ln_first:               .byte 0
ln_last_p1:             .byte 0     ; last + 1 (so `cmp ln_last_p1 / bcs` is the range test)
ln_h:                   .byte 0
ln_v:                   .byte 0
ln_4way:                .byte 0
ln_curve_nw:            .byte 0
ln_curve_ne:            .byte 0
ln_curve_sw:            .byte 0
ln_curve_se:            .byte 0
ln_t_n:                 .byte 0
ln_t_s:                 .byte 0
ln_t_e:                 .byte 0
ln_t_w:                 .byte 0
ln_bridge_h:            .byte 0
ln_bridge_v:            .byte 0
ln_h_power:             .byte 0
ln_v_power:             .byte 0
; Cross-network crossings (rail+road today). Sticky cells in THIS network's
; range that the engine never re-tiles -- net_refresh skips them like bridges.
; Set to $FF when the network has no cross-network crossing (e.g. roads).
ln_xnet_h:              .byte $FF
ln_xnet_v:              .byte $FF
; Extra cell values accepted as a neighbour of this network even though they
; lie OUTSIDE [ln_first, ln_last_p1). Used so the road engine sees rail+road
; crossings (in the rail range) as road neighbours. $FF = no extra. The
; engine's neighbour scan and the public is_*_value predicate both use these.
ln_extra_a:             .byte $FF
ln_extra_b:             .byte $FF

; --- working state shared across iterations ---
net_cx:                 .byte 0     ; cell being (re)oriented
net_cy:                 .byte 0
net_cx_save:            .byte 0     ; saved across the 8-neighbour loop
net_cy_save:            .byte 0
net_mask:               .byte 0     ; refined N/S/E/W connection bits
net_raw:                .byte 0     ; raw 8-neighbour bits
net_nidx:               .byte 0     ; net_refresh_neighbors loop index
net_tmp:                .byte 0
net_cross_s1:           .byte 0     ; net_power_ns/ew: classification of the two sides
net_cross_s2:           .byte 0
net_was_cross:          .byte 0     ; 1 if this cell is already a power crossing (sticky)

; Offsets for the 8 surrounding cells, order NW,N,NE,W,E,SW,S,SE. Shared by
; net_refresh's scan and net_refresh_neighbors. (dx/dy are signed; cmp against
; CELL_COLS/ROWS rejects both underflow and overflow at the edges.)
net_dx:  .byte $FF,$00,$01,$FF,$01,$FF,$00,$01
net_dy:  .byte $FF,$FF,$FF,$00,$00,$01,$01,$01
net_bit: .byte ROAD_BIT_NW,ROAD_BIT_N,ROAD_BIT_NE,ROAD_BIT_W,ROAD_BIT_E,ROAD_BIT_SW,ROAD_BIT_S,ROAD_BIT_SE

; Carry SET if cell value A is strictly inside this network's range
; [ln_first, ln_last_p1). Used by the engine's top-of-refresh "do I own this
; cell?" check -- intentionally strict so a network never re-tiles a sibling
; network's crossing.
is_net_value:
        cmp ln_first
        bcc _inv_no
        cmp ln_last_p1
        bcs _inv_no
        sec
        rts
_inv_no:
        clc
        rts

; Carry SET if cell value A counts as a neighbour of this network: either in
; range (is_net_value) OR one of the two cross-network extras (ln_extra_a/b,
; default $FF = never match). Used by the engine's gather loop and the public
; is_road_value / is_rail_value predicates so cross-network crossings still
; participate in autotile mask formation.
is_net_neighbor:
        jsr is_net_value
        bcs _inn_yes
        cmp ln_extra_a
        beq _inn_yes
        cmp ln_extra_b
        beq _inn_yes
        clc
        rts
_inn_yes:
        sec
        rts

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is strictly in
; this network's range. Used at the top of net_refresh.
net_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_net_value

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it counts as a
; neighbour of this network (range OR extras). Used by the engine's gather
; loop and by city.asm bridge-anchor scans.
net_at_ptr_neighbor:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_net_neighbor

; Re-orient and redraw the cell at (net_cx, net_cy). No-op if not in this network.
; Scans all 8 neighbours into net_raw, drops parallel-run perpendicular
; connections, then chooses the orientation (4-way / T / curve / straight). For
; straight runs, perpendicular power lines on both sides promote to *_POWER.
net_refresh:
        lda net_cx
        sta city_ptr_x
        lda net_cy
        sta city_ptr_y
        jsr net_at_ptr                  ; A = cell value, carry set if in network
        bcc _nr_done

        ; Bridges keep their fixed orientation -- placement enforces straight-
        ; only over water, so we must not let the neighbour scan rewrite a
        ; bridge cell into a curve/T/4-way.
        cmp ln_bridge_h
        beq _nr_done
        cmp ln_bridge_v
        beq _nr_done
        ; Same for cross-network crossings (rail+road today): city.asm creates
        ; them atomically when the player paints one network on top of the
        ; other, and the engine should never re-tile them as a plain rail or
        ; 4-way. ln_xnet_h/v default to $FF when the network has no
        ; cross-network crossing (e.g. roads) so these compares are no-ops.
        cmp ln_xnet_h
        beq _nr_done
        cmp ln_xnet_v
        beq _nr_done

        ; Sticky power crossing: a crossing stays crossed unless a side goes
        ; bare. Remember whether this cell was already a crossing before the
        ; recompute so net_power_ns/ew can preserve it.
        ldx #0
        cmp ln_h_power
        beq _nr_wascross
        cmp ln_v_power
        bne _nr_wasdone
_nr_wascross:
        inx
_nr_wasdone:
        stx net_was_cross

        lda #0
        sta net_raw
        ldx #0
_nr_gather:
        clc
        lda net_cx
        adc net_dx,x
        cmp #CELL_COLS
        bcs _nr_gnext               ; off map (under/overflow)
        sta city_ptr_x
        clc
        lda net_cy
        adc net_dy,x
        cmp #CELL_ROWS
        bcs _nr_gnext
        sta city_ptr_y
        jsr net_at_ptr_neighbor      ; preserves X; accepts range OR ln_extra_a/b
        bcc _nr_gnext
        lda net_raw
        ora net_bit,x
        sta net_raw
_nr_gnext:
        inx
        cpx #8
        bne _nr_gather

        ; refined connections start from the raw N/S/E/W
        lda net_raw
        and #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        sta net_mask
        ; horizontal run (E&W)? drop a N/S neighbour that is itself horizontal
        ; (its own E and W are network -> our diagonals NE/NW or SE/SW)
        lda net_raw
        and #(ROAD_BIT_E|ROAD_BIT_W)
        cmp #(ROAD_BIT_E|ROAD_BIT_W)
        bne _nr_chk_vert
        lda net_raw
        and #(ROAD_BIT_NE|ROAD_BIT_NW)
        cmp #(ROAD_BIT_NE|ROAD_BIT_NW)
        bne _nr_chk_drops
        lda net_mask
        and #(255-ROAD_BIT_N)
        sta net_mask
_nr_chk_drops:
        lda net_raw
        and #(ROAD_BIT_SE|ROAD_BIT_SW)
        cmp #(ROAD_BIT_SE|ROAD_BIT_SW)
        bne _nr_chk_vert
        lda net_mask
        and #(255-ROAD_BIT_S)
        sta net_mask
_nr_chk_vert:
        ; vertical run (N&S)? drop an E/W neighbour that is itself vertical
        lda net_raw
        and #(ROAD_BIT_N|ROAD_BIT_S)
        cmp #(ROAD_BIT_N|ROAD_BIT_S)
        bne _nr_decide
        lda net_raw
        and #(ROAD_BIT_NE|ROAD_BIT_SE)
        cmp #(ROAD_BIT_NE|ROAD_BIT_SE)
        bne _nr_chk_dropw
        lda net_mask
        and #(255-ROAD_BIT_E)
        sta net_mask
_nr_chk_dropw:
        lda net_raw
        and #(ROAD_BIT_NW|ROAD_BIT_SW)
        cmp #(ROAD_BIT_NW|ROAD_BIT_SW)
        bne _nr_decide
        lda net_mask
        and #(255-ROAD_BIT_W)
        sta net_mask
_nr_decide:
        lda net_mask
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        beq _nr_4way
        cmp #(ROAD_BIT_N|ROAD_BIT_W)
        beq _nr_nw
        cmp #(ROAD_BIT_N|ROAD_BIT_E)
        beq _nr_ne
        cmp #(ROAD_BIT_S|ROAD_BIT_W)
        beq _nr_sw
        cmp #(ROAD_BIT_S|ROAD_BIT_E)
        beq _nr_se
        cmp #(ROAD_BIT_N|ROAD_BIT_E|ROAD_BIT_W)
        beq _nr_tn
        cmp #(ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        beq _nr_ts
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E)
        beq _nr_te
        cmp #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_W)
        beq _nr_tw
        and #(ROAD_BIT_N|ROAD_BIT_S)   ; A still = net_mask
        bne _nr_vertical
        ; No road neighbours at all (or only E/W). Check for a perpendicular
        ; power crossing in either direction. Vertical power line through here
        ; -> H_POWER (horizontal road with vertical power crossing). Horizontal
        ; power line -> V_POWER (vertical road with horizontal power crossing).
        ; If neither, plain horizontal road.
        jsr net_power_ns
        bcs _nr_h_power
        jsr net_power_ew
        bcs _nr_v_power
        lda ln_h
        bra _nr_store
_nr_h_power:
        lda ln_h_power
        bra _nr_store
_nr_v_power:
        lda ln_v_power
        bra _nr_store
_nr_4way:
        lda ln_4way
        bra _nr_store
_nr_nw:
        lda ln_curve_nw
        bra _nr_store
_nr_ne:
        lda ln_curve_ne
        bra _nr_store
_nr_sw:
        lda ln_curve_sw
        bra _nr_store
_nr_se:
        lda ln_curve_se
        bra _nr_store
_nr_tn:
        lda ln_t_n
        bra _nr_store
_nr_ts:
        lda ln_t_s
        bra _nr_store
_nr_te:
        lda ln_t_e
        bra _nr_store
_nr_tw:
        lda ln_t_w
        bra _nr_store
_nr_vertical:
        ; pure vertical: a horizontal power line crosses it if power sits on
        ; both the E and W sides.
        jsr net_power_ew
        bcc _nr_v_plain
        lda ln_v_power
        bra _nr_store
_nr_v_plain:
        lda ln_v
_nr_store:
        sta net_tmp
        ; A power crossing being created or removed changes the power network.
        lda net_was_cross
        bne _nr_pdirty
        lda net_tmp
        cmp ln_h_power
        beq _nr_pdirty
        cmp ln_v_power
        bne _nr_pstore
_nr_pdirty:
        jsr power_mark_dirty
_nr_pstore:
        lda net_cx
        sta city_ptr_x
        lda net_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda net_tmp
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_* = (net_cx, net_cy)
_nr_done:
        rts

; Re-orient the 8 cells around (net_cx, net_cy). All 8 because each cell's
; orientation now depends on its diagonal neighbours too (the parallel-run
; test reads them). net_refresh clobbers X, so the loop index lives in
; net_nidx; net_cx/cy are restored to the original before returning.
net_refresh_neighbors:
        lda net_cx
        sta net_cx_save
        lda net_cy
        sta net_cy_save
        lda #0
        sta net_nidx
_nrn_loop:
        ldx net_nidx
        clc
        lda net_cx_save
        adc net_dx,x
        cmp #CELL_COLS
        bcs _nrn_next
        sta net_cx
        clc
        lda net_cy_save
        adc net_dy,x
        cmp #CELL_ROWS
        bcs _nrn_next
        sta net_cy
        jsr net_refresh
_nrn_next:
        inc net_nidx
        lda net_nidx
        cmp #8
        bne _nrn_loop
        lda net_cx_save
        sta net_cx
        lda net_cy_save
        sta net_cy
        rts

; Carry SET if (net_cx, net_cy) should carry a vertical power crossing. A
; crossing side is a power line OR a zone (a line that gets zoned over still
; feeds the zone, so the crossing stays); bare ground or water is NOT a
; crossing side. If the cell is already a crossing (net_was_cross) it is
; retained as long as neither N nor S is bare; a NEW crossing additionally
; needs at least one actual power line so a plain segment between two zones
; grows no phantom wires. Edge rows have no opposite side.
net_power_ns:
        lda net_cy
        beq _npns_no                ; top edge: no N
        cmp #CELL_ROWS-1
        bcs _npns_no                ; bottom edge: no S
        lda net_cx
        sta city_ptr_x
        lda net_cy
        sec
        sbc #1
        sta city_ptr_y
        jsr net_cross_side_at_ptr   ; 0 bare / 1 zone / 2 power line
        sta net_cross_s1
        beq _npns_no
        lda net_cx
        sta city_ptr_x
        lda net_cy
        clc
        adc #1
        sta city_ptr_y
        jsr net_cross_side_at_ptr
        sta net_cross_s2
        beq _npns_no
        lda net_was_cross           ; already crossing -> retain
        bne _npns_yes
        lda net_cross_s1            ; new crossing -> need >=1 power line
        cmp #2
        beq _npns_yes
        lda net_cross_s2
        cmp #2
        beq _npns_yes
_npns_no:
        clc
        rts
_npns_yes:
        sec
        rts

; Carry SET if (net_cx, net_cy) should carry a horizontal power crossing (E/W),
; same sticky rule as net_power_ns.
net_power_ew:
        lda net_cx
        beq _npew_no                ; left edge: no W
        cmp #CELL_COLS-1
        bcs _npew_no                ; right edge: no E
        lda net_cx
        sec
        sbc #1
        sta city_ptr_x
        lda net_cy
        sta city_ptr_y
        jsr net_cross_side_at_ptr
        sta net_cross_s1
        beq _npew_no
        lda net_cx
        clc
        adc #1
        sta city_ptr_x
        lda net_cy
        sta city_ptr_y
        jsr net_cross_side_at_ptr
        sta net_cross_s2
        beq _npew_no
        lda net_was_cross
        bne _npew_yes
        lda net_cross_s1
        cmp #2
        beq _npew_yes
        lda net_cross_s2
        cmp #2
        beq _npew_yes
_npew_no:
        clc
        rts
_npew_yes:
        sec
        rts

; Classify the cell at (city_ptr_x, city_ptr_y) as a power-crossing side:
; A = 0 none (bare ground / water / non-conductor), 1 = power conductor that
; isn't a wire (zone, police HQ, fire HQ, coal / nuclear plant), 2 = actual
; power line. Conductors count because the wire passes power INTO them, so a
; perpendicular crossing here still connects the network correctly. Preserves X.
net_cross_side_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #POWERLINE_CELL_FIRST
        bcc _ncs_chk_conductor
        cmp #POWERLINE_CELL_LAST+1
        bcs _ncs_chk_conductor
        lda #2                      ; power line / wire
        rts
_ncs_chk_conductor:
        jsr is_zone_value           ; preserves A; SET if any zone cell
        bcs _ncs_conductor
        cmp #POLICE_CELL_FIRST
        bcc _ncs_chk_firestation
        cmp #POLICE_CELL_LAST+1
        bcc _ncs_conductor
_ncs_chk_firestation:
        cmp #FIRESTATION_CELL_FIRST
        bcc _ncs_chk_source
        cmp #FIRESTATION_CELL_LAST+1
        bcc _ncs_conductor
_ncs_chk_source:
        jsr is_power_source_cell    ; structure table: coal / nuclear
        bcs _ncs_conductor
        lda #0                      ; truly bare
        rts
_ncs_conductor:
        lda #1                      ; conductor, but not a wire
        rts
