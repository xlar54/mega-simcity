;=======================================================================================
; MEGA65 NCM + sprite mouse repro
;
; Standalone 64tass source. No project includes are required.
;
; Build:
;   64tass --cbm-prg -a ncm_mouse_repro.asm -o ncm_mouse_repro.prg
;
; Run on MEGA65/Xemu and press any key to advance each diagnostic step.
;
; Step 0: boot display, sprite mouse only
; Step 1: unlock VIC-IV registers and disable hot registers
; Step 2: enable VIC4 NCM/FCM-related control bits
; Step 3: set diagnostic screen mode variable to 40
; Step 4: enable H640 + attribute mode
; Step 5: set 640x200 geometry, 80 screen positions x 25 rows
; Step 6: reassert VIC4 control bits
; Step 7: set screen/color/char pointers and turn screen on
; Step 8: clear color RAM with NCM bit set
; Step 9: fill screen RAM with unique 16-bit NCM char codes
; Step 10: clear the NCM backing pixels at $40000-$5F3FF
; Step 11: refill screen RAM with repeated code $1000 for all cells
;
; From step 9 onward, border = mouse_y low nibble unless mouse_y+1 is
; nonzero. If mouse_y+1 is nonzero, border turns red as a high-byte alarm.
;
; Observed problem in the larger project: mouse/sprite Y works before the NCM
; screen-code fill, but after step 9 the sprite/mouse Y becomes pinned at the
; bottom while X still moves.
;=======================================================================================

        .cpu "45gs02"

BORDERCOL               = $D020
BACKCOL                 = $D021
VIC4_KEY                = $D02F
VIC_RASTER              = $D012
VIC3_CTRL               = $D031
VIC4_CTRL               = $D054
VIC4_HOTREGS            = $D05D
VIC4_LINESTPLSB         = $D058
VIC4_LINESTPMSB         = $D059
VIC4_SCRNPTRLSB         = $D060
VIC4_SCRNPTRMSB         = $D061
VIC4_SCRBPTRBNK         = $D062
VIC4_SCRNPTRMB          = $D063
VIC4_COLPTRLSB          = $D064
VIC4_COLPTRMSB          = $D065
VIC4_COLPTRBNK          = $D066
VIC4_COLPTRMB           = $D067
VIC4_CHARPTRLSB         = $D068
VIC4_CHARPTRMSB         = $D069
VIC4_CHARPTRBNK         = $D06A
VIC4_CHARPTRMB          = $D06B
VIC4_TEXTXPOS           = $D04C
VIC4_TEXTYPOS           = $D04E
VIC4_CHRCOUNT           = $D05E
VIC4_SPRXMSB9           = $D05F
VIC4_SPRPTRADRLSB       = $D06C
VIC4_SPRPTRADRMSB       = $D06D
VIC4_SPRPTRBNK          = $D06E
VIC4_SPRYMSB8           = $D077
VIC4_SPRYMSB9           = $D078
VIC4_DISPROWS           = $D07B
MEGA_KEYQUEUE           = $D610

CIA1_PORT_B             = $DC01
CIA1_PORT_A             = $DC00
CIA1_DDRA               = $DC02
CIA1_DDRB               = $DC03
M65_POT_PORT_A_X        = $D620
M65_POT_PORT_A_Y        = $D621

SPRITE0_X               = $D000
SPRITE0_Y               = $D001
SPRITE_X_MSB            = $D010
SPRITE_ENABLE           = $D015
SPRITE_Y_EXPAND         = $D017
SPRITE_PRIORITY         = $D01B
SPRITE_MULTICOLOR       = $D01C
SPRITE_X_EXPAND         = $D01D
SPRITE0_COLOR           = $D027

SCREEN_RAM              = $16000
CHAR_DATA               = $40000
CHAR_CODE_BASE          = $1000          ; CHAR_DATA / 64

PTR                     = $FC

VIEW_COLS               = 80
VIEW_ROWS               = 25
NCM_CELL_PIXELS         = 8
SPRITE_SCREEN_X         = 24
SPRITE_SCREEN_Y         = 50
MOUSE_MAX_X             = (VIEW_COLS * NCM_CELL_PIXELS) - 1
MOUSE_MAX_Y_STEP        = 24
MOUSE_POINTER_WIDTH     = 9
MOUSE_POINTER_MAX_X     = MOUSE_MAX_X - MOUSE_POINTER_WIDTH + 1
MOUSE_WRAP_LOW_X        = 64
MOUSE_WRAP_HIGH_X       = MOUSE_MAX_X - MOUSE_WRAP_LOW_X + 1
MOUSE_SPRITE_MAX_Y      = 249
MOUSE_BUTTON_LEFT       = $10
MOUSE_POT_PORT1_SELECT  = $7F
CPU_40MHZ_BIT           = $40

