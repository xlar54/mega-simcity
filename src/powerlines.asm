;=======================================================================================
; Power-line auto-tiling.
;
; Power lines are 1x1 cells whose tile is chosen from their power-line neighbours,
; exactly like roads (see roads.asm): horizontal or vertical wires that follow the
; run direction. There are no curves. A cell that sits at a genuine intersection
; (wires cross on both axes) is promoted to a "pole" cell, which renders as a +
; crossing of both wire pairs. Poles are sticky -- once a cell is a pole it stays
; one when later re-oriented -- and only demote back to a plain line when the
; intersection is dismantled. (An older cosmetic "every Nth placement is a pole"
; cadence has been removed; intersections are the only source now.)
;
; As with roads, a perpendicular neighbour that is merely a parallel line running
; alongside (revealed by the diagonals) is ignored, so two adjacent parallel power
; lines stay straight instead of every cell turning into an intersection pole.
;
; The paint path (city.asm) writes a placeholder line/pole into (powerline_cx,
; powerline_cy) and calls powerline_refresh / powerline_refresh_neighbors; this
; module decides the orientation, stores the cell value (POWERLINE_CELL_*, see
; platform.asm) and redraws via render_redraw_cell_tile. It reaches the map through
; city_cell_ptr and the shared scratch city_ptr_x/y (city.asm).
;=======================================================================================

; Carry SET if cell value A is a power line (any orientation / pole).
is_powerline_value:
        cmp #POWERLINE_CELL_FIRST
        bcc _iplv_no
        cmp #POWERLINE_CELL_LAST+1
        bcs _iplv_no
        sec
        rts
_iplv_no:
        clc
        rts

; Carry SET if A is a power line OR a power-line bridge over water. Used by the
; power-tool bridge-placement adjacency check so a new bridge cell can anchor
; to either a land-side wire/pole or to another bridge of its own type.
; Preserves A.
is_power_line_or_bridge:
        jsr is_powerline_value
        bcs _ipob_yes
        cmp #POWER_BRIDGE_CELL_FIRST
        bcc _ipob_no
        cmp #POWER_BRIDGE_CELL_LAST+1
        bcs _ipob_no
_ipob_yes:
        sec
        rts
_ipob_no:
        clc
        rts

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is a power line.
; Preserves X (city_cell_ptr does not touch it), so the neighbour scan can use it.
powerline_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jmp is_powerline_value

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it forms a power
; connection toward neighbour-direction index X (0..7, the powerline_dx order).
; A real power line connects in any direction; a road/power crossing tile only
; connects along its wire axis, and only to the cardinal neighbour on that axis
; (ROAD_CELL_H_POWER carries vertical wires -> feeds the N/S neighbour;
; ROAD_CELL_V_POWER carries horizontal wires -> the E/W neighbour). Preserves X.
powerline_conn_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #POWERLINE_CELL_FIRST
        bcc _pcap_cross
        cmp #POWERLINE_CELL_LAST+1
        bcc _pcap_yes               ; real power line: any direction
_pcap_cross:
        cmp #ROAD_CELL_H_POWER
        beq _pcap_vert
        cmp #ROAD_CELL_V_POWER
        beq _pcap_horiz
        clc
        rts
_pcap_vert:
        cpx #1                      ; N
        beq _pcap_yes
        cpx #6                      ; S
        beq _pcap_yes
        clc
        rts
_pcap_horiz:
        cpx #3                      ; W
        beq _pcap_yes
        cpx #4                      ; E
        beq _pcap_yes
        clc
        rts
_pcap_yes:
        sec
        rts

; Read the cell at (city_ptr_x, city_ptr_y); carry SET if it is a "structure" a
; power line points toward -- any of the 27 zone cells or any row in the
; structure table (coal / nuclear / future buildings). Used to orient an
; isolated line between two facing structures.
is_structure_at_ptr:
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_zone_value           ; any of the 27 zone cells counts
        bcs _isa_yes
        jmp is_structure_cell       ; otherwise: structure table
_isa_yes:
        sec
        rts

