;=======================================================================================
; Resident finance state and year-end trigger.
;
; The large annual review UI lives in overlays/ovr-budget.asm. This resident
; module keeps the year-to-date counters that must survive while the overlay is
; unloaded, invokes the overlay at the December rollover, and applies the
; accepted annual net when the overlay's OK hook calls back.
;=======================================================================================

FINANCE_TAX_RATE_DEFAULT       = 7
FINANCE_TAX_RATE_MAX           = 20
FINANCE_BUDGET_APPLY_NONE      = 0
FINANCE_BUDGET_APPLY_YEAR_END  = 1

TRANSPORT_CELL_MONTHLY_MAINT   = 1
POLICE_MONTHLY_MAINT           = 100
FIRE_MONTHLY_MAINT             = 100
PARK_MONTHLY_MAINT             = 25

FIN_SCAN_FULL_PAGES            = 187
FIN_SCAN_REMAINDER             = 128

FIN_ZERO_4 .macro target
        lda #0
        sta \target
        sta \target+1
        sta \target+2
        sta \target+3
.endmacro

FIN_ADD_32 .macro target, src
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

FIN_ADD_CONST32 .macro target, value
        clc
        lda \target
        adc #<\value
        sta \target
        lda \target+1
        adc #>\value
        sta \target+1
        lda \target+2
        adc #`\value
        sta \target+2
        lda \target+3
        adc #0
        sta \target+3
.endmacro

;---------------------------------------------------------------------------------------
; Public API
;---------------------------------------------------------------------------------------

finance_init:
        lda #FINANCE_TAX_RATE_DEFAULT
        sta finance_res_tax_rate
        sta finance_com_tax_rate
        lda #FINANCE_BUDGET_APPLY_NONE
        sta finance_budget_apply_on_ok
        jmp finance_reset_year

finance_reset_year:
        FIN_ZERO_4 finance_ytd_res_base
        FIN_ZERO_4 finance_ytd_com_base
        FIN_ZERO_4 finance_ytd_transport_expense
        FIN_ZERO_4 finance_ytd_police_expense
        FIN_ZERO_4 finance_ytd_fire_expense
        FIN_ZERO_4 finance_ytd_park_expense
        FIN_ZERO_4 finance_res_income
        FIN_ZERO_4 finance_com_income
        FIN_ZERO_4 finance_total_income
        FIN_ZERO_4 finance_total_expense
        FIN_ZERO_4 finance_net_abs
        lda #0
        sta finance_net_negative
        rts

; Called after population_monthly_tick. Adds the current month to the
; year-to-date tax bases and maintenance buckets.
finance_monthly_tick:
        clc
        lda finance_ytd_res_base
        adc population
        sta finance_ytd_res_base
        lda finance_ytd_res_base+1
        adc population+1
        sta finance_ytd_res_base+1
        lda finance_ytd_res_base+2
        adc population+2
        sta finance_ytd_res_base+2
        lda finance_ytd_res_base+3
        adc #0
        sta finance_ytd_res_base+3

        jsr finance_sum_commercial_month
        FIN_ADD_32 finance_ytd_com_base, finance_month_com_base

        jsr finance_scan_map_monthly_costs
        jmp finance_add_monthly_services

; DMA the annual budget overlay from its Attic slot into the shared $A000
; window, then tail-jump into it. The overlay returns after opening the modal
; popup and installing body/OK hooks.
finance_invoke_annual_budget:
        lda #FINANCE_BUDGET_APPLY_YEAR_END
        sta finance_budget_apply_on_ok
        bra finance_invoke_budget_overlay

finance_invoke_budget_adjust:
        lda #FINANCE_BUDGET_APPLY_NONE
        sta finance_budget_apply_on_ok

finance_invoke_budget_overlay:
        lda #$00
        sta $D707
        .byte $80, ATTIC_OVR_BUDGET_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word OVR_WINDOW_SIZE
        .word ATTIC_OVR_BUDGET_ADDR
        .byte ATTIC_OVR_BUDGET_BANK
        .word OVR_WINDOW_ADDR
        .byte $00
        .byte $00
        .word $0000

        jmp OVR_WINDOW_ADDR

; Called by ovr-budget's OK hook after it has recomputed finance_net_* from
; the current tax rates.
finance_accept_annual_review:
        lda finance_net_negative
        bne _faar_subtract
        clc
        lda funds
        adc finance_net_abs
        sta funds
        lda funds+1
        adc finance_net_abs+1
        sta funds+1
        lda funds+2
        adc finance_net_abs+2
        sta funds+2
        lda funds+3
        adc finance_net_abs+3
        sta funds+3
        bra _faar_advance_year

_faar_subtract:
        lda funds
        cmp finance_net_abs
        lda funds+1
        sbc finance_net_abs+1
        lda funds+2
        sbc finance_net_abs+2
        lda funds+3
        sbc finance_net_abs+3
        bcc _faar_zero_funds
        sec
        lda funds
        sbc finance_net_abs
        sta funds
        lda funds+1
        sbc finance_net_abs+1
        sta funds+1
        lda funds+2
        sbc finance_net_abs+2
        sta funds+2
        lda funds+3
        sbc finance_net_abs+3
        sta funds+3
        bra _faar_advance_year

