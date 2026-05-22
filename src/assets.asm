;=======================================================================================
; Boot-time disk asset loading.
;
; The tile PRG is KERNAL-loaded to chip-RAM staging, then DMA-copied to Attic.
; The visible NCM character cache is populated from Attic by tiles_load.
;=======================================================================================

boot_load_tileset:
_blt_retry:
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda #tileset_name_end - tileset_name
        ldx #<tileset_name
        ldy #>tileset_name
        jsr KERNAL_SETNAM
        lda #$40
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcs _blt_retry

        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, ATTIC_TILE_MB
        .byte $00
        .byte $00
        .word TILESET_BODY_SIZE
        .word TILESET_STAGE_ADDR + 2
        .byte $00
        .word ATTIC_TILE_ADDR
        .byte ATTIC_TILE_BANK
        .byte $00
        .word $0000
        rts

tileset_name:
        .text "tileset"
tileset_name_end:

boot_load_ui_tiles:
_blut_retry:
        lda #$00
        ldx #$00
        jsr KERNAL_SETBNK
        lda #0
        ldx #8
        ldy #0
        jsr KERNAL_SETLFS
        lda #ui_tiles_name_end - ui_tiles_name
        ldx #<ui_tiles_name
        ldy #>ui_tiles_name
        jsr KERNAL_SETNAM
        lda #$40
        ldx #<TILESET_STAGE_ADDR
        ldy #>TILESET_STAGE_ADDR
        jsr KERNAL_LOAD
        bcs _blut_retry

        lda #$00
        sta $D707
        .byte $80, $00
        .byte $81, ATTIC_UI_TILE_MB
        .byte $00
        .byte $00
        .word UI_TILE_ASSET_SIZE
        .word TILESET_STAGE_ADDR + 2
        .byte $00
        .word ATTIC_UI_TILE_ADDR
        .byte ATTIC_UI_TILE_BANK
        .byte $00
        .word $0000
        rts

ui_tiles_name:
        .text "uitiles"
ui_tiles_name_end:
