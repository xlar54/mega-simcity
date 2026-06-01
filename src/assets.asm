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

boot_load_ovr_disk:
        #LOAD_ASSET ovr_disk_name, ovr_disk_name_end - ovr_disk_name, OVR_ASSET_SIZE, ATTIC_OVR_DISK_MB, ATTIC_OVR_DISK_ADDR, ATTIC_OVR_DISK_BANK
        rts

ovr_disk_name:
        .text "ovr-disk"
ovr_disk_name_end:

boot_load_ovr_inspect:
        #LOAD_ASSET ovr_inspect_name, ovr_inspect_name_end - ovr_inspect_name, OVR_ASSET_SIZE, ATTIC_OVR_INSPECTOR_MB, ATTIC_OVR_INSPECTOR_ADDR, ATTIC_OVR_INSPECTOR_BANK
        rts

ovr_inspect_name:
        .text "ovr-inspect"
ovr_inspect_name_end:

;---------------------------------------------------------------------------------------
; Palette (shared by both tilesets)
;
; The palette is no longer hardcoded; it lives in a disk asset PALETTE.PRG
; (built from src/assets/palette.asm) with the same on-disk layout the tile
; editor (src/tile-edit.asm) emits: 2-byte PRG header + 256 R + 256 G +
; 256 B, MEGA65 nibble-swapped bytes ready for $D100/$D200/$D300. Editing
; the palette is just "save PALETTE from the tile editor, reboot the game."
;
; Boot flow:
;   boot_load_palette  -- KERNAL_LOAD into staging (bounded retry), then DMA
;                         the 768-byte body to PALETTE_SHADOW_ADDR in chip
;                         RAM. On hard fail flips palette_load_failed=1.
;   tiles_apply_palette -- write the shadow into the VIC-IV palette
;                         registers. If the load failed, fall back to the
;                         C65 ROM default 16-color palette (just enough to
;                         keep the screen legible for the error case).
;   tiles_init_palette  -- legacy entry: do both, in order. The loader
;                         still calls this name; keeps the contract stable.
;---------------------------------------------------------------------------------------

palette_name:
        .text "palette"
palette_name_end:
PALETTE_NAME_LEN = palette_name_end - palette_name

PALETTE_LOAD_RETRIES = 3

palette_load_failed:
        .byte 0

boot_load_palette:
        lda #PALETTE_LOAD_RETRIES
        sta _blp_tries
_blp_attempt:
        lda #TILESET_STAGE_BANK         ; staging lives in bank 5
        ldx #$00                        ; filename bank 0 (this code is bank 0)
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda #PALETTE_NAME_LEN
        ldx #<palette_name
        ldy #>palette_name
        jsr KERNAL_SETNAM
        lda #$40                        ; A=$40: ignore PRG header, load to X/Y
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcc _blp_success
        dec _blp_tries
        bne _blp_attempt
        ; All retries exhausted: flag fallback, leave shadow as-is.
        lda #1
        sta palette_load_failed
        rts

_blp_success:
        lda #0
        sta palette_load_failed
        ; DMA 768 bytes from staging+2 (skip the 2-byte PRG header) to
        ; PALETTE_SHADOW_ADDR in chip RAM bank 0. Layout in the body is
        ; [256 R][256 G][256 B], same as the shadow expects.
        lda #$00
        sta $D707
        .byte $80, $00                  ; src megabyte
        .byte $81, $00                  ; dst megabyte
        .byte $00                       ; end of list
        .byte $00                       ; cmd: copy
        .word PALETTE_BODY_SIZE
        .word TILESET_STAGE_ADDR + 2
        .byte TILESET_STAGE_BANK
        .word PALETTE_SHADOW_ADDR
        .byte $00                       ; dst bank 0 (chip RAM)
        .byte $00
        .word $0000
        rts

_blp_tries:
        .byte 0

tiles_apply_palette:
        lda palette_load_failed
        bne _tap_fallback
        ldx #0
_tap_loop:
        lda PALETTE_SHADOW_ADDR,x
        sta $D100,x
        lda PALETTE_SHADOW_ADDR + 256,x
        sta $D200,x
        lda PALETTE_SHADOW_ADDR + 512,x
        sta $D300,x
        inx
        bne _tap_loop
        rts
