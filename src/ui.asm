;=======================================================================================
; Static SimCity-style UI frame.
;=======================================================================================

LOAD_UI_TILE .macro index, label
        lda #\index
        ldx #<\label
        ldy #>\label
        jsr create_ncm_char
.endmacro

ui_load:
        #LOAD_UI_TILE UI_TILE_PANEL, ui_data_panel
        #LOAD_UI_TILE UI_TILE_MENU, ui_data_menu
        #LOAD_UI_TILE UI_TILE_STATUS_LIGHT, ui_data_status_light
        #LOAD_UI_TILE UI_TILE_STATUS_DARK, ui_data_status_dark
        #LOAD_UI_TILE UI_TILE_FRAME, ui_data_frame
        #LOAD_UI_TILE UI_TILE_BOTTOM, ui_data_bottom
        #LOAD_UI_TILE UI_TILE_TOOL_ROAD, ui_data_tool_road
        #LOAD_UI_TILE UI_TILE_TOOL_RES, ui_data_tool_res
        #LOAD_UI_TILE UI_TILE_TOOL_COM, ui_data_tool_com
        #LOAD_UI_TILE UI_TILE_TOOL_IND, ui_data_tool_ind
        #LOAD_UI_TILE UI_TILE_TOOL_POWER, ui_data_tool_power
        #LOAD_UI_TILE UI_TILE_TOOL_WATER, ui_data_tool_water
        #LOAD_UI_TILE UI_TILE_HELP, ui_data_help
        #LOAD_UI_TILE UI_TILE_RCI_PANEL, ui_data_rci_panel
        rts

ui_data_panel:
        .fill 64, $0C

ui_data_menu:
        .fill 64, $0E

ui_data_status_light:
        .fill 64, $0C

ui_data_status_dark:
        .fill 64, $0B

ui_data_frame:
        .fill 64, $08

ui_data_bottom:
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$08

ui_data_tool_road:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$05,$05,$05,$05,$05,$05,$07
        .byte $07,$05,$06,$05,$05,$06,$05,$07
        .byte $07,$05,$05,$05,$05,$05,$05,$07
        .byte $07,$05,$05,$06,$05,$05,$06,$07
        .byte $07,$05,$05,$05,$05,$05,$05,$07
        .byte $07,$05,$05,$05,$05,$05,$05,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_tool_res:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$00,$0D,$0D,$0D,$00,$00,$07
        .byte $07,$0D,$00,$00,$00,$0D,$00,$07
        .byte $07,$0D,$00,$00,$00,$0D,$00,$07
        .byte $07,$0D,$0D,$0D,$0D,$00,$00,$07
        .byte $07,$0D,$00,$0D,$00,$00,$00,$07
        .byte $07,$0D,$00,$00,$0D,$00,$00,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_tool_com:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$00,$08,$08,$08,$08,$00,$07
        .byte $07,$08,$00,$00,$00,$00,$00,$07
        .byte $07,$08,$00,$00,$00,$00,$00,$07
        .byte $07,$08,$00,$00,$00,$00,$00,$07
        .byte $07,$08,$00,$00,$00,$00,$00,$07
        .byte $07,$00,$08,$08,$08,$08,$00,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_tool_ind:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$00,$09,$09,$09,$00,$00,$07
        .byte $07,$00,$00,$09,$00,$00,$00,$07
        .byte $07,$00,$00,$09,$00,$00,$00,$07
        .byte $07,$00,$00,$09,$00,$00,$00,$07
        .byte $07,$00,$00,$09,$00,$00,$00,$07
        .byte $07,$00,$09,$09,$09,$00,$00,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_tool_power:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$00,$00,$0A,$0A,$00,$00,$07
        .byte $07,$00,$0A,$0A,$00,$00,$00,$07
        .byte $07,$00,$00,$0A,$0A,$00,$00,$07
        .byte $07,$00,$00,$00,$0A,$0A,$00,$07
        .byte $07,$0B,$0B,$0A,$0A,$0B,$0B,$07
        .byte $07,$0B,$0B,$0B,$0B,$0B,$0B,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_tool_water:
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$01,$01,$01,$01,$01,$01,$07
        .byte $07,$01,$0E,$01,$01,$0E,$01,$07
        .byte $07,$01,$01,$01,$0E,$01,$01,$07
        .byte $07,$0E,$01,$01,$01,$01,$01,$07
        .byte $07,$01,$01,$0E,$01,$01,$0E,$07
        .byte $07,$01,$01,$01,$01,$01,$01,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07

ui_data_help:
        .byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
        .byte $0A,$00,$00,$00,$00,$00,$00,$0A
        .byte $0A,$00,$0B,$0B,$0B,$00,$00,$0A
        .byte $0A,$00,$00,$00,$0B,$00,$00,$0A
        .byte $0A,$00,$00,$0B,$00,$00,$00,$0A
        .byte $0A,$00,$00,$0B,$00,$00,$00,$0A
        .byte $0A,$00,$00,$00,$00,$00,$00,$0A
        .byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A

ui_data_rci_panel:
        .fill 64, $0F
