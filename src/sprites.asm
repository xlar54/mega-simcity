;=======================================================================================
; Sprite layer: owns all VIC sprite registers, shapes, and the pointer table.
;
; Sprite 0 = mouse pointer (follows mouse_x/y).
; Sprite 1 = yellow map cursor block (follows mouse_tile_x/y when over the map).
; Sprite 2 = toolbox selector block, positioned only on a toolbar click.
;
; Handlers (mouse.asm, viewport, toolbar) only set logical state. sprites_refresh
; reflects sprites 0 and 1 onto the hardware once per frame; sprite 2 moves only
; via sprite_position_selector (on click / at init). No other module pokes
; sprite registers.
;=======================================================================================

; Sprite 4 (temporary): a yellow lightning bolt parked just below the last
; toolbar icon. Fixed position; X gets the real-hardware correction like the other
; toolbar sprites. Last toolbar row top = (UI_BTN_COUNT-2)*8 + UI_TOOL_SELECTOR_Y;
; the icon is 16px tall, so +18 drops the bolt a couple px below it.
LIGHTNING_SPRITE_X      = SPRITE_SCREEN_X + 12
LIGHTNING_SPRITE_Y      = UI_TOOL_SELECTOR_Y + ((UI_BTN_COUNT - 2) * 8) + 18

; Detect Xemu vs real hardware and set the per-sprite X correction. The Xemu
; author specifies PLATFORM_FLAGS ($D60F) bit 5: set on real MEGA65 hardware,
; clear under Xemu. Real hardware renders sprites ~16px left of Xemu, so shift
; every sprite X right by SPRITE_X_HW_FIX there. Must run after the VIC-IV I/O
; unlock (enable_40mhz) and before any sprite is positioned.
detect_platform:
        lda #0
        sta sprite_x_fix
        lda PLATFORM_FLAGS
        and #PLATFORM_REAL_HW_BIT
        beq +
        lda #SPRITE_X_HW_FIX
        sta sprite_x_fix
+       rts

