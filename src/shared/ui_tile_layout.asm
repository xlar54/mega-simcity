;=======================================================================================
; Shared UI tile definitions and asset layout.
;
; Single source of truth for the UI tile/glyph set: chrome tile IDs, the
; bitmap-font enum, the 16 toolbar button IDs, asset sizing, attic load
; addresses, and the byte offset of every tile inside the loadable `uitiles`
; asset. Self-contained (no platform.asm deps).
;
; Shared by assets/ui_tiles.asm (lays the payload down at these offsets),
; assets.asm (loads the asset from disk and DMAs each tile into char RAM) and
; render.asm (draws the tiles). Pulled in once via main.asm for the main
; program, and directly by the standalone assets/ui_tiles.asm build.
;=======================================================================================

; --- Chrome tile IDs (1x1 FCM chars) ---
UI_TILE_PANEL           = 64
UI_TILE_MENU            = 65
UI_TILE_STATUS_LIGHT    = 66
UI_TILE_STATUS_DARK     = 67
UI_TILE_FRAME           = 68
UI_TILE_BOTTOM          = 69

; --- Bitmap-font glyph IDs (1x1), contiguous A..colon ---
UI_TEXT_A               = UI_TILE_BOTTOM + 1
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
UI_TEXT_COUNT           = (UI_TEXT_COLON - UI_TEXT_A) + 1

; --- Toolbar buttons (2x2, 4 chars each): one consecutive block of UI_BTN_COUNT.
; Slot order is defined by the ui_btn_* data blocks in assets/ui_tiles.asm
; (bulldozer, road, rail, ...). Slot i has char id UI_BTN_BASE + i*4. (Per-button
; name constants are intentionally omitted: 64tass is case-insensitive, so a
; UI_BTN_ROAD constant would collide with the ui_btn_road: label.)
UI_BTN_COUNT            = 16
UI_BTN_BASE             = UI_TEXT_COLON + 1

; Coal-plant tile bitmaps live just above the UI buttons in char RAM (the zone
; "literal" map encoding can't reach this high, so the plant uses a translated
; value range -- see platform.asm COALPP_CELL_* and render.asm cell_to_char).
COALPP_CHAR_BASE        = UI_BTN_BASE + UI_BTN_COUNT * 4
NUCLEARPP_CHAR_BASE     = COALPP_CHAR_BASE + 12     ; right after the 12 coal-plant chars

; --- Top-strip menu buttons (2x2 each) ---
; All buttons live on rows 1-2 in the strip under MEGACITY. They are listed in
; a table in render.asm/toolbar.asm so adding more is a one-line append (col +
; tile id + char-base pair). Each button has an IDLE bitmap (raised: white top +
; left) and a SELECTED bitmap (pressed: black top + left); render_top_buttons
; picks between them based on selected_tile.
INSPECT_CHAR_BASE       = NUCLEARPP_CHAR_BASE + 12  ; pointer icon, idle (4 chars)
INSPECT_INSET_CHAR_BASE = INSPECT_CHAR_BASE + 4     ; pointer icon, selected (4 chars)
LOAD_CHAR_BASE          = INSPECT_INSET_CHAR_BASE + 4  ; disk + down-arrow, idle
LOAD_INSET_CHAR_BASE    = LOAD_CHAR_BASE + 4        ; disk + down-arrow, selected
SAVE_CHAR_BASE          = LOAD_INSET_CHAR_BASE + 4  ; disk + up-arrow, idle
SAVE_INSET_CHAR_BASE    = SAVE_CHAR_BASE + 4        ; disk + up-arrow, selected

; Tree autotile chars. 16 bitmaps, one per 4-neighbor mask. cell_to_char in
; render.asm maps cell value TREE_CELL_FIRST+mask to TREE_CHAR_BASE+mask.
TREE_CHAR_BASE          = SAVE_INSET_CHAR_BASE + 4      ; 222 -> 222..237

; Water-shoreline chars. 15 bitmaps, one per shoreline mask (0..14). Mask 15
; (interior, fully surrounded by water) keeps the existing TILE_WATER quadrant
; chars (0..3). cell_to_char maps WATER_SHORE_CELL_FIRST+mask to
; WATER_SHORE_CHAR_BASE+mask.
WATER_SHORE_CHAR_BASE   = TREE_CHAR_BASE + TREE_CELL_COUNT      ; 238 -> 238..252

; Power-bridge chars. 2 bitmaps (H/V). Road bridges piggy-back on the existing
; ROAD_CELL range (chars 21/22 in the city tileset), so they need no entry here.
POWER_BRIDGE_CHAR_BASE  = WATER_SHORE_CHAR_BASE + WATER_SHORE_CELL_COUNT  ; 253 -> 253..254

; Popup OK button chars (4x2 cells, 8 bitmaps). Scattered through the gaps in
; char RAM rather than a single contiguous range:
;   TL / TR (23, 27)   -- city-tileset slots, overwritten after the city DMA.
;                         TL=23 was a road-headroom slot; TR=27 was the old
;                         POWERLINE_CELL_POLE_V before powerline_refresh stopped
;                         writing it (see assets.asm tiles_load_powerlines).
;   BL..BO (59..63)    -- the 5-char hole between the zone block
;                         (ZONE_GEN_BASE..+ZONE_CELL_COUNT-1 = 32..58) and the
;                         chrome block (UI_TILE_PANEL = 64+).
;   BK                 -- continues the linear chain from POWER_BRIDGE_CHAR_BASE,
;                         so any new range below starts at BTN_OK_BK_CHAR + 1
;                         rather than colliding with this entry at 255.
BTN_OK_TL_CHAR          = 23
BTN_OK_TR_CHAR          = 27
BTN_OK_BL_CHAR          = 59
BTN_OK_BR_CHAR          = 60
BTN_OK_TO_CHAR          = 61
BTN_OK_TK_CHAR          = 62
BTN_OK_BO_CHAR          = 63
BTN_OK_BK_CHAR          = POWER_BRIDGE_CHAR_BASE + POWER_BRIDGE_CELL_COUNT  ; 255 today

