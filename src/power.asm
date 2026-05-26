;=======================================================================================
; Power propagation.
;
; A zone is powered if it is connected to the coal power plant -- directly along
; power lines, or by touching (orthogonally) the plant, a powered line, or another
; powered zone. This is a flood-fill from the plant over all "power node" cells
; (plant / power line / road-power-crossing / zone), 4-connected.
;
; Result lives in a 1-byte-per-cell "powered" array in Attic (ATTIC_POWER_PHYS):
; 0 = unpowered, 1 = powered. It doubles as the flood's visited marker. The work
; stack of (cx,cy) pairs lives in Attic (ATTIC_PSTACK_PHYS), addressed by the
; zero-page POWER_STACK_PTR. bolt_test_update (sprites.asm) reads this array to
; show the "no power" bolt only over unpowered zones.
;
; Recompute is on-demand: city.asm sets power_dirty whenever the network changes
; (a power line, zone, or plant is placed or bulldozed); power_update runs the
; flood once per frame when dirty. The plant is found by scanning the map, so a
; recompute is O(map) plus O(connected network) -- fine as a per-edit cost.
;=======================================================================================

; Carry SET if map cell value A conducts/holds power: the coal plant (source),
; a power line, a road carrying power across it, or a zone (literal char).
is_power_node:
        cmp #COALPP_CELL_FIRST
        bcc _ipn_line
        cmp #COALPP_CELL_LAST+1
        bcc _ipn_yes                ; coal plant cell (source)
_ipn_line:
        cmp #POWERLINE_CELL_FIRST
        bcc _ipn_cross
        cmp #POWERLINE_CELL_LAST+1
        bcc _ipn_yes                ; power line
_ipn_cross:
        cmp #ROAD_CELL_H_POWER
        beq _ipn_yes                ; road with a power crossing
        cmp #ROAD_CELL_V_POWER
        beq _ipn_yes
        cmp #ZONE_CELL_LITERAL
        bcs _ipn_yes                ; zone cell (bit 7 set)
        clc
        rts
_ipn_yes:
        sec
        rts

; MAP_PTR = ATTIC_POWER_PHYS + (city_ptr_lo/hi). Reuses the cell offset computed
; by the most recent city_cell_ptr, so call this right after one. Overwrites the
; map pointer in MAP_PTR with a pointer into the power array.
power_ptr_into_map:
        clc
        lda #<ATTIC_POWER_PHYS
        adc city_ptr_lo
        sta MAP_PTR
        lda #>ATTIC_POWER_PHYS
        adc city_ptr_hi
        sta MAP_PTR+1
        lda #`ATTIC_POWER_PHYS
        adc #0
        sta MAP_PTR+2
        lda #(ATTIC_POWER_PHYS >> 24)
        adc #0
        sta MAP_PTR+3
        rts

; Push (city_ptr_x, city_ptr_y) onto the Attic flood stack.
power_push:
        lda city_ptr_x
        ldz #0
        sta [POWER_STACK_PTR],z
        lda city_ptr_y
        ldz #1
        sta [POWER_STACK_PTR],z
        clc
        lda POWER_STACK_PTR
        adc #2
        sta POWER_STACK_PTR
        lda POWER_STACK_PTR+1
        adc #0
        sta POWER_STACK_PTR+1
        lda POWER_STACK_PTR+2
        adc #0
        sta POWER_STACK_PTR+2
        inc pstack_count
        bne +
        inc pstack_count+1
+       rts

; Pop the top entry into (flood_cx, flood_cy). Caller guarantees non-empty.
power_pop:
        sec
        lda POWER_STACK_PTR
        sbc #2
        sta POWER_STACK_PTR
        lda POWER_STACK_PTR+1
        sbc #0
        sta POWER_STACK_PTR+1
        lda POWER_STACK_PTR+2
        sbc #0
        sta POWER_STACK_PTR+2
        ldz #0
        lda [POWER_STACK_PTR],z
        sta flood_cx
        ldz #1
        lda [POWER_STACK_PTR],z
        sta flood_cy
        lda pstack_count
        bne +
        dec pstack_count+1
+       dec pstack_count
        rts