_tap_fallback:
        ; Boot LOAD couldn't read PALETTE -- restore the C65 ROM 16-color
        ; defaults so the screen is at least legible. The rest of the
        ; game's art will look wrong (it expects the full 37-entry custom
        ; palette), but a wrong-looking screen beats a hung boot.
        jmp restore_default_palette

; Legacy entry. The boot loader still calls tiles_init_palette by name.
tiles_init_palette:
        jsr boot_load_palette
        jmp tiles_apply_palette

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
        jsr tiles_load_debris
        jsr tiles_load_park
        jsr tiles_load_police
        jsr tiles_load_pop_icon
        jsr tiles_load_residential_houses
        jsr tiles_load_apartments
        jsr tiles_load_industrial_heavy
        jsr tiles_load_commercial_heavy
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

        ; --- DISK idle (folder; raised: white top + left) ---
        #STAMP_CHAR DISK_CHAR_BASE,   fcm_folder_tl_idle
        #STAMP_CHAR DISK_CHAR_BASE+1, fcm_folder_tr_idle
        #STAMP_CHAR DISK_CHAR_BASE+2, fcm_folder_bl_idle
        #STAMP_CHAR DISK_CHAR_BASE+3, fcm_folder_br_idle

        ; --- DISK selected (folder; pressed: black top + left) ---
        #STAMP_CHAR DISK_INSET_CHAR_BASE,   fcm_folder_tl_sel
        #STAMP_CHAR DISK_INSET_CHAR_BASE+1, fcm_folder_tr_sel
        #STAMP_CHAR DISK_INSET_CHAR_BASE+2, fcm_folder_bl_sel
        #STAMP_CHAR DISK_INSET_CHAR_BASE+3, fcm_folder_br_sel
        ; --- Divider line used by the disk overlay for menu button borders ---
        #STAMP_CHAR DISK_LINE_CHAR, fcm_disk_line
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

; ===== DISK options button bitmaps =====
;
; One 2x2-char (16x16-px) button showing a yellow file-folder icon, opens the
; disk-options overlay (load / save city). Same idle/selected border swap as
; the inspect button above -- `_idle` is raised (white top + left, dark bottom
; + right); `_sel` is pressed (dark top + left, light bottom + right).

; --- Folder icon, 2x2 cells, 4 chars. A 16x16 yellow ($06) file folder with a
;     black ($00) outline on a light-grey ($0C) button background. The folder
;     has a small left-aligned tab on top (cols 2-6 of the 16-wide design) +
;     a wider body below (cols 2-13). Reuses the same idle/selected border
;     swap as the inspect / save / load buttons above.

fcm_folder_tl_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F       ; row 0: white top border
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C       ; row 1: bg
        .byte $0F,$0C,$00,$00,$00,$00,$00,$0C       ; row 2: tab top (cols 2-6)
        .byte $0F,$0C,$00,$06,$06,$06,$00,$00       ; row 3: tab body + folder top
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 4: folder left edge + fill
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 5
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 6
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 7

fcm_folder_tl_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00       ; pressed: dark top
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C       ; dark left
        .byte $00,$0C,$00,$00,$00,$00,$00,$0C
        .byte $00,$0C,$00,$06,$06,$06,$00,$00
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06

fcm_folder_tr_idle:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F       ; top border
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00       ; bg + dark right border
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$0C,$00       ; folder top extends + bg + right
        .byte $06,$06,$06,$06,$06,$00,$0C,$00       ; folder fill + right edge + bg + right
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $06,$06,$06,$06,$06,$00,$0C,$00

fcm_folder_tr_sel:
        .byte $00,$00,$00,$00,$00,$00,$00,$00       ; dark top
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F       ; bg + light right border
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$00,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F

fcm_folder_bl_idle:
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 8: continues folder body
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 9
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 10
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 11
        .byte $0F,$0C,$00,$06,$06,$06,$06,$06       ; row 12
        .byte $0F,$0C,$00,$00,$00,$00,$00,$00       ; row 13: folder bottom
        .byte $0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C       ; row 14: bg
        .byte $00,$00,$00,$00,$00,$00,$00,$00       ; row 15: dark bottom border

