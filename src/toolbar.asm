;=======================================================================================
; Toolbar: rendering and click handling for both UI button regions.
;
; Two regions live here so the click dispatch can share one entry point and the
; selection state (selected_tile) has a single owner:
;
;   * Left toolbar -- the 16-slot 2-col paint-tool grid down the left edge.
;     Rendered by toolbar_render; click dispatch in _thc_row maps mouse to slot
;     and moves the yellow selector sprite (sprite 2) via sprite_position_selector.
;
;   * Top strip -- the small menu icons under MEGACITY (inspect / load / save).
;     Rendered by render_top_buttons; click dispatch in _thc_check_top runs a
;     table-driven hit test. No selector sprite; the active button shows its
;     SELECTED (pressed) char bitmap instead.
;
; render_ui calls toolbar_render then render_top_buttons. mouse.asm forwards
; any confirmed left-click in either Y band to toolbar_handle_click (see
; mouse_handle_ui_click in main.asm). Adding a top-strip button is a one-line
; append to the top_btn_* table below + new bitmaps in assets.asm.
;=======================================================================================

; Draw the UI_BTN_COUNT toolbar buttons in a 2-column grid of 2x2 icons.
; Slot i: tile = UI_BTN_BASE + i*4, column = LEFT/RIGHT by i's low bit,
; row = UI_TOOL_ROW_TOP + (i & ~1).
;
; UI_BTN_BASE + slot*4 can grow past 255 once toolbar art is added; we compute
; the 16-bit base by hand (slot*4 low byte + carry into hi) and hand it off to
; btn_stamp_2x2.
toolbar_render:
        lda #0
        sta toolbar_btn_slot
_tbr_loop:
        lda toolbar_btn_slot
        and #$FE
        clc
        adc #UI_TOOL_ROW_TOP
        sta toolbar_btn_row
        lda toolbar_btn_slot
        and #1
        beq _tbr_left
        ldx #UI_TOOL_COL_RIGHT
        bra _tbr_col_done
_tbr_left:
        ldx #UI_TOOL_COL_LEFT
_tbr_col_done:
        stx btn_col                  ; save col; need A free for the base calc

        lda toolbar_btn_slot         ; offset = slot * 4 (8-bit, slot < 64 so no carry yet)
        asl
        asl
        clc
        adc #<UI_BTN_BASE            ; + base low byte
        sta btn_base_lo
        lda #>UI_BTN_BASE
        adc #0                        ; + carry from low add
        sta btn_base_hi

        lda btn_base_lo
        ldx btn_col
        ldy toolbar_btn_row
        jsr btn_stamp_2x2

        inc toolbar_btn_slot
        lda toolbar_btn_slot
        cmp #UI_BTN_COUNT
        bne _tbr_loop
        rts

; Stamp a 2x2 button starting at (X, Y) using a 16-bit base char id.
;   A = base_lo, X = col, Y = row, btn_base_hi must be pre-set.
; Each of the 4 chars is base + 0..3; carry from the low byte propagates into
; snc_char_hi so the stamp stays correct across the 255/256 boundary.
btn_stamp_2x2:
        sta btn_base_lo
        stx btn_col
        sty btn_row

        ; char 0: (base+0, col, row)
        lda btn_base_hi
        sta snc_char_hi
        lda btn_base_lo
        ldx btn_col
        ldy btn_row
        jsr set_fcm_char16

        ; char 1: (base+1, col+1, row)
        clc
        lda btn_base_lo
        adc #1
        pha
        lda btn_base_hi
        adc #0
        sta snc_char_hi
        pla
        ldx btn_col
        inx
        ldy btn_row
        jsr set_fcm_char16

        ; char 2: (base+2, col, row+1)
        clc
        lda btn_base_lo
        adc #2
        pha
        lda btn_base_hi
        adc #0
        sta snc_char_hi
        pla
        ldx btn_col
        ldy btn_row
        iny
        jsr set_fcm_char16

        ; char 3: (base+3, col+1, row+1)
        clc
        lda btn_base_lo
        adc #3
        pha
        lda btn_base_hi
        adc #0
        sta snc_char_hi
        pla
        ldx btn_col
        inx
        ldy btn_row
        iny
        jsr set_fcm_char16
        rts

