;=======================================================================================
; Population counter and growth simulation.
;
; Each residential zone is registered on placement (zone_register_residential)
; with its TL origin cell coords. Per-zone population starts at 0 and grows
; once per in-game month, contingent on three checks:
;
;   1. Powered    -- the origin cell is marked in the Attic power-flood result.
;   2. Has jobs   -- commercial_count + industrial_count > 0 anywhere on the
;                    map (any C or I zone exists). V1: a global flag, not a
;                    per-zone reachability search through the road network.
;   3. Road-adjacent -- at least one of the 12 perimeter cells around the 3x3
;                       footprint is a ROAD_CELL_* or a rail+road crossing.
;
; If all three pass, zone_pop[X] += POP_GROWTH_PER_MONTH (clamped at
; ZONE_POP_MAX). The total `population` (the 24-bit chrome readout) is the
; sum of zone_pop[*], recomputed after each monthly tick / bulldoze.
;
; Bulldozing the origin cell of a residential zone removes it from the
; registry (swap-and-pop), drops zone_pop to 0, and triggers a re-sum.
; Partial demolitions (bulldozing a non-origin cell of a 3x3 zone) leave the
; zone in the registry -- the zone is then "broken" but its population stays
; counted. Acceptable for v1; the proper fix is to also re-check power
; flooding after any zone-cell demo, which already happens via the existing
; power_mark_dirty path on bulldoze.
;
; All resident: zone registry caps at ZONE_POP_MAX_COUNT slots (640 bytes of
; bank-0 RAM at ZONE_POP_MAX_COUNT = 128). Sized to comfortably exceed any
; expected city size; trip the .cerror guard if not.
;=======================================================================================

ZONE_POP_MAX_COUNT      = 128   ; max registered residential zones (also caps C and I)
POP_GROWTH_PER_MONTH    = 40    ; people added per residential zone per growing month
ZONE_POP_MAX            = 1000  ; per-residential-zone ceiling

; --- Industrial growth ---
; Industrial zones grow a bit faster than residential (the user's design rule
; "lots of people work here"). Per-cell evolution mirrors the residential
; system: corners develop first via low base thresholds + per-zone jitter +
; the same road-adjacency bonus.
IND_GROWTH_PER_MONTH    = 40    ; dev added per industrial zone per growing month
IND_DEV_MAX             = 1000  ; per-industrial-zone ceiling

; --- Commercial growth ---
; C zones grow slower than residential (supply trails demand: there have to
; be people in town before shops bother showing up). Two gates:
;   * Total city population must be at least MIN_POP_FOR_COMMERCIAL before
;     any C zone grows at all -- "shops don't open without customers".
;   * Growth rate per month is below residential, so even after the gate
;     opens commercial trails the residential build-out.
; Bonuses still applied per cell:
;   * Closer to residential -> faster (people shop near home).
;   * Nearby police         -> faster (commercial likes feeling safe).
COM_GROWTH_PER_MONTH    = 20    ; dev added per commercial zone per growing month
COM_DEV_MAX             = 1000
MIN_POP_FOR_COMMERCIAL  = 50    ; total city pop required before C zones grow

; --- Emergency-services bonus (police + fire) ---
; Each police HQ or fire-department HQ within EMERGENCY_RADIUS Manhattan
; cells of a zone subtracts EMERGENCY_BONUS_STEP from that cell's effective
; house threshold (clamped to >= 0), so growth crosses the threshold sooner.
; Applies to R, C, and I zones uniformly -- a neighborhood with emergency
; services nearby develops faster regardless of type.
;
; Radius is 10 cells (Manhattan), matching the displayed 10-cell rule in the
; manual. Bonus step is calibrated so 1 nearby HQ is a modest speedup and 2
; stacked services (police AND fire within range) is noticeable.
EMERGENCY_RADIUS        = 10
EMERGENCY_BONUS_STEP    = 60
; Legacy aliases kept so any existing comments / debug code still resolves.
POLICE_RADIUS           = EMERGENCY_RADIUS
POLICE_BONUS_STEP       = EMERGENCY_BONUS_STEP

; --- Traffic ---
; Per road-cell traffic level (0..TRAFFIC_LEVEL_MAX), recomputed at the
; monthly tick by traffic_recompute (counts R + C + I origins within
; TRAFFIC_RADIUS Manhattan cells of each road cell, clamped). The render
; path reads it from Attic to vary the animated-car phase threshold so
; busy corridors animate cars more often than rural roads.
;
; Zones perceive their local traffic by sampling the road cells immediately
; adjacent to their footprint -- a 3x3 zone with all 4 cardinal road sides
; busy "feels" max traffic. zad_zone_traffic in [0..TRAFFIC_LEVEL_MAX]
; folds into both a per-cell threshold penalty (slower zone development)
; and a per-zone decay above TRAFFIC_DECAY_LEVEL (people / dev actually
; pack up and leave -- "urban decay").
TRAFFIC_RADIUS          = 8     ; Manhattan; each in-range origin adds 1 to level
TRAFFIC_LEVEL_MAX       = 4     ; matches TRAFFIC_ROAD_PHASE_COUNT in the renderer
TRAFFIC_PENALTY_STEP    = 60    ; threshold add per zone-traffic level
TRAFFIC_DECAY_LEVEL     = 3     ; perceived level at which growth flips to decay
POP_DECAY_PER_MONTH     = 25    ; pop lost per month for an over-trafficked R zone
COM_DECAY_PER_MONTH     = 30    ; dev lost per month for an over-trafficked C zone
IND_DECAY_PER_MONTH     = 30    ; dev lost per month for an over-trafficked I zone

; --- Pollution ---
; Each industrial zone within POLLUTION_RADIUS Manhattan cells of a residential
; zone counts as a pollution source for that R zone. Beyond
; POLLUTION_GRACE such sources, the residential zone's per-cell thresholds
; receive POLLUTION_PENALTY_STEP added per extra source -- so a few I zones
; nearby is fine ("light industrial neighborhood"), but a wall of them across
; the street pushes the high-threshold cells (edges / center) past
; ZONE_POP_MAX, leaving the R zone permanently sparse.
POLLUTION_RADIUS         = 20
POLLUTION_GRACE          = 1
POLLUTION_PENALTY_STEP   = 50
; Per-cell development thresholds live in thresh_house_*/thresh_apt_* below.
; Each of the 9 cells in a zone has its own pair of (house, apartment)
; thresholds, so the zone develops gradually -- one cell at a time -- as
; pop grows, instead of flipping all 9 cells at a single zone-wide threshold.

POP_ROW       = 1               ; first status-strip row, under FUNDS row 0
POP_COL_ICON  = 30
POP_COL_MIL   = 31
POP_COL_HT    = 32
POP_COL_TT    = 33
POP_COL_T     = 34
POP_COL_H     = 35
POP_COL_TE    = 36
POP_COL_U     = 37

;---------------------------------------------------------------------------------------
; Public API
;---------------------------------------------------------------------------------------

population_init:
        lda #0
        sta population
        sta population+1
        sta population+2
        sta zone_org_count
        sta commercial_count
        sta industrial_count
        sta police_count
        sta firestation_count
        sta zad_nearby_ind
        sta zad_nearby_emergency
        lda #1
        sta pop_display_dirty
        rts

; Add the residential zone at (zone_org_x, zone_org_y) to the registry, with
; initial pop 0. No-op silently if the registry is full. Caller is cps_zone
; right after a successful residential placement.
population_register_residential:
        ldx zone_org_count
        cpx #ZONE_POP_MAX_COUNT
        bcs _prr_full
        lda zone_org_x
        sta zone_org_x_arr,x
        lda zone_org_y
        sta zone_org_y_arr,x
        lda #0
        sta zone_pop_lo_arr,x
        sta zone_pop_hi_arr,x
        ; Per-zone random seed: XOR a few uncorrelated runtime values. This is
        ; the only "randomness" source in the development model -- it varies
        ; with when (clock_frames) and where (zone_org_*) the player drops the
        ; zone, so no two zones get identical per-cell jitter patterns.
        lda clock_frames
        eor clock_frames+1
        eor zone_org_x
        eor zone_org_y
        sta zone_rand_arr,x
        inc zone_org_count
        ; New zone starts at pop 0, so the total is unchanged -- no display
        ; refresh needed. Growth will mark dirty at the next monthly tick.
_prr_full:
        rts

; Remove the zone whose origin matches (road_cx, road_cy). Caller is the
; bulldoze single-cell path right after deciding the cell is a residential
; origin. Swap-and-pop the entry, then re-sum the total.
population_unregister_residential:
        ldx #0
_pur_loop:
        cpx zone_org_count
        bcs _pur_done                  ; not found -> defensive no-op
        lda zone_org_x_arr,x
        cmp road_cx
        bne _pur_next
        lda zone_org_y_arr,x
        cmp road_cy
        bne _pur_next
        ; Match at X. Swap-and-pop: if X isn't already the last slot, copy
        ; the (old) last entry over X, then drop the count.
        stx pop_tmp_idx                ; save match slot for the copy
        ldy zone_org_count
        dey                            ; Y = old last index (= count - 1)
        cpy pop_tmp_idx
        beq _pur_just_drop             ; match was last -> nothing to move
        ; Copy entry[Y] -> entry[X]. X still holds the match index.
        lda zone_org_x_arr,y
        sta zone_org_x_arr,x
        lda zone_org_y_arr,y
        sta zone_org_y_arr,x
        lda zone_pop_lo_arr,y
        sta zone_pop_lo_arr,x
        lda zone_pop_hi_arr,y
        sta zone_pop_hi_arr,x
        lda zone_rand_arr,y
        sta zone_rand_arr,x
_pur_just_drop:
        dec zone_org_count
        jsr population_recompute_total
        lda #1
        sta pop_display_dirty
_pur_done:
        rts
_pur_next:
        inx
        bra _pur_loop

