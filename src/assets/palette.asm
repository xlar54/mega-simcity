;=======================================================================================
; Palette asset.
;
; Emits a PRG file whose body is 768 bytes laid out as three 256-byte planes:
;   bytes 0..255   = R values (one per palette index 0..255)
;   bytes 256..511 = G values
;   bytes 512..767 = B values
;
; Each byte is in MEGA65 nibble-swapped format (display value $37 stored as
; $73), so the body is a verbatim drop-in for VIC-IV palette registers
; $D100/$D200/$D300. The 2-byte PRG header lets the boot loader and the
; tile editor (src/tile-edit.asm) load+save with the same A=$40 (explicit
; address) convention and skip the header at staging+2.
;
; Indices 0..36 use the colours the game has always used. Indices 37..255
; are zero-filled -- room for the tile/palette editor to populate without
; changing the file format.
;=======================================================================================

        .cpu "45gs02"

; Origin $0000 makes the PRG header $00 $00, matching what the tile editor
; emits at te_save_palette_to_disk (tile-edit.asm:817-820) so an editor-saved
; PALETTE round-trips cleanly through the boot loader.
        * = $0000

; Nibble-swap one channel byte (display value -> VIC-IV palette byte).
PB .macro v
        .byte ((\v & $0F) << 4) | ((\v >> 4) & $0F)
.endmacro

palette_body:

;---------------------------------------------------------------------------------------
; R plane (256 bytes)
;---------------------------------------------------------------------------------------
        #PB 0      ; 0  black
        #PB 0      ; 1  water
        #PB 32     ; 2  grass
        #PB 0      ; 3  dark green
        #PB 160    ; 4  ground / dirt
        #PB 96     ; 5  road
        #PB 240    ; 6  yellow text / stripe
        #PB 96     ; 7  residential green
        #PB 32     ; 8  commercial blue
        #PB 192    ; 9  industrial orange
        #PB 240    ; 10 power / prompt
        #PB 48     ; 11 dark gray
        #PB 208    ; 12 light gray UI panel
        #PB 224    ; 13 red
        #PB 32     ; 14 cyan
        #PB 240    ; 15 white
        #PB 116    ; 16 ground brown
        #PB 105    ; 17
        #PB 114    ; 18
        #PB 109    ; 19
        #PB 115    ; 20
        #PB 112    ; 21
        #PB 89     ; 22
        #PB 107    ; 23
        #PB 52     ; 24 water base
        #PB 44     ; 25 water dark band
        #PB 64     ; 26 water light band
        #PB 80     ; 27 water ripple
        #PB 232    ; 28 bulldozer salmon
        #PB 124    ; 29 maroon
        #PB 44     ; 30 navy
        #PB 113    ; 31 road top brown
        #PB 102    ; 32 asphalt
        #PB 156    ; 33 lane marking
        #PB 63     ; 34 road shadow
        #PB 117    ; 35 road bottom brown
        #PB 156    ; 36 power-pole wood
        .fill 256 - 37, 0

;---------------------------------------------------------------------------------------
; G plane (256 bytes)
;---------------------------------------------------------------------------------------
        #PB 0
        #PB 48
        #PB 160
        #PB 96
        #PB 112
        #PB 96
        #PB 208
        #PB 208
        #PB 96
        #PB 96
        #PB 224
        #PB 48
        #PB 208
        #PB 32
        #PB 224
        #PB 240
        #PB 86
        #PB 75
        #PB 85
        #PB 83
        #PB 81
        #PB 80
        #PB 70
        #PB 74
        #PB 104
        #PB 92
        #PB 118
        #PB 134
        #PB 148
        #PB 68
        #PB 44
        #PB 86
        #PB 103
        #PB 155
        #PB 56
        #PB 85
        #PB 100
        .fill 256 - 37, 0

;---------------------------------------------------------------------------------------
; B plane (256 bytes)
;---------------------------------------------------------------------------------------
        #PB 0
        #PB 160
        #PB 32
        #PB 16
        #PB 64
        #PB 96
        #PB 16
        #PB 64
        #PB 224
        #PB 16
        #PB 32
        #PB 48
        #PB 208
        #PB 32
        #PB 240
        #PB 240
        #PB 46
        #PB 34
        #PB 55
        #PB 57
        #PB 43
        #PB 59
        #PB 59
        #PB 35
        #PB 180
        #PB 165
        #PB 196
        #PB 208
        #PB 112
        #PB 66
        #PB 60
        #PB 66
        #PB 99
        #PB 155
        #PB 49
        #PB 56
        #PB 52
        .fill 256 - 37, 0

palette_body_end:

        .cerror palette_body_end - palette_body != 768, "palette body must be exactly 768 bytes (256 R + 256 G + 256 B)"
