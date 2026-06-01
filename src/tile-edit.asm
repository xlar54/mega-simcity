;=======================================================================================
; MEGA-City Tile Editor - companion FCM tile/character editor scaffold.
;
; Standalone program. It uses the same FCM screen and 1351-style mouse reader as
; the main game, but keeps its own screen layout and sprite setup.
;
; Current first pass:
;   * left palette strip
;   * single-line header/status strip
;   * right-side character browser for char RAM
;   * resizable enlarged edit grid, one or two source pixels per screen cell
;   * painting writes through to the selected 2x2 block of 8x8 chars
;
; Later passes should add disk save/export and multi-cell tile grouping.
;=======================================================================================

        .cpu "45gs02"
        .include "platform.asm"

;=======================================================================================
; BASIC stub - BANK 0 : SYS 8210 ($2012)
;=======================================================================================

        * = $2001

        .word (+), 2026
        .byte $fe, $02, $30
        .byte ':'
        .byte $9e
        .text "8210"
        .byte 0
+       .word 0

        * = $2012

;=======================================================================================
; Editor constants.
;=======================================================================================

TE_GRID_X               = 4
TE_GRID_Y               = 1
TE_GRID_MIN_W           = 8
TE_GRID_MIN_H           = 8
TE_GRID_MAX_W           = 32
TE_GRID_MAX_H           = 32
TE_GRID_SCREEN_W        = 24
TE_GRID_SCREEN_H        = 24
TE_GRID_START_W         = 8
TE_GRID_START_H         = 8

TE_PALETTE_X            = 1
TE_PALETTE_BUTTON_Y     = 1
TE_PALETTE_Y            = 2
TE_PALETTE_H            = 16
TE_PALETTE_PAGE_STEP    = 16
TE_PALETTE_MAX_BASE     = 240
TE_PALETTE_FILE_SIZE    = 768
TE_PALETTE_EDIT_Y       = 23

TE_PAL_SLIDER_X         = 4
TE_PAL_SLIDER_W         = 16
TE_PAL_R_ROW            = 4
TE_PAL_G_ROW            = 7
TE_PAL_B_ROW            = 10
TE_PAL_VALUE_X          = 22
TE_PAL_PREVIEW_X        = 28
TE_PAL_PREVIEW_Y        = 4
TE_PAL_PREVIEW_SIZE     = 4
TE_PAL_EXIT_Y           = 23

TE_BROWSER_CTRL_X       = 30
TE_BROWSER_CTRL_Y       = 0
TE_BROWSER_X            = 32
TE_BROWSER_Y            = 1
TE_BROWSER_W            = 8
TE_BROWSER_H            = 24
TE_BROWSER_PAGE_STEP    = TE_BROWSER_W * TE_BROWSER_H
TE_BROWSER_MAX_HI       = $03
TE_BROWSER_MAX_LO       = $40          ; 1024 - 192 = 832 = $0340

TE_EDITOR_CHAR_BASE     = 956         ; Last 68 chars in the 0..1023 browser range.
TE_TILESET_LOAD_SIZE    = TE_EDITOR_CHAR_BASE * 64
TE_EXPORT_MAX_CHAR      = TE_EDITOR_CHAR_BASE - 1
TE_EDITOR_CHAR_HI       = >TE_EDITOR_CHAR_BASE
TE_CHAR_SOLID_BASE      = TE_EDITOR_CHAR_BASE
TE_CHAR_GRID_BASE       = TE_EDITOR_CHAR_BASE + 16
TE_CHAR_PANEL           = TE_EDITOR_CHAR_BASE + 32
TE_CHAR_FRAME           = TE_EDITOR_CHAR_BASE + 33
TE_CHAR_TEXT_BG         = TE_EDITOR_CHAR_BASE + 34
TE_CHAR_BROWSER_BG      = TE_EDITOR_CHAR_BASE + 35

TE_TEXT_T               = TE_EDITOR_CHAR_BASE + 36
TE_TEXT_I               = TE_EDITOR_CHAR_BASE + 37
TE_TEXT_L               = TE_EDITOR_CHAR_BASE + 38
TE_TEXT_E               = TE_EDITOR_CHAR_BASE + 39
TE_TEXT_S               = TE_EDITOR_CHAR_BASE + 40
TE_TEXT_Z               = TE_EDITOR_CHAR_BASE + 41
TE_TEXT_COLON           = TE_EDITOR_CHAR_BASE + 42
TE_TEXT_1               = TE_EDITOR_CHAR_BASE + 43
TE_TEXT_6               = TE_EDITOR_CHAR_BASE + 44
TE_TEXT_X               = TE_EDITOR_CHAR_BASE + 45
TE_TEXT_D               = TE_EDITOR_CHAR_BASE + 46
TE_TEXT_2               = TE_EDITOR_CHAR_BASE + 47
TE_TEXT_4               = TE_EDITOR_CHAR_BASE + 48
TE_TEXT_8               = TE_EDITOR_CHAR_BASE + 49
TE_TEXT_3               = TE_EDITOR_CHAR_BASE + 50
TE_TEXT_0               = TE_EDITOR_CHAR_BASE + 51
TE_TEXT_5               = TE_EDITOR_CHAR_BASE + 52
TE_TEXT_7               = TE_EDITOR_CHAR_BASE + 53
TE_TEXT_9               = TE_EDITOR_CHAR_BASE + 54
TE_TEXT_MINUS           = TE_EDITOR_CHAR_BASE + 55
TE_CHAR_PAGE_UP         = TE_EDITOR_CHAR_BASE + 56
TE_CHAR_PAGE_DOWN       = TE_EDITOR_CHAR_BASE + 57
TE_TEXT_R               = TE_EDITOR_CHAR_BASE + 58
TE_TEXT_G               = TE_EDITOR_CHAR_BASE + 59
TE_TEXT_B               = TE_EDITOR_CHAR_BASE + 60
TE_TEXT_P               = TE_EDITOR_CHAR_BASE + 61
TE_TEXT_A               = TE_EDITOR_CHAR_BASE + 62
TE_CHAR_PALETTE_MARKER  = TE_EDITOR_CHAR_BASE + 63
TE_TEXT_C               = TE_EDITOR_CHAR_BASE + 64
TE_TEXT_F               = TE_EDITOR_CHAR_BASE + 65
TE_TEXT_H               = TE_EDITOR_CHAR_BASE + 66
TE_TEXT_HASH            = TE_EDITOR_CHAR_BASE + 67

TE_FILENAME_MAX         = 32

;=======================================================================================
; Small local macros.
;=======================================================================================

LOAD_CHAR .macro id, src
        ldx #<\src
        stx PTR2
        ldx #>\src
        stx PTR2+1
        ldx #>(\id)
        lda #<(\id)
        jsr create_fcm_char16
.endmacro

SET_COLOR .macro index, red, green, blue
        lda #\index
        ldx #((((\red) & $0F) << 4) | (((\red) >> 4) & $0F))
        ldy #((((\green) & $0F) << 4) | (((\green) >> 4) & $0F))
        ldz #((((\blue) & $0F) << 4) | (((\blue) >> 4) & $0F))
        jsr set_palette_color
        lda #((((\red) & $0F) << 4) | (((\red) >> 4) & $0F))
        sta te_palette_red+\index
        lda #((((\green) & $0F) << 4) | (((\green) >> 4) & $0F))
        sta te_palette_green+\index
        lda #((((\blue) & $0F) << 4) | (((\blue) >> 4) & $0F))
        sta te_palette_blue+\index
.endmacro

TEXT_AT .macro row, col, line
        lda #\row
        ldx #\col
        jsr te_set_text_cursor_direct
        ldx #<\line
        ldy #>\line
        jsr te_print_direct_string
.endmacro

;=======================================================================================
; Text-mode startup menu.
;=======================================================================================

te_text_menu:
        jsr te_prepare_text_screen
        jsr te_draw_start_menu

_te_tm_wait:
        jsr te_get_key
        cmp #'1'
        beq _te_tm_new
        cmp #'2'
        beq _te_tm_load
        cmp #'3'
        beq _te_tm_load_palette
        cmp #'4'
        beq _te_tm_enter_editor
        bra _te_tm_wait

_te_tm_new:
        jsr te_prepare_text_screen
        ldx #<te_msg_new_title
        ldy #>te_msg_new_title
        jsr te_print_string
        jsr te_set_default_filename
        jsr te_clear_editable_charset
        ldx #<te_msg_new
        ldy #>te_msg_new
        jsr te_print_string
        jsr te_get_key
        bra te_text_menu

_te_tm_load:
        jsr te_prepare_text_screen
        ldx #<te_msg_load_tiles_title
        ldy #>te_msg_load_tiles_title
        jsr te_print_string
        jsr te_prompt_filename
        lda te_filename_len
        beq te_text_menu
        jsr te_load_tileset_from_disk
        bcc _te_tm_loaded
        ldx #<te_msg_load_fail
        ldy #>te_msg_load_fail
        jsr te_print_string
        jsr te_get_key
        bra te_text_menu
_te_tm_loaded:
        ldx #<te_msg_loaded
        ldy #>te_msg_loaded
        jsr te_print_string
        jsr te_get_key
        bra te_text_menu

_te_tm_load_palette:
        jsr te_prepare_text_screen
        ldx #<te_msg_load_palette_title
        ldy #>te_msg_load_palette_title
        jsr te_print_string
        jsr te_prompt_palette_filename
        lda te_palette_filename_len
        beq te_text_menu
        jsr te_load_palette_from_disk
        bcc _te_tm_palette_loaded
        ldx #<te_msg_palette_load_fail
        ldy #>te_msg_palette_load_fail
        jsr te_print_string
        jsr te_get_key
        bra te_text_menu
_te_tm_palette_loaded:
        ldx #<te_msg_palette_loaded
        ldy #>te_msg_palette_loaded
        jsr te_print_string
        jsr te_get_key
        bra te_text_menu

_te_tm_enter_editor:
        jmp te_enter_editor

te_resume_editor:
        jsr te_enable_40mhz
        jsr te_detect_platform

        lda #MODE_FCM40
        jsr set_screen_mode
        jsr init_fcm
        jsr te_apply_palette_shadow
        jsr te_build_chars
        jsr te_init_sprites
        jsr te_draw_static_ui
        jsr te_draw_palette
        jsr te_draw_browser_controls
        jsr te_draw_browser
        jsr te_draw_grid
        jsr te_select_base_char_as_active
        jsr te_position_browser_cursor
        jsr te_position_pointer_sprite
        jmp te_loop

te_apply_editor_palette:
        lda te_palette_loaded
        beq _te_aep_default
        jmp te_apply_palette_shadow
_te_aep_default:
        jmp te_init_palette

te_print_string:
        stx PTR2
        sty PTR2+1
        ldy #0
_te_ps_loop:
        lda (PTR2),y
        beq _te_ps_done
        jsr KERNAL_CHROUT
        iny
        bne _te_ps_loop
_te_ps_done:
        rts

te_get_key:
        jsr KERNAL_GETIN
        beq te_get_key
        rts

te_input_cursor_show:
        lda #$A4                    ; PETSCII underscore in upper/lower mode.
        jmp KERNAL_CHROUT

te_input_cursor_hide:
        lda #$14
        jmp KERNAL_CHROUT

te_is_cursor_key:
        cmp #KEY_CRSR_UP
        beq _te_ick_yes
        cmp #KEY_CRSR_UP_ALT
        beq _te_ick_yes
        cmp #KEY_CRSR_DOWN
        beq _te_ick_yes
        cmp #KEY_CRSR_RIGHT
        beq _te_ick_yes
        cmp #KEY_CRSR_LEFT
        beq _te_ick_yes
        cmp #KEY_CRSR_LEFT_ALT
        beq _te_ick_yes
        clc
        rts
_te_ick_yes:
        sec
        rts

te_prompt_filename:
        ldx #<te_msg_filename
        ldy #>te_msg_filename
        jsr te_print_string
        lda #0
        sta te_filename_len
        jmp te_prompt_filename_loop

te_prompt_save_filename:
        ldx #<te_msg_save_filename
        ldy #>te_msg_save_filename
        jsr te_print_string
        lda te_filename_len
        beq _te_psf_input
        lda #'['
        jsr KERNAL_CHROUT
        ldx #0
_te_psf_show_current:
        cpx te_filename_len
        bcs _te_psf_show_done
        lda te_filename_buf,x
        jsr KERNAL_CHROUT
        inx
        bra _te_psf_show_current
_te_psf_show_done:
        lda #']'
        jsr KERNAL_CHROUT
        lda #' '
        jsr KERNAL_CHROUT
_te_psf_input:
        lda #0
        sta te_filename_new_len
        lda #1
        sta te_prompt_keep_existing
        bra te_prompt_filename_read_loop

te_prompt_palette_filename:
        ldx #<te_msg_palette_filename
        ldy #>te_msg_palette_filename
        jsr te_print_string
        lda #0
        sta te_palette_filename_len
        jmp te_prompt_palette_filename_loop

te_prompt_save_palette_filename:
        ldx #<te_msg_save_palette_filename
        ldy #>te_msg_save_palette_filename
        jsr te_print_string
        lda te_palette_filename_len
        beq _te_pspf_input
        lda #'['
        jsr KERNAL_CHROUT
        ldx #0
_te_pspf_show_current:
        cpx te_palette_filename_len
        bcs _te_pspf_show_done
        lda te_palette_filename_buf,x
        jsr KERNAL_CHROUT
        inx
        bra _te_pspf_show_current
_te_pspf_show_done:
        lda #']'
        jsr KERNAL_CHROUT
        lda #' '
        jsr KERNAL_CHROUT
_te_pspf_input:
        lda #0
        sta te_filename_new_len
        lda #1
        sta te_prompt_keep_existing
        bra te_prompt_palette_filename_read_loop

te_prompt_save_export_filename:
        ldx #<te_msg_save_export_filename
        ldy #>te_msg_save_export_filename
        jsr te_print_string
        lda te_export_filename_len
        beq _te_psef_input
        lda #'['
        jsr KERNAL_CHROUT
        ldx #0
_te_psef_show_current:
        cpx te_export_filename_len
        bcs _te_psef_show_done
        lda te_export_filename_buf,x
        jsr KERNAL_CHROUT
        inx
        bra _te_psef_show_current
_te_psef_show_done:
        lda #']'
        jsr KERNAL_CHROUT
        lda #' '
        jsr KERNAL_CHROUT
_te_psef_input:
        lda #0
        sta te_filename_new_len
        lda #1
        sta te_prompt_keep_existing
        bra te_prompt_export_filename_read_loop

te_prompt_export_filename_loop:
        lda #0
        sta te_filename_new_len
        sta te_prompt_keep_existing
        jsr te_input_cursor_show
te_prompt_export_filename_read_loop:
        jsr te_get_key
        cmp #$0D
        beq _te_pef_done
        cmp #$14
        beq _te_pef_backspace
        cmp #$08
        beq _te_pef_backspace
        jsr te_is_cursor_key
        bcs te_prompt_export_filename_read_loop
        cmp #$20
        bcc te_prompt_export_filename_read_loop
        ldx te_filename_new_len
        cpx #TE_FILENAME_MAX
        bcs te_prompt_export_filename_read_loop
        sta te_filename_new_buf,x
        pha
        inc te_filename_new_len
        jsr te_input_cursor_hide
        pla
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_export_filename_read_loop
_te_pef_backspace:
        lda te_filename_new_len
        beq te_prompt_export_filename_read_loop
        jsr te_input_cursor_hide
        dec te_filename_new_len
        lda #$14
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_export_filename_read_loop
_te_pef_done:
        jsr te_input_cursor_hide
        lda #$0D
        jsr KERNAL_CHROUT
        lda te_filename_new_len
        bne _te_pef_commit
        lda te_prompt_keep_existing
        bne _te_pef_keep
_te_pef_commit:
        lda te_filename_new_len
        sta te_export_filename_len
        ldx #0
_te_pef_commit_loop:
        cpx te_export_filename_len
        bcs _te_pef_keep
        lda te_filename_new_buf,x
        sta te_export_filename_buf,x
        inx
        bra _te_pef_commit_loop
_te_pef_keep:
        rts

te_prompt_palette_filename_loop:
        lda #0
        sta te_filename_new_len
        sta te_prompt_keep_existing
        jsr te_input_cursor_show
