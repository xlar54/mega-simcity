;=======================================================================================
; MEGA-SimCity - FCM city-builder scaffold for the MEGA65.
;=======================================================================================

        .cpu "45gs02"
        .include "platform.asm"
        .include "shared/ui_tile_layout.asm"

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
        jsr mouse_dispatch
        lda input_action
        cmp #INPUT_QUIT
        beq shutdown
        jsr game_apply_input
        jsr game_tick
        jsr render_frame
        jsr sprites_refresh
        jsr power_update            ; recompute zone power if the network changed
        jsr bolt_test_update        ; round-robin the bolt over UNPOWERED zones
        jsr funds_update            ; redraw FUNDS readout if it changed
        jmp app_loop

shutdown:
        jsr sprites_shutdown
        cli
        lda #MODE_BASIC
        jsr set_screen_mode
        rts

app_init:
        jsr enable_40mhz
        jsr detect_platform         ; sets sprite_x_fix (real HW vs Xemu) post-unlock

        jsr boot_load_tileset
        jsr boot_load_ui_tiles

        lda #MODE_FCM40
        jsr set_screen_mode

        jsr tiles_init_palette
        jsr tiles_load
        jsr ui_load
        jsr city_init

        jsr mouse_init
        jsr sprites_init
        jsr render_init
        jsr sprites_refresh
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
; Master-loop input dispatch.
;
; Runs each frame after input_poll. Classifies the pointer region (toolbar / map
; viewport / off-map) from the raw state mouse.asm produced, updates map state
; (mouse_over_main, mouse_tile_x/y, cursor), and routes clicks to the right
; handler. Sprite positioning is handled separately by sprites_refresh, so there
; are no sprite calls here.
;=======================================================================================

mouse_dispatch:
        jsr mouse_scroll_view_from_edge

        ; The left UI_LEFT_COLS columns are the toolbar, drawn in front of the
        ; map. Treat that whole band as UI: freeze the map cursor at the toolbox
        ; edge, never paint, and route left-clicks to tool selection.
        lda mouse_x+1
        bmi _md_toolbar
        bne _md_viewport
        lda mouse_x
        cmp #UI_TOOL_PIXEL_RIGHT
        bcs _md_viewport
_md_toolbar:
        lda #1
        sta mouse_over_main
        lda #CURSOR_TOOL_FREEZE_X
        sta mouse_tile_x
        jsr mouse_update_city_cursor
        jmp mouse_handle_ui_click

_md_viewport:
        jsr mouse_pointer_inside_viewport
        bcs _md_main

_md_freeze:
        ; Off-map: leave the cursor on its last tile. The pointer can still
        ; scroll at the edge or click UI.
        jmp mouse_handle_ui_click

_md_main:
        lda #1
        sta mouse_over_main
        jsr mouse_compute_tile_clamped
        jsr mouse_compute_cell_clamped
        jsr mouse_update_city_cursor

        lda mouse_buttons
        and #MOUSE_BUTTON_LEFT
        beq _md_done
        lda #INPUT_PAINT
        sta input_action
_md_done:
        rts

; Gate: a confirmed left-click in the toolbar band hands off to toolbar.asm.
; The high-byte guard rejects pointer X >= 256 (right side of screen) so only
; the real toolbar columns register.
mouse_handle_ui_click:
        lda mouse_left_click
        beq _mhu_done
        lda mouse_x+1
        bmi _mhu_toolbar            ; offscreen-left clamp = column 0 = toolbar
        bne _mhu_done
        lda mouse_x
        cmp #UI_TOOL_PIXEL_RIGHT
        bcs _mhu_done
_mhu_toolbar:
        jmp toolbar_handle_click
_mhu_done:
        rts

;=======================================================================================
; Modules.
;=======================================================================================

        .include "graphics/fcm_screen.asm"
        .include "graphics/fcm_core.asm"
        .include "assets.asm"
        .include "city.asm"
        .include "roads.asm"
        .include "powerlines.asm"
        .include "power.asm"
        .include "cost-management.asm"
        .include "structures.asm"
        .include "render.asm"
        .include "mouse.asm"
        .include "sprites.asm"
        .include "viewport.asm"
        .include "toolbar.asm"
        .include "input.asm"
        .include "audio.asm"

; The world map (240x200 cells) lives in Attic RAM at ATTIC_MAP_PHYS, filled by
; city_fill_ground at boot -- it is not allocated in chip RAM. See city.asm.
