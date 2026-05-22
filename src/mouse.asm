;=======================================================================================
; Mouse pointer and map cursor.
;
; Reads a 1351-compatible mouse from control port 1, keeps a 320x200 logical
; mouse position, and displays sprite 0 as either a pointer or a snapped
; 16x16 map cursor.
;=======================================================================================

MOUSE_SPRITE_POINTER    = 0
MOUSE_SPRITE_BLOCK      = 1

mouse_test_init:
        lda #<160
        sta mouse_x
        lda #>160
        sta mouse_x+1
        lda #100
        sta mouse_y
        stz mouse_y+1
        lda #(100 + SPRITE_SCREEN_Y)
        sta mouse_drawn_sprite_y
        lda #SPRITE_SCREEN_Y
        sta mouse_anim_y
        lda #1
        sta mouse_anim_dir

        stz mouse_buttons
        stz mouse_prev_buttons
        stz mouse_left_click
        stz mouse_over_main
        stz mouse_scroll_tick
        stz mouse_scroll_bits
        lda #$FF
        sta mouse_sprite_mode

        jsr mouse_seed_pot_baseline

        jsr mouse_sprite_init
        jsr mouse_use_pointer_shape
        jmp mouse_position_pointer_sprite

mouse_test_poll:
        stz mouse_left_click
        jsr mouse_read_motion
        jsr mouse_read_buttons
        jsr mouse_update_click
        jsr mouse_use_pointer_shape
        jmp mouse_position_pointer_sprite

mouse_init:
        lda #<160
        sta mouse_x
        lda #>160
        sta mouse_x+1
        lda #100
        sta mouse_y
        stz mouse_y+1
        lda #(100 + SPRITE_SCREEN_Y)
        sta mouse_drawn_sprite_y

        stz mouse_buttons
        stz mouse_prev_buttons
        stz mouse_left_click
        stz mouse_over_main
        stz mouse_scroll_tick
        stz mouse_scroll_bits
        lda #$FF
        sta mouse_sprite_mode

        jsr mouse_seed_pot_baseline
        jsr mouse_sprite_init
        jsr mouse_update_hover
        rts

mouse_poll:
        stz mouse_left_click
        stz mouse_scroll_bits
        jsr mouse_read_motion
        jsr mouse_read_buttons
        jsr mouse_update_click
        jsr mouse_update_hover
        rts

mouse_refresh_sprite:
        jsr mouse_use_pointer_shape
        jsr mouse_position_pointer_sprite

        lda mouse_over_main
        beq _mrs_hide_block
        jsr mouse_use_block_shape
        jmp mouse_position_block_sprite

_mrs_hide_block:
        jmp mouse_hide_block_sprite

mouse_shutdown:
        lda SPRITE_ENABLE
        and #%11111100
        sta SPRITE_ENABLE
        rts

mouse_sprite_init:
        lda #<mouse_sprite_ptrs
        sta VIC4_SPRPTRADRLSB
        lda #>mouse_sprite_ptrs
        sta VIC4_SPRPTRADRMSB
        lda #$80
        sta VIC4_SPRPTRBNK

        lda #$0F
        sta SPRITE0_COLOR
        lda #$0A
        sta SPRITE1_COLOR

        lda SPRITE_MULTICOLOR
        and #%11111100
        sta SPRITE_MULTICOLOR
        lda SPRITE_X_EXPAND
        and #%11111100
        sta SPRITE_X_EXPAND
        lda SPRITE_Y_EXPAND
        and #%11111100
        sta SPRITE_Y_EXPAND
        lda SPRITE_PRIORITY
        and #%11111100
        sta SPRITE_PRIORITY

        lda SPRITE_ENABLE
        ora #$01
        and #%11111101
        sta SPRITE_ENABLE

        jsr mouse_use_pointer_shape
        jmp mouse_use_block_shape

mouse_read_motion:
        ldz #$00
        php
        sei
        lda CIA1_PORT_A
        sta mouse_saved_pra
        lda CIA1_DDRA
        sta mouse_saved_ddra
        lda CIA1_DDRB
        sta mouse_saved_ddrb

        jsr mouse_prepare_1351_read
        jsr mouse_select_port1_pots
        jsr mouse_settle_pots

        ; Sample BOTH pots back-to-back, right after the settle, before any
        ; per-axis processing. X was being read fresh but Y was read only after
        ; all the X delta math, which during NCM stalls the CPU long enough that
        ; the POTY sample lands in a noisier window. Reading them together gives
        ; Y the same clean sample X gets.
        jsr mouse_read_pot_x
        sta mouse_potx_sample
        jsr mouse_read_pot_y
        sta mouse_poty_sample

        lda mouse_potx_sample
        ldy mouse_old_pot_x
        jsr mouse_move_check
        sty mouse_old_pot_x
        bcc +
        jsr mouse_double_delta
        jsr mouse_apply_delta_x