te_prompt_palette_filename_read_loop:
        jsr te_get_key
        cmp #$0D
        beq _te_ppf_done
        cmp #$14
        beq _te_ppf_backspace
        cmp #$08
        beq _te_ppf_backspace
        jsr te_is_cursor_key
        bcs te_prompt_palette_filename_read_loop
        cmp #$20
        bcc te_prompt_palette_filename_read_loop
        ldx te_filename_new_len
        cpx #TE_FILENAME_MAX
        bcs te_prompt_palette_filename_read_loop
        sta te_filename_new_buf,x
        pha
        inc te_filename_new_len
        jsr te_input_cursor_hide
        pla
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_palette_filename_read_loop
_te_ppf_backspace:
        lda te_filename_new_len
        beq te_prompt_palette_filename_read_loop
        jsr te_input_cursor_hide
        dec te_filename_new_len
        lda #$14
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_palette_filename_read_loop
_te_ppf_done:
        jsr te_input_cursor_hide
        lda #$0D
        jsr KERNAL_CHROUT
        lda te_filename_new_len
        bne _te_ppf_commit
        lda te_prompt_keep_existing
        bne _te_ppf_keep
_te_ppf_commit:
        lda te_filename_new_len
        sta te_palette_filename_len
        ldx #0
_te_ppf_commit_loop:
        cpx te_palette_filename_len
        bcs _te_ppf_keep
        lda te_filename_new_buf,x
        sta te_palette_filename_buf,x
        inx
        bra _te_ppf_commit_loop
_te_ppf_keep:
        rts

te_prompt_filename_loop:
        lda #0
        sta te_filename_new_len
        sta te_prompt_keep_existing
        jsr te_input_cursor_show
te_prompt_filename_read_loop:
        jsr te_get_key
        cmp #$0D
        beq _te_pf_done
        cmp #$14
        beq _te_pf_backspace
        cmp #$08
        beq _te_pf_backspace
        jsr te_is_cursor_key
        bcs te_prompt_filename_read_loop
        cmp #$20
        bcc te_prompt_filename_read_loop
        ldx te_filename_new_len
        cpx #TE_FILENAME_MAX
        bcs te_prompt_filename_read_loop
        sta te_filename_new_buf,x
        pha
        inc te_filename_new_len
        jsr te_input_cursor_hide
        pla
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_filename_read_loop
_te_pf_backspace:
        lda te_filename_new_len
        beq te_prompt_filename_read_loop
        jsr te_input_cursor_hide
        dec te_filename_new_len
        lda #$14
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra te_prompt_filename_read_loop
_te_pf_done:
        jsr te_input_cursor_hide
        lda #$0D
        jsr KERNAL_CHROUT
        lda te_filename_new_len
        bne _te_pf_commit
        lda te_prompt_keep_existing
        bne _te_pf_keep
_te_pf_commit:
        lda te_filename_new_len
        sta te_filename_len
        ldx #0
_te_pf_commit_loop:
        cpx te_filename_len
        bcs _te_pf_keep
        lda te_filename_new_buf,x
        sta te_filename_buf,x
        inx
        bra _te_pf_commit_loop
_te_pf_keep:
        rts

te_save_from_text_screen:
        lda #0
        sta SPRITE_ENABLE
        sta te_editor_mode
        sta te_mouse_left_latch
        lda #MODE_BASIC
        jsr set_screen_mode
        jsr te_prepare_text_screen
        ldx #<te_msg_save_menu_title
        ldy #>te_msg_save_menu_title
        jsr te_print_string
        ldx #<te_msg_save_menu
        ldy #>te_msg_save_menu
        jsr te_print_string
_te_sfts_menu_wait:
        jsr te_get_key
        cmp #'1'
        beq te_save_tiles_from_text_screen
        cmp #'2'
        beq te_save_palette_from_text_screen
        cmp #'3'
        beq te_export_asm_from_text_screen
        cmp #'4'
        beq te_export_palette_asm_from_text_screen
        cmp #'5'
        beq _te_sfts_return_editor
        cmp #'6'
        beq _te_sfts_exit_basic
        bra _te_sfts_menu_wait
_te_sfts_return_editor:
        jmp te_resume_editor
_te_sfts_exit_basic:
        lda #1
        sta te_quit
        lda #0
        sta SPRITE_ENABLE
        rts

te_save_tiles_from_text_screen:
        jsr te_prepare_text_screen
        ldx #<te_msg_save_title
        ldy #>te_msg_save_title
        jsr te_print_string
_te_sfts_prompt:
        jsr te_prompt_save_filename
        lda te_filename_len
        bne +
        jsr te_set_default_filename
+       jsr te_prompt_char_range
        jsr te_file_exists_tileset
        bcs _te_sfts_save
        jsr te_confirm_replace
        bcc _te_sfts_save
        ldx #<te_msg_choose_new_filename
        ldy #>te_msg_choose_new_filename
        jsr te_print_string
        bra _te_sfts_prompt
_te_sfts_save:
        jsr te_save_tileset_to_disk
        bcs _te_sfts_fail
        ldx #<te_msg_saved
        ldy #>te_msg_saved
        jsr te_print_string
        bra _te_sfts_wait
_te_sfts_fail:
        ldx #<te_msg_save_fail
        ldy #>te_msg_save_fail
        jsr te_print_string
_te_sfts_wait:
        jsr te_get_key
        jmp te_resume_editor

te_save_palette_from_text_screen:
        jsr te_prepare_text_screen
        ldx #<te_msg_save_palette_title
        ldy #>te_msg_save_palette_title
        jsr te_print_string
_te_spfts_prompt:
        jsr te_prompt_save_palette_filename
        lda te_palette_filename_len
        bne +
        jsr te_set_default_palette_filename
+       jsr te_prompt_palette_range
        jsr te_file_exists_palette
        bcs _te_spfts_save
        jsr te_confirm_replace
        bcc _te_spfts_save
        ldx #<te_msg_choose_new_filename
        ldy #>te_msg_choose_new_filename
        jsr te_print_string
        bra _te_spfts_prompt
_te_spfts_save:
        jsr te_save_palette_to_disk
        bcs _te_spfts_fail
        ldx #<te_msg_palette_saved
        ldy #>te_msg_palette_saved
        jsr te_print_string
        bra _te_spfts_wait
_te_spfts_fail:
        ldx #<te_msg_palette_save_fail
        ldy #>te_msg_palette_save_fail
        jsr te_print_string
_te_spfts_wait:
        jsr te_get_key
        jmp te_resume_editor

te_export_asm_from_text_screen:
        jsr te_prepare_text_screen
        ldx #<te_msg_export_title
        ldy #>te_msg_export_title
        jsr te_print_string
_te_eafts_prompt:
        jsr te_prompt_save_export_filename
        lda te_export_filename_len
        bne +
        jsr te_set_default_export_filename
+       jsr te_prompt_char_range
        jsr te_file_exists_export
        bcs _te_eafts_save
        jsr te_confirm_replace
        bcc _te_eafts_save
        ldx #<te_msg_choose_new_filename
        ldy #>te_msg_choose_new_filename
        jsr te_print_string
        bra _te_eafts_prompt
_te_eafts_save:
        jsr te_save_asm_to_disk
        bcs _te_eafts_fail
        ldx #<te_msg_export_saved
        ldy #>te_msg_export_saved
        jsr te_print_string
        bra _te_eafts_wait
_te_eafts_fail:
        ldx #<te_msg_export_save_fail
        ldy #>te_msg_export_save_fail
        jsr te_print_string
_te_eafts_wait:
        jsr te_get_key
        jmp te_resume_editor

te_export_palette_asm_from_text_screen:
        jsr te_prepare_text_screen
        ldx #<te_msg_export_palette_title
        ldy #>te_msg_export_palette_title
        jsr te_print_string
_te_epafts_prompt:
        jsr te_prompt_save_export_filename
        lda te_export_filename_len
        bne +
        jsr te_set_default_export_filename
+       jsr te_prompt_palette_range
        jsr te_file_exists_export
        bcs _te_epafts_save
        jsr te_confirm_replace
        bcc _te_epafts_save
        ldx #<te_msg_choose_new_filename
        ldy #>te_msg_choose_new_filename
        jsr te_print_string
        bra _te_epafts_prompt
_te_epafts_save:
        jsr te_save_palette_asm_to_disk
        bcs _te_epafts_fail
        ldx #<te_msg_palette_export_saved
        ldy #>te_msg_palette_export_saved
        jsr te_print_string
        bra _te_epafts_wait
_te_epafts_fail:
        ldx #<te_msg_palette_export_save_fail
        ldy #>te_msg_palette_export_save_fail
        jsr te_print_string
_te_epafts_wait:
        jsr te_get_key
        jmp te_resume_editor

te_prepare_text_screen:
        jsr restore_default_screen
        lda #$0E                    ; CHR$(14): PETSCII upper/lower text charset.
        jsr KERNAL_CHROUT
        lda #$93                    ; Clear screen after charset switch.
        jsr KERNAL_CHROUT
        jsr te_read_text_screen_base
        jsr te_clear_text_screen_direct
        rts

te_draw_start_menu:
        #TEXT_AT 1, 8, te_start_title
        #TEXT_AT 2, 8, te_start_rule

        #TEXT_AT 4, 4, te_start_new
        #TEXT_AT 5, 7, te_start_new_help
        #TEXT_AT 7, 4, te_start_load_tiles
        #TEXT_AT 8, 7, te_start_load_tiles_help
        #TEXT_AT 10, 4, te_start_load_palette
        #TEXT_AT 11, 7, te_start_load_palette_help
        #TEXT_AT 13, 4, te_start_enter
        #TEXT_AT 14, 7, te_start_enter_help

        #TEXT_AT 17, 4, te_start_controls
        #TEXT_AT 18, 7, te_start_mouse
        #TEXT_AT 19, 7, te_start_cursor
        #TEXT_AT 20, 7, te_start_shift_s
        #TEXT_AT 23, 4, te_start_select
        rts

te_clear_text_screen_direct:
        lda te_text_screen_lo
        sta PTR
        lda te_text_screen_hi
        sta PTR+1
        ldx #7
_te_ctsd_page:
        ldy #0
        lda #$20
_te_ctsd_page_loop:
        sta (PTR),y
        iny
        bne _te_ctsd_page_loop
        inc PTR+1
        dex
        bne _te_ctsd_page

        ldy #0
        lda #$20
_te_ctsd_tail:
        cpy #$D0
        bcs _te_ctsd_done
        sta (PTR),y
        iny
        bra _te_ctsd_tail
_te_ctsd_done:
        rts

te_read_text_screen_base:
        lda VIC4_SCRNPTRLSB
        sta te_text_screen_lo
        lda VIC4_SCRNPTRMSB
        sta te_text_screen_hi
        lda VIC4_SCRBPTRBNK
        sta te_text_screen_bank
        lda VIC4_SCRNPTRMB
        and #$0F
        sta te_text_screen_mb
        rts

te_set_text_cursor_direct:
        sta te_text_row
        stx te_text_col
        lda te_text_screen_lo
        sta PTR
        lda te_text_screen_hi
        sta PTR+1
        lda te_text_row
        beq _te_stcd_add_col
        tax
_te_stcd_row_loop:
        clc
        lda PTR
        adc #80
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        dex
        bne _te_stcd_row_loop
_te_stcd_add_col:
        clc
        lda PTR
        adc te_text_col
        sta PTR
        lda PTR+1
        adc #0
        sta PTR+1
        rts

te_print_direct_string:
        stx PTR2
        sty PTR2+1
        ldy #0
_te_pds_loop:
        lda (PTR2),y
        beq _te_pds_done
        jsr te_screen_code_from_petscii
        sta (PTR),y
        iny
        bne _te_pds_loop
_te_pds_done:
        rts

te_screen_code_from_petscii:
        cmp #$C1
        bcc _te_scfp_ascii
        cmp #$DB
        bcs _te_scfp_ascii
        sec
        sbc #$C0
        rts
_te_scfp_ascii:
        cmp #$41
        bcc _te_scfp_done
        cmp #$5B
        bcs _te_scfp_done
        sec
        sbc #$40
_te_scfp_done:
        rts

te_load_tileset_from_disk:
        lda #TILESET_STAGE_BANK
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda te_filename_len
        ldx #<te_filename_buf
        ldy #>te_filename_buf
        jsr KERNAL_SETNAM
        lda #$40
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcs _te_ltf_fail
        stx te_load_end
        sty te_load_end+1

        sec
        lda te_load_end
        sbc #<(TILESET_STAGE_ADDR + 2)
        sta te_load_size
        lda te_load_end+1
        sbc #>(TILESET_STAGE_ADDR + 2)
        bcc _te_ltf_fail
        sta te_load_size+1

        lda te_load_size+1
        cmp #>TE_TILESET_LOAD_SIZE
        bcc _te_ltf_copy
        bne _te_ltf_clamp
        lda te_load_size
        cmp #<TE_TILESET_LOAD_SIZE
        bcc _te_ltf_copy
_te_ltf_clamp:
        lda #<TE_TILESET_LOAD_SIZE
        sta te_load_size
        lda #>TE_TILESET_LOAD_SIZE
        sta te_load_size+1
_te_ltf_copy:
        lda te_load_size
        ora te_load_size+1
        beq _te_ltf_fail
        jsr te_clear_editable_charset
        jsr te_dma_stage_to_charset
        clc
        rts
_te_ltf_fail:
        sec
        rts

te_load_palette_from_disk:
        lda #TILESET_STAGE_BANK
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda te_palette_filename_len
        ldx #<te_palette_filename_buf
        ldy #>te_palette_filename_buf
        jsr KERNAL_SETNAM
        lda #$40
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcs _te_lpf_fail
        stx te_load_end
        sty te_load_end+1

        sec
        lda te_load_end
        sbc #<(TILESET_STAGE_ADDR + 2)
        sta te_load_size
        lda te_load_end+1
        sbc #>(TILESET_STAGE_ADDR + 2)
        bcc _te_lpf_fail
        sta te_load_size+1

        lda te_load_size+1
        cmp #>TE_PALETTE_FILE_SIZE
        bcc _te_lpf_fail
        bne _te_lpf_copy
        lda te_load_size
        cmp #<TE_PALETTE_FILE_SIZE
        bcc _te_lpf_fail
_te_lpf_copy:
        jsr te_dma_stage_to_palette_shadow
        jsr te_apply_palette_shadow
        lda #1
        sta te_palette_loaded
        clc
        rts
_te_lpf_fail:
        sec
        rts

