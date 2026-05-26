;=======================================================================================
; MEGA-SimCity platform constants.
;=======================================================================================

BORDERCOL               = $D020
BACKCOL                 = $D021
VIC4_KEY                = $D02F
VIC_RASTER              = $D012
VIC3_CTRL               = $D031
VIC4_CTRL               = $D054
VIC4_HOTREGS            = $D05D
VIC4_LINESTPLSB         = $D058
VIC4_LINESTPMSB         = $D059
VIC4_SCRNPTRLSB         = $D060
VIC4_SCRNPTRMSB         = $D061
VIC4_SCRBPTRBNK         = $D062
VIC4_SCRNPTRMB          = $D063
VIC4_COLPTRLSB          = $D064
VIC4_COLPTRMSB          = $D065
VIC4_COLPTRBNK          = $D066
VIC4_COLPTRMB           = $D067
VIC4_CHARPTRLSB         = $D068
VIC4_CHARPTRMSB         = $D069
VIC4_CHARPTRBNK         = $D06A
VIC4_CHARPTRMB          = $D06B
VIC4_TEXTXPOS           = $D04C
VIC4_TEXTYPOS           = $D04E
VIC4_CHRCOUNT           = $D05E
VIC4_SPRXMSB9           = $D05F
VIC4_SPRPTRADRLSB       = $D06C
VIC4_SPRPTRADRMSB       = $D06D
VIC4_SPRPTRBNK          = $D06E
VIC4_SPRYMSB8           = $D077
VIC4_SPRYMSB9           = $D078
VIC4_DISPROWS           = $D07B
MEGA_KEYQUEUE           = $D610
PLATFORM_FLAGS          = $D60F   ; per Xemu author: bit5 (=$20) set = real HW, clear = Xemu
PLATFORM_REAL_HW_BIT    = $20
CIA1_PORT_B             = $DC01
CIA1_PORT_A             = $DC00
CIA1_DDRA               = $DC02
CIA1_DDRB               = $DC03
M65_POT_PORT_A_X        = $D620
M65_POT_PORT_A_Y        = $D621
M65_POT_PORT_B_X        = $D622
M65_POT_PORT_B_Y        = $D623

SPRITE0_X               = $D000
SPRITE0_Y               = $D001
SPRITE1_X               = $D002
SPRITE1_Y               = $D003
SPRITE2_X               = $D004
SPRITE2_Y               = $D005
SPRITE3_X               = $D006
SPRITE3_Y               = $D007
SPRITE4_X               = $D008
SPRITE4_Y               = $D009
SPRITE5_X               = $D00A
SPRITE5_Y               = $D00B
SPRITE_X_MSB            = $D010
SPRITE_ENABLE           = $D015
SPRITE_Y_EXPAND         = $D017
SPRITE_PRIORITY         = $D01B
SPRITE_MULTICOLOR       = $D01C
SPRITE_X_EXPAND         = $D01D
SPRITE0_COLOR           = $D027
SPRITE1_COLOR           = $D028
SPRITE2_COLOR           = $D029
SPRITE3_COLOR           = $D02A
SPRITE4_COLOR           = $D02B
SPRITE5_COLOR           = $D02C

MULTINA                 = $D770
MULTINB                 = $D774
MULTOUT                 = $D778

KERNAL_SETBNK           = $FF6B
KERNAL_CHROUT           = $FFD2
KERNAL_GETIN            = $FFE4
KERNAL_SETLFS           = $FFBA
KERNAL_SETNAM           = $FFBD
KERNAL_LOAD             = $FFD5
KERNAL_PLOT             = $FFF0

; Keep runtime display buffers away from the KERNAL/DOS workspace range at
; $10000-$11FFF and the color-RAM mirror near the top of bank 1.
SCREEN_RAM              = $16000
TEXT_SCREEN_RAM         = $0800
TEXT_COLOR_RAM          = $D800
CHAR_DATA               = $40000
CHAR_CODE_BASE          = $1000

PTR2                    = $FA
PTR                     = $FC
; 4-byte zero-page pointer for the power flood-fill's Attic work stack (power.asm).
; Sits in the free $F0-$F5 block, below MAP_PTR; only used during a power recompute.
POWER_STACK_PTR         = $F0
; 4-byte zero-page pointer for 32-bit indirect access to the world map in Attic.
; Sits below PTR2 and survives set_fcm_char (which only clobbers PTR at $FC-$FF).
; Safe here because the runtime never calls KERNAL (only boot loading does).
MAP_PTR                 = $F6