; Carry SET if a structure sits on BOTH the N and S of (powerline_cx, powerline_cy).
powerline_struct_ns:
        lda powerline_cy
        beq _psns_no
        cmp #CELL_ROWS-1
        bcs _psns_no
        lda powerline_cx
        sta city_ptr_x
        lda powerline_cy
        sec
        sbc #1
        sta city_ptr_y
        jsr is_structure_at_ptr
        bcc _psns_no
        lda powerline_cx
        sta city_ptr_x
        lda powerline_cy
        clc
        adc #1
        sta city_ptr_y
        jsr is_structure_at_ptr
        bcc _psns_no
        sec
        rts
_psns_no:
        clc
        rts

; Carry SET if a structure sits on BOTH the E and W of (powerline_cx, powerline_cy).
powerline_struct_ew:
        lda powerline_cx
        beq _psew_no
        cmp #CELL_COLS-1
        bcs _psew_no
        lda powerline_cx
        sec
        sbc #1
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr is_structure_at_ptr
        bcc _psew_no
        lda powerline_cx
        clc
        adc #1
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr is_structure_at_ptr
        bcc _psew_no
        sec
        rts
_psew_no:
        clc
        rts

; Offsets for the 8 surrounding cells, order NW,N,NE,W,E,SW,S,SE. (dx/dy are
; signed; cmp against CELL_COLS/ROWS rejects both underflow and overflow at the
; edges.) The bits reuse the generic ROAD_BIT_* direction flags from platform.asm.
powerline_dx:  .byte $FF,$00,$01,$FF,$01,$FF,$00,$01
powerline_dy:  .byte $FF,$FF,$FF,$00,$00,$01,$01,$01
powerline_bit: .byte ROAD_BIT_NW,ROAD_BIT_N,ROAD_BIT_NE,ROAD_BIT_W,ROAD_BIT_E,ROAD_BIT_SW,ROAD_BIT_S,ROAD_BIT_SE

; Re-orient and redraw the power-line cell at (powerline_cx, powerline_cy). No-op
; if not a power line. Scans all 8 neighbours into powerline_raw, drops parallel
; runs (same rule as roads), then picks line/pole + orientation.
powerline_refresh:
        lda powerline_cx
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_powerline_value          ; preserves A
        bcc _plr_done
        ; sticky pole: was this cell already a pole?
        ldx #0
        cmp #POWERLINE_CELL_POLE_H
        beq _plr_is_pole
        cmp #POWERLINE_CELL_POLE_V
        bne _plr_scan
_plr_is_pole:
        ldx #1
_plr_scan:
        stx powerline_pole
        lda #0
        sta powerline_isx
        sta powerline_raw
        ldx #0
_plr_gather:
        clc
        lda powerline_cx
        adc powerline_dx,x
        cmp #CELL_COLS
        bcs _plr_gnext              ; off map (under/overflow)
        sta city_ptr_x
        clc
        lda powerline_cy
        adc powerline_dy,x
        cmp #CELL_ROWS
        bcs _plr_gnext
        sta city_ptr_y
        jsr powerline_conn_at_ptr   ; preserves X; crossing tiles count on-axis
        bcc _plr_gnext
        lda powerline_raw
        ora powerline_bit,x
        sta powerline_raw
_plr_gnext:
        inx
        cpx #8
        bne _plr_gather

        ; refined connections start from the raw N/S/E/W
        lda powerline_raw
        and #(ROAD_BIT_N|ROAD_BIT_S|ROAD_BIT_E|ROAD_BIT_W)
        sta powerline_mask
        ; horizontal run (E&W)? drop a N/S neighbour that is itself horizontal
        ; (its own E and W are lines -> our diagonals NE/NW or SE/SW)
        lda powerline_raw
        and #(ROAD_BIT_E|ROAD_BIT_W)
        cmp #(ROAD_BIT_E|ROAD_BIT_W)
        bne _plr_chk_vert
        lda powerline_raw
        and #(ROAD_BIT_NE|ROAD_BIT_NW)
        cmp #(ROAD_BIT_NE|ROAD_BIT_NW)
        bne _plr_chk_drops
        lda powerline_mask
        and #(255-ROAD_BIT_N)
        sta powerline_mask