NCM_DIAG_LAST_STEP      = 11

;=======================================================================================
; BASIC stub - SYS 8210 ($2012)
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
; Main
;=======================================================================================

main_entry:
        cld
        cli

        jsr enable_40mhz
        jsr ncm_diag_init
        sei
        jsr mouse_init

main_loop:
        jsr wait_frame
        jsr ncm_diag_poll_key
        jsr mouse_poll
        jmp main_loop

enable_40mhz:
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

wait_frame:
        lda VIC_RASTER
_wf_wait_bottom:
        cmp #$F0
        bcs _wf_wait_top
        lda VIC_RASTER
        jmp _wf_wait_bottom
_wf_wait_top:
        lda VIC_RASTER
        cmp #$20
        bcs _wf_wait_top
        rts

;=======================================================================================
; NCM diagnostic stepper
;=======================================================================================

ncm_diag_init:
        stz ncm_diag_step
        stz MEGA_KEYQUEUE
        lda #0
        sta BORDERCOL
        sta BACKCOL
        rts

ncm_diag_poll_key:
        lda MEGA_KEYQUEUE
        beq _ndpk_done
        stz MEGA_KEYQUEUE

        lda ncm_diag_step
        cmp #NCM_DIAG_LAST_STEP
        bcs _ndpk_done
        inc ncm_diag_step
        jmp ncm_diag_apply_step

_ndpk_done:
        rts

ncm_diag_apply_step:
        lda ncm_diag_step
        cmp #1
        beq _ndas_1_unlock
        cmp #2
        beq _ndas_2_vic4_ctrl
        cmp #3
        beq _ndas_3_screen_mode
        cmp #4
        beq _ndas_4_vic3_attr
        cmp #5
        beq _ndas_5_geometry
        cmp #6
        beq _ndas_6_reassert_ctrl
        cmp #7
        beq _ndas_7_pointers
        cmp #8
        beq _ndas_8_clear_color
        cmp #9
        beq _ndas_9_init_ncm
        cmp #10
        beq _ndas_10_clear_ncm
        cmp #11
        beq _ndas_11_repeat_ncm
        rts

_ndas_1_unlock:
        lda #$06
        sta BORDERCOL
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY
        lda #$80
        trb VIC4_HOTREGS
        rts

_ndas_2_vic4_ctrl:
        lda #$02
        sta BORDERCOL
        lda #%00000101
        sta VIC4_CTRL
        rts

_ndas_3_screen_mode:
        lda #$05
        sta BORDERCOL
        lda #40
        sta screen_mode
        rts

_ndas_4_vic3_attr:
        lda #$04
        sta BORDERCOL
        lda VIC3_CTRL
        and #%01011111
        ora #%10100000
        sta VIC3_CTRL
        rts

_ndas_5_geometry:
        lda #$03
        sta BORDERCOL
        lda #160
        sta VIC4_LINESTPLSB
        lda #0
        sta VIC4_LINESTPMSB
        lda #80
        sta VIC4_CHRCOUNT
        lda #VIEW_ROWS
        sta VIC4_DISPROWS
        lda #$50
        sta VIC4_TEXTXPOS
        lda #0
        sta VIC4_TEXTXPOS+1
        lda #$69
        sta VIC4_TEXTYPOS
        rts

_ndas_6_reassert_ctrl:
        lda #$07
        sta BORDERCOL
        lda VIC4_CTRL
        ora #%00000101
        sta VIC4_CTRL
        rts

_ndas_7_pointers:
        lda #$01
        sta BORDERCOL
        jsr ssm_setup_pointers
        jsr ssm_screen_on
        rts

_ndas_8_clear_color:
        lda #$08
        sta BORDERCOL
        lda #0
        jsr clear_color_ram_ncm
        rts

_ndas_9_init_ncm:
        lda #$09
        sta BORDERCOL
        jsr init_ncm
        rts

_ndas_10_clear_ncm:
        lda #$0A
        sta BORDERCOL
        jsr ssm_screen_off
        lda #0
        jsr clear_ncm
        jsr ssm_screen_on
        rts

