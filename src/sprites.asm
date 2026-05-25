;=======================================================================================
; Sprite layer: owns all VIC sprite registers, shapes, and the pointer table.
;
; Sprite 0 = mouse pointer (follows mouse_x/y).
; Sprite 1 = yellow map cursor block (follows mouse_tile_x/y when over the map).
; Sprite 2 = toolbox selector block (follows selected_tool).
;
; Handlers (mouse.asm, viewport, toolbar) only set logical state; sprites_refresh
; reflects that state onto the hardware once per frame. No other module pokes
; sprite registers.
;=======================================================================================

; One-time hardware setup for all sprites, then place them from current state.
sprites_init:
        lda SPRITE_X_MSB
        and #%11111000
        sta SPRITE_X_MSB
        lda VIC4_SPRXMSB9
        and #%11111000
        sta VIC4_SPRXMSB9
        lda VIC4_SPRYMSB8
        and #%11111000
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11111000
        sta VIC4_SPRYMSB9
        lda #0
        sta SPRITE0_X
        sta SPRITE0_Y
        sta SPRITE1_X
        sta SPRITE1_Y
        sta SPRITE2_X
        sta SPRITE2_Y

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
        lda #$00                ; black selector box
        sta SPRITE2_COLOR

        lda SPRITE_MULTICOLOR
        and #%11111000
        sta SPRITE_MULTICOLOR
        lda SPRITE_X_EXPAND
        and #%11111000
        sta SPRITE_X_EXPAND
        lda SPRITE_Y_EXPAND
        and #%11111000
        sta SPRITE_Y_EXPAND
        lda SPRITE_PRIORITY
        and #%11111000
        sta SPRITE_PRIORITY

        lda SPRITE_ENABLE
        and #%11110000
        ora #%00000101          ; sprite 0 (pointer) + sprite 2 (tool selector)
        sta SPRITE_ENABLE

        ; Shape pointers: 0 = arrow, 1 = block, 2 = block (selector).
        jsr mouse_use_pointer_shape
        jsr mouse_use_block_shape
        lda #<(sprite_selector_shape / 64)
        sta mouse_sprite_ptrs+4
        lda #>(sprite_selector_shape / 64)
        sta mouse_sprite_ptrs+5

        ; Initial placement from current state.
        jsr mouse_position_pointer_on_cursor_sprite
        jsr mouse_position_block_sprite
        jsr sprite_position_selector
        rts

; Per-frame: reflect current state onto the hardware. Pointer always; cursor
; block only over the map. The selector (sprite 2) is NOT refreshed here -- it
; moves only when a toolbar icon is clicked (toolbar_handle_click calls
; sprite_position_selector), so it stays put and never tracks the pointer.
sprites_refresh:
        jsr mouse_use_pointer_shape
        jsr mouse_position_pointer_sprite

        lda mouse_over_main
        beq _sr_hide_block
        jsr mouse_use_block_shape
        jmp mouse_position_block_sprite

_sr_hide_block:
        jmp mouse_hide_block_sprite

sprites_shutdown:
        lda SPRITE_ENABLE
        and #%11111000
        sta SPRITE_ENABLE
        rts

mouse_position_pointer_sprite:
        lda mouse_x
        sta mouse_sprite_x
        lda mouse_x+1
        sta mouse_sprite_x+1

        lda mouse_sprite_x+1
        bmi _mpps_check_min_x
        cmp #>MOUSE_MAX_X
        bcc _mpps_add_screen_x
        bne _mpps_cap_x
        lda mouse_sprite_x
        cmp #<(MOUSE_MAX_X + 1)
        bcc _mpps_add_screen_x

_mpps_cap_x:
        lda #<MOUSE_MAX_X
        sta mouse_sprite_x
        lda #>MOUSE_MAX_X
        sta mouse_sprite_x+1
        bra _mpps_add_screen_x

