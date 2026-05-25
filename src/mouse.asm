;=======================================================================================
; Mouse pointer and map cursor.
;
; Reads a 1351-compatible mouse from control port 1, tracks a logical pointer
; position, and displays sprite 0 as a pointer plus sprite 1 as a snapped 16x16
; map cursor.
;
; Coordinate systems used below:
;   logical pixel  mouse_x/mouse_y, 0..MOUSE_MAX_X / 0..MOUSE_MAX_Y (sized from
;                  VIEW_COLS/VIEW_ROWS). mouse_x can reach MOUSE_MIN_X for the
;                  offscreen-left clamp. This is the source of truth for input.
;   sprite         VIC sprite coords = logical + SPRITE_SCREEN_X/Y (mouse_sprite_x/y).
;   viewport tile  mouse_tile_x/y, the 16x16 tile under the pointer within the
;                  visible map (0..MAIN_TILE_COLS-1 / 0..MAIN_TILE_ROWS-1).
;   city tile      cursor_x/y = view_x/view_y + tile, the absolute map cell.
;=======================================================================================

MOUSE_SPRITE_POINTER    = 0
MOUSE_SPRITE_BLOCK      = 1

mouse_init:
        lda #0
        sta mouse_buttons
        sta mouse_prev_buttons
        sta mouse_left_click
        sta mouse_left_debounce
        sta mouse_over_main
        sta mouse_scroll_tick
        sta mouse_scroll_bits

        jsr mouse_seed_pot_baseline
        jsr mouse_center_pointer
        rts

mouse_center_pointer:
        lda #<MOUSE_START_X
        sta mouse_x
        lda #>MOUSE_START_X
        sta mouse_x+1
        lda #MOUSE_START_Y
        sta mouse_y
        lda #0
        sta mouse_y+1
        sta mouse_scroll_tick
        sta mouse_scroll_bits
        sta mouse_edge_active
        lda #1
        sta mouse_over_main
        lda #MOUSE_START_TILE_X
        sta mouse_tile_x
        lda #MOUSE_START_TILE_Y
        sta mouse_tile_y
        jsr mouse_update_city_cursor
        rts

mouse_poll:
        ; NOTE: on the 45GS02, STZ stores the Z register, not a literal zero.
        ; These must be explicit zero stores or the click edge never clears.
        lda #0
        sta mouse_left_click
        sta mouse_scroll_bits
        jsr mouse_read_motion
        lda mouse_over_main
        beq _mp_read_buttons
        lda mouse_y+1
        beq _mp_read_buttons
        jsr mouse_sync_pointer_to_cursor

_mp_read_buttons:
        jsr mouse_read_buttons
        jsr mouse_update_click
        rts

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
        ; all the X delta math, which during FCM stalls the CPU long enough that
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
        jsr mouse_apply_delta_x
+
        lda mouse_poty_sample
        ldy mouse_old_pot_y
        jsr mouse_move_check
        sty mouse_old_pot_y
        bcc _mrm_done_y
        ; FCM display fetches make POTY wobble by one 1351 tick. With the #$7F
        ; mask that tick is +/-1, so reject a single-tick delta as noise to keep
        ; a stationary pointer from drifting (and edge-scrolling) at the top.
        cpx #0
        bne _mrm_check_y_neg_noise
        cmp #2
        bcc _mrm_done_y
        bra _mrm_apply_y
_mrm_check_y_neg_noise:
        cmp #$FF
        bcs _mrm_done_y
_mrm_apply_y:
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

; Read a POT axis, retrying until two back-to-back reads agree. Capped so a
; noisy/unplugged/wrong-mode pot can't wedge the machine inside this sei
; section; on giving up, reuse the previous sample (axis registers no movement).
mouse_read_pot_x:
        ldy #MOUSE_POT_READ_TRIES
_mrpx_loop:
        lda M65_POT_PORT_A_X
        cmp M65_POT_PORT_A_X
        beq _mrpx_done
        dey
        bne _mrpx_loop
        lda mouse_old_pot_x
_mrpx_done:
        and #$7F
        rts

mouse_read_pot_y:
        ldy #MOUSE_POT_READ_TRIES
_mrpy_loop:
        lda M65_POT_PORT_A_Y
        cmp M65_POT_PORT_A_Y
        beq _mrpy_done
        dey
        bne _mrpy_loop
        lda mouse_old_pot_y
_mrpy_done:
        and #$7F
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
        ; R5 CIA takes several cycles to settle after DDR output->input before
        ; PORT_B reads reliably (esp. bit 0 = 1351 right button). Busy-wait.
        ldx #MOUSE_BUTTON_SETTLE
_mrb_settle:
        dex
        bne _mrb_settle
        lda CIA1_PORT_B
        eor #$FF
        and #MOUSE_BUTTON_LEFT      ; left button only; right (bit 0) unused
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
        beq _muc_release

        lda mouse_left_debounce
        cmp #2
        bcs _muc_store
        inc mouse_left_debounce
        lda mouse_left_debounce
        cmp #2
        bne _muc_store
        lda #1
        sta mouse_left_click
_muc_store:
        lda mouse_buttons
        sta mouse_prev_buttons
        rts