_ndas_11_repeat_ncm:
        lda #$0B
        sta BORDERCOL
        jsr init_ncm_repeated
        rts

ssm_setup_pointers:
        lda #<SCREEN_RAM
        sta VIC4_SCRNPTRLSB
        lda #>SCREEN_RAM
        sta VIC4_SCRNPTRMSB
        lda #`SCREEN_RAM
        sta VIC4_SCRBPTRBNK
        lda #0
        sta VIC4_SCRNPTRMB

        lda #0
        sta VIC4_COLPTRLSB
        sta VIC4_COLPTRMSB
        sta VIC4_COLPTRBNK
        sta VIC4_COLPTRMB

        ; FCM/NCM tile addresses come from the 16-bit screen code
        ; (CHAR_DATA / 64). Keep CHARPTR at the ROM charset base, matching
        ; the m65-fcm demo setup.
        lda #$00
        sta VIC4_CHARPTRLSB
        lda #$d8
        sta VIC4_CHARPTRMSB
        lda #$02
        sta VIC4_CHARPTRBNK
        lda #0
        sta VIC4_CHARPTRMB
        rts

ssm_screen_on:
        lda $D011
        ora #%00010000
        sta $D011
        rts

ssm_screen_off:
        lda $D011
        and #%11101111
        sta $D011
        rts

;=======================================================================================
; NCM helpers
;=======================================================================================

init_ncm:
        lda #<SCREEN_RAM
        sta PTR
        lda #>SCREEN_RAM
        sta PTR+1
        lda #`SCREEN_RAM
        sta PTR+2
        lda #0
        sta PTR+3

        lda #<CHAR_CODE_BASE
        sta _in_code
        lda #>CHAR_CODE_BASE
        sta _in_code+1

        lda #<2000
        sta _in_cnt
        lda #>2000
        sta _in_cnt+1

_in_loop:
        ldz #0
        lda _in_code
        sta [PTR],z
        inz
        lda _in_code+1
        sta [PTR],z

        inc _in_code
        bne +
        inc _in_code+1
+
        clc
        lda PTR
        adc #2
        sta PTR
        bcc +
        inc PTR+1
        bne +
        inc PTR+2
+
        lda _in_cnt
        bne +
        dec _in_cnt+1
+       dec _in_cnt
        lda _in_cnt
        ora _in_cnt+1
        bne _in_loop
        rts

_in_code:
        .word 0
_in_cnt:
        .word 0

init_ncm_repeated:
        lda #<SCREEN_RAM
        sta PTR
        lda #>SCREEN_RAM
        sta PTR+1
        lda #`SCREEN_RAM
        sta PTR+2
        lda #0
        sta PTR+3

        lda #<2000
        sta _inr_cnt
        lda #>2000
        sta _inr_cnt+1

_inr_loop:
        ldz #0
        lda #<CHAR_CODE_BASE
        sta [PTR],z
        inz
        lda #>CHAR_CODE_BASE
        sta [PTR],z

        clc
        lda PTR
        adc #2
        sta PTR
        bcc +
        inc PTR+1
        bne +
        inc PTR+2
+
        lda _inr_cnt
        bne +
        dec _inr_cnt+1
+       dec _inr_cnt
        lda _inr_cnt
        ora _inr_cnt+1
        bne _inr_loop
        rts

_inr_cnt:
        .word 0

clear_ncm:
        and #$0F
        sta _cn_nibble
        asl
        asl
        asl
        asl
        ora _cn_nibble
        sta _cn_fill

        ; 640 NCM mode uses 2000 chars * 64 bytes = 128000 bytes.
        ; DMA 1 clears $40000-$4FFFF.
        lda _cn_fill
        sta _cn_80_val1
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $03
        .word $0000             ; 0 means 65536
_cn_80_val1:
        .byte $00, $00
        .byte $00
        .word $0000
        .byte $04
        .byte $00
        .word $0000

        ; DMA 2 clears the remaining 62464 bytes at $50000.
        lda _cn_fill
        sta _cn_80_val2
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $03
        .word 62464
_cn_80_val2:
        .byte $00, $00
        .byte $00
        .word $0000
        .byte $05
        .byte $00
        .word $0000
        rts

_cn_fill:
        .byte 0
_cn_nibble:
        .byte 0