te_dma_stage_to_charset:
        lda te_load_size
        sta _te_dsc_count
        lda te_load_size+1
        sta _te_dsc_count+1
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $00
_te_dsc_count:
        .word 0
        .word TILESET_STAGE_ADDR + 2
        .byte TILESET_STAGE_BANK
        .word $0000
        .byte `CHAR_DATA
        .byte $00
        .word $0000
        rts

te_dma_stage_to_palette_shadow:
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $00
        .word TE_PALETTE_FILE_SIZE
        .word TILESET_STAGE_ADDR + 2
        .byte TILESET_STAGE_BANK
        .word te_palette_red
        .byte $00
        .byte $00
        .word $0000
        rts

te_prepare_tile_save_range:
        lda te_export_start
        sta te_save_chunk_src
        lda te_export_start+1
        sta te_save_chunk_src+1
        ldx #6
_te_pts_start_shift:
        asl te_save_chunk_src
        rol te_save_chunk_src+1
        dex
        bne _te_pts_start_shift

        sec
        lda te_export_end
        sbc te_export_start
        sta te_save_remaining
        lda te_export_end+1
        sbc te_export_start+1
        sta te_save_remaining+1
        inc te_save_remaining
        bne _te_pts_count_ready
        inc te_save_remaining+1
_te_pts_count_ready:
        ldx #6
_te_pts_count_shift:
        asl te_save_remaining
        rol te_save_remaining+1
        dex
        bne _te_pts_count_shift
        rts

te_save_tileset_to_disk:
        lda te_filename_len
        bne +
        jsr te_set_default_filename
+       jsr te_scratch_tileset

        lda #1
        ldx #8
        ldy #1
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        jsr te_build_save_name
        lda te_save_len
        ldx #<te_save_buf
        ldy #>te_save_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _te_std_fail

        ldx #1
        jsr KERNAL_CHKOUT
        bcs _te_std_close_fail

        ; PRG load address header. The tile editor skips these two bytes on load.
        lda #$00
        jsr KERNAL_CHROUT
        lda #$00
        jsr KERNAL_CHROUT

        jsr te_prepare_tile_save_range
_te_std_loop:
        lda te_save_remaining
        ora te_save_remaining+1
        beq _te_std_close_ok

        lda te_save_remaining+1
        beq _te_std_partial
        lda #0
        sta te_save_chunk_size_lo
        lda #1
        sta te_save_chunk_size_hi
        bra _te_std_dma
_te_std_partial:
        lda te_save_remaining
        sta te_save_chunk_size_lo
        lda #0
        sta te_save_chunk_size_hi

_te_std_dma:
        lda te_save_chunk_size_lo
        sta te_save_dma_size
        lda te_save_chunk_size_hi
        sta te_save_dma_size+1
        lda te_save_chunk_src
        sta te_save_dma_src
        lda te_save_chunk_src+1
        sta te_save_dma_src+1
        jsr te_save_dma_run

        ldx #0
        lda te_save_chunk_size_hi
        bne _te_std_write_full
_te_std_write_short:
        lda te_save_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        cpx te_save_chunk_size_lo
        bne _te_std_write_short
        bra _te_std_advance
_te_std_write_full:
        lda te_save_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        bne _te_std_write_full

_te_std_advance:
        clc
        lda te_save_chunk_src
        adc te_save_chunk_size_lo
        sta te_save_chunk_src
        lda te_save_chunk_src+1
        adc te_save_chunk_size_hi
        sta te_save_chunk_src+1

        sec
        lda te_save_remaining
        sbc te_save_chunk_size_lo
        sta te_save_remaining
        lda te_save_remaining+1
        sbc te_save_chunk_size_hi
        sta te_save_remaining+1
        bra _te_std_loop

_te_std_close_ok:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        clc
        rts

_te_std_close_fail:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_te_std_fail:
        sec
        rts

te_save_palette_to_disk:
        jsr te_scratch_palette

        lda #1
        ldx #8
        ldy #1
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        jsr te_build_palette_save_name
        lda te_save_len
        ldx #<te_save_buf
        ldy #>te_save_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _te_spd_fail

        ldx #1
        jsr KERNAL_CHKOUT
        bcs _te_spd_close_fail

        ; PRG-style dummy header so the game loader can KERNAL_LOAD later and
        ; copy the 768-byte palette body from +2, just like tile data.
        lda #$00
        jsr KERNAL_CHROUT
        lda #$00
        jsr KERNAL_CHROUT

        lda te_palette_range_start
        sta te_i
_te_spd_red_loop:
        ldx te_i
        lda te_palette_red,x
        jsr KERNAL_CHROUT
        lda te_i
        cmp te_palette_range_end
        beq _te_spd_green_start
        inc te_i
        bra _te_spd_red_loop

_te_spd_green_start:
        lda te_palette_range_start
        sta te_i
_te_spd_green_loop:
        ldx te_i
        lda te_palette_green,x
        jsr KERNAL_CHROUT
        lda te_i
        cmp te_palette_range_end
        beq _te_spd_blue_start
        inc te_i
        bra _te_spd_green_loop

_te_spd_blue_start:
        lda te_palette_range_start
        sta te_i
_te_spd_blue_loop:
        ldx te_i
        lda te_palette_blue,x
        jsr KERNAL_CHROUT
        lda te_i
        cmp te_palette_range_end
        beq _te_spd_close_ok
        inc te_i
        bra _te_spd_blue_loop

_te_spd_close_ok:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        clc
        rts

_te_spd_close_fail:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_te_spd_fail:
        sec
        rts

te_save_asm_to_disk:
        jsr te_scratch_export

        lda #1
        ldx #8
        ldy #2
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        jsr te_build_export_save_name
        lda te_save_len
        ldx #<te_save_buf
        ldy #>te_save_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _te_satd_fail

        ldx #1
        jsr KERNAL_CHKOUT
        bcs _te_satd_close_fail

        lda te_export_start
        sta te_export_current
        lda te_export_start+1
        sta te_export_current+1
_te_satd_char_loop:
        lda te_export_current
        ldx te_export_current+1
        jsr te_prepare_char_ptr16

        lda #0
        sta te_export_offset
        sta te_export_row
_te_satd_row_loop:
        ldx #<te_msg_asm_byte
        ldy #>te_msg_asm_byte
        jsr te_print_string

        lda #0
        sta te_export_col
_te_satd_col_loop:
        lda te_export_offset
        taz
        lda [PTR],z
        jsr te_output_hex_byte

        inc te_export_offset
        inc te_export_col
        lda te_export_col
        cmp #8
        beq _te_satd_row_done
        ldx #<te_msg_comma_space
        ldy #>te_msg_comma_space
        jsr te_print_string
        bra _te_satd_col_loop

_te_satd_row_done:
        jsr te_output_cr
        inc te_export_row
        lda te_export_row
        cmp #8
        bne _te_satd_row_loop
        jsr te_output_cr

        lda te_export_current
        cmp te_export_end
        bne _te_satd_next_char
        lda te_export_current+1
        cmp te_export_end+1
        beq _te_satd_close_ok
_te_satd_next_char:
        inc te_export_current
        bne _te_satd_char_loop
        inc te_export_current+1
        bra _te_satd_char_loop

_te_satd_close_ok:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        clc
        rts

_te_satd_close_fail:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_te_satd_fail:
        sec
        rts

te_save_palette_asm_to_disk:
        jsr te_scratch_export

        lda #1
        ldx #8
        ldy #2
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        jsr te_build_export_save_name
        lda te_save_len
        ldx #<te_save_buf
        ldy #>te_save_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _te_spatd_fail

        ldx #1
        jsr KERNAL_CHKOUT
        bcs _te_spatd_close_fail

        lda te_palette_range_start
        sta te_palette_current
_te_spatd_loop:
        ldx #<te_msg_asm_byte
        ldy #>te_msg_asm_byte
        jsr te_print_string

        ldx te_palette_current
        lda te_palette_red,x
        jsr te_output_hex_byte
        ldx #<te_msg_comma_space
        ldy #>te_msg_comma_space
        jsr te_print_string

        ldx te_palette_current
        lda te_palette_green,x
        jsr te_output_hex_byte
        ldx #<te_msg_comma_space
        ldy #>te_msg_comma_space
        jsr te_print_string

        ldx te_palette_current
        lda te_palette_blue,x
        jsr te_output_hex_byte
        jsr te_output_cr

        lda te_palette_current
        cmp te_palette_range_end
        beq _te_spatd_close_ok
        inc te_palette_current
        bra _te_spatd_loop

_te_spatd_close_ok:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        clc
        rts

_te_spatd_close_fail:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_te_spatd_fail:
        sec
        rts

te_output_hex_byte:
        pha
        lda #'$'
        jsr KERNAL_CHROUT
        pla
        pha
        lsr
        lsr
        lsr
        lsr
        jsr te_output_hex_nibble
        pla
        and #$0F
        jmp te_output_hex_nibble

te_output_hex_nibble:
        tax
        lda te_hex_ascii_chars,x
        jmp KERNAL_CHROUT

te_output_cr:
        lda #$0D
        jmp KERNAL_CHROUT

te_scratch_tileset:
        jsr te_build_scratch_name

        lda #15
        ldx #8
        ldy #15
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        lda te_scratch_len
        ldx #<te_scratch_buf
        ldy #>te_scratch_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        rts

te_build_scratch_name:
        lda #$53
        sta te_scratch_buf
        lda #':'
        sta te_scratch_buf+1
        ldx #0
_te_bsn_copy:
        cpx te_filename_len
        bcs _te_bsn_done
        lda te_filename_buf,x
        sta te_scratch_buf+2,x
        inx
        bra _te_bsn_copy
_te_bsn_done:
        txa
        clc
        adc #2
        sta te_scratch_len
        rts

te_scratch_palette:
        jsr te_build_palette_scratch_name

        lda #15
        ldx #8
        ldy #15
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        lda te_scratch_len
        ldx #<te_scratch_buf
        ldy #>te_scratch_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        rts

te_scratch_export:
        jsr te_build_export_scratch_name

        lda #15
        ldx #8
        ldy #15
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        lda te_scratch_len
        ldx #<te_scratch_buf
        ldy #>te_scratch_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        rts

te_file_exists_tileset:
        jsr te_build_exists_command_tileset
        jmp te_file_exists_from_command

te_file_exists_palette:
        jsr te_build_exists_command_palette
        jmp te_file_exists_from_command

te_file_exists_export:
        jsr te_build_exists_command_export
        jmp te_file_exists_from_command

te_file_exists_from_command:
        lda #15
        ldx #8
        ldy #15
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        lda te_command_len
        ldx #<te_command_buf
        ldy #>te_command_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _te_fefc_missing

        lda #15
        jsr KERNAL_CHKIN
        bcs _te_fefc_close_missing
        jsr KERNAL_CHRIN
        sta te_disk_status_0
        jsr KERNAL_CHRIN
        sta te_disk_status_1
        jsr KERNAL_CLRCHN

        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN

        lda te_disk_status_0
        cmp #'0'
        bne _te_fefc_check_file_exists
        lda te_disk_status_1
        cmp #'0'
        bne _te_fefc_missing_done
        clc
        rts
_te_fefc_check_file_exists:
        lda te_disk_status_0
        cmp #'6'
        bne _te_fefc_missing_done
        lda te_disk_status_1
        cmp #'3'
        bne _te_fefc_missing_done
        clc
        rts

_te_fefc_close_missing:
        jsr KERNAL_CLRCHN
        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        bra _te_fefc_missing_done
_te_fefc_missing:
        lda #15
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_te_fefc_missing_done:
        sec
        rts

te_build_exists_command_tileset:
        lda #$52
        sta te_command_buf
        lda #':'
        sta te_command_buf+1
        ldx #0
_te_bect_copy_old:
        cpx te_filename_len
        bcs _te_bect_equals
        lda te_filename_buf,x
        sta te_command_buf+2,x
        inx
        bra _te_bect_copy_old
_te_bect_equals:
        lda #'='
        sta te_command_buf+2,x
        inx
        ldy #0
_te_bect_copy_new:
        cpy te_filename_len
        bcs _te_bect_done
        lda te_filename_buf,y
        sta te_command_buf+2,x
        inx
        iny
        bra _te_bect_copy_new
_te_bect_done:
        txa
        clc
        adc #2
        sta te_command_len
        rts

te_build_exists_command_palette:
        lda #$52
        sta te_command_buf
        lda #':'
        sta te_command_buf+1
        ldx #0
_te_becp_copy_old:
        cpx te_palette_filename_len
        bcs _te_becp_equals
        lda te_palette_filename_buf,x
        sta te_command_buf+2,x
        inx
        bra _te_becp_copy_old
_te_becp_equals:
        lda #'='
        sta te_command_buf+2,x
        inx
        ldy #0
_te_becp_copy_new:
        cpy te_palette_filename_len
        bcs _te_becp_done
        lda te_palette_filename_buf,y
        sta te_command_buf+2,x
        inx
        iny
        bra _te_becp_copy_new
_te_becp_done:
        txa
        clc
        adc #2
        sta te_command_len
        rts

te_build_exists_command_export:
        lda #$52
        sta te_command_buf
        lda #':'
        sta te_command_buf+1
        ldx #0
_te_bece_copy_old:
        cpx te_export_filename_len
        bcs _te_bece_equals
        lda te_export_filename_buf,x
        sta te_command_buf+2,x
        inx
        bra _te_bece_copy_old
_te_bece_equals:
        lda #'='
        sta te_command_buf+2,x
        inx
        ldy #0
_te_bece_copy_new:
        cpy te_export_filename_len
        bcs _te_bece_done
        lda te_export_filename_buf,y
        sta te_command_buf+2,x
        inx
        iny
        bra _te_bece_copy_new
_te_bece_done:
        txa
        clc
        adc #2
        sta te_command_len
        rts

te_confirm_replace:
        ldx #<te_msg_replace_prompt
        ldy #>te_msg_replace_prompt
        jsr te_print_string
_te_cr_wait:
        jsr te_get_key
        cmp #'Y'
        beq _te_cr_yes
        cmp #'y'
        beq _te_cr_yes
        cmp #'N'
        beq _te_cr_no
        cmp #'n'
        beq _te_cr_no
        bra _te_cr_wait
_te_cr_yes:
        lda #$0D
        jsr KERNAL_CHROUT
        clc
        rts
_te_cr_no:
        lda #$0D
        jsr KERNAL_CHROUT
        sec
        rts

te_prompt_char_range:
        ldx #<te_msg_char_start
        ldy #>te_msg_char_start
        jsr te_print_string
        jsr te_prompt_hex_word
        lda te_range_value
        sta te_export_start
        lda te_range_value+1
        sta te_export_start+1

        ldx #<te_msg_char_end
        ldy #>te_msg_char_end
        jsr te_print_string
        jsr te_prompt_hex_word
        lda te_range_value
        sta te_export_end
        lda te_range_value+1
        sta te_export_end+1
        jmp te_clamp_export_range

te_prompt_export_range:
        jmp te_prompt_char_range

te_prompt_palette_range:
        ldx #<te_msg_palette_start
        ldy #>te_msg_palette_start
        jsr te_print_string
        jsr te_prompt_hex_word
        jsr te_clamp_range_value_to_palette
        lda te_range_value
        sta te_palette_range_start

        ldx #<te_msg_palette_end
        ldy #>te_msg_palette_end
        jsr te_print_string
        jsr te_prompt_hex_word
        jsr te_clamp_range_value_to_palette
        lda te_range_value
        sta te_palette_range_end
        jmp te_clamp_palette_range

te_prompt_hex_word:
        lda #0
        sta te_range_input_len
        jsr te_input_cursor_show
_te_phw_read:
        jsr te_get_key
        cmp #$0D
        beq _te_phw_done
        cmp #$14
        beq _te_phw_backspace
        cmp #$08
        beq _te_phw_backspace
        jsr te_is_cursor_key
        bcs _te_phw_read
        jsr te_hex_ascii_to_nibble
        bcs _te_phw_read
        ldx te_range_input_len
        cpx #4
        bcs _te_phw_read
        lda te_key
        sta te_range_input_buf,x
        inc te_range_input_len
        jsr te_input_cursor_hide
        lda te_key
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra _te_phw_read
_te_phw_backspace:
        lda te_range_input_len
        beq _te_phw_read
        jsr te_input_cursor_hide
        dec te_range_input_len
        lda #$14
        jsr KERNAL_CHROUT
        jsr te_input_cursor_show
        bra _te_phw_read
_te_phw_done:
        jsr te_input_cursor_hide
        lda #$0D
        jsr KERNAL_CHROUT
        lda #0
        sta te_range_value
        sta te_range_value+1
        ldx #0
_te_phw_parse:
        cpx te_range_input_len
        bcs _te_phw_parsed
        lda te_range_input_buf,x
        jsr te_hex_ascii_to_nibble
        asl te_range_value
        rol te_range_value+1
        asl te_range_value
        rol te_range_value+1
        asl te_range_value
        rol te_range_value+1
        asl te_range_value
        rol te_range_value+1
        lda te_range_value
        ora te_hex_nibble
        sta te_range_value
        inx
        bra _te_phw_parse
_te_phw_parsed:
        rts

te_hex_ascii_to_nibble:
        sta te_key
        cmp #'0'
        bcc _te_hatn_bad
        cmp #'9' + 1
        bcc _te_hatn_digit
        cmp #'A'
        bcc _te_hatn_check_lower
        cmp #'F' + 1
        bcc _te_hatn_upper
_te_hatn_check_lower:
        cmp #'a'
        bcc _te_hatn_bad
        cmp #'f' + 1
        bcs _te_hatn_bad
        sec
        sbc #'a' - 10
        sta te_hex_nibble
        clc
        rts
_te_hatn_upper:
        sec
        sbc #'A' - 10
        sta te_hex_nibble
        clc
        rts
_te_hatn_digit:
        sec
        sbc #'0'
        sta te_hex_nibble
        clc
        rts
_te_hatn_bad:
        sec
        rts

te_clamp_export_range:
        lda te_export_start+1
        cmp #>TE_EXPORT_MAX_CHAR
        bcc _te_cer_start_ok
        bne _te_cer_start_max
        lda te_export_start
        cmp #<TE_EXPORT_MAX_CHAR
        bcc _te_cer_start_ok
        beq _te_cer_start_ok
_te_cer_start_max:
        lda #<TE_EXPORT_MAX_CHAR
        sta te_export_start
        lda #>TE_EXPORT_MAX_CHAR
        sta te_export_start+1
_te_cer_start_ok:
        lda te_export_end+1
        cmp #>TE_EXPORT_MAX_CHAR
        bcc _te_cer_end_max_ok
        bne _te_cer_end_max
        lda te_export_end
        cmp #<TE_EXPORT_MAX_CHAR
        bcc _te_cer_end_max_ok
        beq _te_cer_end_max_ok
_te_cer_end_max:
        lda #<TE_EXPORT_MAX_CHAR
        sta te_export_end
        lda #>TE_EXPORT_MAX_CHAR
        sta te_export_end+1
_te_cer_end_max_ok:
        lda te_export_end+1
        cmp te_export_start+1
        bcc _te_cer_end_to_start
        bne _te_cer_done
        lda te_export_end
        cmp te_export_start
        bcs _te_cer_done
_te_cer_end_to_start:
        lda te_export_start
        sta te_export_end
        lda te_export_start+1
        sta te_export_end+1
_te_cer_done:
        rts

te_clamp_palette_range:
        lda te_palette_range_end
        cmp te_palette_range_start
        bcs _te_cpr_done
        lda te_palette_range_start
        sta te_palette_range_end
_te_cpr_done:
        rts

te_clamp_range_value_to_palette:
        lda te_range_value+1
        beq _te_crvtp_done
        lda #$FF
        sta te_range_value
        lda #0
        sta te_range_value+1
_te_crvtp_done:
        rts

te_build_palette_scratch_name:
        lda #$53
        sta te_scratch_buf
        lda #':'
        sta te_scratch_buf+1
        ldx #0
_te_bpsn_copy:
        cpx te_palette_filename_len
        bcs _te_bpsn_done
        lda te_palette_filename_buf,x
        sta te_scratch_buf+2,x
        inx
        bra _te_bpsn_copy
_te_bpsn_done:
        txa
        clc
        adc #2
        sta te_scratch_len
        rts

te_build_export_scratch_name:
        lda #$53
        sta te_scratch_buf
        lda #'0'
        sta te_scratch_buf+1
        lda #':'
        sta te_scratch_buf+2
        ldx #0
_te_besn_copy:
        cpx te_export_filename_len
        bcs _te_besn_done
        lda te_export_filename_buf,x
        sta te_scratch_buf+3,x
        inx
        bra _te_besn_copy
_te_besn_done:
        txa
        clc
        adc #3
        sta te_scratch_len
        rts

te_build_save_name:
        ldx #0
_te_bsv_copy:
        cpx te_filename_len
        bcs _te_bsv_suffix
        lda te_filename_buf,x
        sta te_save_buf,x
        inx
        bra _te_bsv_copy
_te_bsv_suffix:
        lda #','
        sta te_save_buf,x
        inx
        lda #$50
        sta te_save_buf,x
        inx
        lda #','
        sta te_save_buf,x
        inx
        lda #$57
        sta te_save_buf,x
        inx
        stx te_save_len
        rts

te_build_palette_save_name:
        ldx #0
_te_bpsv_copy:
        cpx te_palette_filename_len
        bcs _te_bpsv_suffix
        lda te_palette_filename_buf,x
        sta te_save_buf,x
        inx
        bra _te_bpsv_copy
_te_bpsv_suffix:
        lda #','
        sta te_save_buf,x
        inx
        lda #$50
        sta te_save_buf,x
        inx
        lda #','
        sta te_save_buf,x
        inx
        lda #$57
        sta te_save_buf,x
        inx
        stx te_save_len
        rts

te_build_export_save_name:
        lda #'0'
        sta te_save_buf
        lda #':'
        sta te_save_buf+1
        ldx #0
_te_besv_copy:
        cpx te_export_filename_len
        bcs _te_besv_suffix
        lda te_export_filename_buf,x
        sta te_save_buf+2,x
        inx
        bra _te_besv_copy
_te_besv_suffix:
        lda #','
        sta te_save_buf+2,x
        inx
        lda #$53
        sta te_save_buf+2,x
        inx
        lda #','
        sta te_save_buf+2,x
        inx
        lda #$57
        sta te_save_buf+2,x
        inx
        txa
        clc
        adc #2
        sta te_save_len
        rts

te_save_dma_run:
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $00
te_save_dma_size:
        .word 0
te_save_dma_src:
        .word 0
        .byte `CHAR_DATA
        .word te_save_chunk_buf
        .byte $00
        .byte $00
        .word $0000
        rts