; --- Commercial / industrial workplace registries -------------------------------
; Parallel position arrays so the monthly tick can compute, for each R zone,
; the Manhattan distance to the nearest workplace. Same swap-and-pop pattern
; as the residential registry; no per-zone state beyond position.

; Caller (cps_zone after a successful C placement) has zone_org_x/y set to the
; C zone's TL origin. Push it onto the array, bump the count.
population_register_commercial:
        ldx commercial_count
        cpx #ZONE_POP_MAX_COUNT
        bcs _prc_full
        lda zone_org_x
        sta commercial_org_x_arr,x
        lda zone_org_y
        sta commercial_org_y_arr,x
        lda #0
        sta commercial_dev_lo_arr,x
        sta commercial_dev_hi_arr,x
        lda clock_frames
        eor clock_frames+1
        eor zone_org_x
        eor zone_org_y
        sta commercial_rand_arr,x
        inc commercial_count
_prc_full:
        rts

; Caller (single-cell bulldoze of a C origin) leaves the origin coords in
; (road_cx, road_cy). Find the match by coords, swap-and-pop.
population_unregister_commercial:
        ldx #0
_puc_loop:
        cpx commercial_count
        bcs _puc_done
        lda commercial_org_x_arr,x
        cmp road_cx
        bne _puc_next
        lda commercial_org_y_arr,x
        cmp road_cy
        bne _puc_next
        ; Match at X. Move the (old) last entry into this slot if it isn't
        ; already the last, then drop the count.
        stx pop_tmp_idx
        ldy commercial_count
        dey
        cpy pop_tmp_idx
        beq _puc_drop
        lda commercial_org_x_arr,y
        sta commercial_org_x_arr,x
        lda commercial_org_y_arr,y
        sta commercial_org_y_arr,x
        lda commercial_dev_lo_arr,y
        sta commercial_dev_lo_arr,x
        lda commercial_dev_hi_arr,y
        sta commercial_dev_hi_arr,x
        lda commercial_rand_arr,y
        sta commercial_rand_arr,x
_puc_drop:
        dec commercial_count
_puc_done:
        rts
_puc_next:
        inx
        bra _puc_loop

; Police HQ registry helpers. Called from structures.asm via the
; STRUCT_FLAG_IS_POLICE flag. zone_org_x/y is set by cps_structure (place)
; and structure_demolish_at_cell (origin compute), so both read from there.
population_register_police:
        ldx police_count
        cpx #ZONE_POP_MAX_COUNT
        bcs _prp_full
        lda zone_org_x
        sta police_org_x_arr,x
        lda zone_org_y
        sta police_org_y_arr,x
        inc police_count
_prp_full:
        rts

population_unregister_police:
        ldx #0
_pup_loop:
        cpx police_count
        bcs _pup_done
        lda police_org_x_arr,x
        cmp zone_org_x
        bne _pup_next
        lda police_org_y_arr,x
        cmp zone_org_y
        bne _pup_next
        stx pop_tmp_idx
        ldy police_count
        dey
        cpy pop_tmp_idx
        beq _pup_drop
        lda police_org_x_arr,y
        sta police_org_x_arr,x
        lda police_org_y_arr,y
        sta police_org_y_arr,x
_pup_drop:
        dec police_count
_pup_done:
        rts
_pup_next:
        inx
        bra _pup_loop

; Fire-department registry helpers. Mirror image of the police pair; called
; from structures.asm via STRUCT_FLAG_IS_FIRESTATION at place/demolish time.
; zone_org_x/y is set by cps_structure / structure_demolish_at_cell, so both
; read from there.
population_register_firestation:
        ldx firestation_count
        cpx #ZONE_POP_MAX_COUNT
        bcs _prf_full
        lda zone_org_x
        sta firestation_org_x_arr,x
        lda zone_org_y
        sta firestation_org_y_arr,x
        inc firestation_count
_prf_full:
        rts

population_unregister_firestation:
        ldx #0
_puf_loop:
        cpx firestation_count
        bcs _puf_done
        lda firestation_org_x_arr,x
        cmp zone_org_x
        bne _puf_next
        lda firestation_org_y_arr,x
        cmp zone_org_y
        bne _puf_next
        stx pop_tmp_idx
        ldy firestation_count
        dey
        cpy pop_tmp_idx
        beq _puf_drop
        lda firestation_org_x_arr,y
        sta firestation_org_x_arr,x
        lda firestation_org_y_arr,y
        sta firestation_org_y_arr,x
_puf_drop:
        dec firestation_count
_puf_done:
        rts
_puf_next:
        inx
        bra _puf_loop

population_register_industrial:
        ldx industrial_count
        cpx #ZONE_POP_MAX_COUNT
        bcs _pri_full
        lda zone_org_x
        sta industrial_org_x_arr,x
        lda zone_org_y
        sta industrial_org_y_arr,x
        lda #0
        sta industrial_dev_lo_arr,x
        sta industrial_dev_hi_arr,x
        ; Per-zone random seed -- same source style as residential, so each
        ; placed zone gets a unique-feeling per-cell development pattern.
        lda clock_frames
        eor clock_frames+1
        eor zone_org_x
        eor zone_org_y
        sta industrial_rand_arr,x
        inc industrial_count
_pri_full:
        rts

population_unregister_industrial:
        ldx #0
_pui_loop:
        cpx industrial_count
        bcs _pui_done
        lda industrial_org_x_arr,x
        cmp road_cx
        bne _pui_next
        lda industrial_org_y_arr,x
        cmp road_cy
        bne _pui_next
        stx pop_tmp_idx
        ldy industrial_count
        dey
        cpy pop_tmp_idx
        beq _pui_drop
        lda industrial_org_x_arr,y
        sta industrial_org_x_arr,x
        lda industrial_org_y_arr,y
        sta industrial_org_y_arr,x
        lda industrial_dev_lo_arr,y
        sta industrial_dev_lo_arr,x
        lda industrial_dev_hi_arr,y
        sta industrial_dev_hi_arr,x
        lda industrial_rand_arr,y
        sta industrial_rand_arr,x
_pui_drop:
        dec industrial_count
_pui_done:
        rts
_pui_next:
        inx
        bra _pui_loop

; Called from clock_tick on month rollover. For each registered zone, if
; powered + has-jobs + road-adjacent, add POP_GROWTH_PER_MONTH (clamped).
; Re-sum the total at the end and mark display dirty.
population_monthly_tick:
        ; Pre-compute the global "any jobs?" flag once -- cheaper than per zone.
        lda commercial_count
        ora industrial_count
        sta pop_has_jobs_cache         ; 0 = no jobs, nonzero = jobs exist

        ; Refresh the per-cell traffic snapshot once before any zone passes
        ; consume it. ~2300 cells x (R+C+I origins) of cheap Manhattan
        ; distance -- the heaviest job in the monthly tick but still
        ; comfortably under a frame at 40 MHz.
        jsr traffic_recompute

        ldx #0
_pmt_loop:
        cpx zone_org_count
        bcs _pmt_sum
        stx pop_tmp_idx
        lda zone_org_x_arr,x
        sta pop_tmp_cx
        lda zone_org_y_arr,x
        sta pop_tmp_cy

        jsr is_zone_powered_at_tmp
        bcc _pmt_next
        lda pop_has_jobs_cache
        beq _pmt_next
        ; compute_road_side_mask both gates ("no road -> no growth", via carry)
        ; AND leaves the 4-bit mask in zad_road_mask for the per-cell evolution
        ; in zone_apply_development_state to read.
        jsr compute_road_side_mask
        bcc _pmt_next
        ; Distance to nearest workplace. Closer R zones develop faster (lower
        ; threshold contribution) AND more (high-threshold cells like the
        ; center stay below ZONE_POP_MAX). Far zones effectively never grow
        ; their inner cells.
        jsr compute_zone_distance_to_workplace
        ; Count police+fire HQs within EMERGENCY_RADIUS; the per-cell apply
        ; subtracts a bonus from each cell's effective threshold so a zone
        ; near emergency services develops faster.
        jsr count_nearby_emergency_at_tmp
        ; Sample traffic on roads adjacent to the zone footprint. High
        ; level slows growth via a per-cell threshold penalty AND, above
        ; TRAFFIC_DECAY_LEVEL, flips zone_grow_x to subtract instead of
        ; add (people leaving). Same shape for C and I in their own ticks.
        jsr count_zone_traffic_at_tmp

        ldx pop_tmp_idx
        jsr zone_grow_x
_pmt_next:
        ldx pop_tmp_idx
        inx
        bra _pmt_loop
_pmt_sum:
        jsr population_recompute_total
        lda #1
        sta pop_display_dirty
        ; Now do the industrial pass. I zones grow on the same gate (powered
        ; + road) but with no distance / pollution checks -- a factory doesn't
        ; care whether it's near homes, only whether trucks can reach it.
        jmp industrial_monthly_tick

industrial_monthly_tick:
        ldx #0
_imt_loop:
        cpx industrial_count
        bcs _imt_done
        stx pop_tmp_idx
        lda industrial_org_x_arr,x
        sta pop_tmp_cx
        lda industrial_org_y_arr,x
        sta pop_tmp_cy

        jsr is_zone_powered_at_tmp
        bcc _imt_next
        jsr compute_road_side_mask     ; gates AND populates zad_road_mask
        bcc _imt_next
        ; Emergency-services bonus applies to industrial zones too -- a fire
        ; HQ near a factory district speeds factory build-out.
        jsr count_nearby_emergency_at_tmp
        jsr count_zone_traffic_at_tmp

        ldx pop_tmp_idx
        jsr industrial_grow_x
_imt_next:
        ldx pop_tmp_idx
        inx
        bra _imt_loop
_imt_done:
        jmp commercial_monthly_tick

