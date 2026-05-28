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

; Seed the flood from the recorded plant origins. For each origin, walk its 12
; cells (3 wide x 4 tall) and push any that are still a plant value. This is
; tolerant of partial bulldozing (only the remaining plant cells seed) and of
; stale list entries (a fully-demolished plant just contributes no seeds).
power_seed:
        lda #0
        sta ps_idx
_psd_loop:
        ldx ps_idx
        cpx plant_origin_count
        bcs _psd_done
        lda #0
        sta ps_seeds                ; live plant cells pushed for this origin
        sta ps_dy
_psd_row:
        lda #0
        sta ps_dx
_psd_col:
        ldx ps_idx
        clc
        lda plant_origin_x,x
        adc ps_dx
        sta city_ptr_x
        clc
        lda plant_origin_y,x
        adc ps_dy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #COALPP_CELL_FIRST
        bcc _psd_next_col
        cmp #COALPP_CELL_LAST+1
        bcs _psd_next_col
        ; plant cell -> mark powered and push as a seed
        jsr power_ptr_into_map
        lda #1
        ldz #0
        sta [MAP_PTR],z
        jsr power_push
        inc ps_seeds
_psd_next_col:
        inc ps_dx
        lda ps_dx
        cmp #COALPP_COLS
        bne _psd_col
        inc ps_dy
        lda ps_dy
        cmp #COALPP_ROWS
        bne _psd_row
        ; Finished this origin's 12 cells. If none were still a plant (fully
        ; bulldozed), drop the entry: swap the last origin into this slot and
        ; decrement the count; the swapped-in entry is then processed at the
        ; same ps_idx on the next iteration. Self-swap when this WAS the last
        ; entry is a harmless no-op write; the cpx check at the top terminates.
        lda ps_seeds
        beq _psd_prune
        inc ps_idx
        jmp _psd_loop
_psd_prune:
        dec plant_origin_count
        ldx plant_origin_count
        ldy ps_idx
        lda plant_origin_x,x
        sta plant_origin_x,y
        lda plant_origin_y,x
        sta plant_origin_y,y
        jmp _psd_loop
_psd_done:
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

; Called once per frame: recompute the power map if the network changed, but
; debounce -- wait until power_settle frames have elapsed with no further edits.
; Each edit calls power_mark_dirty, which resets the settle countdown, so a
; multi-cell drag (power line / bulldoze) triggers exactly one recompute on
; release instead of one per frame.
power_update:
        lda power_dirty
        beq _pu_done
        lda power_settle
        beq _pu_go                  ; countdown elapsed -> recompute now
        dec power_settle
        rts
_pu_go:
        lda #0
        sta power_dirty
        jmp power_recompute
_pu_done:
        rts

; Mark the power network dirty and (re)arm the debounce timer. Called from every
; placement / bulldoze that can affect connectivity (see city.asm, roads.asm).
power_mark_dirty:
        lda #1
        sta power_dirty
        lda #POWER_SETTLE_FRAMES
        sta power_settle
        rts

; Record a newly-placed coal plant's origin so power_seed can find it without
; scanning the whole map. Called from city.asm after city_stamp_coalpp. If the
; tracking list is full (PLANT_MAX origins recorded over the session), the new
; plant is silently dropped from the seed list; partial bulldozing of a plant is
; OK because power_seed re-checks each of its 12 cells per recompute.
power_register_plant:
        ldx plant_origin_count
        cpx #PLANT_MAX
        bcs _prp_full
        lda zone_org_x
        sta plant_origin_x,x
        lda zone_org_y
        sta plant_origin_y,x
        inc plant_origin_count
_prp_full:
        rts

; --- tuning ---
POWER_SETTLE_FRAMES = 4         ; frames of edit-idle before a recompute runs
PLANT_MAX           = 32        ; max distinct plant origins tracked per session

; --- state ---
power_dirty:                    ; nonzero -> recompute pending
        .byte 1                 ; start dirty so the first frame computes it
power_settle:                   ; debounce countdown; reset by power_mark_dirty
        .byte 0
flood_cx:
        .byte 0
flood_cy:
        .byte 0
ps_idx:                         ; power_seed: plant_origin index
        .byte 0
ps_dx:                          ; power_seed: cell-within-plant offsets
        .byte 0
ps_dy:
        .byte 0
ps_seeds:                       ; power_seed: live plant cells found this origin
        .byte 0
pstack_count:
        .word 0
plant_origin_count:
        .byte 0
plant_origin_x:
        .fill PLANT_MAX, 0
plant_origin_y:
        .fill PLANT_MAX, 0