_plr_chk_drops:
        lda powerline_raw
        and #(ROAD_BIT_SE|ROAD_BIT_SW)
        cmp #(ROAD_BIT_SE|ROAD_BIT_SW)
        bne _plr_chk_vert
        lda powerline_mask
        and #(255-ROAD_BIT_S)
        sta powerline_mask
_plr_chk_vert:
        ; vertical run (N&S)? drop an E/W neighbour that is itself vertical
        lda powerline_raw
        and #(ROAD_BIT_N|ROAD_BIT_S)
        cmp #(ROAD_BIT_N|ROAD_BIT_S)
        bne _plr_decide
        lda powerline_raw
        and #(ROAD_BIT_NE|ROAD_BIT_SE)
        cmp #(ROAD_BIT_NE|ROAD_BIT_SE)
        bne _plr_chk_dropw
        lda powerline_mask
        and #(255-ROAD_BIT_E)
        sta powerline_mask
_plr_chk_dropw:
        lda powerline_raw
        and #(ROAD_BIT_NW|ROAD_BIT_SW)
        cmp #(ROAD_BIT_NW|ROAD_BIT_SW)
        bne _plr_decide
        lda powerline_mask
        and #(255-ROAD_BIT_W)
        sta powerline_mask
_plr_decide:
        ; No power-line connections? Orient an isolated line by structures (zones
        ; or the plant) sitting on two opposite sides: between two stacked zones it
        ; runs vertical, between two side-by-side zones horizontal. A line already
        ; wired to other lines (mask != 0) keeps that orientation, so a line running
        ; alongside a single zone is unaffected.
        lda powerline_mask
        bne _plr_dec_go
        jsr powerline_struct_ns
        bcc _plr_dec_ew
        lda #(ROAD_BIT_N|ROAD_BIT_S)
        sta powerline_mask
        bra _plr_dec_go
_plr_dec_ew:
        jsr powerline_struct_ew
        bcc _plr_dec_go
        lda #(ROAD_BIT_E|ROAD_BIT_W)
        sta powerline_mask
_plr_dec_go:
        ; vertical orientation if any N/S connection; an intersection (also E/W)
        ; forces a pole. Otherwise horizontal (includes the isolated case).
        ; At a true 4-way crossing we always pick POLE_H -- the cross bitmap is
        ; rotation-symmetric so POLE_V is redundant. Keeping the one variant
        ; frees POLE_V's char slot (27) for popup-button art.
        lda powerline_mask
        and #(ROAD_BIT_N|ROAD_BIT_S)
        beq _plr_horizontal
        lda powerline_mask
        and #(ROAD_BIT_E|ROAD_BIT_W)
        beq _plr_vert
        lda #1
        sta powerline_pole          ; intersection -> pole
        sta powerline_isx           ; ...and protected from demotion
        lda #POWERLINE_CELL_POLE_H  ; explicit: intersections always use POLE_H
        bra _plr_store
_plr_vert:
        lda powerline_pole
        beq _plr_v_line
        lda #POWERLINE_CELL_POLE_H  ; ex-intersection that's now vertical-only
        bra _plr_store
_plr_v_line:
        lda #POWERLINE_CELL_V
        bra _plr_store
_plr_horizontal:
        lda powerline_pole
        beq _plr_h_line
        lda #POWERLINE_CELL_POLE_H
        bra _plr_store
_plr_h_line:
        lda #POWERLINE_CELL_H
_plr_store:
        sta powerline_tmp
        ; Intersections always stay poles. A non-intersection pole demotes to a
        ; plain line if it sits next to a pole that outranks it (any adjacent
        ; intersection, or an equal pole to the N or W), so two adjacent poles
        ; collapse to one pole + one line.
        lda powerline_isx
        bne _plr_write
        lda powerline_tmp
        cmp #POWERLINE_CELL_POLE_V
        beq _plr_maybe_demote
        cmp #POWERLINE_CELL_POLE_H
        bne _plr_write