; Grow industrial zone X by IND_GROWTH_PER_MONTH (clamped at IND_DEV_MAX),
; then apply the per-cell development pass against the new dev level.
; X must be preserved; zad_road_mask must already be set by the caller.
; Decays by IND_DECAY_PER_MONTH (clamped at 0) when zad_zone_traffic exceeds
; TRAFFIC_DECAY_LEVEL -- factories with truck routes jammed solid stop
; expanding and gradually wind down.
industrial_grow_x:
        lda zad_zone_traffic
        cmp #TRAFFIC_DECAY_LEVEL+1
        bcs _ig_decay
        clc
        lda industrial_dev_lo_arr,x
        adc #<IND_GROWTH_PER_MONTH
        sta pop_tmp
        lda industrial_dev_hi_arr,x
        adc #>IND_GROWTH_PER_MONTH
        sta pop_tmp+1
        ; Cap at IND_DEV_MAX
        lda pop_tmp+1
        cmp #>IND_DEV_MAX
        bcc _ig_store
        bne _ig_cap
        lda pop_tmp
        cmp #<IND_DEV_MAX
        bcc _ig_store
        bra _ig_cap
_ig_decay:
        sec
        lda industrial_dev_lo_arr,x
        sbc #<IND_DECAY_PER_MONTH
        sta pop_tmp
        lda industrial_dev_hi_arr,x
        sbc #>IND_DECAY_PER_MONTH
        sta pop_tmp+1
        bcs _ig_store
        lda #0
        sta pop_tmp
        sta pop_tmp+1
        bra _ig_store
_ig_cap:
        lda #<IND_DEV_MAX
        sta pop_tmp
        lda #>IND_DEV_MAX
        sta pop_tmp+1
_ig_store:
        lda pop_tmp
        sta industrial_dev_lo_arr,x
        lda pop_tmp+1
        sta industrial_dev_hi_arr,x
        jmp industrial_apply_development_state

; Called once per frame from app_loop. Redraws the readout iff dirty.
population_update:
        lda pop_display_dirty
        beq _pu_done
        lda #0
        sta pop_display_dirty
        jmp population_render
_pu_done:
        rts

;---------------------------------------------------------------------------------------
; Growth helpers
;---------------------------------------------------------------------------------------

; Check whether the cell at (pop_tmp_cx, pop_tmp_cy) is marked powered in the
; Attic power-flood result. Carry SET = powered, CLEAR = not. Clobbers
; city_ptr_x/y, MAP_PTR, A, Z.
;
; power_ptr_into_map reuses city_ptr_lo/hi from the most recent city_cell_ptr
; call (see power.asm), so we have to jsr city_cell_ptr first to seed the
; offset. (Mirrors the bolt_test_update pattern in sprites.asm.)
is_zone_powered_at_tmp:
        lda pop_tmp_cx
        sta city_ptr_x
        lda pop_tmp_cy
        sta city_ptr_y
        jsr city_cell_ptr
        jsr power_ptr_into_map
        ldz #0
        lda [MAP_PTR],z
        beq _izp_no
        sec
        rts
_izp_no:
        clc
        rts

; Compute a 4-bit road-side mask for the 3x3 zone at (pop_tmp_cx, pop_tmp_cy).
; Each bit is set iff that side has at least one road cell along its 3-cell
; perimeter row/column. Stored in zad_road_mask; carry SET iff any bit is set
; (used by the monthly-tick gate "no road -> no growth").
;
; Bit layout: bit 3 = N, bit 2 = E, bit 1 = S, bit 0 = W.
; Same layout as side_mask_for_offset below; (offset_mask AND zad_road_mask)
; tells you whether a given cell of the zone touches any road side.
compute_road_side_mask:
        lda #0
        sta zad_road_mask
        ; --- North row: y = cy - 1, x in [cx, cx+2] ---
        lda pop_tmp_cy
        beq _crsm_skip_n               ; y == 0 -> no north row
        sec
        sbc #1
        sta ira_y
        lda pop_tmp_cx
        sta ira_x
        ldy #3
_crsm_n_loop:
        jsr ira_check_cell
        bcs _crsm_set_n
        inc ira_x
        dey
        bne _crsm_n_loop
        bra _crsm_skip_n
_crsm_set_n:
        lda zad_road_mask
        ora #$08                       ; bit 3 = N
        sta zad_road_mask
_crsm_skip_n:
        ; --- South row: y = cy + 3, x in [cx, cx+2] ---
        lda pop_tmp_cy
        clc
        adc #3
        cmp #CELL_ROWS
        bcs _crsm_skip_s
        sta ira_y
        lda pop_tmp_cx
        sta ira_x
        ldy #3
_crsm_s_loop:
        jsr ira_check_cell
        bcs _crsm_set_s
        inc ira_x
        dey
        bne _crsm_s_loop
        bra _crsm_skip_s
_crsm_set_s:
        lda zad_road_mask
        ora #$02                       ; bit 1 = S
        sta zad_road_mask
_crsm_skip_s:
        ; --- West column: x = cx - 1, y in [cy, cy+2] ---
        lda pop_tmp_cx
        beq _crsm_skip_w
        sec
        sbc #1
        sta ira_x
        lda pop_tmp_cy
        sta ira_y
        ldy #3
_crsm_w_loop:
        jsr ira_check_cell
        bcs _crsm_set_w
        inc ira_y
        dey
        bne _crsm_w_loop
        bra _crsm_skip_w
_crsm_set_w:
        lda zad_road_mask
        ora #$01                       ; bit 0 = W
        sta zad_road_mask
_crsm_skip_w:
        ; --- East column: x = cx + 3, y in [cy, cy+2] ---
        lda pop_tmp_cx
        clc
        adc #3
        cmp #CELL_COLS
        bcs _crsm_done
        sta ira_x
        lda pop_tmp_cy
        sta ira_y
        ldy #3
_crsm_e_loop:
        jsr ira_check_cell
        bcs _crsm_set_e
        inc ira_y
        dey
        bne _crsm_e_loop
        bra _crsm_done
_crsm_set_e:
        lda zad_road_mask
        ora #$04                       ; bit 2 = E
        sta zad_road_mask
_crsm_done:
        lda zad_road_mask
        beq _crsm_no
        sec
        rts
_crsm_no:
        clc
        rts

; Compute the Manhattan distance from the R zone at (pop_tmp_cx, pop_tmp_cy)
; to the nearest C or I origin. Result in zad_distance (capped at 255). If
; no workplaces exist the result is left at 255 -- but the monthly tick's
; has-jobs gate skips growth entirely in that case.
;
; Cost: ~20 cycles per workplace * (commercial_count + industrial_count) per
; R zone. At full caps (128 R x 128 C + 128 I) this is ~80,000 cycles per
; monthly tick = ~2 ms at 40 MHz. Comfortably cheap.
compute_zone_distance_to_workplace:
        lda #$FF
        sta zad_distance
        lda #0
        sta zad_nearby_ind
        ; --- scan commercial origins ---
        ldy commercial_count
        beq _cdtw_check_ind
_cdtw_c_loop:
        dey
        lda commercial_org_x_arr,y
        sta cdw_dx
        lda commercial_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_then_min
        cpy #0
        bne _cdtw_c_loop
_cdtw_check_ind:
        ldy industrial_count
        beq _cdtw_done
_cdtw_i_loop:
        dey
        lda industrial_org_x_arr,y
        sta cdw_dx
        lda industrial_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_then_min
        ; Pollution: cdw_d holds the Manhattan distance just computed; bump
        ; the nearby counter if this I zone sits within POLLUTION_RADIUS.
        lda cdw_d
        cmp #POLLUTION_RADIUS+1
        bcs _cdtw_i_far
        inc zad_nearby_ind
_cdtw_i_far:
        cpy #0
        bne _cdtw_i_loop
_cdtw_done:
        rts

; cdw_dx, cdw_dy hold a workplace origin. Compute Manhattan distance from
; the R zone at (pop_tmp_cx, pop_tmp_cy), clamp to 255, store min into
; zad_distance. Preserves Y (the workplace-loop counter).
cdw_distance_then_min:
        sty cdw_y_save              ; dedicated slot -- pop_tmp_idx belongs to
                                    ; population_monthly_tick as the R-zone index
                                    ; and must NOT be clobbered here.
        ; |dx| = abs(pop_tmp_cx - cdw_dx)
        lda pop_tmp_cx
        sec
        sbc cdw_dx
        bcs _cdwm_dx_pos
        eor #$FF
        clc
        adc #1
_cdwm_dx_pos:
        sta cdw_dx                 ; reuse slot for |dx|
        ; |dy| = abs(pop_tmp_cy - cdw_dy)
        lda pop_tmp_cy
        sec
        sbc cdw_dy
        bcs _cdwm_dy_pos
        eor #$FF
        clc
        adc #1
_cdwm_dy_pos:
        sta cdw_dy                 ; reuse slot for |dy|
        ; d = |dx| + |dy|, clamp 8-bit
        clc
        lda cdw_dx
        adc cdw_dy
        bcc _cdwm_no_clamp
        lda #$FF
_cdwm_no_clamp:
        sta cdw_d
        ; zad_distance = min(zad_distance, d)
        cmp zad_distance
        bcs _cdwm_done
        sta zad_distance
_cdwm_done:
        ldy cdw_y_save
        rts

; Read the cell at (ira_x, ira_y); carry SET if it's a road cell or a
; rail+road crossing.
ira_check_cell:
        lda ira_x
        sta city_ptr_x
        lda ira_y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp #ROAD_CELL_FIRST
        bcc _icc_check_rail_road
        cmp #ROAD_CELL_LAST+1
        bcc _icc_yes
_icc_check_rail_road:
        cmp #RAIL_CELL_H_ROAD
        beq _icc_yes
        cmp #RAIL_CELL_V_ROAD
        beq _icc_yes
        clc
        rts
_icc_yes:
        sec
        rts

