;=======================================================================================
; Toolbar: button-grid rendering and click handling.
;
; Rendering is driven from render_ui (chrome) via toolbar_render. On a left-click
; that mouse.asm confirms lands in the toolbar band, mouse.asm calls
; toolbar_handle_click, which maps the pointer to a slot and sets selected_tool.
; The selector sprite (sprite 2) is owned by sprites.asm; toolbar_handle_click
; calls sprite_position_selector to move it on a click (sprites_refresh does not
; track it). This module only changes selected_tool / selected_tile.
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

; Called from mouse.asm once a left-click in the toolbar band is confirmed.
; Maps the pointer (mouse_x/mouse_y) to a slot 0..UI_BTN_COUNT-1, selects that
; tool, and moves the selector sprite to it. The selector only moves here (on a
; click), never on hover. Placeholders select but assign no tile.
toolbar_handle_click:
        lda mouse_x+1
        bmi _thc_col0
        lda mouse_x
        lsr
        lsr
        lsr
        sta toolbar_ui_col
        bra _thc_check_inspect
_thc_col0:
        lda #0
        sta toolbar_ui_col

        ; Top-strip inspect icon (cols INSPECT_ICON_COL..+1, rows INSPECT_ICON_ROW..+1)
        ; sits inside the left-toolbar X band but above the button rows. Handle it
        ; first so the row check below doesn't reject it as "above the toolbar".
_thc_check_inspect:
        lda toolbar_ui_col
        cmp #INSPECT_ICON_COL
        bcc _thc_row
        cmp #INSPECT_ICON_COL+2
        bcs _thc_row
        lda mouse_y
        lsr
        lsr
        lsr
        cmp #INSPECT_ICON_ROW
        bcc _thc_row
        cmp #INSPECT_ICON_ROW+2
        bcs _thc_row
        ; click is on the inspect icon
        lda #TILE_INSPECT
        sta selected_tile
        jsr audio_click
        rts

_thc_row:
        lda mouse_y
        cmp #MAIN_PIXEL_Y
        bcc _thc_done

        lda mouse_y
        lsr
        lsr
        lsr
        sta toolbar_ui_row

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
        rts                         ; other slots: selected, no paint tile yet

_thc_road:
        lda #TILE_ROAD
        sta selected_tile
        rts
_thc_power:
        lda #TILE_POWER
        sta selected_tile
        rts
_thc_residential:
        lda #TILE_RESIDENTIAL
        sta selected_tile
        rts
_thc_commercial:
        lda #TILE_COMMERCIAL
        sta selected_tile
        rts
_thc_industrial:
        lda #TILE_INDUSTRIAL
        sta selected_tile
        rts
_thc_coalpp:
        lda #TILE_COALPP
        sta selected_tile
        rts
_thc_nuclearpp:
        lda #TILE_NUCLEARPP
        sta selected_tile
        rts

_thc_bulldoze:
        lda #TILE_GROUND
        sta selected_tile
_thc_done:
        rts

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
