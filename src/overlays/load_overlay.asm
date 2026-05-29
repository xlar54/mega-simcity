;=======================================================================================
; Load overlay (PRG, compiles to $A000 -- shared window with save_overlay).
;
; Loaded from disk at boot into Attic ($86.0000) by boot_load_load_overlay; on
; LOAD click the main game DMAs this overlay from Attic to $A000 and enters via
; jsr load_overlay_main. The overlay drives its own modal loop (mouse + key
; polling, popup drawing, filename input) and on OK confirmation reads the
; save file via streamed CHRIN:
;
;   16 bytes  header     "MEGASIM" + ver byte ($02) + reserved -- verified
;    4 bytes  funds      -> funds[0..3]
;    3 bytes  date       -> sim_month, sim_year, sim_year+1
;    1 byte   plant cnt  -> plant_origin_count
;   32 bytes  plant_x    -> plant_origin_x[0..31]
;   32 bytes  plant_y    -> plant_origin_y[0..31]
;   32 bytes  plant_str  -> plant_origin_struct[0..31]
; 48000 bytes map        -> Attic map cells, in 256-byte CHRIN-fill + DMA-up
;                          chunks (CHRIN -> CPU buffer -> DMA to Attic)
;
; After the load, the overlay sets funds_dirty / clock_dirty, calls
; render_mark_view_dirty (so the next render_frame repaints the viewport from
; the loaded map) and power_mark_dirty (so the power network re-floods from
; the loaded plant_origin list). The overlay's overlay_close call also marks
; the view dirty, so closing handles screen refresh on its own.
;
; Format compatibility: only ver == $02 is accepted. v1 saves (no plant block)
; would corrupt plant_origin so the version check below rejects them.
;=======================================================================================

        .cpu "45gs02"

        .include "../../target/mega-simcity.lbl"

        * = LOAD_OVERLAY_ADDR

LOV_FILENAME_MAX = 12
MAP_LOAD_SIZE    = CELL_COLS * CELL_ROWS

