;=======================================================================================
; Annual budget overlay (PRG, compiles to $A000).
;
; Loaded from Attic by finance_invoke_annual_budget at the December rollover,
; or by finance_invoke_budget_adjust from the top-strip budget button.
; The overlay opens a large modal popup, installs body/OK click hooks that
; remain valid in the shared $A000 window while the popup is active, and then
; returns to the main loop.
;=======================================================================================

        .cpu "45gs02"
        .include "../../target/mega-simcity.lbl"

        * = OVR_WINDOW_ADDR

ANNUAL_POPUP_W                 = 34
ANNUAL_POPUP_H                 = 20
ANNUAL_POPUP_L                 = 5
ANNUAL_POPUP_T                 = 3

AB_LABEL_COL                   = 2
AB_VALUE_COL                   = 23
AB_RATE_LABEL_COL              = 4
AB_RATE_DIGIT_COL              = 10
AB_RATE_UP_COL                 = 23
AB_RATE_DOWN_COL               = 25
AB_RES_RATE_ROW                = 5
AB_COM_RATE_ROW                = 7

AB_ZERO_4 .macro target
        lda #0
        sta \target
        sta \target+1
        sta \target+2
        sta \target+3
.endmacro

AB_COPY_4 .macro dest, src
        lda \src
        sta \dest
        lda \src+1
        sta \dest+1
        lda \src+2
        sta \dest+2
        lda \src+3
        sta \dest+3
.endmacro

AB_ADD_32 .macro target, src
        clc
        lda \target
        adc \src
        sta \target
        lda \target+1
        adc \src+1
        sta \target+1
        lda \target+2
        adc \src+2
        sta \target+2
        lda \target+3
        adc \src+3
        sta \target+3
.endmacro

BUDGET_STRING .macro str, len, col, row
        lda #<\str
        sta ab_str_ptr
        lda #>\str
        sta ab_str_ptr+1
        lda #\len
        sta ab_str_len
        lda #\col
        sta ab_str_col
        lda #\row
        sta ab_str_row
        jsr ab_draw_string
.endmacro

BUDGET_MONEY .macro amount, col, row
        lda #<\amount
        sta ab_amount_ptr
        lda #>\amount
        sta ab_amount_ptr+1
        lda #\col
        sta ab_money_col
        lda #\row
        sta ab_money_row
        jsr ab_draw_money
.endmacro

;---------------------------------------------------------------------------------------
; Entry
;---------------------------------------------------------------------------------------

ovr_budget_main:
        lda #ANNUAL_POPUP_W
        sta popup_w
        lda #ANNUAL_POPUP_H
        sta popup_h
        lda #ANNUAL_POPUP_L
        sta popup_l
        lda #ANNUAL_POPUP_T
        sta popup_t

        lda #<budget_body_click
        sta popup_body_click_hook
        lda #>budget_body_click
        sta popup_body_click_hook+1
        lda #<budget_ok_click
        sta popup_ok_click_hook
        lda #>budget_ok_click
        sta popup_ok_click_hook+1

        jsr budget_recompute_review
        lda #<str_annual_budget_title
        ldx #>str_annual_budget_title
        ldy #STR_ANNUAL_BUDGET_TITLE_LEN
        jsr overlay_open
        jsr budget_render_body
        rts

budget_ok_click:
        jsr audio_click
        jsr budget_recompute_review
        lda finance_budget_apply_on_ok
        beq _boc_close
        jsr finance_accept_annual_review
_boc_close:
        jsr overlay_close
        rts

;---------------------------------------------------------------------------------------
; Click handling
;---------------------------------------------------------------------------------------

budget_body_click:
        lda mouse_x+1
        bne _bbc_done
        lda mouse_x
        lsr
        lsr
        lsr
        cmp popup_l
        bcc _bbc_done
        sec
        sbc popup_l
        sta ab_click_col

        lda mouse_y
        lsr
        lsr
        lsr
        cmp popup_t
        bcc _bbc_done
        sec
        sbc popup_t
        sta ab_click_row

        lda ab_click_row
        cmp #AB_RES_RATE_ROW
        beq _bbc_res
        cmp #AB_COM_RATE_ROW
        beq _bbc_com
        rts

