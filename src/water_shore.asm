;=======================================================================================
; Water shoreline autotile.
;
; Mirrors trees.asm. Each water cell carries the same 4-neighbor mask in the low
; 4 bits, encoded so a set bit means "that neighbor is also water" (so the
; shoreline is drawn on the OPPOSITE sides -- where there's no water neighbor).
; Interior cells (mask 15, fully surrounded by water) are kept as plain
; TILE_WATER so they continue to use the original 4-quadrant ripple chars at
; chars 0..3. Edge cells (mask 0..14) get rewritten to WATER_SHORE_CELL_FIRST +
; mask, which cell_to_char maps to WATER_SHORE_CHAR_BASE + mask.
;
; Established two ways, just like trees:
;   * world-gen: lakes are placed as plain TILE_WATER; world_gen_autotile_water
;     does one full-map pass.
;   * Runtime water-tool paint: city.asm _cps_2x2_write writes a 2x2 of
;     TILE_WATER then calls water_shore_refresh_neighbors so the newly added
;     water cells and their borders re-tile.
;=======================================================================================

;---------------------------------------------------------------------------------------
; Carry SET if A is a water cell -- either plain TILE_WATER (mask 15, interior)
; or any shoreline variant. Preserves A.
;---------------------------------------------------------------------------------------
is_water_value:
        cmp #TILE_WATER
        beq _iwv_yes
        cmp #WATER_SHORE_CELL_FIRST
        bcc _iwv_no
        cmp #WATER_SHORE_CELL_LAST+1
        bcs _iwv_no
_iwv_yes:
        sec
        rts
_iwv_no:
        clc
        rts

;---------------------------------------------------------------------------------------
; Read the cell value at (X, Y). Out: A = value, $FF if out of bounds.
; Carry SET on OOB. Clobbers MAP_PTR, city_ptr_*.
;---------------------------------------------------------------------------------------
water_cell_at_xy:
        cpx #CELL_COLS
        bcs _wcaxy_oob
        cpy #CELL_ROWS
        bcs _wcaxy_oob
        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        clc
        rts
_wcaxy_oob:
        lda #$FF
        sec
        rts

;---------------------------------------------------------------------------------------
; Compute the 4-neighbor water mask for the cell at (X, Y). Out: A = mask.
; Out-of-map neighbors count as "not water" so the shore curves at the map edge.
;---------------------------------------------------------------------------------------
water_compute_mask_at:
        stx water_cx
        sty water_cy
        lda #0
        sta water_mask

        ; N
        ldx water_cx
        ldy water_cy
        dey
        jsr water_cell_at_xy
        jsr is_water_value
        bcc +
        lda water_mask
        ora #WATER_BIT_N
        sta water_mask
+
        ; S
        ldx water_cx
        ldy water_cy
        iny
        jsr water_cell_at_xy
        jsr is_water_value
        bcc +
        lda water_mask
        ora #WATER_BIT_S
        sta water_mask
+
        ; E
        ldx water_cx
        inx
        ldy water_cy
        jsr water_cell_at_xy
        jsr is_water_value
        bcc +
        lda water_mask
        ora #WATER_BIT_E
        sta water_mask
+
        ; W
        ldx water_cx
        dex
        ldy water_cy
        jsr water_cell_at_xy
        jsr is_water_value
        bcc +
        lda water_mask
        ora #WATER_BIT_W
        sta water_mask
+
        lda water_mask
        rts

;---------------------------------------------------------------------------------------
; If (X, Y) is in bounds AND a water cell, recompute its mask and write the
; new value: TILE_WATER if mask == 15 (fully interior), else
; WATER_SHORE_CELL_FIRST + mask (edge variant). NO redraw. Used by the bulk
; autotile pass.
;---------------------------------------------------------------------------------------
water_compute_at:
        cpx #CELL_COLS
        bcs _wca_done
        cpy #CELL_ROWS
        bcs _wca_done
        stx water_cx_outer
        sty water_cy_outer

        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_water_value
        bcc _wca_done

        ldx water_cx_outer
        ldy water_cy_outer
        jsr water_compute_mask_at       ; A = mask
        cmp #15
        bne _wca_shore
        lda #TILE_WATER                 ; mask 15 -> interior, plain water
        bra _wca_write
_wca_shore:
        clc
        adc #WATER_SHORE_CELL_FIRST     ; A = shoreline cell value
_wca_write:
        pha                             ; city_cell_ptr clobbers A
        ldx water_cx_outer
        stx city_ptr_x
        ldy water_cy_outer
        sty city_ptr_y
        jsr city_cell_ptr
        pla
        ldz #0
        sta [MAP_PTR],z
_wca_done:
        rts

;---------------------------------------------------------------------------------------
; Same as water_compute_at + redraw the containing 16x16 tile. Used by the
; runtime water-tool refresh so the new shoreline is visible immediately.
;---------------------------------------------------------------------------------------
water_shore_refresh_at:
        cpx #CELL_COLS
        bcs _wsra_done
        cpy #CELL_ROWS
        bcs _wsra_done
        stx water_cx_outer
        sty water_cy_outer

        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_water_value
        bcc _wsra_done

        ldx water_cx_outer
        ldy water_cy_outer
        jsr water_compute_mask_at
        cmp #15
        bne _wsra_shore
        lda #TILE_WATER
        bra _wsra_write
_wsra_shore:
        clc
        adc #WATER_SHORE_CELL_FIRST
_wsra_write:
        pha
        ldx water_cx_outer
        stx city_ptr_x
        ldy water_cy_outer
        sty city_ptr_y
        jsr city_cell_ptr
        pla
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_x/y still set
_wsra_done:
        rts

;---------------------------------------------------------------------------------------
; Refresh the cell at (city_ptr_x, city_ptr_y) PLUS its 4 cardinal neighbors.
; Used by the runtime water-paint path: after the tool writes a 2x2 block of
; TILE_WATER, calling this for each of the 4 placed cells re-tiles them and
; their adjacent ground/water cells so shorelines curve correctly. (The
; 4 neighbors include the 3 cells inside the same 2x2 block on the appropriate
; iterations, plus the cells outside the block on each edge.)
;---------------------------------------------------------------------------------------
water_shore_refresh_neighbors:
        lda city_ptr_x
        sta wsrn_cx
        lda city_ptr_y
        sta wsrn_cy

        ldx wsrn_cx                     ; self -- in case the placed cell is now an edge
        ldy wsrn_cy
        jsr water_shore_refresh_at

        ldx wsrn_cx                     ; N
        ldy wsrn_cy
        dey
        jsr water_shore_refresh_at

        ldx wsrn_cx                     ; S
        ldy wsrn_cy
        iny
        jsr water_shore_refresh_at

        ldx wsrn_cx                     ; E
        inx
        ldy wsrn_cy
        jsr water_shore_refresh_at

        ldx wsrn_cx                     ; W
        dex
        ldy wsrn_cy
        jsr water_shore_refresh_at
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
water_cx:               .byte 0
water_cy:               .byte 0
water_mask:             .byte 0
water_cx_outer:         .byte 0
water_cy_outer:         .byte 0
wsrn_cx:                .byte 0
wsrn_cy:                .byte 0