clear_color_ram_ncm:
        and #$0F
        asl
        asl
        asl
        asl
        ora #$08
        sta _ccrn_color

        ; Two color-RAM bytes per visible NCM screen position.
        ; 80 * 25 * 2 = 4000 bytes total. First clear byte 0, then fill
        ; byte 1 with NCM bit set and palette base 0.
        lda #$00
        sta $D707
        .byte $81, $FF
        .byte $00
        .byte $03
        .word 4000
        .byte $00, $00
        .byte $00
        .word $0000
        .byte $08
        .byte $00
        .word $0000

        lda #$00
        sta $D707
        .byte $81, $FF
        .byte $85, $02
        .byte $84, $00
        .byte $00
        .byte $03
        .word 2000
_ccrn_color:
        .byte $08, $00
        .byte $00
        .word $0001
        .byte $08
        .byte $00
        .word $0000
        rts

;=======================================================================================
; Minimal 1351 mouse + sprite 0 pointer
;=======================================================================================

mouse_init:
        lda #<160
        sta mouse_x
        lda #>160
        sta mouse_x+1
        lda #100
        sta mouse_y
        stz mouse_y+1
        lda #$FF
        sta mouse_sprite_mode

        jsr mouse_seed_pot_baseline
        jsr mouse_sprite_init
        jsr mouse_use_pointer_shape
        jmp mouse_position_pointer_sprite

mouse_poll:
        jsr mouse_read_motion
        jsr mouse_use_pointer_shape
        jsr mouse_position_pointer_sprite
        jmp mouse_debug_position_colors

mouse_sprite_init:
        lda #<mouse_sprite_ptrs
        sta VIC4_SPRPTRADRLSB
        lda #>mouse_sprite_ptrs
        sta VIC4_SPRPTRADRMSB
        lda #$80                ; 16-bit sprite pointers, bank 0
        sta VIC4_SPRPTRBNK

        lda #$02                ; red, visible against the white/yellow garbage
        sta SPRITE0_COLOR

        lda SPRITE_MULTICOLOR
        and #$FE
        sta SPRITE_MULTICOLOR
        lda SPRITE_X_EXPAND
        and #$FE
        sta SPRITE_X_EXPAND
        lda SPRITE_Y_EXPAND
        and #$FE
        sta SPRITE_Y_EXPAND
        lda SPRITE_PRIORITY
        and #$FE
        sta SPRITE_PRIORITY

        lda SPRITE_ENABLE
        ora #$01
        sta SPRITE_ENABLE
        rts

mouse_read_motion:
        ldz #$00
        php
        sei
        lda CIA1_PORT_A
        sta mouse_saved_pra
        lda CIA1_DDRA
        sta mouse_saved_ddra
        lda CIA1_DDRB
        sta mouse_saved_ddrb

        jsr mouse_prepare_1351_read
        jsr mouse_select_port1_pots
        jsr mouse_settle_pots

        ; Sample both axes before doing any per-axis work.
        jsr mouse_read_pot_x
        sta mouse_potx_sample
        jsr mouse_read_pot_y
        sta mouse_poty_sample

        lda mouse_potx_sample
        ldy mouse_old_pot_x
        jsr mouse_move_check
        sty mouse_old_pot_x
        bcc +
        jsr mouse_double_delta
        jsr mouse_apply_delta_x
+
        lda mouse_poty_sample
        ldy mouse_old_pot_y
        jsr mouse_move_check
        sty mouse_old_pot_y
        bcc _mrm_done_y
        jsr mouse_double_delta
        jsr mouse_apply_delta_y

_mrm_done_y:
        lda mouse_saved_pra
        sta CIA1_PORT_A
        lda mouse_saved_ddra
        sta CIA1_DDRA
        lda mouse_saved_ddrb
        sta CIA1_DDRB
        plp
        rts

mouse_seed_pot_baseline:
        php
        sei
        lda CIA1_PORT_A
        sta mouse_saved_pra
        lda CIA1_DDRA
        sta mouse_saved_ddra
        lda CIA1_DDRB
        sta mouse_saved_ddrb

        jsr mouse_prepare_1351_read
        jsr mouse_select_port1_pots
        jsr mouse_settle_pots
        jsr mouse_read_pot_x
        sta mouse_old_pot_x
        jsr mouse_read_pot_y
        sta mouse_old_pot_y

        lda mouse_saved_pra
        sta CIA1_PORT_A
        lda mouse_saved_ddra
        sta CIA1_DDRA
        lda mouse_saved_ddrb
        sta CIA1_DDRB
        plp
        rts