_bbc_res:
        lda ab_click_col
        cmp #AB_RATE_UP_COL
        beq _bbc_res_up
        cmp #AB_RATE_DOWN_COL
        beq _bbc_res_down
        rts
_bbc_res_up:
        lda finance_res_tax_rate
        cmp #FINANCE_TAX_RATE_MAX
        bcs _bbc_done
        inc finance_res_tax_rate
        bra _bbc_changed
_bbc_res_down:
        lda finance_res_tax_rate
        beq _bbc_done
        dec finance_res_tax_rate
        bra _bbc_changed

_bbc_com:
        lda ab_click_col
        cmp #AB_RATE_UP_COL
        beq _bbc_com_up
        cmp #AB_RATE_DOWN_COL
        beq _bbc_com_down
        rts
_bbc_com_up:
        lda finance_com_tax_rate
        cmp #FINANCE_TAX_RATE_MAX
        bcs _bbc_done
        inc finance_com_tax_rate
        bra _bbc_changed
_bbc_com_down:
        lda finance_com_tax_rate
        beq _bbc_done
        dec finance_com_tax_rate

_bbc_changed:
        jsr audio_click
        jsr budget_recompute_review
        jsr budget_render_body
_bbc_done:
        rts

;---------------------------------------------------------------------------------------
; Review math
;---------------------------------------------------------------------------------------

budget_recompute_review:
        jsr budget_compute_res_income
        jsr budget_compute_com_income

        AB_COPY_4 finance_total_income, finance_res_income
        AB_ADD_32 finance_total_income, finance_com_income

        AB_COPY_4 finance_total_expense, finance_ytd_transport_expense
        AB_ADD_32 finance_total_expense, finance_ytd_police_expense
        AB_ADD_32 finance_total_expense, finance_ytd_fire_expense
        AB_ADD_32 finance_total_expense, finance_ytd_park_expense

        lda finance_total_income
        cmp finance_total_expense
        lda finance_total_income+1
        sbc finance_total_expense+1
        lda finance_total_income+2
        sbc finance_total_expense+2
        lda finance_total_income+3
        sbc finance_total_expense+3
        bcc _brr_negative

        lda #0
        sta finance_net_negative
        sec
        lda finance_total_income
        sbc finance_total_expense
        sta finance_net_abs
        lda finance_total_income+1
        sbc finance_total_expense+1
        sta finance_net_abs+1
        lda finance_total_income+2
        sbc finance_total_expense+2
        sta finance_net_abs+2
        lda finance_total_income+3
        sbc finance_total_expense+3
        sta finance_net_abs+3
        rts

_brr_negative:
        lda #1
        sta finance_net_negative
        sec
        lda finance_total_expense
        sbc finance_total_income
        sta finance_net_abs
        lda finance_total_expense+1
        sbc finance_total_income+1
        sta finance_net_abs+1
        lda finance_total_expense+2
        sbc finance_total_income+2
        sta finance_net_abs+2
        lda finance_total_expense+3
        sbc finance_total_income+3
        sta finance_net_abs+3
        rts

budget_compute_res_income:
        lda population
        sta ab_tax_base
        lda population+1
        sta ab_tax_base+1
        lda population+2
        sta ab_tax_base+2
        lda #0
        sta ab_tax_base+3
        lda finance_res_tax_rate
        jsr ab_compute_tax_percent
        AB_COPY_4 finance_res_income, ab_tax_quotient
        rts

budget_compute_com_income:
        jsr finance_sum_commercial_month
        AB_COPY_4 ab_tax_base, finance_month_com_base
        lda finance_com_tax_rate
        jsr ab_compute_tax_percent
        AB_COPY_4 finance_com_income, ab_tax_quotient
        rts

; Compute floor((ab_tax_base * A) / 100) into ab_tax_quotient.
; Tax rates are UI percentages (7 = 7%), not multipliers.
ab_compute_tax_percent:
        sta ab_tax_rate
        AB_ZERO_4 ab_tax_product
        AB_ZERO_4 ab_tax_quotient
        ldx ab_tax_rate
        beq _actp_done
_actp_mul:
        AB_ADD_32 ab_tax_product, ab_tax_base
        dex
        bne _actp_mul