MODE_BASIC              = 0
MODE_FCM40              = 5

; *** Changing VIEW_COLS to 80 will automatically switch
; *** the entire screen to 640x200
VIEW_COLS               = 40
VIEW_ROWS               = 25

; VIC-IV FCM screen geometry, derived from VIEW_COLS so the column count lives
; in exactly one place. screen_mode (loaded from FCM_SCREEN_MODE) drives
; fcm_core's row stride, which is screen_mode*2 = VIEW_COLS cells per row.
FCM_SCREEN_MODE         = VIEW_COLS / 2
VIC_CHRCOUNT            = VIEW_COLS
VIC_LINESTEP            = VIEW_COLS * 2

; 40 columns runs the display in H320; more than 40 needs H640. These select
; the matching VIC3_CTRL H640 bit ($D031.7) and VIC4_CTRL sprite-X-in-640 bit
; ($D054.4) so flipping VIEW_COLS flips the whole display mode in one place.
.if VIEW_COLS > 40
VIC_H640_BIT            = %10000000
VIC_SPRH640_BIT         = %00010000
.else
VIC_H640_BIT            = %00000000
VIC_SPRH640_BIT         = %00000000
.endif

UI_TOP_ROWS             = 3
UI_LEFT_COLS            = 4
UI_RIGHT_COLS           = 0
UI_BOTTOM_ROWS          = 0

; The visible map can overlap the static chrome by whole FCM cells. Keeping
; these as constants lets us later widen the viewport or hide the top/left UI
; chrome without touching render or mouse hit-testing code.
MAP_OVERLAP_LEFT_COLS   = 0      ; map starts after the toolbar (no left overlap)
MAP_OVERLAP_TOP_ROWS    = 2
MAP_RIGHT_MARGIN_COLS   = UI_RIGHT_COLS
MAP_BOTTOM_MARGIN_ROWS  = UI_BOTTOM_ROWS

MAIN_COL                = UI_LEFT_COLS - MAP_OVERLAP_LEFT_COLS
MAIN_ROW                = UI_TOP_ROWS - MAP_OVERLAP_TOP_ROWS
MAIN_FCM_COLS           = VIEW_COLS - MAIN_COL - MAP_RIGHT_MARGIN_COLS
MAIN_TILE_COLS          = MAIN_FCM_COLS / 2
MAIN_TILE_ROWS          = 12
MAIN_FCM_ROWS           = MAIN_TILE_ROWS * 2
; The map's top MAP_OVERLAP_TOP_ROWS cell rows sit under the top chrome and are
; never visible, so render_viewport starts here and skips the tile rows they
; cover. This keeps the map from drawing into the chrome (the bleed/tearing seen
; on scroll) so the chrome never needs redrawing over the map -- which is what
; made the menu bar flicker. Requires the overlap to be a whole number of tiles.
FIRST_VISIBLE_TILE_ROW  = MAP_OVERLAP_TOP_ROWS / 2
FCM_CELL_PIXELS         = 8
CITY_TILE_PIXELS        = 16
MAIN_PIXEL_X            = MAIN_COL * FCM_CELL_PIXELS
MAIN_PIXEL_Y            = MAIN_ROW * FCM_CELL_PIXELS
MAIN_PIXEL_RIGHT        = (MAIN_COL + MAIN_FCM_COLS) * FCM_CELL_PIXELS
MAIN_PIXEL_BOTTOM       = (MAIN_ROW + MAIN_FCM_ROWS) * FCM_CELL_PIXELS
CURSOR_PIXEL_X          = MAIN_PIXEL_X
CURSOR_TOP_FCM_ROWS     = 2
CURSOR_ROW              = MAIN_ROW + CURSOR_TOP_FCM_ROWS
CURSOR_TILE_MIN_Y       = CURSOR_TOP_FCM_ROWS / 2
CURSOR_PIXEL_Y          = CURSOR_ROW * FCM_CELL_PIXELS
CURSOR_PIXEL_RIGHT      = MAIN_PIXEL_RIGHT
CURSOR_PIXEL_BOTTOM     = MAIN_PIXEL_BOTTOM
; SPRITE_SCREEN_X is the base sprite-X for the screen's left edge. On real MEGA65
; hardware sprites render ~16px left of where Xemu puts them, so an additional
; runtime offset (sprite_x_fix in sprites.asm, set by detect_platform from the
; PLATFORM_FLAGS bit) is added when each sprite's X register is written.
; paint/hit-testing use the logical mouse coords (not SPRITE_SCREEN_X), so they
; are unaffected by the correction.
SPRITE_SCREEN_X         = $18    ; 24 = standard sprite-X for screen left edge
SPRITE_SCREEN_Y         = 50
SPRITE_X_HW_FIX         = 16     ; runtime correction added on real hardware
MOUSE_MIN_X             = $10000 - SPRITE_SCREEN_X
MOUSE_MAX_X             = (VIEW_COLS * FCM_CELL_PIXELS) - 1
MOUSE_MAX_Y             = (VIEW_ROWS * FCM_CELL_PIXELS) - 1
MOUSE_MAX_DELTA         = 24
MOUSE_MAX_Y_STEP        = 24
MOUSE_POINTER_WIDTH     = 9
MOUSE_POINTER_HEIGHT    = 15
MOUSE_POINTER_CELL_HEIGHT = 24
MOUSE_POINTER_MAX_X     = MOUSE_MAX_X - MOUSE_POINTER_WIDTH + 1
MOUSE_POINTER_MAX_Y     = MOUSE_MAX_Y - MOUSE_POINTER_HEIGHT + 1
MOUSE_START_TILE_X      = MAIN_TILE_COLS / 2
MOUSE_START_TILE_Y      = MAIN_TILE_ROWS / 2
MOUSE_START_X           = MAIN_PIXEL_X + (MOUSE_START_TILE_X * CITY_TILE_PIXELS)
MOUSE_START_Y           = MAIN_PIXEL_Y + (MOUSE_START_TILE_Y * CITY_TILE_PIXELS)
MOUSE_SCROLL_DOWN_Y     = CURSOR_PIXEL_BOTTOM - SPRITE_SCREEN_Y - MOUSE_POINTER_CELL_HEIGHT
MOUSE_SPRITE_MAX_Y      = 249
MOUSE_BUTTON_LEFT       = $10
MOUSE_BUTTON_SETTLE     = $40    ; busy-wait after DDR->input before reading
                                 ; PORT_B (R5 CIA settle for reliable reads)
