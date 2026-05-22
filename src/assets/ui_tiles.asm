;=======================================================================================
; 8x8 UI/NCM tiles loaded from disk at boot.
;
; Record format:
;   .word tile id
;   .word payload size
;   .byte payload bytes
;=======================================================================================

        .cpu "45gs02"
        .include "../platform.inc"

UI_TILE_ASSET_BUILD = 1

        * = $6800

ui_tiles_start:
        .include "../ui.asm"
ui_tiles_end:

        .cerror ui_tiles_end - ui_tiles_start != UI_TILE_ASSET_SIZE, "UI tile asset size mismatch"