_faar_zero_funds:
        lda #0
        sta funds
        sta funds+1
        sta funds+2
        sta funds+3

_faar_advance_year:
        lda #1
        sta funds_dirty
        jsr finance_reset_year
        lda #1
        sta sim_month
        inc sim_year
        bne +
        inc sim_year+1
+
        jsr plant_age_year
        lda #1
        sta clock_dirty
        rts

;---------------------------------------------------------------------------------------
; Monthly accounting internals
;---------------------------------------------------------------------------------------

finance_sum_commercial_month:
        FIN_ZERO_4 finance_month_com_base
        ldx #0
_fscm_loop:
        cpx commercial_count
        bcs _fscm_done
        clc
        lda finance_month_com_base
        adc commercial_dev_lo_arr,x
        sta finance_month_com_base
        lda finance_month_com_base+1
        adc commercial_dev_hi_arr,x
        sta finance_month_com_base+1
        lda finance_month_com_base+2
        adc #0
        sta finance_month_com_base+2
        lda finance_month_com_base+3
        adc #0
        sta finance_month_com_base+3
        inx
        bra _fscm_loop
_fscm_done:
        rts

finance_add_monthly_services:
        ldx police_count
_fams_police:
        cpx #0
        beq _fams_fire
        FIN_ADD_CONST32 finance_ytd_police_expense, POLICE_MONTHLY_MAINT
        dex
        bra _fams_police
_fams_fire:
        ldx firestation_count
_fams_fire_loop:
        cpx #0
        beq _fams_done
        FIN_ADD_CONST32 finance_ytd_fire_expense, FIRE_MONTHLY_MAINT
        dex
        bra _fams_fire_loop
_fams_done:
        rts

finance_scan_map_monthly_costs:
        lda #<ATTIC_MAP_PHYS
        sta MAP_PTR
        lda #>ATTIC_MAP_PHYS
        sta MAP_PTR+1
        lda #`ATTIC_MAP_PHYS
        sta MAP_PTR+2
        lda #(ATTIC_MAP_PHYS >> 24)
        sta MAP_PTR+3
        lda #FIN_SCAN_FULL_PAGES
        sta fin_scan_pages
_fsmc_page:
        ldz #0
_fsmc_byte:
        lda [MAP_PTR],z
        jsr finance_classify_monthly_cell
        inz
        bne _fsmc_byte
        inc MAP_PTR+1
        dec fin_scan_pages
        bne _fsmc_page

        ldz #0
_fsmc_rem:
        tza
        cmp #FIN_SCAN_REMAINDER
        bcs _fsmc_done
        lda [MAP_PTR],z
        jsr finance_classify_monthly_cell
        inz
        bra _fsmc_rem
_fsmc_done:
        rts

finance_classify_monthly_cell:
        cmp #ROAD_CELL_FIRST
        bcc _fcmc_check_rail
        cmp #ROAD_CELL_LAST+1
        bcc _fcmc_transport
_fcmc_check_rail:
        cmp #RAIL_CELL_FIRST
        bcc _fcmc_check_park
        cmp #RAIL_CELL_LAST+1
        bcc _fcmc_transport
_fcmc_check_park:
        cmp #PARK_CELL_FIRST
        beq _fcmc_park
        rts
_fcmc_transport:
        FIN_ADD_CONST32 finance_ytd_transport_expense, TRANSPORT_CELL_MONTHLY_MAINT
        rts
_fcmc_park:
        FIN_ADD_CONST32 finance_ytd_park_expense, PARK_MONTHLY_MAINT
        rts

;---------------------------------------------------------------------------------------
; State
;---------------------------------------------------------------------------------------

finance_res_tax_rate:           .byte FINANCE_TAX_RATE_DEFAULT
finance_com_tax_rate:           .byte FINANCE_TAX_RATE_DEFAULT

finance_ytd_res_base:           .byte 0, 0, 0, 0
finance_ytd_com_base:           .byte 0, 0, 0, 0
finance_ytd_transport_expense:  .byte 0, 0, 0, 0
finance_ytd_police_expense:     .byte 0, 0, 0, 0
finance_ytd_fire_expense:       .byte 0, 0, 0, 0
finance_ytd_park_expense:       .byte 0, 0, 0, 0

; The overlay writes these derived display/apply values.
finance_res_income:             .byte 0, 0, 0, 0
finance_com_income:             .byte 0, 0, 0, 0
finance_total_income:           .byte 0, 0, 0, 0
finance_total_expense:          .byte 0, 0, 0, 0
finance_net_abs:                .byte 0, 0, 0, 0
finance_net_negative:           .byte 0
finance_budget_apply_on_ok:     .byte FINANCE_BUDGET_APPLY_NONE

finance_month_com_base:         .byte 0, 0, 0, 0
fin_scan_pages:                 .byte 0
