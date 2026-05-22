;=======================================================================================
; Runtime tile cache.
;
; City tiles are authored as 16x16 assets on disk. Boot loads the tile PRG into
; Attic RAM; this module DMA-copies that bank into VIC-visible NCM character RAM.
;=======================================================================================

SET_COLOR .macro index, red, green, blue
        lda #\index
        ldx #\red
        ldy #\green
        ldz #\blue
        jsr set_palette_color
.endmacro

tiles_init_palette:
        #SET_COLOR 0, 0, 0, 0       ; black / transparent-looking interior
        #SET_COLOR 1, 0, 3, 10      ; water
        #SET_COLOR 2, 2, 10, 2      ; grass
        #SET_COLOR 3, 0, 6, 1       ; dark green
        #SET_COLOR 4, 9, 5, 1       ; dirt
        #SET_COLOR 5, 6, 6, 6       ; road
        #SET_COLOR 6, 15, 13, 1     ; stripe / yellow text
        #SET_COLOR 7, 6, 13, 4      ; residential green
        #SET_COLOR 8, 2, 6, 14      ; commercial blue
        #SET_COLOR 9, 12, 6, 1      ; industrial orange
        #SET_COLOR 10, 15, 14, 2    ; power / prompt
        #SET_COLOR 11, 3, 3, 3      ; dark gray
        #SET_COLOR 12, 13, 13, 13   ; light gray UI panel
        #SET_COLOR 13, 14, 2, 2     ; red
        #SET_COLOR 14, 2, 14, 15    ; cyan
        #SET_COLOR 15, 15, 15, 15   ; white
        rts

tiles_load:
        jsr tiles_dma_city_from_attic
        jsr tiles_load_cursor
        rts

tiles_dma_city_from_attic:
        lda #$00
        sta $D707
        .byte $80, ATTIC_TILE_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word TILESET_BODY_SIZE
        .word ATTIC_TILE_ADDR
        .byte ATTIC_TILE_BANK
        .word $0000             ; low 16 bits of CHAR_DATA ($40000)
        .byte `CHAR_DATA
        .byte $00
        .word $0000
        rts

tiles_load_cursor:
        lda #CITY_CHAR_CURSOR
        ldx #<ncm_cursor_tl
        ldy #>ncm_cursor_tl
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+1
        ldx #<ncm_cursor_tr
        ldy #>ncm_cursor_tr
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+2
        ldx #<ncm_cursor_bl
        ldy #>ncm_cursor_bl
        jsr create_ncm_char

        lda #CITY_CHAR_CURSOR+3
        ldx #<ncm_cursor_br
        ldy #>ncm_cursor_br
        jsr create_ncm_char
        rts

ncm_cursor_tl:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00

ncm_cursor_tr:
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F

ncm_cursor_bl:
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$00,$00,$00,$00,$00,$00,$00
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

ncm_cursor_br:
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $00,$00,$00,$00,$00,$00,$00,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
