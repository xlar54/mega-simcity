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
        jsr tiles_load_button_ok
        jsr tiles_load_pop_icon
        rts

tiles_dma_city_from_attic:
        ; Full map-viewport charset image: Attic start -> CHAR_DATA. The
        ; external tileset is char-indexed, so every runtime char id lands at
        ; CHAR_DATA + char_id*64 in one DMA.
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_ASSET_SIZE
        .word ATTIC_TILE_ADDR
        .byte ATTIC_TILE_BANK
        .word $0000             ; low 16 bits of CHAR_DATA ($40000)
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
