;=======================================================================================
; Structure descriptor table + generic multi-cell placement.
;
; Each row describes one multi-cell building's footprint, map-cell encoding, art
; location, cost, and behaviour flags, so generic code (cps_structure, the
; structure branch of cell_to_char) can handle every entry without per-building
; branches. R/C/I zones use a separate range translation (ZONE_CELL_FIRST..LAST
; in platform.asm) handled directly by cell_to_char and cps_zone in city.asm;
; 1x1 tools (road / power line / bulldoze / water) stay on theirs.
;
; Adding a new building from here is mostly: one row in this table; tile art in
; tileset.asm; a DMA entry in assets.asm; a toolbar slot wire in toolbar.asm; and
; -- only for a new footprint size -- a sprite cursor shape.
;=======================================================================================

; Flag bits.
STRUCT_FLAG_OVERWRITE_POWER = $01    ; may overwrite power-line cells (zone-like)
STRUCT_FLAG_IS_POWER_SOURCE = $02    ; register origin with power_register_plant

; Per-row tuning constants referenced from the table below.
COAL_OUTPUT       = 40              ; zones powered per coal plant (docs/TILE_RULES.md)
NUCLEARPP_OUTPUT  = 120             ; zones powered per nuclear plant

; --- The table (parallel byte arrays; one column per row). ---
struct_tool_id:        .byte TILE_COALPP,                    TILE_NUCLEARPP
struct_cols:           .byte COALPP_COLS,                    NUCLEARPP_COLS
struct_rows:           .byte COALPP_ROWS,                    NUCLEARPP_ROWS
struct_cell_base:      .byte COALPP_CELL_FIRST,              NUCLEARPP_CELL_FIRST
struct_cell_count:     .byte COALPP_CELL_COUNT,              NUCLEARPP_CELL_COUNT
struct_char_base_lo:   .byte <COALPP_CHAR_BASE,              <NUCLEARPP_CHAR_BASE
struct_char_base_hi:   .byte >COALPP_CHAR_BASE,              >NUCLEARPP_CHAR_BASE
struct_cost_lo:        .byte <COST_COALPP,                   <COST_NUCLEARPP
struct_cost_hi:        .byte >COST_COALPP,                   >COST_NUCLEARPP
struct_flags:          .byte STRUCT_FLAG_OVERWRITE_POWER | STRUCT_FLAG_IS_POWER_SOURCE, STRUCT_FLAG_OVERWRITE_POWER | STRUCT_FLAG_IS_POWER_SOURCE
struct_output:         .byte COAL_OUTPUT,                    NUCLEARPP_OUTPUT

struct_count           = 2

; Carry SET if cell value A is in any structure's [cell_base, cell_base+count)
; range. A is preserved. Used by powerline orientation (zones/plants are
; "structures" that a line points toward) and by other table-driven cell tests.
is_structure_cell:
        sta isc_value
        ldy #0
_isc_loop:
        cpy #struct_count
        bcs _isc_no
        lda isc_value
        cmp struct_cell_base,y
        bcc _isc_next
        sec
        sbc struct_cell_base,y
        cmp struct_cell_count,y
        bcc _isc_yes
_isc_next:
        iny
        bra _isc_loop
_isc_no:
        lda isc_value
        clc
        rts
_isc_yes:
        lda isc_value
        sec
        rts

; Carry SET if cell value A is in a structure row whose STRUCT_FLAG_IS_POWER_SOURCE
; flag is set (i.e., a plant cell of any kind). A is preserved.
is_power_source_cell:
        sta isc_value
        ldy #0
_ipsc_loop:
        cpy #struct_count
        bcs _ipsc_no
        lda struct_flags,y
        and #STRUCT_FLAG_IS_POWER_SOURCE
        beq _ipsc_next
        lda isc_value
        cmp struct_cell_base,y
        bcc _ipsc_next
        sec
        sbc struct_cell_base,y
        cmp struct_cell_count,y
        bcc _ipsc_yes
_ipsc_next:
        iny
        bra _ipsc_loop
_ipsc_no:
        lda isc_value
        clc
        rts
_ipsc_yes:
        lda isc_value
        sec
        rts

; Locate a structure by its tool_id. In: A = tool_id. Out: carry SET and X = row
; index if matched; carry CLEAR if no structure handles this tool. A is preserved.
structure_find_by_tool:
        ldx #0
_sfbt_loop:
        cpx #struct_count
        bcs _sfbt_no
        cmp struct_tool_id,x
        beq _sfbt_yes
        inx
        bra _sfbt_loop
_sfbt_no:
        clc
        rts
_sfbt_yes:
        sec
        rts

;---------------------------------------------------------------------------------------
; Generic placement: A = structure index. Origin = pointer cell, clamped so the
; W x H footprint fits; placed iff every cell is buildable per flags and the
; player can afford it. Reuses zone_org_x/y and the zone border re-tiler.
;---------------------------------------------------------------------------------------