_actp_div:
        lda ab_tax_product+3
        bne _actp_sub
        lda ab_tax_product+2
        bne _actp_sub
        lda ab_tax_product+1
        bne _actp_sub
        lda ab_tax_product
        cmp #100
        bcc _actp_done
_actp_sub:
        sec
        lda ab_tax_product
        sbc #100
        sta ab_tax_product
        lda ab_tax_product+1
        sbc #0
        sta ab_tax_product+1
        lda ab_tax_product+2
        sbc #0
        sta ab_tax_product+2
        lda ab_tax_product+3
        sbc #0
        sta ab_tax_product+3
        inc ab_tax_quotient
        bne _actp_div
        inc ab_tax_quotient+1
        bne _actp_div
        inc ab_tax_quotient+2
        bne _actp_div
        inc ab_tax_quotient+3
        bra _actp_div
_actp_done:
        rts

;---------------------------------------------------------------------------------------
; Rendering
;---------------------------------------------------------------------------------------

budget_render_body:
        BUDGET_STRING str_income, STR_INCOME_LEN, AB_LABEL_COL, 3
        BUDGET_STRING str_res_taxes, STR_RES_TAXES_LEN, AB_LABEL_COL, 4
        BUDGET_MONEY finance_res_income, AB_VALUE_COL, 4

        lda finance_res_tax_rate
        sta ab_rate_value
        lda #AB_RES_RATE_ROW
        sta ab_rate_row
        jsr ab_draw_rate_row

        BUDGET_STRING str_com_taxes, STR_COM_TAXES_LEN, AB_LABEL_COL, 6
        BUDGET_MONEY finance_com_income, AB_VALUE_COL, 6

        lda finance_com_tax_rate
        sta ab_rate_value
        lda #AB_COM_RATE_ROW
        sta ab_rate_row
        jsr ab_draw_rate_row

        BUDGET_STRING str_total_income, STR_TOTAL_INCOME_LEN, AB_LABEL_COL, 8
        BUDGET_MONEY finance_total_income, AB_VALUE_COL, 8

        lda #9
        jsr ab_draw_divider

        BUDGET_STRING str_expenditures, STR_EXPENDITURES_LEN, AB_LABEL_COL, 10
        BUDGET_STRING str_transport, STR_TRANSPORT_LEN, AB_LABEL_COL, 11
        BUDGET_MONEY finance_ytd_transport_expense, AB_VALUE_COL, 11
        BUDGET_STRING str_police, STR_POLICE_LEN, AB_LABEL_COL, 12
        BUDGET_MONEY finance_ytd_police_expense, AB_VALUE_COL, 12
        BUDGET_STRING str_fire, STR_FIRE_LEN, AB_LABEL_COL, 13
        BUDGET_MONEY finance_ytd_fire_expense, AB_VALUE_COL, 13
        BUDGET_STRING str_parks, STR_PARKS_LEN, AB_LABEL_COL, 14
        BUDGET_MONEY finance_ytd_park_expense, AB_VALUE_COL, 14

        BUDGET_STRING str_total_expenses, STR_TOTAL_EXPENSES_LEN, AB_LABEL_COL, 15
        BUDGET_MONEY finance_total_expense, AB_VALUE_COL, 15

        lda #AB_LABEL_COL
        sta ab_clear_col
        lda #16
        sta ab_clear_row
        lda #14
        sta ab_clear_len
        jsr ab_clear_span
        lda finance_net_negative
        bne _brb_loss
        BUDGET_STRING str_net_revenue, STR_NET_REVENUE_LEN, AB_LABEL_COL, 16
        bra _brb_net_money
_brb_loss:
        BUDGET_STRING str_net_loss, STR_NET_LOSS_LEN, AB_LABEL_COL, 16
_brb_net_money:
        BUDGET_MONEY finance_net_abs, AB_VALUE_COL, 16
        rts

ab_draw_rate_row:
        lda #<str_rate
        sta ab_str_ptr
        lda #>str_rate
        sta ab_str_ptr+1
        lda #STR_RATE_LEN
        sta ab_str_len
        lda #AB_RATE_LABEL_COL
        sta ab_str_col
        lda ab_rate_row
        sta ab_str_row
        jsr ab_draw_string

        lda ab_rate_value
        ldx #0
