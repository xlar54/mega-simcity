;=======================================================================================
; Boot asset loading.
;
; Tile graphics live in two PRGs on disk ("tileset" = 16x16 city tiles,
; "uitiles" = UI / glyph tiles). Each is a two-stage load at boot:
;   1. KERNAL-LOAD the PRG into chip-RAM staging, then DMA it up to Attic RAM.
;   2. DMA from Attic into the VIC-visible FCM character RAM.
; This module does both stages for both tilesets, plus the shared palette and
; the runtime-built map cursor chars.
;=======================================================================================

; KERNAL-LOAD a disk file into staging RAM, then DMA it up to an Attic bank.
LOAD_ASSET .macro name, namelen, size, attic_mb, attic_addr, attic_bank
-
        lda #TILESET_STAGE_BANK         ; .A = data bank (5); .X = filename bank (0)
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda #\namelen
        ldx #<\name
        ldy #>\name
        jsr KERNAL_SETNAM
        lda #$40
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcs -
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, \attic_mb
        .byte $00
        .byte $00
        .word \size
        .word TILESET_STAGE_ADDR + 2
        .byte TILESET_STAGE_BANK
        .word \attic_addr
        .byte \attic_bank
        .byte $00
        .word $0000
.endmacro

;---------------------------------------------------------------------------------------
; Stage 1: disk -> Attic
;---------------------------------------------------------------------------------------

boot_load_tileset:
        #LOAD_ASSET tileset_name, tileset_name_end - tileset_name, TILESET_ASSET_SIZE, ATTIC_TILE_MB, ATTIC_TILE_ADDR, ATTIC_TILE_BANK
        rts

tileset_name:
        .text "tileset"
tileset_name_end:

boot_load_ui_tiles:
        #LOAD_ASSET ui_tiles_name, ui_tiles_name_end - ui_tiles_name, UI_TILE_ASSET_SIZE, ATTIC_UI_TILE_MB, ATTIC_UI_TILE_ADDR, ATTIC_UI_TILE_BANK
        rts

ui_tiles_name:
        .text "uitiles"
ui_tiles_name_end:

;---------------------------------------------------------------------------------------
; Palette (shared by both tilesets)
;---------------------------------------------------------------------------------------

; Palette color from natural 0-255 RGB. Each channel is nibble-swapped at
; assemble time because the MEGA65 stores palette bytes nibble-swapped (a
; display value of $37 is stored as $73), giving full 8-bit-per-channel color.
SET_COLOR .macro index, red, green, blue
        lda #\index
        ldx #((((\red) & $0F) << 4) | (((\red) >> 4) & $0F))
        ldy #((((\green) & $0F) << 4) | (((\green) >> 4) & $0F))
        ldz #((((\blue) & $0F) << 4) | (((\blue) >> 4) & $0F))
        jsr set_palette_color
.endmacro

tiles_init_palette:
        #SET_COLOR 0,    0,   0,   0    ; black / transparent-looking interior
        #SET_COLOR 1,    0,  48, 160    ; water
        #SET_COLOR 2,   32, 160,  32    ; grass
        #SET_COLOR 3,    0,  96,  16    ; dark green
        #SET_COLOR 4,  160, 112,  64    ; ground / dirt
        #SET_COLOR 5,   96,  96,  96    ; road
        #SET_COLOR 6,  240, 208,  16    ; stripe / yellow text
        #SET_COLOR 7,   96, 208,  64    ; residential green
        #SET_COLOR 8,   32,  96, 224    ; commercial blue
        #SET_COLOR 9,  192,  96,  16    ; industrial orange
        #SET_COLOR 10, 240, 224,  32    ; power / prompt
        #SET_COLOR 11,  48,  48,  48    ; dark gray
        #SET_COLOR 12, 208, 208, 208    ; light gray UI panel
        #SET_COLOR 13, 224,  32,  32    ; red
        #SET_COLOR 14,  32, 224, 240    ; cyan
        #SET_COLOR 15, 240, 240, 240    ; white
        ; ground-texture browns: exact sampled colors, full 8-bit
        #SET_COLOR 16, 116, 86, 46
        #SET_COLOR 17, 105, 75, 34
        #SET_COLOR 18, 114, 85, 55
        #SET_COLOR 19, 109, 83, 57
        #SET_COLOR 20, 115, 81, 43
        #SET_COLOR 21, 112, 80, 59
        #SET_COLOR 22,  89, 70, 59
        #SET_COLOR 23, 107, 74, 35
        ; water blues: close shades for subtle horizontal ripple banding
        #SET_COLOR 24,  52, 104, 180   ; base
        #SET_COLOR 25,  44,  92, 165   ; dark band
        #SET_COLOR 26,  64, 118, 196   ; light band
        #SET_COLOR 27,  80, 134, 208   ; ripple glint
        ; bulldozer icon
        #SET_COLOR 28, 232, 148, 112   ; salmon body
        #SET_COLOR 29, 124,  68,  66   ; maroon canopy / accents
        #SET_COLOR 30,  44,  44,  60   ; navy treads / blade
        ; road tile (8x8 cell)
        #SET_COLOR 31, 113,  86,  66   ; top edge brown
        #SET_COLOR 32, 102, 103,  99   ; asphalt
        #SET_COLOR 33, 156, 155, 155   ; lane marking
        #SET_COLOR 34,  63,  56,  49   ; bottom shadow
        #SET_COLOR 35, 117,  85,  56   ; bottom edge brown
        #SET_COLOR 36, 156, 100,  52   ; power-pole wood brown (post + crossbar)
        rts

;---------------------------------------------------------------------------------------
; Stage 2: Attic -> char RAM
;
; Every tile is DMA'd resident at boot. When the art outgrows char RAM, this
; becomes an on-demand Attic->char-RAM cache instead -- see "Stream tiles from
; Attic" in TODO.md.
;---------------------------------------------------------------------------------------