; Pre-compute zad_emergency_total_lo/hi = zad_nearby_emergency *
; EMERGENCY_BONUS_STEP. Called once per zone at the top of each
; *_apply_development_state so the per-cell threshold loop can subtract a
; single 16-bit value instead of running its own counter loop. Clobbers A, X.
precompute_emergency_total:
        lda #0
        sta zad_emergency_total_lo
        sta zad_emergency_total_hi
        ldx zad_nearby_emergency
        beq _pet_done
_pet_loop:
        clc
        lda zad_emergency_total_lo
        adc #EMERGENCY_BONUS_STEP
        sta zad_emergency_total_lo
        lda zad_emergency_total_hi
        adc #0
        sta zad_emergency_total_hi
        dex
        bne _pet_loop
_pet_done:
        rts

; Subtract the precomputed emergency bonus (zad_emergency_total_lo/hi) from
; a 16-bit threshold pair (lo, hi) in scratch, clamping the result at zero.
; Used per-cell so a zone near a police/fire HQ crosses each cell's threshold
; sooner. Macro form so the target address is resolved at assemble time --
; the callers want zad_eff_h_lo/hi and zad_eff_a_lo/hi, both known up-front.
; Anonymous labels (+/-) are unique per macro expansion, so calling this
; multiple times in the same scope is safe.
EMERGENCY_BONUS_SUB .macro lo_addr, hi_addr
        sec
        lda \lo_addr
        sbc zad_emergency_total_lo
        sta pop_tmp
        lda \hi_addr
        sbc zad_emergency_total_hi
        bcc +
        sta \hi_addr
        lda pop_tmp
        sta \lo_addr
        bra ++
+
        lda #0
        sta \lo_addr
        sta \hi_addr
+
.endmacro

; Grow zone X by POP_GROWTH_PER_MONTH (clamped at ZONE_POP_MAX), then run the
; per-cell development pass. X must be preserved by caller. zad_road_mask is
; expected to be set (the monthly tick calls compute_road_side_mask first).
; Above TRAFFIC_DECAY_LEVEL the zone DECAYS instead -- POP_DECAY_PER_MONTH
; subtracted (clamped at 0) so people gradually leave the over-trafficked
; block. The display dirty flag is set in either case so the readout
; refreshes for changed totals.
zone_grow_x:
        lda zad_zone_traffic
        cmp #TRAFFIC_DECAY_LEVEL+1
        bcs _zg_decay
        clc
        lda zone_pop_lo_arr,x
        adc #<POP_GROWTH_PER_MONTH
        sta pop_tmp
        lda zone_pop_hi_arr,x
        adc #>POP_GROWTH_PER_MONTH
        sta pop_tmp+1
        ; Cap at ZONE_POP_MAX
        lda pop_tmp+1
        cmp #>ZONE_POP_MAX
        bcc _zg_store
        bne _zg_cap
        lda pop_tmp
        cmp #<ZONE_POP_MAX
        bcc _zg_store
        bra _zg_cap
_zg_decay:
        ; Subtract POP_DECAY_PER_MONTH; clamp at 0 on borrow-out so a zone
        ; that's already empty doesn't wrap around into a huge value.
        sec
        lda zone_pop_lo_arr,x
        sbc #<POP_DECAY_PER_MONTH
        sta pop_tmp
        lda zone_pop_hi_arr,x
        sbc #>POP_DECAY_PER_MONTH
        sta pop_tmp+1
        bcs _zg_store               ; no borrow -> result valid
        lda #0                       ; clamp to zero
        sta pop_tmp
        sta pop_tmp+1
        bra _zg_store
_zg_cap:
        lda #<ZONE_POP_MAX
        sta pop_tmp
        lda #>ZONE_POP_MAX
        sta pop_tmp+1
_zg_store:
        lda pop_tmp
        sta zone_pop_lo_arr,x
        lda pop_tmp+1
        sta zone_pop_hi_arr,x
        jmp zone_apply_development_state

;---------------------------------------------------------------------------------------
; Per-cell development pass for zone X.
;
; For each of the 9 cells in the 3x3 zone, compute the target cell value
; (empty plot / house / apartment) from:
;   * the base threshold for that cell offset (perimeter cells are easier than
;     the center, so the zone develops outward),
;   * a per-zone, per-cell jitter (zone_rand[X] XOR offset_jitter[offset]) so
;     no two zones develop in the same fixed pattern,
;   * a 1/2 threshold halving when the cell's side touches a road
;     (zad_road_mask).
;
; If the target differs from the current cell value, write it. After scanning
; all 9 cells, redraw the 4 covering tiles iff anything changed.
;
; In:  X = zone index, zad_road_mask = side-mask for this zone.
; Out: per-cell map cells updated, tiles redrawn if needed. X preserved.
;---------------------------------------------------------------------------------------
zone_apply_development_state:
        stx pop_tmp_idx
        lda zone_pop_lo_arr,x
        sta zad_pop_lo
        lda zone_pop_hi_arr,x
        sta zad_pop_hi
        lda zone_rand_arr,x
        sta zad_rand
        lda #0
        sta zad_changed
        jsr precompute_emergency_total
        jsr precompute_traffic_penalty

        ; Pre-compute distance bonus (zad_distance << 3) as 16-bit so we can
        ; add it to each cell's base threshold below. zad_distance is 0..255,
        ; so the bonus is 0..2040 -- enough to push far cells well past
        ; ZONE_POP_MAX, naturally gating their development without a hard cap.
        lda #0
        sta zad_dist_hi
        lda zad_distance
        asl
        rol zad_dist_hi
        asl
        rol zad_dist_hi
        asl
        rol zad_dist_hi
        sta zad_dist_lo

        ; Pollution bonus: zad_nearby_ind tells how many industrial origins are
        ; within POLLUTION_RADIUS of this R zone. The first POLLUTION_GRACE
        ; sources are free; each one above the grace adds
        ; POLLUTION_PENALTY_STEP to every cell's threshold, on top of the
        ; distance bonus. Adds to zad_dist_lo/hi so the existing per-cell
        ; threshold math doesn't change.
        lda zad_nearby_ind
        cmp #POLLUTION_GRACE+1
        bcc _zad_no_pollution
        sec
        sbc #POLLUTION_GRACE       ; surplus = nearby - GRACE (>= 1 here)
_zad_pollute_loop:
        pha
        clc
        lda zad_dist_lo
        adc #POLLUTION_PENALTY_STEP
        sta zad_dist_lo
        lda zad_dist_hi
        adc #0
        sta zad_dist_hi
        pla
        sec
        sbc #1
        bne _zad_pollute_loop
_zad_no_pollution:

        ldy #0
_zad_loop:
        cpy #9
        bcs _zad_loop_done
        sty zad_offset

        ; --- compute effective house threshold for this offset ---
        ; jitter = (zad_rand XOR offset_jitter[offset]) AND $1F   (0..31)
        lda zad_rand
        eor offset_jitter,y
        and #$1F
        sta zad_jitter
        ; eff_h = base_h[offset] + jitter + (distance << 2)
        ;   - jitter (0..31): per-cell variation so two zones don't match
        ;   - distance bonus: closer-to-work zones develop earlier; far zones
        ;     can push their high-threshold cells (center, edges) past
        ;     ZONE_POP_MAX so they never develop
        clc
        lda thresh_house_lo,y
        adc zad_jitter
        sta zad_eff_h_lo
        lda thresh_house_hi,y
        adc #0
        sta zad_eff_h_hi
        clc
        lda zad_eff_h_lo
        adc zad_dist_lo
        sta zad_eff_h_lo
        lda zad_eff_h_hi
        adc zad_dist_hi
        sta zad_eff_h_hi
        ; eff_a: same shape for the apartment threshold
        clc
        lda thresh_apt_lo,y
        adc zad_jitter
        sta zad_eff_a_lo
        lda thresh_apt_hi,y
        adc #0
        sta zad_eff_a_hi
        clc
        lda zad_eff_a_lo
        adc zad_dist_lo
        sta zad_eff_a_lo
        lda zad_eff_a_hi
        adc zad_dist_hi
        sta zad_eff_a_hi

        ; --- road bonus: if this cell touches a roaded side, halve both
        ; thresholds (one right-shift). side_mask_for_offset[offset] tells
        ; which sides this cell belongs to (corner = 2, edge = 1, center = 0
        ; sides), zad_road_mask tells which sides have roads.
        lda side_mask_for_offset,y
        and zad_road_mask
        beq _zad_no_road_bonus
        lsr zad_eff_h_hi
        ror zad_eff_h_lo
        lsr zad_eff_a_hi
        ror zad_eff_a_lo
_zad_no_road_bonus:
        ; --- emergency-services bonus: each nearby police+fire HQ subtracts
        ; EMERGENCY_BONUS_STEP from both thresholds (clamped at 0), so a zone
        ; in coverage develops past house AND apartment tiers sooner.
        #EMERGENCY_BONUS_SUB zad_eff_h_lo, zad_eff_h_hi
        #EMERGENCY_BONUS_SUB zad_eff_a_lo, zad_eff_a_hi
        ; --- traffic penalty: each level of perceived traffic adds
        ; TRAFFIC_PENALTY_STEP to both thresholds. High traffic raises the
        ; bar for "people want to live here" faster than the road / police
        ; bonuses can compensate, so cells gradually downgrade even before
        ; pop decay kicks in at TRAFFIC_DECAY_LEVEL.
        #TRAFFIC_PENALTY_ADD zad_eff_h_lo, zad_eff_h_hi
        #TRAFFIC_PENALTY_ADD zad_eff_a_lo, zad_eff_a_hi

        ; --- pick target stage from zone_pop vs effective thresholds ---
        ; Compare pop >= eff_a ?
        lda zad_pop_hi
        cmp zad_eff_a_hi
        bcc _zad_pick_house
        bne _zad_pick_apt
        lda zad_pop_lo
        cmp zad_eff_a_lo
        bcs _zad_pick_apt
