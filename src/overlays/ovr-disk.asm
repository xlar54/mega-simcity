;=======================================================================================
; Disk-options overlay (PRG, compiles to $A000).
;
; Single overlay that consolidates the previous ovr-save + ovr-load behaviour
; behind one folder button. The overlay drives its own modal loop, walking
; the player through a small state machine:
;
;   STATE_MENU            -- "Disk Options" panel, 3 buttons: Load / Save / Cancel
;   STATE_LOAD_FILENAME   -- "Load City" panel, filename input + OK/Cancel
;   STATE_SAVE_FILENAME   -- "Save City" panel, filename input (prefilled from
;                            current_city_filename) + OK/Cancel
;   STATE_SAVE_CONFIRM    -- "File exists. Replace?" + OK/Cancel
;   STATE_RESULT          -- "City Saved." / "Loaded." / "Load Error." + OK
;
; Save flow:
;   menu Save -> SAVE_FILENAME -> [check_file_exists]
;                                 +--exists--> SAVE_CONFIRM (OK: scratch+save;
;                                 |                          Cancel: back to filename)
;                                 +--missing-> save immediately
;                                 +-> RESULT(saved) -> close
;
; Load flow:
;   menu Load -> LOAD_FILENAME -> [open + read map] -> RESULT(loaded/error)
;                                                  -> close
;
; Save / load file format is identical to the previous ovr-save / ovr-load
; (16B header + 4B funds + 3B clock + 32B*3 plant origins + 48000B map).
;
; Existence check uses OPEN-for-read, one CHRIN, then reads KERNAL status
; byte $90. Non-zero ST after the first read = file not found (or some other
; read error, which we treat the same way for the purposes of "should I prompt
; to overwrite?").
;=======================================================================================

        .cpu "45gs02"

        .include "../../target/mega-simcity.lbl"

        * = OVR_WINDOW_ADDR

;---------------------------------------------------------------------------------------
; Constants
;---------------------------------------------------------------------------------------
ODV_FILENAME_MAX = CITY_FILENAME_MAX        ; 12, same as the main-game scratch
MAP_IO_SIZE      = CELL_COLS * CELL_ROWS    ; 48000

; State machine codes (stored in odv_state).
STATE_MENU          = 0
STATE_LOAD_FILENAME = 1
STATE_SAVE_FILENAME = 2
STATE_SAVE_CONFIRM  = 3
STATE_RESULT        = 4

; RESULT message indices (stored in odv_result_msg). Each one picks a string
; that gets stamped on the result panel.
RESULT_SAVED      = 0
RESULT_LOADED     = 1
RESULT_LOAD_ERROR = 2

; STATE_RESULT secondary disposition (stored in odv_result_kind), determines
; which title the result panel uses ("LOAD CITY" vs "SAVE CITY").
RESULT_KIND_LOAD = 0
RESULT_KIND_SAVE = 1

; Menu button rows (within the popup, popup-local).
ODV_MENU_BTN1_ROW = 2        ; "LOAD CITY"
ODV_MENU_BTN2_ROW = 4        ; "SAVE CITY"
ODV_MENU_BTN3_ROW = 6        ; "CANCEL"

; OK / Cancel hit areas live in two stamped text labels in the filename and
; confirm states. Cells (popup-local):
ODV_FN_OK_COL     = 3        ; "OK" column start
ODV_FN_OK_W       = 2        ; "OK" 2 chars
ODV_FN_CANCEL_COL = 8        ; "CANCEL" column start
ODV_FN_CANCEL_W   = 6
ODV_FN_BTN_ROW    = 5        ; row where the OK / CANCEL labels sit

;=======================================================================================
; Entry point
;=======================================================================================
ovr_disk_main:
        ; Start in MENU state. odv_enter_state sets up the popup geometry,
        ; opens the panel, and draws state-specific content.
        lda #STATE_MENU
        sta odv_state
        lda #0
        sta odv_exit_flag
        jsr odv_enter_state

        ; Drain a stale keystroke from the toolbar click so the first frame
        ; of our modal loop doesn't see it.
        lda #0
        sta MEGA_KEYQUEUE

_odv_loop:
        jsr wait_frame
        jsr mouse_poll
        jsr mouse_position_pointer_sprite

        ; Process input by state. The dispatch may transition state (set
        ; odv_state_changed) or request exit (set odv_exit_flag).
        jsr odv_dispatch_input

        lda odv_state_changed
        beq _odv_check_exit
        lda #0
        sta odv_state_changed
        jsr odv_enter_state
_odv_check_exit:
        lda odv_exit_flag
        beq _odv_loop

        jsr overlay_close
        rts

;=======================================================================================
; State enter -- runs once per state transition. Closes the current popup,
; sets new geometry, opens it, and stamps the state-specific content.
;=======================================================================================
odv_enter_state:
        jsr overlay_close                 ; close any prior popup (no-op if first)
        lda odv_state
        cmp #STATE_MENU
        beq odv_menu_enter
        cmp #STATE_LOAD_FILENAME
        beq odv_load_fn_enter
        cmp #STATE_SAVE_FILENAME
        beq odv_save_fn_enter
        cmp #STATE_SAVE_CONFIRM
        beq odv_save_confirm_enter
        ; STATE_RESULT (fall through)
        jmp odv_result_enter

;---------------------------------------------------------------------------------------
; MENU state: 3 buttons (Load City / Save City / Cancel).
;---------------------------------------------------------------------------------------
odv_menu_enter:
        jsr odv_set_uniform_geometry
        lda #<odv_title_disk
        ldx #>odv_title_disk
        ldy #odv_title_disk_len
        jsr overlay_open
        ; Overwrite the framework's OK button (drawn by overlay_open) with
        ; panel tiles -- this state has its own buttons drawn as text.
        jsr odv_blank_ok
        ; Border lines around each button row. The buttons sit on rows 2/4/6
        ; with HLINE rows at 1/3/5/7 -- adjacent buttons share their border.
        lda #1
        jsr odv_draw_hline_row
        lda #3
        jsr odv_draw_hline_row
        lda #5
        jsr odv_draw_hline_row
        lda #7
        jsr odv_draw_hline_row

        ; Draw the 3 menu labels centred horizontally on rows 2, 4, 6.
        lda #<odv_label_load_city
        sta odv_dcl_lo
        lda #>odv_label_load_city
        sta odv_dcl_hi
        lda #odv_label_load_city_len
        sta odv_dcl_len
        lda #ODV_MENU_BTN1_ROW
        jsr odv_draw_centered_label
        lda #<odv_label_save_city
        sta odv_dcl_lo
        lda #>odv_label_save_city
        sta odv_dcl_hi
        lda #odv_label_save_city_len
        sta odv_dcl_len
        lda #ODV_MENU_BTN2_ROW
        jsr odv_draw_centered_label
        lda #<odv_label_cancel
        sta odv_dcl_lo
        lda #>odv_label_cancel
        sta odv_dcl_hi
        lda #odv_label_cancel_len
        sta odv_dcl_len
        lda #ODV_MENU_BTN3_ROW
        jsr odv_draw_centered_label
        rts

;---------------------------------------------------------------------------------------
; LOAD_FILENAME / SAVE_FILENAME state: shared layout.
;---------------------------------------------------------------------------------------
odv_load_fn_enter:
        lda #0
        sta odv_filename_len             ; load starts blank
        lda #<odv_title_load
        ldx #>odv_title_load
        ldy #odv_title_load_len
        jmp odv_fn_open_panel

odv_save_fn_enter:
        ; Pre-populate from current_city_filename if non-empty.
        lda current_city_filename_len
        sta odv_filename_len
        beq _odv_save_fn_no_copy
        ldx #0
_odv_save_fn_copy:
        lda current_city_filename,x
        sta odv_filename_buf,x
        inx
        cpx current_city_filename_len
        bne _odv_save_fn_copy
_odv_save_fn_no_copy:
        lda #<odv_title_save
        ldx #>odv_title_save
        ldy #odv_title_save_len
        ; fall through

odv_fn_open_panel:
        sta odv_title_ptr
        stx odv_title_ptr+1
        sty odv_title_len_save
        jsr odv_set_uniform_geometry
        lda odv_title_ptr
        ldx odv_title_ptr+1
        ldy odv_title_len_save
        jsr overlay_open
        jsr odv_blank_ok
        ; "FILE:" label on row 2, col 1.
        lda #UI_TEXT_F
        clc
        ldx #1
        jsr odv_stamp_at_popup_2
        lda #UI_TEXT_I
        ldx #2
        jsr odv_stamp_at_popup_2
        lda #UI_TEXT_L
        ldx #3
        jsr odv_stamp_at_popup_2
        lda #UI_TEXT_E
        ldx #4
        jsr odv_stamp_at_popup_2
        lda #UI_TEXT_COLON
        ldx #5
        jsr odv_stamp_at_popup_2
        ; Filename input field on row 3 (col 1..ODV_FILENAME_MAX).
        jsr odv_draw_filename
        ; "OK" + "CANCEL" labels on row 5.
        jsr odv_draw_ok_cancel
        rts

;---------------------------------------------------------------------------------------
; SAVE_CONFIRM state: prompt to replace an existing file.
;---------------------------------------------------------------------------------------
odv_save_confirm_enter:
        jsr odv_set_uniform_geometry
        lda #<odv_title_save
        ldx #>odv_title_save
        ldy #odv_title_save_len
        jsr overlay_open
        jsr odv_blank_ok
        ; "FILE EXISTS." centred on row 2.
        lda #<odv_msg_exists
        sta odv_dcl_lo
        lda #>odv_msg_exists
        sta odv_dcl_hi
        lda #odv_msg_exists_len
        sta odv_dcl_len
        lda #2
        jsr odv_draw_centered_label
        ; "REPLACE?" centred on row 3.
        lda #<odv_msg_replace
        sta odv_dcl_lo
        lda #>odv_msg_replace
        sta odv_dcl_hi
        lda #odv_msg_replace_len
        sta odv_dcl_len
        lda #3
        jsr odv_draw_centered_label
        jsr odv_draw_ok_cancel
        rts

;---------------------------------------------------------------------------------------
; RESULT state: one of "City Saved.", "Loaded.", "Load Error." + OK only.
;---------------------------------------------------------------------------------------
odv_result_enter:
        jsr odv_set_uniform_geometry
        ; Pick title based on whether this was a load or save action.
        lda odv_result_kind
        bne _odv_res_save_title
        lda #<odv_title_load
        ldx #>odv_title_load
        ldy #odv_title_load_len
        bra _odv_res_open
_odv_res_save_title:
        lda #<odv_title_save
        ldx #>odv_title_save
        ldy #odv_title_save_len
_odv_res_open:
        jsr overlay_open
        ; Pick the body message based on odv_result_msg.
        lda odv_result_msg
        cmp #RESULT_SAVED
        beq _odv_res_msg_saved
        cmp #RESULT_LOADED
        beq _odv_res_msg_loaded
        ; Otherwise: LOAD_ERROR
        lda #<odv_msg_load_err
        ldx #>odv_msg_load_err
        ldy #odv_msg_load_err_len
        bra _odv_res_draw
_odv_res_msg_saved:
        lda #<odv_msg_saved
        ldx #>odv_msg_saved
        ldy #odv_msg_saved_len
        bra _odv_res_draw
_odv_res_msg_loaded:
        lda #<odv_msg_loaded
        ldx #>odv_msg_loaded
        ldy #odv_msg_loaded_len
_odv_res_draw:
        sta odv_dcl_lo
        stx odv_dcl_hi
        sty odv_dcl_len
        lda #2
        jsr odv_draw_centered_label
        ; The framework's OK button stays; that's the single click target.
        rts

;=======================================================================================
; State input dispatch
;=======================================================================================
odv_dispatch_input:
        lda odv_state
        cmp #STATE_MENU
        beq odv_menu_input
        cmp #STATE_LOAD_FILENAME
        beq odv_fn_input
        cmp #STATE_SAVE_FILENAME
        beq odv_fn_input
        cmp #STATE_SAVE_CONFIRM
        beq odv_confirm_input
        ; STATE_RESULT
        jmp odv_result_input

;---------------------------------------------------------------------------------------
; MENU input: click row 2 -> LOAD_FN, row 4 -> SAVE_FN, row 6 -> cancel/exit.
;---------------------------------------------------------------------------------------
odv_menu_input:
        lda mouse_left_click
        beq _odv_mi_done
        ; Convert mouse coords to popup-local cell coords.
        jsr odv_mouse_to_popup_cell      ; out: odv_click_col, odv_click_row, carry
        bcc _odv_mi_done
        ; Row check: 2 = LOAD, 4 = SAVE, 6 = CANCEL. All are 1 row tall.
        lda odv_click_row
        cmp #ODV_MENU_BTN1_ROW
        beq _odv_mi_load
        cmp #ODV_MENU_BTN2_ROW
        beq _odv_mi_save
        cmp #ODV_MENU_BTN3_ROW
        beq _odv_mi_cancel
_odv_mi_done:
        rts
_odv_mi_load:
        jsr audio_click
        lda #STATE_LOAD_FILENAME
        sta odv_state
        lda #1
        sta odv_state_changed
        rts
_odv_mi_save:
        jsr audio_click
        lda #STATE_SAVE_FILENAME
        sta odv_state
        lda #1
        sta odv_state_changed
        rts
_odv_mi_cancel:
        jsr audio_click
        lda #1
        sta odv_exit_flag
        rts

;---------------------------------------------------------------------------------------
; FILENAME input (LOAD or SAVE): keyboard for filename edit, click OK/Cancel.
;---------------------------------------------------------------------------------------
odv_fn_input:
        ; Keyboard
        lda MEGA_KEYQUEUE
        beq _odv_fi_no_key
        sta odv_key
        lda #0
        sta MEGA_KEYQUEUE
        lda odv_key
        cmp #$0D                          ; CR -> OK
        beq _odv_fi_ok
        cmp #$1B                          ; ESC -> cancel
        beq _odv_fi_cancel
        cmp #$14                          ; CBM DEL
        beq _odv_fi_backspace
        cmp #$08                          ; ASCII BS
        beq _odv_fi_backspace
        jsr odv_try_append_key
_odv_fi_no_key:
        ; Mouse
        lda mouse_left_click
        beq _odv_fi_done
        jsr odv_mouse_to_popup_cell
        bcc _odv_fi_done
        lda odv_click_row
        cmp #ODV_FN_BTN_ROW
        bne _odv_fi_done
        ; Row matches. Column?
        lda odv_click_col
        cmp #ODV_FN_OK_COL
        bcc _odv_fi_done
        cmp #(ODV_FN_OK_COL + ODV_FN_OK_W)
        bcc _odv_fi_ok
        cmp #ODV_FN_CANCEL_COL
        bcc _odv_fi_done
        cmp #(ODV_FN_CANCEL_COL + ODV_FN_CANCEL_W)
        bcs _odv_fi_done
        ; fall through -> cancel
_odv_fi_cancel:
        jsr audio_click
        lda #STATE_MENU
        sta odv_state
        lda #1
        sta odv_state_changed
_odv_fi_done:
        rts
_odv_fi_backspace:
        ldx odv_filename_len
        beq _odv_fi_no_key
        dex
        stx odv_filename_len
        jsr odv_draw_filename
        bra _odv_fi_no_key
_odv_fi_ok:
        jsr audio_click
        lda odv_filename_len
        beq _odv_fi_done                  ; empty -> ignore
        ; Different action per state.
        lda odv_state
        cmp #STATE_LOAD_FILENAME
        beq _odv_fi_do_load
        ; SAVE: check for existing file first.
        jsr odv_check_file_exists
        bcs _odv_fi_save_exists
        ; Doesn't exist -> save immediately.
        jsr odv_do_save
        bra _odv_fi_finish_save
_odv_fi_save_exists:
        lda #STATE_SAVE_CONFIRM
        sta odv_state
        lda #1
        sta odv_state_changed
        rts
_odv_fi_do_load:
        jsr odv_do_load
        ; Result code in A: 0 = success, non-zero = error.
        sta odv_load_result
        beq _odv_fi_load_ok
        lda #RESULT_LOAD_ERROR
        sta odv_result_msg
        lda #RESULT_KIND_LOAD
        sta odv_result_kind
        lda #STATE_RESULT
        sta odv_state
        lda #1
        sta odv_state_changed
        rts
_odv_fi_load_ok:
        ; Remember filename for the next save.
        jsr odv_store_current_filename
        lda #RESULT_LOADED
        sta odv_result_msg
        lda #RESULT_KIND_LOAD
        sta odv_result_kind
        lda #STATE_RESULT
        sta odv_state
        lda #1
        sta odv_state_changed
        rts
_odv_fi_finish_save:
        jsr odv_store_current_filename
        lda #RESULT_SAVED
        sta odv_result_msg
        lda #RESULT_KIND_SAVE
        sta odv_result_kind
        lda #STATE_RESULT
        sta odv_state
        lda #1
        sta odv_state_changed
        rts

;---------------------------------------------------------------------------------------
; CONFIRM input: OK -> scratch + save; Cancel -> back to filename input.
;---------------------------------------------------------------------------------------
odv_confirm_input:
        lda mouse_left_click
        beq _odv_ci_done
        jsr odv_mouse_to_popup_cell
        bcc _odv_ci_done
        lda odv_click_row
        cmp #ODV_FN_BTN_ROW
        bne _odv_ci_done
        lda odv_click_col
        cmp #ODV_FN_OK_COL
        bcc _odv_ci_done
        cmp #(ODV_FN_OK_COL + ODV_FN_OK_W)
        bcc _odv_ci_ok
        cmp #ODV_FN_CANCEL_COL
        bcc _odv_ci_done
        cmp #(ODV_FN_CANCEL_COL + ODV_FN_CANCEL_W)
        bcs _odv_ci_done
        ; -> CANCEL
        jsr audio_click
        lda #STATE_SAVE_FILENAME
        sta odv_state
        lda #1
        sta odv_state_changed
_odv_ci_done:
        rts
_odv_ci_ok:
        jsr audio_click
        jsr odv_scratch_file
        jsr odv_do_save
        jsr odv_store_current_filename
        lda #RESULT_SAVED
        sta odv_result_msg
        lda #RESULT_KIND_SAVE
        sta odv_result_kind
        lda #STATE_RESULT
        sta odv_state
        lda #1
        sta odv_state_changed
        rts

;---------------------------------------------------------------------------------------
; RESULT input: OK only. Use the framework's OK rectangle.
;---------------------------------------------------------------------------------------
odv_result_input:
        ; Enter key or click on the framework OK button = close.
        lda MEGA_KEYQUEUE
        cmp #$0D
        bne _odv_ri_check_mouse
        lda #0
        sta MEGA_KEYQUEUE
        bra _odv_ri_close
_odv_ri_check_mouse:
        lda mouse_left_click
        beq _odv_ri_done
        lda mouse_x+1
        bne _odv_ri_done
        lda mouse_x
        cmp popup_ok_x_pixel
        bcc _odv_ri_done
        cmp popup_ok_x_pixel_end
        bcs _odv_ri_done
        lda mouse_y
        cmp popup_ok_y_pixel
        bcc _odv_ri_done
        cmp popup_ok_y_pixel_end
        bcs _odv_ri_done
_odv_ri_close:
        jsr audio_click
        lda #1
        sta odv_exit_flag
_odv_ri_done:
        rts

;=======================================================================================
; KERNAL operations
;=======================================================================================

;---------------------------------------------------------------------------------------
; odv_check_file_exists: try to OPEN-for-read; check status byte $90 after a
; single CHRIN. Returns carry SET if file exists (and is readable), CLEAR if
; not. Always closes the channel before returning.
;---------------------------------------------------------------------------------------
odv_check_file_exists:
        jsr odv_build_read_name
        ; SETLFS 2, 8, 2
        lda #2
        ldx #8
        ldy #2
        jsr KERNAL_SETLFS
        ; SETBNK 0, 0
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        ; SETNAM
        lda odv_full_name_len
        ldx #<odv_full_name_buf
        ldy #>odv_full_name_buf
        jsr KERNAL_SETNAM
        jsr KERNAL_OPEN
        bcs _odv_cfe_not_exists
        ldx #2
        jsr KERNAL_CHKIN
        bcs _odv_cfe_close_not_exists
        jsr KERNAL_CHRIN                  ; read one byte to surface DOS error
        ; Status byte: $00 = clean read, anything else (especially the file-
        ; not-found pattern) = treat as missing.
        lda $90
        bne _odv_cfe_close_not_exists
        ; File exists.
        jsr KERNAL_CLRCHN
        lda #2
        jsr KERNAL_CLOSE
        sec
        rts
_odv_cfe_close_not_exists:
        jsr KERNAL_CLRCHN
        lda #2
        jsr KERNAL_CLOSE
_odv_cfe_not_exists:
        clc
        rts

;---------------------------------------------------------------------------------------
; odv_scratch_file: delete the file by sending "S0:<name>" over the DOS
; command channel (15). Silently ignores any error.
;---------------------------------------------------------------------------------------
odv_scratch_file:
        jsr odv_build_scratch_cmd
        lda #15
        ldx #8
        ldy #15
        jsr KERNAL_SETLFS
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        lda odv_scratch_len
        ldx #<odv_scratch_buf
        ldy #>odv_scratch_buf
        jsr KERNAL_SETNAM
        jsr KERNAL_OPEN
        lda #15
        jsr KERNAL_CLOSE
        rts

;---------------------------------------------------------------------------------------
; odv_do_save: write the save file. Same format the previous ovr-save used.
; Sets odv_save_result = 0 on success, non-zero on error. (Caller doesn't use
; the value today -- save errors are treated as success and just show "saved";
; the user can verify via the file list. Future: surface errors in RESULT.)
;---------------------------------------------------------------------------------------
odv_do_save:
        jsr odv_build_write_name
        lda #1
        ldx #8
        ldy #1
        jsr KERNAL_SETLFS
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        lda odv_full_name_len
        ldx #<odv_full_name_buf
        ldy #>odv_full_name_buf
        jsr KERNAL_SETNAM
        jsr KERNAL_OPEN
        bcs _odv_save_done
        ldx #1
        jsr KERNAL_CHKOUT
        bcs _odv_save_close
        ; --- 16-byte header ---
        ldx #0
_odv_save_hdr:
        lda odv_save_header,x
        jsr KERNAL_CHROUT
        inx
        cpx #16
        bne _odv_save_hdr
        ; --- funds (4) ---
        lda funds
        jsr KERNAL_CHROUT
        lda funds+1
        jsr KERNAL_CHROUT
        lda funds+2
        jsr KERNAL_CHROUT
        lda funds+3
        jsr KERNAL_CHROUT
        ; --- clock (3) ---
        lda sim_month
        jsr KERNAL_CHROUT
        lda sim_year
        jsr KERNAL_CHROUT
        lda sim_year+1
        jsr KERNAL_CHROUT
        ; --- plant origins (1 + 32*3) ---
        lda plant_origin_count
        jsr KERNAL_CHROUT
        ldx #0
_odv_save_px:
        lda plant_origin_x,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _odv_save_px
        ldx #0
_odv_save_py:
        lda plant_origin_y,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _odv_save_py
        ldx #0
_odv_save_ps:
        lda plant_origin_struct,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _odv_save_ps
        ; --- map (48000 bytes via chunked DMA -> CHROUT) ---
        lda #<MAP_IO_SIZE
        sta odv_remaining
        lda #>MAP_IO_SIZE
        sta odv_remaining+1
        lda #0
        sta odv_chunk_off
        sta odv_chunk_off+1
_odv_save_map_loop:
        lda odv_remaining
        ora odv_remaining+1
        beq _odv_save_close
        lda odv_remaining+1
        beq _odv_save_partial
        lda #0
        sta odv_chunk_size_lo
        lda #1
        sta odv_chunk_size_hi
        bra _odv_save_set_dma
_odv_save_partial:
        lda odv_remaining
        sta odv_chunk_size_lo
        lda #0
        sta odv_chunk_size_hi
_odv_save_set_dma:
        ; DMA Attic -> chunk_buf
        lda odv_chunk_size_lo
        sta odv_dma_size
        lda odv_chunk_size_hi
        sta odv_dma_size+1
        lda odv_chunk_off
        sta odv_dma_src
        lda odv_chunk_off+1
        sta odv_dma_src+1
        lda #ATTIC_MAP_BANK
        sta odv_dma_src_bank
        lda #ATTIC_MAP_MB
        sta odv_dma_src_mb
        lda #<odv_chunk_buf
        sta odv_dma_dst
        lda #>odv_chunk_buf
        sta odv_dma_dst+1
        lda #$00
        sta odv_dma_dst_bank
        sta odv_dma_dst_mb
        jsr odv_dma_run
        ; CHROUT the chunk
        ldx #0
        lda odv_chunk_size_hi
        bne _odv_save_chrout_full
_odv_save_chrout_short:
        lda odv_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        cpx odv_chunk_size_lo
        bne _odv_save_chrout_short
        bra _odv_save_advance
_odv_save_chrout_full:
        lda odv_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        bne _odv_save_chrout_full
_odv_save_advance:
        clc
        lda odv_chunk_off
        adc odv_chunk_size_lo
        sta odv_chunk_off
        lda odv_chunk_off+1
        adc odv_chunk_size_hi
        sta odv_chunk_off+1
        sec
        lda odv_remaining
        sbc odv_chunk_size_lo
        sta odv_remaining
        lda odv_remaining+1
        sbc odv_chunk_size_hi
        sta odv_remaining+1
        bra _odv_save_map_loop
_odv_save_close:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_odv_save_done:
        rts

;---------------------------------------------------------------------------------------
; odv_do_load: read the save file. Returns A = 0 on success, non-zero on error.
;---------------------------------------------------------------------------------------
odv_do_load:
        jsr odv_build_read_name
        lda #1
        ldx #8
        ldy #2                            ; secondary 2 = read mode (CBM convention)
        jsr KERNAL_SETLFS
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        lda odv_full_name_len
        ldx #<odv_full_name_buf
        ldy #>odv_full_name_buf
        jsr KERNAL_SETNAM
        jsr KERNAL_OPEN
        bcs _odv_load_err_open
        ldx #1
        jsr KERNAL_CHKIN
        bcs _odv_load_err_close
        ; --- 16-byte header ---
        ldx #0
_odv_load_hdr:
        jsr KERNAL_CHRIN
        sta odv_save_header,x             ; reuse header buf for verify
        inx
        cpx #16
        bne _odv_load_hdr
        ; Magic check ("MEGASIM" in bytes 0..6).
        ldx #0
_odv_load_magic:
        lda odv_save_header,x
        cmp odv_magic_expected,x
        bne _odv_load_err_close
        inx
        cpx #7
        bne _odv_load_magic
        ; Version: accept $01 (legacy) or $02 (with plant block).
        lda odv_save_header+8
        cmp #$01
        beq _odv_load_ver_ok
        cmp #$02
        bne _odv_load_err_close
_odv_load_ver_ok:
        sta odv_load_version
        ; --- funds ---
        jsr KERNAL_CHRIN
        sta funds
        jsr KERNAL_CHRIN
        sta funds+1
        jsr KERNAL_CHRIN
        sta funds+2
        jsr KERNAL_CHRIN
        sta funds+3
        ; --- clock ---
        jsr KERNAL_CHRIN
        sta sim_month
        jsr KERNAL_CHRIN
        sta sim_year
        jsr KERNAL_CHRIN
        sta sim_year+1
        ; --- plant origins (only present in v2+) ---
        lda odv_load_version
        cmp #$02
        bne _odv_load_skip_plants
        jsr KERNAL_CHRIN
        sta plant_origin_count
        ldx #0
_odv_load_px:
        jsr KERNAL_CHRIN
        sta plant_origin_x,x
        inx
        cpx #PLANT_MAX
        bne _odv_load_px
        ldx #0
_odv_load_py:
        jsr KERNAL_CHRIN
        sta plant_origin_y,x
        inx
        cpx #PLANT_MAX
        bne _odv_load_py
        ldx #0
_odv_load_ps:
        jsr KERNAL_CHRIN
        sta plant_origin_struct,x
        inx
        cpx #PLANT_MAX
        bne _odv_load_ps
        bra _odv_load_after_plants
_odv_load_skip_plants:
        lda #0
        sta plant_origin_count
_odv_load_after_plants:
        ; --- map (48000 bytes via CHRIN -> chunk_buf -> DMA to Attic) ---
        lda #<MAP_IO_SIZE
        sta odv_remaining
        lda #>MAP_IO_SIZE
        sta odv_remaining+1
        lda #0
        sta odv_chunk_off
        sta odv_chunk_off+1
_odv_load_map_loop:
        lda odv_remaining
        ora odv_remaining+1
        beq _odv_load_ok_close
        lda odv_remaining+1
        beq _odv_load_partial
        lda #0
        sta odv_chunk_size_lo
        lda #1
        sta odv_chunk_size_hi
        bra _odv_load_fill
_odv_load_partial:
        lda odv_remaining
        sta odv_chunk_size_lo
        lda #0
        sta odv_chunk_size_hi
_odv_load_fill:
        ldx #0
        lda odv_chunk_size_hi
        bne _odv_load_fill_full
_odv_load_fill_short:
        jsr KERNAL_CHRIN
        sta odv_chunk_buf,x
        inx
        cpx odv_chunk_size_lo
        bne _odv_load_fill_short
        bra _odv_load_dma
_odv_load_fill_full:
        jsr KERNAL_CHRIN
        sta odv_chunk_buf,x
        inx
        bne _odv_load_fill_full
_odv_load_dma:
        ; DMA chunk_buf -> Attic at odv_chunk_off
        lda odv_chunk_size_lo
        sta odv_dma_size
        lda odv_chunk_size_hi
        sta odv_dma_size+1
        lda #<odv_chunk_buf
        sta odv_dma_src
        lda #>odv_chunk_buf
        sta odv_dma_src+1
        lda #$00
        sta odv_dma_src_bank
        sta odv_dma_src_mb
        lda odv_chunk_off
        sta odv_dma_dst
        lda odv_chunk_off+1
        sta odv_dma_dst+1
        lda #ATTIC_MAP_BANK
        sta odv_dma_dst_bank
        lda #ATTIC_MAP_MB
        sta odv_dma_dst_mb
        jsr odv_dma_run
        clc
        lda odv_chunk_off
        adc odv_chunk_size_lo
        sta odv_chunk_off
        lda odv_chunk_off+1
        adc odv_chunk_size_hi
        sta odv_chunk_off+1
        sec
        lda odv_remaining
        sbc odv_chunk_size_lo
        sta odv_remaining
        lda odv_remaining+1
        sbc odv_chunk_size_hi
        sta odv_remaining+1
        bra _odv_load_map_loop
_odv_load_ok_close:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
        ; Mark display caches dirty so the gameplay screen repaints.
        lda #1
        sta funds_dirty
        sta clock_dirty
        jsr power_mark_dirty
        jsr render_mark_view_dirty
        lda #0                            ; success
        rts
_odv_load_err_close:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_odv_load_err_open:
        lda #1                            ; non-zero = error
        rts

;---------------------------------------------------------------------------------------
; odv_dma_run: enhanced DMA, params patched in the inline list by the caller.
;---------------------------------------------------------------------------------------
odv_dma_run:
        lda #$00
        sta $D707
        .byte $80
odv_dma_src_mb:
        .byte 0
        .byte $81
odv_dma_dst_mb:
        .byte 0
        .byte $00
        .byte $00                         ; job: copy
odv_dma_size:
        .word 0
odv_dma_src:
        .word 0
odv_dma_src_bank:
        .byte 0
odv_dma_dst:
        .word 0
odv_dma_dst_bank:
        .byte 0
        .byte $00
        .word $0000
        rts

;=======================================================================================
; Helpers: build filenames with the various CBM-DOS suffixes; mouse-cell
; conversion; label/filename drawing.
;=======================================================================================

;---------------------------------------------------------------------------------------
; Build "<name>,S,R" into odv_full_name_buf.
;---------------------------------------------------------------------------------------
odv_build_read_name:
        jsr odv_copy_filename
        ldx odv_full_name_len
        lda #$2C
        sta odv_full_name_buf,x
        inx
        lda #$53
        sta odv_full_name_buf,x
        inx
        lda #$2C
        sta odv_full_name_buf,x
        inx
        lda #$52
        sta odv_full_name_buf,x
        inx
        stx odv_full_name_len
        rts

;---------------------------------------------------------------------------------------
; Build "<name>,S,W" into odv_full_name_buf.
;---------------------------------------------------------------------------------------
odv_build_write_name:
        jsr odv_copy_filename
        ldx odv_full_name_len
        lda #$2C
        sta odv_full_name_buf,x
        inx
        lda #$53
        sta odv_full_name_buf,x
        inx
        lda #$2C
        sta odv_full_name_buf,x
        inx
        lda #$57
        sta odv_full_name_buf,x
        inx
        stx odv_full_name_len
        rts

;---------------------------------------------------------------------------------------
; Build "S0:<name>" into odv_scratch_buf.
;---------------------------------------------------------------------------------------
odv_build_scratch_cmd:
        lda #$53                          ; 'S'
        sta odv_scratch_buf+0
        lda #$30                          ; '0'
        sta odv_scratch_buf+1
        lda #$3A                          ; ':'
        sta odv_scratch_buf+2
        ldx #0
_odv_bsc_copy:
        cpx odv_filename_len
        bcs _odv_bsc_done
        lda odv_filename_buf,x
        sta odv_scratch_buf+3,x
        inx
        bra _odv_bsc_copy
_odv_bsc_done:
        txa
        clc
        adc #3                            ; "S0:" prefix length
        sta odv_scratch_len
        rts

;---------------------------------------------------------------------------------------
; Copy odv_filename_buf -> odv_full_name_buf, set odv_full_name_len.
;---------------------------------------------------------------------------------------
odv_copy_filename:
        ldx #0
_odv_cf_loop:
        cpx odv_filename_len
        bcs _odv_cf_done
        lda odv_filename_buf,x
        sta odv_full_name_buf,x
        inx
        bra _odv_cf_loop
_odv_cf_done:
        stx odv_full_name_len
        rts

;---------------------------------------------------------------------------------------
; Remember current filename on successful save / load.
;---------------------------------------------------------------------------------------
odv_store_current_filename:
        lda odv_filename_len
        sta current_city_filename_len
        ldx #0
_odv_scf_loop:
        cpx odv_filename_len
        bcs _odv_scf_done
        lda odv_filename_buf,x
        sta current_city_filename,x
        inx
        bra _odv_scf_loop
_odv_scf_done:
        rts

;---------------------------------------------------------------------------------------
; mouse_x/y -> popup-local cell coords. Returns carry SET if inside the popup,
; with odv_click_col / odv_click_row populated. Carry CLEAR if outside.
;---------------------------------------------------------------------------------------
odv_mouse_to_popup_cell:
        ; Reject off-screen X.
        lda mouse_x+1
        bne _odv_mtpc_no
        lda mouse_x
        lsr
        lsr
        lsr
        sec
        sbc popup_l
        bcc _odv_mtpc_no
        cmp popup_w
        bcs _odv_mtpc_no
        sta odv_click_col
        lda mouse_y
        lsr
        lsr
        lsr
        sec
        sbc popup_t
        bcc _odv_mtpc_no
        cmp popup_h
        bcs _odv_mtpc_no
        sta odv_click_row
        sec
        rts
_odv_mtpc_no:
        clc
        rts

;---------------------------------------------------------------------------------------
; Try to append a key (ASCII) to the filename. Same rules as ovr-save's old
; sov_try_append: filter to A-Z, 0-9, '-', '.', uppercase the letters.
;---------------------------------------------------------------------------------------
odv_try_append_key:
        cmp #$61                          ; ASCII 'a'
        bcc _odv_tak_upper
        cmp #$7B
        bcs _odv_tak_other
        sec
        sbc #$20
        bra _odv_tak_accept
_odv_tak_upper:
        cmp #$41
        bcc _odv_tak_digit
        cmp #$5B
        bcc _odv_tak_accept
        bra _odv_tak_other
_odv_tak_digit:
        cmp #$30
        bcc _odv_tak_other
        cmp #$3A
        bcc _odv_tak_accept
_odv_tak_other:
        cmp #$2D
        beq _odv_tak_accept
        cmp #$2E
        beq _odv_tak_accept
        rts
_odv_tak_accept:
        ldx odv_filename_len
        cpx #ODV_FILENAME_MAX
        bcs _odv_tak_done
        sta odv_filename_buf,x
        inx
        stx odv_filename_len
        jsr odv_draw_filename
_odv_tak_done:
        rts

;---------------------------------------------------------------------------------------
; Draw the filename input on popup row 3, cols 1..ODV_FILENAME_MAX. Empty
; positions show UI_TILE_PANEL.
;---------------------------------------------------------------------------------------
odv_draw_filename:
        lda #0
        sta odv_draw_idx
_odv_df_loop:
        ldx odv_draw_idx
        cpx odv_filename_len
        bcs _odv_df_blank
        lda odv_filename_buf,x
        jsr odv_ascii_to_char
        bra _odv_df_stamp
_odv_df_blank:
        lda #UI_TILE_PANEL
_odv_df_stamp:
        pha
        lda odv_draw_idx
        clc
        adc popup_l
        adc #1                            ; col 1 of the popup (inset)
        tax
        clc
        lda popup_t
        adc #3                            ; row 3
        tay
        pla
        jsr set_fcm_char
        inc odv_draw_idx
        lda odv_draw_idx
        cmp #ODV_FILENAME_MAX
        bne _odv_df_loop
        rts

;---------------------------------------------------------------------------------------
; Stamp a char (A) at popup-local (X, 2). Used by the "FILE:" label.
;---------------------------------------------------------------------------------------
odv_stamp_at_popup_2:
        pha
        txa
        clc
        adc popup_l
        tax
        clc
        lda popup_t
        adc #2
        tay
        pla
        jmp set_fcm_char

;---------------------------------------------------------------------------------------
; Draw "OK" + "CANCEL" labels on popup row ODV_FN_BTN_ROW. Cell positions are
; popup-local: OK at cols 3-4, CANCEL at cols 8-13.
;---------------------------------------------------------------------------------------
odv_draw_ok_cancel:
        ; OK
        lda #UI_TEXT_O
        ldx #ODV_FN_OK_COL
        jsr _odv_doc_stamp
        lda #UI_TEXT_K
        ldx #(ODV_FN_OK_COL + 1)
        jsr _odv_doc_stamp
        ; CANCEL
        lda #UI_TEXT_C
        ldx #ODV_FN_CANCEL_COL
        jsr _odv_doc_stamp
        lda #UI_TEXT_A
        ldx #(ODV_FN_CANCEL_COL + 1)
        jsr _odv_doc_stamp
        lda #UI_TEXT_N
        ldx #(ODV_FN_CANCEL_COL + 2)
        jsr _odv_doc_stamp
        lda #UI_TEXT_C
        ldx #(ODV_FN_CANCEL_COL + 3)
        jsr _odv_doc_stamp
        lda #UI_TEXT_E
        ldx #(ODV_FN_CANCEL_COL + 4)
        jsr _odv_doc_stamp
        lda #UI_TEXT_L
        ldx #(ODV_FN_CANCEL_COL + 5)
        jsr _odv_doc_stamp
        rts
_odv_doc_stamp:
        pha
        txa
        clc
        adc popup_l
        tax
        clc
        lda popup_t
        adc #ODV_FN_BTN_ROW
        tay
        pla
        jmp set_fcm_char

;---------------------------------------------------------------------------------------
; Set the unified popup geometry every state uses (20 wide x 9 tall, centred
; horizontally on the 40-col screen, anchored at row 8). Keeps the panel a
; consistent size as the state machine walks the player through menu -> input
; -> confirm -> result so the visible window doesn't jump around.
;---------------------------------------------------------------------------------------
odv_set_uniform_geometry:
        lda #20
        sta popup_w
        lda #9
        sta popup_h
        lda #10
        sta popup_l
        lda #8
        sta popup_t
        rts

;---------------------------------------------------------------------------------------
; Stamp DISK_LINE_CHAR across the popup width on popup-local row A. Produces
; a horizontal divider line spanning the entire popup body.
;---------------------------------------------------------------------------------------
odv_draw_hline_row:
        sta odv_tmp                       ; popup-local row
        clc
        adc popup_t
        sta odv_tmp+1                     ; absolute row
        lda #0
        sta odv_dcl_idx                   ; col idx reused as the column counter
_odv_dhr_loop:
        ldx odv_dcl_idx
        cpx popup_w
        bcs _odv_dhr_done
        lda popup_l
        clc
        adc odv_dcl_idx
        tax
        ldy odv_tmp+1
        lda #DISK_LINE_CHAR
        jsr set_fcm_char
        inc odv_dcl_idx
        bra _odv_dhr_loop
_odv_dhr_done:
        rts

;---------------------------------------------------------------------------------------
; Stamp UI_TILE_PANEL across the popup_ok rectangle (POPUP_OK_W cols x
; POPUP_OK_H rows). Used to erase the framework's OK chrome on states that
; have their own buttons (MENU, FILENAME, CONFIRM).
;---------------------------------------------------------------------------------------
odv_blank_ok:
        lda #0
        sta odv_tmp                       ; row offset
_odv_blank_row:
        lda #0
        sta odv_tmp+1                     ; col offset
_odv_blank_col:
        lda #UI_TILE_PANEL
        pha
        lda odv_tmp+1
        clc
        adc popup_ok_col
        tax
        lda odv_tmp
        clc
        adc popup_ok_row
        tay
        pla
        jsr set_fcm_char
        inc odv_tmp+1
        lda odv_tmp+1
        cmp #POPUP_OK_W
        bne _odv_blank_col
        inc odv_tmp
        lda odv_tmp
        cmp #POPUP_OK_H
        bne _odv_blank_row
        rts

;---------------------------------------------------------------------------------------
; ASCII (in filename buffer) -> UI_TEXT_* char id.
;---------------------------------------------------------------------------------------
odv_ascii_to_char:
        cmp #$41
        bcc _odv_atc_digit
        cmp #$5B
        bcs _odv_atc_digit
        sec
        sbc #$41
        clc
        adc #UI_TEXT_A
        rts
_odv_atc_digit:
        cmp #$30
        bcc _odv_atc_dot
        cmp #$3A
        bcs _odv_atc_dot
        sec
        sbc #$30
        clc
        adc #UI_TEXT_0
        rts
_odv_atc_dot:
        cmp #$2D
        beq _odv_atc_punct_dash
        lda #UI_TEXT_DOT
        rts
_odv_atc_punct_dash:
        ; No UI_TEXT_DASH char in the glyph set; fall back to dot for
        ; rendering. The on-disk filename still uses '-' literally.
        lda #UI_TEXT_DOT
        rts

;---------------------------------------------------------------------------------------
; Draw a centred label. Caller pre-sets odv_dcl_lo / odv_dcl_hi / odv_dcl_len
; (string ptr + length), then passes the popup-local row in A.
;---------------------------------------------------------------------------------------
odv_draw_centered_label:
        sta odv_dcl_row
        ; col = popup_l + (popup_w - len) / 2
        sec
        lda popup_w
        sbc odv_dcl_len
        lsr
        clc
        adc popup_l
        sta odv_dcl_col
        clc
        lda popup_t
        adc odv_dcl_row
        sta odv_dcl_screen_row
        lda #0
        sta odv_dcl_idx
_odv_dcl_loop:
        ldy odv_dcl_idx
        cpy odv_dcl_len
        bcs _odv_dcl_done
        ; Re-seat PTR each iteration -- set_fcm_char clobbers it, so we can't
        ; rely on a one-time setup outside the loop.
        lda odv_dcl_lo
        sta PTR
        lda odv_dcl_hi
        sta PTR+1
        lda (PTR),y
        pha
        tya
        clc
        adc odv_dcl_col
        tax
        ldy odv_dcl_screen_row
        pla
        jsr set_fcm_char
        inc odv_dcl_idx
        bra _odv_dcl_loop
_odv_dcl_done:
        rts

;=======================================================================================
; Strings & data
;=======================================================================================

; Titles (each byte = UI_TEXT_* char id, like the other overlays).
odv_title_disk:
        .byte UI_TEXT_D, UI_TEXT_I, UI_TEXT_S, UI_TEXT_K
odv_title_disk_len = * - odv_title_disk

odv_title_load:
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D
odv_title_load_len = * - odv_title_load

odv_title_save:
        .byte UI_TEXT_S, UI_TEXT_A, UI_TEXT_V, UI_TEXT_E
odv_title_save_len = * - odv_title_save

; Menu button labels. UI_TILE_PANEL acts as a "space" character -- it stamps
; the popup's panel-background tile, which blends in with the rest of the
; popup so the gap between words reads as visual whitespace.
odv_label_load_city:
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D, UI_TILE_PANEL, UI_TEXT_C, UI_TEXT_I, UI_TEXT_T, UI_TEXT_Y
odv_label_load_city_len = * - odv_label_load_city

odv_label_save_city:
        .byte UI_TEXT_S, UI_TEXT_A, UI_TEXT_V, UI_TEXT_E, UI_TILE_PANEL, UI_TEXT_C, UI_TEXT_I, UI_TEXT_T, UI_TEXT_Y
odv_label_save_city_len = * - odv_label_save_city

odv_label_cancel:
        .byte UI_TEXT_C, UI_TEXT_A, UI_TEXT_N, UI_TEXT_C, UI_TEXT_E, UI_TEXT_L
odv_label_cancel_len = * - odv_label_cancel

; "FILE EXISTS." / "REPLACE?"  (UI_TILE_PANEL = visual space, see labels above)
odv_msg_exists:
        .byte UI_TEXT_F, UI_TEXT_I, UI_TEXT_L, UI_TEXT_E, UI_TILE_PANEL, UI_TEXT_E, UI_TEXT_X, UI_TEXT_I, UI_TEXT_S, UI_TEXT_T, UI_TEXT_S, UI_TEXT_DOT
odv_msg_exists_len = * - odv_msg_exists

odv_msg_replace:
        .byte UI_TEXT_R, UI_TEXT_E, UI_TEXT_P, UI_TEXT_L, UI_TEXT_A, UI_TEXT_C, UI_TEXT_E
odv_msg_replace_len = * - odv_msg_replace

; Result messages.
odv_msg_saved:
        .byte UI_TEXT_C, UI_TEXT_I, UI_TEXT_T, UI_TEXT_Y, UI_TILE_PANEL, UI_TEXT_S, UI_TEXT_A, UI_TEXT_V, UI_TEXT_E, UI_TEXT_D
odv_msg_saved_len = * - odv_msg_saved

odv_msg_loaded:
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D, UI_TEXT_E, UI_TEXT_D
odv_msg_loaded_len = * - odv_msg_loaded

odv_msg_load_err:
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D, UI_TILE_PANEL, UI_TEXT_E, UI_TEXT_R, UI_TEXT_R, UI_TEXT_O, UI_TEXT_R
odv_msg_load_err_len = * - odv_msg_load_err

; 16-byte save file header.
odv_save_header:
        .byte $4D, $45, $47, $41, $53, $49, $4D, $00, $02, $00, $00, $00, $00, $00, $00, $00

odv_magic_expected:
        .byte $4D, $45, $47, $41, $53, $49, $4D

;---------------------------------------------------------------------------------------
; State / scratch
;---------------------------------------------------------------------------------------
odv_state:                  .byte 0
odv_state_changed:          .byte 0
odv_exit_flag:              .byte 0
odv_result_msg:             .byte 0       ; RESULT_* code
odv_result_kind:            .byte 0       ; RESULT_KIND_LOAD or _SAVE
odv_load_result:            .byte 0
odv_load_version:           .byte 0

odv_filename_buf:           .fill ODV_FILENAME_MAX, 0
odv_filename_len:           .byte 0

odv_full_name_buf:          .fill ODV_FILENAME_MAX + 4, 0
odv_full_name_len:          .byte 0

odv_scratch_buf:            .fill ODV_FILENAME_MAX + 3, 0
odv_scratch_len:            .byte 0

odv_key:                    .byte 0
odv_draw_idx:               .byte 0
odv_click_col:              .byte 0
odv_click_row:              .byte 0
odv_remaining:              .word 0
odv_chunk_off:              .word 0
odv_chunk_size_lo:          .byte 0
odv_chunk_size_hi:          .byte 0
odv_title_ptr:              .word 0
odv_title_len_save:         .byte 0
odv_tmp:                    .byte 0, 0
odv_tmp_ptr:                .word 0
odv_tmp_len:                .byte 0

odv_dcl_row:                .byte 0       ; centred-label scratch
odv_dcl_col:                .byte 0
odv_dcl_screen_row:         .byte 0
odv_dcl_lo:                 .byte 0
odv_dcl_hi:                 .byte 0
odv_dcl_len:                .byte 0
odv_dcl_idx:                .byte 0

;=======================================================================================
; Chunk buffer at $AF00 -- last 256 bytes of the overlay window. Pad before it
; so the buffer is aligned and the overlay ends at exactly $B000 so the loader
; copies the full window.
;=======================================================================================
        .fill $AF00 - *, 0
odv_chunk_buf:
        .fill 256, 0

        .cerror * != $B000, "ovr-disk overlay must end at exactly $B000"