tiles_load:
        jsr tiles_dma_city_from_attic
        jsr tiles_load_cursor
        jsr tiles_load_top_buttons
        jsr tiles_load_trees
        jsr tiles_load_water_shore
        jsr tiles_load_bridges
        jsr tiles_load_powerlines
        jsr tiles_load_button_ok
        jsr tiles_load_rails
        rts

tiles_dma_city_from_attic:
        ; Base tiles (chars 0-27): Attic start -> CHAR_DATA.
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_BODY_SIZE
        .word ATTIC_TILE_ADDR
        .byte ATTIC_TILE_BANK
        .word $0000             ; low 16 bits of CHAR_DATA ($40000)
        .byte `CHAR_DATA
        .byte $00
        .word $0000

        ; Zone cells (chars ZONE_GEN_BASE..+26): they follow the base tiles in
        ; the asset (Attic + TILESET_BODY_SIZE) -> CHAR_DATA + ZONE_GEN_BASE*64.
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_ZONE_SIZE
        .word ATTIC_TILE_ADDR + TILESET_BODY_SIZE
        .byte ATTIC_TILE_BANK
        .word ZONE_GEN_BASE * 64
        .byte `CHAR_DATA
        .byte $00
        .word $0000

        ; Coal-plant cells: they follow the zone cells in the asset (Attic +
        ; TILESET_BODY_SIZE + TILESET_ZONE_SIZE) -> CHAR_DATA + COALPP_CHAR_BASE*64
        ; (above the UI tiles).
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_COALPP_SIZE
        .word ATTIC_TILE_ADDR + TILESET_BODY_SIZE + TILESET_ZONE_SIZE
        .byte ATTIC_TILE_BANK
        .word COALPP_CHAR_BASE * 64
        .byte `CHAR_DATA
        .byte $00
        .word $0000

        ; Nuclear-plant cells: right after the coal-plant cells in the asset.
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_NUCLEARPP_SIZE
        .word ATTIC_TILE_ADDR + TILESET_BODY_SIZE + TILESET_ZONE_SIZE + TILESET_COALPP_SIZE
        .byte ATTIC_TILE_BANK
        .word NUCLEARPP_CHAR_BASE * 64
        .byte `CHAR_DATA
        .byte $00
        .word $0000
        rts

tiles_load_cursor:
        #STAMP_CHAR CITY_CHAR_CURSOR,   fcm_cursor_tl
        #STAMP_CHAR CITY_CHAR_CURSOR+1, fcm_cursor_tr
        #STAMP_CHAR CITY_CHAR_CURSOR+2, fcm_cursor_bl
        #STAMP_CHAR CITY_CHAR_CURSOR+3, fcm_cursor_br
        rts

fcm_cursor_tl:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00

fcm_cursor_tr:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F

fcm_cursor_bl:
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

fcm_cursor_br:
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; Top-strip menu buttons (inspect / load / save). Each button has an IDLE and a
; SELECTED state, each state is 4 chars (TL, TR, BL, BR). Both LOAD and SAVE
; share the disk bottom-halves (only the arrow top-halves differ), so the same
; fcm_disk_bl / fcm_disk_br bitmaps are wired into both buttons' bottom rows.
;
; In the source data, the `_inset`-suffixed label carries the white-top-left
; bitmap (raised look) and the bare label carries the black-top-left bitmap
; (pressed look). The two are wired to the IDLE/SELECTED char bases here so
; the visible IDLE icon is raised and the SELECTED icon is pressed.
tiles_load_top_buttons:
        ; --- INSPECT idle (raised: white top + left) ---
        #STAMP_CHAR INSPECT_CHAR_BASE,   fcm_inspect_tl_inset
        #STAMP_CHAR INSPECT_CHAR_BASE+1, fcm_inspect_tr_inset
        #STAMP_CHAR INSPECT_CHAR_BASE+2, fcm_inspect_bl_inset
        #STAMP_CHAR INSPECT_CHAR_BASE+3, fcm_inspect_br_inset

        ; --- INSPECT selected (pressed: black top + left) ---
        #STAMP_CHAR INSPECT_INSET_CHAR_BASE,   fcm_inspect_tl
        #STAMP_CHAR INSPECT_INSET_CHAR_BASE+1, fcm_inspect_tr
        #STAMP_CHAR INSPECT_INSET_CHAR_BASE+2, fcm_inspect_bl
        #STAMP_CHAR INSPECT_INSET_CHAR_BASE+3, fcm_inspect_br

        ; --- LOAD idle (down-arrow + disk; raised) ---
        #STAMP_CHAR LOAD_CHAR_BASE,   fcm_load_tl_idle
        #STAMP_CHAR LOAD_CHAR_BASE+1, fcm_load_tr_idle
        #STAMP_CHAR LOAD_CHAR_BASE+2, fcm_disk_bl_idle
        #STAMP_CHAR LOAD_CHAR_BASE+3, fcm_disk_br_idle

        ; --- LOAD selected (pressed) ---
        #STAMP_CHAR LOAD_INSET_CHAR_BASE,   fcm_load_tl_sel
        #STAMP_CHAR LOAD_INSET_CHAR_BASE+1, fcm_load_tr_sel
        #STAMP_CHAR LOAD_INSET_CHAR_BASE+2, fcm_disk_bl_sel
        #STAMP_CHAR LOAD_INSET_CHAR_BASE+3, fcm_disk_br_sel

        ; --- SAVE idle (up-arrow + disk; raised) ---
        #STAMP_CHAR SAVE_CHAR_BASE,   fcm_save_tl_idle
        #STAMP_CHAR SAVE_CHAR_BASE+1, fcm_save_tr_idle
        #STAMP_CHAR SAVE_CHAR_BASE+2, fcm_disk_bl_idle
        #STAMP_CHAR SAVE_CHAR_BASE+3, fcm_disk_br_idle

        ; --- SAVE selected (pressed) ---
        #STAMP_CHAR SAVE_INSET_CHAR_BASE,   fcm_save_tl_sel
        #STAMP_CHAR SAVE_INSET_CHAR_BASE+1, fcm_save_tr_sel
        #STAMP_CHAR SAVE_INSET_CHAR_BASE+2, fcm_disk_bl_sel
        #STAMP_CHAR SAVE_INSET_CHAR_BASE+3, fcm_disk_br_sel
        rts

