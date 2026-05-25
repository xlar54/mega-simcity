;=======================================================================================
; Boot asset loading.
;
; Tile graphics live in two PRGs on disk ("tileset" = 16x16 city tiles,
; "uitiles" = UI / glyph tiles). Each is a two-stage load at boot:
;   1. KERNAL-LOAD the PRG into chip-RAM staging, then DMA it up to Attic RAM.
;   2. DMA from Attic into the VIC-visible NCM character RAM.
; This module does both stages for both tilesets, plus the shared palette and
; the runtime-built map cursor chars.
;=======================================================================================

; KERNAL-LOAD a disk file into staging RAM, then DMA it up to an Attic bank.
LOAD_ASSET .macro name, namelen, size, attic_mb, attic_addr, attic_bank
-
        lda #$00
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
        .byte $00
        .word \attic_addr
        .byte \attic_bank
        .byte $00
        .word $0000
.endmacro

;---------------------------------------------------------------------------------------
; Stage 1: disk -> Attic
;---------------------------------------------------------------------------------------

boot_load_tileset:
        #LOAD_ASSET tileset_name, tileset_name_end - tileset_name, TILESET_BODY_SIZE, ATTIC_TILE_MB, ATTIC_TILE_ADDR, ATTIC_TILE_BANK
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
        rts

;---------------------------------------------------------------------------------------
; Stage 2: Attic -> char RAM
;---------------------------------------------------------------------------------------

tiles_load:
        jsr tiles_dma_city_from_attic
        jsr tiles_load_cursor
        rts

tiles_dma_city_from_attic:
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
        rts

tiles_load_cursor:
        lda #CITY_CHAR_CURSOR
        ldx #<ncm_cursor_tl
        ldy #>ncm_cursor_tl
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+1
        ldx #<ncm_cursor_tr
        ldy #>ncm_cursor_tr
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+2
        ldx #<ncm_cursor_bl
        ldy #>ncm_cursor_bl
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+3
        ldx #<ncm_cursor_br
        ldy #>ncm_cursor_br
        jsr create_ncm_char
        rts

ncm_cursor_tl:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00

ncm_cursor_tr:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F

ncm_cursor_bl:
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

ncm_cursor_br:
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

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
.for i = 0, i < UI_TEXT_COUNT, i = i + 1
        #UI_TILE_DMA (UI_TEXT_A + i), UI_TILE_CHAR_SIZE, UI_TEXT_OFF_BASE + i * UI_TILE_CHAR_SIZE
.next
.for i = 0, i < UI_BTN_COUNT, i = i + 1
        #UI_TILE_DMA (UI_BTN_BASE + i * 4), UI_BTN_TILE_SIZE, UI_BTN_OFF_BASE + i * UI_BTN_TILE_SIZE
.next
        rts
