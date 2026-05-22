;=======================================================================================
; NCM helpers for MEGA65.
;
; Based on C:\Users\scott\repos\m65-fcm\src\ncm.asm, narrowed to the routines
; the city scaffold needs.
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

        ldx #0
        lda screen_mode
        cmp #40
        bne +
        ldx #2
+       lda _in_counts,x
        sta _in_cnt
        lda _in_counts+1,x
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
_in_counts:
        .word 1000, 2000

init_ncm_20x25:
        lda #<SCREEN_RAM
        sta PTR
        lda #>SCREEN_RAM
        sta PTR+1
        lda #`SCREEN_RAM
        sta PTR+2
        lda #0
        sta PTR+3

        lda #<CHAR_CODE_BASE
        sta _in20_code
        lda #>CHAR_CODE_BASE
        sta _in20_code+1

        lda #<500
        sta _in20_cnt
        lda #>500
        sta _in20_cnt+1

_in20_loop:
        ldz #0
        lda _in20_code
        sta [PTR],z
        inz
        lda _in20_code+1
        sta [PTR],z

        inc _in20_code
        bne +
        inc _in20_code+1
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
        lda _in20_cnt
        bne +
        dec _in20_cnt+1
+       dec _in20_cnt
        lda _in20_cnt
        ora _in20_cnt+1
        bne _in20_loop
        rts

_in20_code:
        .word 0
_in20_cnt:
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

        lda screen_mode
        cmp #40
        beq _cn_80col

        lda _cn_fill
        sta _cn_40_val
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $03
        .word 64000
_cn_40_val:
        .byte $00, $00
        .byte $00
        .word $0000
        .byte $04
        .byte $00
        .word $0000
        rts

_cn_80col:
        lda _cn_fill
        sta _cn_80_val1
        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, $00
        .byte $00
        .byte $03
        .word $0000
_cn_80_val1:
        .byte $00, $00
        .byte $00
        .word $0000
        .byte $04
        .byte $00
        .word $0000

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

        ldx #0
        lda screen_mode
        cmp #40
        bne +
        ldx #2
+       lda _ccrn_byte_counts,x
        sta _ccrn_dma1_cnt
        lda _ccrn_byte_counts+1,x
        sta _ccrn_dma1_cnt+1
        lda _ccrn_pos_counts,x
        sta _ccrn_dma2_cnt
        lda _ccrn_pos_counts+1,x
        sta _ccrn_dma2_cnt+1

        lda #$00
        sta $D707
        .byte $81, $FF
        .byte $00
        .byte $03
_ccrn_dma1_cnt:
        .word 2000
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
_ccrn_dma2_cnt:
        .word 1000
_ccrn_color:
        .byte $08, $00
        .byte $00
        .word $0001
        .byte $08
        .byte $00
        .word $0000
        rts

_ccrn_byte_counts:
        .word 2000, 4000
_ccrn_pos_counts:
        .word 1000, 2000

create_ncm_char:
        sta _cnc_char_idx
        stx PTR2
        sty PTR2+1

        lda _cnc_char_idx
        sta MULTINA
        lda #0
        sta MULTINA+1
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

        ldy #0
_cnc_loop:
        tya
        taz
        lda (PTR2),y
        sta [PTR],z
        iny
        cpy #64
        bne _cnc_loop
        rts

_cnc_char_idx:
        .byte 0

set_ncm_char:
        sta _snc_char
        stx _snc_col
        sty _snc_row

        lda _snc_row
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3

        lda screen_mode
        asl
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3

        clc
        lda MULTOUT
        adc _snc_col
        sta _snc_pos
        lda MULTOUT+1
        adc #0
        sta _snc_pos+1

        asl _snc_pos
        rol _snc_pos+1

        clc
        lda #<SCREEN_RAM
        adc _snc_pos
        sta PTR
        lda #>SCREEN_RAM
        adc _snc_pos+1
        sta PTR+1
        lda #`SCREEN_RAM
        adc #0
        sta PTR+2
        lda #0
        sta PTR+3

        ldz #0
        clc
        lda #<CHAR_CODE_BASE
        adc _snc_char
        sta [PTR],z
        inz
        lda #>CHAR_CODE_BASE
        adc #0
        sta [PTR],z
        rts

_snc_char:
        .byte 0
_snc_col:
        .byte 0
_snc_row:
        .byte 0
_snc_pos:
        .word 0

set_ncm_palette:
        pha
        stx _snp_col
        sty _snp_row

        lda _snp_row
        sta MULTINA
        lda #0
        sta MULTINA+1
        sta MULTINA+2
        sta MULTINA+3

        lda screen_mode
        asl
        sta MULTINB
        lda #0
        sta MULTINB+1
        sta MULTINB+2
        sta MULTINB+3

        clc
        lda MULTOUT
        adc _snp_col
        sta _snp_pos
        lda MULTOUT+1
        adc #0
        sta _snp_pos+1

        asl _snp_pos
        rol _snp_pos+1

        clc
        lda _snp_pos
        sta PTR
        lda _snp_pos+1
        sta PTR+1
        lda #$F8
        sta PTR+2
        lda #$0F
        sta PTR+3

        ldz #0
        lda #0
        sta [PTR],z
        inz
        pla
        and #$0F
        asl
        asl
        asl
        asl
        ora #$08
        sta [PTR],z
        rts

_snp_col:
        .byte 0
_snp_row:
        .byte 0
_snp_pos:
        .word 0
