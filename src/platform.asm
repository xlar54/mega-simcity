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
SPRITE_X_MSB            = $D010
SPRITE_ENABLE           = $D015
SPRITE_Y_EXPAND         = $D017
SPRITE_PRIORITY         = $D01B
SPRITE_MULTICOLOR       = $D01C
SPRITE_X_EXPAND         = $D01D
SPRITE0_COLOR           = $D027
SPRITE1_COLOR           = $D028

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

MODE_BASIC              = 0
MODE_NCM40              = 5

; *** Changing VIEW_COLS to 80 will automatically switch
; *** the entire screen to 640x200
VIEW_COLS               = 40
VIEW_ROWS               = 25

; VIC-IV NCM screen geometry, derived from VIEW_COLS so the column count lives
; in exactly one place. screen_mode (loaded from NCM_SCREEN_MODE) drives
; ncm_core's row stride, which is screen_mode*2 = VIEW_COLS cells per row.
NCM_SCREEN_MODE         = VIEW_COLS / 2
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

UI_TOP_ROWS             = 5
UI_LEFT_COLS            = 4
UI_RIGHT_COLS           = 0
UI_BOTTOM_ROWS          = 0

; The visible map can overlap the static chrome by whole NCM cells. Keeping
; these as constants lets us later widen the viewport or hide the top/left UI
; chrome without touching render or mouse hit-testing code.
MAP_OVERLAP_LEFT_COLS   = 2
MAP_OVERLAP_TOP_ROWS    = 4
MAP_RIGHT_MARGIN_COLS   = UI_RIGHT_COLS
MAP_BOTTOM_MARGIN_ROWS  = UI_BOTTOM_ROWS

MAIN_COL                = UI_LEFT_COLS - MAP_OVERLAP_LEFT_COLS
MAIN_ROW                = UI_TOP_ROWS - MAP_OVERLAP_TOP_ROWS
MAIN_NCM_COLS           = VIEW_COLS - MAIN_COL - MAP_RIGHT_MARGIN_COLS
MAIN_TILE_COLS          = MAIN_NCM_COLS / 2
MAIN_TILE_ROWS          = 12
MAIN_NCM_ROWS           = MAIN_TILE_ROWS * 2
NCM_CELL_PIXELS         = 8
CITY_TILE_PIXELS        = 16
MAIN_PIXEL_X            = MAIN_COL * NCM_CELL_PIXELS
MAIN_PIXEL_Y            = MAIN_ROW * NCM_CELL_PIXELS
MAIN_PIXEL_RIGHT        = (MAIN_COL + MAIN_NCM_COLS) * NCM_CELL_PIXELS
MAIN_PIXEL_BOTTOM       = (MAIN_ROW + MAIN_NCM_ROWS) * NCM_CELL_PIXELS
CURSOR_PIXEL_X          = MAIN_PIXEL_X
CURSOR_TOP_NCM_ROWS     = 2
CURSOR_ROW              = MAIN_ROW + CURSOR_TOP_NCM_ROWS
CURSOR_TILE_MIN_Y       = CURSOR_TOP_NCM_ROWS / 2
CURSOR_PIXEL_Y          = CURSOR_ROW * NCM_CELL_PIXELS
CURSOR_PIXEL_RIGHT      = MAIN_PIXEL_RIGHT
CURSOR_PIXEL_BOTTOM     = MAIN_PIXEL_BOTTOM
SPRITE_SCREEN_X         = $28
SPRITE_SCREEN_Y         = 50
MOUSE_MIN_X             = $10000 - SPRITE_SCREEN_X
MOUSE_MAX_X             = (VIEW_COLS * NCM_CELL_PIXELS) - 1
MOUSE_MAX_Y             = (VIEW_ROWS * NCM_CELL_PIXELS) - 1
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
MOUSE_SCROLL_DELAY      = 2
MOUSE_SCROLL_LEFT       = $01
MOUSE_SCROLL_RIGHT      = $02
MOUSE_SCROLL_UP         = $04
MOUSE_SCROLL_DOWN       = $08
MOUSE_POT_PORT1_SELECT  = $7F
CPU_40MHZ_BIT           = $40

CITY_COLS               = 64
CITY_ROWS               = 32
CITY_MAP_SIZE           = CITY_COLS * CITY_ROWS
CITY_VIEW_MAX_X         = CITY_COLS - MAIN_TILE_COLS
CITY_VIEW_MAX_Y         = CITY_ROWS - MAIN_TILE_ROWS

TILE_WATER              = 0
TILE_GRASS              = 1
TILE_ROAD               = 2
TILE_RESIDENTIAL        = 3
TILE_COMMERCIAL         = 4
TILE_INDUSTRIAL         = 5
TILE_POWER              = 6
CITY_TILE_TYPE_COUNT    = 7
CITY_CHARS_PER_TILE     = 4
CITY_CHAR_CURSOR        = CITY_TILE_TYPE_COUNT * CITY_CHARS_PER_TILE
TILESET_BODY_SIZE       = CITY_TILE_TYPE_COUNT * CITY_CHARS_PER_TILE * 64

TILESET_STAGE_ADDR      = $6000
ATTIC_TILE_MB           = $80
ATTIC_TILE_BANK         = $00
ATTIC_TILE_ADDR         = $0000

UI_TOOL_COL_LEFT        = 0
UI_TOOL_COL_RIGHT       = 2
UI_TOOL_ROW_TOP         = 3
UI_TOOL_ROW_MID         = 8
UI_TOOL_ROW_BOTTOM      = 11

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