_zad_pick_house:
        ; pop >= eff_h ?
        lda zad_pop_hi
        cmp zad_eff_h_hi
        bcc _zad_pick_empty
        bne _zad_pick_house_yes
        lda zad_pop_lo
        cmp zad_eff_h_lo
        bcc _zad_pick_empty
_zad_pick_house_yes:
        lda #RES_HOUSE_CELL_FIRST
        bra _zad_have_target
_zad_pick_apt:
        lda #APT_CELL_FIRST
        bra _zad_have_target
_zad_pick_empty:
        lda #ZONE_CELL_FIRST
_zad_have_target:
        clc
        adc zad_offset
        sta zad_target

        ; --- read current cell at (zone_org + dx, dy); rewrite if changed ---
        ldy zad_offset
        ldx pop_tmp_idx
        clc
        lda zone_org_x_arr,x
        adc offset_to_dx,y
        sta city_ptr_x
        clc
        lda zone_org_y_arr,x
        adc offset_to_dy,y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp zad_target
        beq _zad_next
        lda zad_target
        sta [MAP_PTR],z
        inc zad_changed
_zad_next:
        ldy zad_offset
        iny
        bra _zad_loop

_zad_loop_done:
        lda zad_changed
        beq _zad_render_done
        ; Redraw the 4 tiles covering the 3x3 footprint, by hitting the 4
        ; corner cells. render_redraw_cell_tile clobbers city_ptr_*; re-seed
        ; from the registry each time. (Same pattern as cps_zone.)
        ldx pop_tmp_idx
        lda zone_org_x_arr,x
        sta city_ptr_x
        lda zone_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda zone_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda zone_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda zone_org_x_arr,x
        sta city_ptr_x
        lda zone_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda zone_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda zone_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
_zad_render_done:
        rts

;---------------------------------------------------------------------------------------
; Industrial per-cell development pass. Single tier (empty -> heavy) so the
; threshold math only needs the house thresholds; reuses jitter, road bonus,
; and the offset_to_dx/dy tables. No distance / pollution bonuses -- industry
; doesn't care about being near anything.
;
; In:  X = industrial zone index, zad_road_mask = side-mask for this zone.
;---------------------------------------------------------------------------------------
industrial_apply_development_state:
        stx pop_tmp_idx
        lda industrial_dev_lo_arr,x
        sta zad_pop_lo
        lda industrial_dev_hi_arr,x
        sta zad_pop_hi
        lda industrial_rand_arr,x
        sta zad_rand
        lda #0
        sta zad_changed
        jsr precompute_emergency_total
        jsr precompute_traffic_penalty

        ldy #0
_iad_loop:
        cpy #9
        bcs _iad_loop_done
        sty zad_offset

        lda zad_rand
        eor offset_jitter,y
        and #$1F
        sta zad_jitter

        clc
        lda thresh_house_lo,y
        adc zad_jitter
        sta zad_eff_h_lo
        lda thresh_house_hi,y
        adc #0
        sta zad_eff_h_hi

        lda side_mask_for_offset,y
        and zad_road_mask
        beq _iad_no_road_bonus
        lsr zad_eff_h_hi
        ror zad_eff_h_lo
_iad_no_road_bonus:
        ; Emergency-services bonus -- same shape as R: each nearby HQ
        ; subtracts EMERGENCY_BONUS_STEP from the effective threshold so an
        ; industrial zone in coverage develops to heavy industrial sooner.
        #EMERGENCY_BONUS_SUB zad_eff_h_lo, zad_eff_h_hi
        #TRAFFIC_PENALTY_ADD zad_eff_h_lo, zad_eff_h_hi

        ; Pick target: dev >= eff_h -> heavy, else empty.
        lda zad_pop_hi
        cmp zad_eff_h_hi
        bcc _iad_pick_empty
        bne _iad_pick_heavy
        lda zad_pop_lo
        cmp zad_eff_h_lo
        bcc _iad_pick_empty
_iad_pick_heavy:
        lda #IND_HEAVY_CELL_FIRST
        bra _iad_have_target
_iad_pick_empty:
        ; Empty industrial origin = ZONE_CELL_FIRST + 18 (offset 0 within
        ; the I block of the zone-cell range); + zad_offset for the cell.
        lda #ZONE_CELL_FIRST + 18
_iad_have_target:
        clc
        adc zad_offset
        sta zad_target

        ldy zad_offset
        ldx pop_tmp_idx
        clc
        lda industrial_org_x_arr,x
        adc offset_to_dx,y
        sta city_ptr_x
        clc
        lda industrial_org_y_arr,x
        adc offset_to_dy,y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp zad_target
        beq _iad_next
        lda zad_target
        sta [MAP_PTR],z
        inc zad_changed
_iad_next:
        ldy zad_offset
        iny
        bra _iad_loop

_iad_loop_done:
        lda zad_changed
        beq _iad_render_done
        ldx pop_tmp_idx
        lda industrial_org_x_arr,x
        sta city_ptr_x
        lda industrial_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda industrial_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda industrial_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda industrial_org_x_arr,x
        sta city_ptr_x
        lda industrial_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda industrial_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda industrial_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
_iad_render_done:
        rts

;---------------------------------------------------------------------------------------
; Commercial monthly pass: same gates as industrial (powered + road) plus a
; "has residents anywhere?" check -- without people the shops have no
; customers. Bonuses applied per cell:
;   * Distance to nearest R origin       -> further = slower (zad_distance << 3
;                                            added to threshold, same as R<->jobs).
;   * Police HQs within POLICE_RADIUS    -> each subtracts POLICE_BONUS_STEP from
;                                            the distance bonus (clamped at 0).
;---------------------------------------------------------------------------------------
commercial_monthly_tick:
        ; Population gate: don't even start the loop unless the city has at
        ; least MIN_POP_FOR_COMMERCIAL people in residence. population is
        ; 24-bit; any nonzero high byte means we're well past 50, and only
        ; the low byte matters otherwise.
        lda population+2
        bne _cmt_pop_ok
        lda population+1
        bne _cmt_pop_ok
        lda population
        cmp #MIN_POP_FOR_COMMERCIAL
        bcc _cmt_done
_cmt_pop_ok:
        ldx #0
_cmt_loop:
        cpx commercial_count
        bcs _cmt_done
        stx pop_tmp_idx
        lda commercial_org_x_arr,x
        sta pop_tmp_cx
        lda commercial_org_y_arr,x
        sta pop_tmp_cy

        jsr is_zone_powered_at_tmp
        bcc _cmt_next
        jsr compute_road_side_mask
        bcc _cmt_next

        jsr compute_commercial_distance_and_emergency
        jsr count_zone_traffic_at_tmp
        ldx pop_tmp_idx
        jsr commercial_grow_x
_cmt_next:
        ldx pop_tmp_idx
        inx
        bra _cmt_loop
_cmt_done:
        rts

; Grow commercial zone X by COM_GROWTH_PER_MONTH (clamped at COM_DEV_MAX),
; then run the per-cell development pass. Decays by COM_DECAY_PER_MONTH
; (clamped at 0) when zad_zone_traffic exceeds TRAFFIC_DECAY_LEVEL --
; shops shutter when their street gets too congested for foot traffic.
commercial_grow_x:
        lda zad_zone_traffic
        cmp #TRAFFIC_DECAY_LEVEL+1
        bcs _cg_decay
        clc
        lda commercial_dev_lo_arr,x
        adc #<COM_GROWTH_PER_MONTH
        sta pop_tmp
        lda commercial_dev_hi_arr,x
        adc #>COM_GROWTH_PER_MONTH
        sta pop_tmp+1
        lda pop_tmp+1
        cmp #>COM_DEV_MAX
        bcc _cg_store
        bne _cg_cap
        lda pop_tmp
        cmp #<COM_DEV_MAX
        bcc _cg_store
        bra _cg_cap
_cg_decay:
        sec
        lda commercial_dev_lo_arr,x
        sbc #<COM_DECAY_PER_MONTH
        sta pop_tmp
        lda commercial_dev_hi_arr,x
        sbc #>COM_DECAY_PER_MONTH
        sta pop_tmp+1
        bcs _cg_store
        lda #0
        sta pop_tmp
        sta pop_tmp+1
        bra _cg_store
_cg_cap:
        lda #<COM_DEV_MAX
        sta pop_tmp
        lda #>COM_DEV_MAX
        sta pop_tmp+1
_cg_store:
        lda pop_tmp
        sta commercial_dev_lo_arr,x
        lda pop_tmp+1
        sta commercial_dev_hi_arr,x
        jmp commercial_apply_development_state

; For the current C zone at (pop_tmp_cx, pop_tmp_cy):
;   * zad_distance       = min Manhattan distance to any R origin (clamped 255)
;   * zad_nearby_emergency = count of police+fire origins within EMERGENCY_RADIUS
; Same per-iteration cost as compute_zone_distance_to_workplace but pointed
; at a different pair of arrays.
compute_commercial_distance_and_emergency:
        lda #$FF
        sta zad_distance
        ; --- distance to nearest R ---
        ldy zone_org_count
        beq _ccde_count_emergency
_ccde_r_loop:
        dey
        lda zone_org_x_arr,y
        sta cdw_dx
        lda zone_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_then_min
        cpy #0
        bne _ccde_r_loop
_ccde_count_emergency:
        jmp count_nearby_emergency_at_tmp

; Count emergency-service HQs (police + fire) within EMERGENCY_RADIUS Manhattan
; cells of the zone at (pop_tmp_cx, pop_tmp_cy). Result in zad_nearby_emergency.
; Shared by the R, C, and I monthly ticks so every zone type sees the same bonus.
count_nearby_emergency_at_tmp:
        lda #0
        sta zad_nearby_emergency
        ; --- police HQs ---
        ldy police_count
        beq _cne_check_fire
