;=======================================================================================
; Inspect overlay (PRG, compiles to $A000 -- shared CPU window with ovr-save
; and ovr-load).
;
; Loaded from disk at boot into Attic ($87.0000) by boot_load_ovr_inspect; on
; INSPECT click the main game DMAs this overlay from Attic to $A000 and enters
; via jsr ovr_inspect_main with MAP_PTR already pointing at the inspected
; cell (city.asm sets that up before invoke). The overlay reads the cell
; value, looks up its short uppercase label, sets the default popup geometry
; (16x8 centred), and opens the popup. Control returns immediately -- the
; main game's mouse_dispatch / overlay_handle_click take over once the popup
; is up. The popup closes on the next OK click via the resident overlay_*
; helpers in popup.asm.
;
; This used to be three pieces of resident code (popup.asm's caller in
; city.asm + the str_* tables + tile_name_for_cell). Moving the lookup table
; and the orchestration into a disk-loaded overlay frees ~500 bytes of
; resident memory; the cell range dispatch matches cell_to_char's intervals
; so adding a new tile category is one new `cmp / bcc / label` line.
;=======================================================================================

        .cpu "45gs02"

        ; Main game labels: every global symbol from mega-simcity, including
        ; the resident popup helpers (overlay_open, overlay_set_default_
        ; geometry), screen-write helper (set_fcm_char), and every UI_TEXT_*
        ; glyph id + cell-range constant referenced below.
        .include "../../target/mega-simcity.lbl"

        * = OVR_WINDOW_ADDR

;---------------------------------------------------------------------------------------
; ovr_inspect_main
; Entry point. Caller (city.asm _cps_inspect) has set city_ptr_x/y and called
; city_cell_ptr so MAP_PTR points at the inspected cell. We read the cell,
; look up its label, configure the default-sized popup, open it, and rts.
;---------------------------------------------------------------------------------------
ovr_inspect_main:
        ldz #0
        lda [MAP_PTR],z                  ; A = cell value
        jsr tile_name_for_cell            ; X = ptr lo, Y = ptr hi, A = length
        ; Stash so we can re-load A:X:Y in overlay_open's calling convention
        ; (A = ptr lo, X = ptr hi, Y = length).
        sta inspect_title_len_tmp
        stx inspect_title_lo_tmp
        sty inspect_title_hi_tmp
        jsr overlay_set_default_geometry  ; 16x8 cells centred at row 8
        lda inspect_title_lo_tmp
        ldx inspect_title_hi_tmp
        ldy inspect_title_len_tmp
        jsr overlay_open
        rts

;---------------------------------------------------------------------------------------
; tile_name_for_cell(A) -> X:Y = string pointer, A = length
;
; Maps a map-cell value to a short uppercase label suitable for the popup
; title bar. Range-dispatch follows the same intervals cell_to_char uses,
; so adding a new cell range is one new `cmp / bcc / label_jmp` line.
;
; Strings live as byte arrays of UI_TEXT_* glyph ids -- overlay_open's title
; renderer stamps them straight onto screen RAM. Lengths are .cerror-guarded
; against POPUP_TITLE_MAX so they fit in the default popup's title bar.
;---------------------------------------------------------------------------------------
tile_name_for_cell:
        cmp #TILE_WATER
        beq _tnfc_water
        cmp #TILE_GROUND
        beq _tnfc_ground
        cmp #ROAD_CELL_FIRST
        bcc _tnfc_unknown
        cmp #ROAD_CELL_BRIDGE_H
        bcc _tnfc_road              ; 8..20
        cmp #ROAD_CELL_BRIDGE_V+1
        bcc _tnfc_bridge            ; 21..22
        cmp #POWERLINE_CELL_FIRST
        bcc _tnfc_unknown
        cmp #POWERLINE_CELL_LAST+1
        bcc _tnfc_power             ; 24..27
        cmp #COALPP_CELL_FIRST
        bcc _tnfc_unknown
        cmp #COALPP_CELL_LAST+1
        bcc _tnfc_coal              ; 71..82
        cmp #NUCLEARPP_CELL_LAST+1
        bcc _tnfc_nuclear           ; 83..94
        cmp #TREE_CELL_LAST+1
        bcc _tnfc_forest            ; 95..110
        cmp #WATER_SHORE_CELL_LAST+1
        bcc _tnfc_shore             ; 111..125
        cmp #(ZONE_CELL_FIRST+9)
        bcc _tnfc_res               ; 126..134
        cmp #(ZONE_CELL_FIRST+18)
        bcc _tnfc_com               ; 135..143
        cmp #ZONE_CELL_LAST+1
        bcc _tnfc_ind               ; 144..152
        cmp #POWER_BRIDGE_CELL_LAST+1
        bcc _tnfc_pbridge           ; 153..154
        cmp #RAIL_CELL_FIRST
        bcc _tnfc_unknown
        cmp #(RAIL_CELL_BRIDGE_H)
        bcc _tnfc_rail              ; 155..167 (incl. *_POWER cross)
        cmp #(RAIL_CELL_H_ROAD)
        bcc _tnfc_rbridge           ; 168..169
        cmp #RAIL_CELL_LAST+1
        bcc _tnfc_rroad             ; 170..171
        cmp #DEBRIS_CELL_FIRST
        bcc _tnfc_unknown
        cmp #DEBRIS_CELL_LAST+1
        bcc _tnfc_debris            ; 172
        cmp #PARK_CELL_FIRST
        bcc _tnfc_unknown
        cmp #PARK_CELL_LAST+1
        bcc _tnfc_park              ; 173..188
        cmp #POLICE_CELL_FIRST
        bcc _tnfc_unknown
        cmp #POLICE_CELL_LAST+1
        bcc _tnfc_police            ; 189..204
        ; fall through to unknown for 205..255