_adrr_tens:
        cmp #10
        bcc _adrr_digits
        sec
        sbc #10
        inx
        bra _adrr_tens
_adrr_digits:
        sta ab_rate_units
        stx ab_rate_tens
        txa
        clc
        adc #UI_TEXT_0
        ldx #AB_RATE_DIGIT_COL
        ldy ab_rate_row
        jsr ab_draw_char_local
        lda ab_rate_units
        clc
        adc #UI_TEXT_0
        ldx #AB_RATE_DIGIT_COL+1
        ldy ab_rate_row
        jsr ab_draw_char_local
        lda #UI_TEXT_U
        ldx #AB_RATE_UP_COL
        ldy ab_rate_row
        jsr ab_draw_char_local
        lda #UI_TEXT_D
        ldx #AB_RATE_DOWN_COL
        ldy ab_rate_row
        jmp ab_draw_char_local

ab_draw_divider:
        sta ab_divider_row
        lda #1
        sta ab_divider_col
_add_loop:
        lda #>DISK_LINE_CHAR
        sta snc_char_hi
        clc
        lda popup_l
        adc ab_divider_col
        tax
        clc
        lda popup_t
        adc ab_divider_row
        tay
        lda #<DISK_LINE_CHAR
        jsr set_fcm_char16
        inc ab_divider_col
        lda ab_divider_col
        cmp #ANNUAL_POPUP_W-1
        bne _add_loop
        rts

ab_draw_string:
        lda ab_str_ptr
        sta PTR2
        lda ab_str_ptr+1
        sta PTR2+1
        lda #0
        sta ab_str_idx
_ads_loop:
        lda ab_str_idx
        cmp ab_str_len
        bcs _ads_done
        ldy ab_str_idx
        lda (PTR2),y
        pha
        clc
        lda popup_l
        adc ab_str_col
        clc
        adc ab_str_idx
        tax
        clc
        lda popup_t
        adc ab_str_row
        tay
        pla
        jsr set_fcm_char
        inc ab_str_idx
        bra _ads_loop
_ads_done:
        rts

ab_draw_char_local:
        pha
        txa
        clc
        adc popup_l
        tax
        tya
        clc
        adc popup_t
        tay
        pla
        jmp set_fcm_char

ab_clear_span:
        lda #0
        sta ab_clear_idx
_acs_loop:
        lda ab_clear_idx
        cmp ab_clear_len
        bcs _acs_done
        ; Compute X = ab_clear_col + ab_clear_idx, then load the panel char
        ; into A *after* the math -- the original sequence did `lda #UI_TILE_PANEL`
        ; then `txa` which clobbered A, so set_fcm_char drew col+idx as the
        ; char value (a row of road cells appearing across the net-revenue row).
        clc
        lda ab_clear_col
        adc ab_clear_idx
        tax
        ldy ab_clear_row
        lda #UI_TILE_PANEL
        jsr ab_draw_char_local
        inc ab_clear_idx
        bra _acs_loop
_acs_done:
        rts

ab_draw_money:
        lda ab_amount_ptr
        sta PTR2
        lda ab_amount_ptr+1
        sta PTR2+1
        ldy #0
        lda (PTR2),y
        sta ab_amount_work
        iny
        lda (PTR2),y
        sta ab_amount_work+1
        iny
        lda (PTR2),y
        sta ab_amount_work+2
        iny
        lda (PTR2),y
        sta ab_amount_work+3
        jsr ab_amount_to_digits

        lda #UI_TEXT_DOLLAR
        ldx ab_money_col
        ldy ab_money_row
        jsr ab_draw_char_local

        lda #0
        sta ab_seen
        sta ab_digit_idx
_adm_loop:
        lda ab_digit_idx
        cmp #7
        bcs _adm_done
        cmp #6
        beq _adm_digit
        tax
        lda ab_digits,x
        ora ab_seen
        beq _adm_blank
_adm_digit:
        ldx ab_digit_idx
        lda ab_digits,x
        ldx #1
        stx ab_seen
        clc
        adc #UI_TEXT_0
        bra _adm_stamp
_adm_blank:
        lda #UI_TILE_PANEL