; Clear the whole power array to 0 (one DMA fill).
power_clear:
        lda #$00
        sta $D707
        .byte $80, $00              ; src MB (unused by fill)
        .byte $81, ATTIC_POWER_MB   ; dst MB
        .byte $00
        .byte $03                   ; FILL
        .word CELL_MAP_SIZE
        .byte $00, $00              ; fill byte = 0 (src addr lo = fill value)
        .byte $00
        .word ATTIC_POWER_ADDR
        .byte ATTIC_POWER_BANK
        .byte $00
        .word $0000
        rts

; Scan the whole map; for each coal-plant cell, mark it powered and push it as a
; flood seed.
power_seed:
        lda #0
        sta power_sy
_psd_row:
        lda #0
        sta power_sx
_psd_col:
        lda power_sx
        sta city_ptr_x
        lda power_sy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #COALPP_CELL_FIRST
        bcc _psd_next
        cmp #COALPP_CELL_LAST+1
        bcs _psd_next
        ; plant cell -> seed
        jsr power_ptr_into_map
        lda #1
        ldz #0
        sta [MAP_PTR],z
        jsr power_push
_psd_next:
        inc power_sx
        lda power_sx
        cmp #CELL_COLS
        bne _psd_col
        inc power_sy
        lda power_sy
        cmp #CELL_ROWS
        bne _psd_row
        rts

; Flood from the seeded cells: pop, then for each in-bounds 4-neighbour that is a
; power node and not yet powered, mark it powered and push it.
power_flood:
_pf_loop:
        lda pstack_count
        ora pstack_count+1
        beq _pf_done
        jsr power_pop
        lda flood_cy                ; N
        beq _pf_s
        lda flood_cx
        sta city_ptr_x
        lda flood_cy
        sec
        sbc #1
        sta city_ptr_y
        jsr power_try_cell
_pf_s:
        lda flood_cy                ; S
        cmp #CELL_ROWS-1
        bcs _pf_e
        lda flood_cx
        sta city_ptr_x
        lda flood_cy
        clc
        adc #1
        sta city_ptr_y
        jsr power_try_cell
_pf_e:
        lda flood_cx                ; E
        cmp #CELL_COLS-1
        bcs _pf_w
        lda flood_cx
        clc
        adc #1
        sta city_ptr_x
        lda flood_cy
        sta city_ptr_y
        jsr power_try_cell
_pf_w:
        lda flood_cx                ; W
        beq _pf_loop
        lda flood_cx
        sec
        sbc #1
        sta city_ptr_x
        lda flood_cy
        sta city_ptr_y
        jsr power_try_cell
        jmp _pf_loop
_pf_done:
        rts

; Candidate neighbour in (city_ptr_x, city_ptr_y): if it is a power node and not
; already powered, mark it and push it.
power_try_cell:
        jsr city_cell_ptr           ; MAP_PTR = map cell, city_ptr_lo/hi = offset
        ldz #0
        lda [MAP_PTR],z
        jsr is_power_node
        bcc _ptc_no
        jsr power_ptr_into_map      ; MAP_PTR = power[cell] (same offset)
        ldz #0
        lda [MAP_PTR],z
        bne _ptc_no                 ; already powered
        lda #1
        sta [MAP_PTR],z
        jmp power_push              ; push (city_ptr_x, city_ptr_y); tail call
_ptc_no:
        rts

; Full recompute: clear, reset the stack, seed from the plant, flood.
power_recompute:
        jsr power_clear
        lda #<ATTIC_PSTACK_PHYS
        sta POWER_STACK_PTR
        lda #>ATTIC_PSTACK_PHYS
        sta POWER_STACK_PTR+1
        lda #`ATTIC_PSTACK_PHYS
        sta POWER_STACK_PTR+2
        lda #(ATTIC_PSTACK_PHYS >> 24)
        sta POWER_STACK_PTR+3
        lda #0
        sta pstack_count
        sta pstack_count+1
        jsr power_seed
        jmp power_flood

; Called once per frame: recompute the power map if the network changed.
power_update:
        lda power_dirty
        beq _pu_done
        lda #0
        sta power_dirty
        jmp power_recompute
_pu_done:
        rts

; --- state ---
power_dirty:                    ; nonzero -> recompute on the next power_update
        .byte 1                 ; start dirty so the first frame computes it
flood_cx:
        .byte 0
flood_cy:
        .byte 0
power_sx:
        .byte 0
power_sy:
        .byte 0
pstack_count:
        .word 0