fcm_folder_bl_sel:
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$06,$06,$06,$06,$06
        .byte $00,$0C,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F       ; light bottom border (pressed)

fcm_folder_br_idle:
        .byte $06,$06,$06,$06,$06,$00,$0C,$00       ; folder body + edge + bg + right border
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $06,$06,$06,$06,$06,$00,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$0C,$00       ; folder bottom + bg + right border
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00       ; bottom border

fcm_folder_br_sel:
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $06,$06,$06,$06,$06,$00,$0C,$0F
        .byte $00,$00,$00,$00,$00,$00,$0C,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; --- DISK_LINE: panel-bg with a 1-pixel black horizontal line through the
; middle (row 3). Stamped across a popup row by the disk overlay to draw
; menu-button divider lines.
fcm_disk_line:
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C

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

;---------------------------------------------------------------------------------------
; Debris -- one bitmap of scattered rubble, drawn over the ground brown ($13)
; base with dark-brown chunks ($24) and dark-grey shadow flecks ($0B). Left
; behind when a power plant (or, future, a fire) gets bulldozed; player has
; to clear it with the bulldozer for COST_BULLDOZE before building on the cell.
;---------------------------------------------------------------------------------------
fcm_debris:
        .byte $13,$13,$24,$24,$13,$13,$24,$13
        .byte $13,$24,$24,$13,$0B,$24,$24,$13
        .byte $24,$24,$0B,$24,$24,$24,$13,$24
        .byte $13,$0B,$24,$24,$13,$24,$24,$0B
        .byte $13,$13,$24,$0B,$24,$13,$0B,$24
        .byte $24,$24,$13,$13,$24,$24,$24,$13
        .byte $13,$13,$24,$24,$0B,$24,$13,$13
        .byte $24,$0B,$24,$13,$13,$24,$24,$13

tiles_load_debris:
        #STAMP_CHAR DEBRIS_CHAR_BASE, fcm_debris
        rts

;---------------------------------------------------------------------------------------
; Park -- a 4x4 cell (32x32 px = 2x2 tile) structure with trees in the four
; corners, a 2x2 stone fountain in the centre (water $18 in the middle, light-
; grey $0C stone surround, dark-grey $0B rim), and grass with white/yellow
; flowers around the rest. 7 unique bitmaps reused across 16 char slots so the
; corner trees share art, the edge grass alternates between two flower
; arrangements for visual variety, and the centre uses 4 distinct fountain
; quadrants that mesh into a circular pool when tiled.
;---------------------------------------------------------------------------------------

; Tree centered in 8x8 with a small brown trunk -- shared by all four corners.
fcm_park_tree:
        .byte $02,$02,$02,$03,$03,$02,$02,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Grass with yellow ($06) dandelion-style flowers (variant A).
fcm_park_grass_a:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Grass with white ($0F) flowers (variant B) -- different positions.
fcm_park_grass_b:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$0F,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0F,$02,$02
        .byte $02,$0F,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$0F,$02,$02,$02

; Fountain TL quadrant: stone in the NW, water spreading out toward SE so the
; four quadrants mesh into a circular pool with stone rim.
fcm_park_fnt_tl:
        .byte $02,$02,$0B,$0B,$0C,$0C,$0C,$0C
        .byte $02,$0B,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0C,$0C,$18,$18,$18
        .byte $0C,$0C,$0C,$0C,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18

; Fountain TR quadrant (mirror horizontally of TL).
fcm_park_fnt_tr:
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0B,$02
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B
        .byte $18,$18,$18,$0C,$0C,$0C,$0C,$0B
        .byte $18,$18,$18,$18,$0C,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$18,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C

; Fountain BL quadrant (mirror vertically of TL).
fcm_park_fnt_bl:
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$18,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$0C,$18,$18,$18,$18
        .byte $0B,$0C,$0C,$0C,$0C,$18,$18,$18
        .byte $0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $02,$0B,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $02,$02,$0B,$0B,$0C,$0C,$0C,$0C

