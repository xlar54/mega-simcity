;=======================================================================================
; Game clock.
;
; A frame-counted in-game month/year. clock_tick is called per frame; once
; FRAMES_PER_MONTH frames have elapsed (3 wall-clock minutes at PAL 50 Hz) the
; counter resets and sim_month advances, rolling over to January / sim_year+1.
; Start of game = January 2026.
;
; The readout "Mmm YYYY" sits on row 0 alongside the FUNDS field. Redrawn only
; when clock_dirty is set (initial render + each month tick + each UI refresh).
;
; A real-time-clock-driven version is a clean swap-in: replace clock_tick with
; logic that reads the MEGA65 RTC minutes and advances on a 3-minute delta.
;=======================================================================================

; Per-speed frames-per-month, indexed by sim_speed (SPEED_SLOW/MEDIUM/FAST).
; Slow is the historical 4500-frame default; Medium halves it; Fast quarters.
; The clock_tick rollover threshold is a runtime lookup against these tables.
sim_speed_fpm_lo:           .byte <FPM_SLOW, <FPM_MEDIUM, <FPM_FAST
sim_speed_fpm_hi:           .byte >FPM_SLOW, >FPM_MEDIUM, >FPM_FAST

; Menu-bar layout, row 0: "Mmm YYYY" centered on the menu line (date starts at
; col 20), then a small gap before the $ funds field.
CLK_ROW      = 0
CLK_COL_MON  = 20           ; month: 3 chars starting here (cols 20..22)
CLK_COL_YR   = 24           ; year:  4 digits starting here (cols 24..27)

;---------------------------------------------------------------------------------------
; Public API
;---------------------------------------------------------------------------------------

clock_init:
        lda #1
        sta sim_month
        lda #<2026
        sta sim_year
        lda #>2026
        sta sim_year+1
        lda #0
        sta clock_frames
        sta clock_frames+1
        sta sim_speed                ; default to SPEED_SLOW (= 0) -- the
                                     ; historical pace, so a save predating
                                     ; the speed picker plays the same.
        lda #1
        sta clock_dirty
        rts

; Called every frame. Increments the frame counter; on rollover (>=FRAMES_PER_MONTH)
; advances sim_month/sim_year and marks the readout dirty.
;
; Pause gate: while a popup is open, the clock freezes -- no frame counter
; advance, no month/year rollover, no population/plant ticks. The popup's
; modal feel becomes a true sim pause so the player can read without time
; sliding underneath them.
clock_tick:
        lda overlay_active
        bne _ct_paused
        inc clock_frames
        bne +
        inc clock_frames+1
+
        ; Threshold lookup: sim_speed indexes sim_speed_fpm_lo/hi for the
        ; per-speed frames-per-month value. Slow = 4500 (default), Medium =
        ; 2250, Fast = 1125. Compare 16-bit clock_frames against threshold.
        ldx sim_speed
        lda clock_frames
        cmp sim_speed_fpm_lo,x
        lda clock_frames+1
        sbc sim_speed_fpm_hi,x
        bcc _ct_done                ; frames < threshold
        lda #0
        sta clock_frames
        sta clock_frames+1
        inc sim_month
        lda sim_month
        cmp #13
        bne _ct_dirty
        ; rolled past December -> January, year+1
        lda #1
        sta sim_month
        inc sim_year
        bne _ct_yr_age
        inc sim_year+1
_ct_yr_age:
        ; New year -> tick each registered plant's years-left counter down by
        ; one (clamped at 0). The inspect popup reads the counter to show
        ; "NN YEARS LEFT" per coal / nuclear plant.
        jsr plant_age_year
_ct_dirty:
        jsr population_monthly_tick     ; per-month growth pass on registered zones
        lda #1
        sta clock_dirty
_ct_done:
_ct_paused:
        rts

; Called once per frame. Redraws if clock_dirty.
clock_update:
        lda clock_dirty
        beq _cu_done
        lda #0
        sta clock_dirty
        jmp clock_render
_cu_done:
        rts

;---------------------------------------------------------------------------------------
; Render "Mmm YYYY" on row 0. Idempotent: redraws each call. The space between
; month and year is provided by the menu-bar fill (drawn before us), so we
; don't need to stamp it ourselves.
;---------------------------------------------------------------------------------------