_muc_release:
        lda #0                  ; STZ stores Z on 45GS02; force a real zero
        sta mouse_left_debounce
        bra _muc_store


mouse_sync_pointer_to_cursor:
        lda mouse_tile_x
        sta mouse_x
        lda #0
        sta mouse_x+1
        ldx #4
_msptc_x_shift:
        asl mouse_x
        rol mouse_x+1
        dex
        bne _msptc_x_shift

        clc
        lda mouse_x
        adc #<(MAIN_PIXEL_X + 2)
        sta mouse_x
        lda mouse_x+1
        adc #>(MAIN_PIXEL_X + 2)
        sta mouse_x+1

        lda mouse_tile_y
        asl
        asl
        asl
        asl
        clc
        adc #(MAIN_PIXEL_Y + 2)
        sta mouse_y
        lda #0
        sta mouse_y+1
        rts

mouse_apply_delta_x:
        ; Clamp the incoming signed delta (X:A) to +/-MOUSE_MAX_DELTA, then add
        ; it to mouse_x. Capping the per-frame step means a noisy POT sample
        ; can't produce a wrap-sized jump, so the old wrap-rejection (which
        ; trapped mouse_x against the right edge and blocked leftward motion)
        ; is removed -- mirroring the mouse_apply_delta_y fix.
        cpx #0
        bne _madx_clamp_neg
        ; positive delta = rightward motion this frame
        pha
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_RIGHT
        sta mouse_scroll_bits
        pla
        cmp #(MOUSE_MAX_DELTA + 1)
        bcc _madx_have_delta
        lda #MOUSE_MAX_DELTA
        bra _madx_have_delta
_madx_clamp_neg:
        ; negative delta = leftward motion this frame
        pha
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_LEFT
        sta mouse_scroll_bits
        pla
        cmp #(256 - MOUSE_MAX_DELTA)
        bcs _madx_have_delta
        lda #(256 - MOUSE_MAX_DELTA)
_madx_have_delta:
        sta mouse_delta
        stx mouse_delta+1

        clc
        lda mouse_x
        adc mouse_delta
        sta mouse_next
        lda mouse_x+1
        adc mouse_delta+1
        sta mouse_next+1

_madx_bounds:
        lda mouse_next+1
        bmi _madx_check_min
        cmp #>MOUSE_MAX_X
        bcc _madx_store
        bne _madx_max
        lda mouse_next
        cmp #<(MOUSE_MAX_X + 1)
        bcc _madx_store

_madx_max:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_RIGHT
        sta mouse_scroll_bits
        lda #<MOUSE_MAX_X
        sta mouse_x
        lda #>MOUSE_MAX_X
        sta mouse_x+1
        rts

_madx_check_min:
        cmp #>MOUSE_MIN_X
        bne _madx_min
        lda mouse_next
        cmp #<MOUSE_MIN_X
        bcs _madx_store

_madx_min:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_LEFT
        sta mouse_scroll_bits
        lda #<MOUSE_MIN_X
        sta mouse_x
        lda #>MOUSE_MIN_X
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
        ; Noisy FCM-era POT samples can otherwise produce wrap-sized jumps;
        ; capping the per-frame step means a single frame can never look like
        ; a counter wraparound, so we don't need (and must not have) the old
        ; wrap-rejection that trapped mouse_y against the bottom edge.
        cpx #0
        bne _mady_clamp_neg
        ; positive delta = upward motion this frame (mouse_y decreases)
        pha
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_UP
        sta mouse_scroll_bits
        pla
        cmp #(MOUSE_MAX_Y_STEP + 1)
        bcc _mady_have_delta
        lda #MOUSE_MAX_Y_STEP
        bra _mady_have_delta
_mady_clamp_neg:
        ; negative delta = downward motion this frame (mouse_y increases)
        pha
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_DOWN
        sta mouse_scroll_bits
        pla
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

        lda mouse_next+1
        bmi _mady_min
        bne _mady_max
        lda mouse_next
        cmp #(MOUSE_MAX_Y + 1)
        bcc _mady_store

_mady_max:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_DOWN
        sta mouse_scroll_bits
        lda #MOUSE_MAX_Y
        sta mouse_y
        lda #0
        sta mouse_y+1
        rts

_mady_min:
        lda mouse_scroll_bits
        ora #MOUSE_SCROLL_UP
        sta mouse_scroll_bits
        lda #0
        sta mouse_y
        sta mouse_y+1
        rts

_mady_store:
        lda mouse_next
        sta mouse_y
        lda mouse_next+1
        sta mouse_y+1
_mady_done:
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
mouse_potx_sample:
        .byte 0
mouse_poty_sample:
        .byte 0
mouse_old_pot_x:
        .byte 0
mouse_old_pot_y:
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
mouse_left_debounce:
        .byte 0
mouse_over_main:
        .byte 0
mouse_tile_x:
        .byte 0
mouse_tile_y:
        .byte 0
mouse_cell_x:
        .byte 0
mouse_cell_y:
        .byte 0
mouse_edge_active:
        .byte 0
mouse_scroll_tick:
        .byte 0
mouse_scroll_bits:
        .byte 0
mouse_saved_ddra:
        .byte 0
mouse_saved_ddrb:
        .byte 0
mouse_saved_pra:
        .byte 0