+
        lda mouse_poty_sample
        ldy mouse_old_pot_y
        jsr mouse_move_check
        sty mouse_old_pot_y
        bcc _mrm_done_y
        jsr mouse_double_delta
        jsr mouse_apply_delta_y
_mrm_done_y:
        lda mouse_saved_pra
        sta CIA1_PORT_A
        lda mouse_saved_ddra
        sta CIA1_DDRA
        lda mouse_saved_ddrb
        sta CIA1_DDRB
        plp
        rts

mouse_seed_pot_baseline:
        php
        sei
        lda CIA1_PORT_A
        sta mouse_saved_pra
        lda CIA1_DDRA
        sta mouse_saved_ddra
        lda CIA1_DDRB
        sta mouse_saved_ddrb

        jsr mouse_prepare_1351_read
        jsr mouse_select_port1_pots
        jsr mouse_settle_pots
        jsr mouse_read_pot_x
        sta mouse_old_pot_x
        jsr mouse_read_pot_y
        sta mouse_old_pot_y
        jsr mouse_read_pot_b_y
        sta mouse_old_pot_b_y

        lda mouse_saved_pra
        sta CIA1_PORT_A
        lda mouse_saved_ddra
        sta CIA1_DDRA
        lda mouse_saved_ddrb
        sta CIA1_DDRB
        plp
        rts

mouse_prepare_1351_read:
        lda #0
        sta CIA1_DDRB
        sta CIA1_DDRA
        rts

mouse_select_port1_pots:
        lda CIA1_DDRA
        ora #%11000000
        sta CIA1_DDRA
        lda #MOUSE_POT_PORT1_SELECT
        sta CIA1_PORT_A
        rts

mouse_settle_pots:
        ldy #24
_msp_outer:
        ldx #0
_msp_inner:
        dex
        bne _msp_inner
        dey
        bne _msp_outer
        rts

mouse_read_pot_x:
        lda M65_POT_PORT_A_X
        cmp M65_POT_PORT_A_X
        bne mouse_read_pot_x
        and #$7E
        rts

mouse_read_pot_y:
        lda M65_POT_PORT_A_Y
        cmp M65_POT_PORT_A_Y
        bne mouse_read_pot_y
        and #$7E
        rts

mouse_read_pot_y_raw:
        lda M65_POT_PORT_A_Y
        cmp M65_POT_PORT_A_Y
        bne mouse_read_pot_y_raw
        and #$7F
        rts

mouse_read_pot_b_y:
        lda M65_POT_PORT_B_Y
        cmp M65_POT_PORT_B_Y
        bne mouse_read_pot_b_y
        and #$7E
        rts

mouse_read_buttons:
        php
        sei
        lda CIA1_PORT_A
        sta mouse_saved_pra
        lda CIA1_DDRA
        sta mouse_saved_ddra
        lda CIA1_DDRB
        sta mouse_saved_ddrb

        jsr mouse_prepare_1351_read
        lda CIA1_PORT_B
        eor #$FF
        and #$1F
        sta mouse_buttons

        lda mouse_saved_pra
        sta CIA1_PORT_A
        lda mouse_saved_ddra
        sta CIA1_DDRA
        lda mouse_saved_ddrb
        sta CIA1_DDRB
        plp
        rts

mouse_update_click:
        lda mouse_buttons
        and #MOUSE_BUTTON_LEFT
        beq _muc_store
        lda mouse_prev_buttons
        and #MOUSE_BUTTON_LEFT
        bne _muc_store
        lda #1
        sta mouse_left_click
_muc_store:
        lda mouse_buttons
        sta mouse_prev_buttons
        rts

mouse_update_hover:
        jsr mouse_scroll_view_from_edge
        jsr mouse_pointer_inside_viewport
        bcs _muh_main
        lda mouse_edge_active
        beq _muh_pointer

_muh_main:
        lda #1
        sta mouse_over_main
        jsr mouse_compute_tile_clamped
        jsr mouse_update_city_cursor
        jsr mouse_use_pointer_shape
        jsr mouse_position_pointer_sprite

        lda mouse_buttons
        and #MOUSE_BUTTON_LEFT
        beq _muh_done
        lda #INPUT_PAINT
        sta input_action
_muh_done:
        rts

_muh_pointer:
        stz mouse_over_main
        stz mouse_scroll_tick
        jsr mouse_use_pointer_shape
        jsr mouse_position_pointer_sprite
        jmp mouse_handle_ui_click