_tnfc_unknown:
        ldx #<str_unknown
        ldy #>str_unknown
        lda #str_unknown_len
        rts
_tnfc_water:
        ldx #<str_water
        ldy #>str_water
        lda #str_water_len
        rts
_tnfc_ground:
        ldx #<str_ground
        ldy #>str_ground
        lda #str_ground_len
        rts
_tnfc_road:
        ldx #<str_road
        ldy #>str_road
        lda #str_road_len
        rts
_tnfc_bridge:
        ldx #<str_bridge
        ldy #>str_bridge
        lda #str_bridge_len
        rts
_tnfc_power:
        ldx #<str_power
        ldy #>str_power
        lda #str_power_len
        rts
_tnfc_coal:
        ldx #<str_coal
        ldy #>str_coal
        lda #str_coal_len
        rts
_tnfc_nuclear:
        ldx #<str_nuclear
        ldy #>str_nuclear
        lda #str_nuclear_len
        rts
_tnfc_forest:
        ldx #<str_forest
        ldy #>str_forest
        lda #str_forest_len
        rts
_tnfc_shore:
        ldx #<str_shore
        ldy #>str_shore
        lda #str_shore_len
        rts
_tnfc_res:
        ldx #<str_res
        ldy #>str_res
        lda #str_res_len
        rts
_tnfc_com:
        ldx #<str_com
        ldy #>str_com
        lda #str_com_len
        rts
_tnfc_ind:
        ldx #<str_ind
        ldy #>str_ind
        lda #str_ind_len
        rts
_tnfc_pbridge:
        ldx #<str_pbridge
        ldy #>str_pbridge
        lda #str_pbridge_len
        rts
_tnfc_rail:
        ldx #<str_rail
        ldy #>str_rail
        lda #str_rail_len
        rts
_tnfc_rbridge:
        ldx #<str_rbridge
        ldy #>str_rbridge
        lda #str_rbridge_len
        rts
_tnfc_rroad:
        ldx #<str_rroad
        ldy #>str_rroad
        lda #str_rroad_len
        rts
_tnfc_debris:
        ldx #<str_debris
        ldy #>str_debris
        lda #str_debris_len
        rts
_tnfc_park:
        ldx #<str_park
        ldy #>str_park
        lda #str_park_len
        rts
_tnfc_police:
        ldx #<str_police
        ldy #>str_police
        lda #str_police_len
        rts

;---------------------------------------------------------------------------------------
; Strings -- bytes are UI_TEXT_* char ids.
;---------------------------------------------------------------------------------------
str_water:      .byte UI_TEXT_W, UI_TEXT_A, UI_TEXT_T, UI_TEXT_E, UI_TEXT_R
str_water_len   = * - str_water

str_ground:     .byte UI_TEXT_G, UI_TEXT_R, UI_TEXT_O, UI_TEXT_U, UI_TEXT_N, UI_TEXT_D
str_ground_len  = * - str_ground

str_road:       .byte UI_TEXT_R, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D
str_road_len    = * - str_road

str_bridge:     .byte UI_TEXT_B, UI_TEXT_R, UI_TEXT_I, UI_TEXT_D, UI_TEXT_G, UI_TEXT_E
str_bridge_len  = * - str_bridge

str_power:      .byte UI_TEXT_P, UI_TEXT_O, UI_TEXT_W, UI_TEXT_E, UI_TEXT_R
str_power_len   = * - str_power

str_coal:       .byte UI_TEXT_C, UI_TEXT_O, UI_TEXT_A, UI_TEXT_L
str_coal_len    = * - str_coal

str_nuclear:    .byte UI_TEXT_N, UI_TEXT_U, UI_TEXT_C, UI_TEXT_L, UI_TEXT_E, UI_TEXT_A, UI_TEXT_R
str_nuclear_len = * - str_nuclear

str_forest:     .byte UI_TEXT_F, UI_TEXT_O, UI_TEXT_R, UI_TEXT_E, UI_TEXT_S, UI_TEXT_T
str_forest_len  = * - str_forest

str_shore:      .byte UI_TEXT_S, UI_TEXT_H, UI_TEXT_O, UI_TEXT_R, UI_TEXT_E
str_shore_len   = * - str_shore