INSPECT_ICON_COL        = 0
INSPECT_ICON_ROW        = 1
LOAD_ICON_COL           = 2
LOAD_ICON_ROW           = 1
SAVE_ICON_COL           = 4
SAVE_ICON_ROW           = 1
TOP_BTN_W               = 2     ; all top buttons are 2x2 cells
TOP_BTN_H               = 2

; cell_to_char (render.asm) plumbs a 16-bit char id (low byte in A, high byte in
; ctc_char_hi) through render_draw_tile + set_fcm_char16, so the ceiling is now
; the resident char-bank window rather than the 8-bit char-id range. CHAR_DATA
; lives at bank-4 $0000 and the bank-5 stage area starts at $10000, so each char
; bitmap (64 bytes) must satisfy char_id*64 < $10000 -> char_id < 1024.
        .cerror COALPP_CHAR_BASE + 12 > 1024, "coal plant chars exceed resident char-bank window"
        .cerror NUCLEARPP_CHAR_BASE + 12 > 1024, "nuclear plant chars exceed resident char-bank window"
        .cerror SAVE_INSET_CHAR_BASE + 4 > 1024, "top-strip button chars exceed resident char-bank window"
        .cerror TREE_CHAR_BASE + TREE_CELL_COUNT > 1024, "tree chars exceed resident char-bank window"
        .cerror WATER_SHORE_CHAR_BASE + WATER_SHORE_CELL_COUNT > 1024, "water shore chars exceed resident char-bank window"
        .cerror POWER_BRIDGE_CHAR_BASE + POWER_BRIDGE_CELL_COUNT > 1024, "power bridge chars exceed resident char-bank window"
        .cerror BTN_OK_BK_CHAR + 1 > 1024, "popup OK button BK char exceeds resident char-bank window"
        ; popup.asm overlay_draw_ok stamps the OK chars with set_fcm_char (8-bit),
        ; so every BTN_OK_*_CHAR must fit in a byte. BK is the only one that
        ; floats (anchored to POWER_BRIDGE_CHAR_BASE + COUNT), so cap it explicitly
        ; here. The mid-block and city-tileset slots are <= 63 by construction.
        .cerror BTN_OK_BK_CHAR > 255, "BTN_OK_BK_CHAR > 255: popup overlay_draw_ok needs set_fcm_char16"
        ; Guard the BL..BO mid-block against either side growing into it: zones
        ; below (32..58) and chrome above (UI_TILE_PANEL = 64+). Both edges are
        ; constants here, so the check is free.
        .cerror BTN_OK_BL_CHAR < ZONE_GEN_BASE + ZONE_CELL_COUNT, "OK button mid-block collides with zone chars"
        .cerror BTN_OK_BO_CHAR >= UI_TILE_PANEL, "OK button mid-block collides with chrome chars"

; --- Attic load address + asset sizing ---
; UI tiles are staged at Attic $2000 (not $1000) so the city tileset -- now large
; enough with the coal plant to exceed $1000 -- has room below it.
ATTIC_UI_TILE_MB        = $80
ATTIC_UI_TILE_BANK      = $00
ATTIC_UI_TILE_ADDR      = $2000
UI_TILE_CHAR_SIZE       = 64
UI_BTN_CELLS_X          = 2
UI_BTN_CELLS_Y          = 2
UI_BTN_TILE_SIZE        = UI_BTN_CELLS_X * UI_BTN_CELLS_Y * UI_TILE_CHAR_SIZE
; 6 chrome + UI_TEXT_COUNT glyphs are 1x1; UI_BTN_COUNT buttons are 2x2. The
; asset is just the tile payload in this order; the loader DMAs each tile from
; its compile-time offset below (no separate runtime index).
UI_TILE_ASSET_SIZE      = ((6 + UI_TEXT_COUNT) * UI_TILE_CHAR_SIZE) + (UI_BTN_COUNT * UI_BTN_TILE_SIZE)

; --- Payload byte offsets (producer <-> loader contract) ---
UI_ASSET_OFF_PANEL          = 0
UI_ASSET_OFF_MENU           = UI_ASSET_OFF_PANEL + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_STATUS_LIGHT   = UI_ASSET_OFF_MENU + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_STATUS_DARK    = UI_ASSET_OFF_STATUS_LIGHT + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_FRAME          = UI_ASSET_OFF_STATUS_DARK + UI_TILE_CHAR_SIZE
UI_ASSET_OFF_BOTTOM         = UI_ASSET_OFF_FRAME + UI_TILE_CHAR_SIZE
; Glyph run, then the 16-button block; both generated by .for loops in the
; producer and loader, so the sequences live in exactly one place each.
UI_TEXT_OFF_BASE            = UI_ASSET_OFF_BOTTOM + UI_TILE_CHAR_SIZE
UI_BTN_OFF_BASE             = UI_TEXT_OFF_BASE + (UI_TEXT_COUNT * UI_TILE_CHAR_SIZE)