fcm_inspect_tl:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$0C,$00,$0C,$0C,$0C,$0C,$0C
        .byte $00,$0C,$00,$00,$0C,$0C,$0C,$0C
        .byte $00,$0C,$00,$00,$00,$0C,$0C,$0C
        .byte $00,$0C,$00,$00,$00,$00,$0C,$0C
        .byte $00,$0C,$00,$00,$00,$00,$00,$0C
        .byte $00,$0C,$00,$00,$00,$00,$00,$00

fcm_inspect_tr:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F

fcm_inspect_bl:
        .byte $00,$0C,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$00,$00,$00,$00,$0C,$0C
        .byte $00,$0C,$00,$0C,$00,$00,$0C,$0C
        .byte $00,$0C,$0C,$0C,$0C,$00,$00,$0C
        .byte $00,$0C,$0C,$0C,$0C,$0C,$00,$0C
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

fcm_inspect_br:
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; Inset versions: only the BORDER pixels are swapped from the outset tiles
; (top + left $00 -> $0F, right + bottom $0F -> $00). The pointer arrow pixels
; (interior $00s) stay $00 so the pointer keeps its black outline in both
; states. Corners follow whichever border line "wins" in the outset tile, so
; the diagonal-light direction stays consistent.
fcm_inspect_tl_inset:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$00,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$00,$00,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$00,$00,$00,$0C,$0C,$0C
        .byte $0F,$0C,$00,$00,$00,$00,$0C,$0C
        .byte $0F,$0C,$00,$00,$00,$00,$00,$0C
        .byte $0F,$0C,$00,$00,$00,$00,$00,$00

fcm_inspect_tr_inset:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_inspect_bl_inset:
        .byte $0F,$0C,$00,$00,$00,$00,$00,$00
        .byte $0F,$0C,$00,$00,$00,$00,$0C,$0C
        .byte $0F,$0C,$00,$0C,$00,$00,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$00,$00,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$00,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$00,$00,$00,$00,$00,$00

fcm_inspect_br_inset:
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00

; ===== LOAD / SAVE button bitmaps =====
;
; Each button is a 2x2-char (16x16-px) frame around an arrow stacked on top of
; a floppy disk. The top half holds the arrow (down for LOAD, up for SAVE);
; the bottom half holds the disk and is shared between both buttons via
; fcm_disk_bl/br.
;
; For every tile we provide an `_idle` version (raised: white top + left, black
; bottom + right) and a `_sel` version (pressed: black top + left, white bottom
; + right). The interior arrow / disk pixels stay $00 in both states so the
; symbol keeps its black outline regardless of which border lights up.

; --- LOAD top-left: down-arrow shaft + start of head ---
fcm_load_tl_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$00,$00,$00,$00
        .byte $0F,$0C,$0C,$0C,$0C,$00,$00,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$00,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_load_tl_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00

; --- LOAD top-right: down-arrow shaft + rest of head ---
fcm_load_tr_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_load_tr_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F

; --- SAVE top-left: up-arrow head tapering down to shaft ---
fcm_save_tl_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$00,$00
        .byte $0F,$0C,$0C,$0C,$0C,$00,$00,$00
        .byte $0F,$0C,$0C,$0C,$00,$00,$00,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_save_tl_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00

; --- SAVE top-right: up-arrow head + shaft ---
fcm_save_tr_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_save_tr_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F

; --- Disk bottom-halves (shared between LOAD and SAVE) ---
; A simple 3.5"-disk silhouette: rectangle outline with a small label window in
; the middle. Same bitmap regardless of which arrow is on top.
fcm_disk_bl_idle:
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$00,$00,$00,$00,$00
        .byte $0F,$0C,$0C,$00,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$00,$0C,$00,$0C,$0C
        .byte $0F,$0C,$0C,$00,$0C,$00,$0C,$0C
        .byte $0F,$0C,$0C,$00,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00

fcm_disk_bl_sel:
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$0C,$0C,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$00,$0C,$0C,$0C,$0C
        .byte $00,$0C,$0C,$00,$0C,$00,$0C,$0C
        .byte $00,$0C,$0C,$00,$0C,$00,$0C,$0C
        .byte $00,$0C,$0C,$00,$0C,$0C,$0C,$0C
        .byte $00,$0C,$0C,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

fcm_disk_br_idle:
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$00,$0C,$0C,$00
        .byte $0C,$0C,$00,$0C,$00,$0C,$0C,$00
        .byte $0C,$0C,$00,$0C,$00,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$00,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00

fcm_disk_br_sel:
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$00,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$00,$0C,$0C,$0F
        .byte $0C,$0C,$00,$0C,$00,$0C,$0C,$0F
        .byte $0C,$0C,$00,$0C,$00,$0C,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$00,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$00,$0C,$0C,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

UI_TILE_DMA .macro index, size, offset
        lda #$00
        sta $D707
        .byte $80, ATTIC_UI_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word \size
        .word ATTIC_UI_TILE_ADDR + \offset
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
.for i = 0, i < UI_TEXT_COUNT, i = i + 1
        #UI_TILE_DMA (UI_TEXT_A + i), UI_TILE_CHAR_SIZE, UI_TEXT_OFF_BASE + i * UI_TILE_CHAR_SIZE