; One-time hardware setup for all sprites, then place them from current state.
sprites_init:
        lda SPRITE_X_MSB
        and #%11000000              ; clear MSB bits for sprites 0-5
        sta SPRITE_X_MSB
        lda VIC4_SPRXMSB9
        and #%11000000
        sta VIC4_SPRXMSB9
        lda VIC4_SPRYMSB8
        and #%11000000
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11000000
        sta VIC4_SPRYMSB9
        lda #0
        sta SPRITE0_X
        sta SPRITE0_Y
        sta SPRITE1_X
        sta SPRITE1_Y
        sta SPRITE2_X
        sta SPRITE2_Y
        sta SPRITE3_X
        sta SPRITE3_Y

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
        lda #$0A                ; yellow road cursor (8x8)
        sta SPRITE3_COLOR
        lda #$0A                ; yellow lightning bolt body (sprite 4)
        sta SPRITE4_COLOR
        lda #$00                ; black lightning outline (sprite 5)
        sta SPRITE5_COLOR

        lda SPRITE_MULTICOLOR
        and #%11000000          ; sprites 0-5 mono
        sta SPRITE_MULTICOLOR
        lda SPRITE_X_EXPAND
        and #%11000000          ; sprites 0-5 not X-expanded
        sta SPRITE_X_EXPAND
        lda SPRITE_Y_EXPAND
        and #%11000000          ; sprites 0-5 not Y-expanded
        sta SPRITE_Y_EXPAND
        lda SPRITE_PRIORITY
        and #%11000000          ; sprites 0-5 in front of the foreground
        sta SPRITE_PRIORITY

        lda SPRITE_ENABLE
        and #%11000000
        ora #%00110101          ; sprite 0 (pointer) + 2 (selector) + 4,5 (lightning)
        sta SPRITE_ENABLE

        ; Shape pointers: 0 = arrow, 1 = block, 2 = block (selector).
        jsr mouse_use_pointer_shape
        jsr mouse_use_block_shape
        lda #<(sprite_selector_shape / 64)
        sta mouse_sprite_ptrs+4
        lda #>(sprite_selector_shape / 64)
        sta mouse_sprite_ptrs+5
        lda #<(sprite_road_cursor_shape / 64)
        sta mouse_sprite_ptrs+6
        lda #>(sprite_road_cursor_shape / 64)
        sta mouse_sprite_ptrs+7

        ; Sprite 4: yellow lightning bolt body, parked below the last toolbar icon.
        ; Sprite 5: its black outline (the bolt dilated 1px), one px higher so it
        ; peeks out around all sides; sprite 4 draws in front and covers the middle.
        lda #<(sprite_lightning_shape / 64)
        sta mouse_sprite_ptrs+8
        lda #>(sprite_lightning_shape / 64)
        sta mouse_sprite_ptrs+9
        lda #<(sprite_lightning_outline_shape / 64)
        sta mouse_sprite_ptrs+10
        lda #>(sprite_lightning_outline_shape / 64)
        sta mouse_sprite_ptrs+11
        clc
        lda #LIGHTNING_SPRITE_X
        adc sprite_x_fix
        sta SPRITE4_X
        sta SPRITE5_X               ; outline shares the X; its shape holds the offset
        lda #LIGHTNING_SPRITE_Y
        sta SPRITE4_Y
        lda #LIGHTNING_SPRITE_Y-1
        sta SPRITE5_Y

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
        beq _sr_hide_cursors
        lda selected_tile
        cmp #TILE_INSPECT
        beq _sr_hide_cursors        ; inspect mode: no map cursor, just the pointer
        cmp #TILE_DISK
        beq _sr_hide_cursors        ; disk options is a menu action, not a paint tool

        ; Cursor size follows the tool footprint: road -> 8x8 (sprite 3),
        ; zones -> 24x24 (sprite 3, Y-expanded), everything else -> 16x16 (sprite 1).
        cmp #TILE_ROAD
        beq _sr_road
        cmp #TILE_GROUND
        beq _sr_road                ; bulldozer also uses the 8x8 cursor
        cmp #TILE_POWER
        beq _sr_road                ; power lines are 1x1 -> 8x8 cursor
        cmp #TILE_RAIL
        beq _sr_road                ; rail is 1x1 -> 8x8 cursor
        cmp #TILE_COALPP
        beq _sr_coalpp              ; coal plant -> 24x32 cursor
        cmp #TILE_NUCLEARPP
        beq _sr_coalpp              ; nuclear plant: same 3x4 footprint, same cursor
        cmp #TILE_PARK
        beq _sr_park                ; park -> 32x32 cursor (X- and Y-expanded)
        cmp #TILE_RESIDENTIAL
        bcc _sr_block               ; water -> 16x16
        jsr mouse_hide_block_sprite
        jsr sprite3_use_zone_shape
        jsr mouse_position_road_cursor
        bra _sr_color_sprite3

_sr_coalpp:
        jsr mouse_hide_block_sprite
        jsr sprite3_use_coalpp_shape
        jsr mouse_position_road_cursor
        bra _sr_color_sprite3

_sr_park:
        jsr mouse_hide_block_sprite
        jsr sprite3_use_park_shape
        jsr mouse_position_road_cursor
        bra _sr_color_sprite3

_sr_block:
        jsr mouse_hide_road_cursor
        jsr mouse_use_block_shape
        jsr mouse_position_block_sprite
        rts                          ; 2x2 water tool: live-color not yet wired

_sr_road:
        jsr mouse_hide_block_sprite
        jsr sprite3_use_road_shape
        jsr mouse_position_road_cursor
        bra _sr_color_sprite3

; Recolor sprite 3 based on whether the current selection would place
; successfully at the cursor cell. cursor_placement_valid only flips RED for
; structures + zones today (per its comment); other tools always return SET
; and stay yellow. Color indices target this game's custom palette
; (tiles_init_palette in assets.asm): $0D = red, $0A = yellow.
_sr_color_sprite3:
        jsr cursor_placement_valid
        lda #$0D                     ; red = cannot place
        bcc _sr_set_sprite3
        lda #$0A                     ; yellow = OK