mouse_pointer_inside_viewport:
        lda mouse_y+1
        bne _mpiv_no
        lda mouse_y
        cmp #MAIN_PIXEL_Y
        bcc _mpiv_no
        cmp #MAIN_PIXEL_BOTTOM
        bcs _mpiv_no

        lda mouse_x+1
        bmi _mpiv_no
        bne _mpiv_check_right
        lda mouse_x
        cmp #MAIN_PIXEL_X
        bcc _mpiv_no

_mpiv_check_right:
        lda mouse_x+1
        cmp #>MAIN_PIXEL_RIGHT
        bcc _mpiv_yes
        bne _mpiv_no
        lda mouse_x
        cmp #<MAIN_PIXEL_RIGHT
        bcc _mpiv_yes

_mpiv_no:
        clc
        rts

_mpiv_yes:
        sec
        rts

mouse_compute_tile:
        sec
        lda mouse_x
        sbc #<MAIN_PIXEL_X
        sta mouse_rel
        lda mouse_x+1
        sbc #>MAIN_PIXEL_X
        sta mouse_rel+1

        ldx #4
_mct_x_shift:
        lsr mouse_rel+1
        ror mouse_rel
        dex
        bne _mct_x_shift
        lda mouse_rel
        sta mouse_tile_x

        sec
        lda mouse_y
        sbc #MAIN_PIXEL_Y
        sta mouse_rel
        stz mouse_rel+1

        ldx #4
_mct_y_shift:
        lsr mouse_rel+1
        ror mouse_rel
        dex
        bne _mct_y_shift
        lda mouse_rel
        sta mouse_tile_y
        rts

mouse_compute_tile_clamped:
        lda mouse_x+1
        bmi _mctc_x_min
        bne _mctc_x_check_right
        lda mouse_x
        cmp #MAIN_PIXEL_X
        bcc _mctc_x_min

_mctc_x_check_right:
        lda mouse_x+1
        cmp #>MAIN_PIXEL_RIGHT
        bcc _mctc_x_compute
        bne _mctc_x_max
        lda mouse_x
        cmp #<MAIN_PIXEL_RIGHT
        bcc _mctc_x_compute

_mctc_x_max:
        lda #MAIN_TILE_COLS-1
        sta mouse_tile_x
        bra _mctc_y

_mctc_x_min:
        stz mouse_tile_x
        bra _mctc_y

_mctc_x_compute:
        sec
        lda mouse_x
        sbc #<MAIN_PIXEL_X
        sta mouse_rel
        lda mouse_x+1
        sbc #>MAIN_PIXEL_X
        sta mouse_rel+1

        ldx #4
_mctc_x_shift:
        lsr mouse_rel+1
        ror mouse_rel
        dex
        bne _mctc_x_shift
        lda mouse_rel
        sta mouse_tile_x

_mctc_y:
        lda mouse_y+1
        bmi _mctc_y_min
        bne _mctc_y_max
        lda mouse_y
        cmp #MAIN_PIXEL_Y
        bcc _mctc_y_min
        cmp #MAIN_PIXEL_BOTTOM
        bcs _mctc_y_max

        sec
        lda mouse_y
        sbc #MAIN_PIXEL_Y
        sta mouse_rel
        stz mouse_rel+1

        ldx #4
_mctc_y_shift:
        lsr mouse_rel+1
        ror mouse_rel
        dex
        bne _mctc_y_shift
        lda mouse_rel
        sta mouse_tile_y
        rts

_mctc_y_min:
        stz mouse_tile_y
        rts

_mctc_y_max:
        lda #MAIN_TILE_ROWS-1
        sta mouse_tile_y
        rts

mouse_scroll_view_from_edge:
        stz mouse_edge_active

        lda mouse_scroll_bits
        and #MOUSE_SCROLL_LEFT
        bne _msv_mark_left
        lda mouse_x+1
        bpl _msv_right_check
_msv_mark_left:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_LEFT
        sta mouse_edge_active

_msv_right_check:
        lda mouse_scroll_bits
        and #MOUSE_SCROLL_RIGHT
        bne _msv_mark_right
        lda mouse_x+1
        bmi _msv_up_check
        cmp #>(MOUSE_MAX_X + 1)
        bcc _msv_up_check
        bne _msv_mark_right
        lda mouse_x
        cmp #<(MOUSE_MAX_X + 1)
        bcc _msv_up_check
_msv_mark_right:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_RIGHT
        sta mouse_edge_active

_msv_up_check:
        lda mouse_scroll_bits
        and #MOUSE_SCROLL_UP
        bne _msv_mark_up
        lda mouse_y+1
        bpl _msv_down_check
_msv_mark_up:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_UP
        sta mouse_edge_active

_msv_down_check:
        lda mouse_scroll_bits
        and #MOUSE_SCROLL_DOWN
        beq _msv_maybe_scroll
        lda mouse_edge_active
        ora #MOUSE_SCROLL_DOWN
        sta mouse_edge_active

