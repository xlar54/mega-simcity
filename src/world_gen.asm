;=======================================================================================
; World generation.
;
; Builds the initial map at city_init time: drunkard's-walk lakes, drunkard's-walk
; forest patches, then a single full-map pass that rewrites every tree cell's
; value with its 4-neighbor mask (TREE_CELL_FIRST + mask) so cell_to_char can
; pick the right autotile bitmap.
;
; A 16-bit Galois LFSR (poly $B400, full 65535-period) supplies all randomness.
; Fixed seed during dev so test maps are reproducible; later we'll reseed from
; the MEGA65 RTC at boot.
;
; Tunables are constants so we can balance density without touching code.
;=======================================================================================

WORLDGEN_SEED   = $ACE1

LAKE_COUNT      = 12
LAKE_STEPS      = 200           ; drunkard's-walk cells written per lake

FOREST_COUNT    = 40
FOREST_STEPS    = 200           ; drunkard's-walk cells written per forest patch

WG_DIR_N        = 0
WG_DIR_S        = 1
WG_DIR_E        = 2
WG_DIR_W        = 3

;---------------------------------------------------------------------------------------
; Public entry. Assumes city_fill_ground has already filled every cell with
; TILE_GROUND. Walks each pass, then runs the tree-autotile rewrite at the end.
;---------------------------------------------------------------------------------------
world_gen_run:
        lda #<WORLDGEN_SEED
        sta worldgen_rng
        lda #>WORLDGEN_SEED
        sta worldgen_rng+1

        jsr world_gen_lakes
        jsr world_gen_autotile_water    ; shoreline tiles for the just-placed lakes
        jsr world_gen_forests
        jsr world_gen_autotile_trees
        rts

;---------------------------------------------------------------------------------------
; 16-bit Galois LFSR. Returns the next pseudo-random word; A = low byte on exit.
; Caller can read worldgen_rng+1 for the high byte if it needs more entropy.
;---------------------------------------------------------------------------------------
worldgen_next:
        lsr worldgen_rng+1
        ror worldgen_rng        ; carry out = output bit
        bcc +
        lda worldgen_rng+1      ; output bit 1 -> XOR state with poly $B400
        eor #$B4                ; (low byte of poly is $00, so low needs no XOR)
        sta worldgen_rng+1
+       lda worldgen_rng
        rts

; Write A to the cell at (wg_walk_cx, wg_walk_cy). Bounds were enforced by the
; walker (drunkard's-walk steps that would leave the map are clamped).
;
; If wg_walk_only_ground is nonzero, the write is gated on the current cell
; being TILE_GROUND -- so the forest walker doesn't stomp lakes or freshly-
; tiled shorelines on its way through them. The walker still advances through
; non-ground cells; it just doesn't paint over them. Lakes leave the flag at 0
; and overwrite ground unconditionally.
world_gen_write_walker:
        pha
        lda wg_walk_cx
        sta city_ptr_x
        lda wg_walk_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda wg_walk_only_ground
        beq _wgww_write             ; unconditional write
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        bne _wgww_skip              ; lake / shore / earlier tree -> leave it alone
_wgww_write:
        pla
        sta [MAP_PTR],z
        rts
_wgww_skip:
        pla
        rts

;---------------------------------------------------------------------------------------
; Drunkard's-walk lake. Picks a random starting cell, then steps N times in
; random N/S/E/W directions; each step writes TILE_WATER. Edges clamp the
; walker so a long random run can't escape the map.
;---------------------------------------------------------------------------------------
world_gen_lakes:
        lda #0
        sta wg_walk_only_ground     ; lakes overwrite whatever's there
        lda #LAKE_COUNT
        sta wg_remaining
_wgl_loop:
        lda wg_remaining
        beq _wgl_done

        jsr worldgen_next                ; random start cell
        jsr wg_random_cx
        sta wg_walk_cx
        jsr worldgen_next
        jsr wg_random_cy
        sta wg_walk_cy

        lda #LAKE_STEPS
        sta wg_steps
        lda #TILE_WATER
        sta wg_walk_value
        jsr world_gen_walk

        dec wg_remaining
        bra _wgl_loop
_wgl_done:
        rts

;---------------------------------------------------------------------------------------
; Drunkard's-walk forest patch. Same as lakes but writes TREE_CELL_FIRST (the
; mask=0 "isolated" tree). world_gen_autotile_trees will rewrite each cell's
; mask afterward.
;---------------------------------------------------------------------------------------
world_gen_forests:
        lda #1
        sta wg_walk_only_ground     ; don't stomp lakes/shorelines placed earlier
        lda #FOREST_COUNT
        sta wg_remaining