_sr_set_sprite3:
        sta SPRITE3_COLOR
        rts

_sr_hide_cursors:
        jsr mouse_hide_block_sprite
        jmp mouse_hide_road_cursor

; Shape sprite 3 as the 8x8 road cursor (no Y-expand, no X-expand).
sprite3_use_road_shape:
        lda #<(sprite_road_cursor_shape / 64)
        sta mouse_sprite_ptrs+6
        lda #>(sprite_road_cursor_shape / 64)
        sta mouse_sprite_ptrs+7
        lda SPRITE_Y_EXPAND
        and #%11110111
        sta SPRITE_Y_EXPAND
        lda SPRITE_X_EXPAND
        and #%11110111
        sta SPRITE_X_EXPAND
        rts

; Shape sprite 3 as the 24x32 coal-plant cursor (Y-expanded: 16 rows -> 32px tall;
; X NOT expanded so the box stays 24px wide).
sprite3_use_coalpp_shape:
        lda #<(sprite_coalpp_cursor_shape / 64)
        sta mouse_sprite_ptrs+6
        lda #>(sprite_coalpp_cursor_shape / 64)
        sta mouse_sprite_ptrs+7
        lda SPRITE_Y_EXPAND
        ora #%00001000
        sta SPRITE_Y_EXPAND
        lda SPRITE_X_EXPAND
        and #%11110111
        sta SPRITE_X_EXPAND
        rts

; Shape sprite 3 as the 24x24 zone cursor (Y-expanded: 12 rows -> 24px tall;
; X NOT expanded so the box stays 24px wide).
sprite3_use_zone_shape:
        lda #<(sprite_zone_cursor_shape / 64)
        sta mouse_sprite_ptrs+6
        lda #>(sprite_zone_cursor_shape / 64)
        sta mouse_sprite_ptrs+7
        lda SPRITE_Y_EXPAND
        ora #%00001000
        sta SPRITE_Y_EXPAND
        lda SPRITE_X_EXPAND
        and #%11110111
        sta SPRITE_X_EXPAND
        rts

; Shape sprite 3 as the 32x32 park cursor. The MEGA65 hardware sprite is 24
; pixels wide native; we use both expand bits (Y for 16 rows -> 32 px tall, X
; for each source pixel to display 2 px wide). With X-expand, source pixel N
; renders at display pixels 2N..2N+1, so to terminate the box outline at
; display col 31 (the right edge of the 4-cell-wide park footprint), the right
; edge of the bitmap sits at source col 15 (byte 1, bit 0). Bytes at source
; cols 16..23 (byte 2) are zero, hiding the rest of the sprite. Result: a
; clean 32x32 outline despite the underlying 48x42 expanded sprite area.
sprite3_use_park_shape:
        lda #<(sprite_park_cursor_shape / 64)
        sta mouse_sprite_ptrs+6
        lda #>(sprite_park_cursor_shape / 64)
        sta mouse_sprite_ptrs+7
        lda SPRITE_Y_EXPAND
        ora #%00001000
        sta SPRITE_Y_EXPAND
        lda SPRITE_X_EXPAND
        ora #%00001000
        sta SPRITE_X_EXPAND
        rts

sprites_shutdown:
        lda SPRITE_ENABLE
        and #%11000000
        sta SPRITE_ENABLE
        rts

;=======================================================================================
; TEMP test: each frame, move the lightning bolt (sprites 4 & 5) to the top-left
; cell of one visible zone, cycling through them round-robin. Scans the visible
; cell window; is_zone_origin_value (city.asm) is true ONLY for the 3 TL cell
; values (one per R/C/I), so each 3x3 zone is found exactly once. Speed is
; unimportant; this is throwaway.
;=======================================================================================
BOLT_ZONE_MAX = 64

bolt_test_update:
        lda #0
        sta bolt_zone_count
        sta bolt_row_i
        lda view_y
        asl
        sta bolt_scan_cy