_msv_maybe_scroll:
        lda mouse_edge_active
        bne _msv_count
        stz mouse_scroll_tick
        rts

_msv_count:
        inc mouse_scroll_tick
        lda mouse_scroll_tick
        cmp #MOUSE_SCROLL_DELAY
        bcs _msv_do_scroll
        rts

_msv_do_scroll:
        stz mouse_scroll_tick

        lda mouse_edge_active
        and #MOUSE_SCROLL_LEFT
        beq _msv_do_right
        lda view_x
        beq _msv_do_right
        dec view_x
        jsr render_mark_view_dirty

_msv_do_right:
        lda mouse_edge_active
        and #MOUSE_SCROLL_RIGHT
        beq _msv_do_up
        lda view_x
        cmp #CITY_VIEW_MAX_X
        bcs _msv_do_up
        inc view_x
        jsr render_mark_view_dirty

_msv_do_up:
        lda mouse_edge_active
        and #MOUSE_SCROLL_UP
        beq _msv_do_down
        lda view_y
        beq _msv_do_down
        dec view_y
        jsr render_mark_view_dirty

_msv_do_down:
        lda mouse_edge_active
        and #MOUSE_SCROLL_DOWN
        beq _msv_done
        lda view_y
        cmp #CITY_VIEW_MAX_Y
        bcs _msv_done
        inc view_y
        jsr render_mark_view_dirty
_msv_done:
        rts

mouse_update_city_cursor:
        clc
        lda view_x
        adc mouse_tile_x
        sta cursor_x

        clc
        lda view_y
        adc mouse_tile_y
        sta cursor_y
        rts

mouse_handle_ui_click:
        lda mouse_left_click
        beq _mhu_done
        lda mouse_x+1
        bne _mhu_done
        lda mouse_x
        cmp #MAIN_PIXEL_X
        bcs _mhu_done
        lda mouse_y
        cmp #MAIN_PIXEL_Y
        bcc _mhu_done

        lda mouse_x
        lsr
        lsr
        lsr
        sta mouse_ui_col
        lda mouse_y
        lsr
        lsr
        lsr
        sta mouse_ui_row

        lda mouse_ui_col
        cmp #UI_LEFT_COLS
        bcs _mhu_done

        lda mouse_ui_row
        cmp #5
        bcc _mhu_done
        cmp #7
        bcc _mhu_zone
        cmp #9
        bcc _mhu_zone_ci
        cmp #11
        bcc _mhu_zone_pw
        rts

_mhu_zone:
        lda mouse_ui_col
        cmp #2
        bcc _mhu_road
        lda #TILE_RESIDENTIAL
        sta selected_tile
        rts

_mhu_zone_ci:
        lda mouse_ui_col
        cmp #2
        bcc _mhu_commercial
        lda #TILE_INDUSTRIAL
        sta selected_tile
        rts

_mhu_zone_pw:
        lda mouse_ui_col
        cmp #2
        bcc _mhu_power
        lda #TILE_WATER
        sta selected_tile
        rts

_mhu_road:
        lda #TILE_ROAD
        sta selected_tile
        rts

_mhu_commercial:
        lda #TILE_COMMERCIAL
        sta selected_tile
        rts

_mhu_power:
        lda #TILE_POWER
        sta selected_tile
_mhu_done:
        rts

mouse_position_pointer_sprite:
        lda mouse_x
        sta mouse_sprite_x
        lda mouse_x+1
        sta mouse_sprite_x+1

        clc
        lda mouse_sprite_x
        adc #<SPRITE_SCREEN_X
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>SPRITE_SCREEN_X
        sta mouse_sprite_x+1

        lda mouse_sprite_x+1
        bpl _mpps_y
        stz mouse_sprite_x
        stz mouse_sprite_x+1

_mpps_y:
        lda mouse_y+1
        bmi _mpps_top
        beq _mpps_check_y_max
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
        bra _mpps_store_y

_mpps_check_y_max:
        lda mouse_y
        cmp #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y + 1)
        bcc _mpps_store_y
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
        bra _mpps_store_y

_mpps_top:
        lda #(256 - SPRITE_SCREEN_Y)
_mpps_store_y:
        clc
        adc #SPRITE_SCREEN_Y
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_position_test_pointer_sprite:
        lda mouse_x
        sta mouse_sprite_x
        lda mouse_x+1
        sta mouse_sprite_x+1

        lda mouse_y
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_test_animate_sprite_y:
        ; Final-step diagnostic: ignore mouse_y for the sprite and drive
        ; SPRITE0_Y directly. If this still sticks, the issue is VIC sprite
        ; display state under active NCM, not mouse accumulation.
        lda mouse_x
        sta mouse_sprite_x
        lda mouse_x+1
        sta mouse_sprite_x+1

        lda mouse_sprite_x+1
        cmp #>MOUSE_POINTER_MAX_X
        bcc _mtasy_add_screen_x
        bne _mtasy_cap_x
        lda mouse_sprite_x
        cmp #<(MOUSE_POINTER_MAX_X + 1)
        bcc _mtasy_add_screen_x

