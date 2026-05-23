;=======================================================================================
; MEGA-SimCity - NCM city-builder scaffold for the MEGA65.
;=======================================================================================

        .cpu "45gs02"
        .include "platform.asm"

;=======================================================================================
; BASIC stub - BANK 0 : SYS 8210 ($2012)
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

;=======================================================================================
; Main entry.
;=======================================================================================

main_entry:
        cld
        cli

        jsr app_init

app_loop:
        jsr wait_frame
        jsr input_poll
        lda input_action
        cmp #INPUT_QUIT
        beq shutdown
        jsr game_apply_input
        jsr game_tick
        jsr render_frame
        jsr mouse_refresh_sprite
        jmp app_loop

shutdown:
        jsr mouse_shutdown
        cli
        lda #MODE_BASIC
        jsr set_screen_mode
        rts

app_init:
        jsr enable_40mhz

        jsr boot_load_tileset
        jsr boot_load_ui_tiles

        lda #MODE_NCM40
        jsr set_screen_mode

        jsr tiles_init_palette
        jsr tiles_load
        jsr ui_load
        jsr city_init

        jsr mouse_init
        jsr render_init
        jsr mouse_refresh_sprite
        sei
        rts

enable_40mhz:
        lda #65
        sta $00
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #CPU_40MHZ_BIT
        tsb VIC3_CTRL
        lda #$80
        tsb VIC4_HOTREGS
        rts

wait_frame:
        lda VIC_RASTER
_wf_wait_bottom:
        cmp #$F0
        bcs _wf_wait_top
        lda VIC_RASTER
        jmp _wf_wait_bottom
_wf_wait_top:
        lda VIC_RASTER
        cmp #$20
        bcs _wf_wait_top
        rts

;=======================================================================================
; Modules.
;=======================================================================================

        .include "graphics/ncm_screen.asm"
        .include "graphics/ncm_core.asm"
        .include "assets.asm"
        .include "tiles.asm"
UI_TILE_ASSET_BUILD = 0
        .include "ui.asm"
        .include "city.asm"
        .include "render.asm"
        .include "mouse.asm"
        .include "input.asm"