_btu_row:
        lda #0
        sta bolt_col_i
        lda view_x
        asl
        sta bolt_scan_cx
_btu_col:
        lda bolt_scan_cx
        sta city_ptr_x
        lda bolt_scan_cy
        sta city_ptr_y
        jsr city_cell_ptr
        ldz #0
        lda [MAP_PTR],z
        jsr is_zone_origin_value
        bcs _btu_found
        ; Police + fire-station buildings consume power too -- show the bolt
        ; over an unpowered one. The TL cell of each 3x3 footprint has value
        ; *_CELL_FIRST (offset 0), so a simple equality check picks the origin
        ; without iterating the rest of the structure footprint.
        cmp #POLICE_CELL_FIRST
        beq _btu_found
        cmp #FIRESTATION_CELL_FIRST
        bne _btu_next
_btu_found:
        ; only round-robin over UNPOWERED zones (power.asm marked the powered ones).
        ; city_cell_ptr above left the cell offset, so reuse it for the power array.
        jsr power_ptr_into_map
        ldz #0
        lda [MAP_PTR],z
        bne _btu_next               ; powered -> no bolt
        ldx bolt_zone_count
        cpx #BOLT_ZONE_MAX
        bcs _btu_next
        lda bolt_col_i              ; store view-relative cell (col_i = vrx, row_i = vry)
        sta bolt_zx,x
        lda bolt_row_i
        sta bolt_zy,x
        inx
        stx bolt_zone_count
_btu_next:
        inc bolt_scan_cx
        inc bolt_col_i
        lda bolt_col_i
        cmp #(MAIN_TILE_COLS * 2)
        bne _btu_col
        inc bolt_scan_cy
        inc bolt_row_i
        lda bolt_row_i
        cmp #(MAIN_TILE_ROWS * 2)
        bne _btu_row

        lda bolt_zone_count
        bne _btu_have
        jmp bolt_hide               ; no visible zones -> hide the bolt
_btu_have:
        lda bolt_rr                 ; target = bolt_rr mod count
_btu_mod:
        cmp bolt_zone_count
        bcc _btu_moddone
        sec
        sbc bolt_zone_count
        bra _btu_mod
_btu_moddone:
        tax                         ; X = chosen zone index
        inc bolt_rr

        lda bolt_zx,x               ; sprite X = vrx*8 + screen origin
        sta bolt_sx
        lda #0
        sta bolt_sx+1
        asl bolt_sx
        rol bolt_sx+1
        asl bolt_sx
        rol bolt_sx+1
        asl bolt_sx
        rol bolt_sx+1
        clc
        lda bolt_sx
        adc #<(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta bolt_sx
        lda bolt_sx+1
        adc #>(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta bolt_sx+1

        lda bolt_zy,x               ; sprite Y = vry*8 + screen origin
        asl
        asl
        asl
        clc
        adc #(SPRITE_SCREEN_Y + MAIN_PIXEL_Y)
        sta bolt_sy

        lda SPRITE_ENABLE           ; make sure both bolt sprites are on
        ora #%00110000
        sta SPRITE_ENABLE
        ; fall through to bolt_set_position

; Position sprites 4 (body) & 5 (outline) at 16-bit sprite X = bolt_sx, Y = bolt_sy
; (sprite 5 one px higher). Applies sprite_x_fix and the per-sprite X MSB bit.
bolt_set_position:
        clc
        lda bolt_sx
        adc sprite_x_fix
        sta bolt_sx
        lda bolt_sx+1
        adc #0
        sta bolt_sx+1

        lda bolt_sx
        sta SPRITE4_X
        sta SPRITE5_X
        lda bolt_sy
        sta SPRITE4_Y
        sec
        sbc #1
        sta SPRITE5_Y

        lda SPRITE_X_MSB            ; X bit 8 for sprites 4 and 5
        and #%11001111
        sta SPRITE_X_MSB
        lda bolt_sx+1
        and #$01
        beq +
        lda SPRITE_X_MSB
        ora #%00110000
        sta SPRITE_X_MSB