cps_structure:
        sta struct_idx
        tax
        ; Clamp origin x.
        lda view_x
        asl
        clc
        adc mouse_cell_x
        sta cs_tmp_x
        sec
        lda #CELL_COLS
        sbc struct_cols,x
        sta cs_max
        lda cs_tmp_x
        cmp cs_max
        bcc _cs_x_ok
        beq _cs_x_ok
        lda cs_max
_cs_x_ok:
        sta zone_org_x
        ; Clamp origin y.
        ldx struct_idx
        lda view_y
        asl
        clc
        adc mouse_cell_y
        sta cs_tmp_y
        sec
        lda #CELL_ROWS
        sbc struct_rows,x
        sta cs_max
        lda cs_tmp_y
        cmp cs_max
        bcc _cs_y_ok
        beq _cs_y_ok
        lda cs_max
_cs_y_ok:
        sta zone_org_y

        ldx struct_idx
        jsr structure_can_place
        bcc _cs_no
        ldx struct_idx
        lda struct_cost_lo,x
        sta cost_amount
        lda struct_cost_hi,x
        sta cost_amount+1
        jsr funds_can_afford
        bcc _cs_no
        jsr funds_subtract
        ldx struct_idx
        jsr structure_stamp
        jsr power_mark_dirty
        ldx struct_idx
        lda struct_flags,x
        and #STRUCT_FLAG_IS_POWER_SOURCE
        beq _cs_no_register
        jsr power_register_plant
_cs_no_register:
        jsr audio_construct
        ldx struct_idx
        jsr structure_redraw
        ldx struct_idx
        lda struct_cols,x
        clc
        adc #2
        sta zrb_w
        lda struct_rows,x
        clc
        adc #2
        sta zrb_h
        jmp city_zone_refresh_border
_cs_no:
        rts

;---------------------------------------------------------------------------------------
; X = structure index. Carry SET if every cell of the footprint at zone_org_x/y
; is buildable: TILE_GROUND always counts; a power-line cell counts only when
; STRUCT_FLAG_OVERWRITE_POWER is set on this structure.
;---------------------------------------------------------------------------------------
structure_can_place:
        lda #0
        sta cs_dy
_scp_row:
        lda #0
        sta cs_dx
_scp_col:
        clc
        lda zone_org_x
        adc cs_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc cs_dy
        sta city_ptr_y
        jsr city_cell_ptr               ; preserves X
        ldz #0
        lda [MAP_PTR],z
        cmp #TILE_GROUND
        beq _scp_ok
        lda struct_flags,x
        and #STRUCT_FLAG_OVERWRITE_POWER
        beq _scp_no
        ldz #0
        lda [MAP_PTR],z
        jsr is_powerline_value          ; preserves X
        bcc _scp_no
_scp_ok:
        inc cs_dx
        lda cs_dx
        cmp struct_cols,x
        bne _scp_col
        inc cs_dy
        lda cs_dy
        cmp struct_rows,x
        bne _scp_row
        sec
        rts
_scp_no:
        clc
        rts

;---------------------------------------------------------------------------------------
; X = structure index. Writes each cell as struct_cell_base + (dy*cols + dx).
;---------------------------------------------------------------------------------------
structure_stamp:
        lda #0
        sta cs_dy
_sts_row:
        lda #0
        sta cs_dx
_sts_col:
        clc
        lda zone_org_x
        adc cs_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc cs_dy
        sta city_ptr_y
        jsr city_cell_ptr
        ; cell value = struct_cell_base[x] + (cs_dy * struct_cols[x] + cs_dx)
        lda cs_dy
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        lda struct_cols,x
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        clc
        lda MULTOUT
        adc cs_dx
        clc
        adc struct_cell_base,x
        ldz #0
        sta [MAP_PTR],z
        inc cs_dx
        lda cs_dx
        cmp struct_cols,x
        bne _sts_col
        inc cs_dy
        lda cs_dy
        cmp struct_rows,x
        bne _sts_row
        rts

;---------------------------------------------------------------------------------------
; X = structure index. Redraw each cell's containing tile (duplicate calls land
; on the same tile and are harmless).
;---------------------------------------------------------------------------------------
structure_redraw:
        lda #0
        sta cs_dy
_srd_row:
        lda #0
        sta cs_dx
_srd_col:
        clc
        lda zone_org_x
        adc cs_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc cs_dy
        sta city_ptr_y
        jsr render_redraw_cell_tile     ; clobbers X
        ldx struct_idx                  ; reload for the loop test
        inc cs_dx
        lda cs_dx
        cmp struct_cols,x
        bne _srd_col
        inc cs_dy
        lda cs_dy
        cmp struct_rows,x
        bne _srd_row
        rts