_mtasy_cap_x:
        lda #<MOUSE_POINTER_MAX_X
        sta mouse_sprite_x
        lda #>MOUSE_POINTER_MAX_X
        sta mouse_sprite_x+1

_mtasy_add_screen_x:
        clc
        lda mouse_sprite_x
        adc #<SPRITE_SCREEN_X
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>SPRITE_SCREEN_X
        sta mouse_sprite_x+1

        ; DEBUG: force a FIXED sprite Y (60, near the top). If the sprite
        ; parks near the top, $D001 controls sprite Y and the bounce is the
        ; problem. If it still falls/sticks at the bottom, $D001 does NOT drive
        ; the sprite Y in this mode and something else does.
        jsr mouse_advance_anim_y        ; keep advancing so the border heartbeat sweeps
        lda #60
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_advance_anim_y:
        lda mouse_anim_dir
        beq _may_up

        lda mouse_anim_y
        cmp #MOUSE_SPRITE_MAX_Y
        bcs _may_turn_up
        inc mouse_anim_y
        rts

_may_turn_up:
        stz mouse_anim_dir
        dec mouse_anim_y
        rts

_may_up:
        lda mouse_anim_y
        cmp #SPRITE_SCREEN_Y
        beq _may_turn_down
        bcc _may_turn_down
        dec mouse_anim_y
        rts

_may_turn_down:
        lda #1
        sta mouse_anim_dir
        inc mouse_anim_y
        rts

mouse_position_block_sprite:
        lda mouse_tile_x
        sta mouse_sprite_x
        stz mouse_sprite_x+1
        ldx #4
_mpb_x_shift:
        asl mouse_sprite_x
        rol mouse_sprite_x+1
        dex
        bne _mpb_x_shift

        clc
        lda mouse_sprite_x
        adc #<(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta mouse_sprite_x+1

        lda mouse_tile_y
        asl
        asl
        asl
        asl
        clc
        adc #(SPRITE_SCREEN_Y + MAIN_PIXEL_Y)
        sta mouse_sprite_y
        jmp mouse_set_block_sprite_position

mouse_set_sprite_position:
        lda SPRITE_X_MSB
        and #$FE
        sta SPRITE_X_MSB
        lda mouse_sprite_x+1
        and #$01
        beq +
        lda SPRITE_X_MSB
        ora #$01
        sta SPRITE_X_MSB
+
        lda VIC4_SPRXMSB9
        and #$FE
        sta VIC4_SPRXMSB9
        lda mouse_sprite_x+1
        and #$02
        beq +
        lda VIC4_SPRXMSB9
        ora #$01
        sta VIC4_SPRXMSB9
+
        lda VIC4_SPRYMSB8
        and #$FE
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #$FE
        sta VIC4_SPRYMSB9

        lda mouse_sprite_x
        sta SPRITE0_X
        lda mouse_sprite_y
        sta SPRITE0_Y
        rts

mouse_set_block_sprite_position:
        lda SPRITE_X_MSB
        and #%11111101
        sta SPRITE_X_MSB
        lda mouse_sprite_x+1
        and #$01
        beq +
        lda SPRITE_X_MSB
        ora #%00000010
        sta SPRITE_X_MSB
+
        lda VIC4_SPRXMSB9
        and #%11111101
        sta VIC4_SPRXMSB9
        lda mouse_sprite_x+1
        and #$02
        beq +
        lda VIC4_SPRXMSB9
        ora #%00000010
        sta VIC4_SPRXMSB9
+
        lda VIC4_SPRYMSB8
        and #%11111101
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11111101
        sta VIC4_SPRYMSB9

        lda mouse_sprite_x
        sta SPRITE1_X
        lda mouse_sprite_y
        sta SPRITE1_Y

        lda SPRITE_ENABLE
        ora #%00000010
        sta SPRITE_ENABLE
        rts

mouse_hide_block_sprite:
        lda SPRITE_ENABLE
        and #%11111101
        sta SPRITE_ENABLE
        rts

mouse_use_pointer_shape:
        lda #MOUSE_SPRITE_POINTER
        sta mouse_sprite_mode
        lda #<(mouse_pointer_sprite / 64)
        sta mouse_sprite_ptrs
        lda #>(mouse_pointer_sprite / 64)
        sta mouse_sprite_ptrs+1
        rts

