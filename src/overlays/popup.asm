;=======================================================================================
; Popup (resident shared code for every overlay).
;
; Generic modal popup the inspector / save / load overlays all build on. Each
; overlay sets the geometry vars (popup_w/h/l/t) BEFORE calling overlay_open;
; overlay_open then derives the OK button position (centred horizontally, one
; row above the bottom edge) and renders the title bar + body + OK button.
; The hit-test runs against the derived pixel bounds so the same code handles
; any popup size.
;
; A convenience helper `overlay_set_default_geometry` sets 16x8 cells centred
; in the 40-col view (cols 12..27 / rows 8..15) -- the size every overlay used
; before the parameterisation pass.
;
; While the overlay is open:
;   * mouse_handle_ui_click forwards every confirmed left-click here first;
;     clicks on the OK rect close the popup, everything else is swallowed.
;   * render_frame skips render_viewport so the map redraw doesn't paint over
;     the popup chars. Chrome rows (0..2) are still redrawn because they're
;     above the popup and never overlap it.
;   * overlay_close marks the view dirty so the next frame repaints the
;     popup-sized region from the unchanged cell values underneath.
;=======================================================================================

; Fixed parts of the popup design (intrinsic to the OK button glyphs and the
; one-cell title-bar inset). Popup size and position are runtime.
POPUP_OK_W              = 4     ; cells across (32 px)
POPUP_OK_H              = 2     ; cells down (16 px)
POPUP_OK_PIXEL_W        = POPUP_OK_W * 8
POPUP_OK_PIXEL_H        = POPUP_OK_H * 8
POPUP_TITLE_COL_LOCAL   = 1
POPUP_TITLE_ROW_LOCAL   = 0
POPUP_DEFAULT_W         = 16
POPUP_DEFAULT_H         = 8
POPUP_DEFAULT_L         = (VIEW_COLS - POPUP_DEFAULT_W) / 2     ; 12
POPUP_DEFAULT_T         = 8
; tile_names.asm `.cerror`s use this for compile-time string-length checks.
; Tied to the default-popup width since the inspector uses default geometry.
POPUP_TITLE_MAX         = POPUP_DEFAULT_W - 2                    ; 14

;---------------------------------------------------------------------------------------
; overlay_set_default_geometry: 16x8 cells centred horizontally, anchored at
; row 8. Convenience for overlays that don't care about size.
;---------------------------------------------------------------------------------------
overlay_set_default_geometry:
        lda #POPUP_DEFAULT_W
        sta popup_w
        lda #POPUP_DEFAULT_H
        sta popup_h
        lda #POPUP_DEFAULT_L
        sta popup_l
        lda #POPUP_DEFAULT_T
        sta popup_t
        rts

;---------------------------------------------------------------------------------------
; overlay_open
;   A:X = pointer to the title string (each byte is a UI_TEXT_* char id)
;   Y   = title length (clamped to popup_w - 2)
;   Caller has pre-set popup_l / popup_t / popup_w / popup_h.
;
; Derives OK button position + pixel hit-test bounds from the geometry vars,
; draws the popup, sets overlay_active = 1.
;---------------------------------------------------------------------------------------
overlay_open:
        sta overlay_title_ptr
        stx overlay_title_ptr+1

        ; Clamp title length to popup_w - 2 (1 col padding on each side).
        sty overlay_title_len
        sec
        lda popup_w
        sbc #2
        cmp overlay_title_len
        bcs +
        sta overlay_title_len
+
        ; popup_ok_col = popup_l + (popup_w - POPUP_OK_W) / 2 (centred horizontally)
        sec
        lda popup_w
        sbc #POPUP_OK_W
        lsr
        clc
        adc popup_l
        sta popup_ok_col

        ; popup_ok_row = popup_t + popup_h - POPUP_OK_H - 1 (one cell padding above bottom)
        clc
        lda popup_t
        adc popup_h
        sec
        sbc #(POPUP_OK_H + 1)
        sta popup_ok_row

        ; Pixel hit-test bounds for overlay_handle_click and overlays that
        ; want to drive their own mouse loop (save/load).
        lda popup_ok_col
        asl
        asl
        asl
        sta popup_ok_x_pixel
        clc
        adc #POPUP_OK_PIXEL_W
        sta popup_ok_x_pixel_end
        lda popup_ok_row
        asl
        asl
        asl
        sta popup_ok_y_pixel
        clc
        adc #POPUP_OK_PIXEL_H
        sta popup_ok_y_pixel_end

        jsr overlay_draw_panel
        jsr overlay_draw_title_text
        jsr overlay_draw_ok

        lda #1
        sta overlay_active
        rts

;---------------------------------------------------------------------------------------
; overlay_close
; Clears overlay_active and flags the map view dirty; the next render_frame
; repaints the popup-sized region from the unchanged cells.
;---------------------------------------------------------------------------------------
overlay_close:
        lda #0
        sta overlay_active
        ; Drop any body-click hook so a popup that registered one doesn't
        ; keep dispatching clicks after it closed.
        sta popup_body_click_hook
        sta popup_body_click_hook+1
        jmp render_mark_view_dirty