+
        lda VIC4_SPRXMSB9          ; clear the 640-mode X bit and the Y MSBs (Y<256)
        and #%11001111
        sta VIC4_SPRXMSB9
        lda VIC4_SPRYMSB8
        and #%11001111
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11001111
        sta VIC4_SPRYMSB9
        rts

bolt_hide:
        lda SPRITE_ENABLE
        and #%11001111              ; disable sprites 4 and 5
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
        clc                         ; apply real-hardware sprite-X correction
        lda mouse_sprite_x
        adc sprite_x_fix
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #0
        sta mouse_sprite_x+1

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
        clc                         ; apply real-hardware sprite-X correction
        lda mouse_sprite_x
        adc sprite_x_fix
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #0
        sta mouse_sprite_x+1

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

; Position sprite 3 (8x8 road cursor) over the 8x8 cell under the pointer.
mouse_position_road_cursor:
        lda mouse_cell_x
        sta mouse_sprite_x
        lda #0
        sta mouse_sprite_x+1
        asl mouse_sprite_x          ; cell_x * 8 -> pixels
        rol mouse_sprite_x+1
        asl mouse_sprite_x
        rol mouse_sprite_x+1
        asl mouse_sprite_x
        rol mouse_sprite_x+1

        clc
        lda mouse_sprite_x
        adc #<(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>(SPRITE_SCREEN_X + MAIN_PIXEL_X)
        sta mouse_sprite_x+1

        lda mouse_cell_y
        asl
        asl
        asl                         ; cell_y * 8
        clc
        adc #(SPRITE_SCREEN_Y + MAIN_PIXEL_Y)
        sta mouse_sprite_y

mouse_set_road_cursor_position:
        clc                         ; apply real-hardware sprite-X correction
        lda mouse_sprite_x
        adc sprite_x_fix
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #0
        sta mouse_sprite_x+1

        lda SPRITE_X_MSB
        and #%11110111
        sta SPRITE_X_MSB
        lda mouse_sprite_x+1
        and #$01
        beq +
        lda SPRITE_X_MSB
        ora #%00001000
        sta SPRITE_X_MSB
+
        lda VIC4_SPRXMSB9
        and #%11110111
        sta VIC4_SPRXMSB9
        lda mouse_sprite_x+1
        and #$02
        beq +
        lda VIC4_SPRXMSB9
        ora #%00001000
        sta VIC4_SPRXMSB9
+
        lda VIC4_SPRYMSB8
        and #%11110111
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11110111
        sta VIC4_SPRYMSB9

        lda mouse_sprite_x
        sta SPRITE3_X
        lda mouse_sprite_y
        sta SPRITE3_Y

        lda SPRITE_ENABLE
        ora #%00001000
        sta SPRITE_ENABLE
        rts

mouse_hide_road_cursor:
        lda SPRITE_ENABLE
        and #%11110111
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
        clc                         ; apply real-hardware sprite-X correction
        adc sprite_x_fix
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
sprite_x_fix:
        .byte 0                     ; real-hardware sprite-X correction (0 or 16)

; TEMP bolt round-robin state
bolt_rr:
        .byte 0
bolt_zone_count:
        .byte 0
bolt_scan_cx:
        .byte 0
bolt_scan_cy:
        .byte 0
bolt_col_i:
        .byte 0
bolt_row_i:
        .byte 0
bolt_sx:
        .word 0
bolt_sy:
        .byte 0
bolt_zx:
        .fill BOLT_ZONE_MAX, 0
bolt_zy:
        .fill BOLT_ZONE_MAX, 0

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

        ; Road cursor (sprite 3): an 8x8 box outline (uses only the left byte).
        .align 64
sprite_road_cursor_shape:
        .byte %11111111,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %10000001,%00000000,%00000000
        .byte %11111111,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Zone cursor (sprite 3): a 24x24 box. Drawn as 12 rows (full sprite
        ; width) and Y-expanded x2 by sprite3_use_zone_shape to reach 24px tall.
        .align 64
