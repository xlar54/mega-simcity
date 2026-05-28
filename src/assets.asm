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
        lda #CITY_CHAR_CURSOR
        ldx #<fcm_cursor_tl
        ldy #>fcm_cursor_tl
        jsr create_fcm_char

        lda #CITY_CHAR_CURSOR+1
        ldx #<fcm_cursor_tr
        ldy #>fcm_cursor_tr
        jsr create_fcm_char

        lda #CITY_CHAR_CURSOR+2
        ldx #<fcm_cursor_bl
        ldy #>fcm_cursor_bl
        jsr create_fcm_char

        lda #CITY_CHAR_CURSOR+3
        ldx #<fcm_cursor_br
        ldy #>fcm_cursor_br
        jsr create_fcm_char
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
        lda #INSPECT_CHAR_BASE
        ldx #<fcm_inspect_tl_inset
        ldy #>fcm_inspect_tl_inset
        jsr create_fcm_char
        lda #INSPECT_CHAR_BASE+1
        ldx #<fcm_inspect_tr_inset
        ldy #>fcm_inspect_tr_inset
        jsr create_fcm_char
        lda #INSPECT_CHAR_BASE+2
        ldx #<fcm_inspect_bl_inset
        ldy #>fcm_inspect_bl_inset
        jsr create_fcm_char
        lda #INSPECT_CHAR_BASE+3
        ldx #<fcm_inspect_br_inset
        ldy #>fcm_inspect_br_inset
        jsr create_fcm_char

        ; --- INSPECT selected (pressed: black top + left) ---
        lda #INSPECT_INSET_CHAR_BASE
        ldx #<fcm_inspect_tl
        ldy #>fcm_inspect_tl
        jsr create_fcm_char
        lda #INSPECT_INSET_CHAR_BASE+1
        ldx #<fcm_inspect_tr
        ldy #>fcm_inspect_tr
        jsr create_fcm_char
        lda #INSPECT_INSET_CHAR_BASE+2
        ldx #<fcm_inspect_bl
        ldy #>fcm_inspect_bl
        jsr create_fcm_char
        lda #INSPECT_INSET_CHAR_BASE+3
        ldx #<fcm_inspect_br
        ldy #>fcm_inspect_br
        jsr create_fcm_char

        ; --- LOAD idle (down-arrow + disk; raised) ---
        lda #LOAD_CHAR_BASE
        ldx #<fcm_load_tl_idle
        ldy #>fcm_load_tl_idle
        jsr create_fcm_char
        lda #LOAD_CHAR_BASE+1
        ldx #<fcm_load_tr_idle
        ldy #>fcm_load_tr_idle
        jsr create_fcm_char
        lda #LOAD_CHAR_BASE+2
        ldx #<fcm_disk_bl_idle
        ldy #>fcm_disk_bl_idle
        jsr create_fcm_char
        lda #LOAD_CHAR_BASE+3
        ldx #<fcm_disk_br_idle
        ldy #>fcm_disk_br_idle
        jsr create_fcm_char

        ; --- LOAD selected (pressed) ---
        lda #LOAD_INSET_CHAR_BASE
        ldx #<fcm_load_tl_sel
        ldy #>fcm_load_tl_sel
        jsr create_fcm_char
        lda #LOAD_INSET_CHAR_BASE+1
        ldx #<fcm_load_tr_sel
        ldy #>fcm_load_tr_sel
        jsr create_fcm_char
        lda #LOAD_INSET_CHAR_BASE+2
        ldx #<fcm_disk_bl_sel
        ldy #>fcm_disk_bl_sel
        jsr create_fcm_char
        lda #LOAD_INSET_CHAR_BASE+3
        ldx #<fcm_disk_br_sel
        ldy #>fcm_disk_br_sel
        jsr create_fcm_char

        ; --- SAVE idle (up-arrow + disk; raised) ---
        lda #SAVE_CHAR_BASE
        ldx #<fcm_save_tl_idle
        ldy #>fcm_save_tl_idle
        jsr create_fcm_char
        lda #SAVE_CHAR_BASE+1
        ldx #<fcm_save_tr_idle
        ldy #>fcm_save_tr_idle
        jsr create_fcm_char
        lda #SAVE_CHAR_BASE+2
        ldx #<fcm_disk_bl_idle
        ldy #>fcm_disk_bl_idle
        jsr create_fcm_char
        lda #SAVE_CHAR_BASE+3
        ldx #<fcm_disk_br_idle
        ldy #>fcm_disk_br_idle
        jsr create_fcm_char

        ; --- SAVE selected (pressed) ---
        lda #SAVE_INSET_CHAR_BASE
        ldx #<fcm_save_tl_sel
        ldy #>fcm_save_tl_sel
        jsr create_fcm_char
        lda #SAVE_INSET_CHAR_BASE+1
        ldx #<fcm_save_tr_sel
        ldy #>fcm_save_tr_sel
        jsr create_fcm_char
        lda #SAVE_INSET_CHAR_BASE+2
        ldx #<fcm_disk_bl_sel
        ldy #>fcm_disk_bl_sel
        jsr create_fcm_char
        lda #SAVE_INSET_CHAR_BASE+3
        ldx #<fcm_disk_br_sel
        ldy #>fcm_disk_br_sel
        jsr create_fcm_char
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