te_set_default_filename:
        ldx #0
_te_sdf_loop:
        lda te_default_filename,x
        beq _te_sdf_done
        sta te_filename_buf,x
        inx
        bra _te_sdf_loop
_te_sdf_done:
        stx te_filename_len
        rts

te_set_default_palette_filename:
        ldx #0
_te_sdpf_loop:
        lda te_default_palette_filename,x
        beq _te_sdpf_done
        sta te_palette_filename_buf,x
        inx
        bra _te_sdpf_loop
_te_sdpf_done:
        stx te_palette_filename_len
        rts

te_set_default_export_filename:
        ldx #0
_te_sdef_loop:
        lda te_default_export_filename,x
        beq _te_sdef_done
        sta te_export_filename_buf,x
        inx
        bra _te_sdef_loop
_te_sdef_done:
        stx te_export_filename_len
        rts

te_clear_editable_charset:
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $03
        .word TE_TILESET_LOAD_SIZE
        .byte $00, $00
        .byte $00
        .word $0000
        .byte `CHAR_DATA
        .byte $00
        .word $0000
        rts

te_msg_title:
        .byte $0D
        .text "        MEGACITY TILE EDITOR"
        .byte $0D
        .text "        --------------------"
        .byte $0D, $0D, 0
te_start_title:
        .text "MEGACITY TILE EDITOR"
        .byte 0
te_start_rule:
        .text "--------------------"
        .byte 0
te_start_new:
        .text "1) NEW TILE SET"
        .byte 0
te_start_new_help:
        .text "START WITH BLANK FCM CHARS."
        .byte 0
te_start_load_tiles:
        .text "2) LOAD TILE SET"
        .byte 0
te_start_load_tiles_help:
        .text "LOAD AN EXISTING DISK FILE."
        .byte 0
te_start_load_palette:
        .text "3) LOAD PALETTE"
        .byte 0
te_start_load_palette_help:
        .text "LOAD PALETTE DATA FIRST."
        .byte 0
te_start_enter:
        .text "4) ENTER EDITOR"
        .byte 0
te_start_enter_help:
        .text "START EDITING WITH LOADED DATA."
        .byte 0
te_start_controls:
        .text "IN EDITOR CONTROLS:"
        .byte 0
te_start_mouse:
        .text "MOUSE PORT 1"
        .byte 0
te_start_cursor:
        .text "CURSOR KEYS TO EXPAND CANVAS"
        .byte 0
te_start_shift_s:
        .text "SHIFT-S FOR SAVE OPTIONS"
        .byte 0
te_start_select:
        .text "SELECT 1-4:"
        .byte 0
te_msg_menu:
        .text "1) NEW TILE SET"
        .byte $0D
        .text "   START WITH BLANK FCM CHARS."
        .byte $0D, $0D
        .text "2) LOAD TILE SET"
        .byte $0D
        .text "   LOAD AN EXISTING DISK FILE."
        .byte $0D, $0D
        .text "3) LOAD PALETTE"
        .byte $0D
        .text "   LOAD PALETTE DATA FIRST."
        .byte $0D, $0D
        .text "4) ENTER EDITOR"
        .byte $0D
        .text "   START EDITING WITH LOADED DATA."
        .byte $0D, $0D
        .text "IN EDITOR CONTROLS:"
        .byte $0D
        .text "  MOUSE PORT 1"
        .byte $0D
        .text "  CURSOR KEYS EXPAND"
        .byte $0D
        .text "  CANVAS SIZE"
        .byte $0D
        .text "  SHIFT-S FOR SAVE OPTIONS"
        .byte $0D, $0D
        .text "SELECT 1-4: "
        .byte 0
te_msg_new_title:
        .text "New Tile Set"
        .byte $0D
        .text "------------"
        .byte $0D, $0D, 0
te_msg_load_tiles_title:
        .text "Load Tileset"
        .byte $0D
        .text "------------"
        .byte $0D, $0D, 0
te_msg_load_palette_title:
        .text "Load Palette"
        .byte $0D
        .text "------------"
        .byte $0D, $0D, 0
te_msg_new:
        .text "New tile set ready."
        .byte $0D
        .text "Press any key."
        .byte $0D, 0
te_msg_filename:
        .text "Filename: "
        .byte 0
te_msg_palette_filename:
        .text "Filename: "
        .byte 0
te_msg_save_title:
        .text "Save Tiles"
        .byte $0D
        .text "----------"
        .byte $0D, $0D, 0
te_msg_save_menu_title:
        .text "Save Options:"
        .byte $0D
        .byte $0D, $0D, 0
te_msg_save_menu:
        .text "1) Save Tiles"
        .byte $0D
        .text "2) Save Palette"
        .byte $0D
        .text "3) Export Tile Data as ASM"
        .byte $0D
        .text "4) Export Palette Data as ASM"
        .byte $0D
        .text "5) Return to Editor"
        .byte $0D
        .text "6) Exit to BASIC"
        .byte $0D, $0D
        .text "Select 1-6: "
        .byte 0
te_msg_save_filename:
        .text "Filename: "
        .byte 0
te_msg_save_palette_filename:
        .text "Filename: "
        .byte 0
te_msg_save_export_filename:
        .text "Filename: "
        .byte 0
te_msg_save_palette_title:
        .text "Save Palette"
        .byte $0D
        .text "------------"
        .byte $0D, $0D, 0
te_msg_export_title:
        .text "Export Tile Data as ASM"
        .byte $0D
        .text "-----------------------"
        .byte $0D, $0D, 0
te_msg_export_palette_title:
        .text "Export Palette Data as ASM"
        .byte $0D
        .text "--------------------------"
        .byte $0D, $0D, 0
te_msg_char_start:
        .text "Start Char Hex: "
        .byte 0
te_msg_char_end:
        .text "End Char Hex: "
        .byte 0
te_msg_export_start:
        .text "Start Char Hex: "
        .byte 0
te_msg_export_end:
        .text "End Char Hex: "
        .byte 0
te_msg_palette_start:
        .text "Start Palette Hex: "
        .byte 0
te_msg_palette_end:
        .text "End Palette Hex: "
        .byte 0
te_msg_replace_prompt:
        .byte $0D
        .text "File exists. Replace (Y/N)? "
        .byte 0
te_msg_choose_new_filename:
        .byte $0D
        .text "Enter a different filename."
        .byte $0D
        .byte 0
te_msg_saved:
        .byte $0D
        .text "Tiles saved. Press any key."
        .byte $0D, 0
te_msg_palette_saved:
        .byte $0D
        .text "Palette saved. Press any key."
        .byte $0D, 0
te_msg_export_saved:
        .byte $0D
        .text "Tile ASM export saved. Press any key."
        .byte $0D, 0
te_msg_palette_export_saved:
        .byte $0D
        .text "Palette ASM export saved. Press any key."
        .byte $0D, 0
te_msg_save_fail:
        .byte $0D
        .text "Save failed. Press any key."
        .byte $0D, 0
te_msg_palette_save_fail:
        .byte $0D
        .text "Palette save failed. Press any key."
        .byte $0D, 0
te_msg_export_save_fail:
        .byte $0D
        .text "Tile ASM export failed. Press any key."
        .byte $0D, 0
te_msg_palette_export_save_fail:
        .byte $0D
        .text "Palette ASM export failed. Press any key."
        .byte $0D, 0
te_msg_asm_byte:
        .text ".byte "
        .byte 0
te_msg_comma_space:
        .text ", "
        .byte 0
te_msg_loaded:
        .byte $0D
        .text "Tiles loaded."
        .byte $0D
        .text "Press any key."
        .byte $0D, 0
te_msg_palette_loaded:
        .byte $0D
        .text "Palette loaded."
        .byte $0D
        .text "Press any key."
        .byte $0D, 0
te_msg_load_fail:
        .byte $0D
        .text "Load failed. Press any key."
        .byte $0D, 0
te_msg_palette_load_fail:
        .byte $0D
        .text "Palette load failed. Press any key."
        .byte $0D, 0

;=======================================================================================
; Entry and loop.
;=======================================================================================

tile_edit_entry:
        cld
        cli
        jsr te_set_default_filename
        jsr te_set_default_palette_filename
        jsr te_set_default_export_filename
        jsr te_clear_editable_charset
        lda #0
        sta te_palette_loaded
        jmp te_text_menu

te_enter_editor:
        jsr te_enable_40mhz
        jsr te_detect_platform

        lda #MODE_FCM40
        jsr set_screen_mode
        jsr init_fcm

        jsr te_apply_editor_palette
        jsr te_build_chars
        jsr te_init_sprites
        jsr mouse_init
        jsr te_center_pointer
        jsr te_init_document
        jsr te_draw_static_ui
        jsr te_draw_palette
        jsr te_draw_browser_controls
        jsr te_draw_browser
        jsr te_load_selected_char_to_grid
        jsr te_draw_grid
        jsr te_select_base_char_as_active
        jsr te_draw_title
        jsr te_position_browser_cursor
        jsr te_position_pointer_sprite

te_loop:
        jsr te_wait_frame
        jsr mouse_poll
        jsr te_handle_mouse
        jsr te_position_pointer_sprite
        jsr te_check_keyboard
        lda te_quit
        beq te_loop

        lda #0
        sta SPRITE_ENABLE
        lda #MODE_BASIC
        jsr set_screen_mode
        rts

te_enable_40mhz:
        lda #65
        sta $00
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #CPU_40MHZ_BIT
        tsb VIC3_CTRL
        lda #$80
        tsb VIC4_HOTREGS
        rts

te_detect_platform:
        lda #0
        sta te_sprite_x_fix
        lda PLATFORM_FLAGS
        and #PLATFORM_REAL_HW_BIT
        beq +
        lda #SPRITE_X_HW_FIX
        sta te_sprite_x_fix
+       rts

te_wait_frame:
        lda VIC_RASTER
_te_wf_wait_bottom:
        cmp #$F0
        bcs _te_wf_wait_top
        lda VIC_RASTER
        jmp _te_wf_wait_bottom
_te_wf_wait_top:
        lda VIC_RASTER
        cmp #$20
        bcs _te_wf_wait_top
        rts

te_check_keyboard:
        lda MEGA_KEYQUEUE
        bne _te_ck_have_key
        jsr KERNAL_GETIN
        beq _te_ck_done
        bra _te_ck_store_key
_te_ck_have_key:
        sta te_key
        lda #0
        sta MEGA_KEYQUEUE
        bra _te_ck_process_key
_te_ck_store_key:
        sta te_key
_te_ck_process_key:
        lda te_editor_mode
        bne _te_ck_palette_mode

        lda te_key
        cmp #'Q'
        beq _te_ck_quit
        cmp #'q'
        beq _te_ck_quit
        cmp #KEY_CRSR_UP
        beq _te_ck_shorter
        cmp #KEY_CRSR_UP_ALT
        beq _te_ck_shorter
        cmp #KEY_CRSR_DOWN
        beq _te_ck_taller
        cmp #KEY_CRSR_RIGHT
        beq _te_ck_wider
        cmp #KEY_CRSR_LEFT
        beq _te_ck_narrower
        cmp #KEY_CRSR_LEFT_ALT
        beq _te_ck_narrower
        cmp #'S'
        beq _te_ck_save
        cmp #'s'
        beq _te_ck_save
_te_ck_done:
        rts
_te_ck_palette_mode:
        lda te_key
        cmp #'Q'
        beq _te_ck_quit
        cmp #'q'
        beq _te_ck_quit
        rts
_te_ck_quit:
        lda #1
        sta te_quit
        rts

_te_ck_wider:
        lda te_grid_w
        cmp #TE_GRID_MAX_W
        bcs _te_ck_done
        clc
        adc #8
        sta te_grid_w
        jmp te_resize_grid

_te_ck_narrower:
        lda te_grid_w
        cmp #TE_GRID_MIN_W
        beq _te_ck_done
        sec
        sbc #8
        sta te_grid_w
        jmp te_resize_grid

_te_ck_taller:
        lda te_grid_h
        cmp #TE_GRID_MAX_H
        bcs _te_ck_done
        clc
        adc #8
        sta te_grid_h
        jmp te_resize_grid

_te_ck_shorter:
        lda te_grid_h
        cmp #TE_GRID_MIN_H
        beq _te_ck_done
        sec
        sbc #8
        sta te_grid_h
        jmp te_resize_grid

_te_ck_save:
        jmp te_save_from_text_screen

;=======================================================================================
; Screen drawing.
;=======================================================================================

te_draw_static_ui:
        lda #<TE_CHAR_PANEL
        sta te_rect_char
        lda #0
        sta te_rect_x
        sta te_rect_y
        lda #VIEW_COLS
        sta te_rect_w
        lda #VIEW_ROWS
        sta te_rect_h
        jsr te_fill_rect

        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #0
        sta te_rect_x
        sta te_rect_y
        lda #VIEW_COLS
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        jsr te_draw_title
        jsr te_draw_size_text
        rts

te_draw_title:
        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #0
        sta te_rect_x
        sta te_rect_y
        lda #17
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        jsr te_draw_edit_word
        ldx #5
        ldy #0
        lda #<TE_TEXT_C
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_H
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_A
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_R
        jsr te_set_editor_char
        ldx #10
        lda #<TE_TEXT_HASH
        jsr te_set_editor_char

        lda te_active_char+1
        lsr
        lsr
        lsr
        lsr
        ldx #11
        ldy #0
        jsr te_draw_hex_digit
        lda te_active_char+1
        and #$0F
        ldx #12
        ldy #0
        jsr te_draw_hex_digit
        lda te_active_char
        lsr
        lsr
        lsr
        lsr
        ldx #13
        ldy #0
        jsr te_draw_hex_digit
        lda te_active_char
        and #$0F
        ldx #14
        ldy #0
        jsr te_draw_hex_digit
        rts

te_draw_edit_word:
        ldx #0
        ldy #0
        lda #<TE_TEXT_E
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_D
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_I
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_T
        jsr te_set_editor_char
        rts

te_draw_size_text:
        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #17
        sta te_rect_x
        lda #0
        sta te_rect_y
        lda #6
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        ldx #17
        ldy #0
        lda te_grid_w
        jsr te_draw_size_number
        ldx te_num_x
        ldy #0
        lda #<TE_TEXT_X
        jsr te_set_editor_char
        inc te_num_x
        ldx te_num_x
        ldy #0
        lda te_grid_h
        jsr te_draw_size_number
        rts

te_draw_hex_digit:
        stx te_num_x
        sty te_num_y
        and #$0F
        tax
        lda te_hex_digit_chars,x
        ldx te_num_x
        ldy te_num_y
        jsr te_set_editor_char
        inc te_num_x
        rts

te_draw_size_number:
        stx te_num_x
        sty te_num_y
        cmp #8
        beq _te_dsn_8
        cmp #16
        beq _te_dsn_16
        cmp #24
        beq _te_dsn_24
        lda #<TE_TEXT_3
        sta te_num_tens
        lda #<TE_TEXT_2
        sta te_num_ones
        bra _te_dsn_draw
_te_dsn_24:
        lda #<TE_TEXT_2
        sta te_num_tens
        lda #<TE_TEXT_4
        sta te_num_ones
        bra _te_dsn_draw
_te_dsn_8:
        lda #<TE_TEXT_8
        sta te_num_ones
        bra _te_dsn_draw_one
_te_dsn_16:
        lda #<TE_TEXT_1
        sta te_num_tens
        lda #<TE_TEXT_6
        sta te_num_ones
_te_dsn_draw:
        ldx te_num_x
        ldy te_num_y
        lda te_num_tens
        jsr te_set_editor_char
        inc te_num_x
_te_dsn_draw_one:
        ldx te_num_x
        ldy te_num_y
        lda te_num_ones
        jsr te_set_editor_char
        inc te_num_x
        rts

te_draw_browser_controls:
        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #TE_BROWSER_CTRL_X
        sta te_rect_x
        lda #TE_BROWSER_CTRL_Y
        sta te_rect_y
        lda #10
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        clc
        lda te_browser_scroll
        adc #1
        sta te_dec_value
        lda te_browser_scroll+1
        adc #0
        sta te_dec_value+1
        ldx #TE_BROWSER_CTRL_X
        ldy #TE_BROWSER_CTRL_Y
        jsr te_draw_decimal

        lda #<TE_TEXT_MINUS
        ldx te_num_x
        ldy #TE_BROWSER_CTRL_Y
        jsr te_set_editor_char
        inc te_num_x

        clc
        lda te_browser_scroll
        adc #<TE_BROWSER_PAGE_STEP
        sta te_dec_value
        lda te_browser_scroll+1
        adc #>TE_BROWSER_PAGE_STEP
        sta te_dec_value+1
        ldx te_num_x
        ldy #TE_BROWSER_CTRL_Y
        jsr te_draw_decimal

        lda #<TE_CHAR_PAGE_UP
        ldx #(TE_BROWSER_CTRL_X + 8)
        ldy #TE_BROWSER_CTRL_Y
        jsr te_set_editor_char
        lda #<TE_CHAR_PAGE_DOWN
        ldx #(TE_BROWSER_CTRL_X + 9)
        ldy #TE_BROWSER_CTRL_Y
        jmp te_set_editor_char

te_draw_decimal:
        stx te_num_x
        sty te_num_y
        lda #0
        sta te_dec_started

        jsr te_dec_digit_1000
        lda te_dec_digit
        beq _te_dd_hundreds
        jsr te_draw_digit
        lda #1
        sta te_dec_started

_te_dd_hundreds:
        jsr te_dec_digit_100
        lda te_dec_digit
        bne _te_dd_draw_hundreds
        lda te_dec_started
        beq _te_dd_tens
        lda #0
_te_dd_draw_hundreds:
        jsr te_draw_digit
        lda #1
        sta te_dec_started

_te_dd_tens:
        jsr te_dec_digit_10
        lda te_dec_digit
        bne _te_dd_draw_tens
        lda te_dec_started
        beq _te_dd_ones
        lda #0
_te_dd_draw_tens:
        jsr te_draw_digit

_te_dd_ones:
        lda te_dec_value
        jmp te_draw_digit

te_dec_digit_1000:
        lda #0
        sta te_dec_digit
_te_dd1000_loop:
        lda te_dec_value+1
        cmp #>1000
        bcc _te_dd1000_done
        bne _te_dd1000_sub
        lda te_dec_value
        cmp #<1000
        bcc _te_dd1000_done
_te_dd1000_sub:
        sec
        lda te_dec_value
        sbc #<1000
        sta te_dec_value
        lda te_dec_value+1
        sbc #>1000
        sta te_dec_value+1
        inc te_dec_digit
        bra _te_dd1000_loop
_te_dd1000_done:
        rts

te_dec_digit_100:
        lda #0
        sta te_dec_digit
_te_dd100_loop:
        lda te_dec_value+1
        bne _te_dd100_sub
        lda te_dec_value
        cmp #100
        bcc _te_dd100_done
_te_dd100_sub:
        sec
        lda te_dec_value
        sbc #100
        sta te_dec_value
        lda te_dec_value+1
        sbc #0
        sta te_dec_value+1
        inc te_dec_digit
        bra _te_dd100_loop
_te_dd100_done:
        rts

te_dec_digit_10:
        lda #0
        sta te_dec_digit
_te_dd10_loop:
        lda te_dec_value+1
        bne _te_dd10_sub
        lda te_dec_value
        cmp #10
        bcc _te_dd10_done
_te_dd10_sub:
        sec
        lda te_dec_value
        sbc #10
        sta te_dec_value
        lda te_dec_value+1
        sbc #0
        sta te_dec_value+1
        inc te_dec_digit
        bra _te_dd10_loop
_te_dd10_done:
        rts

te_draw_digit:
        tax
        lda te_digit_chars,x
        ldx te_num_x
        ldy te_num_y
        jsr te_set_editor_char
        inc te_num_x
        rts

te_draw_palette:
        jsr te_rebuild_palette_chars

        lda #<TE_CHAR_PANEL
        sta te_rect_char
        lda #0
        sta te_rect_x
        lda #TE_PALETTE_BUTTON_Y
        sta te_rect_y
        lda #4
        sta te_rect_w
        lda #(TE_PALETTE_H + 1)
        sta te_rect_h
        jsr te_fill_rect

        lda #<TE_CHAR_PAGE_UP
        ldx #TE_PALETTE_X
        ldy #TE_PALETTE_BUTTON_Y
        jsr te_set_editor_char
        lda #<TE_CHAR_PAGE_DOWN
        ldx #(TE_PALETTE_X + 1)
        ldy #TE_PALETTE_BUTTON_Y
        jsr te_set_editor_char
        jsr te_draw_palette_edit_button

        lda #0
        sta te_i
_te_dp_loop:
        clc
        lda #TE_PALETTE_Y
        adc te_i
        tay

        lda te_selected_color
        cmp te_palette_base
        bcc _te_dp_no_marker
        sec
        sbc te_palette_base
        cmp #16
        bcs _te_dp_no_marker
        cmp te_i
        bne _te_dp_no_marker
        lda #<TE_CHAR_PALETTE_MARKER
        bra _te_dp_have_marker
_te_dp_no_marker:
        lda #<TE_CHAR_PANEL
_te_dp_have_marker:
        ldx #0
        jsr te_set_editor_char

        clc
        lda #<TE_CHAR_SOLID_BASE
        adc te_i
        ldx #TE_PALETTE_X
        jsr te_set_editor_char
        clc
        lda #<TE_CHAR_SOLID_BASE
        adc te_i
        ldx #(TE_PALETTE_X + 1)
        jsr te_set_editor_char

        inc te_i
        lda te_i
        cmp #16
        bne _te_dp_loop

        lda te_selected_color
        jsr te_color_to_palette_slot
        clc
        adc #<TE_CHAR_SOLID_BASE
        ldx #39
        ldy #0
        jsr te_set_editor_char
        rts

te_draw_palette_edit_button:
        lda te_selected_color
        bne _te_dpeb_visible
        lda #<TE_CHAR_PANEL
        sta te_rect_char
        lda #0
        sta te_rect_x
        lda #TE_PALETTE_EDIT_Y
        sta te_rect_y
        lda #4
        sta te_rect_w
        lda #1
        sta te_rect_h
        jmp te_fill_rect

_te_dpeb_visible:
        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #0
        sta te_rect_x
        lda #TE_PALETTE_EDIT_Y
        sta te_rect_y
        lda #4
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        ldx #0
        ldy #TE_PALETTE_EDIT_Y
        lda #<TE_TEXT_E
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_D
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_I
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_T
        jsr te_set_editor_char
        rts

te_rebuild_palette_chars:
        lda #0
        sta te_i
_te_rpc_loop:
        clc
        lda te_palette_base
        adc te_i
        sta te_fill_color

        clc
        lda #<TE_CHAR_SOLID_BASE
        adc te_i
        pha
        lda #>TE_CHAR_SOLID_BASE
        adc #0
        tax
        pla
        jsr te_fill_solid_char16

        inc te_i
        lda te_i
        cmp #16
        bne _te_rpc_loop
        rts

te_build_grid_color_cache:
        lda #0
        sta te_grid_color_count
        sta te_edit_y
_te_bgcc_row:
        lda #0
        sta te_edit_x
_te_bgcc_col:
        jsr te_read_grid_pixel
        jsr te_add_grid_color

        inc te_edit_x
        lda te_edit_x
        cmp te_grid_w
        bne _te_bgcc_col

        inc te_edit_y
        lda te_edit_y
        cmp te_grid_h
        bne _te_bgcc_row

        jmp te_rebuild_grid_chars

te_add_grid_color:
        sta te_grid_color_value
        ldx #0
_te_agc_find:
        cpx te_grid_color_count
        beq _te_agc_add
        lda te_grid_color_cache,x
        cmp te_grid_color_value
        beq _te_agc_done
        inx
        bra _te_agc_find
_te_agc_add:
        lda te_grid_color_count
        cmp #16
        bcs _te_agc_done
        tax
        lda te_grid_color_value
        sta te_grid_color_cache,x
        inc te_grid_color_count
_te_agc_done:
        rts

te_rebuild_grid_chars:
        lda #0
        sta te_i
_te_rgc_loop:
        lda te_i
        cmp te_grid_color_count
        bcs _te_rgc_empty
        tax
        lda te_grid_color_cache,x
        bra _te_rgc_have_color
_te_rgc_empty:
        lda #0
_te_rgc_have_color:
        sta te_fill_color

        clc
        lda #<TE_CHAR_GRID_BASE
        adc te_i
        pha
        lda #>TE_CHAR_GRID_BASE
        adc #0
        tax
        pla
        jsr te_fill_grid_char16

        inc te_i
        lda te_i
        cmp #16
        bne _te_rgc_loop
        rts

te_color_to_palette_slot:
        cmp te_palette_base
        bcc _te_ctps_low_nibble
        sec
        sbc te_palette_base
        cmp #16
        bcc _te_ctps_done
_te_ctps_low_nibble:
        and #$0F
_te_ctps_done:
        rts

te_color_to_grid_slot:
        sta te_grid_color_value
        ldx #0
_te_ctgs_find:
        cpx te_grid_color_count
        beq _te_ctgs_add
        lda te_grid_color_cache,x
        cmp te_grid_color_value
        beq _te_ctgs_found
        inx
        bra _te_ctgs_find
_te_ctgs_found:
        txa
        rts

_te_ctgs_add:
        lda te_grid_color_count
        cmp #16
        bcs _te_ctgs_fallback
        tax
        stx te_grid_color_slot
        lda te_grid_color_value
        sta te_grid_color_cache,x
        inc te_grid_color_count
        sta te_fill_color

        txa
        clc
        adc #<TE_CHAR_GRID_BASE
        pha
        lda #>TE_CHAR_GRID_BASE
        adc #0
        tax
        pla
        jsr te_fill_grid_char16

        lda te_grid_color_slot
        rts

_te_ctgs_fallback:
        lda te_grid_color_value
        and #$0F
        rts

te_draw_browser:
        lda #0
        sta te_browser_index
        lda #TE_BROWSER_Y
        sta te_browser_row
_te_db_row:
        lda #TE_BROWSER_X
        sta te_browser_col
_te_db_col:
        clc
        lda te_browser_scroll
        adc te_browser_index
        sta te_char_lo
        lda te_browser_scroll+1
        adc #0
        sta snc_char_hi

        lda te_char_lo
        ldx te_browser_col
        ldy te_browser_row
        jsr set_fcm_char16

        inc te_browser_col
        inc te_browser_index
        lda te_browser_col
        cmp #(TE_BROWSER_X + TE_BROWSER_W)
        bne _te_db_col

        inc te_browser_row
        lda te_browser_row
        cmp #(TE_BROWSER_Y + TE_BROWSER_H)
        bne _te_db_row
        rts

te_draw_grid:
        lda te_active_char
        sta te_saved_active_char
        lda te_active_char+1
        sta te_saved_active_char+1
        lda #0
        sta te_grid_display_y
_te_dg_row:
        lda #0
        sta te_grid_display_x
_te_dg_col:
        jsr te_display_to_edit_origin
        jsr te_read_grid_pixel
        jsr te_color_to_grid_slot
        clc
        adc #<TE_CHAR_GRID_BASE
        pha
        clc
        lda #TE_GRID_X
        adc te_grid_display_x
        tax
        clc
        lda #TE_GRID_Y
        adc te_grid_display_y
        tay
        pla
        jsr te_set_editor_char

        inc te_grid_display_x
        lda te_grid_display_x
        cmp te_grid_display_w
        bne _te_dg_col

        inc te_grid_display_y
        lda te_grid_display_y
        cmp te_grid_display_h
        bne _te_dg_row
        lda te_saved_active_char
        sta te_active_char
        lda te_saved_active_char+1
        sta te_active_char+1
        rts

te_clear_grid_area:
        lda #<TE_CHAR_PANEL
        sta te_rect_char
        lda #TE_GRID_X
        sta te_rect_x
        lda #TE_GRID_Y
        sta te_rect_y
        lda #TE_GRID_SCREEN_W
        sta te_rect_w
        lda #TE_GRID_SCREEN_H
        sta te_rect_h
        jmp te_fill_rect

te_display_to_edit_origin:
        lda te_grid_display_x
        ldx te_grid_scale_shift
        beq +
        asl
+       sta te_edit_x
        lda te_grid_display_y
        ldx te_grid_scale_shift
        beq +
        asl
+       sta te_edit_y
        rts

te_resize_grid:
        jsr te_recalc_tile_cells
        jsr te_build_grid_color_cache
        jsr te_clear_grid_area
        jsr te_draw_size_text
        jsr te_draw_grid
        jsr te_select_base_char_as_active
        jmp te_draw_title

te_fill_rect:
        lda te_rect_y
        sta te_rect_cur_y
        lda te_rect_h
        sta te_rect_rows_left
_te_fr_row:
        lda te_rect_x
        sta te_rect_cur_x
        lda te_rect_w
        sta te_rect_cols_left
_te_fr_col:
        lda te_rect_char
        ldx te_rect_cur_x
        ldy te_rect_cur_y
        jsr te_set_editor_char
        inc te_rect_cur_x
        dec te_rect_cols_left
        bne _te_fr_col
        inc te_rect_cur_y
        dec te_rect_rows_left
        bne _te_fr_row
        rts

;=======================================================================================
; Mouse hit testing / editing.
;=======================================================================================

te_handle_mouse:
        jsr te_mouse_to_cell
        lda te_editor_mode
        beq _te_hm_tile_mode
        jmp te_handle_palette_editor_mouse

_te_hm_tile_mode:
        jsr te_update_grid_hover_char
        lda mouse_buttons
        and #MOUSE_BUTTON_LEFT
        bne _te_hm_pressed
        lda #0
        sta te_mouse_left_latch
        rts

_te_hm_pressed:
        lda te_mouse_left_latch
        bne _te_hm_drag_paint
        lda #1
        sta te_mouse_left_latch

        jsr te_try_palette_click
        bcs _te_hm_done
        jsr te_try_browser_click
        bcs _te_hm_done
_te_hm_drag_paint:
        jsr te_try_grid_paint
_te_hm_done:
        rts

te_try_palette_click:
        lda te_mouse_cell_y
        cmp #TE_PALETTE_EDIT_Y
        bne _te_tpc_page_buttons
        lda te_mouse_cell_x
        cmp #4
        bcs _te_tpc_no
        lda te_selected_color
        beq _te_tpc_no
        jsr te_enter_palette_editor
        sec
        rts

_te_tpc_page_buttons:
        lda te_mouse_cell_y
        cmp #TE_PALETTE_BUTTON_Y
        bne _te_tpc_swatch
        lda te_mouse_cell_x
        cmp #TE_PALETTE_X
        bne _te_tpc_check_down_button
        jsr te_palette_page_up
        sec
        rts
_te_tpc_check_down_button:
        cmp #(TE_PALETTE_X + 1)
        bne _te_tpc_no
        jsr te_palette_page_down
        sec
        rts

_te_tpc_swatch:
        lda te_mouse_cell_x
        cmp #TE_PALETTE_X
        bcc _te_tpc_no
        cmp #(TE_PALETTE_X + 2)
        bcs _te_tpc_no
        lda te_mouse_cell_y
        cmp #TE_PALETTE_Y
        bcc _te_tpc_no
        cmp #(TE_PALETTE_Y + TE_PALETTE_H)
        bcs _te_tpc_no
        sec
        sbc #TE_PALETTE_Y
        clc
        adc te_palette_base
        sta te_selected_color
        jsr te_draw_palette
        sec
        rts
_te_tpc_no:
        clc
        rts

te_palette_page_up:
        lda te_palette_base
        bne _te_ppu_do
        rts
_te_ppu_do:
        sec
        sbc #TE_PALETTE_PAGE_STEP
        sta te_palette_base
        sta te_selected_color
        jsr te_draw_palette
        jmp te_draw_grid

te_palette_page_down:
        lda te_palette_base
        cmp #TE_PALETTE_MAX_BASE
        bcc _te_ppd_do
        rts
_te_ppd_do:
        clc
        adc #TE_PALETTE_PAGE_STEP
        sta te_palette_base
        sta te_selected_color
        jsr te_draw_palette
        jmp te_draw_grid

te_try_browser_click:
        lda te_mouse_cell_y
        cmp #TE_BROWSER_CTRL_Y
        bne _te_tbc_grid
        lda te_mouse_cell_x
        cmp #(TE_BROWSER_CTRL_X + 8)
        bne _te_tbc_check_down_button
        jsr te_browser_scroll_up
        sec
        rts
_te_tbc_check_down_button:
        cmp #(TE_BROWSER_CTRL_X + 9)
        bne _te_tbc_no
        jsr te_browser_scroll_down
        sec
        rts

_te_tbc_grid:
        lda te_mouse_cell_x
        cmp #TE_BROWSER_X
        bcc _te_tbc_no
        cmp #(TE_BROWSER_X + TE_BROWSER_W)
        bcs _te_tbc_no

        lda te_mouse_cell_y
        cmp #TE_BROWSER_Y
        bcc _te_tbc_no
        cmp #(TE_BROWSER_Y + TE_BROWSER_H)
        bcs _te_tbc_no

        sec
        lda te_mouse_cell_y
        sbc #TE_BROWSER_Y
        sta te_browser_pick_row
        lda te_mouse_cell_x
        sec
        sbc #TE_BROWSER_X
        sta te_browser_pick_col

        lda te_browser_pick_row
        asl
        asl
        asl
        clc
        adc te_browser_pick_col
        clc
        adc te_browser_scroll
        sta te_selected_char
        lda te_browser_scroll+1
        adc #0
        sta te_selected_char+1

        jsr te_load_selected_char_to_grid
        jsr te_draw_grid
        jsr te_select_base_char_as_active
        jsr te_draw_title
        jsr te_position_browser_cursor
        sec
        rts

_te_tbc_no:
        clc
        rts

te_try_grid_paint:
        lda te_mouse_cell_x
        cmp #TE_GRID_X
        bcc _te_tgp_no
        sec
        sbc #TE_GRID_X
        cmp te_grid_display_w
        bcs _te_tgp_no
        sta te_grid_display_x
        lda te_mouse_cell_y
        cmp #TE_GRID_Y
        bcc _te_tgp_no
        sec
        sbc #TE_GRID_Y
        cmp te_grid_display_h
        bcs _te_tgp_no
        sta te_grid_display_y

        jsr te_display_to_edit_origin
        jsr te_draw_one_grid_cell
        jsr te_write_selected_grid_cell
        jsr te_draw_title
        jsr te_position_browser_cursor
        sec
        rts

_te_tgp_no:
        clc
        rts

te_update_grid_hover_char:
        lda te_mouse_cell_x
        cmp #TE_GRID_X
        bcc _te_ughc_done
        sec
        sbc #TE_GRID_X
        cmp te_grid_display_w
        bcs _te_ughc_done
        sta te_grid_display_x
        lda te_mouse_cell_y
        cmp #TE_GRID_Y
        bcc _te_ughc_done
        sec
        sbc #TE_GRID_Y
        cmp te_grid_display_h
        bcs _te_ughc_done
        sta te_grid_display_y

        jsr te_display_to_edit_origin
        jsr te_select_active_char_from_grid
        jsr te_draw_title
        jmp te_position_browser_cursor
_te_ughc_done:
        rts

;=======================================================================================
; Palette editor.
;=======================================================================================

te_enter_palette_editor:
        lda te_selected_color
        bne _te_epe_ok
        rts
_te_epe_ok:
        lda #1
        sta te_editor_mode
        ; Treat the click that opened this screen as already consumed until release.
        lda #1
        sta te_mouse_left_latch
        jsr te_load_palette_rgb
        jsr te_draw_palette_editor_screen
        lda SPRITE_ENABLE
        and #%11111101
        sta SPRITE_ENABLE
        rts

te_exit_palette_editor:
        lda #0
        sta te_editor_mode
        ; Treat the click that closed this screen as already consumed until release.
        lda #1
        sta te_mouse_left_latch
        jsr te_draw_static_ui
        jsr te_draw_palette
        jsr te_draw_browser_controls
        jsr te_draw_browser
        jsr te_draw_grid
        jsr te_position_browser_cursor
        rts

te_handle_palette_editor_mouse:
        lda mouse_buttons
        and #MOUSE_BUTTON_LEFT
        bne _te_hpem_pressed
        lda #0
        sta te_mouse_left_latch
        rts

_te_hpem_pressed:
        lda te_mouse_left_latch
        bne _te_hpem_drag
        lda #1
        sta te_mouse_left_latch

        jsr te_try_palette_editor_button
        bcs _te_hpem_done
_te_hpem_drag:
        jsr te_try_palette_editor_slider
_te_hpem_done:
        rts

te_try_palette_editor_button:
        lda te_mouse_cell_y
        cmp #TE_PAL_EXIT_Y
        bne _te_tpeb_no
        lda te_mouse_cell_x
        cmp #4
        bcs _te_tpeb_no
        jsr te_exit_palette_editor
        sec
        rts
_te_tpeb_no:
        clc
        rts

te_try_palette_editor_slider:
        lda te_mouse_cell_x
        cmp #TE_PAL_SLIDER_X
        bcc _te_tpes_no
        sec
        sbc #TE_PAL_SLIDER_X
        cmp #TE_PAL_SLIDER_W
        bcs _te_tpes_no
        sta te_palette_slider_value

        lda te_mouse_cell_y
        cmp #TE_PAL_R_ROW
        bne _te_tpes_check_g
        lda te_palette_slider_value
        sta te_palette_r
        bra _te_tpes_apply
_te_tpes_check_g:
        cmp #TE_PAL_G_ROW
        bne _te_tpes_check_b
        lda te_palette_slider_value
        sta te_palette_g
        bra _te_tpes_apply
_te_tpes_check_b:
        cmp #TE_PAL_B_ROW
        bne _te_tpes_no
        lda te_palette_slider_value
        sta te_palette_b
_te_tpes_apply:
        jsr te_apply_palette_rgb
        jsr te_draw_palette_editor_screen
        sec
        rts
_te_tpes_no:
        clc
        rts

te_draw_palette_editor_screen:
        jsr te_rebuild_palette_chars

        lda #<TE_CHAR_PANEL
        sta te_rect_char
        lda #0
        sta te_rect_x
        sta te_rect_y
        lda #VIEW_COLS
        sta te_rect_w
        lda #VIEW_ROWS
        sta te_rect_h
        jsr te_fill_rect

        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #0
        sta te_rect_x
        sta te_rect_y
        lda #VIEW_COLS
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        jsr te_draw_edit_word
        jsr te_draw_palette_editor_header
        jsr te_draw_palette_editor_sliders
        jsr te_draw_palette_editor_preview
        jmp te_draw_palette_editor_exit

te_draw_palette_editor_header:
        ldx #5
        ldy #0
        lda #<TE_TEXT_P
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_A
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_L
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_COLON
        jsr te_set_editor_char
        inx
        inx
        lda te_selected_color
        sta te_dec_value
        lda #0
        sta te_dec_value+1
        jmp te_draw_decimal

te_draw_palette_editor_sliders:
        lda te_palette_r
        sta te_palette_slider_value
        lda #<TE_TEXT_R
        ldy #TE_PAL_R_ROW
        jsr te_draw_palette_slider

        lda te_palette_g
        sta te_palette_slider_value
        lda #<TE_TEXT_G
        ldy #TE_PAL_G_ROW
        jsr te_draw_palette_slider

        lda te_palette_b
        sta te_palette_slider_value
        lda #<TE_TEXT_B
        ldy #TE_PAL_B_ROW
        jmp te_draw_palette_slider

te_draw_palette_slider:
        sta te_palette_slider_label
        sty te_palette_slider_row

        ldx #2
        ldy te_palette_slider_row
        lda te_palette_slider_label
        jsr te_set_editor_char

        lda #0
        sta te_i
_te_dps_loop:
        lda te_i
        cmp te_palette_slider_value
        bne _te_dps_bg
        lda #<TE_CHAR_FRAME
        bra _te_dps_have_char
_te_dps_bg:
        lda #<TE_CHAR_TEXT_BG
_te_dps_have_char:
        pha
        clc
        lda #TE_PAL_SLIDER_X
        adc te_i
        tax
        ldy te_palette_slider_row
        pla
        jsr te_set_editor_char

        inc te_i
        lda te_i
        cmp #TE_PAL_SLIDER_W
        bne _te_dps_loop

        lda te_palette_slider_value
        sta te_dec_value
        lda #0
        sta te_dec_value+1
        ldx #TE_PAL_VALUE_X
        ldy te_palette_slider_row
        jmp te_draw_decimal

te_draw_palette_editor_preview:
        lda te_selected_color
        jsr te_color_to_palette_slot
        clc
        adc #<TE_CHAR_SOLID_BASE
        sta te_rect_char
        lda #TE_PAL_PREVIEW_X
        sta te_rect_x
        lda #TE_PAL_PREVIEW_Y
        sta te_rect_y
        lda #TE_PAL_PREVIEW_SIZE
        sta te_rect_w
        sta te_rect_h
        jmp te_fill_rect

te_draw_palette_editor_exit:
        lda #<TE_CHAR_TEXT_BG
        sta te_rect_char
        lda #0
        sta te_rect_x
        lda #TE_PAL_EXIT_Y
        sta te_rect_y
        lda #4
        sta te_rect_w
        lda #1
        sta te_rect_h
        jsr te_fill_rect

        ldx #0
        ldy #TE_PAL_EXIT_Y
        lda #<TE_TEXT_E
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_X
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_I
        jsr te_set_editor_char
        inx
        lda #<TE_TEXT_T
        jsr te_set_editor_char
        rts

te_load_palette_rgb:
        ldx te_selected_color
        lda te_palette_red,x
        and #$0F
        sta te_palette_r
        lda te_palette_green,x
        and #$0F
        sta te_palette_g
        lda te_palette_blue,x
        and #$0F
        sta te_palette_b
        rts

te_apply_palette_rgb:
        lda te_selected_color
        bne _te_apr_not_zero
        jmp te_lock_palette_zero
_te_apr_not_zero:
        ldx te_selected_color
        lda te_palette_r
        jsr te_nibble_to_palette_byte
        sta $D100,x
        sta te_palette_red,x
        lda te_palette_g
        jsr te_nibble_to_palette_byte
        sta $D200,x
        sta te_palette_green,x
        lda te_palette_b
        jsr te_nibble_to_palette_byte
        sta $D300,x
        sta te_palette_blue,x
        rts

te_apply_palette_shadow:
        jsr te_lock_palette_zero
        lda #0
        sta te_i
_te_aps_loop:
        ldx te_i
        lda te_palette_red,x
        sta $D100,x
        lda te_palette_green,x
        sta $D200,x
        lda te_palette_blue,x
        sta $D300,x
        inc te_i
        bne _te_aps_loop
        rts

te_lock_palette_zero:
        lda #0
        sta te_palette_red
        sta te_palette_green
        sta te_palette_blue
        sta $D100
        sta $D200
        sta $D300
        rts

te_nibble_to_palette_byte:
        and #$0F
        sta te_palette_channel_tmp
        asl
        asl
        asl
        asl
        ora te_palette_channel_tmp
        rts

te_draw_one_grid_cell:
        lda te_selected_color
        jsr te_color_to_grid_slot
        clc
        adc #<TE_CHAR_GRID_BASE
        pha
        clc
        lda #TE_GRID_X
        adc te_grid_display_x
        tax
        clc
        lda #TE_GRID_Y
        adc te_grid_display_y
        tay
        pla
        jsr te_set_editor_char
        rts

te_set_editor_char:
        pha
        lda #TE_EDITOR_CHAR_HI
        sta snc_char_hi
        pla
        jmp set_fcm_char16

te_prepare_char_ptr16:
        stx te_fill_char_hi
        sta te_fill_char_lo

        lda te_fill_char_lo
        sta MULTINA
        lda te_fill_char_hi
        sta MULTINA+1
        lda #0
        sta MULTINA+2
        sta MULTINA+3

        lda #64
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3

        clc
        lda MULTOUT
        adc #<CHAR_DATA
        sta PTR
        lda MULTOUT+1
        adc #>CHAR_DATA
        sta PTR+1
        lda MULTOUT+2
        adc #`CHAR_DATA
        sta PTR+2
        lda #0
        sta PTR+3
        rts