;---------------------------------------------------------------------------------------
; Top-strip menu buttons (inspect / load / save). Table-driven so adding a button
; is a one-line append below + new IDLE/SELECTED char bases and bitmaps. Each
; button is 2x2 cells. The same table feeds the click hit-test in
; _thc_check_top further down.
;---------------------------------------------------------------------------------------
TOP_BTN_COUNT = 3

top_btn_col:
        .byte INSPECT_ICON_COL, LOAD_ICON_COL, SAVE_ICON_COL
top_btn_row:
        .byte INSPECT_ICON_ROW, LOAD_ICON_ROW, SAVE_ICON_ROW
top_btn_tile:
        .byte TILE_INSPECT, TILE_LOAD, TILE_SAVE
; Char bases are split into lo/hi parallel arrays so any base can exceed 255
; without silently truncating the high byte. Add a row = one entry in each.
top_btn_base_idle_lo:
        .byte <INSPECT_CHAR_BASE, <LOAD_CHAR_BASE, <SAVE_CHAR_BASE
top_btn_base_idle_hi:
        .byte >INSPECT_CHAR_BASE, >LOAD_CHAR_BASE, >SAVE_CHAR_BASE
top_btn_base_sel_lo:
        .byte <INSPECT_INSET_CHAR_BASE, <LOAD_INSET_CHAR_BASE, <SAVE_INSET_CHAR_BASE
top_btn_base_sel_hi:
        .byte >INSPECT_INSET_CHAR_BASE, >LOAD_INSET_CHAR_BASE, >SAVE_INSET_CHAR_BASE

; Redraw every top-strip button. The button whose tile id matches selected_tile
; gets its SELECTED (pressed) chars; the rest get IDLE (raised). Called from
; render_ui after the panel fill, and as a tail-call from toolbar_handle_click
; whenever a click might have changed the selection.
render_top_buttons:
        lda #0
        sta rtb_idx
_rtb_loop:
        ldy rtb_idx
        cpy #TOP_BTN_COUNT
        bcs _rtb_done

        ; Pick idle or selected base lo/hi for this row, both columns at once
        ; (table read happens before any reg gets clobbered).
        lda selected_tile
        cmp top_btn_tile,y
        beq _rtb_pick_sel
        lda top_btn_base_idle_lo,y
        sta btn_base_lo
        lda top_btn_base_idle_hi,y
        sta btn_base_hi
        bra _rtb_have_base
_rtb_pick_sel:
        lda top_btn_base_sel_lo,y
        sta btn_base_lo
        lda top_btn_base_sel_hi,y
        sta btn_base_hi
_rtb_have_base:
        ldx top_btn_col,y
        lda top_btn_row,y
        tay
        lda btn_base_lo
        jsr btn_stamp_2x2            ; 16-bit base via btn_base_hi pre-set

        inc rtb_idx
        bra _rtb_loop
_rtb_done:
        rts

;---------------------------------------------------------------------------------------
; Click dispatch (shared entry for both regions).
;---------------------------------------------------------------------------------------
; Called from mouse.asm once a left-click in either toolbar band is confirmed.
; Top-strip hit test runs first; on miss, falls through to the left-toolbar
; grid. All exit paths tail-call render_top_buttons so the IDLE/SELECTED state
; flips on every selection change.
toolbar_handle_click:
        ; Belt-and-braces X gate. mouse_handle_ui_click already rejects X >= 256
        ; before forwarding here, but repeating the check means the wrap (low
        ; byte / 8 silently mapping cols 32..39 into 0..7) can't bite if a
        ; future caller forgets the upstream gate.
        lda mouse_x+1
        bmi _thc_col0               ; negative -> off-screen left, clamp to col 0
        bne _thc_reject             ; positive nonzero -> X >= 256, not the toolbar
        lda mouse_x
        lsr
        lsr
        lsr
        sta toolbar_ui_col
        bra _thc_check_top
_thc_reject:
        rts
_thc_col0:
        lda #0
        sta toolbar_ui_col

        ; Top-strip menu buttons (inspect / load / save). They live above the
        ; left-toolbar grid in the rows under MEGACITY, so we check them BEFORE
        ; the "above the toolbar band" row test in _thc_row -- otherwise that
        ; test would reject them. Table is shared with render.asm; each row is
        ; (col, row, tile id, idle char base, selected char base), all 2x2 cells.