; Fountain BR quadrant (mirror both axes).
fcm_park_fnt_br:
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$0C,$0C,$0C,$0C
        .byte $18,$18,$18,$0C,$0C,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0B,$02
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02

; Load the 16 park chars. Each cell of the 4x4 footprint gets its own char id
; (PARK_CHAR_BASE+0 through +15) but the actual bitmap reuses one of 7 shared
; templates -- corners use the same tree, edges alternate between grass_a/b,
; centre uses the four fountain quadrants in NW/NE/SW/SE positions.
;
; 4x4 char layout (row-major, same order structure_stamp writes cells):
;     +0  +1  +2  +3       tree  gA   gB   tree
;     +4  +5  +6  +7       gB    fTL  fTR  gA
;     +8  +9 +10 +11       gA    fBL  fBR  gB
;    +12 +13 +14 +15       tree  gB   gA   tree
tiles_load_park:
        #STAMP_CHAR PARK_CHAR_BASE+0,  fcm_park_tree
        #STAMP_CHAR PARK_CHAR_BASE+1,  fcm_park_grass_a
        #STAMP_CHAR PARK_CHAR_BASE+2,  fcm_park_grass_b
        #STAMP_CHAR PARK_CHAR_BASE+3,  fcm_park_tree
        #STAMP_CHAR PARK_CHAR_BASE+4,  fcm_park_grass_b
        #STAMP_CHAR PARK_CHAR_BASE+5,  fcm_park_fnt_tl
        #STAMP_CHAR PARK_CHAR_BASE+6,  fcm_park_fnt_tr
        #STAMP_CHAR PARK_CHAR_BASE+7,  fcm_park_grass_a
        #STAMP_CHAR PARK_CHAR_BASE+8,  fcm_park_grass_a
        #STAMP_CHAR PARK_CHAR_BASE+9,  fcm_park_fnt_bl
        #STAMP_CHAR PARK_CHAR_BASE+10, fcm_park_fnt_br
        #STAMP_CHAR PARK_CHAR_BASE+11, fcm_park_grass_b
        #STAMP_CHAR PARK_CHAR_BASE+12, fcm_park_tree
        #STAMP_CHAR PARK_CHAR_BASE+13, fcm_park_grass_b
        #STAMP_CHAR PARK_CHAR_BASE+14, fcm_park_grass_a
        #STAMP_CHAR PARK_CHAR_BASE+15, fcm_park_tree
        rts

;---------------------------------------------------------------------------------------
; Police department -- a 3x3 cell (24x24 px) building, same footprint as a
; residential/commercial/industrial zone. The blue ($08 commercial-blue) PD
; building sits in the top 2 rows (rows 0-1 of the 3x3 grid) framed by a white
; ($0F) edge moulding, with the "PD" letters in white in the centre cell. The
; bottom row is the building's landscaped grounds: grass ($02) with yellow
; ($06) flower dots and a dark-grey ($0B) driveway in the middle cell.
;
; 9 unique bitmaps -- one per cell of the 3x3 grid.
;---------------------------------------------------------------------------------------

; Row 0: blue building roof with white top edge.
fcm_pol_tl:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $0F,$08,$08,$08,$08,$08,$08,$08   ; white left edge + blue body
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08

fcm_pol_tc:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08

fcm_pol_tr:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F

; Row 1: middle of building. ML has the white left edge; centre has PD letters;
; MR has the white right edge. Bottom row of each is the white south edge of
; the building (the building ends here -- row 2 is grass below).
fcm_pol_ml:
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white south edge

; Centre cell with "PD" in white on blue.
;   col:  0   1   2   3   4   5   6   7
; row 0:  .   .   .   .   .   .   .   .
; row 1:  .   P   P   P   .   D   D   .       PPP DD
; row 2:  .   P   .   P   .   D   .   D       P P D D
; row 3:  .   P   P   P   .   D   .   D       PPP D D
; row 4:  .   P   .   .   .   D   .   D       P   D D
; row 5:  .   P   .   .   .   D   D   .       P   DD
; row 6:  .   .   .   .   .   .   .   .
; row 7:  white south edge
fcm_pol_c:
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$0F,$0F,$0F,$08,$0F,$0F,$08
        .byte $08,$0F,$08,$0F,$08,$0F,$08,$0F
        .byte $08,$0F,$0F,$0F,$08,$0F,$08,$0F
        .byte $08,$0F,$08,$08,$08,$0F,$08,$0F
        .byte $08,$0F,$08,$08,$08,$0F,$0F,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