te_fill_solid_char16:
        jsr te_prepare_char_ptr16
        ldy #0
_te_fsc_loop:
        tya
        taz
        lda te_fill_color
        sta [PTR],z
        iny
        cpy #64
        bne _te_fsc_loop
        rts

te_fill_grid_char16:
        jsr te_fill_solid_char16

        ldy #0
_te_fgc_top_loop:
        tya
        taz
        lda #$0B
        sta [PTR],z
        iny
        cpy #8
        bne _te_fgc_top_loop

        ldy #8
_te_fgc_left_loop:
        tya
        taz
        lda #$0B
        sta [PTR],z
        tya
        clc
        adc #8
        tay
        cpy #64
        bne _te_fgc_left_loop
        rts

te_mouse_to_cell:
        lda mouse_x+1
        beq _te_mtc_x_low
        cmp #1
        beq _te_mtc_x_high1
        bmi _te_mtc_x_min
        lda #(VIEW_COLS - 1)
        bra _te_mtc_x_store
_te_mtc_x_min:
        lda #0
        bra _te_mtc_x_store
_te_mtc_x_low:
        lda mouse_x
        lsr
        lsr
        lsr
        bra _te_mtc_x_store
_te_mtc_x_high1:
        lda mouse_x
        lsr
        lsr
        lsr
        clc
        adc #32
        cmp #VIEW_COLS
        bcc _te_mtc_x_store
        lda #(VIEW_COLS - 1)
