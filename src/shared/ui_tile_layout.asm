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
; Single disk-options button consolidates the old LOAD + SAVE pair into one
; folder icon. Clicking it opens the disk-options overlay (ovr-disk).
DISK_CHAR_BASE          = INSPECT_INSET_CHAR_BASE + 4  ; folder icon, idle
DISK_INSET_CHAR_BASE    = DISK_CHAR_BASE + 4        ; folder icon, selected
; Single divider-line glyph used by the disk overlay to draw borders above /
; below the menu buttons. Light-grey ($0C) panel background with a 1-pixel
; black ($00) line through the middle, so stamping it across the popup
; width makes a clean horizontal rule.
DISK_LINE_CHAR          = DISK_INSET_CHAR_BASE + 4

; Tree autotile chars. 16 bitmaps, one per 4-neighbor mask. cell_to_char in
; render.asm maps cell value TREE_CELL_FIRST+mask to TREE_CHAR_BASE+mask.
; (Was at SAVE_INSET_CHAR_BASE + 4 before LOAD/SAVE were merged; the merge
;  freed 8 chars, so this and every range above shift DOWN by 8.)
TREE_CHAR_BASE          = DISK_LINE_CHAR + 1

; Water-shoreline chars. 15 bitmaps, one per shoreline mask (0..14). Mask 15
; (interior, fully surrounded by water) keeps the existing TILE_WATER quadrant
; chars (0..3). cell_to_char maps WATER_SHORE_CELL_FIRST+mask to
; WATER_SHORE_CHAR_BASE+mask.
WATER_SHORE_CHAR_BASE   = TREE_CHAR_BASE + TREE_CELL_COUNT

; Power-bridge chars. 2 bitmaps (H/V). Road bridges piggy-back on the existing
; ROAD_CELL range (chars 21/22 in the city tileset), so they need no entry here.
POWER_BRIDGE_CHAR_BASE  = WATER_SHORE_CHAR_BASE + WATER_SHORE_CELL_COUNT

; Popup OK button chars (4x2 cells, 8 bitmaps). Scattered through the gaps in
; char RAM rather than a single contiguous range:
;   TL / TR (23, 27)   -- city-tileset slots, overwritten after the city DMA.
;                         TL=23 is a road-headroom slot; TR=27 is the old
;                         POWERLINE_CELL_POLE_V char, now retired from the map
;                         encoding (platform.asm POWERLINE_CELL_LAST stops at
;                         POLE_H=26) so this slot belongs exclusively to the
;                         popup. The tileset bitmap at slot 27 is left in place
;                         for asset-layout stability; BTN_OK_TR overwrites it.
;   BL..BO (59..63)    -- the 5-char hole between the zone block
;                         (ZONE_GEN_BASE..+ZONE_CELL_COUNT-1 = 32..58) and the
;                         chrome block (UI_TILE_PANEL = 64+).
;   BK                 -- continues the linear chain from POWER_BRIDGE_CHAR_BASE,
;                         so any new range below starts at BTN_OK_BK_CHAR + 1
;                         rather than colliding with this entry.
BTN_OK_TL_CHAR          = 23
BTN_OK_TR_CHAR          = 27
BTN_OK_BL_CHAR          = 59
BTN_OK_BR_CHAR          = 60
BTN_OK_TO_CHAR          = 61
BTN_OK_TK_CHAR          = 62
BTN_OK_BO_CHAR          = 63
BTN_OK_BK_CHAR          = POWER_BRIDGE_CHAR_BASE + POWER_BRIDGE_CELL_COUNT

; Rail chars. 17 bitmaps: H, V, 4-way, 4 curves, 4 T-junctions, H_POWER,
; V_POWER, BRIDGE_H/V, and road crossings -- one per RAIL_CELL_* offset.
; Cell-to-char translates RAIL_CELL_FIRST + offset to RAIL_CHAR_BASE + offset.
; This range crosses the 8-bit char-id boundary, so the render path must keep
; using set_fcm_char16/create_fcm_char16 for high chars.
RAIL_CHAR_BASE          = BTN_OK_BK_CHAR + 1