_adm_stamp:
        pha
        clc
        lda ab_money_col
        adc #1
        clc
        adc ab_digit_idx
        tax
        ldy ab_money_row
        pla
        jsr ab_draw_char_local
        inc ab_digit_idx
        bra _adm_loop
_adm_done:
        rts

ab_amount_to_digits:
        ldx #0
_aatd_loop:
        lda #0
        sta ab_digit_count
_aatd_sub:
        lda ab_amount_work
        cmp ab_powers_lo,x
        lda ab_amount_work+1
        sbc ab_powers_hi,x
        lda ab_amount_work+2
        sbc ab_powers_up,x
        lda ab_amount_work+3
        sbc #0
        bcc _aatd_next
        sec
        lda ab_amount_work
        sbc ab_powers_lo,x
        sta ab_amount_work
        lda ab_amount_work+1
        sbc ab_powers_hi,x
        sta ab_amount_work+1
        lda ab_amount_work+2
        sbc ab_powers_up,x
        sta ab_amount_work+2
        lda ab_amount_work+3
        sbc #0
        sta ab_amount_work+3
        inc ab_digit_count
        bra _aatd_sub
_aatd_next:
        lda ab_digit_count
        sta ab_digits,x
        inx
        cpx #7
        bne _aatd_loop
        rts

ab_powers_lo:  .byte $40,$A0,$10,$E8,$64,$0A,$01
ab_powers_hi:  .byte $42,$86,$27,$03,$00,$00,$00
ab_powers_up:  .byte $0F,$01,$00,$00,$00,$00,$00

;---------------------------------------------------------------------------------------
; Strings
;---------------------------------------------------------------------------------------

str_annual_budget_title:
        .byte UI_TEXT_A, UI_TEXT_N, UI_TEXT_N, UI_TEXT_U, UI_TEXT_A, UI_TEXT_L
        .byte UI_TILE_PANEL
        .byte UI_TEXT_B, UI_TEXT_U, UI_TEXT_D, UI_TEXT_G, UI_TEXT_E, UI_TEXT_T
STR_ANNUAL_BUDGET_TITLE_LEN = * - str_annual_budget_title

str_income:
        .byte UI_TEXT_I, UI_TEXT_N, UI_TEXT_C, UI_TEXT_O, UI_TEXT_M, UI_TEXT_E
STR_INCOME_LEN = * - str_income

str_res_taxes:
        .byte UI_TEXT_R, UI_TEXT_E, UI_TEXT_S, UI_TEXT_I, UI_TEXT_D, UI_TEXT_E, UI_TEXT_N, UI_TEXT_T, UI_TEXT_I, UI_TEXT_A, UI_TEXT_L
        .byte UI_TILE_PANEL
        .byte UI_TEXT_T, UI_TEXT_A, UI_TEXT_X, UI_TEXT_E, UI_TEXT_S, UI_TEXT_COLON
STR_RES_TAXES_LEN = * - str_res_taxes

str_com_taxes:
        .byte UI_TEXT_C, UI_TEXT_O, UI_TEXT_M, UI_TEXT_M, UI_TEXT_E, UI_TEXT_R, UI_TEXT_C, UI_TEXT_I, UI_TEXT_A, UI_TEXT_L
        .byte UI_TILE_PANEL
        .byte UI_TEXT_T, UI_TEXT_A, UI_TEXT_X, UI_TEXT_E, UI_TEXT_S, UI_TEXT_COLON
STR_COM_TAXES_LEN = * - str_com_taxes

str_rate:
        .byte UI_TEXT_R, UI_TEXT_A, UI_TEXT_T, UI_TEXT_E, UI_TEXT_COLON
STR_RATE_LEN = * - str_rate

str_total_income:
        .byte UI_TEXT_T, UI_TEXT_O, UI_TEXT_T, UI_TEXT_A, UI_TEXT_L
        .byte UI_TILE_PANEL
        .byte UI_TEXT_I, UI_TEXT_N, UI_TEXT_C, UI_TEXT_O, UI_TEXT_M, UI_TEXT_E, UI_TEXT_COLON
STR_TOTAL_INCOME_LEN = * - str_total_income