fcm_pol_mr:
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; Row 2: grass ($02) with yellow ($06) flower dots; centre cell has a dark
; ($0B) driveway approaching the building from the south.
fcm_pol_bl:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

fcm_pol_bc:
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$06,$0B,$0B,$0B,$0B,$06,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02

fcm_pol_br:
        .byte $02,$02,$02,$06,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$06,$02,$02,$02,$02

; 3x3 char layout (row-major, same order structure_stamp writes cells):
;     +0  +1  +2       tl   tc   tr            (building roof)
;     +3  +4  +5       ml   c    mr            (building middle + "PD")
;     +6  +7  +8       bl   bc   br            (grounds: grass + driveway)
tiles_load_police:
        #STAMP_CHAR POLICE_CHAR_BASE+0, fcm_pol_tl
        #STAMP_CHAR POLICE_CHAR_BASE+1, fcm_pol_tc
        #STAMP_CHAR POLICE_CHAR_BASE+2, fcm_pol_tr
        #STAMP_CHAR POLICE_CHAR_BASE+3, fcm_pol_ml
        #STAMP_CHAR POLICE_CHAR_BASE+4, fcm_pol_c
        #STAMP_CHAR POLICE_CHAR_BASE+5, fcm_pol_mr
        #STAMP_CHAR POLICE_CHAR_BASE+6, fcm_pol_bl
        #STAMP_CHAR POLICE_CHAR_BASE+7, fcm_pol_bc
        #STAMP_CHAR POLICE_CHAR_BASE+8, fcm_pol_br
        rts

;---------------------------------------------------------------------------------------
; Population icon -- a single 8x8 human silhouette glyph that prefixes the
; population readout on the status row. Slightly thicker than a stick figure:
; 2-px head, 4-px shoulders/torso, arms outstretched on row 5, legs split with
; a 1-px gap on the bottom row. Black ($00) on the light-grey status-row tile
; ($0C) so it reads at a glance.
;---------------------------------------------------------------------------------------
fcm_pop_icon:
        .byte $0C,$0C,$0C,$00,$00,$0C,$0C,$0C   ; row 0:  . . . X X . . .
        .byte $0C,$0C,$00,$00,$00,$00,$0C,$0C   ; row 1:  . . X X X X . .
        .byte $0C,$0C,$00,$00,$00,$00,$0C,$0C   ; row 2:  . . X X X X . .
        .byte $0C,$0C,$0C,$00,$00,$0C,$0C,$0C   ; row 3:  . . . X X . . .
        .byte $0C,$0C,$00,$00,$00,$00,$0C,$0C   ; row 4:  . . X X X X . .
        .byte $0C,$00,$00,$00,$00,$00,$00,$0C   ; row 5:  . X X X X X X .
        .byte $0C,$0C,$00,$00,$00,$00,$0C,$0C   ; row 6:  . . X X X X . .
        .byte $0C,$0C,$00,$00,$0C,$00,$00,$0C   ; row 7:  . . X X . X X .

tiles_load_pop_icon:
        #STAMP_CHAR POP_ICON_CHAR, fcm_pop_icon
        rts

;---------------------------------------------------------------------------------------
; Residential houses -- low-density evolution of the 3x3 residential zone.
; 9 char slots loaded with 3 unique bitmaps:
;   * fcm_res_house  -- small top-down house with red roof + white walls on
;                       grass, used at the 4 corner positions of the zone.
;   * fcm_res_yard   -- a small dark-green tree on grass, in the center.
;   * fcm_res_grass  -- grass with a couple of yellow dots (flowers), filling
;                       the 4 edge positions between the houses.
; Layout matches structures.asm's row-major (dy*3+dx) cell-offset ordering:
;     +0  +1  +2     house  grass  house
;     +3  +4  +5     grass  yard   grass
;     +6  +7  +8     house  grass  house
;---------------------------------------------------------------------------------------