MOUSE_POT_READ_TRIES    = $20    ; cap on POT stable-read retries (anti-wedge)
MOUSE_SCROLL_DELAY      = 2
MOUSE_SCROLL_LEFT       = $01
MOUSE_SCROLL_RIGHT      = $02
MOUSE_SCROLL_UP         = $04
MOUSE_SCROLL_DOWN       = $08
MOUSE_POT_PORT1_SELECT  = $7F
CPU_40MHZ_BIT           = $40

; The map is stored at 8x8-cell resolution (CELL_*). The viewport, cursor,
; hit-testing and scrolling still work in 16x16 tiles (CITY_*); a 16x16 tile is
; a 2x2 block of same-type cells, so tile (tx,ty) maps to cell (tx*2,ty*2).
; Full SimCity/Amiga map: 1920x1600 px = 120x100 tiles = 240x200 cells = 48,000
; bytes. Too big for bank 0, so the cell array lives in Attic (see ATTIC_MAP_*).
CITY_COLS               = 120
CITY_ROWS               = 100
CITY_MAP_SIZE           = CITY_COLS * CITY_ROWS
CITY_VIEW_MAX_X         = CITY_COLS - MAIN_TILE_COLS
CITY_VIEW_MAX_Y         = CITY_ROWS - MAIN_TILE_ROWS

CELL_COLS               = CITY_COLS * 2
CELL_ROWS               = CITY_ROWS * 2
CELL_MAP_SIZE           = CELL_COLS * CELL_ROWS

TILE_WATER              = 0
TILE_GROUND             = 1
TILE_ROAD               = 2     ; tool id; road map cells use ROAD_CELL_* (below)
TILE_RESIDENTIAL        = 3
TILE_COMMERCIAL         = 4
TILE_INDUSTRIAL         = 5
TILE_POWER              = 6     ; tool id for the power-LINE tool (1x1, see below)
TILE_COALPP             = 7     ; tool id for the coal power plant (3x4 structure)
; TILE_RESIDENTIAL/COMMERCIAL/INDUSTRIAL are tool ids; on the map a zone is not a
; base tile type but a 3x3 block of literal zone-cell chars (see below).
ZONE_SIZE               = 3      ; 3x3 cells