; Debris char. A single rubble-pattern bitmap left behind when a structure is
; bulldozed; cell_to_char translates DEBRIS_CELL_FIRST -> DEBRIS_CHAR_BASE.
DEBRIS_CHAR_BASE        = RAIL_CHAR_BASE + RAIL_CELL_COUNT

; Park chars. 16 bitmaps for the 4x4 park (corner trees, edge grass, centre
; fountain). cell_to_char goes through the structures.asm dispatch -- park
; chars get loaded via struct_char_base_lo/hi lookups.
PARK_CHAR_BASE          = DEBRIS_CHAR_BASE + DEBRIS_CELL_COUNT

; Police chars. 9 bitmaps for the 3x3 police department. Same struct-table
; dispatch as park.
POLICE_CHAR_BASE        = PARK_CHAR_BASE + PARK_CELL_COUNT

; Single 8x8 human-silhouette glyph that prefixes the population readout
; (population.asm). One char, no cell encoding -- rendered only by chrome
; init / population_render, never by cell_to_char.
POP_ICON_CHAR           = POLICE_CHAR_BASE + POLICE_CELL_COUNT

; Residential houses chars: 9 cells (3x3) that replace the empty residential
; zone art once that zone's pop crosses POP_HOUSES_THRESHOLD. cell_to_char
; maps RES_HOUSE_CELL_FIRST + offset -> RES_HOUSE_CHAR_BASE + offset.
RES_HOUSE_CHAR_BASE     = POP_ICON_CHAR + 1

; Apartment chars: second residential tier. Same shape as houses; 9 cells
; mapped from APT_CELL_FIRST + offset.
APT_CHAR_BASE           = RES_HOUSE_CHAR_BASE + RES_HOUSE_CELL_COUNT

; Industrial-heavy chars: 9 cells for the developed industrial tier.
; cell_to_char maps IND_HEAVY_CELL_FIRST + offset -> IND_HEAVY_CHAR_BASE + offset.
IND_HEAVY_CHAR_BASE     = APT_CHAR_BASE + APT_CELL_COUNT

; Commercial-heavy chars: 9 cells for the developed commercial tier.
COM_HEAVY_CHAR_BASE     = IND_HEAVY_CHAR_BASE + IND_HEAVY_CELL_COUNT

; Fire-department chars: 9 bitmaps for the 3x3 fire station. Same struct-table
; dispatch as park / police.
FIRESTATION_CHAR_BASE   = COM_HEAVY_CHAR_BASE + COM_HEAVY_CELL_COUNT

; Speed button chars: 4 bitmaps for the 2x2 top-strip SPEED icon. Lives in the
; toolbar-art zone, stamped from inline bitmaps in assets.asm at boot. SPEED
; is a one-shot popup trigger (like DISK after the inset fix), so we render
; only the idle (raised) state -- both the idle and selected base entries in
; top_btn_base_*_lo/hi point at this same block, since selected_tile never
; latches TILE_SPEED.
SPEED_CHAR_BASE         = FIRESTATION_CHAR_BASE + FIRESTATION_CELL_COUNT

; Checkbox glyphs for the speed popup: 1 char each for "empty" (just an
; outline) and "checked" (outline with checkmark). Used by speed_popup.asm
; to render the radio list and updated in place when the user clicks a row.
CHECKBOX_EMPTY_CHAR     = SPEED_CHAR_BASE + 4
CHECKBOX_CHECKED_CHAR   = CHECKBOX_EMPTY_CHAR + 1

INSPECT_ICON_COL        = 0
INSPECT_ICON_ROW        = 1
DISK_ICON_COL           = 2
DISK_ICON_ROW           = 1
SPEED_ICON_COL          = 4
SPEED_ICON_ROW          = 1
TOP_BTN_W               = 2     ; all top buttons are 2x2 cells
TOP_BTN_H               = 2