; Centered top-down house: red ($0D) peaked roof on rows 1-3, white ($0F)
; walls on rows 4-6 with a 2-pixel-wide black ($00) door, grass ($02)
; everywhere else.
fcm_res_house:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$0D,$0D,$0D,$0D,$02,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$0F,$00,$00,$00,$00,$0F,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Center cell: small dark-green ($03) tree with a brown ($04) trunk on a
; grass ($02) field. Different from corner trees so the center reads as a
; deliberate yard / common, not just more landscape.
fcm_res_yard:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$03,$03,$03,$02,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$02,$03,$03,$03,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Edge cell: plain grass with a couple of yellow ($06) flower dots. Reused
; across all 4 edge positions; the pattern reads as "grass" without obvious
; tiling seams against either the corner house or the centre yard.
fcm_res_grass:
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

tiles_load_residential_houses:
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+0, fcm_res_house    ; NW corner
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+1, fcm_res_grass    ; N edge
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+2, fcm_res_house    ; NE corner
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+3, fcm_res_grass    ; W edge
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+4, fcm_res_yard     ; center
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+5, fcm_res_grass    ; E edge
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+6, fcm_res_house    ; SW corner
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+7, fcm_res_grass    ; S edge
        #STAMP_CHAR RES_HOUSE_CHAR_BASE+8, fcm_res_house    ; SE corner
        rts

;---------------------------------------------------------------------------------------
; Residential apartments -- mid-density evolution. Three unique bitmaps reused
; across the 9 char slots:
;   * fcm_apt_building -- a multi-story apartment block (dark gray roof + light
;                         gray walls + dark windows). Used at the 4 corners.
;   * fcm_apt_pavement -- solid road-gray asphalt for the 4 edges, reading as
;                         the lot between buildings.
;   * fcm_apt_court    -- a small paved courtyard with a green bush border in
;                         the middle, used at the center.
;---------------------------------------------------------------------------------------

; Apartment building: 3 floors of windows on light-grey walls with a dark
; roof + foundation; 1-pixel grass borders on left/right so the building
; reads as sitting in its lot rather than tiling edge-to-edge.
fcm_apt_building:
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02   ; row 0: roof top
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 1: roof
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 2: top of wall
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 3: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 4: between floors
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 5: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 6: bottom of wall
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 7: foundation

; Pavement: solid road-gray, no markings (street/lot fill between buildings).
fcm_apt_pavement:
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

; Courtyard: pavement border around a small grass patch with dark-green
; shrubs forming a hollow square. Sits between the 4 corner apartments.
fcm_apt_court:
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$02,$02,$02,$02,$02,$02,$05
        .byte $05,$02,$03,$03,$03,$03,$02,$05
        .byte $05,$02,$03,$02,$02,$03,$02,$05
        .byte $05,$02,$03,$02,$02,$03,$02,$05
        .byte $05,$02,$03,$03,$03,$03,$02,$05
        .byte $05,$02,$02,$02,$02,$02,$02,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

tiles_load_apartments:
        #STAMP_CHAR APT_CHAR_BASE+0, fcm_apt_building    ; NW corner
        #STAMP_CHAR APT_CHAR_BASE+1, fcm_apt_pavement    ; N edge
        #STAMP_CHAR APT_CHAR_BASE+2, fcm_apt_building    ; NE corner
        #STAMP_CHAR APT_CHAR_BASE+3, fcm_apt_pavement    ; W edge
        #STAMP_CHAR APT_CHAR_BASE+4, fcm_apt_court       ; center
        #STAMP_CHAR APT_CHAR_BASE+5, fcm_apt_pavement    ; E edge
        #STAMP_CHAR APT_CHAR_BASE+6, fcm_apt_building    ; SW corner
        #STAMP_CHAR APT_CHAR_BASE+7, fcm_apt_pavement    ; S edge
        #STAMP_CHAR APT_CHAR_BASE+8, fcm_apt_building    ; SE corner
        rts

