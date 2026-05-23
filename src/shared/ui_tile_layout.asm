;=======================================================================================
; Shared UI tile definitions and asset layout.
;
; Single source of truth for the UI tile/glyph set: tile IDs, the bitmap-font
; enum, asset sizing, attic load addresses, and the byte offset of every tile
; inside the loadable `uitiles` asset. Self-contained (no platform.asm deps).
;
; Shared by assets/ui_tiles.asm (lays the payload down at these offsets),
; tileloader.asm (DMAs from them), assets.asm (loads the asset from disk) and
; render.asm (draws the tiles). Pulled in once via main.asm for the main
; program, and directly by the standalone assets/ui_tiles.asm build.
;=======================================================================================

; --- Tile and glyph IDs (NCM screen codes) ---
UI_TILE_PANEL           = 64
UI_TILE_MENU            = 65
UI_TILE_STATUS_LIGHT    = 66
UI_TILE_STATUS_DARK     = 67
UI_TILE_FRAME           = 68
UI_TILE_BOTTOM          = 69
UI_TILE_TOOL_ROAD       = 70
UI_TILE_TOOL_ROAD_CHARS = 4
UI_TILE_TOOL_RES        = UI_TILE_TOOL_ROAD + UI_TILE_TOOL_ROAD_CHARS
UI_TILE_TOOL_COM        = UI_TILE_TOOL_RES + 1
UI_TILE_TOOL_IND        = UI_TILE_TOOL_COM + 1
UI_TILE_TOOL_POWER      = UI_TILE_TOOL_IND + 1
UI_TILE_TOOL_WATER      = UI_TILE_TOOL_POWER + 1
UI_TILE_HELP            = UI_TILE_TOOL_WATER + 1
UI_TILE_RCI_PANEL       = UI_TILE_HELP + 1
UI_TEXT_A               = UI_TILE_RCI_PANEL + 1
UI_TEXT_B               = UI_TEXT_A + 1
UI_TEXT_C               = UI_TEXT_B + 1
UI_TEXT_D               = UI_TEXT_C + 1
UI_TEXT_E               = UI_TEXT_D + 1
UI_TEXT_F               = UI_TEXT_E + 1
UI_TEXT_G               = UI_TEXT_F + 1
UI_TEXT_H               = UI_TEXT_G + 1
UI_TEXT_I               = UI_TEXT_H + 1
UI_TEXT_J               = UI_TEXT_I + 1
UI_TEXT_K               = UI_TEXT_J + 1
UI_TEXT_L               = UI_TEXT_K + 1
UI_TEXT_M               = UI_TEXT_L + 1
UI_TEXT_N               = UI_TEXT_M + 1
UI_TEXT_O               = UI_TEXT_N + 1
UI_TEXT_P               = UI_TEXT_O + 1
UI_TEXT_Q               = UI_TEXT_P + 1
UI_TEXT_R               = UI_TEXT_Q + 1
UI_TEXT_S               = UI_TEXT_R + 1
UI_TEXT_T               = UI_TEXT_S + 1
UI_TEXT_U               = UI_TEXT_T + 1
UI_TEXT_V               = UI_TEXT_U + 1
UI_TEXT_W               = UI_TEXT_V + 1
UI_TEXT_X               = UI_TEXT_W + 1
UI_TEXT_Y               = UI_TEXT_X + 1
UI_TEXT_Z               = UI_TEXT_Y + 1
UI_TEXT_0               = UI_TEXT_Z + 1
UI_TEXT_1               = UI_TEXT_0 + 1
UI_TEXT_2               = UI_TEXT_1 + 1
UI_TEXT_3               = UI_TEXT_2 + 1
UI_TEXT_4               = UI_TEXT_3 + 1
UI_TEXT_5               = UI_TEXT_4 + 1
UI_TEXT_6               = UI_TEXT_5 + 1
UI_TEXT_7               = UI_TEXT_6 + 1
UI_TEXT_8               = UI_TEXT_7 + 1
UI_TEXT_9               = UI_TEXT_8 + 1
UI_TEXT_COMMA           = UI_TEXT_9 + 1
UI_TEXT_DOT             = UI_TEXT_COMMA + 1
UI_TEXT_DOLLAR          = UI_TEXT_DOT + 1
UI_TEXT_COLON           = UI_TEXT_DOLLAR + 1

; --- Attic load address + asset sizing ---
ATTIC_UI_TILE_MB        = $80
ATTIC_UI_TILE_BANK      = $00
ATTIC_UI_TILE_ADDR      = $1000
UI_TILE_CHAR_SIZE       = 64
UI_TILE_INDEX_ENTRY_SIZE = 8
UI_TILE_ASSET_COUNT     = 54
UI_TILE_INDEX_SIZE      = UI_TILE_ASSET_COUNT * UI_TILE_INDEX_ENTRY_SIZE
UI_ROAD_ICON_CELLS_X    = 2
UI_ROAD_ICON_CELLS_Y    = 2
UI_ROAD_ICON_SIZE       = UI_ROAD_ICON_CELLS_X * UI_ROAD_ICON_CELLS_Y * UI_TILE_CHAR_SIZE
UI_TILE_PAYLOAD_SIZE    = ((UI_TILE_ASSET_COUNT - 1) * UI_TILE_CHAR_SIZE) + UI_ROAD_ICON_SIZE
UI_TILE_ASSET_SIZE      = UI_TILE_INDEX_SIZE + UI_TILE_PAYLOAD_SIZE

; --- Payload byte offsets (producer <-> loader contract) ---
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
