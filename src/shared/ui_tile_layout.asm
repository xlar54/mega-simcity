;=======================================================================================
; Shared UI tile asset layout.
;
; The byte offset of every UI tile/glyph inside the loadable `uitiles` asset.
; This is the contract between the producer (assets/ui_tiles.asm, which lays the
; payload bytes down at these offsets) and the consumer (tileloader.asm, which
; DMAs each tile from these offsets). Both include this file so the two can
; never drift.
;
; Depends on the UI_TILE_*/UI_TEXT_* IDs and sizes from platform.asm, which must
; be included first.
;=======================================================================================

UI_ASSET_OFF_PANEL          = 0
UI_ASSET_OFF_MENU           = UI_ASSET_OFF_PANEL + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_STATUS_LIGHT   = UI_ASSET_OFF_MENU + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_STATUS_DARK    = UI_ASSET_OFF_STATUS_LIGHT + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_FRAME          = UI_ASSET_OFF_STATUS_DARK + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_BOTTOM         = UI_ASSET_OFF_FRAME + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_TOOL_ROAD      = UI_ASSET_OFF_BOTTOM + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_AFTER_ROAD     = UI_ASSET_OFF_TOOL_ROAD + UI_ROAD_ICON_SIZE
UI_ASSET_OFF_TOOL_RES       = UI_ASSET_OFF_AFTER_ROAD
UI_ASSET_OFF_TOOL_COM       = UI_ASSET_OFF_TOOL_RES + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_TOOL_IND       = UI_ASSET_OFF_TOOL_COM + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_TOOL_POWER     = UI_ASSET_OFF_TOOL_IND + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_TOOL_WATER     = UI_ASSET_OFF_TOOL_POWER + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_HELP           = UI_ASSET_OFF_TOOL_WATER + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_RCI_PANEL      = UI_ASSET_OFF_HELP + UI_TILE_CHAR_SIZE

; The text glyphs (A-Z, 0-9, comma/dot/dollar/colon) are a uniform run of
; UI_TILE_CHAR_SIZE chars with contiguous tile IDs (UI_TEXT_A..UI_TEXT_COLON,
; from platform.asm), laid out contiguously in the asset payload. The producer
; and loader generate their per-glyph entries with .for loops, so the sequence
; is spelled out only once (the UI_TEXT_* enum) plus the ui_glyph_* data, which
; MUST stay in the same A..colon order.
UI_TEXT_OFF_BASE            = UI_ASSET_OFF_RCI_PANEL + UI_TILE_CHAR_SIZE
UI_TEXT_COUNT               = (UI_TEXT_COLON - UI_TEXT_A) + 1