_plr_maybe_demote:
        jsr powerline_should_demote
        bcc _plr_write
        lda powerline_tmp
        cmp #POWERLINE_CELL_POLE_V
        bne _plr_demote_h
        lda #POWERLINE_CELL_V
        sta powerline_tmp
        bra _plr_write
_plr_demote_h:
        lda #POWERLINE_CELL_H
        sta powerline_tmp
_plr_write:
        lda powerline_cx
        sta city_ptr_x
        lda powerline_cy
        sta city_ptr_y
        jsr city_cell_ptr
        lda powerline_tmp
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_* = (powerline_cx, powerline_cy)
_plr_done:
        rts

; Re-orient the 8 cells around (powerline_cx, powerline_cy). All 8 because the
; parallel-run test reads the diagonals. powerline_refresh clobbers X, so the loop
; index lives in powerline_nidx.
powerline_refresh_neighbors:
        lda powerline_cx
        sta powerline_cx_save
        lda powerline_cy
        sta powerline_cy_save
        lda #0
        sta powerline_nidx
_plrn_loop:
        ldx powerline_nidx
        clc
        lda powerline_cx_save
        adc powerline_dx,x
        cmp #CELL_COLS
        bcs _plrn_next
        sta powerline_cx
        clc
        lda powerline_cy_save
        adc powerline_dy,x
        cmp #CELL_ROWS
        bcs _plrn_next
        sta powerline_cy
        jsr powerline_refresh
_plrn_next:
        inc powerline_nidx
        lda powerline_nidx
        cmp #8
        bne _plrn_loop
        lda powerline_cx_save
        sta powerline_cx
        lda powerline_cy_save
        sta powerline_cy
        rts

; Carry SET if the pole at (powerline_cx, powerline_cy) should demote to a plain
; line. It demotes when:
;   - an on-axis road crossing is adjacent (a road carrying this line's wires --
;     ROAD_CELL_H_POWER above/below, ROAD_CELL_V_POWER left/right -- so the line
;     runs into the crossing as plain wires, not a pole jammed against the road);
;   - any adjacent intersection (always a pole) outranks it; or
;   - for two equal non-intersection poles, a pole on its N or W side -- so exactly
;     one of an adjacent pair stays a pole.
; Clobbers city_ptr_x/y, X, Z, pl_chk_x/y.
powerline_should_demote:
        ; N neighbour: on-axis crossing or any pole outranks
        lda powerline_cy
        beq _psd_skipn
        lda powerline_cx
        sta pl_chk_x
        lda powerline_cy
        sec
        sbc #1
        sta pl_chk_y
        jsr powerline_val_at_chk
        cmp #ROAD_CELL_H_POWER
        beq _psd_yes
        jsr powerline_pole_class
        cmp #2
        beq _psd_yes
        cmp #1
        beq _psd_yes
_psd_skipn:
        ; W neighbour: on-axis crossing or any pole outranks
        lda powerline_cx
        beq _psd_skipw
        lda powerline_cx
        sec
        sbc #1
        sta pl_chk_x
        lda powerline_cy
        sta pl_chk_y
        jsr powerline_val_at_chk
        cmp #ROAD_CELL_V_POWER
        beq _psd_yes
        jsr powerline_pole_class
        cmp #2
        beq _psd_yes
        cmp #1
        beq _psd_yes
_psd_skipw:
        ; S neighbour: on-axis crossing, or an intersection, outranks
        lda powerline_cy
        cmp #CELL_ROWS-1
        bcs _psd_skips
        lda powerline_cx
        sta pl_chk_x
        lda powerline_cy
        clc
        adc #1
        sta pl_chk_y
        jsr powerline_val_at_chk
        cmp #ROAD_CELL_H_POWER
        beq _psd_yes
        jsr powerline_pole_class
        cmp #2
        beq _psd_yes
