;=======================================================================================
; Map viewport: pointer hit-testing, tile/cursor computation, edge-scrolling.
;
; Translates raw pointer state (mouse_x/y, produced by the device driver in
; mouse.asm) into map-relative state: whether the pointer is inside the playable
; area, which tile it is over (mouse_tile_x/y), the absolute city cursor
; (cursor_x/y), and edge-triggered view scrolling (view_x/y). The dispatcher
; decides when to call these; this module is pure map geometry.
;=======================================================================================

mouse_pointer_inside_viewport:
        lda mouse_y+1
        bne _mpiv_no
        lda mouse_y
        cmp #CURSOR_PIXEL_Y
        bcc _mpiv_no
        cmp #CURSOR_PIXEL_BOTTOM
        bcs _mpiv_no

        lda mouse_x+1
        bmi _mpiv_no
        bne _mpiv_check_right
        lda mouse_x
        cmp #CURSOR_PIXEL_X
        bcc _mpiv_no

_mpiv_check_right:
        lda mouse_x+1
        cmp #>CURSOR_PIXEL_RIGHT
        bcc _mpiv_yes
        bne _mpiv_no
        lda mouse_x
        cmp #<CURSOR_PIXEL_RIGHT
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
        lda #0
        sta mouse_rel+1

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
        lda #0
        sta mouse_tile_x
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
        cmp #CURSOR_PIXEL_Y
        bcc _mctc_y_min
        cmp #MAIN_PIXEL_BOTTOM
        bcs _mctc_y_max

        sec
        lda mouse_y
        sbc #MAIN_PIXEL_Y
        sta mouse_rel
        lda #0
        sta mouse_rel+1

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
        lda #CURSOR_TILE_MIN_Y
        sta mouse_tile_y
        rts

_mctc_y_max:
        lda #MAIN_TILE_ROWS-1
        sta mouse_tile_y
        rts

mouse_scroll_view_from_edge:
        lda #0
        sta mouse_edge_active

        ; Scroll only at the actual screen edges. The square cursor may freeze
        ; over UI chrome, but map scrolling is controlled by the pointer itself.
        lda mouse_x
        cmp #<MOUSE_MIN_X
        bne _msv_right_check
        lda mouse_x+1
        cmp #>MOUSE_MIN_X
        bne _msv_right_check
_msv_mark_left:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_LEFT
        sta mouse_edge_active

_msv_right_check:
        lda mouse_x+1
        bmi _msv_up_check
        cmp #>MOUSE_MAX_X
        bcc _msv_up_check
        bne _msv_mark_right
        lda mouse_x
        cmp #<MOUSE_MAX_X
        bcc _msv_up_check
_msv_mark_right:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_RIGHT
        sta mouse_edge_active

_msv_up_check:
        lda mouse_y+1
        bne _msv_down_check
        lda mouse_y
        bne _msv_down_check
_msv_mark_up:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_UP
        sta mouse_edge_active

_msv_down_check:
        lda mouse_y+1
        bne _msv_mark_down
        lda mouse_y
        ; Trigger when the pointer top-left reaches the logical bottom screen
        ; row. At the clamp, fresh POT deltas are not guaranteed every frame.
        cmp #MOUSE_MAX_Y
        bcc _msv_maybe_scroll
_msv_mark_down:
        lda mouse_edge_active
        ora #MOUSE_SCROLL_DOWN
        sta mouse_edge_active

_msv_maybe_scroll:
        ; Keep scrolling while the pointer remains in an edge band. At the
        ; physical edges the mouse can stop producing fresh deltas, so gating
        ; this on per-frame motion can make scrolling stall.
        lda mouse_edge_active
        bne _msv_count
        lda #0
        sta mouse_scroll_tick
        rts

_msv_count:
        inc mouse_scroll_tick
        lda mouse_scroll_tick
        cmp #MOUSE_SCROLL_DELAY
        bcs _msv_do_scroll
        rts

_msv_do_scroll:
        lda #0
        sta mouse_scroll_tick

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