;---------------------------------------------------------------------------------------
; Industrial-heavy -- the developed industrial tier. Three unique bitmaps
; reused across the 9 char slots, on the industrial-orange ($09) ground:
;   * fcm_ind_factory  -- a small factory building with windows + a small
;                         smokestack on the right. Used at the 4 corners.
;   * fcm_ind_pavement -- orange industrial pavement with dark loading-dock
;                         stripes. Used for the 4 edge slots.
;   * fcm_ind_silo     -- a top-down storage tank in the centre cell.
;---------------------------------------------------------------------------------------

fcm_ind_factory:
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 0: smokestack top
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 1: smokestack
        .byte $09,$09,$0B,$0B,$0B,$0B,$0B,$09   ; row 2: roof + stack base
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 3: roof
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 4: top of walls
        .byte $09,$0C,$00,$0C,$00,$0C,$0C,$09   ; row 5: windows
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 6: walls
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 7: foundation

fcm_ind_pavement:
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe

fcm_ind_silo:
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$0B,$0B,$0B,$09,$09   ; silo top
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09   ; silo wall (LG=$0C)
        .byte $09,$0B,$0C,$0F,$0F,$0C,$0B,$09   ; silo + white reflection
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09
        .byte $09,$09,$0B,$0B,$0B,$0B,$09,$09   ; silo bottom
        .byte $09,$09,$09,$09,$09,$09,$09,$09

tiles_load_industrial_heavy:
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+0, fcm_ind_factory    ; NW corner
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+1, fcm_ind_pavement   ; N edge
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+2, fcm_ind_factory    ; NE corner
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+3, fcm_ind_pavement   ; W edge
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+4, fcm_ind_silo       ; center
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+5, fcm_ind_pavement   ; E edge
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+6, fcm_ind_factory    ; SW corner
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+7, fcm_ind_pavement   ; S edge
        #STAMP_CHAR IND_HEAVY_CHAR_BASE+8, fcm_ind_factory    ; SE corner
        rts

;---------------------------------------------------------------------------------------
; Commercial-heavy -- the developed commercial tier. Three unique bitmaps on
; light-grey sidewalks with blue commercial accents:
;   * fcm_com_shop     -- a storefront building with a blue awning and large
;                         shop windows. Used at the 4 corners.
;   * fcm_com_sidewalk -- patterned light-grey sidewalk for the 4 edges.
;   * fcm_com_plaza    -- a small open plaza with a blue fountain in the
;                         centre cell.
;---------------------------------------------------------------------------------------

; Storefront: light-grey walls with a blue commercial-color awning row and a
; row of big shop windows.
fcm_com_shop:
        .byte $0C,$08,$08,$08,$08,$08,$08,$0C   ; row 0: blue awning
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 1: signboard
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 2: windows
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 3: windows
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 4: between
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 5: big shop window
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 6: big shop window
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; row 7: sidewalk

; Sidewalk: light-grey with a darker grey tile pattern.
fcm_com_sidewalk:
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C

; Plaza: sidewalk frame around a small blue fountain in the centre.
fcm_com_plaza:
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$0B,$0C
        .byte $0C,$0B,$0C,$0C,$0C,$0C,$0B,$0C
        .byte $0C,$0B,$0C,$01,$01,$0C,$0B,$0C   ; blue fountain
        .byte $0C,$0B,$0C,$01,$01,$0C,$0B,$0C
        .byte $0C,$0B,$0C,$0C,$0C,$0C,$0B,$0C
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C

tiles_load_commercial_heavy:
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+0, fcm_com_shop      ; NW corner
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+1, fcm_com_sidewalk  ; N edge
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+2, fcm_com_shop      ; NE corner
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+3, fcm_com_sidewalk  ; W edge
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+4, fcm_com_plaza     ; center
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+5, fcm_com_sidewalk  ; E edge
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+6, fcm_com_shop      ; SW corner
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+7, fcm_com_sidewalk  ; S edge
        #STAMP_CHAR COM_HEAVY_CHAR_BASE+8, fcm_com_shop      ; SE corner
        rts