mouse_use_block_shape:
        lda #MOUSE_SPRITE_BLOCK
        sta mouse_sprite_mode
        lda #<(mouse_block_sprite / 64)
        sta mouse_sprite_ptrs+2
        lda #>(mouse_block_sprite / 64)
        sta mouse_sprite_ptrs+3
        rts

mouse_apply_delta_x:
        sta mouse_delta
        stx mouse_delta+1

        clc
        lda mouse_x
        adc mouse_delta
        sta mouse_next
        lda mouse_x+1
        adc mouse_delta+1
        sta mouse_next+1

        lda mouse_x+1
        bmi _madx_bounds
        lda mouse_x+1
        bne _madx_check_right_wrap
        lda mouse_x
        cmp #MOUSE_WRAP_LOW_X
        bcs _madx_check_right_wrap
        lda mouse_next+1
        bmi _madx_bounds
        cmp #>MOUSE_WRAP_HIGH_X
        bcc _madx_bounds
        bne _madx_done
        lda mouse_next
        cmp #<MOUSE_WRAP_HIGH_X
        bcs _madx_done

_madx_check_right_wrap:
        lda mouse_x+1
        cmp #>MOUSE_WRAP_HIGH_X
        bcc _madx_bounds
        bne _madx_check_right_next
        lda mouse_x
        cmp #<MOUSE_WRAP_HIGH_X
        bcc _madx_bounds

_madx_check_right_next:
        lda mouse_next+1
        bne _madx_bounds
        lda mouse_next
        cmp #MOUSE_WRAP_LOW_X
        bcc _madx_done

_madx_bounds:
        lda mouse_next+1
        bmi _madx_negative_bounds
        cmp #>MOUSE_MAX_X_OFFSCREEN
        bcc _madx_store
        bne _madx_max
        lda mouse_next
        cmp #<(MOUSE_MAX_X_OFFSCREEN + 1)
        bcc _madx_store

_madx_max:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_RIGHT
        sta mouse_scroll_bits
        lda #<MOUSE_MAX_X_OFFSCREEN
        sta mouse_x
        lda #>MOUSE_MAX_X_OFFSCREEN
        sta mouse_x+1
        rts

_madx_negative_bounds:
        cmp #$FF
        bne _madx_min
        lda mouse_next
        cmp #MOUSE_MIN_X_OFFSCREEN_LO
        bcs _madx_store

_madx_min:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_LEFT
        sta mouse_scroll_bits
        lda #MOUSE_MIN_X_OFFSCREEN_LO
        sta mouse_x
        lda #$FF
        sta mouse_x+1
        rts

_madx_store:
        lda mouse_next
        sta mouse_x
        lda mouse_next+1
        sta mouse_x+1
_madx_done:
        rts

mouse_apply_delta_y:
        ; Hard-clamp the incoming signed delta (X:A) to +/-MOUSE_MAX_Y_STEP.
        ; Noisy NCM-era POT samples can otherwise produce wrap-sized jumps;
        ; capping the per-frame step means a single frame can never look like
        ; a counter wraparound, so we don't need (and must not have) the old
        ; wrap-rejection that trapped mouse_y against the bottom edge.
        cpx #0
        bne _mady_clamp_neg
        cmp #(MOUSE_MAX_Y_STEP + 1)
        bcc _mady_have_delta
        lda #MOUSE_MAX_Y_STEP
        bra _mady_have_delta
_mady_clamp_neg:
        cmp #(256 - MOUSE_MAX_Y_STEP)
        bcs _mady_have_delta
        lda #(256 - MOUSE_MAX_Y_STEP)
_mady_have_delta:
        sta mouse_delta
        stx mouse_delta+1

        sec
        lda mouse_y
        sbc mouse_delta
        sta mouse_next
        lda mouse_y+1
        sbc mouse_delta+1
        sta mouse_next+1

        ; Let the pointer move a little above the visible screen, but clamp at
        ; the bottom until we wire sprite Y MSBs for lower offscreen motion.
        lda mouse_next+1
        bmi _mady_negative_bounds
        bne _mady_max
        lda mouse_next
        cmp #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y + 1)
        bcc _mady_store

_mady_max:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_DOWN
        sta mouse_scroll_bits
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
        sta mouse_y
        stz mouse_y+1
        rts

_mady_negative_bounds:
        cmp #$FF
        bne _mady_min
        lda mouse_next
        cmp #MOUSE_MIN_Y_OFFSCREEN_LO
        bcs _mady_store

_mady_min:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_UP
        sta mouse_scroll_bits
        lda #MOUSE_MIN_Y_OFFSCREEN_LO
        sta mouse_y
        lda #$FF
        sta mouse_y+1
        rts

_mady_store:
        lda mouse_next
        sta mouse_y
        lda mouse_next+1
        sta mouse_y+1
_mady_done:
        rts

