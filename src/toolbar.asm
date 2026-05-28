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
        lda toolbar_btn_slot
        asl
        asl
        clc
        adc #UI_BTN_BASE
        ldy toolbar_btn_row
        jsr toolbar_draw_icon
        inc toolbar_btn_slot
        lda toolbar_btn_slot
        cmp #UI_BTN_COUNT
        bne _tbr_loop
        rts

; A = base char id of a 2x2 icon (uses base..base+3), X = left col, Y = top row.
toolbar_draw_icon:
        sta toolbar_icon_base
        stx toolbar_icon_left
        sty toolbar_icon_top

        lda toolbar_icon_base
        ldx toolbar_icon_left
        ldy toolbar_icon_top
        jsr set_fcm_char

        lda toolbar_icon_base
        clc
        adc #1
        ldx toolbar_icon_left
        inx
        ldy toolbar_icon_top
        jsr set_fcm_char

        lda toolbar_icon_base
        clc
        adc #2
        ldx toolbar_icon_left
        ldy toolbar_icon_top
        iny
        jsr set_fcm_char

        lda toolbar_icon_base
        clc
        adc #3
        ldx toolbar_icon_left
        inx
        ldy toolbar_icon_top
        iny
        jsr set_fcm_char
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
top_btn_base_idle:
        .byte INSPECT_CHAR_BASE, LOAD_CHAR_BASE, SAVE_CHAR_BASE
top_btn_base_sel:
        .byte INSPECT_INSET_CHAR_BASE, LOAD_INSET_CHAR_BASE, SAVE_INSET_CHAR_BASE

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

        lda selected_tile
        cmp top_btn_tile,y
        beq _rtb_pick_sel
        lda top_btn_base_idle,y
        bra _rtb_have_base
_rtb_pick_sel:
        lda top_btn_base_sel,y
_rtb_have_base:
        ; A = base, Y = loop idx. Set up X = col + Y = row before the jsr.
        ; (`ldy abs,y` doesn't exist, so we stash the base and let Y get clobbered;
        ; rtb_idx is the source of truth for the loop index, reloaded at the top.)
        sta tbd_base
        ldx top_btn_col,y
        lda top_btn_row,y
        tay
        lda tbd_base
        jsr top_btn_draw_tile

        inc rtb_idx
        bra _rtb_loop
_rtb_done:
        rts

; Stamp a 2x2 button's four chars. A = base char id, X = left col, Y = top row.
top_btn_draw_tile:
        sta tbd_base
        stx tbd_col
        sty tbd_row

        lda tbd_base
        ldx tbd_col
        ldy tbd_row
        jsr set_fcm_char

        lda tbd_base
        clc
        adc #1
        ldx tbd_col
        inx
        ldy tbd_row
        jsr set_fcm_char

        lda tbd_base
        clc
        adc #2
        ldx tbd_col
        ldy tbd_row
        iny
        jsr set_fcm_char

        lda tbd_base
        clc
        adc #3
        ldx tbd_col
        inx
        ldy tbd_row
        iny
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; Click dispatch (shared entry for both regions).
;---------------------------------------------------------------------------------------
; Called from mouse.asm once a left-click in either toolbar band is confirmed.
; Top-strip hit test runs first; on miss, falls through to the left-toolbar
; grid. All exit paths tail-call render_top_buttons so the IDLE/SELECTED state
; flips on every selection change.
toolbar_handle_click:
        lda mouse_x+1
        bmi _thc_col0
        lda mouse_x
        lsr
        lsr
        lsr
        sta toolbar_ui_col
        bra _thc_check_top
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
toolbar_icon_base:
        .byte 0
toolbar_icon_left:
        .byte 0
toolbar_icon_top:
        .byte 0
toolbar_ui_col:
        .byte 0
toolbar_ui_row:
        .byte 0
rtb_idx:                    ; render_top_buttons: loop index
        .byte 0
tbd_base:                   ; top_btn_draw_tile: scratch for the 4-char stamp
        .byte 0
tbd_col:
        .byte 0
tbd_row:
        .byte 0
