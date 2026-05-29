;=======================================================================================
; Popup overlay.
;
; A modal info window that sits over the map. Carries a 16x8-cell footprint
; (light-grey panel) with a darker title bar at the top and an "OK" hit-rect at
; the bottom. While the overlay is open:
;
;   * mouse_handle_ui_click forwards every confirmed left-click here first;
;     clicks on the OK rect close the popup, everything else is swallowed (so
;     the player can't interact with chrome / map underneath -- the popup is
;     genuinely modal).
;   * render_frame skips render_viewport so the map redraw doesn't paint over
;     the popup chars. Chrome (row 0 menu, FUNDS/DATE, top buttons) is still
;     allowed to redraw because none of those overlap the popup rect.
;   * overlay_close marks the view dirty so the next frame re-renders the
;     16x8 region the popup covered. The underlying cell values are
;     untouched, so cell_to_char reproduces what was there before.
;
; The user reserved $7000-$7FFF for overlay code/data. v1 fits comfortably; if
; future overlays grow past that we'll lay them out by hand.
;=======================================================================================

POPUP_W                 = 16    ; cells across
POPUP_H                 = 8     ; cells down
POPUP_L                 = (VIEW_COLS - POPUP_W) / 2     ; 12 -> cols 12..27
POPUP_T                 = 8                              ; rows 8..15

; Title text starts at this (col, row) within the popup, on the dark title bar.
POPUP_TITLE_COL_LOCAL   = 1
POPUP_TITLE_ROW_LOCAL   = 0
POPUP_TITLE_MAX         = POPUP_W - 2   ; padding on both sides

; OK button: 4 cells wide, 2 cells tall (= 32x16 px) with a raised 3D border
; and camel-case "Ok" baked into the centre chars. The click hit-rect covers
; the whole 32x16 area so it's a comfortable target.
POPUP_OK_W              = 4     ; cells across
POPUP_OK_H              = 2     ; cells down
POPUP_OK_COL_LOCAL      = (POPUP_W - POPUP_OK_W) / 2    ; 6
POPUP_OK_ROW_LOCAL      = POPUP_H - POPUP_OK_H - 1       ; 5 (one row padding above bottom)
POPUP_OK_COL            = POPUP_L + POPUP_OK_COL_LOCAL   ; 18
POPUP_OK_ROW            = POPUP_T + POPUP_OK_ROW_LOCAL   ; 13

;---------------------------------------------------------------------------------------
; overlay_open
;   A:X = pointer to the title string (each byte is a UI_TEXT_* char id)
;   Y   = title length (clamped to POPUP_TITLE_MAX)
;
; Draws the popup; sets overlay_active = 1.
;---------------------------------------------------------------------------------------
overlay_open:
        sta overlay_title_ptr
        stx overlay_title_ptr+1
        cpy #POPUP_TITLE_MAX+1
        bcc +
        ldy #POPUP_TITLE_MAX
+       sty overlay_title_len

        jsr overlay_draw_panel
        jsr overlay_draw_title_text
        jsr overlay_draw_ok

        lda #1
        sta overlay_active
        rts

;---------------------------------------------------------------------------------------
; overlay_close
; Clears overlay_active and flags the map view dirty; the next render_frame
; will repaint the 16x8 region from the unchanged cells.
;---------------------------------------------------------------------------------------
overlay_close:
        lda #0
        sta overlay_active
        jmp render_mark_view_dirty

;---------------------------------------------------------------------------------------
; overlay_handle_click
; Called from mouse_handle_ui_click when overlay_active is set. If the click is
; on the OK rect, closes the overlay. Every click (hit or miss) is consumed,
; so chrome / map clicks don't leak through.
;---------------------------------------------------------------------------------------
overlay_handle_click:
        lda mouse_x+1
        bne _ohc_done               ; off-screen left -- can't be on OK
        lda mouse_x
        cmp #POPUP_OK_COL * 8
        bcc _ohc_done
        cmp #(POPUP_OK_COL + POPUP_OK_W) * 8
        bcs _ohc_done
        lda mouse_y
        cmp #POPUP_OK_ROW * 8
        bcc _ohc_done
        cmp #(POPUP_OK_ROW + POPUP_OK_H) * 8
        bcs _ohc_done
        jsr audio_click
        jsr overlay_close