;---------------------------------------------------------------------------------------
; Whole-plant demolition. The 1x1 bulldozer in city.asm falls through here when
; the targeted cell turns out to be inside a multi-cell structure footprint
; (coal plant, nuclear plant, ...). Tearing the entire footprint down keeps the
; power model honest: power.asm/power_sum_capacity grants the plant's full
; struct_output to every still-registered origin, so a one-cell remnant would
; otherwise keep producing 40/120 zones of power. With the whole footprint
; cleared to TILE_GROUND, power_seed prunes the origin from plant_origin_* on
; the next recompute and the output goes to zero.
;
; Input:   A = cell value (caller has confirmed it's a structure cell via
;              is_structure_cell), city_ptr_x/y = cell coords of A.
; Action:  finds the structure row; recovers its origin from the cell offset;
;          charges the full footprint bulldoze cost (COST_BULLDOZE * cols * rows);
;          stamps TILE_GROUND across the entire footprint and redraws every
;          covered tile; plays the explosion sfx; marks the power network dirty;
;          refreshes the perimeter (roads + power lines re-orient around the
;          now-empty rect). Silently bails if the player can't afford the cost.
;---------------------------------------------------------------------------------------
structure_demolish_at_cell:
        sta sdc_value
        ; Find the struct row whose [cell_base, cell_base+count) contains A.
        ldy #0
_sdc_find:
        cpy #struct_count
        bcs _sdc_done                   ; defensive: shouldn't happen if caller checked
        lda sdc_value
        cmp struct_cell_base,y
        bcc _sdc_find_next
        sec
        sbc struct_cell_base,y          ; A = offset within the structure footprint
        cmp struct_cell_count,y
        bcc _sdc_found
_sdc_find_next:
        iny
        bra _sdc_find
_sdc_found:
        sta sdc_offset
        sty sdc_row

        ; (dx, dy) = (offset mod cols, offset / cols) by iterative subtract.
        ; cols is small (3 today) so this runs at most rows-1 iterations.
        ldz #0                          ; quotient = dy
        lda sdc_offset
_sdc_div:
        cmp struct_cols,y
        bcc _sdc_div_done
        sec
        sbc struct_cols,y
        inz
        bra _sdc_div
_sdc_div_done:
        sta sdc_dx                      ; remainder = dx
        tza
        sta sdc_dy                      ; quotient = dy

        ; origin = (city_ptr_x - dx, city_ptr_y - dy). The footprint is fully
        ; on-map by construction (placement clamps origin), so no underflow.
        sec
        lda city_ptr_x
        sbc sdc_dx
        sta zone_org_x
        sec
        lda city_ptr_y
        sbc sdc_dy
        sta zone_org_y

        ; cost = COST_BULLDOZE * cols * rows. cols*rows is up to 12 today,
        ; COST_BULLDOZE is $1, so this fits in a byte today -- but compute with
        ; the full 16-bit width so growing either constant doesn't bite later.
        ldx sdc_row
        lda struct_cols,x
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3
        lda struct_rows,x
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3
        lda MULTOUT
        sta MULTINA                     ; cols*rows -> first input
        lda MULTOUT+1
        sta MULTINA+1
        lda #0
        sta MULTINA+2
        sta MULTINA+3
        lda #<COST_BULLDOZE
        sta MULTINB
        lda #>COST_BULLDOZE
        sta MULTINB+1
        lda #0
        sta MULTINB+2
        sta MULTINB+3
        lda MULTOUT
        sta cost_amount
        lda MULTOUT+1
        sta cost_amount+1

        jsr funds_can_afford
        bcc _sdc_done                   ; can't afford -> silent bail (no change)
        jsr funds_subtract

        ; Stamp TILE_GROUND across the full footprint + redraw each tile.
        ldx sdc_row
        lda #0
        sta cs_dy
_sdc_row:
        lda #0
        sta cs_dx
_sdc_col:
        clc
        lda zone_org_x
        adc cs_dx
        sta city_ptr_x
        clc
        lda zone_org_y
        adc cs_dy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda #TILE_GROUND
        sta [MAP_PTR],z
        jsr render_redraw_cell_tile     ; clobbers X
        ldx sdc_row
        inc cs_dx
        lda cs_dx
        cmp struct_cols,x
        bne _sdc_col
        inc cs_dy
        lda cs_dy
        cmp struct_rows,x
        bne _sdc_row

        jsr power_mark_dirty            ; power_seed prunes the origin next pass
        jsr audio_explosion

        ; Border refresh: roads + power lines around the now-empty footprint
        ; re-orient. Same idiom cps_structure uses for placement.
        ldx sdc_row
        lda struct_cols,x
        clc
        adc #2
        sta zrb_w
        lda struct_rows,x
        clc
        adc #2
        sta zrb_h
        jmp city_zone_refresh_border    ; tail call
_sdc_done:
        rts

; --- scratch ---
struct_idx:                     ; currently-dispatched row in the table
        .byte 0
cs_tmp_x:                       ; cps_structure: proposed origin (pre-clamp)
        .byte 0
cs_tmp_y:
        .byte 0
cs_max:                         ; cps_structure: max valid origin coord (clamp limit)
        .byte 0
cs_dx:                          ; W x H stamp/redraw/can_place loop counters
        .byte 0
cs_dy:
        .byte 0
isc_value:                      ; scratch for is_structure_cell / is_power_source_cell
        .byte 0
sdc_value:                      ; structure_demolish_at_cell scratch
        .byte 0
sdc_offset:
        .byte 0
sdc_row:
        .byte 0
sdc_dx:
        .byte 0
sdc_dy:
        .byte 0
