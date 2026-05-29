;=======================================================================================
; Tile name lookup.
;
; tile_name_for_cell(A) -> X:Y = string pointer, A = length
;
; Maps a map-cell value to a short uppercase label suitable for the popup
; title bar. Range-dispatch follows the same intervals cell_to_char uses, so
; adding a new cell range is one new `cmp / bcc / label_jmp` line here.
;
; Strings live as byte arrays of UI_TEXT_* glyph ids -- the popup renderer
; stamps them straight onto screen RAM with set_fcm_char. Lengths are .cerror-
; guarded against POPUP_TITLE_MAX so they fit in the title bar.
;=======================================================================================

;---------------------------------------------------------------------------------------
; tile_name_for_cell
;   In : A = cell value
;   Out: X:Y = ptr lo:hi, A = length
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
        cmp #(RAIL_CELL_BRIDGE_H)   ; 155..167 -> plain rail (incl. *_POWER cross)
        bcc _tnfc_rail
        cmp #(RAIL_CELL_H_ROAD)
        bcc _tnfc_rbridge           ; 168..169 -> rail bridge
        cmp #RAIL_CELL_LAST+1
        bcc _tnfc_rroad             ; 170..171 -> rail+road crossing
        ; fall through to unknown for 172..255

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
