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

; Carry SET if map cell value A conducts/holds power: a power line, a road
; carrying power across it, any of the 27 zone cells, or any structure tagged
; as a power source (currently coal / nuclear plants). Plant cells go through
; the structure table so adding a new power source is just a table-row flag.
is_power_node:
        cmp #POWERLINE_CELL_FIRST
        bcc _ipn_cross
        cmp #POWERLINE_CELL_LAST+1
        bcc _ipn_yes                ; power line
_ipn_cross:
        cmp #ROAD_CELL_H_POWER
        beq _ipn_yes
        cmp #ROAD_CELL_V_POWER
        beq _ipn_yes                ; road with a power crossing
        jsr is_zone_value           ; any zone cell counts as a power node
        bcs _ipn_yes
        jmp is_power_source_cell    ; structure table: any power-source row
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
        ; Pick up the structure row this origin was registered against. Footprint
        ; dimensions and the cell-value range vary per plant type (coal vs nuclear
        ; today; possibly more later) and live in the structure table.
        lda plant_origin_struct,x
        sta ps_struct
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
        ldy ps_struct
        cmp struct_cell_base,y
        bcc _psd_next_col
        sec
        sbc struct_cell_base,y
        cmp struct_cell_count,y
        bcs _psd_next_col
        ; plant cell still in range -> mark powered and push as a seed
        jsr power_ptr_into_map
        lda #1
        ldz #0
        sta [MAP_PTR],z
        jsr power_push
        inc ps_seeds
_psd_next_col:
        ldy ps_struct
        inc ps_dx
        lda ps_dx
        cmp struct_cols,y
        bne _psd_col
        inc ps_dy
        lda ps_dy
        cmp struct_rows,y
        bne _psd_row
        ; Finished this origin's footprint. If none were still a plant (fully
        ; bulldozed) drop the entry: swap the last origin into this slot and
        ; decrement the count; the swapped-in entry is processed at the same
        ; ps_idx on the next iteration. Self-swap on the last entry is a harmless
        ; no-op; the cpx check at the top terminates.
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
        lda plant_origin_struct,x
        sta plant_origin_struct,y
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

; Full recompute: clear, reset the stack, seed from the plants, flood, then trim
; the powered set to the pooled output capacity so each plant's zone limit (e.g.
; coal=40, nuclear=120) is enforced.
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
        jsr power_sum_capacity
        jsr power_flood
        jmp power_apply_capacity

; Sum every (post-prune) registered plant's struct_output into total_power_capacity.
; All plants on the connected network share one pooled cap; the apply pass below
; trims the powered zone count down to this number.
power_sum_capacity:
        lda #0
        sta total_power_capacity
        sta total_power_capacity+1
        ldx #0
_psc_loop:
        cpx plant_origin_count
        bcs _psc_done
        ldy plant_origin_struct,x
        clc
        lda total_power_capacity
        adc struct_output,y
        sta total_power_capacity
        lda total_power_capacity+1
        adc #0
        sta total_power_capacity+1
        inx
        bra _psc_loop
_psc_done:
        rts

; Raster scan: for each zone TL (residential / commercial / industrial position-0
; cell) check the power array; for each one the flood marked powered, increment a
; running tally and -- once it has exceeded total_power_capacity -- zero the
; zone's 9 power-array cells so the bolt re-appears on it.
;
; Raster order is deterministic but arbitrary (top-left zones keep power, bottom-
; right drop first). See TODO.md "Power plant simulation" for the v2 swap-in:
; record zones in flood order (BFS distance from the plant) and drop the
; farthest-from-plant zones, which feels more SimCity-correct.
power_apply_capacity:
        lda #0
        sta capacity_used
        sta capacity_used+1
        sta pac_cy
_pac_row:
        lda #0
        sta pac_cx
_pac_col:
        lda pac_cx
        sta city_ptr_x
        lda pac_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_zone_origin_value    ; only TL cells -> each zone counted exactly once
        bcc _pac_next_cell
_pac_is_tl:
        jsr power_ptr_into_map      ; reuse the cell offset to read the power array
        ldz #0
        lda [MAP_PTR],z
        beq _pac_next_cell          ; not powered -> flood never reached it
        inc capacity_used
        bne +
        inc capacity_used+1
+
        ; if capacity_used > total_power_capacity, drop this zone.
        sec
        lda total_power_capacity
        sbc capacity_used
        lda total_power_capacity+1
        sbc capacity_used+1
        bcs _pac_next_cell          ; cap >= used: keep this zone powered
        ; over capacity: zero the 3x3 power-array cells of this zone.
        lda pac_cx
        sta pac_tl_x
        lda pac_cy
        sta pac_tl_y
        lda #0
        sta pac_dy
_pac_drop_row:
        lda #0
        sta pac_dx
_pac_drop_col:
        clc
        lda pac_tl_x
        adc pac_dx
        sta city_ptr_x
        clc
        lda pac_tl_y
        adc pac_dy
        sta city_ptr_y
        jsr city_cell_ptr
        jsr power_ptr_into_map
        lda #0
        ldz #0
        sta [MAP_PTR],z
        inc pac_dx
        lda pac_dx
        cmp #ZONE_SIZE
        bne _pac_drop_col
        inc pac_dy
        lda pac_dy
        cmp #ZONE_SIZE
        bne _pac_drop_row
_pac_next_cell:
        inc pac_cx
        lda pac_cx
        cmp #CELL_COLS
        bne _pac_col
        inc pac_cy
        lda pac_cy
        cmp #CELL_ROWS
        bne _pac_row
        rts

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

; Record a newly-placed plant's origin and which structure row it belongs to so
; power_seed can find it without scanning the whole map. Called from cps_structure
; after stamping, with struct_idx already set to the placed row. If the tracking
; list is full (PLANT_MAX entries this session) the new plant is silently dropped
; from the seed list; partial bulldozing is OK because power_seed re-reads each
; footprint cell per recompute and prunes fully-demolished entries.
power_register_plant:
        ldx plant_origin_count
        cpx #PLANT_MAX
        bcs _prp_full
        lda zone_org_x
        sta plant_origin_x,x
        lda zone_org_y
        sta plant_origin_y,x
        lda struct_idx
        sta plant_origin_struct,x
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
plant_origin_struct:            ; struct table index per origin (coal vs nuclear, ...)
        .fill PLANT_MAX, 0
ps_struct:                      ; power_seed: structure row for the current origin
        .byte 0
total_power_capacity:           ; summed struct_output across all registered plants
        .word 0
capacity_used:                  ; powered zones tallied so far by power_apply_capacity
        .word 0
pac_cx:                         ; power_apply_capacity raster-scan cursor
        .byte 0
pac_cy:
        .byte 0
pac_tl_x:                       ; saved zone-TL coords while zeroing the 3x3 footprint
        .byte 0
pac_tl_y:
        .byte 0
pac_dx:                         ; 3x3 footprint loop counters for zone zero-out
        .byte 0
pac_dy:
        .byte 0
