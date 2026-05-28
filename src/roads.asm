;=======================================================================================
; Road auto-tiling.
;
; Roads are 1x1 cells whose tile is chosen from their road neighbours. The paint
; path (city.asm) writes a placeholder road cell into (road_cx, road_cy) and calls
; road_refresh / road_refresh_neighbors; this module decides the orientation,
; stores it as the cell value (ROAD_CELL_*, see platform.asm), and redraws via
; render_redraw_cell_tile. It reaches the map through city_cell_ptr and the
; shared scratch city_ptr_x/y (city.asm).
;=======================================================================================

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
        jsr road_at_ptr             ; A = cell value, carry set if a road
        bcc _rr_done
        ; remember whether this road is already a power crossing: a crossing is
        ; sticky and stays crossed unless bare ground (or water) ends up beside it.
        ldx #0
        cmp #ROAD_CELL_H_POWER
        beq _rr_wascross
        cmp #ROAD_CELL_V_POWER
        bne _rr_wasdone
_rr_wascross:
        inx
_rr_wasdone:
        stx road_was_cross
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
        ; pure horizontal road: a vertical power line crosses it if power sits on
        ; both the N and S sides (only straight roads cross -- see road_power_ns).
        jsr road_power_ns
        bcc _rr_h_plain
        lda #ROAD_CELL_H_POWER
        bra _rr_store
_rr_h_plain:
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
        ; pure vertical road: a horizontal power line crosses it if power sits on
        ; both the E and W sides.
        jsr road_power_ew
        bcc _rr_v_plain
        lda #ROAD_CELL_V_POWER
        bra _rr_store
_rr_v_plain:
        lda #ROAD_CELL_V
_rr_store:
        sta road_tmp
        ; A power crossing being created or removed changes the power network.
        lda road_was_cross
        bne _rr_pdirty
        lda road_tmp
        cmp #ROAD_CELL_H_POWER
        beq _rr_pdirty
        cmp #ROAD_CELL_V_POWER
        bne _rr_pstore
_rr_pdirty:
        jsr power_mark_dirty
_rr_pstore:
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

; Carry SET if (road_cx, road_cy) should carry a vertical power crossing. A
; crossing side is a power line OR a zone (a line that gets zoned over still feeds
; the zone, so the crossing stays); bare ground or water is NOT a crossing side.
; If the road is already a crossing (road_was_cross) it is retained as long as
; neither N nor S is bare; a NEW crossing additionally needs at least one actual
; power line so a plain road between two zones grows no phantom wires. Edge rows
; have no opposite side. Clobbers city_ptr_x/y (road_refresh re-seeds them).
road_power_ns:
        lda road_cy
        beq _rpns_no                ; top edge: no N
        cmp #CELL_ROWS-1
        bcs _rpns_no                ; bottom edge: no S
        lda road_cx
        sta city_ptr_x
        lda road_cy
        sec
        sbc #1
        sta city_ptr_y
        jsr road_cross_side_at_ptr  ; 0 bare / 1 zone / 2 power line
        sta road_cross_s1
        beq _rpns_no                ; bare ground/water beside -> no crossing
        lda road_cx
        sta city_ptr_x
        lda road_cy
        clc
        adc #1
        sta city_ptr_y
        jsr road_cross_side_at_ptr
        sta road_cross_s2
        beq _rpns_no
        lda road_was_cross          ; already crossing -> retain
        bne _rpns_yes
        lda road_cross_s1           ; new crossing -> need >=1 power line
        cmp #2
        beq _rpns_yes
        lda road_cross_s2
        cmp #2
        beq _rpns_yes
_rpns_no:
        clc
        rts
_rpns_yes:
        sec
        rts

; Carry SET if (road_cx, road_cy) should carry a horizontal power crossing (E/W),
; same sticky rule as road_power_ns.
road_power_ew:
        lda road_cx
        beq _rpew_no                ; left edge: no W
        cmp #CELL_COLS-1
        bcs _rpew_no                ; right edge: no E
        lda road_cx
        sec
        sbc #1
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr road_cross_side_at_ptr
        sta road_cross_s1
        beq _rpew_no
        lda road_cx
        clc
        adc #1
        sta city_ptr_x
        lda road_cy
        sta city_ptr_y
        jsr road_cross_side_at_ptr
        sta road_cross_s2
        beq _rpew_no
        lda road_was_cross          ; already crossing -> retain
        bne _rpew_yes
        lda road_cross_s1
        cmp #2
        beq _rpew_yes
        lda road_cross_s2
        cmp #2
        beq _rpew_yes
_rpew_no:
        clc
        rts
_rpew_yes:
        sec
        rts

; Classify the cell at (city_ptr_x, city_ptr_y) as a power-crossing side:
; A = 0 none, 1 = zone (a line may run into a zone), 2 = power line. Preserves X.
road_cross_side_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #POWERLINE_CELL_FIRST
        bcc _rcs_chkzone
        cmp #POWERLINE_CELL_LAST+1
        bcs _rcs_chkzone
        lda #2                      ; power line
        rts
_rcs_chkzone:
        cmp #ZONE_CELL_LITERAL      ; bit 7 set -> zone literal
        bcc _rcs_none
        lda #1                      ; zone
        rts
_rcs_none:
        lda #0
        rts

; --- work vars ---
road_cx:                        ; cell being (re)oriented; set by the paint path
        .byte 0
road_cy:
        .byte 0
road_cx_save:
        .byte 0
road_cy_save:
        .byte 0
road_mask:                      ; refined N/S/E/W connection bits
        .byte 0
road_raw:                       ; raw 8-neighbour road bits
        .byte 0
road_nidx:                      ; road_refresh_neighbors loop index
        .byte 0
road_tmp:
        .byte 0
road_cross_s1:                  ; road_power_ns/ew: the two perpendicular sides
        .byte 0
road_cross_s2:
        .byte 0
road_was_cross:                 ; 1 if the cell is already a power crossing (sticky)
        .byte 0