_cne_p_loop:
        dey
        lda police_org_x_arr,y
        sta cdw_dx
        lda police_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_only
        lda cdw_d
        cmp #EMERGENCY_RADIUS+1
        bcs _cne_p_far
        inc zad_nearby_emergency
_cne_p_far:
        cpy #0
        bne _cne_p_loop
_cne_check_fire:
        ; --- fire HQs (same scan, different arrays) ---
        ldy firestation_count
        beq _cne_done
_cne_f_loop:
        dey
        lda firestation_org_x_arr,y
        sta cdw_dx
        lda firestation_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_only
        lda cdw_d
        cmp #EMERGENCY_RADIUS+1
        bcs _cne_f_far
        inc zad_nearby_emergency
_cne_f_far:
        cpy #0
        bne _cne_f_loop
_cne_done:
        rts

;---------------------------------------------------------------------------------------
; Traffic system.
;
; traffic_init  -- zero the Attic traffic-level array. Called once from
;                  city_init. The array is only meaningful after traffic_
;                  recompute has populated it; zeroing means "no traffic
;                  anywhere yet" so the road animation degrades gracefully
;                  to plain (empty) roads on the very first frame.
;
; traffic_recompute -- walk every cell of the world map. For each road cell
;                  (ROAD_CELL_FIRST..LAST), count the R + C + I zone origins
;                  within TRAFFIC_RADIUS Manhattan cells; clamp at
;                  TRAFFIC_LEVEL_MAX; write to the Attic traffic array.
;                  Non-road cells are written 0 so the renderer can read
;                  the same byte for any cell without a type check.
;
; count_zone_traffic_at_tmp -- sample the perimeter of the 3x3 zone at
;                  (pop_tmp_cx, pop_tmp_cy); take the max traffic_level
;                  found on any adjacent road cell into zad_zone_traffic.
;                  Same role as count_nearby_emergency_at_tmp.
;---------------------------------------------------------------------------------------

; Set MAP_PTR to point at the Attic traffic-level cell at (city_ptr_x,
; city_ptr_y). Assumes city_ptr_lo/hi are already set (call after
; city_cell_ptr or whenever city_ptr_lo/hi are current). Clobbers A.
traffic_ptr_into_map:
        clc
        lda #<ATTIC_TRAFFIC_PHYS
        adc city_ptr_lo
        sta MAP_PTR
        lda #>ATTIC_TRAFFIC_PHYS
        adc city_ptr_hi
        sta MAP_PTR+1
        lda #`ATTIC_TRAFFIC_PHYS
        adc #0
        sta MAP_PTR+2
        lda #(ATTIC_TRAFFIC_PHYS >> 24)
        adc #0
        sta MAP_PTR+3
        rts

; Clear the entire traffic-level array. Iterates over every cell in the map
; and DMA would be overkill for ~2.3 KB at boot. Plain loop.
traffic_init:
        lda #0
        sta ctr_y
_ti_row:
        lda #0
        sta ctr_x
_ti_col:
        lda ctr_x
        sta city_ptr_x
        lda ctr_y
        sta city_ptr_y
        jsr city_cell_ptr
        jsr traffic_ptr_into_map
        ldz #0
        lda #0
        sta [MAP_PTR],z
        inc ctr_x
        lda ctr_x
        cmp #CELL_COLS
        bne _ti_col
        inc ctr_y
        lda ctr_y
        cmp #CELL_ROWS
        bne _ti_row
        rts

; Recompute traffic_level for every cell. Non-road cells write 0; road cells
; (ROAD_CELL_FIRST..LAST inclusive) write the clamped count of R + C + I
; origins within TRAFFIC_RADIUS. Called once per monthly tick before the
; per-zone passes run, so zad_zone_traffic reads a fresh snapshot.
traffic_recompute:
        lda #0
        sta ctr_y
_trr_row:
        lda #0
        sta ctr_x