mouse_prepare_1351_read:
        lda #0
        sta CIA1_DDRB
        sta CIA1_DDRA
        rts

mouse_select_port1_pots:
        lda CIA1_DDRA
        ora #%11000000
        sta CIA1_DDRA
        lda #MOUSE_POT_PORT1_SELECT
        sta CIA1_PORT_A
        rts

mouse_settle_pots:
        ldy #24
_msp_outer:
        ldx #0
_msp_inner:
        dex
        bne _msp_inner
        dey
        bne _msp_outer
        rts

mouse_debug_position_colors:
        lda ncm_diag_step
        cmp #9
        bcc _mdpc_done

        lda mouse_y+1
        beq _mdpc_show_low
        lda #$02                ; red = high byte is nonzero
        sta BORDERCOL
        lda #0
        sta BACKCOL
        rts

_mdpc_show_low:
        lda mouse_y
        and #$0F
        sta BORDERCOL
        lda #0
        sta BACKCOL
_mdpc_done:
        rts

mouse_read_pot_x:
        lda M65_POT_PORT_A_X
        cmp M65_POT_PORT_A_X
        bne mouse_read_pot_x
        and #$7E
        rts

mouse_read_pot_y:
        lda M65_POT_PORT_A_Y
        cmp M65_POT_PORT_A_Y
        bne mouse_read_pot_y
        and #$7E
        rts

mouse_move_check:
        sty mouse_old_value
        sta mouse_new_value
        ldx #0

        sec
        sbc mouse_old_value
        cmp #$3F
        bcs _mmc_not_positive

        ldy mouse_new_value
        ldx #0
        sec
        rts

_mmc_not_positive:
        cmp #$C0
        bcc _mmc_no_move
        ldy mouse_new_value
        ldx #$FF
        sec
        rts

_mmc_no_move:
        ldy mouse_new_value
        txa
        clc
        rts

mouse_double_delta:
        asl
        pha
        txa
        rol
        tax
        pla
        rts

mouse_apply_delta_x:
        sta mouse_delta
        stx mouse_delta+1

        clc
        lda mouse_x
        adc mouse_delta
        sta mouse_next
        lda mouse_x+1
        adc mouse_delta+1
        sta mouse_next+1

        lda mouse_x+1
        bne _madx_check_right_wrap
        lda mouse_x
        cmp #MOUSE_WRAP_LOW_X
        bcs _madx_check_right_wrap
        lda mouse_next+1
        cmp #>MOUSE_WRAP_HIGH_X
        bcc _madx_bounds
        bne _madx_done
        lda mouse_next
        cmp #<MOUSE_WRAP_HIGH_X
        bcs _madx_done

_madx_check_right_wrap:
        lda mouse_x+1
        cmp #>MOUSE_WRAP_HIGH_X
        bcc _madx_bounds
        bne _madx_check_right_next
        lda mouse_x
        cmp #<MOUSE_WRAP_HIGH_X
        bcc _madx_bounds

_madx_check_right_next:
        lda mouse_next+1
        bne _madx_bounds
        lda mouse_next
        cmp #MOUSE_WRAP_LOW_X
        bcc _madx_done

_madx_bounds:
        lda mouse_next+1
        bmi _madx_min
        cmp #>MOUSE_MAX_X
        bcc _madx_store
        bne _madx_max
        lda mouse_next
        cmp #<(MOUSE_MAX_X + 1)
        bcc _madx_store

_madx_max:
        lda #<MOUSE_MAX_X
        sta mouse_x
        lda #>MOUSE_MAX_X
        sta mouse_x+1
        rts

_madx_min:
        stz mouse_x
        stz mouse_x+1
        rts

_madx_store:
        lda mouse_next
        sta mouse_x
        lda mouse_next+1
        sta mouse_x+1
_madx_done:
        rts

mouse_apply_delta_y:
        ; 8-bit Y accumulator. Clamp signed delta (X:A) to
        ; +/-MOUSE_MAX_Y_STEP, then apply it without ever letting mouse_y+1
        ; participate in the math. This avoids the step-9 failure mode where
        ; a nonzero high byte repeatedly forced the bottom clamp.
        cpx #0
        bne _mady_neg

        ; Positive delta: move up, y = max(y - delta, 0).
        cmp #(MOUSE_MAX_Y_STEP + 1)
        bcc _mady_pos_have_delta
        lda #MOUSE_MAX_Y_STEP