str_expenditures:
        .byte UI_TEXT_E, UI_TEXT_X, UI_TEXT_P, UI_TEXT_E, UI_TEXT_N, UI_TEXT_D, UI_TEXT_I, UI_TEXT_T, UI_TEXT_U, UI_TEXT_R, UI_TEXT_E, UI_TEXT_S
STR_EXPENDITURES_LEN = * - str_expenditures

str_transport:
        .byte UI_TEXT_T, UI_TEXT_R, UI_TEXT_A, UI_TEXT_N, UI_TEXT_S, UI_TEXT_P, UI_TEXT_O, UI_TEXT_R, UI_TEXT_T
        .byte UI_TILE_PANEL
        .byte UI_TEXT_M, UI_TEXT_A, UI_TEXT_I, UI_TEXT_N, UI_TEXT_T, UI_TEXT_COLON
STR_TRANSPORT_LEN = * - str_transport

str_police:
        .byte UI_TEXT_P, UI_TEXT_O, UI_TEXT_L, UI_TEXT_I, UI_TEXT_C, UI_TEXT_E, UI_TEXT_COLON
STR_POLICE_LEN = * - str_police

str_fire:
        .byte UI_TEXT_F, UI_TEXT_I, UI_TEXT_R, UI_TEXT_E, UI_TEXT_COLON
STR_FIRE_LEN = * - str_fire

str_parks:
        .byte UI_TEXT_P, UI_TEXT_A, UI_TEXT_R, UI_TEXT_K, UI_TEXT_S, UI_TEXT_COLON
STR_PARKS_LEN = * - str_parks

str_total_expenses:
        .byte UI_TEXT_T, UI_TEXT_O, UI_TEXT_T, UI_TEXT_A, UI_TEXT_L
        .byte UI_TILE_PANEL
        .byte UI_TEXT_E, UI_TEXT_X, UI_TEXT_P, UI_TEXT_E, UI_TEXT_N, UI_TEXT_S, UI_TEXT_E, UI_TEXT_S, UI_TEXT_COLON
STR_TOTAL_EXPENSES_LEN = * - str_total_expenses

str_net_revenue:
        .byte UI_TEXT_N, UI_TEXT_E, UI_TEXT_T
        .byte UI_TILE_PANEL
        .byte UI_TEXT_R, UI_TEXT_E, UI_TEXT_V, UI_TEXT_E, UI_TEXT_N, UI_TEXT_U, UI_TEXT_E, UI_TEXT_COLON
STR_NET_REVENUE_LEN = * - str_net_revenue

str_net_loss:
        .byte UI_TEXT_N, UI_TEXT_E, UI_TEXT_T
        .byte UI_TILE_PANEL
        .byte UI_TEXT_L, UI_TEXT_O, UI_TEXT_S, UI_TEXT_S, UI_TEXT_COLON
STR_NET_LOSS_LEN = * - str_net_loss

;---------------------------------------------------------------------------------------
; Scratch
;---------------------------------------------------------------------------------------

ab_click_col:           .byte 0
ab_click_row:           .byte 0
ab_rate_value:          .byte 0
ab_rate_row:            .byte 0
ab_rate_tens:           .byte 0
ab_rate_units:          .byte 0
ab_str_ptr:             .word 0
ab_str_len:             .byte 0
ab_str_col:             .byte 0
ab_str_row:             .byte 0
ab_str_idx:             .byte 0
ab_divider_row:         .byte 0
ab_divider_col:         .byte 0
ab_clear_col:           .byte 0
ab_clear_row:           .byte 0
ab_clear_len:           .byte 0
ab_clear_idx:           .byte 0
ab_amount_ptr:          .word 0
ab_money_col:           .byte 0
ab_money_row:           .byte 0
ab_amount_work:         .byte 0, 0, 0, 0
ab_digits:              .fill 7, 0
ab_digit_count:         .byte 0
ab_digit_idx:           .byte 0
ab_seen:                .byte 0
ab_tax_base:            .byte 0, 0, 0, 0
ab_tax_product:         .byte 0, 0, 0, 0
ab_tax_quotient:        .byte 0, 0, 0, 0
ab_tax_rate:            .byte 0

        .cerror * > OVR_WINDOW_ADDR + OVR_WINDOW_SIZE, "budget overlay exceeds OVR_WINDOW_SIZE"
