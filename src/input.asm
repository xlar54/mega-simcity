;=======================================================================================
; Mouse-first gameplay input. Keyboard is kept for quit and tool shortcuts.
;=======================================================================================

input_poll:
        stz input_action
        jsr mouse_poll

        jsr input_space_held
        bcc _ip_check_mouse
        lda #0
        sta MEGA_KEYQUEUE
        lda #INPUT_MOVE_DOWN
        sta input_action
        rts

_ip_check_mouse:
        lda mouse_buttons
        beq _ip_keyboard
        lda #0
        sta MEGA_KEYQUEUE
        rts

_ip_keyboard:
        lda MEGA_KEYQUEUE
        beq _ip_done
        sta input_key
        lda #0
        sta MEGA_KEYQUEUE
        lda input_key

        cmp #'Q'
        beq _ip_quit
        cmp #'q'
        beq _ip_quit

        ; Cursor-key viewport scrolling is disabled while the mouse owns
        ; scrolling by moving offscreen.
        ;cmp #KEY_CRSR_UP
        ;beq _ip_move_up
        ;cmp #KEY_CRSR_UP_ALT
        ;beq _ip_move_up
        ;cmp #KEY_CRSR_DOWN
        ;beq _ip_move_down
        ;cmp #KEY_CRSR_LEFT
        ;beq _ip_move_left
        ;cmp #KEY_CRSR_LEFT_ALT
        ;beq _ip_move_left
        ;cmp #KEY_CRSR_RIGHT
        ;beq _ip_move_right

        cmp #' '
        beq _ip_paint

        cmp #'0'
        beq _ip_water
        cmp #'1'
        beq _ip_grass
        cmp #'2'
        beq _ip_road
        cmp #'3'
        beq _ip_residential
        cmp #'4'
        beq _ip_commercial
        cmp #'5'
        beq _ip_industrial
        cmp #'6'
        beq _ip_power
_ip_done:
        rts

_ip_quit:
        lda #INPUT_QUIT
        sta input_action
        rts

_ip_move_up:
        lda #INPUT_MOVE_UP
        sta input_action
        rts

_ip_move_down:
        lda #INPUT_MOVE_DOWN
        sta input_action
        rts

_ip_move_left:
        lda #INPUT_MOVE_LEFT
        sta input_action
        rts

_ip_move_right:
        lda #INPUT_MOVE_RIGHT
        sta input_action
        rts

_ip_paint:
        lda #INPUT_PAINT
        sta input_action
        rts

_ip_water:
        lda #TILE_WATER
        sta selected_tile
        jmp _ip_paint

_ip_grass:
        lda #TILE_GRASS
        sta selected_tile
        jmp _ip_paint

_ip_road:
        lda #TILE_ROAD
        sta selected_tile
        jmp _ip_paint

_ip_residential:
        lda #TILE_RESIDENTIAL
        sta selected_tile
        jmp _ip_paint

_ip_commercial:
        lda #TILE_COMMERCIAL
        sta selected_tile
        jmp _ip_paint

_ip_industrial:
        lda #TILE_INDUSTRIAL
        sta selected_tile
        jmp _ip_paint

_ip_power:
        lda #TILE_POWER
        sta selected_tile
        jmp _ip_paint

input_space_held:
        php
        sei
        lda CIA1_PORT_A
        sta input_saved_pra
        lda CIA1_DDRA
        sta input_saved_ddra
        lda CIA1_DDRB
        sta input_saved_ddrb

        lda #$FF
        sta CIA1_DDRA
        lda #$00
        sta CIA1_DDRB
        lda #$7F
        sta CIA1_PORT_A
        lda CIA1_PORT_B
        sta input_space_row

        lda input_saved_pra
        sta CIA1_PORT_A
        lda input_saved_ddra
        sta CIA1_DDRA
        lda input_saved_ddrb
        sta CIA1_DDRB
        plp

        lda input_space_row
        and #$10
        beq _ish_down
        clc
        rts

_ish_down:
        sec
        rts

input_action:
        .byte INPUT_NONE
input_key:
        .byte 0
input_saved_pra:
        .byte 0
input_saved_ddra:
        .byte 0
input_saved_ddrb:
        .byte 0
input_space_row:
        .byte 0