_psd_skips:
        ; E neighbour: on-axis crossing, or an intersection, outranks
        lda powerline_cx
        cmp #CELL_COLS-1
        bcs _psd_no
        lda powerline_cx
        clc
        adc #1
        sta pl_chk_x
        lda powerline_cy
        sta pl_chk_y
        jsr powerline_val_at_chk
        cmp #ROAD_CELL_V_POWER
        beq _psd_yes
        jsr powerline_pole_class
        cmp #2
        beq _psd_yes
_psd_no:
        clc
        rts
_psd_yes:
        sec
        rts

; Read and return (in A) the cell value at (pl_chk_x, pl_chk_y). Preserves X.
powerline_val_at_chk:
        lda pl_chk_x
        sta city_ptr_x
        lda pl_chk_y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        rts

; Classify the cell at (pl_chk_x, pl_chk_y): A = 0 not a pole, 1 non-intersection
; pole, 2 intersection pole (power connects on both axes). Clobbers city_ptr_x/y,
; X, Z. Connectivity uses powerline_conn_at_ptr, so a crossing tile counts on-axis.
powerline_pole_class:
        lda pl_chk_x
        sta city_ptr_x
        lda pl_chk_y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #POWERLINE_CELL_POLE_H
        beq _ppc_pole
        cmp #POWERLINE_CELL_POLE_V
        beq _ppc_pole
        lda #0
        rts
_ppc_pole:
        lda #0
        sta pl_class_v
        sta pl_class_h
        lda pl_chk_y                ; N
        beq _ppc_s
        lda pl_chk_x
        sta city_ptr_x
        lda pl_chk_y
        sec
        sbc #1
        sta city_ptr_y
        ldx #1
        jsr powerline_conn_at_ptr
        bcc _ppc_s
        lda #1
        sta pl_class_v
_ppc_s:
        lda pl_chk_y                ; S
        cmp #CELL_ROWS-1
        bcs _ppc_e
        lda pl_chk_x
        sta city_ptr_x
        lda pl_chk_y
        clc
        adc #1
        sta city_ptr_y
        ldx #6
        jsr powerline_conn_at_ptr
        bcc _ppc_e
        lda #1
        sta pl_class_v
_ppc_e:
        lda pl_chk_x                ; E
        cmp #CELL_COLS-1
        bcs _ppc_w
        lda pl_chk_x
        clc
        adc #1
        sta city_ptr_x
        lda pl_chk_y
        sta city_ptr_y
        ldx #4
        jsr powerline_conn_at_ptr
        bcc _ppc_w
        lda #1
        sta pl_class_h
_ppc_w:
        lda pl_chk_x                ; W
        beq _ppc_decide
        lda pl_chk_x
        sec
        sbc #1
        sta city_ptr_x
        lda pl_chk_y
        sta city_ptr_y
        ldx #3
        jsr powerline_conn_at_ptr
        bcc _ppc_decide
        lda #1
        sta pl_class_h
_ppc_decide:
        lda pl_class_v
        and pl_class_h
        beq _ppc_one                ; not both axes -> non-intersection pole
        lda #2
        rts
_ppc_one:
        lda #1
        rts

; --- work vars ---
powerline_cx:                   ; cell being (re)oriented; set by the paint path
        .byte 0
powerline_cy:
        .byte 0
powerline_cx_save:
        .byte 0
powerline_cy_save:
        .byte 0
powerline_mask:                 ; refined N/S/E/W connection bits
        .byte 0
powerline_raw:                  ; raw 8-neighbour power-line bits
        .byte 0
powerline_pole:                 ; nonzero if this cell should render as a pole
        .byte 0
powerline_isx:                  ; nonzero if this cell is an intersection pole
        .byte 0
powerline_nidx:                 ; powerline_refresh_neighbors loop index
        .byte 0
powerline_tmp:
        .byte 0
pl_chk_x:                       ; scratch cell for the pole-adjacency checks
        .byte 0
pl_chk_y:
        .byte 0
pl_class_v:                     ; pole_class: vertical / horizontal axis connected
        .byte 0
pl_class_h:
        .byte 0