;---------------------------------------------------------------------------------------
; Entry. Caller has DMA'd this overlay to $A000 and jsr'd here.
;---------------------------------------------------------------------------------------
load_overlay_main:
        lda #<lov_title
        ldx #>lov_title
        ldy #lov_title_len
        jsr overlay_open

        lda #0
        sta lov_filename_len
        jsr lov_draw_label
        jsr lov_draw_filename

        ; Drain any stale keystroke (the LOAD click's release).
        lda #0
        sta MEGA_KEYQUEUE

_lov_loop:
        jsr wait_frame
        jsr mouse_poll
        jsr mouse_position_pointer_sprite

        ; --- keyboard ---
        lda MEGA_KEYQUEUE
        beq _lov_after_key
        sta lov_key
        lda #0
        sta MEGA_KEYQUEUE
        lda lov_key
        cmp #$0D                    ; Enter -> confirm
        beq _lov_do_load
        cmp #$1B                    ; ESC -> cancel
        beq _lov_close_only
        cmp #$14                    ; CBM DEL
        beq _lov_backspace
        cmp #$08                    ; ASCII BS
        beq _lov_backspace
        jsr lov_try_append

_lov_after_key:
        ; --- mouse click on OK ---
        lda mouse_left_click
        beq _lov_loop
        lda mouse_x+1
        bne _lov_loop
        lda mouse_x
        cmp #POPUP_OK_COL * 8
        bcc _lov_loop
        cmp #(POPUP_OK_COL + POPUP_OK_W) * 8
        bcs _lov_loop
        lda mouse_y
        cmp #POPUP_OK_ROW * 8
        bcc _lov_loop
        cmp #(POPUP_OK_ROW + POPUP_OK_H) * 8
        bcs _lov_loop

_lov_do_load:
        jsr audio_click
        lda lov_filename_len
        beq _lov_close              ; empty name -> just close
        jsr lov_disk_load
        bra _lov_close

_lov_backspace:
        ldx lov_filename_len
        beq _lov_after_key
        dex
        stx lov_filename_len
        jsr lov_draw_filename
        bra _lov_after_key

_lov_close_only:
        jsr audio_click
_lov_close:
        jsr overlay_close
        rts

;---------------------------------------------------------------------------------------
; lov_try_append: same filter as save_overlay -- A-Z, 0-9, dash, dot. Hex
; literals because 64tass's default encoding doesn't match the ASCII bytes
; MEGA_KEYQUEUE produces.
;---------------------------------------------------------------------------------------
lov_try_append:
        cmp #$61                    ; ASCII 'a'
        bcc _lta_upper
        cmp #$7B                    ; 'z'+1
        bcs _lta_other
        sec
        sbc #$20                    ; lowercase -> uppercase
        bra _lta_accept
_lta_upper:
        cmp #$41                    ; 'A'
        bcc _lta_digit
        cmp #$5B                    ; 'Z'+1
        bcc _lta_accept
        bra _lta_other
_lta_digit:
        cmp #$30                    ; '0'
        bcc _lta_other
        cmp #$3A                    ; '9'+1
        bcc _lta_accept
_lta_other:
        cmp #$2D                    ; '-'
        beq _lta_accept
        cmp #$2E                    ; '.'
        beq _lta_accept
        rts
_lta_accept:
        ldx lov_filename_len
        cpx #LOV_FILENAME_MAX
        bcs _lta_done
        sta lov_filename_buf,x
        inx
        stx lov_filename_len
        jsr lov_draw_filename
_lta_done:
        rts

;---------------------------------------------------------------------------------------
; lov_draw_label: stamp "FILE:" at popup row 2.
;---------------------------------------------------------------------------------------
lov_draw_label:
        lda #UI_TEXT_F
        ldx #(POPUP_L + 1)
        ldy #(POPUP_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_I
        ldx #(POPUP_L + 2)
        ldy #(POPUP_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_L
        ldx #(POPUP_L + 3)
        ldy #(POPUP_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_E
        ldx #(POPUP_L + 4)
        ldy #(POPUP_T + 2)
        jsr set_fcm_char
        lda #UI_TEXT_COLON
        ldx #(POPUP_L + 5)
        ldy #(POPUP_T + 2)
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; lov_draw_filename: 12-char input row at popup row 3. Empty slots show
; UI_TILE_PANEL.
;---------------------------------------------------------------------------------------
lov_draw_filename:
        lda #0
        sta lov_draw_idx
_ldf_loop:
        ldx lov_draw_idx
        cpx lov_filename_len
        bcs _ldf_blank
        lda lov_filename_buf,x
        jsr lov_ascii_to_char
        bra _ldf_stamp
_ldf_blank:
        lda #UI_TILE_PANEL
_ldf_stamp:
        pha
        lda lov_draw_idx
        clc
        adc #(POPUP_L + 1)
        tax
        ldy #(POPUP_T + 3)
        pla
        jsr set_fcm_char
        inc lov_draw_idx
        lda lov_draw_idx
        cmp #LOV_FILENAME_MAX
        bne _ldf_loop
        rts

;---------------------------------------------------------------------------------------
; lov_ascii_to_char: ASCII uppercase A-Z / 0-9 -> UI_TEXT_* char id.
;---------------------------------------------------------------------------------------
lov_ascii_to_char:
        cmp #$41                    ; 'A'
        bcc _lac_digit
        cmp #$5B                    ; 'Z'+1
        bcs _lac_digit
        sec
        sbc #$41
        clc
        adc #UI_TEXT_A
        rts
_lac_digit:
        cmp #$30
        bcc _lac_dot
        cmp #$3A
        bcs _lac_dot
        sec
        sbc #$30
        clc
        adc #UI_TEXT_0
        rts
_lac_dot:
        lda #UI_TEXT_DOT
        rts

;---------------------------------------------------------------------------------------
; lov_disk_load: open the file for read, verify header, stream into game state.
; Silently bails on OPEN / CHKIN / magic / version errors. Always marks the
; redraw / power-recompute flags before returning so the next frame reflects
; whatever made it in (or stays consistent if the load aborted early).
;---------------------------------------------------------------------------------------
lov_disk_load:
        jsr lov_build_full_name

        ; SETLFS 1, 8, 0 -- secondary 0 = read.
        lda #1
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS

        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK

        lda lov_full_name_len
        ldx #<lov_full_name_buf
        ldy #>lov_full_name_buf
        jsr KERNAL_SETNAM

        jsr KERNAL_OPEN
        bcs _lov_load_done

        ldx #1
        jsr KERNAL_CHKIN
        bcs _lov_load_close

        ; --- read 16-byte header into scratch + verify magic + version ---
        ldx #0
_ldl_hdr:
        jsr KERNAL_CHRIN
        sta lov_header_check,x
        inx
        cpx #16
        bne _ldl_hdr
        ; magic: bytes 0..6 must be "MEGASIM"
        ldx #0
_ldl_magic:
        lda lov_header_check,x
        cmp lov_magic_expected,x
        bne _lov_load_close         ; mismatch -> abort
        inx
        cpx #7
        bne _ldl_magic
        ; version: accept $01 (legacy -- no plant block) or $02 (with plant block).
        ; Cache the version so the plant-section read knows whether to skip it.
        lda lov_header_check+8
        cmp #$01
        beq _ldl_ver_ok
        cmp #$02
        bne _lov_load_close
_ldl_ver_ok:
        sta lov_format_ver

        ; --- funds (4 bytes) ---
        jsr KERNAL_CHRIN
        sta funds
        jsr KERNAL_CHRIN
        sta funds+1
        jsr KERNAL_CHRIN
        sta funds+2
        jsr KERNAL_CHRIN
        sta funds+3

        ; --- clock: month (1), year (2) ---
        jsr KERNAL_CHRIN
        sta sim_month
        jsr KERNAL_CHRIN
        sta sim_year
        jsr KERNAL_CHRIN
        sta sim_year+1

        ; --- plant origins: v2 has count + x[32] + y[32] + struct[32]. v1
        ; saves predate this section; for a v1 file just clear the count so
        ; the power engine doesn't seed from stale plant_origin entries.
        lda lov_format_ver
        cmp #$02
        bne _ldl_skip_plant
        jsr KERNAL_CHRIN
        sta plant_origin_count
        ldx #0
_ldl_plant_x:
        jsr KERNAL_CHRIN
        sta plant_origin_x,x
        inx
        cpx #PLANT_MAX
        bne _ldl_plant_x
        ldx #0
_ldl_plant_y:
        jsr KERNAL_CHRIN
        sta plant_origin_y,x
        inx
        cpx #PLANT_MAX
        bne _ldl_plant_y
        ldx #0
_ldl_plant_s:
        jsr KERNAL_CHRIN
        sta plant_origin_struct,x
        inx
        cpx #PLANT_MAX
        bne _ldl_plant_s
        bra _ldl_after_plant
_ldl_skip_plant:
        lda #0
        sta plant_origin_count
_ldl_after_plant:

        ; --- map cells (MAP_LOAD_SIZE bytes, in 256-byte CHRIN-fill+DMA chunks) ---
        lda #<MAP_LOAD_SIZE
        sta lov_remaining
        lda #>MAP_LOAD_SIZE
        sta lov_remaining+1
        lda #0
        sta lov_chunk_dst
        sta lov_chunk_dst+1
_ldl_map_loop:
        lda lov_remaining
        ora lov_remaining+1
        beq _lov_load_close
        ; chunk size = min(256, remaining)
        lda lov_remaining+1
        beq _ldl_partial
        lda #0
        sta lov_chunk_size_lo
        lda #1
        sta lov_chunk_size_hi
        bra _ldl_fill
_ldl_partial:
        lda lov_remaining
        sta lov_chunk_size_lo
        lda #0
        sta lov_chunk_size_hi
_ldl_fill:
        ; fill lov_chunk_buf via CHRIN
        ldx #0
        lda lov_chunk_size_hi
        bne _ldl_fill_full
_ldl_fill_short:
        jsr KERNAL_CHRIN
        sta lov_chunk_buf,x
        inx
        cpx lov_chunk_size_lo
        bne _ldl_fill_short
        bra _ldl_dma
_ldl_fill_full:
        jsr KERNAL_CHRIN
        sta lov_chunk_buf,x
        inx
        bne _ldl_fill_full
_ldl_dma:
        ; DMA the chunk up to Attic at offset lov_chunk_dst
        lda lov_chunk_size_lo
        sta lov_dma_size
        lda lov_chunk_size_hi
        sta lov_dma_size+1
        lda lov_chunk_dst
        sta lov_dma_dst
        lda lov_chunk_dst+1
        sta lov_dma_dst+1
        jsr lov_dma_run
        ; advance dst, decrement remaining
        clc
        lda lov_chunk_dst
        adc lov_chunk_size_lo
        sta lov_chunk_dst
        lda lov_chunk_dst+1
        adc lov_chunk_size_hi
        sta lov_chunk_dst+1
        sec
        lda lov_remaining
        sbc lov_chunk_size_lo
        sta lov_remaining
        lda lov_remaining+1
        sbc lov_chunk_size_hi
        sta lov_remaining+1
        bra _ldl_map_loop

_lov_load_close:
        lda #1
        jsr KERNAL_CLOSE
        jsr KERNAL_CLRCHN
_lov_load_done:
        ; Mark every cache dirty so the next frame's render picks up the
        ; loaded values. overlay_close has already set render_view_dirty;
        ; we additionally flag funds + clock readouts and force a power
        ; recompute from the loaded plant_origin list.
        lda #1
        sta funds_dirty
        sta clock_dirty
        jmp power_mark_dirty        ; tail-call: marks the power network dirty + rts

;---------------------------------------------------------------------------------------
; lov_build_full_name: append CBM-DOS ",S,R" suffix (sequential file, read
; mode). Hex literals for the same reason as the save overlay -- 64tass's
; default encoding doesn't map ASCII chars 1:1.
;---------------------------------------------------------------------------------------
lov_build_full_name:
        ldx #0
_lbfn_copy:
        cpx lov_filename_len
        bcs _lbfn_copy_done
        lda lov_filename_buf,x
        sta lov_full_name_buf,x
        inx
        bra _lbfn_copy
_lbfn_copy_done:
        lda #$2C                    ; ','
        sta lov_full_name_buf,x
        inx
        lda #$53                    ; 'S'
        sta lov_full_name_buf,x
        inx
        lda #$2C
        sta lov_full_name_buf,x
        inx
        lda #$52                    ; 'R'
        sta lov_full_name_buf,x
        inx
        stx lov_full_name_len
        rts

;---------------------------------------------------------------------------------------
; lov_dma_run: trigger an enhanced DMA from CPU bank 0 (lov_chunk_buf) to
; Attic MB ATTIC_MAP_MB at addr lov_dma_dst, lov_dma_size bytes. Inline list
; bytes are patched per chunk.
;---------------------------------------------------------------------------------------
lov_dma_run:
        lda #$00
        sta $D707
        .byte $80, $00              ; src MB (bank 0, the chunk buffer)
        .byte $81, ATTIC_MAP_MB     ; dst MB
        .byte $00
        .byte $00                   ; job: copy
lov_dma_size:
        .word 0                     ; size (patched per chunk)
        .word lov_chunk_buf         ; src addr (CPU)
        .byte $00                   ; src bank
lov_dma_dst:
        .word 0                     ; dst addr (Attic, patched per chunk)
        .byte ATTIC_MAP_BANK
        .byte $00
        .word $0000
        rts

;---------------------------------------------------------------------------------------
; Strings & data
;---------------------------------------------------------------------------------------

; Title: "LOAD"
lov_title:
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_A, UI_TEXT_D
lov_title_len = * - lov_title

; 7 ASCII bytes "MEGASIM" -- expected at file offset 0.
lov_magic_expected:
        .byte $4D, $45, $47, $41, $53, $49, $4D    ; "MEGASIM" in ASCII

; --- scratch ---
lov_key:                .byte 0
lov_draw_idx:           .byte 0
lov_format_ver:         .byte 0     ; 1 or 2, cached from the header byte
lov_remaining:          .word 0
lov_chunk_dst:          .word 0
lov_chunk_size_lo:      .byte 0
lov_chunk_size_hi:      .byte 0
lov_header_check:       .fill 16, 0

lov_filename_buf:       .fill LOV_FILENAME_MAX, 0
lov_filename_len:       .byte 0

lov_full_name_buf:      .fill LOV_FILENAME_MAX + 4, 0
lov_full_name_len:      .byte 0

;---------------------------------------------------------------------------------------
; Chunk buffer at $AF00 (last 256 bytes of the overlay window).
;---------------------------------------------------------------------------------------
        .fill $AF00 - *, 0
lov_chunk_buf:
        .fill 256, 0

        .cerror * != LOAD_OVERLAY_ADDR + LOAD_OVERLAY_SIZE, "load overlay overflowed its $1000-byte window"