_te_mtc_x_store:
        sta te_mouse_cell_x

        lda mouse_y
        lsr
        lsr
        lsr
        cmp #VIEW_ROWS
        bcc +
        lda #(VIEW_ROWS - 1)
+       sta te_mouse_cell_y
        rts

te_browser_scroll_up:
        lda te_browser_scroll+1
        bne _te_bsu_do
        lda te_browser_scroll
        bne _te_bsu_do
        rts
_te_bsu_do:
        sec
        lda te_browser_scroll
        sbc #<TE_BROWSER_PAGE_STEP
        sta te_browser_scroll
        lda te_browser_scroll+1
        sbc #>TE_BROWSER_PAGE_STEP
        sta te_browser_scroll+1
        bpl _te_bsu_redraw
        lda #0
        sta te_browser_scroll
        sta te_browser_scroll+1
_te_bsu_redraw:
        jsr te_draw_browser_controls
        jsr te_draw_browser
        jmp te_position_browser_cursor

te_browser_scroll_down:
        lda te_browser_scroll+1
        cmp #TE_BROWSER_MAX_HI
        bcc _te_bsd_do
        bne _te_bsd_done
        lda te_browser_scroll
        cmp #TE_BROWSER_MAX_LO
        bcs _te_bsd_done
_te_bsd_do:
        clc
        lda te_browser_scroll
        adc #<TE_BROWSER_PAGE_STEP
        sta te_browser_scroll
        lda te_browser_scroll+1
        adc #>TE_BROWSER_PAGE_STEP
        sta te_browser_scroll+1

        lda te_browser_scroll+1
        cmp #TE_BROWSER_MAX_HI
        bcc _te_bsd_redraw
        bne _te_bsd_clamp
        lda te_browser_scroll
        cmp #TE_BROWSER_MAX_LO
        bcc _te_bsd_redraw