_ohc_done:
        rts

;---------------------------------------------------------------------------------------
; Fill the 16x8 popup footprint: row 0 with the dark UI_TILE_MENU title bar,
; rows 1..H-1 with the lighter UI_TILE_PANEL body. The title text and OK glyphs
; are stamped on top by the two helpers below.
;---------------------------------------------------------------------------------------
overlay_draw_panel:
        lda #0
        sta overlay_row_idx
_odp_row:
        lda #0
        sta overlay_col_idx
_odp_col:
        ; tile = UI_TILE_MENU on row 0, else UI_TILE_PANEL
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
        adc #POPUP_L
        tax
        clc
        lda overlay_row_idx
        adc #POPUP_T
        tay
        pla
        jsr set_fcm_char
        inc overlay_col_idx
        lda overlay_col_idx
        cmp #POPUP_W
        bne _odp_col
        inc overlay_row_idx
        lda overlay_row_idx
        cmp #POPUP_H
        bne _odp_row
        rts

;---------------------------------------------------------------------------------------
; Stamp the title string starting at the configured local column on the title bar.
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
        adc #(POPUP_L + POPUP_TITLE_COL_LOCAL)
        tax
        ldy #(POPUP_T + POPUP_TITLE_ROW_LOCAL)
        pla
        jsr set_fcm_char
        inc overlay_col_idx
        bra _odtt_loop
_odtt_done:
        rts

;---------------------------------------------------------------------------------------
; Stamp the 4x2 OK button: a raised 3D rectangle with "Ok" baked in. The
; BTN_OK_*_CHAR constants live in shared/ui_tile_layout.asm (next to the other
; char-id allocations, where the .cerror guards can keep them in range); the
; bitmaps live in assets.asm.
;
; These stamps use the 8-bit set_fcm_char entry, so every BTN_OK_*_CHAR must fit
; in a byte. The BK slot is the only one that floats (it's anchored to the end
; of POWER_BRIDGE_CHAR_BASE in ui_tile_layout.asm), so the .cerror there caps
; BTN_OK_BK_CHAR at 255 -- if the chain ever grows past that, this routine
; needs to switch to set_fcm_char16.
;
; Layout:
;   row POPUP_OK_ROW   : [TL][Top-of-O][Top-of-k][TR]
;   row POPUP_OK_ROW+1 : [BL][Bot-of-O][Bot-of-k][BR]
;---------------------------------------------------------------------------------------
overlay_draw_ok:
        ; Top row
        lda #BTN_OK_TL_CHAR
        ldx #POPUP_OK_COL
        ldy #POPUP_OK_ROW
        jsr set_fcm_char
        lda #BTN_OK_TO_CHAR
        ldx #POPUP_OK_COL+1
        ldy #POPUP_OK_ROW
        jsr set_fcm_char
        lda #BTN_OK_TK_CHAR
        ldx #POPUP_OK_COL+2
        ldy #POPUP_OK_ROW
        jsr set_fcm_char
        lda #BTN_OK_TR_CHAR
        ldx #POPUP_OK_COL+3
        ldy #POPUP_OK_ROW
        jsr set_fcm_char
        ; Bottom row
        lda #BTN_OK_BL_CHAR
        ldx #POPUP_OK_COL
        ldy #POPUP_OK_ROW+1
        jsr set_fcm_char
        lda #BTN_OK_BO_CHAR
        ldx #POPUP_OK_COL+1
        ldy #POPUP_OK_ROW+1
        jsr set_fcm_char
        lda #BTN_OK_BK_CHAR
        ldx #POPUP_OK_COL+2
        ldy #POPUP_OK_ROW+1
        jsr set_fcm_char
        lda #BTN_OK_BR_CHAR
        ldx #POPUP_OK_COL+3
        ldy #POPUP_OK_ROW+1
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------
overlay_active:                 .byte 0
overlay_title_ptr:              .word 0
overlay_title_len:              .byte 0
overlay_row_idx:                .byte 0
overlay_col_idx:                .byte 0