str_res:        .byte UI_TEXT_H, UI_TEXT_O, UI_TEXT_U, UI_TEXT_S, UI_TEXT_I, UI_TEXT_N, UI_TEXT_G
str_res_len     = * - str_res

str_com:        .byte UI_TEXT_C, UI_TEXT_O, UI_TEXT_M, UI_TEXT_M, UI_TEXT_E, UI_TEXT_R, UI_TEXT_C, UI_TEXT_E
str_com_len     = * - str_com

str_ind:        .byte UI_TEXT_I, UI_TEXT_N, UI_TEXT_D, UI_TEXT_U, UI_TEXT_S, UI_TEXT_T, UI_TEXT_R, UI_TEXT_Y
str_ind_len     = * - str_ind

str_pbridge:    .byte UI_TEXT_P, UI_TEXT_O, UI_TEXT_W, UI_TEXT_E, UI_TEXT_R, UI_TEXT_DOT, UI_TEXT_B, UI_TEXT_R, UI_TEXT_I, UI_TEXT_D, UI_TEXT_G, UI_TEXT_E
str_pbridge_len = * - str_pbridge

str_rail:       .byte UI_TEXT_R, UI_TEXT_A, UI_TEXT_I, UI_TEXT_L
str_rail_len    = * - str_rail

str_rbridge:    .byte UI_TEXT_R, UI_TEXT_A, UI_TEXT_I, UI_TEXT_L, UI_TEXT_DOT, UI_TEXT_B, UI_TEXT_R, UI_TEXT_I, UI_TEXT_D, UI_TEXT_G, UI_TEXT_E
str_rbridge_len = * - str_rbridge

str_rroad:      .byte UI_TEXT_R, UI_TEXT_A, UI_TEXT_I, UI_TEXT_L, UI_TEXT_DOT, UI_TEXT_R, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D
str_rroad_len   = * - str_rroad

str_debris:     .byte UI_TEXT_D, UI_TEXT_E, UI_TEXT_B, UI_TEXT_R, UI_TEXT_I, UI_TEXT_S
str_debris_len  = * - str_debris

str_park:       .byte UI_TEXT_P, UI_TEXT_A, UI_TEXT_R, UI_TEXT_K
str_park_len    = * - str_park

str_police:     .byte UI_TEXT_P, UI_TEXT_O, UI_TEXT_L, UI_TEXT_I, UI_TEXT_C, UI_TEXT_E
str_police_len  = * - str_police

str_unknown:    .byte UI_TEXT_DOT, UI_TEXT_DOT, UI_TEXT_DOT
str_unknown_len = * - str_unknown

        .cerror str_water_len   > POPUP_TITLE_MAX, "WATER label too long"
        .cerror str_ground_len  > POPUP_TITLE_MAX, "GROUND label too long"
        .cerror str_road_len    > POPUP_TITLE_MAX, "ROAD label too long"
        .cerror str_bridge_len  > POPUP_TITLE_MAX, "BRIDGE label too long"
        .cerror str_power_len   > POPUP_TITLE_MAX, "POWER label too long"
        .cerror str_coal_len    > POPUP_TITLE_MAX, "COAL label too long"
        .cerror str_nuclear_len > POPUP_TITLE_MAX, "NUCLEAR label too long"
        .cerror str_forest_len  > POPUP_TITLE_MAX, "FOREST label too long"
        .cerror str_shore_len   > POPUP_TITLE_MAX, "SHORE label too long"
        .cerror str_res_len     > POPUP_TITLE_MAX, "HOUSING label too long"
        .cerror str_com_len     > POPUP_TITLE_MAX, "COMMERCE label too long"
        .cerror str_ind_len     > POPUP_TITLE_MAX, "INDUSTRY label too long"
        .cerror str_pbridge_len > POPUP_TITLE_MAX, "POWER.BRIDGE label too long"
        .cerror str_rail_len    > POPUP_TITLE_MAX, "RAIL label too long"
        .cerror str_rbridge_len > POPUP_TITLE_MAX, "RAIL.BRIDGE label too long"
        .cerror str_rroad_len   > POPUP_TITLE_MAX, "RAIL.ROAD label too long"
        .cerror str_debris_len  > POPUP_TITLE_MAX, "DEBRIS label too long"
        .cerror str_park_len    > POPUP_TITLE_MAX, "PARK label too long"
        .cerror str_police_len  > POPUP_TITLE_MAX, "POLICE label too long"

;---------------------------------------------------------------------------------------
; Scratch -- shuffle bytes between tile_name_for_cell's X/Y/A return order
; and overlay_open's A/X/Y calling convention.
;---------------------------------------------------------------------------------------
inspect_title_lo_tmp:   .byte 0
inspect_title_hi_tmp:   .byte 0
inspect_title_len_tmp:  .byte 0

        ; Sanity: the assembled overlay must end before $B000 (window upper
        ; bound). Inspect doesn't fill the whole 4KB the way save/load do --
        ; just verify we didn't accidentally overflow.
        .cerror * > OVR_WINDOW_ADDR + OVR_WINDOW_SIZE, "inspect overlay overflowed its $1000-byte window"
