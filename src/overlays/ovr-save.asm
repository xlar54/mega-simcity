;=======================================================================================
; Save overlay (PRG, compiles to $A000).
;
; Loaded from disk at boot into Attic ($85.0000) by boot_load_ovr_save; on
; SAVE click the main game DMAs this overlay from Attic to $A000 and enters via
; jsr ovr_save_main. The overlay drives its own modal loop -- mouse + key
; polling, popup drawing, filename input -- and on OK confirmation writes the
; save file via the streamed-BSOUT path:
;
;   16 bytes  header     "MEGASIM" + ver byte ($02) + reserved
;    4 bytes  funds      (32-bit, little-endian from main game's `funds` var)
;    3 bytes  date       sim_month, sim_year_lo, sim_year_hi
;    1 byte   plant cnt  plant_origin_count
;   32 bytes  plant_x    plant_origin_x[0..31]
;   32 bytes  plant_y    plant_origin_y[0..31]
;   32 bytes  plant_str  plant_origin_struct[0..31]
; 48000 bytes map        CELL_COLS * CELL_ROWS, streamed from Attic in 256-byte
;                        chunks via DMA -> CPU buffer -> KERNAL_CHROUT loop
;
; Format version 2 -- the plant_origin block is needed so power flooding works
; right after load. Without it, the plant_origin list is stale and zone
; powering breaks. The load overlay verifies version >= 2.
;
; Architecture: the overlay imports the main game's label file
; (target/mega-simcity.lbl) so it can call into helpers like overlay_open,
; set_fcm_char, mouse_poll, etc. without duplicating their code. The build
; script links save_overlay AFTER main game so the labels are current.
;
; Real-hardware caveat: in-game KERNAL I/O (the OPEN/CHKOUT/CHROUT/CLOSE call
; chain below) depends on the boot environment being intact. This codebase
; doesn't install a custom MAP and doesn't touch $00/$01/$D030, so on Xemu the
; calls work. Real hardware behaviour is untested; TODO.md notes the
; trampoline work needed for hardened in-game KERNAL I/O.
;=======================================================================================

        .cpu "45gs02"

        ; Main game labels: every global symbol assembled into mega-simcity
        ; (function addresses, constants like POPUP_OK_COL, UI_TEXT_*, etc.).
        ; Pure `name = $addr` assignments -- they take no output space.
        .include "../../target/mega-simcity.lbl"

        * = OVR_WINDOW_ADDR

SOV_FILENAME_MAX = 12          ; max chars the user can type
MAP_SAVE_SIZE    = CELL_COLS * CELL_ROWS   ; 48000

;---------------------------------------------------------------------------------------
; ovr_save_main
; Entry point. Caller has DMA'd this overlay to $A000 and jsr'd here. Drives
; its own modal loop until the user confirms (OK click or Enter) or cancels
; (ESC). On confirm, streams the save file to disk. rts back to caller.
;---------------------------------------------------------------------------------------
ovr_save_main:
        ; --- open the popup (default 16x8 centred) with title "SAVE.AS" ---
        jsr overlay_set_default_geometry
        lda #<sov_title
        ldx #>sov_title
        ldy #sov_title_len
        jsr overlay_open

        ; Reset filename buffer + draw the input area
        lda #0
        sta sov_filename_len
        jsr sov_draw_label
        jsr sov_draw_filename

        ; Drain any stale keystroke from the queue so the SAVE click's release
        ; doesn't accidentally land in the input field.
        lda #0
        sta MEGA_KEYQUEUE

_sov_loop:
        jsr wait_frame
        jsr mouse_poll
        ; Main game's app_loop is blocked while we run, so it isn't refreshing
        ; the pointer sprite -- do that here so the cursor tracks the mouse
        ; while the popup is up. Cursor block / selector are static for this
        ; modal, so just the pointer.
        jsr mouse_position_pointer_sprite

        ; --- keyboard ---
        lda MEGA_KEYQUEUE
        beq _sov_after_key
        sta sov_key
        lda #0
        sta MEGA_KEYQUEUE
        lda sov_key
        cmp #$0D                    ; CR / Enter -> confirm
        beq _sov_do_save
        cmp #$1B                    ; ESC -> cancel
        beq _sov_close_only
        cmp #$14                    ; CBM DEL
        beq _sov_backspace
        cmp #$08                    ; ASCII backspace
        beq _sov_backspace
        jsr sov_try_append          ; otherwise: printable -> append

_sov_after_key:
        ; --- mouse click on OK ---
        lda mouse_left_click
        beq _sov_loop
        lda mouse_x+1
        bne _sov_loop
        lda mouse_x
        cmp popup_ok_x_pixel
        bcc _sov_loop
        cmp popup_ok_x_pixel_end
        bcs _sov_loop
        lda mouse_y
        cmp popup_ok_y_pixel
        bcc _sov_loop
        cmp popup_ok_y_pixel_end
        bcs _sov_loop
        ; fall through to confirm

_sov_do_save:
        jsr audio_click
        lda sov_filename_len
        beq _sov_close              ; empty name -> just close, no save
        jsr sov_disk_save
        bra _sov_close

_sov_backspace:
        ldx sov_filename_len
        beq _sov_after_key
        dex
        stx sov_filename_len
        jsr sov_draw_filename
        bra _sov_after_key

_sov_close_only:
        jsr audio_click
_sov_close:
        jsr overlay_close
        rts

;---------------------------------------------------------------------------------------
; sov_try_append: A = key (ASCII byte from MEGA_KEYQUEUE). If printable for
; filenames, convert lowercase to uppercase and append to sov_filename_buf
; (up to SOV_FILENAME_MAX chars). Otherwise ignore.
;
; Uses raw hex throughout because 64tass's default encoding maps 'a' to $41
; (PETSCII unshifted) and 'A' to $C1 (PETSCII shifted), neither of which
; matches the ASCII bytes MEGA_KEYQUEUE actually produces ($61 for 'a', $41
; for 'A'). Hex literals keep the filter and the hardware speaking the same
; language regardless of 64tass's encoding mode.
;---------------------------------------------------------------------------------------
sov_try_append:
        cmp #$61                    ; ASCII 'a'
        bcc _sta_upper
        cmp #$7B                    ; ASCII 'z'+1
        bcs _sta_other
        sec
        sbc #$20                    ; lowercase -> uppercase ($61..$7A -> $41..$5A)
        bra _sta_accept
_sta_upper:
        cmp #$41                    ; ASCII 'A'
        bcc _sta_digit
        cmp #$5B                    ; ASCII 'Z'+1
        bcc _sta_accept
        bra _sta_other
_sta_digit:
        cmp #$30                    ; ASCII '0'
        bcc _sta_other
        cmp #$3A                    ; ASCII '9'+1
        bcc _sta_accept
        ; fall through
_sta_other:
        cmp #$2D                    ; ASCII '-'
        beq _sta_accept
        cmp #$2E                    ; ASCII '.'
        beq _sta_accept
        rts
_sta_accept:
        ldx sov_filename_len
        cpx #SOV_FILENAME_MAX
        bcs _sta_done
        sta sov_filename_buf,x
        inx
        stx sov_filename_len
        jsr sov_draw_filename
_sta_done:
        rts

;---------------------------------------------------------------------------------------
; sov_draw_label: stamp "FILE:" at popup row 2, starting col POPUP_DEFAULT_L+1.
;---------------------------------------------------------------------------------------
sov_draw_label:
        lda #UI_TEXT_F
        ldx #(POPUP_DEFAULT_L + 1)
        ldy #(POPUP_DEFAULT_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_I
        ldx #(POPUP_DEFAULT_L + 2)
        ldy #(POPUP_DEFAULT_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_L
        ldx #(POPUP_DEFAULT_L + 3)
        ldy #(POPUP_DEFAULT_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_E
        ldx #(POPUP_DEFAULT_L + 4)
        ldy #(POPUP_DEFAULT_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_COLON
        ldx #(POPUP_DEFAULT_L + 5)
        ldy #(POPUP_DEFAULT_T + 2)
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; sov_draw_filename: stamp the SOV_FILENAME_MAX-wide input row at popup row 3,
; cols POPUP_DEFAULT_L+1 .. POPUP_DEFAULT_L+SOV_FILENAME_MAX. Typed chars use their glyph;
; empty positions show UI_TILE_PANEL (the popup's grey).
;---------------------------------------------------------------------------------------
sov_draw_filename:
        lda #0
        sta sov_draw_idx
_sdf_loop:
        ldx sov_draw_idx
        cpx sov_filename_len
        bcs _sdf_blank
        lda sov_filename_buf,x
        jsr sov_ascii_to_char       ; A = ASCII -> A = UI_TEXT_* char id
        bra _sdf_stamp
_sdf_blank:
        lda #UI_TILE_PANEL
_sdf_stamp:
        pha
        lda sov_draw_idx
        clc
        adc #(POPUP_DEFAULT_L + 1)
        tax
        ldy #(POPUP_DEFAULT_T + 3)
        pla
        jsr set_fcm_char
        inc sov_draw_idx
        lda sov_draw_idx
        cmp #SOV_FILENAME_MAX
        bne _sdf_loop
        rts

;---------------------------------------------------------------------------------------
; sov_ascii_to_char: A = ASCII -> A = UI_TEXT_* char id. The filename buffer
; only ever contains uppercase ASCII A-Z (sov_try_append converts), digits
; 0-9, and the dash / dot punctuation. Hex literals for the same reason as
; sov_try_append: 64tass's default encoding doesn't match the ASCII bytes the
; buffer holds.
;---------------------------------------------------------------------------------------
sov_ascii_to_char:
        cmp #$41                    ; ASCII 'A'
        bcc _atc_digit
        cmp #$5B                    ; ASCII 'Z'+1
        bcs _atc_digit
        sec
        sbc #$41                    ; offset within A-Z
        clc
        adc #UI_TEXT_A
        rts
_atc_digit:
        cmp #$30                    ; ASCII '0'
        bcc _atc_dot
        cmp #$3A                    ; ASCII '9'+1
        bcs _atc_dot
        sec
        sbc #$30                    ; offset within 0-9
        clc
        adc #UI_TEXT_0
        rts
_atc_dot:
        lda #UI_TEXT_DOT
        rts

;---------------------------------------------------------------------------------------
; sov_disk_save: build the OPEN filename ("<name>,S,W"), open the file, stream
; the save data via KERNAL_CHROUT, close. Silently bails on any error.
;---------------------------------------------------------------------------------------
sov_disk_save:
        jsr sov_build_full_name

        ; SETLFS 1, 8, 1 -- channel 1, device 8 (drive), secondary 1 (write).
        lda #1
        ldx #8
        ldy #1
        jsr KERNAL_SETLFS

        ; SETBNK 0/0 -- filename lives in CPU bank 0.
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        ; SETNAM <len>, <buf>
        lda sov_full_name_len
        ldx #<sov_full_name_buf
        ldy #>sov_full_name_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _sov_save_done          ; error -> bail without close

        ldx #1
        jsr KERNAL_CHKOUT
        bcs _sov_save_close

        ; --- header (16 bytes) ---
        ldx #0
_sds_hdr:
        lda sov_header,x
        jsr KERNAL_CHROUT
        inx
        cpx #16
        bne _sds_hdr

        ; --- funds (4 bytes) ---
        lda funds
        jsr KERNAL_CHROUT
        lda funds+1
        jsr KERNAL_CHROUT
        lda funds+2
        jsr KERNAL_CHROUT
        lda funds+3
        jsr KERNAL_CHROUT

        ; --- clock: month (1), year (2) ---
        lda sim_month
        jsr KERNAL_CHROUT
        lda sim_year
        jsr KERNAL_CHROUT
        lda sim_year+1
        jsr KERNAL_CHROUT

        ; --- plant origins: count (1), x[PLANT_MAX], y[PLANT_MAX], struct[PLANT_MAX] ---
        lda plant_origin_count
        jsr KERNAL_CHROUT
        ldx #0
_sds_plant_x:
        lda plant_origin_x,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _sds_plant_x
        ldx #0
_sds_plant_y:
        lda plant_origin_y,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _sds_plant_y
        ldx #0
_sds_plant_s:
        lda plant_origin_struct,x
        jsr KERNAL_CHROUT
        inx
        cpx #PLANT_MAX
        bne _sds_plant_s

        ; --- map cells (MAP_SAVE_SIZE bytes, in 256-byte DMA chunks) ---
        lda #<MAP_SAVE_SIZE
        sta sov_remaining
        lda #>MAP_SAVE_SIZE
        sta sov_remaining+1
        lda #0
        sta sov_chunk_src
        sta sov_chunk_src+1
_sds_map_loop:
        ; If remaining == 0, done.
        lda sov_remaining
        ora sov_remaining+1
        beq _sov_save_close
        ; Pick chunk size: 256 if remaining >= 256, else remaining low byte.
        lda sov_remaining+1
        beq _sds_partial
        ; full 256-byte chunk
        lda #0
        sta sov_chunk_size_lo
        lda #1
        sta sov_chunk_size_hi
        bra _sds_set_dma
_sds_partial:
        lda sov_remaining
        sta sov_chunk_size_lo
        lda #0
        sta sov_chunk_size_hi
_sds_set_dma:
        ; Write the chunk-specific DMA-list fields and trigger.
        lda sov_chunk_size_lo
        sta sov_dma_size
        lda sov_chunk_size_hi
        sta sov_dma_size+1
        lda sov_chunk_src
        sta sov_dma_src
        lda sov_chunk_src+1
        sta sov_dma_src+1
        jsr sov_dma_run

        ; CHROUT chunk_size bytes from the buffer. Full-chunk case (size=256)
        ; is handled by the X=0..255 wrap.
        ldx #0
        lda sov_chunk_size_hi
        bne _sds_bsout_full         ; size_hi == 1 -> 256 bytes
_sds_bsout_short:
        lda sov_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        cpx sov_chunk_size_lo
        bne _sds_bsout_short
        bra _sds_advance
_sds_bsout_full:
        lda sov_chunk_buf,x
        jsr KERNAL_CHROUT
        inx
        bne _sds_bsout_full

_sds_advance:
        ; src += chunk_size, remaining -= chunk_size  (16-bit each)
        clc
        lda sov_chunk_src
        adc sov_chunk_size_lo
        sta sov_chunk_src
        lda sov_chunk_src+1
        adc sov_chunk_size_hi
        sta sov_chunk_src+1
        sec
        lda sov_remaining
        sbc sov_chunk_size_lo
        sta sov_remaining
        lda sov_remaining+1
        sbc sov_chunk_size_hi
        sta sov_remaining+1
        bra _sds_map_loop

_sov_save_close:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_sov_save_done:
        rts

;---------------------------------------------------------------------------------------
; sov_build_full_name: copy sov_filename_buf to sov_full_name_buf, append
; the CBM-DOS suffix ",S,W" (sequential file, write mode). The result is the
; full filename SETNAM expects.
;---------------------------------------------------------------------------------------
sov_build_full_name:
        ldx #0
_sbfn_copy:
        cpx sov_filename_len
        bcs _sbfn_copy_done
        lda sov_filename_buf,x
        sta sov_full_name_buf,x
        inx
        bra _sbfn_copy
_sbfn_copy_done:
        ; Append ",S,W" -- 4 bytes. Hex literals so the on-disk filename ends
        ; up as ASCII regardless of 64tass's source encoding.
        lda #$2C                    ; ASCII ','
        sta sov_full_name_buf,x
        inx
        lda #$53                    ; ASCII 'S'
        sta sov_full_name_buf,x
        inx
        lda #$2C
        sta sov_full_name_buf,x
        inx
        lda #$57                    ; ASCII 'W'
        sta sov_full_name_buf,x
        inx
        stx sov_full_name_len
        rts

;---------------------------------------------------------------------------------------
; sov_dma_run: trigger an enhanced DMA from Attic (MB ATTIC_MAP_MB, addr
; sov_dma_src, bank ATTIC_MAP_BANK) to sov_chunk_buf, sov_dma_size bytes.
; The inline list bytes get patched per chunk by sov_disk_save's loop.
;---------------------------------------------------------------------------------------
sov_dma_run:
        lda #$00
        sta $D707
        .byte $80, ATTIC_MAP_MB
        .byte $81, $00
        .byte $00
        .byte $00                   ; job: copy
sov_dma_size:
        .word 0                     ; bytes (patched per chunk)
sov_dma_src:
        .word 0                     ; src addr (patched per chunk)
        .byte ATTIC_MAP_BANK
        .word sov_chunk_buf
        .byte $00
        .byte $00
        .word $0000
        rts

;---------------------------------------------------------------------------------------
; Strings & data
;---------------------------------------------------------------------------------------

; Title: "SAVE.AS"
sov_title:
        .byte UI_TEXT_S, UI_TEXT_A, UI_TEXT_V, UI_TEXT_E, UI_TEXT_DOT, UI_TEXT_A, UI_TEXT_S
sov_title_len = * - sov_title

; 16-byte save file header: "MEGASIM" + null + version + 7 reserved.
; Hex bytes (not .text) because 64tass's default encoding turns 'M' into
; PETSCII shifted $CD instead of ASCII $4D, and the load overlay's magic
; check expects raw ASCII.
sov_header:
        .byte $4D, $45, $47, $41, $53, $49, $4D     ; "MEGASIM" in ASCII
        .byte $00, $02, $00, $00, $00, $00, $00, $00, $00

; --- scratch ---
sov_key:                .byte 0
sov_draw_idx:           .byte 0
sov_remaining:          .word 0
sov_chunk_src:          .word 0
sov_chunk_size_lo:      .byte 0
sov_chunk_size_hi:      .byte 0

sov_filename_buf:       .fill SOV_FILENAME_MAX, 0
sov_filename_len:       .byte 0

sov_full_name_buf:      .fill SOV_FILENAME_MAX + 4, 0   ; +4 for ",S,W"
sov_full_name_len:      .byte 0

;---------------------------------------------------------------------------------------
; Chunk buffer at $AF00 (last 256 bytes of the overlay window) -- DMA target
; for each Attic chunk. Right at the end of the $A000-$AFFF region.
;---------------------------------------------------------------------------------------
        .fill $AF00 - *, 0
sov_chunk_buf:
        .fill 256, 0

        ; Sanity: the assembled overlay must end at exactly $B000 so the boot
        ; loader copies the full OVR_WINDOW_SIZE bytes.
        .cerror * != OVR_WINDOW_ADDR + OVR_WINDOW_SIZE, "save overlay overflowed its $1000-byte window"