; mouse_apply_y_clamped: A = signed 8-bit pot diff (new - old). Treats any
; non-zero diff as motion. Clamps |delta| to 8 to keep one frame from
; slamming mouse_y to a clamp. Inverts sign for screen-Y convention (mouse
; up = +pot = decrease mouse_y).
mouse_apply_y_clamped:
        cmp #0
        beq _mayc_done                ; no change
        bpl _mayc_positive            ; A in $01..$7F

        ; A in $80..$FF → negative diff. Clamp magnitude to 8.
        cmp #$F8                      ; -8 = $F8
        bcs _mayc_apply_neg_keep
        lda #$F8                      ; clamp to -8
_mayc_apply_neg_keep:
        ; mouse_y -= signed_delta. For negative A, mouse_y -= (-|delta|) = mouse_y + |delta|.
        ; 8-bit signed value in A; sign-extend high byte.
        ldx #$FF
        jmp _mayc_apply

_mayc_positive:
        ; A in $01..$7F → positive diff. Clamp magnitude to 8.
        cmp #$08
        bcc _mayc_apply_pos_keep
        lda #$08
_mayc_apply_pos_keep:
        ldx #0
_mayc_apply:
        sta mouse_delta
        stx mouse_delta+1
        sec
        lda mouse_y
        sbc mouse_delta
        sta mouse_next
        lda mouse_y+1
        sbc mouse_delta+1
        sta mouse_next+1

        lda mouse_next+1
        bmi _mayc_clamp_zero
        bne _mayc_clamp_max
        lda mouse_next
        cmp #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y + 1)
        bcc _mayc_store
_mayc_clamp_max:
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
        sta mouse_y
        stz mouse_y+1
        rts
_mayc_clamp_zero:
        stz mouse_y
        stz mouse_y+1
        rts
_mayc_store:
        lda mouse_next
        sta mouse_y
        lda mouse_next+1
        sta mouse_y+1
_mayc_done:
        rts

; Legacy diagnostic absolute-Y routine. Do not use for gameplay mouse motion:
; it maps raw POTY directly to screen Y and is fragile once NCM fetches begin.
mouse_apply_absolute_y:
        sta mouse_raw_y

        lda mouse_old_pot_y
        cmp #MOUSE_RAW_WRAP_HIGH_Y
        bcc _maay_check_raw_bottom
        lda mouse_raw_y
        cmp #MOUSE_RAW_WRAP_LOW_Y
        bcc _maay_reject_top_wrap

_maay_check_raw_bottom:
        lda mouse_old_pot_y
        cmp #MOUSE_RAW_WRAP_LOW_Y
        bcs _maay_scale_raw
        lda mouse_raw_y
        cmp #MOUSE_RAW_WRAP_HIGH_Y
        bcs _maay_reject_bottom_wrap

_maay_scale_raw:
        lda mouse_raw_y
        lsr
        sta mouse_abs_y

        lda mouse_raw_y
        clc
        adc mouse_abs_y
        sta mouse_abs_y

        lda mouse_raw_y
        lsr
        lsr
        lsr
        lsr
        clc
        adc mouse_abs_y
        cmp #MOUSE_MAX_Y+1
        bcc +
        lda #MOUSE_MAX_Y
+       sta mouse_abs_y

        sec
        lda #MOUSE_MAX_Y
        sbc mouse_abs_y
        sta mouse_abs_y

        lda mouse_y+1
        bne _maay_store

        ; Guard in VIC sprite coordinates so the visible pointer never wraps
        ; from one vertical edge to the other.
        clc
        lda mouse_abs_y
        adc #SPRITE_SCREEN_Y
        sta mouse_candidate_sprite_y

        cmp #MOUSE_SPRITE_MIN_Y
        bcc _maay_reject
        cmp #(MOUSE_SPRITE_MAX_Y + 1)
        bcs _maay_reject

        clc
        lda mouse_y
        adc #SPRITE_SCREEN_Y
        sta mouse_current_sprite_y

        lda mouse_current_sprite_y
        cmp #(MOUSE_SPRITE_MIN_Y + MOUSE_SPRITE_WRAP_Y)
        bcs _maay_check_bottom_sprite_wrap
        lda mouse_candidate_sprite_y
        cmp #(MOUSE_SPRITE_MAX_Y - MOUSE_SPRITE_WRAP_Y)
        bcs _maay_reject

_maay_check_bottom_sprite_wrap:
        lda mouse_current_sprite_y
        cmp #(MOUSE_SPRITE_MAX_Y - MOUSE_SPRITE_WRAP_Y)
        bcc _maay_delta_check
        lda mouse_candidate_sprite_y
        cmp #(MOUSE_SPRITE_MIN_Y + MOUSE_SPRITE_WRAP_Y)
        bcc _maay_reject