_te_bsd_clamp:
        lda #TE_BROWSER_MAX_LO
        sta te_browser_scroll
        lda #TE_BROWSER_MAX_HI
        sta te_browser_scroll+1
_te_bsd_redraw:
        jsr te_draw_browser_controls
        jsr te_draw_browser
        jmp te_position_browser_cursor
_te_bsd_done:
        rts

;=======================================================================================
; Character RAM import/export for selected multi-cell tile.
;=======================================================================================

te_load_selected_char_to_grid:
        jmp te_resize_grid

te_read_grid_pixel:
        jsr te_select_active_char_from_grid
        jsr te_active_char_ptr
        lda te_char_pixel_offset
        taz
        lda [PTR],z
        rts

te_write_selected_grid_cell:
        lda te_grid_scale_shift
        bne _te_wsg_compact
        jmp te_write_selected_char_pixel

_te_wsg_compact:
        jsr te_write_selected_char_pixel
        inc te_edit_x
        jsr te_write_selected_char_pixel
        dec te_edit_x
        inc te_edit_y
        jsr te_write_selected_char_pixel
        inc te_edit_x
        jsr te_write_selected_char_pixel
        dec te_edit_x
        dec te_edit_y
        rts

te_write_selected_char_pixel:
        jsr te_select_active_char_from_grid
        jsr te_active_char_ptr
        lda te_char_pixel_offset
        taz
        lda te_selected_color
        sta [PTR],z
        rts

te_select_base_char_as_active:
        lda te_selected_char
        sta te_active_char
        lda te_selected_char+1
        sta te_active_char+1
        rts

te_select_active_char_from_grid:
        jsr te_select_base_char_as_active

        lda te_edit_x
        lsr
        lsr
        lsr
        sta te_char_cell_x

        lda te_edit_y
        lsr
        lsr
        lsr
        sta te_char_cell_y
        lda #0
        sta te_char_cell_offset
_te_sac_row_offset:
        lda te_char_cell_y
        beq _te_sac_have_row_offset
        clc
        lda te_char_cell_offset
        adc te_tile_cell_cols
        sta te_char_cell_offset
        dec te_char_cell_y
        bra _te_sac_row_offset
_te_sac_have_row_offset:
        clc
        lda te_char_cell_offset
        adc te_char_cell_x
        sta te_char_cell_offset

        clc
        lda te_active_char
        adc te_char_cell_offset
        sta te_active_char
        bcc _te_sac_pixel_offset
        inc te_active_char+1

_te_sac_pixel_offset:
        lda te_edit_y
        and #$07
        asl
        asl
        asl
        sta te_char_pixel_offset
        lda te_edit_x
        and #$07
        clc
        adc te_char_pixel_offset
        sta te_char_pixel_offset
        rts

te_active_char_ptr:
        lda te_active_char
        sta MULTINA
        lda te_active_char+1
        sta MULTINA+1
        lda #0
        sta MULTINA+2
        sta MULTINA+3

        lda #64
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3

        clc
        lda MULTOUT
        adc #<CHAR_DATA
        sta PTR
        lda MULTOUT+1
        adc #>CHAR_DATA
        sta PTR+1
        lda MULTOUT+2
        adc #`CHAR_DATA
        sta PTR+2
        lda #0
        sta PTR+3
        rts

te_recalc_tile_cells:
        lda te_grid_w
        lsr
        lsr
        lsr
        sta te_tile_cell_cols
        lda te_grid_h
        lsr
        lsr
        lsr
        sta te_tile_cell_rows

        lda #0
        sta te_grid_scale_shift
        lda te_grid_w
        cmp #(TE_GRID_SCREEN_W + 1)
        bcs _te_rtc_compact
        lda te_grid_h
        cmp #(TE_GRID_SCREEN_H + 1)
        bcc _te_rtc_display_size
_te_rtc_compact:
        lda #1
        sta te_grid_scale_shift

_te_rtc_display_size:
        lda te_grid_w
        ldx te_grid_scale_shift
        beq +
        lsr
+       sta te_grid_display_w
        lda te_grid_h
        ldx te_grid_scale_shift
        beq +
        lsr
+       sta te_grid_display_h
        rts

te_grid_index_from_xy:
        lda te_edit_y
        asl
        asl
        asl
        asl
        clc
        adc te_edit_x
        rts

;=======================================================================================
; Mouse/sprite setup.
;=======================================================================================

te_center_pointer:
        lda #160
        sta mouse_x
        lda #0
        sta mouse_x+1
        lda #100
        sta mouse_y
        lda #0
        sta mouse_y+1
        sta mouse_over_main
        rts

te_init_sprites:
        lda SPRITE_X_MSB
        and #%11111100
        sta SPRITE_X_MSB
        lda VIC4_SPRXMSB9
        and #%11111100
        sta VIC4_SPRXMSB9
        lda VIC4_SPRYMSB8
        and #%11111100
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #%11111100
        sta VIC4_SPRYMSB9

        lda #<te_sprite_ptrs
        sta VIC4_SPRPTRADRLSB
        lda #>te_sprite_ptrs
        sta VIC4_SPRPTRADRMSB
        lda #$80
        sta VIC4_SPRPTRBNK

        lda #<(te_pointer_sprite / 64)
        sta te_sprite_ptrs
        lda #>(te_pointer_sprite / 64)
        sta te_sprite_ptrs+1
        lda #<(te_browser_cursor_sprite / 64)
        sta te_sprite_ptrs+2
        lda #>(te_browser_cursor_sprite / 64)
        sta te_sprite_ptrs+3

        lda #$0F
        sta SPRITE0_COLOR
        lda #$0A
        sta SPRITE1_COLOR

        lda SPRITE_MULTICOLOR
        and #%11111100
        sta SPRITE_MULTICOLOR
        lda SPRITE_X_EXPAND
        and #%11111100
        sta SPRITE_X_EXPAND
        lda SPRITE_Y_EXPAND
        and #%11111100
        sta SPRITE_Y_EXPAND
        lda SPRITE_PRIORITY
        and #%11111100
        sta SPRITE_PRIORITY

        lda SPRITE_ENABLE
        and #%11111100
        ora #%00000011
        sta SPRITE_ENABLE
        rts

te_position_pointer_sprite:
        clc
        lda mouse_x
        adc #<SPRITE_SCREEN_X
        sta te_mouse_sprite_x
        lda mouse_x+1
        adc #>SPRITE_SCREEN_X
        sta te_mouse_sprite_x+1
        clc
        lda te_mouse_sprite_x
        adc te_sprite_x_fix
        sta te_mouse_sprite_x
        lda te_mouse_sprite_x+1
        adc #0
        sta te_mouse_sprite_x+1

        lda SPRITE_X_MSB
        and #%11111110
        sta SPRITE_X_MSB
        lda te_mouse_sprite_x+1
        beq +
        lda SPRITE_X_MSB
        ora #%00000001
        sta SPRITE_X_MSB
+       lda te_mouse_sprite_x
        sta SPRITE0_X

        clc
        lda mouse_y
        adc #SPRITE_SCREEN_Y
        sta SPRITE0_Y
        rts

te_position_browser_cursor:
        sec
        lda te_active_char
        sbc te_browser_scroll
        sta te_browser_cursor_index
        lda te_active_char+1
        sbc te_browser_scroll+1
        bne _te_pbc_hide
        lda te_browser_cursor_index
        cmp #TE_BROWSER_PAGE_STEP
        bcs _te_pbc_hide

        and #$07
        clc
        adc #TE_BROWSER_X
        sta te_browser_cursor_cell_x

        lda te_browser_cursor_index
        lsr
        lsr
        lsr
        clc
        adc #TE_BROWSER_Y
        sta te_browser_cursor_cell_y

        lda te_browser_cursor_cell_x
        sta te_browser_sprite_x
        lda #0
        sta te_browser_sprite_x+1
        asl te_browser_sprite_x
        rol te_browser_sprite_x+1
        asl te_browser_sprite_x
        rol te_browser_sprite_x+1
        asl te_browser_sprite_x
        rol te_browser_sprite_x+1

        clc
        lda te_browser_sprite_x
        adc #<SPRITE_SCREEN_X
        sta te_browser_sprite_x
        lda te_browser_sprite_x+1
        adc #>SPRITE_SCREEN_X
        sta te_browser_sprite_x+1

        clc
        lda te_browser_sprite_x
        adc te_sprite_x_fix
        sta te_browser_sprite_x
        lda te_browser_sprite_x+1
        adc #0
        sta te_browser_sprite_x+1

        lda SPRITE_X_MSB
        and #%11111101
        sta SPRITE_X_MSB
        lda te_browser_sprite_x+1
        beq +
        lda SPRITE_X_MSB
        ora #%00000010
        sta SPRITE_X_MSB
+       lda te_browser_sprite_x
        sta SPRITE1_X

        lda te_browser_cursor_cell_y
        asl
        asl
        asl
        clc
        adc #SPRITE_SCREEN_Y
        sta SPRITE1_Y

        lda SPRITE_ENABLE
        ora #%00000010
        sta SPRITE_ENABLE
        rts

_te_pbc_hide:
        lda SPRITE_ENABLE
        and #%11111101
        sta SPRITE_ENABLE
        rts

; mouse.asm expects this hook from viewport.asm in the main game. The editor
; does not maintain city cursor coordinates, so it is intentionally empty.
mouse_update_city_cursor:
        rts

;=======================================================================================
; Data init.
;=======================================================================================

te_init_document:
        lda #0
        sta te_selected_char
        sta te_selected_char+1
        sta te_active_char
        sta te_active_char+1
        sta te_browser_scroll
        sta te_browser_scroll+1
        sta te_selected_color
        sta te_palette_base
        sta te_editor_mode
        sta te_quit
        sta te_mouse_left_latch
        lda #TE_GRID_START_W
        sta te_grid_w
        lda #TE_GRID_START_H
        sta te_grid_h
        jsr te_recalc_tile_cells
        rts

te_init_palette:
        #SET_COLOR 0,    0,   0,   0
        #SET_COLOR 1,    0,  48, 160
        #SET_COLOR 2,   32, 160,  32
        #SET_COLOR 3,    0,  96,  16
        #SET_COLOR 4,  160, 112,  64
        #SET_COLOR 5,   96,  96,  96
        #SET_COLOR 6,  240, 208,  16
        #SET_COLOR 7,   96, 208,  64
        #SET_COLOR 8,   32,  96, 224
        #SET_COLOR 9,  192,  96,  16
        #SET_COLOR 10, 240, 224,  32
        #SET_COLOR 11,  48,  48,  48
        #SET_COLOR 12, 208, 208, 208
        #SET_COLOR 13, 224,  32,  32
        #SET_COLOR 14,  32, 224, 240
        #SET_COLOR 15, 240, 240, 240
        #SET_COLOR 16, 116,  86,  46
        #SET_COLOR 17, 105,  75,  34
        #SET_COLOR 18, 114,  85,  55
        #SET_COLOR 19, 109,  83,  57
        #SET_COLOR 20, 115,  81,  43
        #SET_COLOR 21, 112,  80,  59
        #SET_COLOR 22,  89,  70,  59
        #SET_COLOR 23, 107,  74,  35
        #SET_COLOR 24,  52, 104, 180
        #SET_COLOR 25,  44,  92, 165
        #SET_COLOR 26,  64, 118, 196
        #SET_COLOR 27,  80, 134, 208
        #SET_COLOR 28, 232, 148, 112
        #SET_COLOR 29, 124,  68,  66
        #SET_COLOR 30,  44,  44,  60
        #SET_COLOR 31, 113,  86,  66
        #SET_COLOR 32, 102, 103,  99
        #SET_COLOR 33, 156, 155, 155
        #SET_COLOR 34,  63,  56,  49
        #SET_COLOR 35, 117,  85,  56
        #SET_COLOR 36, 156, 100,  52
        rts

te_build_chars:
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 0, te_solid_0
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 1, te_solid_1
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 2, te_solid_2
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 3, te_solid_3
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 4, te_solid_4
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 5, te_solid_5
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 6, te_solid_6
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 7, te_solid_7
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 8, te_solid_8
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 9, te_solid_9
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 10, te_solid_10
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 11, te_solid_11
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 12, te_solid_12
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 13, te_solid_13
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 14, te_solid_14
        #LOAD_CHAR TE_CHAR_SOLID_BASE + 15, te_solid_15

        #LOAD_CHAR TE_CHAR_GRID_BASE + 0, te_grid_0
        #LOAD_CHAR TE_CHAR_GRID_BASE + 1, te_grid_1
        #LOAD_CHAR TE_CHAR_GRID_BASE + 2, te_grid_2
        #LOAD_CHAR TE_CHAR_GRID_BASE + 3, te_grid_3
        #LOAD_CHAR TE_CHAR_GRID_BASE + 4, te_grid_4
        #LOAD_CHAR TE_CHAR_GRID_BASE + 5, te_grid_5
        #LOAD_CHAR TE_CHAR_GRID_BASE + 6, te_grid_6
        #LOAD_CHAR TE_CHAR_GRID_BASE + 7, te_grid_7
        #LOAD_CHAR TE_CHAR_GRID_BASE + 8, te_grid_8
        #LOAD_CHAR TE_CHAR_GRID_BASE + 9, te_grid_9
        #LOAD_CHAR TE_CHAR_GRID_BASE + 10, te_grid_10
        #LOAD_CHAR TE_CHAR_GRID_BASE + 11, te_grid_11
        #LOAD_CHAR TE_CHAR_GRID_BASE + 12, te_grid_12
        #LOAD_CHAR TE_CHAR_GRID_BASE + 13, te_grid_13
        #LOAD_CHAR TE_CHAR_GRID_BASE + 14, te_grid_14
        #LOAD_CHAR TE_CHAR_GRID_BASE + 15, te_grid_15

        #LOAD_CHAR TE_CHAR_PANEL, te_solid_12
        #LOAD_CHAR TE_CHAR_FRAME, te_solid_11
        #LOAD_CHAR TE_CHAR_TEXT_BG, te_solid_15
        #LOAD_CHAR TE_CHAR_BROWSER_BG, te_solid_0

        #LOAD_CHAR TE_TEXT_T, te_glyph_t
        #LOAD_CHAR TE_TEXT_I, te_glyph_i
        #LOAD_CHAR TE_TEXT_L, te_glyph_l
        #LOAD_CHAR TE_TEXT_E, te_glyph_e
        #LOAD_CHAR TE_TEXT_S, te_glyph_s
        #LOAD_CHAR TE_TEXT_Z, te_glyph_z
        #LOAD_CHAR TE_TEXT_COLON, te_glyph_colon
        #LOAD_CHAR TE_TEXT_1, te_glyph_1
        #LOAD_CHAR TE_TEXT_6, te_glyph_6
        #LOAD_CHAR TE_TEXT_X, te_glyph_x
        #LOAD_CHAR TE_TEXT_D, te_glyph_d
        #LOAD_CHAR TE_TEXT_2, te_glyph_2
        #LOAD_CHAR TE_TEXT_4, te_glyph_4
        #LOAD_CHAR TE_TEXT_8, te_glyph_8
        #LOAD_CHAR TE_TEXT_3, te_glyph_3
        #LOAD_CHAR TE_TEXT_0, te_glyph_0
        #LOAD_CHAR TE_TEXT_5, te_glyph_5
        #LOAD_CHAR TE_TEXT_7, te_glyph_7
        #LOAD_CHAR TE_TEXT_9, te_glyph_9
        #LOAD_CHAR TE_TEXT_MINUS, te_glyph_minus
        #LOAD_CHAR TE_CHAR_PAGE_UP, te_button_up
        #LOAD_CHAR TE_CHAR_PAGE_DOWN, te_button_down
        #LOAD_CHAR TE_TEXT_R, te_glyph_r
        #LOAD_CHAR TE_TEXT_G, te_glyph_g
        #LOAD_CHAR TE_TEXT_B, te_glyph_b
        #LOAD_CHAR TE_TEXT_P, te_glyph_p
        #LOAD_CHAR TE_TEXT_A, te_glyph_a
        #LOAD_CHAR TE_CHAR_PALETTE_MARKER, te_palette_marker
        #LOAD_CHAR TE_TEXT_C, te_glyph_c
        #LOAD_CHAR TE_TEXT_F, te_glyph_f
        #LOAD_CHAR TE_TEXT_H, te_glyph_h
        #LOAD_CHAR TE_TEXT_HASH, te_glyph_hash
        rts

