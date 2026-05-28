;=======================================================================================
; Tree autotile.
;
; Trees are 1x1 cells whose value carries a 4-neighbor mask (TREE_BIT_N|S|E|W)
; in the low 4 bits: cell value = TREE_CELL_FIRST + mask. cell_to_char maps each
; mask to its own bitmap (TREE_CHAR_BASE + mask), so the renderer never has to
; look at neighbors at draw time -- the mask is precomputed and stored.
;
; The mask is established two ways:
;
;   * Initial world-gen: world_gen.asm seeds trees with mask=0 (isolated), then
;     calls a full-map autotile pass that asks this module to recompute every
;     tree cell's mask once.
;
;   * Bulldoze: when the player removes a tree, the 4 neighbors may have stale
;     masks (they used to count the removed cell as a neighbor). The bulldoze
;     path in city.asm calls tree_refresh_neighbors after writing TILE_GROUND.
;
; All routines operate on cell coordinates (cx, cy); out-of-map coordinates are
; treated as "not a tree" so edges and corners just work.
;=======================================================================================

;---------------------------------------------------------------------------------------
; Carry SET if A is in the tree-cell range [TREE_CELL_FIRST, TREE_CELL_LAST].
; Preserves A.
;---------------------------------------------------------------------------------------
is_tree_value:
        cmp #TREE_CELL_FIRST
        bcc _itv_no
        cmp #TREE_CELL_LAST+1
        bcs _itv_no
        sec
        rts
_itv_no:
        clc
        rts

;---------------------------------------------------------------------------------------
; Read the cell value at (X, Y). Out: A = value, or $FF if (X, Y) is out of map
; bounds. Carry SET on out-of-bounds. Clobbers MAP_PTR + city_ptr_*.
;---------------------------------------------------------------------------------------
tree_cell_at_xy:
        cpx #CELL_COLS
        bcs _tcaxy_oob
        cpy #CELL_ROWS
        bcs _tcaxy_oob
        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        clc
        rts
_tcaxy_oob:
        lda #$FF
        sec
        rts

;---------------------------------------------------------------------------------------
; Compute the 4-neighbor tree mask for the cell at (X, Y). Out: A = mask in
; [0, 15]. Out-of-map neighbors count as "not a tree". Clobbers MAP_PTR +
; city_ptr_*.
;---------------------------------------------------------------------------------------
tree_compute_mask_at:
        stx tree_cx
        sty tree_cy
        lda #0
        sta tree_mask

        ; N: (cx, cy-1)
        ldx tree_cx
        ldy tree_cy
        dey
        jsr tree_cell_at_xy
        jsr is_tree_value
        bcc +
        lda tree_mask
        ora #TREE_BIT_N
        sta tree_mask
+
        ; S: (cx, cy+1)
        ldx tree_cx
        ldy tree_cy
        iny
        jsr tree_cell_at_xy
        jsr is_tree_value
        bcc +
        lda tree_mask
        ora #TREE_BIT_S
        sta tree_mask
+
        ; E: (cx+1, cy)
        ldx tree_cx
        inx
        ldy tree_cy
        jsr tree_cell_at_xy
        jsr is_tree_value
        bcc +
        lda tree_mask
        ora #TREE_BIT_E
        sta tree_mask
+
        ; W: (cx-1, cy)
        ldx tree_cx
        dex
        ldy tree_cy
        jsr tree_cell_at_xy
        jsr is_tree_value
        bcc +
        lda tree_mask
        ora #TREE_BIT_W
        sta tree_mask
+
        lda tree_mask
        rts

;---------------------------------------------------------------------------------------
; If (X, Y) is in bounds AND holds a tree cell, recompute its 4-neighbor mask
; and write the new value (TREE_CELL_FIRST + mask). NO redraw -- used by the
; bulk autotile pass at boot. OOB / non-tree cells are skipped silently.
;---------------------------------------------------------------------------------------
tree_compute_at:
        cpx #CELL_COLS
        bcs _tca_done
        cpy #CELL_ROWS
        bcs _tca_done
        stx tree_cx_outer
        sty tree_cy_outer

        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_tree_value
        bcc _tca_done

        ldx tree_cx_outer
        ldy tree_cy_outer
        jsr tree_compute_mask_at        ; A = mask
        clc
        adc #TREE_CELL_FIRST            ; A = new cell value

        pha                             ; city_cell_ptr clobbers A -- save the new value
        ldx tree_cx_outer
        stx city_ptr_x
        ldy tree_cy_outer
        sty city_ptr_y
        jsr city_cell_ptr               ; re-fetch MAP_PTR -- tree_compute_mask_at clobbered it
        pla
        ldz #0
        sta [MAP_PTR],z
_tca_done:
        rts

;---------------------------------------------------------------------------------------
; Same as tree_compute_at + redraw the containing 16x16 tile. Used by the
; bulldoze path's neighbor refresh (changes are visible immediately).
;---------------------------------------------------------------------------------------
tree_refresh_at:
        cpx #CELL_COLS
        bcs _tra_done
        cpy #CELL_ROWS
        bcs _tra_done
        stx tree_cx_outer
        sty tree_cy_outer

        stx city_ptr_x
        sty city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_tree_value
        bcc _tra_done

        ldx tree_cx_outer
        ldy tree_cy_outer
        jsr tree_compute_mask_at
        clc
        adc #TREE_CELL_FIRST

        pha                             ; city_cell_ptr clobbers A
        ldx tree_cx_outer
        stx city_ptr_x
        ldy tree_cy_outer
        sty city_ptr_y
        jsr city_cell_ptr
        pla
        ldz #0
        sta [MAP_PTR],z
        jmp render_redraw_cell_tile     ; city_ptr_x/y still set
_tra_done:
        rts

;---------------------------------------------------------------------------------------
; Refresh the 4 neighbors of the cell at (city_ptr_x, city_ptr_y). Called by
; the bulldoze path AFTER writing TILE_GROUND so each adjacent tree's mask
; drops the now-removed neighbor and redraws with the right edge bitmap.
;---------------------------------------------------------------------------------------
tree_refresh_neighbors:
        lda city_ptr_x
        sta trn_cx
        lda city_ptr_y
        sta trn_cy

        ldx trn_cx          ; N
        ldy trn_cy
        dey
        jsr tree_refresh_at

        ldx trn_cx          ; S
        ldy trn_cy
        iny
        jsr tree_refresh_at

        ldx trn_cx          ; E
        inx
        ldy trn_cy
        jsr tree_refresh_at

        ldx trn_cx          ; W
        dex
        ldy trn_cy
        jsr tree_refresh_at
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
tree_cx:                .byte 0     ; scratch for the mask-compute neighbor walk
tree_cy:                .byte 0
tree_mask:              .byte 0
tree_cx_outer:          .byte 0     ; saved across tree_compute_mask_at's clobber
tree_cy_outer:          .byte 0
trn_cx:                 .byte 0     ; saved across tree_refresh_neighbors' 4 calls
trn_cy:                 .byte 0