.next
.for i = 0, i < UI_BTN_COUNT, i = i + 1
        #UI_TILE_DMA (UI_BTN_BASE + i * 4), UI_BTN_TILE_SIZE, UI_BTN_OFF_BASE + i * UI_BTN_TILE_SIZE
.next
        rts

;---------------------------------------------------------------------------------------
; Trees: 16 bitmaps, indexed by 4-neighbor mask. The mask's low 4 bits encode
; (W:E:S:N); cell value TREE_CELL_FIRST+mask maps to char TREE_CHAR_BASE+mask
; via cell_to_char.
;
; Per-tile rule: each corner of the 8x8 char (NW/NE/SW/SE, 3 pixels each) is
; either FILLED (dark green $03) or ROUNDED (brown $04). The corner is filled
; iff EITHER adjacent edge has a tree neighbor:
;
;     nw_filled = N || W      ne_filled = N || E
;     sw_filled = S || W      se_filled = S || E
;
; All non-corner pixels are always dark green. So fully-surrounded cells render
; as solid green blocks (correct: they're interior forest), and only the 9
; visually-distinct edge/corner masks change shape.
;
; Layout of each 8x8 tile:
;     row 0:  [NW NW][G G G G][NE NE]
;     row 1:  [NW   ][G G G G G G][   NE]
;     rows 2-5: all green
;     row 6:  [SW   ][G G G G G G][   SE]
;     row 7:  [SW SW][G G G G][SE SE]
;
; Where [NW NW] = $03 $03 if NW filled, else $04 $04 (brown); same idea for the
; other corners. Two pixels on the outer ring + 1 on the inner ring = 3 corner
; pixels per corner, giving a chunky-but-readable rounded silhouette at 8x8.
;---------------------------------------------------------------------------------------

; Macro: emit one 8x8 tree tile from 4 cardinal-neighbor flags (n, s, e, w).
; Compared to the previous version, this drives BOTH the corner rounding AND
; the edge silhouette darkening from the same flags, so every forest patch gets
; a darker green outline against the brown ground -- the cue that makes the
; reference image read as "organic" instead of "tiled".
;
; Pixel-zone responsibilities:
;   * 2x2 corner outer pixels (3 per corner): brown $04 if !N&&!W (etc.), else
;     match the edge color so the silhouette continues smoothly.
;   * 1 inner-corner pixel per corner: dark $03 if the corner is rounded
;     (1-pixel silhouette curve), else interior mid green $02.
;   * 4-pixel mid stretches on each of the 4 edges: dark $03 silhouette if the
;     corresponding cardinal neighbor is absent, mid $02 otherwise (so adjacent
;     filled tiles join with no visible seam).
;   * Interior 6x4 region (rows 2-5, cols 1-6): static dithered scatter of
;     $02/$03/$07 -- mask-independent, identical across all 16 tiles.
;
; The macro derives the 4 corner-filled flags inline as (n|w), (n|e), (s|w),
; (s|e); see the comments on the 16 calls below for the per-mask shape.
TREE_TILE .macro n, s, e, w
        ; --- Row 0: NW corner (2) + top-edge stripe (4) + NE corner (2) ---
.if (\n)|(\w)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.if \n
        .byte $02, $02, $02, $02
.else
        .byte $03, $03, $03, $03        ; top-edge silhouette
.fi
.if (\n)|(\e)
        .byte $02, $02
.else
        .byte $04, $04
.fi
        ; --- Row 1: NW edge (1) + inner-NW (1) + interior (4) + inner-NE (1) + NE edge (1) ---
.if (\n)|(\w)
        .byte $02
.else
        .byte $04
.fi
.if (\n)|(\w)
        .byte $02                       ; inner-NW: filled -> blend
.else
        .byte $03                       ; inner-NW: rounded -> silhouette curve
.fi
        .byte $07, $02, $02, $07
.if (\n)|(\e)
        .byte $03                       ; inner-NE: rounded -> silhouette
.else
        .byte $03
.fi
.if (\n)|(\e)
        .byte $02
.else
        .byte $04
.fi
        ; --- Rows 2..5: W edge (1) + interior 6x4 scatter (6) + E edge (1) ---
.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $03, $02, $07, $02, $02, $03
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $02, $07, $02, $03, $07, $02
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $07, $02, $03, $02, $02, $07
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $02, $03, $02, $07, $02, $03
.if \e
        .byte $02
.else
        .byte $03
.fi

        ; --- Row 6: SW edge (1) + inner-SW (1) + interior (4) + inner-SE (1) + SE edge (1) ---
.if (\s)|(\w)
        .byte $02
.else
        .byte $04
.fi
.if (\s)|(\w)
        .byte $02
.else
        .byte $03
.fi
        .byte $07, $02, $02, $07
.if (\s)|(\e)
        .byte $02
.else
        .byte $03
.fi
.if (\s)|(\e)
        .byte $02
.else
        .byte $04
.fi

        ; --- Row 7: SW corner (2) + bottom-edge stripe (4) + SE corner (2) ---
.if (\s)|(\w)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.if \s
        .byte $02, $02, $02, $02
.else
        .byte $03, $03, $03, $03        ; bottom-edge silhouette
.fi
.if (\s)|(\e)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.endmacro

; The 16 tiles, indexed by mask. mask bit 0 = N, 1 = S, 2 = E, 3 = W.
;
;     mask  N S E W
;     0     0 0 0 0   isolated single bush
;     1     1 0 0 0   N only -> south end of vertical run
;     2     0 1 0 0   S only -> north end
;     3     1 1 0 0   NS -> vertical middle (solid interior)
;     4     0 0 1 0   E only -> west end of horizontal run
;     5     1 0 1 0   NE -> SW corner rounded (forest opens SW)
;     6     0 1 1 0   SE -> NW corner rounded
;     7     1 1 1 0   NSE -> W edge of solid forest
;     8     0 0 0 1   W only -> east end
;     9     1 0 0 1   NW -> SE corner rounded
;     10    0 1 0 1   SW -> NE corner rounded
;     11    1 1 0 1   NSW -> E edge of solid forest
;     12    0 0 1 1   EW horizontal middle (solid)
;     13    1 0 1 1   NEW -> S edge of solid forest
;     14    0 1 1 1   SEW -> N edge of solid forest
;     15    1 1 1 1   surrounded (fully solid interior)
;
fcm_tree_tiles:
        #TREE_TILE 0, 0, 0, 0       ; mask  0
        #TREE_TILE 1, 0, 0, 0       ; mask  1
        #TREE_TILE 0, 1, 0, 0       ; mask  2
        #TREE_TILE 1, 1, 0, 0       ; mask  3
        #TREE_TILE 0, 0, 1, 0       ; mask  4
        #TREE_TILE 1, 0, 1, 0       ; mask  5
        #TREE_TILE 0, 1, 1, 0       ; mask  6
        #TREE_TILE 1, 1, 1, 0       ; mask  7
        #TREE_TILE 0, 0, 0, 1       ; mask  8
        #TREE_TILE 1, 0, 0, 1       ; mask  9
        #TREE_TILE 0, 1, 0, 1       ; mask 10
        #TREE_TILE 1, 1, 0, 1       ; mask 11
        #TREE_TILE 0, 0, 1, 1       ; mask 12
        #TREE_TILE 1, 0, 1, 1       ; mask 13
        #TREE_TILE 0, 1, 1, 1       ; mask 14
        #TREE_TILE 1, 1, 1, 1       ; mask 15

;---------------------------------------------------------------------------------------
; Water shoreline: 15 bitmaps for masks 0..14 (mask 15 = interior, served by
; the existing TILE_WATER quadrant chars 0..3). Mirror of TREE_TILE -- same
; N/S/E/W geometry, but the "outside" pixels are brown ground and the "inside"
; pixels match the existing water tile's palette and ripple style:
;
;   $18 = base water (matches assets\tileset.asm TILE_WATER fill)
;   $19 = dark band  (used for the depth-line silhouette at no-neighbor edges
;                     AND as natural ripple flecks scattered in the interior)
;   $1A = light band (interior ripples)
;   $1B = ripple glint (rare interior highlights)
;
; The interior pattern is sampled from the same dark-band/light-band/glint
; vocabulary as the existing water chars, so a shoreline cell sitting next to
; an interior water cell reads as the same body of water with a faint extra
; depth line where the bottom rises up to the shore.
WATER_SHORE_TILE .macro n, s, e, w
        ; --- Row 0: NW corner (2) + top edge (4) + NE corner (2) ---
.if (\n)|(\w)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.if \n
        .byte $18, $18, $18, $18
.else
        .byte $19, $19, $19, $19        ; depth line along the shore
.fi
.if (\n)|(\e)
        .byte $18, $18
.else
        .byte $04, $04
.fi
        ; --- Row 1: NW edge (1) + inner-NW (1) + interior (4) + inner-NE (1) + NE edge (1) ---
.if (\n)|(\w)
        .byte $18
.else
        .byte $04
.fi
.if (\n)|(\w)
        .byte $18
.else
        .byte $19                        ; inner-corner depth pixel
.fi
        .byte $18, $1A, $1A, $18
.if (\n)|(\e)
        .byte $18
.else
        .byte $19
.fi
.if (\n)|(\e)
        .byte $18
.else
        .byte $04
.fi
        ; --- Rows 2..5: W edge (1) + interior 6 + E edge (1) ---
.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $1B, $1B, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $18, $18, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $1A, $1A, $1A, $18, $18, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $18, $19, $19
.if \e
        .byte $18
.else
        .byte $19
.fi

        ; --- Row 6: SW edge (1) + inner-SW (1) + interior (4) + inner-SE (1) + SE edge (1) ---
.if (\s)|(\w)
        .byte $18
.else
        .byte $04
.fi
.if (\s)|(\w)
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $1A, $1A, $18
.if (\s)|(\e)
        .byte $18
.else
        .byte $19
.fi
.if (\s)|(\e)
        .byte $18
.else
        .byte $04
.fi
        ; --- Row 7: SW corner (2) + bottom edge (4) + SE corner (2) ---
.if (\s)|(\w)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.if \s
        .byte $18, $18, $18, $18
.else
        .byte $19, $19, $19, $19
.fi
.if (\s)|(\e)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.endmacro

; 15 shoreline tiles, masks 0..14 (mask 15 = interior, served by chars 0..3).
fcm_water_shore_tiles:
        #WATER_SHORE_TILE 0, 0, 0, 0       ; mask  0  isolated
        #WATER_SHORE_TILE 1, 0, 0, 0       ; mask  1  N
        #WATER_SHORE_TILE 0, 1, 0, 0       ; mask  2  S
        #WATER_SHORE_TILE 1, 1, 0, 0       ; mask  3  NS
        #WATER_SHORE_TILE 0, 0, 1, 0       ; mask  4  E
        #WATER_SHORE_TILE 1, 0, 1, 0       ; mask  5  NE
        #WATER_SHORE_TILE 0, 1, 1, 0       ; mask  6  SE
        #WATER_SHORE_TILE 1, 1, 1, 0       ; mask  7  NSE
        #WATER_SHORE_TILE 0, 0, 0, 1       ; mask  8  W
        #WATER_SHORE_TILE 1, 0, 0, 1       ; mask  9  NW
        #WATER_SHORE_TILE 0, 1, 0, 1       ; mask 10  SW
        #WATER_SHORE_TILE 1, 1, 0, 1       ; mask 11  NSW
        #WATER_SHORE_TILE 0, 0, 1, 1       ; mask 12  EW
        #WATER_SHORE_TILE 1, 0, 1, 1       ; mask 13  NEW
        #WATER_SHORE_TILE 0, 1, 1, 1       ; mask 14  SEW

; Loader: chars WATER_SHORE_CHAR_BASE..+14 from fcm_water_shore_tiles. Same
; pattern as tiles_load_trees.
tiles_load_water_shore:
        lda #0
        sta tlws_idx
_tlws_loop:
        lda tlws_idx
        cmp #WATER_SHORE_CELL_COUNT
        bcs _tlws_done

        lda tlws_idx
        sta tlws_src_lo
        lda #0
        sta tlws_src_hi
.for i = 0, i < 6, i = i + 1
        asl tlws_src_lo
        rol tlws_src_hi
.next
        clc
        lda tlws_src_lo
        adc #<fcm_water_shore_tiles
        sta tlws_src_lo
        lda tlws_src_hi
        adc #>fcm_water_shore_tiles
        sta tlws_src_hi

        ; 16-bit char id = WATER_SHORE_CHAR_BASE + tlws_idx, carry into hi byte.
        ; create_fcm_char16 expects PTR2 preset and reads X (char_hi) + A (char_lo).
        lda tlws_src_lo
        sta PTR2
        lda tlws_src_hi
        sta PTR2+1
        lda tlws_idx
        clc
        adc #<WATER_SHORE_CHAR_BASE
        sta tlws_char_lo
        lda #>WATER_SHORE_CHAR_BASE
        adc #0
        tax                          ; X = char_hi
        lda tlws_char_lo             ; A = char_lo
        jsr create_fcm_char16

        inc tlws_idx
        bra _tlws_loop
_tlws_done:
        rts

tlws_idx:
        .byte 0
tlws_src_lo:
        .byte 0
tlws_src_hi:
        .byte 0
tlws_char_lo:
        .byte 0

; Load chars TREE_CHAR_BASE..+15 from the 16 bitmaps above. fcm_tree_tiles is
; contiguous (1024 bytes), so tile N starts at fcm_tree_tiles + N*64.
; Compute idx*64 by shifting a 16-bit value left 6 times.
tiles_load_trees:
        lda #0
        sta tlt_idx
_tlt_loop:
        lda tlt_idx
        cmp #TREE_CELL_COUNT
        bcs _tlt_done

        lda tlt_idx
        sta tlt_src_lo
        lda #0
        sta tlt_src_hi
.for i = 0, i < 6, i = i + 1
        asl tlt_src_lo
        rol tlt_src_hi
.next
        clc
        lda tlt_src_lo
        adc #<fcm_tree_tiles
        sta tlt_src_lo
        lda tlt_src_hi
        adc #>fcm_tree_tiles
        sta tlt_src_hi

        ; 16-bit char id = TREE_CHAR_BASE + tlt_idx, carry into hi byte.
        lda tlt_src_lo
        sta PTR2
        lda tlt_src_hi
        sta PTR2+1
        lda tlt_idx
        clc
        adc #<TREE_CHAR_BASE
        sta tlt_char_lo
        lda #>TREE_CHAR_BASE
        adc #0
        tax                          ; X = char_hi
        lda tlt_char_lo              ; A = char_lo
        jsr create_fcm_char16

        inc tlt_idx
        bra _tlt_loop
_tlt_done:
        rts

tlt_idx:
        .byte 0
tlt_src_lo:
        .byte 0
tlt_src_hi:
        .byte 0
tlt_char_lo:
        .byte 0

;---------------------------------------------------------------------------------------
; Bridges: 4 bitmaps overwriting chars 21/22 (the unused road-headroom slots
; in the city tileset) for road bridges, and chars POWER_BRIDGE_CHAR_BASE/+1
; for power-line bridges. Style mirrors the underlying tile -- road bridges
; reuse the asphalt + lane-marking palette ($20/$21) with water ($18) at the
; top/bottom edges and a dark $22 railing just inside; power bridges keep the
; existing $22 wire colour over a water background ($18 plus $1A ripples).
;---------------------------------------------------------------------------------------

fcm_bridge_road_h:
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; row 0: water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; row 1: dark railing
        .byte $20,$20,$20,$20,$20,$20,$20,$20    ; rows 2..5: asphalt
        .byte $20,$20,$21,$21,$21,$21,$20,$20    ; row 3: lane marking
        .byte $20,$20,$21,$21,$21,$21,$20,$20    ; row 4: lane marking
        .byte $20,$20,$20,$20,$20,$20,$20,$20    ; row 5: asphalt
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; row 6: dark railing
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; row 7: water

fcm_bridge_road_v:
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18

fcm_bridge_power_h:
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $18,$18,$18,$1A,$1A,$18,$18,$18    ; water + ripple
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; horizontal wire
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; horizontal wire
        .byte $18,$1A,$1A,$18,$18,$18,$18,$18    ; water + ripple
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water

fcm_bridge_power_v:
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$18,$22,$1A,$1A,$22,$18,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$1A,$22,$18,$18,$22,$1A,$18
        .byte $18,$1A,$22,$18,$18,$22,$1A,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$18,$22,$1A,$1A,$22,$18,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18

; Stamp each bridge bitmap into its char slot. Road bridges go into the city-
; tileset slots 21/22 (the city DMA put placeholder content there; we
; overwrite it). Power bridges go into the dedicated POWER_BRIDGE_CHAR_BASE
; slots at the top of char RAM.
tiles_load_bridges:
        #STAMP_CHAR ROAD_CELL_BRIDGE_H,     fcm_bridge_road_h
        #STAMP_CHAR ROAD_CELL_BRIDGE_V,     fcm_bridge_road_v
        #STAMP_CHAR POWER_BRIDGE_CHAR_BASE, fcm_bridge_power_h
        #STAMP_CHAR POWER_BRIDGE_CHAR_BASE+1, fcm_bridge_power_v
        rts

;---------------------------------------------------------------------------------------
; Power lines: redesigned bitmaps overwriting the city-tileset slots at chars
; 24..27. The plain H and V tiles each show two wires plus a small hatch (a
; perpendicular bar) at one row/col, so when many are tiled together you get a
; periodic crossbar pattern without any clutter. The POLE_H / POLE_V slots
; (26/27) now render as a clean + intersection -- two horizontal wires AND
; two vertical wires superimposed -- because powerline_refresh writes a POLE
; value when (and only when) a cell sits at a 4-way wire crossing. The old
; "every 4th placement is a pole" cosmetic cadence has been removed in
; city.asm so these chars now appear only at true intersections.
;---------------------------------------------------------------------------------------

fcm_powerline_h:
        ; Horizontal wires (rows 2 + 5) with a vertical hatch at col 1.
        .byte $13,$13,$13,$13,$13,$13,$13,$13   ; row 0: brown
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 1: hatch
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 2: wire 1
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 3: hatch
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 4: hatch
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 5: wire 2
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 6: hatch
        .byte $13,$13,$13,$13,$13,$13,$13,$13   ; row 7: brown

fcm_powerline_v:
        ; Vertical wires (cols 2 + 5) with a horizontal hatch at row 1.
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 0: wires
        .byte $13,$22,$22,$22,$22,$22,$22,$13   ; row 1: hatch (spans both wires + 1 px)
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 2: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 3: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 4: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 5: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 6: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 7: wires

fcm_powerline_cross:
        ; + intersection: both H and V wires; no hatch (the cross IS the cue).
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 0: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 1: V wires
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 2: H wire 1
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 3: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 4: V wires
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 5: H wire 2
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 6: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 7: V wires

tiles_load_powerlines:
        #STAMP_CHAR POWERLINE_CELL_H, fcm_powerline_h
        #STAMP_CHAR POWERLINE_CELL_V, fcm_powerline_v
        ; POLE_H is the single intersection variant. POLE_V is no longer
        ; written by powerline_refresh, so its char slot (27) is free for
        ; other use (popup button TR corner, currently).
        #STAMP_CHAR POWERLINE_CELL_POLE_H, fcm_powerline_cross
        rts

;---------------------------------------------------------------------------------------
; Popup OK button: a 4x2 cell (32x16 px) raised button with the camel-case "Ok"
; label baked in. The eight char-id constants (BTN_OK_*_CHAR) and the rationale
; for the scattered slot choices live in shared/ui_tile_layout.asm next to the
; other char allocations, so any new range that bumps into them gets caught by
; the .cerror guards there.
;
; Border style mirrors the inspect icon's raised look: white ($0F) on the top
; row + left column, black ($00) on the bottom row + right column, light grey
; ($0C) interior. Letters are black on grey, split vertically across the two
; rows so a 12px-tall 'O' / 'k' fits in the 14px-tall interior.
;---------------------------------------------------------------------------------------

fcm_btn_ok_tl:
        ; row 0 white top, col 0 white below, rest grey
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C

fcm_btn_ok_tr:
        ; row 0 white top, col 7 black below, rest grey
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00

fcm_btn_ok_bl:
        ; col 0 white above, row 7 black bottom, rest grey
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$00,$00,$00,$00,$00,$00

fcm_btn_ok_br:
        ; col 7 black above, row 7 black bottom, rest grey
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00

; Top half of 'O' (5x3 of the 5x6 letter, lower 3 rows go into BO). White top
; border row stays; letter occupies char rows 5..7 in cols 1..5.
fcm_btn_ok_top_o:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; row 0: white top
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; rows 1..4: grey padding
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$00,$00,$00,$0C,$0C,$0C   ; row 5: .XXX.  (top of O)
        .byte $0C,$00,$0C,$0C,$0C,$00,$0C,$0C   ; row 6: X...X
        .byte $0C,$00,$0C,$0C,$0C,$00,$0C,$0C   ; row 7: X...X

; Top half of 'k' (lowercase). Plain stem in cols 1, kick coming together.
fcm_btn_ok_top_k:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; row 0: white top
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; rows 1..3: grey padding
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$00,$0C,$0C,$0C,$0C,$0C,$0C   ; row 4: stem starts (X.....)
        .byte $0C,$00,$0C,$0C,$0C,$0C,$0C,$0C   ; row 5: stem
        .byte $0C,$00,$0C,$0C,$00,$0C,$0C,$0C   ; row 6: X..X..  (kick branches)
        .byte $0C,$00,$0C,$00,$0C,$0C,$0C,$0C   ; row 7: X.X...

; Bottom half of 'O': rows 0..2 are the rest of the O, then padding, then the
; black bottom border at row 7.
fcm_btn_ok_bot_o:
        .byte $0C,$00,$0C,$0C,$0C,$00,$0C,$0C   ; row 0: X...X
        .byte $0C,$00,$0C,$0C,$0C,$00,$0C,$0C   ; row 1: X...X
        .byte $0C,$0C,$00,$00,$00,$0C,$0C,$0C   ; row 2: .XXX.
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; rows 3..6: grey padding
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$00,$00,$00,$00,$00,$00   ; row 7: black bottom

; Bottom half of 'k': kick spread out from the stem, returning to the stem.
fcm_btn_ok_bot_k:
        .byte $0C,$00,$00,$0C,$0C,$0C,$0C,$0C   ; row 0: XX....  (return to stem)
        .byte $0C,$00,$0C,$00,$0C,$0C,$0C,$0C   ; row 1: X.X...
        .byte $0C,$00,$0C,$0C,$00,$0C,$0C,$0C   ; row 2: X..X..  (lower kick)
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; rows 3..6: grey padding
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$00,$00,$00,$00,$00,$00   ; row 7: black bottom

tiles_load_button_ok:
        #STAMP_CHAR BTN_OK_TL_CHAR, fcm_btn_ok_tl
        #STAMP_CHAR BTN_OK_TR_CHAR, fcm_btn_ok_tr
        #STAMP_CHAR BTN_OK_BL_CHAR, fcm_btn_ok_bl
        #STAMP_CHAR BTN_OK_BR_CHAR, fcm_btn_ok_br
        #STAMP_CHAR BTN_OK_TO_CHAR, fcm_btn_ok_top_o
        #STAMP_CHAR BTN_OK_TK_CHAR, fcm_btn_ok_top_k
        #STAMP_CHAR BTN_OK_BO_CHAR, fcm_btn_ok_bot_o
        #STAMP_CHAR BTN_OK_BK_CHAR, fcm_btn_ok_bot_k
        rts

;---------------------------------------------------------------------------------------
; Rail tiles. 17 bitmaps loaded into chars RAIL_CHAR_BASE..+16 -- the first
; range that actually lives above char id 255, so STAMP_CHAR resolves to the
; 16-bit create_fcm_char16 entry.
;
; Style: brown ground ($13) base, steel-grey rails ($21, the same medium grey
; the road lane-stripe uses) at rows 2/5 (H) or cols 2/5 (V), dark brown ($24)
; ties between the rails. Power crossings paint perpendicular wires ($22) over
; the rails; bridges sit on water ($18) with a dark railing ($22) flanking the
; deck (same idiom as the road bridge). Curves use a stair-step arc on the
; outer rail (col 5 -> row 5 etc.) so the bend reads as a curve rather than
; a hard L; the inner rail is too tight (2px radius) for a real arc so it
; keeps a sharp corner.
;
; The road crossings (RAIL_*_ROAD) bake a full perpendicular road tile under
; the rail: $20 asphalt fills the road band, rails ($21) cross over it at the
; rail rows/cols. The crossing is sticky -- net_refresh skips re-tile on these
; values so the engine never replaces them with a plain rail or 4-way.
;---------------------------------------------------------------------------------------

fcm_rail_h:
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13

fcm_rail_v:
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

fcm_rail_4way:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Curves use a stair-step arc on the outer rail (e.g. NW outer col 5 -> row 5
; transitions via cols 4,5 at row 3 and cols 3,4 at row 4). The inner rail
; (col 2 -> row 2) still corners sharply -- 2px is too tight for an arc at
; this resolution.
fcm_rail_curve_nw:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $21,$21,$21,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13

fcm_rail_curve_ne:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$21,$21
        .byte $13,$13,$21,$21,$13,$13,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13

fcm_rail_curve_sw:
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $21,$21,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

fcm_rail_curve_se:
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$21,$21,$21
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; T-junctions: 3 sides open, 1 closed. T_N connects N+E+W, closed S.
fcm_rail_t_n:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13

fcm_rail_t_s:
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

fcm_rail_t_e:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

fcm_rail_t_w:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Power crossings: rail + perpendicular power line. Rail $21 wins at the rail
; rows/cols; wire $22 fills the rest of the wire column/row.
fcm_rail_h_power:
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $24,$13,$22,$13,$24,$22,$24,$13
        .byte $24,$13,$22,$13,$24,$22,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $13,$13,$22,$13,$13,$22,$13,$13

fcm_rail_v_power:
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $22,$22,$21,$22,$22,$21,$22,$22
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $22,$22,$21,$22,$22,$21,$22,$22
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Bridges: rail over water. Dark railing flanking the brown deck, mirroring
; the road bridge idiom so shorelines visually flow under both.
fcm_rail_bridge_h:
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; dark railing
        .byte $21,$21,$21,$21,$21,$21,$21,$21    ; top rail
        .byte $24,$13,$24,$13,$24,$13,$24,$13    ; ties on the deck
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21    ; bottom rail
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; dark railing
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water

fcm_rail_bridge_v:
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18

; Road crossings: rail + perpendicular road. RAIL_H_ROAD = horizontal rail
; (rails at rows 2/5) with a vertical road band (asphalt $20 at cols 2..5);
; RAIL_V_ROAD is the mirror. Cell value lives in the rail range and city.asm
; creates these atomically when the player paints rail on a straight road
; (or road on a straight rail). The engine treats them as sticky.
fcm_rail_h_road:
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13

fcm_rail_v_road:
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

tiles_load_rails:
        #STAMP_CHAR RAIL_CHAR_BASE+0,  fcm_rail_h
        #STAMP_CHAR RAIL_CHAR_BASE+1,  fcm_rail_v
        #STAMP_CHAR RAIL_CHAR_BASE+2,  fcm_rail_4way
        #STAMP_CHAR RAIL_CHAR_BASE+3,  fcm_rail_curve_nw
        #STAMP_CHAR RAIL_CHAR_BASE+4,  fcm_rail_curve_ne
        #STAMP_CHAR RAIL_CHAR_BASE+5,  fcm_rail_curve_sw
        #STAMP_CHAR RAIL_CHAR_BASE+6,  fcm_rail_curve_se
        #STAMP_CHAR RAIL_CHAR_BASE+7,  fcm_rail_t_n
        #STAMP_CHAR RAIL_CHAR_BASE+8,  fcm_rail_t_s
        #STAMP_CHAR RAIL_CHAR_BASE+9,  fcm_rail_t_e
        #STAMP_CHAR RAIL_CHAR_BASE+10, fcm_rail_t_w
        #STAMP_CHAR RAIL_CHAR_BASE+11, fcm_rail_h_power
        #STAMP_CHAR RAIL_CHAR_BASE+12, fcm_rail_v_power
        #STAMP_CHAR RAIL_CHAR_BASE+13, fcm_rail_bridge_h
        #STAMP_CHAR RAIL_CHAR_BASE+14, fcm_rail_bridge_v
        #STAMP_CHAR RAIL_CHAR_BASE+15, fcm_rail_h_road
        #STAMP_CHAR RAIL_CHAR_BASE+16, fcm_rail_v_road
        rts