_thc_check_top:
        lda mouse_y
        lsr
        lsr
        lsr
        sta toolbar_ui_row
        ldy #0
_thct_loop:
        cpy #TOP_BTN_COUNT
        bcs _thc_row                ; no top button hit -> fall through
        lda toolbar_ui_col
        sec
        sbc top_btn_col,y
        bcc _thct_next              ; col < button col
        cmp #TOP_BTN_W
        bcs _thct_next              ; col >= button col + W
        lda toolbar_ui_row
        sec
        sbc top_btn_row,y
        bcc _thct_next              ; row < button row
        cmp #TOP_BTN_H
        bcs _thct_next              ; row >= button row + H
        ; hit
        lda top_btn_tile,y
        sta selected_tile
        jsr audio_click
        jmp render_top_buttons      ; flip idle <-> selected for the new state
_thct_next:
        iny
        bra _thct_loop

_thc_row:
        lda mouse_y
        cmp #MAIN_PIXEL_Y
        bcc _thc_done

        ; toolbar_ui_row was already set by the top-button scan above.
        lda toolbar_ui_col
        cmp #UI_LEFT_COLS
        bcs _thc_done

        lda toolbar_ui_row
        cmp #UI_TOOL_ROW_TOP
        bcc _thc_done
        cmp #UI_TOOL_ROW_TOP + 16
        bcs _thc_done

        sec
        sbc #UI_TOOL_ROW_TOP        ; 0..15 within the grid
        and #$FE                    ; button row * 2 = the row's left slot
        tax
        lda toolbar_ui_col
        cmp #UI_TOOL_COL_RIGHT
        bcc +
        inx                         ; right column -> +1
+
        txa                         ; A = clicked slot 0..15
        sta selected_tool
        jsr sprite_position_selector   ; move selector to the clicked slot
        jsr audio_click                ; toolbar button clicked -> click

        lda selected_tool
        beq _thc_bulldoze           ; slot 0 -> bulldozer
        cmp #1
        beq _thc_road               ; slot 1 -> road
        cmp #2
        beq _thc_rail               ; slot 2 -> rail (1x1)
        cmp #3
        beq _thc_power              ; slot 3 -> power lines (1x1)
        cmp #5
        beq _thc_residential        ; slot 5 -> residential zone (3x3)
        cmp #6
        beq _thc_commercial         ; slot 6 -> commercial zone (3x3)
        cmp #7
        beq _thc_industrial         ; slot 7 -> industrial zone (3x3)
        cmp #12
        beq _thc_coalpp             ; slot 12 -> coal power plant (3x4)
        cmp #13
        beq _thc_nuclearpp          ; slot 13 -> nuclear power plant (3x4)
        bra _thc_done               ; other slots: selected, no paint tile yet

_thc_road:
        lda #TILE_ROAD
        sta selected_tile
        bra _thc_done
_thc_rail:
        lda #TILE_RAIL
        sta selected_tile
        bra _thc_done
_thc_power:
        lda #TILE_POWER
        sta selected_tile
        bra _thc_done
_thc_residential:
        lda #TILE_RESIDENTIAL
        sta selected_tile
        bra _thc_done
_thc_commercial:
        lda #TILE_COMMERCIAL
        sta selected_tile
        bra _thc_done
_thc_industrial:
        lda #TILE_INDUSTRIAL
        sta selected_tile
        bra _thc_done
_thc_coalpp:
        lda #TILE_COALPP
        sta selected_tile
        bra _thc_done
_thc_nuclearpp:
        lda #TILE_NUCLEARPP
        sta selected_tile
        bra _thc_done

_thc_bulldoze:
        lda #TILE_GROUND
        sta selected_tile
_thc_done:
        jmp render_top_buttons      ; flip raised <-> pressed for any selection change

toolbar_btn_slot:
        .byte 0
toolbar_btn_row:
        .byte 0
toolbar_ui_col:
        .byte 0
toolbar_ui_row:
        .byte 0
rtb_idx:                    ; render_top_buttons: loop index
        .byte 0
btn_base_lo:                ; btn_stamp_2x2: 16-bit base char id + col/row
        .byte 0
btn_base_hi:
        .byte 0
btn_col:
        .byte 0
btn_row:
        .byte 0
