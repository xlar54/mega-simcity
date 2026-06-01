;=======================================================================================
; MEGA-SimCity loader -- Phase 1: prove the trampoline before stripping main.
;
; Built as its own PRG. BASIC SYS bootstraps INTO HERE, not into mega-simcity.prg
; directly. Job:
;   1. KERNAL_LOAD every disk asset (tileset, uitiles, ovr-save, ovr-load,
;      ovr-inspect) into its Attic slot.
;   2. Init the palette and DMA every char bitmap into char RAM. Display mode
;      is left at the C65 BASIC default; main owns display-state changes.
;   3. Hop to a tail trampoline parked at TRAMP_DEST ($1600) that KERNAL_LOADs
;      mega-simcity.prg over us at $2001 and JMPs to main_entry.
;
; The whole loader runs in pristine BASIC65 env: no SEI, no 40 MHz, no custom
; MAP, no $01 / $D030 / VIC-mode changes. That's what HYPPO LOAD requires, so
; the loader is the one place every KERNAL call lives at boot. Note: this is
; about BOOT asset loading. The in-game SAVE/LOAD overlays still use KERNAL
; disk I/O at gameplay time -- isolating BOOT loads is the point of this PRG,
; not eliminating KERNAL from the game.
;
; PHASING (see PR discussion):
;   Phase 1 (this commit): build the loader as a real PRG, leave main unchanged.
;     The loader stages assets, trampoline-loads mega-simcity.prg, and main
;     redundantly re-loads the same assets via its own app_init. That's
;     deliberate -- it proves the trampoline and second KERNAL_LOAD round-trip
;     on real hardware before we delete anything resident.
;   Phase 2 (follow-up): strip main of boot_load_*, assets.asm, tiles_load,
;     ui_load; main_entry assumes graphics assets are already resident. This
;     is where the ~9 KB resident savings actually land.
;=======================================================================================

        .cpu "45gs02"
        .include "platform.asm"
        .include "shared/ui_tile_layout.asm"

        ; main_entry is the BASIC SYS target in main.asm ($2012, after the
        ; BASIC stub at $2001..$2011). We don't .include the main .lbl here
        ; because the loader's own `.include "assets.asm"` defines every
        ; fcm_*/tiles_load_* label that main also defines, and 64tass treats
        ; the duplicate (same-value) definitions as errors. main_entry is the
        ; only main symbol the loader needs; pin it explicitly. Phase 2 will
        ; revisit if main_entry's address moves (e.g. BASIC stub removal).
main_entry              = $2012

;=======================================================================================
; BASIC stub - BANK 0 : SYS 8210 ($2012)
; Same convention as main today, so RUN from BASIC lands in loader_entry.
;=======================================================================================

        * = $2001

        .word (+), 2026
        .byte $fe, $02, $30
        .byte ':'
        .byte $9e
        .text "8210"
        .byte 0
+       .word 0

        * = $2012

loader_entry:
        cld
        cli                                  ; keep KERNAL IRQ alive for boot LOADs

        ; --- Stage 1: disk -> Attic ---------------------------------------------------
        ; Each of these is a KERNAL_LOAD into a chip-RAM staging buffer plus a
        ; DMA up to the matching Attic slot. Same code as today's
        ; boot_load_overlays sequence, lifted verbatim from assets.asm.
        jsr boot_load_tileset                ; -> ATTIC_TILE_*
        jsr boot_load_ui_tiles               ; -> ATTIC_UI_TILE_*
        jsr boot_load_ovr_disk               ; -> ATTIC_OVR_DISK_*
        jsr boot_load_ovr_inspect            ; -> ATTIC_OVR_INSPECTOR_*

        ; --- Stage 2: char RAM ---------------------------------------------------------
        ; Display mode stays at the C65 BASIC default (text). Palette writes
        ; and char-RAM DMAs work in any VIC mode, so there's no reason to flip
        ; into FCM40 here -- main_entry will do that as its first display step.
        ; Keeping the loader in BASIC text mode means the final KERNAL_LOAD in
        ; the trampoline runs in the same VIC state that the boot_load_* calls
        ; above run in. The map and UI charsets DMA from Attic; only the small
        ; runtime/control chars still STAMP_CHAR-DMA from bitmap tables baked
        ; into THIS PRG (cursor, top-strip buttons, OK button, population icon).
        jsr tiles_init_palette
        jsr tiles_load
        jsr ui_load

        ; --- Stage 3: hand off to the tail trampoline ---------------------------------
        ; The next step KERNAL_LOADs mega-simcity.prg over us at $2001, which
        ; means the running instruction stream cannot be inside the loader
        ; anymore. Copy a tiny trampoline (KERNAL_SETBNK/SETLFS/SETNAM/LOAD +
        ; JMP) into TRAMP_DEST ($1600, reserved in platform.asm) and jump to
        ; it. mega-simcity.prg's load range is $2001..end so $1600 is
        ; untouched by the second LOAD.
        ;
        ; LOAD convention: secondary=1 (use PRG header). The 2-byte header in
        ; mega-simcity.prg places the body starting at $2001+2 = $2003. Today
        ; main.asm puts a BASIC stub at $2001..$2011 and main_entry at $2012
        ; (the SYS target). In Phase 1 main is unchanged, so the trampoline
        ; just JMPs to main_entry's address as imported via the .lbl file.
        ldx #tramp_size
_lcp:   lda tramp_src-1,x
        sta TRAMP_DEST-1,x
        dex
        bne _lcp
        jmp TRAMP_DEST

tramp_src:
.logical TRAMP_DEST
        lda #$00                             ; data bank = 0 (chip RAM)
        ldx #$00                             ; filename bank = 0
        jsr KERNAL_SETBNK
        lda #$00                             ; logical file 0
        ldx #$08                             ; device 8
        ldy #$01                             ; secondary 1 = use PRG header for load addr
        jsr KERNAL_SETLFS
        lda #main_prg_name_end - main_prg_name
        ldx #<main_prg_name
        ldy #>main_prg_name
        jsr KERNAL_SETNAM
        lda #$00                             ; 0 = LOAD (1 = VERIFY)
        ldx #$00                             ; X/Y unused when secondary=1
        ldy #$00
        jsr KERNAL_LOAD
        ; mega-simcity is now resident at $2001. JMP to its entry point.
        jmp main_entry
main_prg_name:
        .text "mega-simcity"
main_prg_name_end:
.endlogical
tramp_size = * - tramp_src
        .cerror tramp_size > 255, "loader trampoline > 255 bytes; X-indexed copy loop overflows"

;=======================================================================================
; Modules pulled in from the existing tree -- ONLY the boot/asset surface.
; Nothing here is needed at gameplay time, which is the whole point: the moment
; megasim.prg loads over us, every byte of this PRG vanishes from RAM with no
; loss to the resident budget.
;=======================================================================================

        .include "graphics/fcm_screen.asm"   ; set_screen_mode (and only that)
        .include "graphics/fcm_core.asm"     ; STAMP_CHAR macro the tile loaders need
        .include "assets.asm"                ; boot_load_*, tiles_init_palette,
                                             ; tiles_load, ui_load, tiles_load_*,
                                             ; all fcm_* bitmap tables (~10 KB)
