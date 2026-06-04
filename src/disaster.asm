;=======================================================================================
; Resident disaster state + overlay invoke.
;
; The selector UI lives in overlays/ovr-disaster.asm and is streamed into the
; shared $A000 overlay window on demand. This file only keeps the durable
; selected-disaster value and the tiny DMA stub used by toolbar.asm.
;=======================================================================================

DISASTER_NONE           = 0
DISASTER_FIRE           = 1
DISASTER_TORNADO        = 2
DISASTER_EARTHQUAKE     = 3
DISASTER_FLOOD          = 4
DISASTER_RIOT           = 5
DISASTER_MONSTER        = 6

disaster_invoke:
        lda #$00
        sta $D707
        .byte $80, ATTIC_OVR_DISASTER_MB
        .byte $81, $00
        .byte $00
        .byte $00
        .word OVR_WINDOW_SIZE
        .word ATTIC_OVR_DISASTER_ADDR
        .byte ATTIC_OVR_DISASTER_BANK
        .word OVR_WINDOW_ADDR
        .byte $00
        .byte $00
        .word $0000

        jmp OVR_WINDOW_ADDR

disaster_selected:
        .byte DISASTER_NONE
