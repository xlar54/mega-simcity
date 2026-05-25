;=======================================================================================
; MEGA65 FCM screen setup.
;
; Derived from the local m65-fcm screen setup. set_screen_mode brings up the FCM
; display whose width follows VIEW_COLS (H320 at 40 columns, H640 above) and
; restores the default screen on exit.
;=======================================================================================

screen_mode:
        .byte 0                 ; m65-fcm helper value; 20 means 40 screen positions

ssm_mode:
        .byte 0

set_screen_mode:
        sta ssm_mode
        cmp #MODE_BASIC
        bne _ssm_check_fcm40
        jmp restore_default_screen

_ssm_check_fcm40:
        cmp #MODE_FCM40
        beq _ssm_fcm_init
        jmp restore_default_screen

_ssm_fcm_init:
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY

        lda #$80
        trb $D05D               ; disable hot registers

        lda #(%00000101 | VIC_SPRH640_BIT)  ; FCLRHI + CHR16, sprite-X width per VIEW_COLS
        sta VIC4_CTRL

        jsr ssm_screen_off

_ssm_fcm40:
        lda #FCM_SCREEN_MODE    ; screen_mode * 2 = VIEW_COLS screen positions
        sta screen_mode

        lda VIC3_CTRL
        and #%01011111
        sta VIC3_CTRL
        lda VIC3_CTRL
        ora #(%00100000 | VIC_H640_BIT)     ; attribute mode + H640/H320 per VIEW_COLS
        sta VIC3_CTRL

        lda #<VIC_LINESTEP      ; VIEW_COLS * 2 bytes per row
        sta VIC4_LINESTPLSB
        lda #>VIC_LINESTEP
        sta VIC4_LINESTPMSB

        lda #VIC_CHRCOUNT
        sta VIC4_CHRCOUNT

        lda #VIEW_ROWS
        sta VIC4_DISPROWS

        lda #$50
        sta VIC4_TEXTXPOS
        lda #0
        sta VIC4_TEXTXPOS+1
        lda #$69
        sta VIC4_TEXTYPOS

        lda VIC4_CTRL
        and #%11101111          ; clear SPRH640, then set it per VIEW_COLS
        ora #(%00000101 | VIC_SPRH640_BIT) ; FCLRHI + CHR16 + sprite-X width
        sta VIC4_CTRL

        jsr ssm_setup_pointers

        lda #0
        jsr clear_color_ram_fcm
        lda #0
        jsr clear_fcm

        lda #0
        sta BORDERCOL
        sta BACKCOL
        jmp ssm_screen_on

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

        ; FCM/FCM tile addresses come from the 16-bit screen code
        ; (CHAR_DATA / 64). Keep CHARPTR at the ROM charset base like m65-fcm.
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

restore_default_screen:
        lda #$47
        sta VIC4_KEY
        lda #$53
        sta VIC4_KEY

        lda #$80
        tsb $D05D

        lda #0
        sta VIC4_CTRL

        lda VIC3_CTRL
        ora #%10000000
        and #%11011111
        sta VIC3_CTRL

        lda #80
        sta VIC4_LINESTPLSB
        lda #0
        sta VIC4_LINESTPMSB

        lda #80
        sta VIC4_CHRCOUNT

        lda #$00
        sta VIC4_SCRNPTRLSB
        lda #$08
        sta VIC4_SCRNPTRMSB
        lda #$00
        sta VIC4_SCRBPTRBNK
        sta VIC4_SCRNPTRMB

        lda #$00
        sta VIC4_CHARPTRLSB
        lda #$D0
        sta VIC4_CHARPTRMSB
        lda #$02
        sta VIC4_CHARPTRBNK
        lda #$00
        sta VIC4_CHARPTRMB

        lda #25
        sta VIC4_DISPROWS

        lda #$50
        sta VIC4_TEXTXPOS
        lda #0
        sta VIC4_TEXTXPOS+1
        lda #$68
        sta VIC4_TEXTYPOS

        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $FF
        .byte $00
        .byte $03
        .word 5632
        .byte $05, $00
        .byte $00
        .word $0000
        .byte $08
        .byte $00
        .word $0000

        jsr restore_default_palette
        jsr $FF81
        jsr $FF84

        lda #$06
        sta BORDERCOL
        sta BACKCOL
        rts

restore_default_palette:
        ldx #0
_rdp_loop:
        lda _rdp_defaults,x
        sta $D100,x
        lda _rdp_defaults+16,x
        sta $D200,x
        lda _rdp_defaults+32,x
        sta $D300,x
        inx
        cpx #16
        bne _rdp_loop
        rts

_rdp_defaults:
        .byte $00,$0F,$0F,$00,$0F,$00,$00,$0F
        .byte $0F,$0A,$0F,$05,$08,$09,$09,$0B
        .byte $00,$0F,$00,$0F,$00,$0F,$00,$0F
        .byte $06,$04,$07,$05,$08,$0F,$09,$0B
        .byte $00,$0F,$00,$0F,$0F,$00,$0F,$00
        .byte $00,$00,$07,$05,$08,$09,$0F,$0B

set_palette_color:
        sta _spc_idx
        stx _spc_r
        sty _spc_g
        tza
        sta _spc_b
        ldx _spc_idx
        lda _spc_r
        sta $D100,x
        lda _spc_g
        sta $D200,x
        lda _spc_b
        sta $D300,x
        rts

_spc_idx:
        .byte 0
_spc_r:
        .byte 0
_spc_g:
        .byte 0
_spc_b:
        .byte 0