; cell_to_char (render.asm) plumbs a 16-bit char id (low byte in A, high byte in
; ctc_char_hi) through render_draw_tile + set_fcm_char16, so the ceiling is now
; the resident char-bank window rather than the 8-bit char-id range. CHAR_DATA
; lives at bank-4 $0000 and the bank-5 stage area starts at $10000, so each char
; bitmap (64 bytes) must satisfy char_id*64 < $10000 -> char_id < 1024.
        .cerror COALPP_CHAR_BASE + 12 > 1024, "coal plant chars exceed resident char-bank window"
        .cerror NUCLEARPP_CHAR_BASE + 12 > 1024, "nuclear plant chars exceed resident char-bank window"
        .cerror DISK_INSET_CHAR_BASE + 4 > 1024, "top-strip button chars exceed resident char-bank window"
        .cerror DISK_LINE_CHAR + 1 > 1024, "disk-line char exceeds resident char-bank window"
        .cerror TREE_CHAR_BASE + TREE_CELL_COUNT > 1024, "tree chars exceed resident char-bank window"
        .cerror WATER_SHORE_CHAR_BASE + WATER_SHORE_CELL_COUNT > 1024, "water shore chars exceed resident char-bank window"
        .cerror POWER_BRIDGE_CHAR_BASE + POWER_BRIDGE_CELL_COUNT > 1024, "power bridge chars exceed resident char-bank window"
        .cerror DEBRIS_CHAR_BASE + DEBRIS_CELL_COUNT > 1024, "debris chars exceed resident char-bank window"
        .cerror PARK_CHAR_BASE + PARK_CELL_COUNT > 1024, "park chars exceed resident char-bank window"
        .cerror POLICE_CHAR_BASE + POLICE_CELL_COUNT > 1024, "police chars exceed resident char-bank window"
        .cerror POP_ICON_CHAR + 1 > 1024, "population icon char exceeds resident char-bank window"
        .cerror RES_HOUSE_CHAR_BASE + RES_HOUSE_CELL_COUNT > 1024, "residential-house chars exceed resident char-bank window"
        .cerror APT_CHAR_BASE + APT_CELL_COUNT > 1024, "apartment chars exceed resident char-bank window"
        .cerror IND_HEAVY_CHAR_BASE + IND_HEAVY_CELL_COUNT > 1024, "industrial-heavy chars exceed resident char-bank window"
        .cerror COM_HEAVY_CHAR_BASE + COM_HEAVY_CELL_COUNT > 1024, "commercial-heavy chars exceed resident char-bank window"
        .cerror FIRESTATION_CHAR_BASE + FIRESTATION_CELL_COUNT > 1024, "fire station chars exceed resident char-bank window"
        .cerror SPEED_CHAR_BASE + 4 > 1024, "SPEED top-strip button chars exceed resident char-bank window"
        .cerror CHECKBOX_CHECKED_CHAR + 1 > 1024, "checkbox chars exceed resident char-bank window"
        .cerror BTN_OK_BK_CHAR + 1 > 1024, "popup OK button BK char exceeds resident char-bank window"
        .cerror RAIL_CHAR_BASE + RAIL_CELL_COUNT > 1024, "rail chars exceed resident char-bank window"
        .cerror TILESET_ASSET_CHARS != FIRESTATION_CHAR_BASE + FIRESTATION_CELL_COUNT, "TILESET_ASSET_CHARS must cover every map-viewport char"
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
; UI tiles are staged at Attic $6000 so the now char-indexed map tileset
; (0..COM_HEAVY last char) has clear room below it.
ATTIC_UI_TILE_MB        = $80
ATTIC_UI_TILE_BANK      = $00
ATTIC_UI_TILE_ADDR      = $6000
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