sprite_zone_cursor_shape:
        .byte %11111111,%11111111,%11111111
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %11111111,%11111111,%11111111
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Lightning bolt body (sprite 4): yellow, ~6px wide x 9px tall, kept inside
        ; cols 1-5 so the black outline (sprite 5) has a 1px margin on every side.
        ; Top-left downstroke, a rightward kink, then tapering to a point.
        .align 64
sprite_lightning_shape:
        .byte %00011000,%00000000,%00000000
        .byte %00111000,%00000000,%00000000
        .byte %01110000,%00000000,%00000000
        .byte %01111100,%00000000,%00000000
        .byte %00001100,%00000000,%00000000
        .byte %00011000,%00000000,%00000000
        .byte %00110000,%00000000,%00000000
        .byte %00100000,%00000000,%00000000
        .byte %01000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Lightning outline (sprite 5): the bolt body dilated by 1px (8-connected),
        ; so when drawn one px above sprite 4 it forms a 1px black border. The body
        ; sits at rows 1-9 here to align with sprite 4 (which is one px lower).
        .align 64
sprite_lightning_outline_shape:
        .byte %00111100,%00000000,%00000000
        .byte %01111100,%00000000,%00000000
        .byte %11111100,%00000000,%00000000
        .byte %11111110,%00000000,%00000000
        .byte %11111110,%00000000,%00000000
        .byte %11111110,%00000000,%00000000
        .byte %01111110,%00000000,%00000000
        .byte %01111100,%00000000,%00000000
        .byte %11111000,%00000000,%00000000
        .byte %11110000,%00000000,%00000000
        .byte %11100000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Coal-plant cursor (sprite 3): a 24x32 box. 16 rows (full sprite width),
        ; Y-expanded x2 by sprite3_use_coalpp_shape to reach 32px tall.
        .align 64
sprite_coalpp_cursor_shape:
        .byte %11111111,%11111111,%11111111
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %10000000,%00000000,%00000001
        .byte %11111111,%11111111,%11111111
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000

        ; Park cursor (sprite 3): a 32x32 box drawn into the first 16 source
        ; columns (bytes 0 and 1) of a 24-wide sprite, X-expanded x2 by
        ; sprite3_use_park_shape so source cols 0..15 render at display cols
        ; 0..31. Byte 2 is zero -- those source cols would have stretched
        ; into display cols 32..47 (16 px past the right edge of the park).
        ; Y-expanded x2 turns 16 rows into 32 px tall. Top edge (row 0) and
        ; bottom edge (row 15) span source cols 0..15 (= display 0..31);
        ; sides keep source col 0 and source col 15 lit (= display cols 0/1
        ; and 30/31, i.e. 2-px wide vertical lines at the box edges).
        .align 64
sprite_park_cursor_shape:
        .byte %11111111,%11111111,%00000000   ; row 0:  full top edge
        .byte %10000000,%00000001,%00000000   ; row 1:  L + R sides
        .byte %10000000,%00000001,%00000000   ; row 2
        .byte %10000000,%00000001,%00000000   ; row 3
        .byte %10000000,%00000001,%00000000   ; row 4
        .byte %10000000,%00000001,%00000000   ; row 5
        .byte %10000000,%00000001,%00000000   ; row 6
        .byte %10000000,%00000001,%00000000   ; row 7
        .byte %10000000,%00000001,%00000000   ; row 8
        .byte %10000000,%00000001,%00000000   ; row 9
        .byte %10000000,%00000001,%00000000   ; row 10
        .byte %10000000,%00000001,%00000000   ; row 11
        .byte %10000000,%00000001,%00000000   ; row 12
        .byte %10000000,%00000001,%00000000   ; row 13
        .byte %10000000,%00000001,%00000000   ; row 14
        .byte %11111111,%11111111,%00000000   ; row 15: full bottom edge
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000,%00000000,%00000000
        .byte %00000000