clock_render:
        ; Month: 3 chars from month_chars[(sim_month-1) * 3 ..]
        lda sim_month
        sec
        sbc #1
        sta clk_tmp
        asl                         ; *2
        clc
        adc clk_tmp                 ; *3
        sta clk_mon_base

        ldx clk_mon_base
        lda month_chars,x
        ldx #CLK_COL_MON
        ldy #CLK_ROW
        jsr set_fcm_char
        ldx clk_mon_base
        inx
        lda month_chars,x
        ldx #CLK_COL_MON+1
        ldy #CLK_ROW
        jsr set_fcm_char
        ldx clk_mon_base
        inx
        inx
        lda month_chars,x
        ldx #CLK_COL_MON+2
        ldy #CLK_ROW
        jsr set_fcm_char

        ; Year: 4 digits. Year starts at 2026 and only grows, so no leading-zero
        ; blanking needed.
        jsr year_to_digits

        lda year_d
        clc
        adc #UI_TEXT_0
        ldx #CLK_COL_YR
        ldy #CLK_ROW
        jsr set_fcm_char
        lda year_d+1
        clc
        adc #UI_TEXT_0
        ldx #CLK_COL_YR+1
        ldy #CLK_ROW
        jsr set_fcm_char
        lda year_d+2
        clc
        adc #UI_TEXT_0
        ldx #CLK_COL_YR+2
        ldy #CLK_ROW
        jsr set_fcm_char
        lda year_d+3
        clc
        adc #UI_TEXT_0
        ldx #CLK_COL_YR+3
        ldy #CLK_ROW
        jsr set_fcm_char
        rts

;---------------------------------------------------------------------------------------
; Convert sim_year (16-bit) to year_d[0..3] (thousands, hundreds, tens, units) by
; repeated subtraction of each power of ten.
;---------------------------------------------------------------------------------------

year_to_digits:
        lda sim_year
        sta yd_work
        lda sim_year+1
        sta yd_work+1
        ldx #0
_ytd_loop:
        lda #0
        sta yd_count
_ytd_sub:
        lda yd_work
        cmp yd_powers_lo,x
        lda yd_work+1
        sbc yd_powers_hi,x
        bcc _ytd_next
        sec
        lda yd_work
        sbc yd_powers_lo,x
        sta yd_work
        lda yd_work+1
        sbc yd_powers_hi,x
        sta yd_work+1
        inc yd_count
        jmp _ytd_sub
_ytd_next:
        lda yd_count
        sta year_d,x
        inx
        cpx #4
        bne _ytd_loop
        rts

yd_powers_lo:  .byte <1000, <100, <10, <1
yd_powers_hi:  .byte >1000, >100, >10, >1

month_chars:                ; 3 chars per month, in calendar order
        .byte UI_TEXT_J, UI_TEXT_A, UI_TEXT_N
        .byte UI_TEXT_F, UI_TEXT_E, UI_TEXT_B
        .byte UI_TEXT_M, UI_TEXT_A, UI_TEXT_R
        .byte UI_TEXT_A, UI_TEXT_P, UI_TEXT_R
        .byte UI_TEXT_M, UI_TEXT_A, UI_TEXT_Y
        .byte UI_TEXT_J, UI_TEXT_U, UI_TEXT_N
        .byte UI_TEXT_J, UI_TEXT_U, UI_TEXT_L
        .byte UI_TEXT_A, UI_TEXT_U, UI_TEXT_G
        .byte UI_TEXT_S, UI_TEXT_E, UI_TEXT_P
        .byte UI_TEXT_O, UI_TEXT_C, UI_TEXT_T
        .byte UI_TEXT_N, UI_TEXT_O, UI_TEXT_V
        .byte UI_TEXT_D, UI_TEXT_E, UI_TEXT_C

; --- state ---
sim_month:                  ; 1..12
        .byte 1
sim_year:                   ; 16-bit
        .word 2026
clock_frames:               ; frames elapsed since the last month tick
        .word 0
clock_dirty:                ; nonzero -> redraw the readout next frame
        .byte 0
sim_speed:                  ; SPEED_SLOW/MEDIUM/FAST -- indexes
        .byte 0             ; sim_speed_fpm_lo/hi to pick the month threshold

clk_tmp:                    ; scratch for the month index math
        .byte 0
clk_mon_base:               ; offset into month_chars (= (month-1) * 3)
        .byte 0

yd_work:                    ; year_to_digits: 16-bit working copy of sim_year
        .word 0
yd_count:                   ; current digit accumulator
        .byte 0
year_d:                     ; the 4 decoded digits (thousands..units)
        .fill 4, 0