CITY_TILE_TYPE_COUNT    = 7
CITY_CHARS_PER_TILE     = 4
CITY_CHAR_CURSOR        = CITY_TILE_TYPE_COUNT * CITY_CHARS_PER_TILE
; Road cells (1x1) live in a contiguous block whose cell value EQUALS its char
; index (8..14), so cell_to_char maps a road with no arithmetic and the block can
; grow (chars 21-23 are free) before it would reach the power-line chars at 24.
; Orientation is chosen from a cell's road neighbours (see city.asm road_refresh).
ROAD_CELL_H             = 8     ; horizontal
ROAD_CELL_V             = 9     ; vertical (char 8 rotated 90 deg)
ROAD_CELL_4WAY          = 10    ; roads on all four sides (plain asphalt square)
ROAD_CELL_CURVE_NW      = 11    ; connects north + west
ROAD_CELL_CURVE_NE      = 12    ; connects north + east
ROAD_CELL_CURVE_SW      = 13    ; connects south + west
ROAD_CELL_CURVE_SE      = 14    ; connects south + east
ROAD_CELL_T_N           = 15    ; T-junction, connects N+E+W (closed south)
ROAD_CELL_T_S           = 16    ; T-junction, connects S+E+W (closed north)
ROAD_CELL_T_E           = 17    ; T-junction, connects N+S+E (closed west)
ROAD_CELL_T_W           = 18    ; T-junction, connects N+S+W (closed east)
; Straight roads with a power line crossing over them (only straight H/V roads can
; cross; curves/T/4-way never do). Chosen by road_refresh when power lines sit on
; both perpendicular sides of the road -- see roads.asm road_power_ns/road_power_ew.
ROAD_CELL_H_POWER       = 19    ; horizontal road, vertical power line crossing
ROAD_CELL_V_POWER       = 20    ; vertical road, horizontal power line crossing
ROAD_CELL_FIRST         = ROAD_CELL_H
ROAD_CELL_LAST          = ROAD_CELL_V_POWER
; Neighbour direction bits used by road_refresh to choose the orientation. The
; diagonals are used to spot a parallel road running alongside (so two adjacent
; parallel roads stay straight rather than forming a junction).
ROAD_BIT_N              = $01
ROAD_BIT_S              = $02
ROAD_BIT_E              = $04
ROAD_BIT_W              = $08
ROAD_BIT_NE             = $10
ROAD_BIT_NW             = $20
ROAD_BIT_SE             = $40
ROAD_BIT_SW             = $80
; Power-line cells (1x1) occupy the four chars (24..27) that the old 2x2 power
; placeholder used; like roads, the cell value EQUALS its char index so
; cell_to_char needs no arithmetic. Orientation follows a cell's power-line
; neighbours (powerlines.asm) and there are no curves. A "pole" (crossarm) tile
; is used for every POWERLINE_POLE_EVERY-th line the player places (a running
; count) and at any intersection. These reuse the ROAD_BIT_* direction bits.
; NOTE: the coal power PLANT is a separate, larger building (a future feature) --
; these constants are only the wires/poles.
POWERLINE_CELL_H        = 24    ; horizontal wires
POWERLINE_CELL_V        = 25    ; vertical wires
POWERLINE_CELL_POLE_H   = 26    ; pole (crossarm) on a horizontal run
POWERLINE_CELL_POLE_V   = 27    ; pole (crossarm) on a vertical run
POWERLINE_CELL_FIRST    = POWERLINE_CELL_H
POWERLINE_CELL_LAST     = POWERLINE_CELL_POLE_V
POWERLINE_POLE_EVERY    = 4     ; every 4th placed line becomes a pole
; 3x3 zone cells: 3 zones x 9 positions at char offsets 32..58. Their bitmaps are
; part of the tileset disk asset (after the base tiles) and DMA'd into char RAM.
; A painted zone cell stores (ZONE_GEN_BASE + zone_index*9 + position) | $80;
; bit 7 marks the cell byte as a literal char (see cell_to_char).
ZONE_GEN_BASE           = 32
ZONE_CELL_LITERAL       = $80
ZONE_TYPE_COUNT         = 3      ; residential, commercial, industrial
ZONE_CELL_CHAR_COUNT    = ZONE_TYPE_COUNT * ZONE_SIZE * ZONE_SIZE   ; 27 distinct cells
; Coal power plant: a 3-wide x 4-tall (24x32 px) structure of 12 distinct cells.
; Char ids 32..58 are taken by zones and 64..173 by the UI tileset, and the zone
; "literal" encoding only reaches char 127, so the plant's bitmaps live ABOVE the
; UI at chars COALPP_CHAR_BASE.. (see ui_tile_layout.asm). On the map each cell is
; stored as a non-literal value COALPP_CELL_FIRST+position (position = dy*3+dx);
; cell_to_char translates that range to the char id (render.asm).
COALPP_COLS             = 3
COALPP_ROWS             = 4
COALPP_CELL_COUNT       = COALPP_COLS * COALPP_ROWS                 ; 12
COALPP_CELL_FIRST       = 71     ; map-cell value of position 0 (free, non-literal)
COALPP_CELL_LAST        = COALPP_CELL_FIRST + COALPP_CELL_COUNT - 1 ; 82
; Tileset disk asset = base tiles (chars 0-27), then the 3x3 zone cells (loaded to
; chars ZONE_GEN_BASE..+26), then the 12 coal-plant cells. TILESET_ASSET_SIZE is
; the whole blob.
TILESET_BODY_SIZE       = CITY_TILE_TYPE_COUNT * CITY_CHARS_PER_TILE * 64
TILESET_ZONE_SIZE       = ZONE_CELL_CHAR_COUNT * 64
TILESET_COALPP_SIZE     = COALPP_CELL_COUNT * 64
TILESET_ASSET_SIZE      = TILESET_BODY_SIZE + TILESET_ZONE_SIZE + TILESET_COALPP_SIZE