;=======================================================================================
; Variables.
;=======================================================================================

te_quit:
        .byte 0
te_key:
        .byte 0
te_filename_len:
        .byte 0
te_palette_filename_len:
        .byte 0
te_export_filename_len:
        .byte 0
te_scratch_len:
        .byte 0
te_save_len:
        .byte 0
te_command_len:
        .byte 0
te_filename_new_len:
        .byte 0
te_prompt_keep_existing:
        .byte 0
te_disk_status_0:
        .byte 0
te_disk_status_1:
        .byte 0
te_palette_loaded:
        .byte 0
te_load_end:
        .word 0
te_load_size:
        .word 0
te_selected_color:
        .byte 0
te_palette_base:
        .byte 0
te_editor_mode:
        .byte 0
te_palette_r:
        .byte 0
te_palette_g:
        .byte 0
te_palette_b:
        .byte 0
te_palette_slider_value:
        .byte 0
te_palette_slider_label:
        .byte 0
te_palette_slider_row:
        .byte 0
te_palette_channel_tmp:
        .byte 0
te_palette_range_start:
        .byte 0
te_palette_range_end:
        .byte 0
te_palette_current:
        .byte 0
te_selected_char:
        .word 0
te_active_char:
        .word 0
te_saved_active_char:
        .word 0
te_browser_scroll:
        .word 0
te_mouse_cell_x:
        .byte 0
te_mouse_cell_y:
        .byte 0
te_mouse_left_latch:
        .byte 0
te_edit_x:
        .byte 0
te_edit_y:
        .byte 0
te_grid_w:
        .byte TE_GRID_START_W
te_grid_h:
        .byte TE_GRID_START_H
te_grid_display_w:
        .byte TE_GRID_START_W
te_grid_display_h:
        .byte TE_GRID_START_H
te_grid_display_x:
        .byte 0
te_grid_display_y:
        .byte 0
te_grid_scale_shift:
        .byte 0
te_tile_cell_cols:
        .byte 1
te_tile_cell_rows:
        .byte 1
te_char_cell_x:
        .byte 0
te_char_cell_y:
        .byte 0
te_char_cell_offset:
        .byte 0
te_num_x:
        .byte 0
te_num_y:
        .byte 0
te_num_tens:
        .byte 0
te_num_ones:
        .byte 0
te_dec_value:
        .word 0
te_dec_digit:
        .byte 0
te_dec_started:
        .byte 0
te_save_remaining:
        .word 0
te_save_chunk_src:
        .word 0
te_save_chunk_size_lo:
        .byte 0
te_save_chunk_size_hi:
        .byte 0
te_i:
        .byte 0
te_char_lo:
        .byte 0
te_browser_index:
        .byte 0
te_browser_col:
        .byte 0
te_browser_row:
        .byte 0
te_browser_pick_col:
        .byte 0
te_browser_pick_row:
        .byte 0
te_char_pixel_offset:
        .byte 0
te_fill_char_lo:
        .byte 0
te_fill_char_hi:
        .byte 0
te_fill_color:
        .byte 0
te_grid_color_count:
        .byte 0
te_grid_color_value:
        .byte 0
te_grid_color_slot:
        .byte 0
te_hex_nibble:
        .byte 0
te_range_input_len:
        .byte 0
te_range_value:
        .word 0
te_export_start:
        .word 0
te_export_end:
        .word 0
te_export_current:
        .word 0
te_export_offset:
        .byte 0
te_export_row:
        .byte 0
te_export_col:
        .byte 0
te_rect_char:
        .byte 0
te_rect_x:
        .byte 0
te_rect_y:
        .byte 0
te_rect_w:
        .byte 0
te_rect_h:
        .byte 0
te_rect_cur_x:
        .byte 0
te_rect_cur_y:
        .byte 0
te_rect_cols_left:
        .byte 0
te_rect_rows_left:
        .byte 0
te_mouse_sprite_x:
        .word 0
te_browser_sprite_x:
        .word 0
te_browser_cursor_index:
        .byte 0
te_browser_cursor_cell_x:
        .byte 0
te_browser_cursor_cell_y:
        .byte 0
te_sprite_x_fix:
        .byte 0
te_text_row:
        .byte 0
te_text_col:
        .byte 0
te_text_screen_lo:
        .byte 0
te_text_screen_hi:
        .byte 0
te_text_screen_bank:
        .byte 0
te_text_screen_mb:
        .byte 0
te_default_filename:
        .text "NEWTILES"
        .byte 0
te_default_palette_filename:
        .text "PALETTE"
        .byte 0
te_default_export_filename:
        .text "TILEASM"
        .byte 0
te_scratch_buf:
        .fill TE_FILENAME_MAX + 3, 0
te_save_buf:
        .fill TE_FILENAME_MAX + 6, 0
te_command_buf:
        .fill (TE_FILENAME_MAX * 2) + 4, 0
te_filename_new_buf:
        .fill TE_FILENAME_MAX, 0
te_filename_buf:
        .fill TE_FILENAME_MAX, 0
te_palette_filename_buf:
        .fill TE_FILENAME_MAX, 0
te_export_filename_buf:
        .fill TE_FILENAME_MAX, 0
te_range_input_buf:
        .fill 4, 0

te_save_chunk_buf:
        .fill 256, 0
te_palette_red:
        .fill 256, 0
te_palette_green:
        .fill 256, 0
te_palette_blue:
        .fill 256, 0
te_grid_color_cache:
        .fill 16, 0

te_digit_chars:
        .byte <TE_TEXT_0, <TE_TEXT_1, <TE_TEXT_2, <TE_TEXT_3, <TE_TEXT_4
        .byte <TE_TEXT_5, <TE_TEXT_6, <TE_TEXT_7, <TE_TEXT_8, <TE_TEXT_9

te_hex_digit_chars:
        .byte <TE_TEXT_0, <TE_TEXT_1, <TE_TEXT_2, <TE_TEXT_3
        .byte <TE_TEXT_4, <TE_TEXT_5, <TE_TEXT_6, <TE_TEXT_7
        .byte <TE_TEXT_8, <TE_TEXT_9, <TE_TEXT_A, <TE_TEXT_B
        .byte <TE_TEXT_C, <TE_TEXT_D, <TE_TEXT_E, <TE_TEXT_F

te_hex_ascii_chars:
        .byte $30,$31,$32,$33,$34,$35,$36,$37
        .byte $38,$39,$41,$42,$43,$44,$45,$46

        .align 16
te_sprite_ptrs:
        .fill 16, 0

        .align 64
te_pointer_sprite:
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
te_browser_cursor_sprite:
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
        .byte $00

;=======================================================================================
; Character source data.
;=======================================================================================

SOLID .macro c
        .fill 64, \c
.endmacro

GRID .macro c
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
        .byte $0B,\c,\c,\c,\c,\c,\c,\c
.endmacro

TFF = $00
TFB = $0F

FONT_00 .macro
        .byte TFB,TFB,TFB,TFB,TFB,TFB,TFB,TFB
.endmacro
FONT_06 .macro
        .byte TFB,TFB,TFB,TFB,TFB,TFF,TFF,TFB
.endmacro
FONT_0C .macro
        .byte TFB,TFB,TFB,TFB,TFF,TFF,TFB,TFB
.endmacro
FONT_0E .macro
        .byte TFB,TFB,TFB,TFB,TFF,TFF,TFF,TFB
.endmacro
FONT_18 .macro
        .byte TFB,TFB,TFB,TFF,TFF,TFB,TFB,TFB
.endmacro
FONT_1C .macro
        .byte TFB,TFB,TFB,TFF,TFF,TFF,TFB,TFB
.endmacro
FONT_1E .macro
        .byte TFB,TFB,TFB,TFF,TFF,TFF,TFF,TFB
.endmacro
FONT_30 .macro
        .byte TFB,TFB,TFF,TFF,TFB,TFB,TFB,TFB
.endmacro
FONT_38 .macro
        .byte TFB,TFB,TFF,TFF,TFF,TFB,TFB,TFB
.endmacro
FONT_3C .macro
        .byte TFB,TFB,TFF,TFF,TFF,TFF,TFB,TFB
.endmacro
FONT_3E .macro
        .byte TFB,TFB,TFF,TFF,TFF,TFF,TFF,TFB
.endmacro
FONT_60 .macro
        .byte TFB,TFF,TFF,TFB,TFB,TFB,TFB,TFB
.endmacro
FONT_66 .macro
        .byte TFB,TFF,TFF,TFB,TFB,TFF,TFF,TFB
.endmacro
FONT_6C .macro
        .byte TFB,TFF,TFF,TFB,TFF,TFF,TFB,TFB
.endmacro
FONT_6E .macro
        .byte TFB,TFF,TFF,TFB,TFF,TFF,TFF,TFB
.endmacro
FONT_76 .macro
        .byte TFB,TFF,TFF,TFF,TFB,TFF,TFF,TFB
.endmacro
FONT_78 .macro
        .byte TFB,TFF,TFF,TFF,TFF,TFB,TFB,TFB
.endmacro
FONT_7C .macro
        .byte TFB,TFF,TFF,TFF,TFF,TFF,TFB,TFB
.endmacro
FONT_7E .macro
        .byte TFB,TFF,TFF,TFF,TFF,TFF,TFF,TFB
.endmacro
FONT_7F .macro
        .byte TFB,TFF,TFF,TFF,TFF,TFF,TFF,TFF
.endmacro

te_solid_0:  #SOLID $00
te_solid_1:  #SOLID $01
te_solid_2:  #SOLID $02
te_solid_3:  #SOLID $03
te_solid_4:  #SOLID $04
te_solid_5:  #SOLID $05
te_solid_6:  #SOLID $06
te_solid_7:  #SOLID $07
te_solid_8:  #SOLID $08
te_solid_9:  #SOLID $09
te_solid_10: #SOLID $0A
te_solid_11: #SOLID $0B
te_solid_12: #SOLID $0C
te_solid_13: #SOLID $0D
te_solid_14: #SOLID $0E
te_solid_15: #SOLID $0F

te_grid_0:  #GRID $00
te_grid_1:  #GRID $01
te_grid_2:  #GRID $02
te_grid_3:  #GRID $03
te_grid_4:  #GRID $04
te_grid_5:  #GRID $05
te_grid_6:  #GRID $06
te_grid_7:  #GRID $07
te_grid_8:  #GRID $08
te_grid_9:  #GRID $09
te_grid_10: #GRID $0A
te_grid_11: #GRID $0B
te_grid_12: #GRID $0C
te_grid_13: #GRID $0D
te_grid_14: #GRID $0E
te_grid_15: #GRID $0F

te_glyph_t:
        #FONT_7E
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_00
te_glyph_i:
        #FONT_3C
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_3C
        #FONT_00
te_glyph_l:
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_7E
        #FONT_00
te_glyph_e:
        #FONT_7E
        #FONT_60
        #FONT_60
        #FONT_78
        #FONT_60
        #FONT_60
        #FONT_7E
        #FONT_00
te_glyph_s:
        #FONT_3C
        #FONT_66
        #FONT_60
        #FONT_3C
        #FONT_06
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_z:
        #FONT_7E
        #FONT_06
        #FONT_0C
        #FONT_18
        #FONT_30
        #FONT_60
        #FONT_7E
        #FONT_00
te_glyph_colon:
        #FONT_00
        #FONT_18
        #FONT_18
        #FONT_00
        #FONT_00
        #FONT_18
        #FONT_18
        #FONT_00
te_glyph_1:
        #FONT_18
        #FONT_38
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_7E
        #FONT_00
te_glyph_6:
        #FONT_3C
        #FONT_66
        #FONT_60
        #FONT_7C
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_x:
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_18
        #FONT_3C
        #FONT_66
        #FONT_66
        #FONT_00
te_glyph_d:
        #FONT_78
        #FONT_6C
        #FONT_66
        #FONT_66
        #FONT_66
        #FONT_6C
        #FONT_78
        #FONT_00
te_glyph_2:
        #FONT_3C
        #FONT_66
        #FONT_06
        #FONT_0C
        #FONT_18
        #FONT_30
        #FONT_7E
        #FONT_00
te_glyph_3:
        #FONT_3C
        #FONT_66
        #FONT_06
        #FONT_1C
        #FONT_06
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_4:
        #FONT_06
        #FONT_0E
        #FONT_1E
        #FONT_66
        #FONT_7F
        #FONT_06
        #FONT_06
        #FONT_00
te_glyph_8:
        #FONT_3C
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_0:
        #FONT_3C
        #FONT_66
        #FONT_6E
        #FONT_76
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_5:
        #FONT_7E
        #FONT_60
        #FONT_7C
        #FONT_06
        #FONT_06
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_7:
        #FONT_7E
        #FONT_66
        #FONT_0C
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_18
        #FONT_00
te_glyph_9:
        #FONT_3C
        #FONT_66
        #FONT_66
        #FONT_3E
        #FONT_06
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_minus:
        #FONT_00
        #FONT_00
        #FONT_00
        #FONT_7E
        #FONT_00
        #FONT_00
        #FONT_00
        #FONT_00

te_glyph_r:
        #FONT_7C
        #FONT_66
        #FONT_66
        #FONT_7C
        #FONT_6C
        #FONT_66
        #FONT_66
        #FONT_00
te_glyph_g:
        #FONT_3C
        #FONT_66
        #FONT_60
        #FONT_6E
        #FONT_66
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_b:
        #FONT_7C
        #FONT_66
        #FONT_66
        #FONT_7C
        #FONT_66
        #FONT_66
        #FONT_7C
        #FONT_00
te_glyph_p:
        #FONT_7C
        #FONT_66
        #FONT_66
        #FONT_7C
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_00
te_glyph_a:
        #FONT_3C
        #FONT_66
        #FONT_66
        #FONT_7E
        #FONT_66
        #FONT_66
        #FONT_66
        #FONT_00
te_glyph_c:
        #FONT_3C
        #FONT_66
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_66
        #FONT_3C
        #FONT_00
te_glyph_f:
        #FONT_7E
        #FONT_60
        #FONT_60
        #FONT_78
        #FONT_60
        #FONT_60
        #FONT_60
        #FONT_00
te_glyph_h:
        #FONT_66
        #FONT_66
        #FONT_66
        #FONT_7E
        #FONT_66
        #FONT_66
        #FONT_66
        #FONT_00
te_glyph_hash:
        #FONT_66
        #FONT_66
        #FONT_7F
        #FONT_66
        #FONT_7F
        #FONT_66
        #FONT_66
        #FONT_00

te_palette_marker:
        .byte $0C,$0C,$0B,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0B,$0B,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0B,$0B,$0B,$0C,$0C,$0C
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0C,$0C
        .byte $0C,$0C,$0B,$0B,$0B,$0C,$0C,$0C
        .byte $0C,$0C,$0B,$0B,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0B,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C

te_button_up:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$00,$00,$0C,$0C,$0F
        .byte $00,$0C,$00,$00,$00,$00,$0C,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
te_button_down:
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$0C,$00,$00,$00,$00,$0C,$0F
        .byte $00,$0C,$0C,$00,$00,$0C,$0C,$0F
        .byte $00,$0C,$0C,$0C,$0C,$0C,$0C,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

;=======================================================================================
; Reused low-level modules.
;=======================================================================================

        .include "graphics/fcm_screen.asm"
        .include "graphics/fcm_core.asm"
        .include "mouse.asm"