_maay_delta_check:
        sec
        lda mouse_abs_y
        sbc mouse_y
        beq _maay_done
        cmp #1
        beq _maay_done
        cmp #$FF
        beq _maay_done
        cmp #$60
        bcc _maay_store
        cmp #$A0
        bcs _maay_store
        jmp _maay_update_raw_done

_maay_store:
        lda mouse_abs_y
        sta mouse_y
        stz mouse_y+1
_maay_update_raw_done:
        lda mouse_raw_y
        sta mouse_old_pot_y
_maay_done:
        rts

_maay_reject:
        lda mouse_raw_y
        sta mouse_old_pot_y
        rts

_maay_reject_top_wrap:
        stz mouse_y
        stz mouse_y+1
        lda mouse_raw_y
        sta mouse_old_pot_y
        rts

_maay_reject_bottom_wrap:
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
        sta mouse_y
        stz mouse_y+1
        lda mouse_raw_y
        sta mouse_old_pot_y
        rts

mouse_double_delta:
        asl
        pha
        txa
        rol
        tax
        pla
        rts

mouse_move_check:
        sty mouse_old_value
        sta mouse_new_value
        ldx #0

        sec
        sbc mouse_old_value
        cmp #$3F
        bcs _mmc_not_positive

        ldy mouse_new_value
        ldx #0
        sec
        rts

_mmc_not_positive:
        cmp #$C0
        bcc _mmc_no_move
        ldy mouse_new_value
        ldx #$FF
        sec
        rts

_mmc_no_move:
        ldy mouse_new_value
        txa
        clc
        rts

mouse_move_check_raw7:
        sty mouse_old_value
        sta mouse_new_value
        ldx #0

        sec
        sbc mouse_old_value
        and #$7F
        beq _mmc7_no_move
        cmp #$40
        bcs _mmc7_negative

        ldy mouse_new_value
        ldx #0
        sec
        rts

_mmc7_negative:
        ora #$80
        ldy mouse_new_value
        ldx #$FF
        sec
        rts

_mmc7_no_move:
        ldy mouse_new_value
        txa
        clc
        rts

mouse_x:
        .word 0
mouse_y:
        .word 0
mouse_next:
        .word 0
mouse_delta:
        .word 0
mouse_rel:
        .word 0
mouse_raw_y:
        .byte 0
mouse_abs_y:
        .byte 0
mouse_potx_sample:
        .byte 0
mouse_poty_sample:
        .byte 0
mouse_sprite_x:
        .word 0
mouse_sprite_y:
        .byte 0
mouse_anim_y:
        .byte 0
mouse_anim_dir:
        .byte 0
mouse_drawn_sprite_y:
        .byte 0
mouse_current_sprite_y:
        .byte 0
mouse_candidate_sprite_y:
        .byte 0
mouse_old_pot_x:
        .byte 0
mouse_old_pot_y:
        .byte 0
mouse_old_pot_b_y:
        .byte 0
mouse_old_value:
        .byte 0
mouse_new_value:
        .byte 0
mouse_buttons:
        .byte 0
mouse_prev_buttons:
        .byte 0
mouse_left_click:
        .byte 0
mouse_over_main:
        .byte 0
mouse_tile_x:
        .byte 0
mouse_tile_y:
        .byte 0
mouse_ui_col:
        .byte 0
mouse_ui_row:
        .byte 0
mouse_edge_active:
        .byte 0
mouse_scroll_tick:
        .byte 0
mouse_scroll_bits:
        .byte 0
mouse_sprite_mode:
        .byte 0
mouse_saved_ddra:
        .byte 0
mouse_saved_ddrb:
        .byte 0
mouse_saved_pra:
        .byte 0

        .align 16
mouse_sprite_ptrs:
        .fill 16, 0

        .align 64
mouse_pointer_sprite:
        .byte %10000000,%00000000,%00000000
        .byte %11000000,%00000000,%00000000
        .byte %11100000,%00000000,%00000000
        .byte %11110000,%00000000,%00000000
        .byte %11111000,%00000000,%00000000
        .byte %11111100,%00000000,%00000000
        .byte %11111110,%00000000,%00000000
        .byte %11111111,%00000000,%00000000
        .byte %11111111,%10000000,%00000000
        .byte %11111000,%00000000,%00000000
        .byte %11011000,%00000000,%00000000
        .byte %10001100,%00000000,%00000000
        .byte %00001100,%00000000,%00000000
        .byte %00000110,%00000000,%00000000
        .byte %00000110,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte $00

        .align 64
mouse_block_sprite:
        .byte $FF,$FF,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $80,$01,$00
        .byte $FF,$FF,$00
        .byte $00,$00,$00
        .byte $00,$00,$00
        .byte $00,$00,$00
        .byte $00,$00,$00
        .byte $00,$00,$00
        .byte $00