; Boot staging buffer: KERNAL-LOAD lands here in chip RAM, then DMA to Attic.
; Bank 5 ($50000, the top 64K of the MEGA65's 384K) keeps it clear of program
; code in bank 0, which previously grew into the old $6000 buffer and crashed.
TILESET_STAGE_BANK      = $05
TILESET_STAGE_ADDR      = $0000
ATTIC_TILE_MB           = $80
ATTIC_TILE_BANK         = $00
ATTIC_TILE_ADDR         = $0000

; World map cell array in Attic, 2 MB past the asset library (clean MB boundary;
; leaves the first 2 MB of Attic for the tile/asset library to grow into).
; Physical $08200000 = MB $82. ATTIC_MAP_PHYS is the same address as the CPU sees
; it for 32-bit indirect addressing ([MAP_PTR],z).
ATTIC_MAP_MB            = $82
ATTIC_MAP_BANK          = $00
ATTIC_MAP_ADDR          = $0000
ATTIC_MAP_PHYS          = $8200000

; Power-propagation scratch (power.asm), one MB each past the world map:
;   $83 = "powered" marker, 1 byte/cell (flood-fill visited + result).
;   $84 = flood-fill work stack of (cx,cy) byte pairs.
ATTIC_POWER_MB          = $83
ATTIC_POWER_BANK        = $00
ATTIC_POWER_ADDR        = $0000
ATTIC_POWER_PHYS        = $8300000
ATTIC_PSTACK_PHYS       = $8400000

UI_TOOL_COL_LEFT        = 0      ; left button column (cells 0-1)
UI_TOOL_COL_RIGHT       = 2      ; right button column (cells 2-3)
UI_TOOL_ROW_TOP         = 3      ; top of the 2x8 toolbar grid (8 rows of 2x2)
UI_TOOL_PIXEL_RIGHT     = UI_LEFT_COLS * FCM_CELL_PIXELS
; Sprite 2 (selector) position for slot 0 (the bulldozer at FCM col 0, row 3).
; Same sprite-coordinate convention as the pointer/cursor: sprite = cell*8 + screen offset.
UI_TOOL_SELECTOR_X      = SPRITE_SCREEN_X + (UI_TOOL_COL_LEFT * FCM_CELL_PIXELS)
UI_TOOL_SELECTOR_Y      = SPRITE_SCREEN_Y + (UI_TOOL_ROW_TOP * FCM_CELL_PIXELS) + 1
CURSOR_TOOL_FREEZE_X    = 0      ; first visible map tile against the toolbar

INPUT_NONE              = 0
INPUT_MOVE_UP           = 1
INPUT_MOVE_DOWN         = 2
INPUT_MOVE_LEFT         = 3
INPUT_MOVE_RIGHT        = 4
INPUT_PAINT             = 5
INPUT_QUIT              = 6

KEY_CRSR_DOWN           = $11
KEY_CRSR_RIGHT          = $1D
KEY_CRSR_UP             = $AF
KEY_CRSR_LEFT           = $5F
KEY_CRSR_UP_ALT         = $91
KEY_CRSR_LEFT_ALT       = $9D
KEY_RETURN              = $0D
