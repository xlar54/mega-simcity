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
        jsr clock_tick              ; advance the in-game month every 3 wall minutes
        jsr render_frame
        jsr sprites_refresh
        jsr power_update            ; recompute zone power if the network changed
        jsr bolt_test_update        ; round-robin the bolt over UNPOWERED zones
        jsr funds_update            ; redraw FUNDS readout if it changed
        jsr clock_update            ; redraw DATE readout if it changed
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
        jsr boot_load_ovr_save
        jsr boot_load_ovr_load
        jsr boot_load_ovr_inspect

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
        ; Modal overlay: any confirmed left-click goes straight to the popup's
        ; OK hit-test. Edge-scroll, cursor updates, tool selection, and paint
        ; are all suppressed so the popup is genuinely blocking. The toolbar
        ; gate at mouse_handle_ui_click below also routes to the overlay if it
        ; somehow gets reached, but the primary path is here.
        lda overlay_active
        beq _md_no_overlay
        lda mouse_left_click
        beq _md_overlay_idle
        jmp overlay_handle_click
_md_overlay_idle:
        rts
_md_no_overlay:
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
; the real toolbar columns register. Two Y bands forward to toolbar.asm:
;   * Top-strip rows (rows 1..1+TOP_BTN_H-1, the menu icons under MEGACITY) --
;     forwarded regardless of X, because top buttons can sit past col 4
;     (e.g. SAVE at col 4 = pixel 32, beyond UI_TOOL_PIXEL_RIGHT). The
;     table-driven hit test in toolbar_handle_click decides hit vs miss.
;   * Left-toolbar X band (cols 0..UI_LEFT_COLS-1) for the button grid below.
mouse_handle_ui_click:
        lda mouse_left_click
        beq _mhu_done
        ; Modal overlay: when one is open, every click is forwarded to the
        ; overlay's hit-test (OK button vs swallow). Nothing else runs until
        ; the overlay closes.
        lda overlay_active
        beq _mhu_no_overlay
        jmp overlay_handle_click
_mhu_no_overlay:
        lda mouse_x+1
        bmi _mhu_toolbar            ; offscreen-left clamp = column 0 = toolbar
        bne _mhu_done
        lda mouse_y
        cmp #INSPECT_ICON_ROW * 8
        bcc _mhu_check_left         ; above the top-strip Y band
        cmp #(INSPECT_ICON_ROW + TOP_BTN_H) * 8
        bcc _mhu_toolbar            ; inside top-strip rows -> forward regardless of X
_mhu_check_left:
        lda mouse_x
        cmp #UI_TOOL_PIXEL_RIGHT
        bcs _mhu_done
_mhu_toolbar:
        jmp toolbar_handle_click
_mhu_done:
        rts

;=======================================================================================
; Save overlay invoke. DMA the save-overlay PRG from its Attic slot down to
; $A000, then jsr the entry point. The overlay drives its own modal loop and
; rts back here when done. Triggered from toolbar.asm when the SAVE icon is
; clicked.
;=======================================================================================
ovr_save_invoke:
        lda #$00
        sta $D707                    ; F018B DMA list at next bytes
        .byte $80, ATTIC_OVR_SAVE_MB    ; src MB
        .byte $81, $00                       ; dst MB = bank 0
        .byte $00                            ; end of MB options
        .byte $00                            ; job: copy
        .word OVR_WINDOW_SIZE              ; bytes
        .word ATTIC_OVR_SAVE_ADDR        ; src addr
        .byte ATTIC_OVR_SAVE_BANK        ; src bank
        .word OVR_WINDOW_ADDR              ; dst addr ($A000)
        .byte $00                            ; dst bank
        .byte $00                            ; end of list
        .word $0000

        jmp OVR_WINDOW_ADDR        ; tail-call the overlay; it rts's back to our caller

;=======================================================================================
; Load overlay invoke. Same idea as ovr_save_invoke -- the LOAD overlay
; shares the $A000 CPU window, so DMA whichever overlay is needed at trigger
; time and jsr its entry point. Triggered from toolbar.asm when LOAD is clicked.
;=======================================================================================
ovr_load_invoke:
        lda #$00
        sta $D707
        .byte $80, ATTIC_OVR_LOAD_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word OVR_WINDOW_SIZE
        .word ATTIC_OVR_LOAD_ADDR
        .byte ATTIC_OVR_LOAD_BANK
        .word OVR_WINDOW_ADDR
        .byte $00
        .byte $00
        .word $0000

        jmp OVR_WINDOW_ADDR

;=======================================================================================
; Inspect overlay invoke. DMA the inspector PRG to $A000 and tail-jump in.
; Caller (city.asm _cps_inspect) has set city_ptr_x/y + called city_cell_ptr
; so MAP_PTR (zero page) is already pointing at the inspected cell -- the
; DMA + jmp preserves zero page. The overlay reads the cell, looks up its
; label, sets default popup geometry, and opens the popup; main game's
; mouse_dispatch / overlay_handle_click handle the OK click afterwards.
;=======================================================================================
ovr_inspect_invoke:
        lda #$00
        sta $D707
        .byte $80, ATTIC_OVR_INSPECTOR_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word OVR_WINDOW_SIZE
        .word ATTIC_OVR_INSPECTOR_ADDR
        .byte ATTIC_OVR_INSPECTOR_BANK
        .word OVR_WINDOW_ADDR
        .byte $00
        .byte $00
        .word $0000

        jmp OVR_WINDOW_ADDR

;=======================================================================================
; Modules.
;=======================================================================================

        .include "graphics/fcm_screen.asm"
        .include "graphics/fcm_core.asm"
        .include "assets.asm"
        .include "city.asm"
        .include "trees.asm"
        .include "water_shore.asm"
        .include "world_gen.asm"
        .include "linear_net.asm"
        .include "roads.asm"
        .include "rails.asm"
        .include "powerlines.asm"
        .include "power.asm"
        .include "cost-management.asm"
        .include "structures.asm"
        .include "clock.asm"
        .include "render.asm"
        .include "mouse.asm"
        .include "sprites.asm"
        .include "viewport.asm"
        .include "toolbar.asm"
        .include "input.asm"
        .include "audio.asm"
        .include "overlays/popup.asm"

; The world map (240x200 cells) lives in Attic RAM at ATTIC_MAP_PHYS, filled by
; city_fill_ground at boot -- it is not allocated in chip RAM. See city.asm.