_trr_col:
        ; Read the map cell value.
        lda ctr_x
        sta city_ptr_x
        sta pop_tmp_cx              ; cdw_distance_only reads pop_tmp_c*
        lda ctr_y
        sta city_ptr_y
        sta pop_tmp_cy
        jsr city_cell_ptr            ; MAP_PTR -> map cell
        ldz #0
        lda [MAP_PTR],z
        ; Is it a road? (ROAD_CELL_FIRST..LAST, includes H/V/curves/T/4way/
        ; bridges/*_POWER -- anything cars could drive on.)
        cmp #ROAD_CELL_FIRST
        bcc _trr_no_road
        cmp #ROAD_CELL_LAST+1
        bcs _trr_no_road
        ; Score this road cell against R, C, I origins. Each origin within
        ; TRAFFIC_RADIUS Manhattan cells contributes +1; clamp at
        ; TRAFFIC_LEVEL_MAX so the renderer's 4-position threshold works.
        lda #0
        sta ctr_level
        jsr ctr_score_residential
        jsr ctr_score_commercial
        jsr ctr_score_industrial
        lda ctr_level
        cmp #TRAFFIC_LEVEL_MAX+1
        bcc _trr_have_level
        lda #TRAFFIC_LEVEL_MAX
_trr_have_level:
        bra _trr_write
_trr_no_road:
        lda #0
_trr_write:
        pha
        ; MAP_PTR currently points at the MAP cell. Re-derive for traffic.
        jsr traffic_ptr_into_map
        pla
        ldz #0
        sta [MAP_PTR],z
        inc ctr_x
        lda ctr_x
        cmp #CELL_COLS
        bne _trr_col
        inc ctr_y
        lda ctr_y
        cmp #CELL_ROWS
        bne _trr_row
        rts

; Each ctr_score_* routine adds +1 to ctr_level for every origin of its zone
; type within TRAFFIC_RADIUS of (pop_tmp_cx, pop_tmp_cy). Cap is applied at
; the call site after all three run.
ctr_score_residential:
        ldy zone_org_count
        beq _ctrr_done
_ctrr_loop:
        dey
        lda zone_org_x_arr,y
        sta cdw_dx
        lda zone_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_only
        lda cdw_d
        cmp #TRAFFIC_RADIUS+1
        bcs _ctrr_far
        inc ctr_level
_ctrr_far:
        cpy #0
        bne _ctrr_loop
_ctrr_done:
        rts

ctr_score_commercial:
        ldy commercial_count
        beq _ctrc_done
_ctrc_loop:
        dey
        lda commercial_org_x_arr,y
        sta cdw_dx
        lda commercial_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_only
        lda cdw_d
        cmp #TRAFFIC_RADIUS+1
        bcs _ctrc_far
        inc ctr_level
_ctrc_far:
        cpy #0
        bne _ctrc_loop
_ctrc_done:
        rts

ctr_score_industrial:
        ldy industrial_count
        beq _ctri_done
_ctri_loop:
        dey
        lda industrial_org_x_arr,y
        sta cdw_dx
        lda industrial_org_y_arr,y
        sta cdw_dy
        jsr cdw_distance_only
        lda cdw_d
        cmp #TRAFFIC_RADIUS+1
        bcs _ctri_far
        inc ctr_level
_ctri_far:
        cpy #0
        bne _ctri_loop
_ctri_done:
        rts

; For the zone at (pop_tmp_cx, pop_tmp_cy), scan the cells immediately
; surrounding the 3x3 footprint (an outer 5x5 ring minus the zone itself).
; Take the MAX traffic_level seen on any adjacent cell into zad_zone_traffic.
; "Max" so a single bordering busy road causes the whole zone to feel it --
; matches how a real busy-side-street ruins one block of housing even if
; the others sides are quiet.
count_zone_traffic_at_tmp:
        lda #0
        sta czt_level
        lda #$FF                    ; -1: start one cell northwest of origin
        sta czt_dy
_czt_row:
        lda #$FF
        sta czt_dx
_czt_col:
        ; Skip cells INSIDE the zone footprint (dx in 0..2 AND dy in 0..2).
        lda czt_dx
        cmp #3
        bcs _czt_outside            ; dx >= 3 -> outside footprint to the east
        ; dx in $FF (-1), 0, 1, 2: 0/1/2 are inside on x; -1 is outside
        cmp #0
        bcc _czt_outside            ; dx == $FF
        ; dx in 0..2 here -- check dy too
        lda czt_dy
        cmp #3
        bcs _czt_outside
        cmp #0
        bcc _czt_outside
        ; (dx,dy) both 0..2 -> inside the zone, skip.
        bra _czt_next
_czt_outside:
        ; Build absolute cell coords. Skip if off map (any underflow / overflow).
        clc
        lda pop_tmp_cx
        adc czt_dx
        bcc _czt_next_no_carry      ; underflow (dx was $FF and pop_tmp_cx == 0)
        cmp #CELL_COLS
        bcs _czt_next               ; off east edge
        sta city_ptr_x
        clc
        lda pop_tmp_cy
        adc czt_dy
        bcc _czt_next_no_carry
        cmp #CELL_ROWS
        bcs _czt_next
        sta city_ptr_y
        ; Read traffic_level at this cell.
        jsr city_cell_ptr
        jsr traffic_ptr_into_map
        ldz #0
        lda [MAP_PTR],z
        cmp czt_level
        bcc _czt_next               ; not higher than current max
        sta czt_level
_czt_next:
_czt_next_no_carry:
        inc czt_dx
        lda czt_dx
        cmp #4                       ; dx range: -1, 0, 1, 2, 3 -- 5 values
        bne _czt_col
        inc czt_dy
        lda czt_dy
        cmp #4
        bne _czt_row
        lda czt_level
        sta zad_zone_traffic
        rts

; Precompute zad_traffic_penalty_lo/hi = zad_zone_traffic *
; TRAFFIC_PENALTY_STEP, so each cell's apply loop can add a single 16-bit
; constant to its effective threshold instead of looping. Mirrors
; precompute_emergency_total.
precompute_traffic_penalty:
        lda #0
        sta zad_traffic_penalty_lo
        sta zad_traffic_penalty_hi
        ldx zad_zone_traffic
        beq _ptp_done
_ptp_loop:
        clc
        lda zad_traffic_penalty_lo
        adc #TRAFFIC_PENALTY_STEP
        sta zad_traffic_penalty_lo
        lda zad_traffic_penalty_hi
        adc #0
        sta zad_traffic_penalty_hi
        dex
        bne _ptp_loop
_ptp_done:
        rts

; Add the precomputed traffic penalty (zad_traffic_penalty_lo/hi) to the 16-
; bit threshold (lo_addr, hi_addr). Symmetric to EMERGENCY_BONUS_SUB but on
; the addition side. No clamp -- the threshold simply grows out of reach,
; preventing the cell from developing while traffic is high.
TRAFFIC_PENALTY_ADD .macro lo_addr, hi_addr
        clc
        lda \lo_addr
        adc zad_traffic_penalty_lo
        sta \lo_addr
        lda \hi_addr
        adc zad_traffic_penalty_hi
        sta \hi_addr
.endmacro

; cdw_dx, cdw_dy -> Manhattan distance from (pop_tmp_cx, pop_tmp_cy), clamped
; at 255, stored in cdw_d. Like cdw_distance_then_min but no min-of-pair tracking.
; Preserves Y. Used by the emergency-services scan in count_nearby_emergency_at_tmp.
cdw_distance_only:
        sty cdw_y_save
        lda pop_tmp_cx
        sec
        sbc cdw_dx
        bcs _cdo_dx_pos
        eor #$FF
        clc
        adc #1
_cdo_dx_pos:
        sta cdw_dx
        lda pop_tmp_cy
        sec
        sbc cdw_dy
        bcs _cdo_dy_pos
        eor #$FF
        clc
        adc #1
_cdo_dy_pos:
        sta cdw_dy
        clc
        lda cdw_dx
        adc cdw_dy
        bcc _cdo_no_clamp
        lda #$FF
_cdo_no_clamp:
        sta cdw_d
        ldy cdw_y_save
        rts

;---------------------------------------------------------------------------------------
; Commercial per-cell development pass. Single tier (empty -> heavy). Mirrors
; industrial_apply_development_state plus a distance-bonus from the C zone's
; distance to the nearest R, and the shared emergency-services bonus that
; subtracts from each cell's effective threshold (clamped at 0).
;---------------------------------------------------------------------------------------
commercial_apply_development_state:
        stx pop_tmp_idx
        lda commercial_dev_lo_arr,x
        sta zad_pop_lo
        lda commercial_dev_hi_arr,x
        sta zad_pop_hi
        lda commercial_rand_arr,x
        sta zad_rand
        lda #0
        sta zad_changed
        jsr precompute_emergency_total
        jsr precompute_traffic_penalty

        ; Distance bonus: zad_distance << 3 as 16-bit -- same shape as R.
        lda #0
        sta zad_dist_hi
        lda zad_distance
        asl
        rol zad_dist_hi
        asl
        rol zad_dist_hi
        asl
        rol zad_dist_hi
        sta zad_dist_lo

        ldy #0
_cad_loop:
        cpy #9
        bcs _cad_loop_done
        sty zad_offset

        lda zad_rand
        eor offset_jitter,y
        and #$1F
        sta zad_jitter

        clc
        lda thresh_house_lo,y
        adc zad_jitter
        sta zad_eff_h_lo
        lda thresh_house_hi,y
        adc #0
        sta zad_eff_h_hi
        clc
        lda zad_eff_h_lo
        adc zad_dist_lo
        sta zad_eff_h_lo
        lda zad_eff_h_hi
        adc zad_dist_hi
        sta zad_eff_h_hi

        lda side_mask_for_offset,y
        and zad_road_mask
        beq _cad_no_road_bonus
        lsr zad_eff_h_hi
        ror zad_eff_h_lo
_cad_no_road_bonus:
        ; Emergency-services bonus: each nearby police+fire HQ subtracts
        ; EMERGENCY_BONUS_STEP from the effective threshold (clamped at 0),
        ; applied AFTER the road halving so the bonus is meaningful even when
        ; the road already halved the threshold.
        #EMERGENCY_BONUS_SUB zad_eff_h_lo, zad_eff_h_hi
        #TRAFFIC_PENALTY_ADD zad_eff_h_lo, zad_eff_h_hi

        lda zad_pop_hi
        cmp zad_eff_h_hi
        bcc _cad_pick_empty
        bne _cad_pick_heavy
        lda zad_pop_lo
        cmp zad_eff_h_lo
        bcc _cad_pick_empty
_cad_pick_heavy:
        lda #COM_HEAVY_CELL_FIRST
        bra _cad_have_target
_cad_pick_empty:
        ; Empty C origin = ZONE_CELL_FIRST + 9 (offset 0 of the C block within
        ; the zone-cell range); + zad_offset for the cell.
        lda #ZONE_CELL_FIRST + 9
_cad_have_target:
        clc
        adc zad_offset
        sta zad_target

        ldy zad_offset
        ldx pop_tmp_idx
        clc
        lda commercial_org_x_arr,x
        adc offset_to_dx,y
        sta city_ptr_x
        clc
        lda commercial_org_y_arr,x
        adc offset_to_dy,y
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        cmp zad_target
        beq _cad_next
        lda zad_target
        sta [MAP_PTR],z
        inc zad_changed
_cad_next:
        ldy zad_offset
        iny
        bra _cad_loop

_cad_loop_done:
        lda zad_changed
        beq _cad_render_done
        ldx pop_tmp_idx
        lda commercial_org_x_arr,x
        sta city_ptr_x
        lda commercial_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda commercial_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda commercial_org_y_arr,x
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda commercial_org_x_arr,x
        sta city_ptr_x
        lda commercial_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
        ldx pop_tmp_idx
        lda commercial_org_x_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_x
        lda commercial_org_y_arr,x
        clc
        adc #ZONE_SIZE-1
        sta city_ptr_y
        jsr render_redraw_cell_tile
_cad_render_done:
        rts

;---------------------------------------------------------------------------------------
; Per-offset development tables. Cell offset layout (row-major, dy*3+dx):
;   0  1  2     NW  N   NE
;   3  4  5      W  C    E
;   6  7  8     SW  S   SE
;
; thresh_house: base pop at which this cell becomes a house. Perimeter cells
; have lower thresholds than the center so the zone develops outward; jitter +
; road bonus + the per-zone random seed give variation per zone.
; thresh_apt:   base pop at which this cell evolves further to an apartment.
;---------------------------------------------------------------------------------------
; offset:            0    1    2    3    4    5    6    7    8
;                   NW   N    NE   W    C    E    SW   S    SE
; corners ~30, edges ~100, center ~250: a gap large enough that with the
; distance bonus (zad_distance << 3 added to every cell's threshold) far
; zones push their edge and center thresholds past ZONE_POP_MAX while
; corners can still develop.
thresh_house_lo: .byte 30, 100, 30, 100, 250, 100, 30, 100, 30
thresh_house_hi: .byte  0,   0,  0,   0,   0,   0,  0,   0,  0
; 400 = $0190 -> lo=$90 hi=$01;  600 = $0258 -> lo=$58 hi=$02
thresh_apt_lo:   .byte $90, $90, $90, $90, $58, $90, $90, $90, $90
thresh_apt_hi:   .byte   1,   1,   1,   1,   2,   1,   1,   1,   1

; (offset -> dx, dy) for the 3x3 layout above.
offset_to_dx:    .byte 0, 1, 2, 0, 1, 2, 0, 1, 2
offset_to_dy:    .byte 0, 0, 0, 1, 1, 1, 2, 2, 2

; Which of the 4 zone sides a given cell belongs to. Bits match
; compute_road_side_mask: bit3=N, bit2=E, bit1=S, bit0=W.
; Corners belong to 2 sides; edges to 1; center to none.
;                            NW    N    NE    W     C    E    SW   S    SE
side_mask_for_offset: .byte $09, $08, $0C, $01, $00, $04, $03, $02, $06

; Per-offset jitter bytes XOR'd with zone_rand[X] to give each cell its own
; pseudo-random threshold perturbation within its zone. Hand-picked prime-ish
; values so the 9 perturbations don't collide.
offset_jitter:        .byte $37, $5B, $19, $A3, $7D, $C1, $4F, $2D, $E9

; population = sum(zone_pop[0..zone_org_count-1]). 24-bit result.
population_recompute_total:
        lda #0
        sta population
        sta population+1
        sta population+2
        ldx #0
_prt_loop:
        cpx zone_org_count
        bcs _prt_done
        clc
        lda population
        adc zone_pop_lo_arr,x
        sta population
        lda population+1
        adc zone_pop_hi_arr,x
        sta population+1
        lda population+2
        adc #0
        sta population+2
        inx
        bra _prt_loop
_prt_done:
        rts

;---------------------------------------------------------------------------------------
; Render the icon + 7-digit count on row POP_ROW. Idempotent. Status-row tile
; (UI_TILE_STATUS_LIGHT) fills positions blanked by leading-zero suppression.
;---------------------------------------------------------------------------------------

population_render:
        jsr pop_to_digits

        ; Human silhouette icon (col 30). POP_ICON_CHAR > 255, so route through
        ; set_fcm_char16: caller pre-sets snc_char_hi, passes low byte in A.
        lda #>POP_ICON_CHAR
        sta snc_char_hi
        lda #<POP_ICON_CHAR
        ldx #POP_COL_ICON
        ldy #POP_ROW
        jsr set_fcm_char16

        lda #0
        sta pop_seen

        lda pop_digits
        beq _pr_d0_blank
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_MIL
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d1
_pr_d0_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_MIL
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d1:
        lda pop_digits+1
        ora pop_seen
        beq _pr_d1_blank
        lda pop_digits+1
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_HT
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d2
_pr_d1_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_HT
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d2:
        lda pop_digits+2
        ora pop_seen
        beq _pr_d2_blank
        lda pop_digits+2
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_TT
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d3
_pr_d2_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_TT
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d3:
        lda pop_digits+3
        ora pop_seen
        beq _pr_d3_blank
        lda pop_digits+3
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_T
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d4
_pr_d3_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_T
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d4:
        lda pop_digits+4
        ora pop_seen
        beq _pr_d4_blank
        lda pop_digits+4
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_H
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d5
_pr_d4_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_H
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d5:
        lda pop_digits+5
        ora pop_seen
        beq _pr_d5_blank
        lda pop_digits+5
        jsr pr_set_seen
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_TE
        ldy #POP_ROW
        jsr set_fcm_char
        bra _pr_d6
_pr_d5_blank:
        lda #UI_TILE_STATUS_LIGHT
        ldx #POP_COL_TE
        ldy #POP_ROW
        jsr set_fcm_char

_pr_d6:
        ; Units digit always renders -- a city with 0 people still shows "0".
        lda pop_digits+6
        clc
        adc #UI_TEXT_0
        ldx #POP_COL_U
        ldy #POP_ROW
        jmp set_fcm_char

pr_set_seen:
        ldx #1
        stx pop_seen
        rts

;---------------------------------------------------------------------------------------
; Internal: convert `population` (24-bit) to pop_digits[0..6] (millions..units).
;---------------------------------------------------------------------------------------

pop_to_digits:
        lda population
        sta pd_work
        lda population+1
        sta pd_work+1
        lda population+2
        sta pd_work+2
        ldx #0
_ptd_loop:
        lda #0
        sta pd_count
_ptd_sub:
        lda pd_work
        cmp pd_powers_lo,x
        lda pd_work+1
        sbc pd_powers_hi,x
        lda pd_work+2
        sbc pd_powers_up,x
        bcc _ptd_next
        sec
        lda pd_work
        sbc pd_powers_lo,x
        sta pd_work
        lda pd_work+1
        sbc pd_powers_hi,x
        sta pd_work+1
        lda pd_work+2
        sbc pd_powers_up,x
        sta pd_work+2
        inc pd_count
        jmp _ptd_sub
_ptd_next:
        lda pd_count
        sta pop_digits,x
        inx
        cpx #7
        bne _ptd_loop
        rts

pd_powers_lo:  .byte $40,$A0,$10,$E8,$64,$0A,$01
pd_powers_hi:  .byte $42,$86,$27,$03,$00,$00,$00
pd_powers_up:  .byte $0F,$01,$00,$00,$00,$00,$00

; --- state ---
population:                     ; 24-bit running total
        .byte 0, 0, 0
pop_display_dirty:              ; nonzero -> redraw next frame
        .byte 0

; Zone registry: parallel arrays. Sized to ZONE_POP_MAX_COUNT (128).
zone_org_count:                 ; 0..ZONE_POP_MAX_COUNT
        .byte 0
zone_org_x_arr:
        .fill ZONE_POP_MAX_COUNT, 0
zone_org_y_arr:
        .fill ZONE_POP_MAX_COUNT, 0
zone_pop_lo_arr:
        .fill ZONE_POP_MAX_COUNT, 0
zone_pop_hi_arr:
        .fill ZONE_POP_MAX_COUNT, 0
zone_rand_arr:                  ; per-zone random seed (drives per-cell jitter)
        .fill ZONE_POP_MAX_COUNT, 0

commercial_count:               ; # placed commercial zones, for has-jobs check
        .byte 0
industrial_count:               ; # placed industrial zones, for has-jobs check
        .byte 0

; Commercial / industrial origin positions, parallel to commercial_count and
; industrial_count. Each capped at ZONE_POP_MAX_COUNT (128 entries).
commercial_org_x_arr:
        .fill ZONE_POP_MAX_COUNT, 0
commercial_org_y_arr:
        .fill ZONE_POP_MAX_COUNT, 0
industrial_org_x_arr:
        .fill ZONE_POP_MAX_COUNT, 0
industrial_org_y_arr:
        .fill ZONE_POP_MAX_COUNT, 0
industrial_dev_lo_arr:          ; 16-bit per-zone industrial dev level
        .fill ZONE_POP_MAX_COUNT, 0
industrial_dev_hi_arr:
        .fill ZONE_POP_MAX_COUNT, 0
industrial_rand_arr:            ; per-zone random seed (jitter source)
        .fill ZONE_POP_MAX_COUNT, 0
commercial_dev_lo_arr:          ; 16-bit per-zone commercial dev level
        .fill ZONE_POP_MAX_COUNT, 0
commercial_dev_hi_arr:
        .fill ZONE_POP_MAX_COUNT, 0
commercial_rand_arr:            ; per-zone random seed (jitter source)
        .fill ZONE_POP_MAX_COUNT, 0

; Police HQ registry: origin positions of every placed police structure.
; Maintained by population_register_police / population_unregister_police,
; which structures.asm calls via the STRUCT_FLAG_IS_POLICE flag at place /
; demolish time. Read by count_nearby_emergency_at_tmp.
police_count:
        .byte 0
police_org_x_arr:
        .fill ZONE_POP_MAX_COUNT, 0
police_org_y_arr:
        .fill ZONE_POP_MAX_COUNT, 0

; Fire-department HQ registry: identical shape to police, maintained via the
; STRUCT_FLAG_IS_FIRESTATION flag. count_nearby_emergency_at_tmp scans both.
firestation_count:
        .byte 0
firestation_org_x_arr:
        .fill ZONE_POP_MAX_COUNT, 0
firestation_org_y_arr:
        .fill ZONE_POP_MAX_COUNT, 0

; --- scratch ---
pop_tmp:                        ; 16-bit clamp scratch (zone_grow_x)
        .byte 0, 0
pop_tmp_idx:                    ; saved zone index across helper calls
        .byte 0
pop_tmp_cx:                     ; current zone's origin (monthly tick)
        .byte 0
pop_tmp_cy:
        .byte 0
pop_has_jobs_cache:             ; pre-computed once per monthly tick
        .byte 0
ira_x:                          ; perimeter scan position
        .byte 0
ira_y:
        .byte 0
; zone_apply_development_state scratch.
zad_road_mask:                  ; 4 bits: which sides of this zone have roads
        .byte 0
zad_pop_lo:                     ; cached zone_pop for the current zone
        .byte 0
zad_pop_hi:
        .byte 0
zad_rand:                       ; cached zone_rand for the current zone
        .byte 0
zad_changed:                    ; nonzero -> at least one cell changed; redraw
        .byte 0
zad_offset:                     ; current cell offset 0..8 in the 3x3 loop
        .byte 0
zad_jitter:                     ; per-cell threshold perturbation (0..31)
        .byte 0
zad_eff_h_lo:                   ; effective house threshold for current cell
        .byte 0
zad_eff_h_hi:
        .byte 0
zad_eff_a_lo:                   ; effective apartment threshold for current cell
        .byte 0
zad_eff_a_hi:
        .byte 0
zad_target:                     ; cell value to write
        .byte 0
zad_distance:                   ; Manhattan dist (capped 255) from this R zone
        .byte 0                 ; to the nearest C/I origin
zad_dist_lo:                    ; zad_distance << 2, as 16-bit, for threshold
        .byte 0                 ; bonus math (see zone_apply_development_state)
zad_dist_hi:
        .byte 0
cdw_dx:                         ; compute_zone_distance_to_workplace scratch
        .byte 0
cdw_dy:
        .byte 0
cdw_d:                          ; per-pair Manhattan distance
        .byte 0
cdw_y_save:                     ; Y-register save slot inside cdw_distance_then_min
        .byte 0
zad_nearby_ind:                 ; # of industrial origins within POLLUTION_RADIUS
        .byte 0                 ; of the current R zone (populated by
                                ; compute_zone_distance_to_workplace, consumed
                                ; by zone_apply_development_state)
zad_nearby_emergency:           ; # of emergency-service HQs (police + fire)
        .byte 0                 ; within EMERGENCY_RADIUS of the current zone.
                                ; Populated by count_nearby_emergency_at_tmp
                                ; once per zone in each monthly tick; consumed
                                ; by *_apply_development_state to subtract a
                                ; bonus from each cell's effective threshold.
zad_zone_traffic:               ; perceived traffic level (0..TRAFFIC_LEVEL_MAX)
        .byte 0                 ; on roads adjacent to the current zone.
                                ; Populated by count_zone_traffic_at_tmp;
                                ; consumed by *_apply_development_state for
                                ; the threshold penalty + *_grow_x for decay
                                ; when the level exceeds TRAFFIC_DECAY_LEVEL.
zad_traffic_penalty_lo:         ; zad_zone_traffic * TRAFFIC_PENALTY_STEP,
        .byte 0                 ; precomputed once per zone for cheap per-cell
zad_traffic_penalty_hi:         ; adds to eff_h / eff_a thresholds.
        .byte 0
ctr_x:                          ; traffic_recompute scratch -- inner loop cursor
        .byte 0
ctr_y:
        .byte 0
ctr_level:                      ; running traffic level for the cell being scored
        .byte 0
czt_dx:                         ; count_zone_traffic_at_tmp cell-offset scratch
        .byte 0
czt_dy:
        .byte 0
czt_level:                      ; running max over the perimeter scan
        .byte 0
zad_emergency_total_lo:         ; zad_nearby_emergency * EMERGENCY_BONUS_STEP,
        .byte 0                 ; precomputed once per zone so the per-cell
zad_emergency_total_hi:         ; loop subtracts a single 16-bit value
        .byte 0                 ; instead of looping.

pd_work:                        ; pop_to_digits 24-bit working copy
        .byte 0, 0, 0
pd_count:
        .byte 0
pop_digits:
        .fill 7, 0
pop_seen:
        .byte 0