_mady_pos_have_delta:
        sta mouse_delta
        sec
        lda mouse_y
        sbc mouse_delta
        bcs _mady_store_a

_mady_min:
        stz mouse_y
        stz mouse_y+1
        rts

_mady_neg:
        ; Negative delta: move down, y = min(y + abs(delta), max).
        cmp #(256 - MOUSE_MAX_Y_STEP)
        bcs _mady_neg_have_delta
        lda #(256 - MOUSE_MAX_Y_STEP)
_mady_neg_have_delta:
        eor #$FF
        clc
        adc #1
        sta mouse_delta

        clc
        lda mouse_y
        adc mouse_delta
        bcs _mady_max
        cmp #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y + 1)
        bcc _mady_store_a

_mady_max:
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
_mady_store_a:
        sta mouse_y
        stz mouse_y+1
        rts

mouse_position_pointer_sprite:
        lda mouse_x
        sta mouse_sprite_x
        lda mouse_x+1
        sta mouse_sprite_x+1

        lda mouse_sprite_x+1
        cmp #>MOUSE_POINTER_MAX_X
        bcc _mpps_add_screen_x
        bne _mpps_cap_x
        lda mouse_sprite_x
        cmp #<(MOUSE_POINTER_MAX_X + 1)
        bcc _mpps_add_screen_x

_mpps_cap_x:
        lda #<MOUSE_POINTER_MAX_X
        sta mouse_sprite_x
        lda #>MOUSE_POINTER_MAX_X
        sta mouse_sprite_x+1

_mpps_add_screen_x:
        clc
        lda mouse_sprite_x
        adc #<SPRITE_SCREEN_X
        sta mouse_sprite_x
        lda mouse_sprite_x+1
        adc #>SPRITE_SCREEN_X
        sta mouse_sprite_x+1

        lda mouse_y
        cmp #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y + 1)
        bcc _mpps_store_y
        lda #(MOUSE_SPRITE_MAX_Y - SPRITE_SCREEN_Y)
_mpps_store_y:
        clc
        adc #SPRITE_SCREEN_Y
        sta mouse_sprite_y
        jmp mouse_set_sprite_position

mouse_set_sprite_position:
        lda SPRITE_X_MSB
        and #$FE
        sta SPRITE_X_MSB
        lda mouse_sprite_x+1
        and #$01
        beq +
        lda SPRITE_X_MSB
        ora #$01
        sta SPRITE_X_MSB
+
        lda VIC4_SPRXMSB9
        and #$FE
        sta VIC4_SPRXMSB9
        lda mouse_sprite_x+1
        and #$02
        beq +
        lda VIC4_SPRXMSB9
        ora #$01
        sta VIC4_SPRXMSB9
+
        lda VIC4_SPRYMSB8
        and #$FE
        sta VIC4_SPRYMSB8
        lda VIC4_SPRYMSB9
        and #$FE
        sta VIC4_SPRYMSB9

        lda mouse_sprite_x
        sta SPRITE0_X
        lda mouse_sprite_y
        sta SPRITE0_Y
        rts

mouse_use_pointer_shape:
        lda mouse_sprite_mode
        beq _mups_done
        stz mouse_sprite_mode
        lda #<(mouse_pointer_sprite / 64)
        sta mouse_sprite_ptrs
        lda #>(mouse_pointer_sprite / 64)
        sta mouse_sprite_ptrs+1
_mups_done:
        rts

;=======================================================================================
; Variables and sprite data
;=======================================================================================

screen_mode:
        .byte 0
ncm_diag_step:
        .byte 0

mouse_x:
        .word 0
mouse_y:
        .word 0
mouse_next:
        .word 0
mouse_delta:
        .word 0
mouse_potx_sample:
        .byte 0
mouse_poty_sample:
        .byte 0
mouse_sprite_x:
        .word 0
mouse_sprite_y:
        .byte 0
mouse_old_pot_x:
        .byte 0
mouse_old_pot_y:
        .byte 0
mouse_old_value:
        .byte 0
mouse_new_value:
        .byte 0
mouse_sprite_mode:
        .byte 0
mouse_saved_ddra:
        .byte 0
mouse_saved_ddrb:
        .byte 0
mouse_saved_pra:
        .byte 0

        .align 16
mouse_sprite_ptrs:
        .fill 16, 0

        .align 64
mouse_pointer_sprite:
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
