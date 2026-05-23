;=======================================================================================
; UI tile loader.
;
; Copies the UI tiles/glyphs from the `uitiles` asset (loaded into attic RAM at
; boot) into char RAM via DMA. The per-tile source offsets come from the shared
; layout that the asset producer (assets/ui_tiles.asm) also uses, so the two
; never drift. platform.asm is already included by main.asm before this module.
;=======================================================================================

        .include "shared/ui_tile_layout.asm"

UI_TILE_DMA .macro index, size, offset
        lda #$00
        sta $D707
        .byte $80, ATTIC_UI_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word \size
        .word ATTIC_UI_TILE_ADDR + UI_TILE_INDEX_SIZE + \offset
        .byte ATTIC_UI_TILE_BANK
        .word \index * UI_TILE_CHAR_SIZE
        .byte `CHAR_DATA
        .byte $00
        .word $0000
.endmacro

ui_load:
        #UI_TILE_DMA UI_TILE_PANEL, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_PANEL
        #UI_TILE_DMA UI_TILE_MENU, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_MENU
        #UI_TILE_DMA UI_TILE_STATUS_LIGHT, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_STATUS_LIGHT
        #UI_TILE_DMA UI_TILE_STATUS_DARK, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_STATUS_DARK
        #UI_TILE_DMA UI_TILE_FRAME, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_FRAME
        #UI_TILE_DMA UI_TILE_BOTTOM, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_BOTTOM
        #UI_TILE_DMA UI_TILE_TOOL_ROAD, UI_ROAD_ICON_SIZE, UI_ASSET_OFF_TOOL_ROAD
        #UI_TILE_DMA UI_TILE_TOOL_RES, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_TOOL_RES
        #UI_TILE_DMA UI_TILE_TOOL_COM, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_TOOL_COM
        #UI_TILE_DMA UI_TILE_TOOL_IND, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_TOOL_IND
        #UI_TILE_DMA UI_TILE_TOOL_POWER, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_TOOL_POWER
        #UI_TILE_DMA UI_TILE_TOOL_WATER, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_TOOL_WATER
        #UI_TILE_DMA UI_TILE_HELP, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_HELP
        #UI_TILE_DMA UI_TILE_RCI_PANEL, UI_TILE_CHAR_SIZE, UI_ASSET_OFF_RCI_PANEL
.for i = 0, i < UI_TEXT_COUNT, i = i + 1
        #UI_TILE_DMA (UI_TEXT_A + i), UI_TILE_CHAR_SIZE, UI_TEXT_OFF_BASE + i * UI_TILE_CHAR_SIZE
.next
        rts