_wgf_loop:
        lda wg_remaining
        beq _wgf_done

        jsr worldgen_next
        jsr wg_random_cx
        sta wg_walk_cx
        jsr worldgen_next
        jsr wg_random_cy
        sta wg_walk_cy

        lda #FOREST_STEPS
        sta wg_steps
        lda #TREE_CELL_FIRST
        sta wg_walk_value
        jsr world_gen_walk

        dec wg_remaining
        bra _wgf_loop
_wgf_done:
        rts

;---------------------------------------------------------------------------------------
; Run the drunkard's walker. Writes wg_walk_value at (wg_walk_cx, wg_walk_cy),
; then steps in a random N/S/E/W direction; repeats wg_steps times. Walker
; clamps to map bounds (a step that would leave the map is just skipped).
;---------------------------------------------------------------------------------------
world_gen_walk:
_wgw_step:
        lda wg_walk_value
        jsr world_gen_write_walker

        jsr worldgen_next
        and #$03                ; 0=N, 1=S, 2=E, 3=W
        tax
        cpx #WG_DIR_N
        beq _wgw_n
        cpx #WG_DIR_S
        beq _wgw_s
        cpx #WG_DIR_E
        beq _wgw_e
        ; W
        lda wg_walk_cx
        beq _wgw_step_done
        dec wg_walk_cx
        bra _wgw_step_done
_wgw_n:
        lda wg_walk_cy
        beq _wgw_step_done
        dec wg_walk_cy
        bra _wgw_step_done
_wgw_s:
        lda wg_walk_cy
        cmp #CELL_ROWS - 1
        bcs _wgw_step_done
        inc wg_walk_cy
        bra _wgw_step_done
_wgw_e:
        lda wg_walk_cx
        cmp #CELL_COLS - 1
        bcs _wgw_step_done
        inc wg_walk_cx
_wgw_step_done:
        dec wg_steps
        bne _wgw_step
        rts

; A -> random cx in [0, CELL_COLS). CELL_COLS=240 < 256, so one subtraction
; max brings any A in 0..255 into range.
wg_random_cx:
        cmp #CELL_COLS
        bcc +
        sec
        sbc #CELL_COLS
+       rts

; A -> random cy in [0, CELL_ROWS). CELL_ROWS=200; worst case A=255 needs one
; subtraction to land in 0..199 -- but if A is in [200, 255], one subtract gives
; A-200 in [0, 55]. Good enough; the bias toward the top is small and we don't
; need a precise uniform distribution for a few dozen patch centers.
wg_random_cy:
        cmp #CELL_ROWS
        bcc +
        sec
        sbc #CELL_ROWS
+       rts

;---------------------------------------------------------------------------------------
; Autotile pass: walk every cell, delegating to water_compute_at
; (water_shore.asm) which skips non-water cells and rewrites edge water with
; the appropriate shoreline value (or keeps it as plain TILE_WATER for
; interior). One pass is enough since the mask is purely local.
;---------------------------------------------------------------------------------------
world_gen_autotile_water:
        lda #0
        sta wg_at_cy
_wgaw_row:
        lda #0
        sta wg_at_cx
_wgaw_col:
        ldx wg_at_cx
        ldy wg_at_cy
        jsr water_compute_at
        inc wg_at_cx
        lda wg_at_cx
        cmp #CELL_COLS
        bne _wgaw_col
        inc wg_at_cy
        lda wg_at_cy
        cmp #CELL_ROWS
        bne _wgaw_row
        rts

;---------------------------------------------------------------------------------------
; Autotile pass: walk every cell, delegating to tree_compute_at (trees.asm)
; which skips non-tree cells and rewrites trees with their 4-neighbor mask.
; One pass over the map is enough since the mask is purely a function of the
; current neighbor state.
;---------------------------------------------------------------------------------------
world_gen_autotile_trees:
        lda #0
        sta wg_at_cy
_wgat_row:
        lda #0
        sta wg_at_cx
_wgat_col:
        ldx wg_at_cx
        ldy wg_at_cy
        jsr tree_compute_at
        inc wg_at_cx
        lda wg_at_cx
        cmp #CELL_COLS
        bne _wgat_col
        inc wg_at_cy
        lda wg_at_cy
        cmp #CELL_ROWS
        bne _wgat_row
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
worldgen_rng:           .word 0

wg_remaining:           .byte 0     ; patches/lakes left
wg_steps:               .byte 0     ; walker steps left
wg_walk_cx:             .byte 0     ; walker position
wg_walk_cy:             .byte 0
wg_walk_value:          .byte 0     ; cell value to write each step

wg_at_cx:               .byte 0     ; autotile pass position
wg_at_cy:               .byte 0

wg_walk_only_ground:    .byte 0     ; nonzero -> walker skips writes onto non-ground cells