;---------------------------------------------------------------------------------------
; overlay_handle_click
; Called from mouse_handle_ui_click when overlay_active is set. If the click
; is on the OK rect, closes the overlay; otherwise the click is swallowed so
; chrome / map underneath stays inert.
;---------------------------------------------------------------------------------------
overlay_handle_click:
        lda mouse_x+1
        bne _ohc_done               ; off-screen left -- can't be on OK
        ; OK rect first: closes the popup unconditionally.
        lda mouse_x
        cmp popup_ok_x_pixel
        bcc _ohc_body
        cmp popup_ok_x_pixel_end
        bcs _ohc_body
        lda mouse_y
        cmp popup_ok_y_pixel
        bcc _ohc_body
        cmp popup_ok_y_pixel_end
        bcs _ohc_body
        jsr audio_click
        jsr overlay_close
        rts
_ohc_body:
        ; Body click: if the active popup registered a body-click hook
        ; (popup_body_click_hook != 0), dispatch through it. The hook
        ; reads mouse_x/y, updates whatever popup state it owns, and rts.
        ; Without a hook, the click is swallowed (existing behaviour).
        lda popup_body_click_hook
        ora popup_body_click_hook+1
        beq _ohc_done
        jmp (popup_body_click_hook)
_ohc_done:
        rts

;---------------------------------------------------------------------------------------
; Fill the popup footprint: row 0 with the dark UI_TILE_MENU title bar,
; rows 1..popup_h-1 with the lighter UI_TILE_PANEL body. The title text and
; OK glyphs are stamped on top by the two helpers below.
;---------------------------------------------------------------------------------------
overlay_draw_panel:
        lda #0
        sta overlay_row_idx
_odp_row:
        lda #0
        sta overlay_col_idx
_odp_col:
        lda overlay_row_idx
        bne _odp_body
        lda #UI_TILE_MENU
        bra _odp_have_tile
_odp_body:
        lda #UI_TILE_PANEL
_odp_have_tile:
        pha
        clc
        lda overlay_col_idx
        adc popup_l
        tax
        clc
        lda overlay_row_idx
        adc popup_t
        tay
        pla
        jsr set_fcm_char
        inc overlay_col_idx
        lda overlay_col_idx
        cmp popup_w
        bne _odp_col
        inc overlay_row_idx
        lda overlay_row_idx
        cmp popup_h
        bne _odp_row
        rts

;---------------------------------------------------------------------------------------
; Stamp the title string starting at popup_l + POPUP_TITLE_COL_LOCAL on the
; title bar (popup_t + POPUP_TITLE_ROW_LOCAL).
;---------------------------------------------------------------------------------------
overlay_draw_title_text:
        lda overlay_title_len
        beq _odtt_done
        ; PTR2 is the zero-page pointer for (zp),y addressing. set_fcm_char
        ; only touches PTR/$FC, so PTR2 survives across the loop body.
        lda overlay_title_ptr
        sta PTR2
        lda overlay_title_ptr+1
        sta PTR2+1
        lda #0
        sta overlay_col_idx
_odtt_loop:
        lda overlay_col_idx
        cmp overlay_title_len
        bcs _odtt_done
        ldy overlay_col_idx
        lda (PTR2),y
        pha
        clc
        lda overlay_col_idx
        adc popup_l
        clc
        adc #POPUP_TITLE_COL_LOCAL
        tax
        clc
        lda popup_t
        adc #POPUP_TITLE_ROW_LOCAL
        tay
        pla
        jsr set_fcm_char
        inc overlay_col_idx
        bra _odtt_loop
_odtt_done:
        rts

;---------------------------------------------------------------------------------------
; Stamp the 4x2 OK button at (popup_ok_col, popup_ok_row).
; Layout:
;   row 0: [TL][Top-of-O][Top-of-k][TR]
;   row 1: [BL][Bot-of-O][Bot-of-k][BR]
;
; set_fcm_char preserves X and Y across calls, so we just walk X and bump
; Y once for the bottom row.
;---------------------------------------------------------------------------------------
overlay_draw_ok:
        ldx popup_ok_col
        ldy popup_ok_row
        lda #BTN_OK_TL_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_TO_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_TK_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_TR_CHAR
        jsr set_fcm_char
        ; bottom row
        ldx popup_ok_col
        iny
        lda #BTN_OK_BL_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_BO_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_BK_CHAR
        jsr set_fcm_char
        inx
        lda #BTN_OK_BR_CHAR
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------

; Caller-set geometry (any cell coordinate up to VIEW_COLS x VIEW_ROWS).
popup_l:                .byte 0
popup_t:                .byte 0
popup_w:                .byte 0
popup_h:                .byte 0

; Derived by overlay_open from the geometry. Used by overlay_draw_ok and
; overlay_handle_click + the save/load overlays' own mouse loops.
popup_ok_col:           .byte 0
popup_ok_row:           .byte 0
popup_ok_x_pixel:       .byte 0
popup_ok_x_pixel_end:   .byte 0
popup_ok_y_pixel:       .byte 0
popup_ok_y_pixel_end:   .byte 0

; Existing state.
overlay_active:                 .byte 0
overlay_title_ptr:              .word 0
overlay_title_len:              .byte 0
overlay_row_idx:                .byte 0
overlay_col_idx:                .byte 0

; Optional body-click hook. When non-zero, overlay_handle_click jmp's through
; it for any click NOT on the OK rect, so the popup body can run its own
; click handler (rows, buttons, etc.). overlay_close clears the hook so it
; doesn't fire across popup boundaries. Hook should rts (not jmp); it may
; redraw whatever popup state changed.
popup_body_click_hook:          .word 0