_mpps_check_min_x:
        cmp #>MOUSE_MIN_X
        bne _mpps_min_x
        lda mouse_sprite_x
        cmp #<MOUSE_MIN_X
        bcs _mpps_add_screen_x

_mpps_min_x:
        lda #<MOUSE_MIN_X
        sta mouse_sprite_x
        lda #>MOUSE_MIN_X
        sta mouse_sprite_x+1

_mpps_add_screen_x:
        clc
        lda mouse_sprite_x
        adc #<SPRITE_SCREEN_X
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>SPRITE_SCREEN_X
        sta mouse_sprite_x+1

_mpps_y:
        lda mouse_y+1
        bmi _mpps_min_y
        beq _mpps_check_y_max
        lda #MOUSE_MAX_Y
        bra _mpps_store_y

_mpps_check_y_max:
        lda mouse_y
        cmp #(MOUSE_MAX_Y + 1)
        bcc _mpps_store_y
        lda #MOUSE_MAX_Y
        bra _mpps_store_y

_mpps_min_y:
        lda #0
_mpps_store_y:
        clc
        adc #SPRITE_SCREEN_Y
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_position_pointer_on_cursor_sprite:
        lda mouse_over_main
        beq mouse_position_pointer_sprite

        lda mouse_tile_x
        sta mouse_sprite_x
        lda #0
        sta mouse_sprite_x+1
        ldx #4
_mppoc_x_shift:
        asl mouse_sprite_x
        rol mouse_sprite_x+1
        dex
        bne _mppoc_x_shift

        clc
        lda mouse_sprite_x
        adc #<(SPRITE_SCREEN_X + MAIN_PIXEL_X + 2)
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>(SPRITE_SCREEN_X + MAIN_PIXEL_X + 2)
        sta mouse_sprite_x+1

        lda mouse_tile_y
        asl
        asl
        asl
        asl
        clc
        adc #(SPRITE_SCREEN_Y + MAIN_PIXEL_Y + 2)
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_position_block_sprite:
        lda mouse_tile_x
        sta mouse_sprite_x
        lda #0
        sta mouse_sprite_x+1
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

; Place sprite 2 (selector box) over selected_tool's toolbar slot. Column: even
; slots -> left, odd -> right. Row pair advances by 16 pixels per toolbar row.
; Uses toolbox sprite coordinates, not the general mouse/map pointer offset.
sprite_position_selector:
        lda selected_tool
        cmp #UI_BTN_COUNT
        bcc +
        lda #0
        sta selected_tool
+
        lda selected_tool
        and #1
        beq _sps_left
        lda #(UI_TOOL_SELECTOR_X + ((UI_TOOL_COL_RIGHT - UI_TOOL_COL_LEFT) * FCM_CELL_PIXELS))
        bra _sps_x_done
_sps_left:
        lda #UI_TOOL_SELECTOR_X
_sps_x_done:
        sta SPRITE2_X

        lda selected_tool
        and #$FE
        asl
        asl
        asl
        clc
        adc #UI_TOOL_SELECTOR_Y
        sta SPRITE2_Y

        lda SPRITE_X_MSB
        and #%11111011
        sta SPRITE_X_MSB
        lda VIC4_SPRXMSB9
        and #%11111011
        sta VIC4_SPRXMSB9
        lda VIC4_SPRYMSB8
        and #%11111011
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11111011
        sta VIC4_SPRYMSB9
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

mouse_sprite_x:
        .word 0
mouse_sprite_y:
        .byte 0
mouse_sprite_mode:
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
        .byte %11111111,%11111111,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %10000000,%00000001,%00000000
        .byte %11111111,%11111111,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Selector box (sprite 2): same as mouse_block_sprite but 1px wider --
        ; right edge at pixel 16 instead of 15. Sprite 1 keeps the 16px box.
        .align 64
sprite_selector_shape:
        .byte %11111111,%11111111,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %10000000,%00000000,%10000000
        .byte %11111111,%11111111,%10000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000
