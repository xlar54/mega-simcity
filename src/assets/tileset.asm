;=======================================================================================
; Map-viewport FCM charset loaded from disk at boot.
;
; This file is char-indexed: byte offset char_id*64 contains the 8x8 FCM bitmap
; for that exact runtime char id. UI/control-only chars are blank here and get
; stamped later from assets.asm or uitiles.
;=======================================================================================

        .cpu "45gs02"
        .include "../platform.asm"
        .include "../shared/ui_tile_layout.asm"

; Origin is irrelevant: this is a position-independent data blob. The value only
; sets the 2-byte PRG load-address header, which the boot loader strips (it DMAs
; the body from staging+2 into Attic). $0000 so no reader infers a real address.
        * = $0000
tileset_start:

; TILE_WATER  (close blues $18-$1B, subtle horizontal ripple banding)
        ; TL cell
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$1A,$1A,$1A,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $19,$19,$19,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$1B,$1B,$18
        .byte $18,$18,$18,$18,$1A,$1A,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$1A
        ; TR cell
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$1A,$1A,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$19,$19,$19,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $1A,$1A,$1A,$18,$18,$18,$18,$18
        ; BL cell
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $19,$19,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$1A,$1A,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $19,$19,$19,$18,$18,$18,$18,$18
        ; BR cell
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$19,$19,$19,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$1B,$1B,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $1A,$1A,$1A,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$18,$18,$18
        .byte $18,$18,$18,$18,$18,$19,$19,$18

; TILE_GROUND  (8 exact sampled browns $10-$17, even fine-noise dither)
        ; TL cell
        .byte $13,$15,$15,$11,$11,$10,$17,$14
        .byte $13,$17,$12,$10,$17,$10,$16,$13
        .byte $12,$16,$13,$13,$15,$15,$12,$16
        .byte $17,$12,$10,$16,$11,$11,$11,$17
        .byte $13,$17,$12,$13,$17,$11,$12,$17
        .byte $15,$11,$13,$12,$12,$13,$12,$15
        .byte $15,$10,$16,$11,$15,$12,$16,$17
        .byte $17,$14,$13,$10,$17,$13,$12,$15
        ; TR cell
        .byte $16,$16,$10,$16,$10,$17,$17,$10
        .byte $16,$15,$17,$17,$12,$11,$10,$14
        .byte $12,$16,$11,$16,$16,$11,$12,$14
        .byte $15,$10,$17,$14,$15,$12,$15,$10
        .byte $14,$12,$13,$13,$17,$14,$14,$14
        .byte $16,$14,$11,$11,$14,$15,$13,$13
        .byte $14,$13,$14,$13,$11,$12,$11,$17
        .byte $10,$15,$14,$17,$13,$14,$11,$15
        ; BL cell
        .byte $11,$15,$11,$16,$15,$10,$11,$12
        .byte $13,$10,$12,$13,$12,$15,$12,$16
        .byte $16,$13,$12,$17,$17,$16,$16,$15
        .byte $12,$15,$15,$16,$16,$10,$10,$15
        .byte $13,$17,$15,$11,$16,$14,$16,$17
        .byte $14,$12,$13,$12,$13,$14,$15,$16
        .byte $10,$11,$16,$11,$12,$12,$13,$16
        .byte $13,$12,$13,$14,$16,$13,$11,$14
        ; BR cell
        .byte $16,$17,$10,$15,$14,$17,$12,$11
        .byte $15,$16,$14,$10,$11,$15,$14,$12
        .byte $14,$10,$14,$11,$17,$12,$11,$14
        .byte $10,$11,$17,$17,$16,$14,$17,$17
        .byte $15,$15,$11,$10,$14,$16,$10,$13
        .byte $14,$10,$11,$10,$13,$13,$10,$10
        .byte $11,$14,$17,$10,$14,$12,$10,$14
        .byte $16,$10,$10,$15,$13,$11,$17,$15

; Road tile block (chars 8-14; the road cell value equals its char index -- see
; platform.asm ROAD_CELL_*): 8 horizontal, 9 vertical (char 8 rotated 90 deg),
; 10 four-way (plain asphalt), 11-14 curves NW/NE/SW/SE. The renderer picks the
; orientation per cell from its road neighbours (see city.asm road_refresh).
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F   ; char 8 row 0: top edge brown
        .byte $20,$20,$20,$20,$20,$20,$20,$20   ; rows 1-5: asphalt
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$21,$21,$21,$21,$20,$20   ; row 3: lane marking (cols 2-5)
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 6: bottom shadow
        .byte $23,$23,$23,$23,$23,$23,$23,$23   ; row 7: bottom edge brown
        ; char 9: vertical road -- char 8 rotated 90 deg (curbs left/right, lane
        ; stripe top-to-bottom at col 4).
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .fill 64, $20                           ; char 10 = 4-way junction (plain asphalt)
        ; char 11 = curve NW (connects N+W; ground rounds the SE outside corner)
        .byte $20,$20,$20,$20,$21,$20,$20,$1F
        .byte $20,$20,$20,$20,$21,$20,$20,$1F
        .byte $20,$20,$20,$21,$20,$20,$20,$1F
        .byte $20,$20,$21,$20,$20,$20,$20,$1F
        .byte $20,$21,$20,$20,$20,$20,$20,$1F
        .byte $20,$20,$20,$20,$20,$20,$20,$13
        .byte $20,$20,$20,$20,$20,$20,$11,$16
        .byte $1F,$1F,$1F,$1F,$1F,$12,$15,$14
        ; char 12 = curve NE (connects N+E; ground rounds the SW outside corner)
        .byte $1F,$20,$20,$21,$20,$20,$20,$20
        .byte $1F,$20,$20,$21,$20,$20,$20,$20
        .byte $1F,$20,$20,$20,$21,$20,$20,$20
        .byte $1F,$20,$20,$20,$20,$21,$20,$20
        .byte $1F,$20,$20,$20,$20,$20,$21,$20
        .byte $13,$20,$20,$20,$20,$20,$20,$20
        .byte $16,$11,$20,$20,$20,$20,$20,$20
        .byte $14,$15,$12,$1F,$1F,$1F,$1F,$1F
        ; char 13 = curve SW (connects S+W; ground rounds the NE outside corner)
        .byte $1F,$1F,$1F,$1F,$1F,$12,$15,$14
        .byte $20,$20,$20,$20,$20,$20,$11,$16
        .byte $20,$20,$20,$20,$20,$20,$20,$13
        .byte $20,$21,$20,$20,$20,$20,$20,$1F
        .byte $20,$20,$21,$20,$20,$20,$20,$1F
        .byte $20,$20,$20,$21,$20,$20,$20,$1F
        .byte $20,$20,$20,$20,$21,$20,$20,$1F
        .byte $20,$20,$20,$20,$21,$20,$20,$1F
        ; char 14 = curve SE (connects S+E; ground rounds the NW outside corner)
        .byte $14,$15,$12,$1F,$1F,$1F,$1F,$1F
        .byte $16,$11,$20,$20,$20,$20,$20,$20
        .byte $13,$20,$20,$20,$20,$20,$20,$20
        .byte $1F,$20,$20,$20,$20,$20,$21,$20
        .byte $1F,$20,$20,$20,$20,$21,$20,$20
        .byte $1F,$20,$20,$20,$21,$20,$20,$20
        .byte $1F,$20,$20,$21,$20,$20,$20,$20
        .byte $1F,$20,$20,$21,$20,$20,$20,$20

        ; char 15 = T-junction T_N (connects N+E+W; dark border 1px in from south)
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        ; char 16 = T-junction T_S (connects S+E+W; ground on the closed north edge)
        .byte $13,$15,$15,$11,$11,$10,$17,$14
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        ; char 17 = T-junction T_E (connects N+S+E; dark border 1px in from west)
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        .byte $20,$22,$20,$20,$20,$20,$20,$20
        ; char 18 = T-junction T_W (connects N+S+W; ground on the closed east edge)
        .byte $20,$20,$20,$20,$20,$20,$20,$13
        .byte $20,$20,$20,$20,$20,$20,$20,$11
        .byte $20,$20,$20,$20,$20,$20,$20,$16
        .byte $20,$20,$20,$20,$20,$20,$20,$12
        .byte $20,$20,$20,$20,$20,$20,$20,$15
        .byte $20,$20,$20,$20,$20,$20,$20,$10
        .byte $20,$20,$20,$20,$20,$20,$20,$14
        .byte $20,$20,$20,$20,$20,$20,$20,$17

; char 19 = ROAD_CELL_H_POWER: horizontal road (char 8) with two vertical power
; wires ($22, cols 2 and 5) crossing over it -- aligns with POWERLINE_CELL_V.
        .byte $1F,$1F,$22,$1F,$1F,$22,$1F,$1F
        .byte $20,$20,$22,$20,$20,$22,$20,$20
        .byte $20,$20,$22,$20,$20,$22,$20,$20
        .byte $20,$20,$22,$21,$21,$22,$20,$20
        .byte $20,$20,$22,$20,$20,$22,$20,$20
        .byte $20,$20,$22,$20,$20,$22,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$23,$22,$23,$23,$22,$23,$23
; char 20 = ROAD_CELL_V_POWER: vertical road (char 9) with two horizontal power
; wires ($22, rows 2 and 5) crossing over it -- aligns with POWERLINE_CELL_H.
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
; char 21 = ROAD_CELL_BRIDGE_H: horizontal road bridge over water.
        ; fcm_bridge_road_h
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; row 0: water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; row 1: dark railing
        .byte $20,$20,$20,$20,$20,$20,$20,$20    ; rows 2..5: asphalt
        .byte $20,$20,$21,$21,$21,$21,$20,$20    ; row 3: lane marking
        .byte $20,$20,$21,$21,$21,$21,$20,$20    ; row 4: lane marking
        .byte $20,$20,$20,$20,$20,$20,$20,$20    ; row 5: asphalt
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; row 6: dark railing
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; row 7: water
; char 22 = ROAD_CELL_BRIDGE_V: vertical road bridge over water.
        ; fcm_bridge_road_v
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$21,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18
        .byte $18,$22,$20,$20,$20,$20,$22,$18
; char 23 = popup OK TL slot, stamped later by assets.asm.
        .fill 64, $00

; Power-line block (chars 24-26); char 27 is no longer in the map encoding and
; is reserved for the popup OK TR slot, stamped later by assets.asm.
; char 24 = POWERLINE_CELL_H
        ; fcm_powerline_h
        ; Horizontal wires (rows 2 + 5) with a vertical hatch at col 1.
        .byte $13,$13,$13,$13,$13,$13,$13,$13   ; row 0: brown
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 1: hatch
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 2: wire 1
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 3: hatch
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 4: hatch
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 5: wire 2
        .byte $13,$22,$13,$13,$13,$13,$13,$13   ; row 6: hatch
        .byte $13,$13,$13,$13,$13,$13,$13,$13   ; row 7: brown
; char 25 = POWERLINE_CELL_V
        ; fcm_powerline_v
        ; Vertical wires (cols 2 + 5) with a horizontal hatch at row 1.
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 0: wires
        .byte $13,$22,$22,$22,$22,$22,$22,$13   ; row 1: hatch (spans both wires + 1 px)
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 2: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 3: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 4: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 5: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 6: wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 7: wires
; char 26 = POWERLINE_CELL_POLE_H / intersection cross
        ; fcm_powerline_cross
        ; + intersection: both H and V wires; no hatch (the cross IS the cue).
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 0: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 1: V wires
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 2: H wire 1
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 3: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 4: V wires
        .byte $22,$22,$22,$22,$22,$22,$22,$22   ; row 5: H wire 2
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 6: V wires
        .byte $13,$13,$22,$13,$13,$22,$13,$13   ; row 7: V wires
; char 27 = popup OK TR slot, stamped later by assets.asm.
        .fill 64, $00

tileset_base_end:
        .cerror tileset_base_end - tileset_start != TILESET_BODY_SIZE, "tileset base must match TILESET_BODY_SIZE"

        .fill (ZONE_GEN_BASE * 64) - (tileset_base_end - tileset_start), $00

;=======================================================================================
; 3x3 zone cells (chars ZONE_GEN_BASE..+26), DMA'd into char RAM after the base
; tiles. Each zone is 9 distinct 8x8 cells (TL,T,TR,L,C,R,BL,B,BR): solid zone
; colour, grey ($0C) only on the OUTWARD-facing edges so a placed zone shows a
; single grey border around the whole 24x24 block, with the white (R/C/I) letter
; in the center cell. The map stores ZONE_CELL_FIRST + type*9 + position per
; zone cell; cell_to_char translates each value to the matching char id (see
; render.asm and the zone paint in city.asm).
;=======================================================================================
tileset_zones:
        .cerror tileset_zones - tileset_start != ZONE_GEN_BASE * 64, "zone cells must start at ZONE_GEN_BASE"
        ; residential zone cells (chars 32-40)
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; res TL
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; res T
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; res TR
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $0C,$07,$07,$07,$07,$07,$07,$07   ; res L
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07   ; res C
        .byte $07,$07,$0F,$0F,$0F,$07,$07,$07
        .byte $07,$07,$0F,$07,$0F,$07,$07,$07
        .byte $07,$07,$0F,$0F,$0F,$07,$07,$07
        .byte $07,$07,$0F,$0F,$07,$07,$07,$07
        .byte $07,$07,$0F,$07,$0F,$07,$07,$07
        .byte $07,$07,$0F,$07,$0F,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$0C   ; res R
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $0C,$07,$07,$07,$07,$07,$07,$07   ; res BL
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$07   ; res B
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $07,$07,$07,$07,$07,$07,$07,$07
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C   ; res BR
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $07,$07,$07,$07,$07,$07,$07,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        ; commercial zone cells (chars 41-49)
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; com TL
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; com T
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; com TR
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $0C,$08,$08,$08,$08,$08,$08,$08   ; com L
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08   ; com C
        .byte $08,$08,$0F,$0F,$0F,$08,$08,$08
        .byte $08,$08,$0F,$08,$08,$08,$08,$08
        .byte $08,$08,$0F,$08,$08,$08,$08,$08
        .byte $08,$08,$0F,$08,$08,$08,$08,$08
        .byte $08,$08,$0F,$08,$08,$08,$08,$08
        .byte $08,$08,$0F,$0F,$0F,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$0C   ; com R
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $0C,$08,$08,$08,$08,$08,$08,$08   ; com BL
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$08   ; com B
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C   ; com BR
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $08,$08,$08,$08,$08,$08,$08,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        ; industrial zone cells (chars 50-58)
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; ind TL
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; ind T
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; ind TR
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $0C,$09,$09,$09,$09,$09,$09,$09   ; ind L
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09   ; ind C
        .byte $09,$09,$0F,$0F,$0F,$09,$09,$09
        .byte $09,$09,$09,$0F,$09,$09,$09,$09
        .byte $09,$09,$09,$0F,$09,$09,$09,$09
        .byte $09,$09,$09,$0F,$09,$09,$09,$09
        .byte $09,$09,$09,$0F,$09,$09,$09,$09
        .byte $09,$09,$0F,$0F,$0F,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$0C   ; ind R
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $0C,$09,$09,$09,$09,$09,$09,$09   ; ind BL
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$09   ; ind B
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C   ; ind BR
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $09,$09,$09,$09,$09,$09,$09,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
tileset_zones_end:
        .cerror tileset_zones_end - tileset_zones != TILESET_ZONE_SIZE, "zone cells must match TILESET_ZONE_SIZE"

        .fill (COALPP_CHAR_BASE * 64) - (tileset_zones_end - tileset_start), $00

;=======================================================================================
; Coal power plant: a 3-wide x 4-tall (24x32 px) structure, 12 cells in row-major
; order (position = dy*3 + dx). DMA'd into char RAM at COALPP_CHAR_BASE; the map
; stores COALPP_CELL_FIRST + position per cell. Reference-inspired angled view:
; light roof slab $0C, dark right/foot sides $0B, mid front face $05, black stack
; row and coal pile $00, white/blue left wall strip $0F/$08, red stack accent
; $0D, yellow electric bolt $0A, and grass surround $02.
;=======================================================================================
tileset_coalpp:
        .cerror tileset_coalpp - tileset_start != COALPP_CHAR_BASE * 64, "coal plant chars must start at COALPP_CHAR_BASE"
        ; pos 0  (row 0, col 0)
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0B,$0B,$0B
        .byte $02,$02,$02,$02,$0C,$0C,$0C,$0C
        .byte $02,$02,$02,$02,$0C,$0C,$0C,$0C
        .byte $02,$02,$02,$02,$0C,$0C,$0C,$0C
        .byte $02,$02,$02,$02,$0C,$0C,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$0C,$0C,$0C
        ; pos 1  (row 0, col 1)
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$0F
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$00,$00,$0F
        .byte $0C,$0C,$0C,$0C,$0C,$00,$00,$0C
        .byte $0C,$0C,$0C,$0C,$00,$00,$0F,$0C
        .byte $0C,$0C,$0C,$0C,$00,$00,$0D,$0C
        ; pos 2  (row 0, col 2)
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $0B,$0B,$02,$02,$02,$02,$02,$02
        .byte $0C,$0C,$0B,$02,$02,$02,$02,$02
        .byte $0C,$0C,$02,$0B,$02,$02,$02,$02
        .byte $0C,$0C,$0B,$02,$0B,$02,$02,$02
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$02,$02
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$02,$02
        ; pos 3  (row 1, col 0)
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$0C
        ; pos 4  (row 1, col 1)
        .byte $00,$00,$0F,$0C,$0C,$00,$00,$0C
        .byte $0C,$0C,$0C,$00,$00,$0C,$0C,$0C
        .byte $0C,$0C,$00,$00,$0F,$0C,$0C,$0C
        .byte $0C,$0C,$00,$00,$0D,$0C,$0C,$0C
        .byte $0C,$00,$00,$0F,$0C,$0C,$0C,$0C
        .byte $0C,$00,$00,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$0F,$0C,$0C,$0C,$0C,$0C
        .byte $00,$00,$0D,$0C,$0C,$0C,$0C,$0C
        ; pos 5  (row 1, col 2)
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02
        .byte $0C,$0B,$0B,$0A,$0A,$0B,$02,$02
        .byte $0C,$0B,$0B,$0A,$0A,$0B,$02,$02
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$02,$02
        .byte $0C,$0B,$0B,$0B,$0B,$08,$08,$02
        .byte $0C,$0B,$0B,$0B,$0B,$08,$08,$02
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$02,$02
        ; pos 6  (row 2, col 0)
        .byte $02,$02,$0F,$0F,$0F,$08,$0C,$00
        .byte $02,$02,$0F,$0F,$0F,$08,$05,$00
        .byte $02,$02,$0F,$0F,$0F,$08,$05,$00
        .byte $02,$02,$0F,$0F,$0F,$08,$05,$05
        .byte $02,$02,$0F,$0F,$0F,$08,$05,$05
        .byte $02,$02,$0F,$0F,$0F,$08,$05,$05
        .byte $02,$02,$0F,$0F,$0F,$08,$00,$00
        .byte $02,$02,$0F,$0F,$0F,$08,$00,$00
        ; pos 7  (row 2, col 1)
        .byte $00,$0F,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $00,$05,$05,$05,$05,$05,$05,$05
        .byte $00,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $00,$00,$00,$00,$00,$05,$05,$05
        .byte $00,$00,$00,$00,$00,$05,$05,$05
        ; pos 8  (row 2, col 2)
        .byte $0C,$0B,$0B,$0E,$0E,$0B,$02,$02
        .byte $05,$0B,$0B,$0E,$0E,$0B,$02,$02
        .byte $05,$0B,$0B,$0B,$0B,$0D,$0D,$02
        .byte $05,$0B,$0B,$0B,$0B,$0D,$0D,$02
        .byte $05,$0B,$0B,$0A,$0B,$0B,$02,$02
        .byte $05,$0B,$0A,$0B,$0B,$0B,$02,$02
        .byte $05,$0A,$0B,$0B,$0B,$0B,$02,$02
        .byte $0A,$0A,$0B,$0B,$0B,$0B,$02,$02
        ; pos 9  (row 3, col 0)
        .byte $02,$02,$0F,$0F,$0F,$08,$00,$00
        .byte $02,$02,$0F,$0F,$0F,$08,$00,$00
        .byte $02,$02,$02,$02,$02,$00,$00,$00
        .byte $02,$02,$02,$02,$00,$00,$00,$00
        .byte $02,$02,$02,$02,$00,$00,$00,$00
        .byte $02,$02,$02,$02,$02,$02,$02,$0B
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; pos 10 (row 3, col 1)
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$0A
        .byte $00,$00,$00,$00,$00,$00,$0A,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00
        .byte $0B,$0B,$0F,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; pos 11 (row 3, col 2)
        .byte $0A,$0B,$0B,$0B,$0B,$0B,$02,$02
        .byte $00,$00,$0B,$0B,$0B,$02,$02,$02
        .byte $00,$00,$0B,$0B,$0B,$02,$02,$02
        .byte $00,$00,$0B,$0B,$0B,$02,$02,$02
        .byte $00,$00,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
tileset_coalpp_end:
        .cerror tileset_coalpp_end - tileset_coalpp != TILESET_COALPP_SIZE, "coal plant cells must match TILESET_COALPP_SIZE"

;=======================================================================================
; Nuclear power plant: same 3x4 footprint as coal, 12 cells in row-major order.
; Two cylindrical cooling towers (dark concrete bands), steam puffs above, a
; containment dome with a cyan "reactor glow" core, and cyan window strips along
; the building base. First-draft art -- refine to taste.
;=======================================================================================
tileset_nuclearpp:
        .cerror tileset_nuclearpp - tileset_start != NUCLEARPP_CHAR_BASE * 64, "nuclear plant chars must start at NUCLEARPP_CHAR_BASE"
        ; pos 0  (row 0, col 0)
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0B,$05,$05,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$05,$05,$05,$0C,$0C,$0C,$05
        .byte $0B,$05,$05,$05,$05,$0C,$05,$05
        .byte $0B,$05,$05,$0C,$05,$05,$05,$0C
        .byte $0B,$05,$05,$05,$0E,$0E,$0E,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$0B,$0B,$0B,$05
        ; pos 1  (row 0, col 1)
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $05,$02,$05,$05,$05,$02,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        ; pos 2  (row 0, col 2)
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$05,$05,$0B
        .byte $05,$0C,$0C,$0C,$05,$05,$05,$0B
        .byte $05,$05,$0C,$05,$05,$05,$05,$0B
        .byte $0C,$05,$05,$05,$0C,$05,$05,$0B
        .byte $05,$0E,$0E,$0E,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0B,$0B,$0B,$05,$05,$05,$0B
        ; pos 3  (row 1, col 0)
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$0B,$0B,$0B,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$0B,$0B,$0B,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$0B,$0B,$0B,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$0B,$0B,$0B,$05
        ; pos 4  (row 1, col 1)
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        ; pos 5  (row 1, col 2)
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0B,$0B,$0B,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0B,$0B,$0B,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0B,$0B,$0B,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0B,$0B,$0B,$05,$05,$05,$0B
        ; pos 6  (row 2, col 0)
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$0B,$0B,$0B,$0B,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        ; pos 7  (row 2, col 1)
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$0B,$0B,$0B,$0B,$05,$05
        .byte $05,$0B,$05,$05,$05,$05,$0B,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$05,$0E,$0E,$0E,$0E,$05,$05
        .byte $05,$0E,$0E,$0E,$0E,$0E,$0E,$05
        .byte $05,$05,$0E,$0E,$0E,$0E,$05,$05
        ; pos 8  (row 2, col 2)
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$0B,$0B,$0B,$0B,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        ; pos 9  (row 3, col 0)
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$05,$0E,$0E,$05,$0E,$0E,$05
        .byte $0B,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$0B,$05,$05,$05,$05,$05,$05
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        ; pos 10 (row 3, col 1)
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $0E,$0E,$05,$0E,$0E,$05,$0E,$0E
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        ; pos 11 (row 3, col 2)
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $0B,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$0E,$0E,$05,$0E,$0E,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$05,$0B
        .byte $05,$05,$05,$05,$05,$05,$0B,$0B
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B
tileset_nuclearpp_end:
        .cerror tileset_nuclearpp_end - tileset_nuclearpp != TILESET_NUCLEARPP_SIZE, "nuclear plant cells must match TILESET_NUCLEARPP_SIZE"

        .fill (TREE_CHAR_BASE * 64) - (tileset_nuclearpp_end - tileset_start), $00

;=======================================================================================
; Tree autotiles: 16 chars at TREE_CHAR_BASE, one per 4-neighbor mask.
;=======================================================================================
TREE_TILE .macro n, s, e, w
        ; --- Row 0: NW corner (2) + top-edge stripe (4) + NE corner (2) ---
.if (\n)|(\w)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.if \n
        .byte $02, $02, $02, $02
.else
        .byte $03, $03, $03, $03        ; top-edge silhouette
.fi
.if (\n)|(\e)
        .byte $02, $02
.else
        .byte $04, $04
.fi
        ; --- Row 1: NW edge (1) + inner-NW (1) + interior (4) + inner-NE (1) + NE edge (1) ---
.if (\n)|(\w)
        .byte $02
.else
        .byte $04
.fi
.if (\n)|(\w)
        .byte $02                       ; inner-NW: filled -> blend
.else
        .byte $03                       ; inner-NW: rounded -> silhouette curve
.fi
        .byte $07, $02, $02, $07
.if (\n)|(\e)
        .byte $03                       ; inner-NE: rounded -> silhouette
.else
        .byte $03
.fi
.if (\n)|(\e)
        .byte $02
.else
        .byte $04
.fi
        ; --- Rows 2..5: W edge (1) + interior 6x4 scatter (6) + E edge (1) ---
.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $03, $02, $07, $02, $02, $03
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $02, $07, $02, $03, $07, $02
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $07, $02, $03, $02, $02, $07
.if \e
        .byte $02
.else
        .byte $03
.fi

.if \w
        .byte $02
.else
        .byte $03
.fi
        .byte $02, $03, $02, $07, $02, $03
.if \e
        .byte $02
.else
        .byte $03
.fi

        ; --- Row 6: SW edge (1) + inner-SW (1) + interior (4) + inner-SE (1) + SE edge (1) ---
.if (\s)|(\w)
        .byte $02
.else
        .byte $04
.fi
.if (\s)|(\w)
        .byte $02
.else
        .byte $03
.fi
        .byte $07, $02, $02, $07
.if (\s)|(\e)
        .byte $02
.else
        .byte $03
.fi
.if (\s)|(\e)
        .byte $02
.else
        .byte $04
.fi

        ; --- Row 7: SW corner (2) + bottom-edge stripe (4) + SE corner (2) ---
.if (\s)|(\w)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.if \s
        .byte $02, $02, $02, $02
.else
        .byte $03, $03, $03, $03        ; bottom-edge silhouette
.fi
.if (\s)|(\e)
        .byte $02, $02
.else
        .byte $04, $04
.fi
.endmacro

; The 16 tiles, indexed by mask. mask bit 0 = N, 1 = S, 2 = E, 3 = W.
;
;     mask  N S E W
;     0     0 0 0 0   isolated single bush
;     1     1 0 0 0   N only -> south end of vertical run
;     2     0 1 0 0   S only -> north end
;     3     1 1 0 0   NS -> vertical middle (solid interior)
;     4     0 0 1 0   E only -> west end of horizontal run
;     5     1 0 1 0   NE -> SW corner rounded (forest opens SW)
;     6     0 1 1 0   SE -> NW corner rounded
;     7     1 1 1 0   NSE -> W edge of solid forest
;     8     0 0 0 1   W only -> east end
;     9     1 0 0 1   NW -> SE corner rounded
;     10    0 1 0 1   SW -> NE corner rounded
;     11    1 1 0 1   NSW -> E edge of solid forest
;     12    0 0 1 1   EW horizontal middle (solid)
;     13    1 0 1 1   NEW -> S edge of solid forest
;     14    0 1 1 1   SEW -> N edge of solid forest
;     15    1 1 1 1   surrounded (fully solid interior)
;
fcm_tree_tiles:
        #TREE_TILE 0, 0, 0, 0       ; mask  0
        #TREE_TILE 1, 0, 0, 0       ; mask  1
        #TREE_TILE 0, 1, 0, 0       ; mask  2
        #TREE_TILE 1, 1, 0, 0       ; mask  3
        #TREE_TILE 0, 0, 1, 0       ; mask  4
        #TREE_TILE 1, 0, 1, 0       ; mask  5
        #TREE_TILE 0, 1, 1, 0       ; mask  6
        #TREE_TILE 1, 1, 1, 0       ; mask  7
        #TREE_TILE 0, 0, 0, 1       ; mask  8
        #TREE_TILE 1, 0, 0, 1       ; mask  9
        #TREE_TILE 0, 1, 0, 1       ; mask 10
        #TREE_TILE 1, 1, 0, 1       ; mask 11
        #TREE_TILE 0, 0, 1, 1       ; mask 12
        #TREE_TILE 1, 0, 1, 1       ; mask 13
        #TREE_TILE 0, 1, 1, 1       ; mask 14
        #TREE_TILE 1, 1, 1, 1       ; mask 15
tileset_trees_end:
        .cerror tileset_trees_end - fcm_tree_tiles != TREE_CELL_COUNT * 64, "tree chars must match TREE_CELL_COUNT"

        .fill (WATER_SHORE_CHAR_BASE * 64) - (tileset_trees_end - tileset_start), $00

;=======================================================================================
; Water shoreline autotiles: 15 chars at WATER_SHORE_CHAR_BASE, masks 0..14.
;=======================================================================================
WATER_SHORE_TILE .macro n, s, e, w
        ; --- Row 0: NW corner (2) + top edge (4) + NE corner (2) ---
.if (\n)|(\w)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.if \n
        .byte $18, $18, $18, $18
.else
        .byte $19, $19, $19, $19        ; depth line along the shore
.fi
.if (\n)|(\e)
        .byte $18, $18
.else
        .byte $04, $04
.fi
        ; --- Row 1: NW edge (1) + inner-NW (1) + interior (4) + inner-NE (1) + NE edge (1) ---
.if (\n)|(\w)
        .byte $18
.else
        .byte $04
.fi
.if (\n)|(\w)
        .byte $18
.else
        .byte $19                        ; inner-corner depth pixel
.fi
        .byte $18, $1A, $1A, $18
.if (\n)|(\e)
        .byte $18
.else
        .byte $19
.fi
.if (\n)|(\e)
        .byte $18
.else
        .byte $04
.fi
        ; --- Rows 2..5: W edge (1) + interior 6 + E edge (1) ---
.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $1B, $1B, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $18, $18, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $1A, $1A, $1A, $18, $18, $18
.if \e
        .byte $18
.else
        .byte $19
.fi

.if \w
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $18, $18, $18, $19, $19
.if \e
        .byte $18
.else
        .byte $19
.fi

        ; --- Row 6: SW edge (1) + inner-SW (1) + interior (4) + inner-SE (1) + SE edge (1) ---
.if (\s)|(\w)
        .byte $18
.else
        .byte $04
.fi
.if (\s)|(\w)
        .byte $18
.else
        .byte $19
.fi
        .byte $18, $1A, $1A, $18
.if (\s)|(\e)
        .byte $18
.else
        .byte $19
.fi
.if (\s)|(\e)
        .byte $18
.else
        .byte $04
.fi
        ; --- Row 7: SW corner (2) + bottom edge (4) + SE corner (2) ---
.if (\s)|(\w)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.if \s
        .byte $18, $18, $18, $18
.else
        .byte $19, $19, $19, $19
.fi
.if (\s)|(\e)
        .byte $18, $18
.else
        .byte $04, $04
.fi
.endmacro

; 15 shoreline tiles, masks 0..14 (mask 15 = interior, served by chars 0..3).
fcm_water_shore_tiles:
        #WATER_SHORE_TILE 0, 0, 0, 0       ; mask  0  isolated
        #WATER_SHORE_TILE 1, 0, 0, 0       ; mask  1  N
        #WATER_SHORE_TILE 0, 1, 0, 0       ; mask  2  S
        #WATER_SHORE_TILE 1, 1, 0, 0       ; mask  3  NS
        #WATER_SHORE_TILE 0, 0, 1, 0       ; mask  4  E
        #WATER_SHORE_TILE 1, 0, 1, 0       ; mask  5  NE
        #WATER_SHORE_TILE 0, 1, 1, 0       ; mask  6  SE
        #WATER_SHORE_TILE 1, 1, 1, 0       ; mask  7  NSE
        #WATER_SHORE_TILE 0, 0, 0, 1       ; mask  8  W
        #WATER_SHORE_TILE 1, 0, 0, 1       ; mask  9  NW
        #WATER_SHORE_TILE 0, 1, 0, 1       ; mask 10  SW
        #WATER_SHORE_TILE 1, 1, 0, 1       ; mask 11  NSW
        #WATER_SHORE_TILE 0, 0, 1, 1       ; mask 12  EW
        #WATER_SHORE_TILE 1, 0, 1, 1       ; mask 13  NEW
        #WATER_SHORE_TILE 0, 1, 1, 1       ; mask 14  SEW
tileset_water_shore_end:
        .cerror tileset_water_shore_end - fcm_water_shore_tiles != WATER_SHORE_CELL_COUNT * 64, "water-shore chars must match WATER_SHORE_CELL_COUNT"

        .fill (POWER_BRIDGE_CHAR_BASE * 64) - (tileset_water_shore_end - tileset_start), $00

;=======================================================================================
; Power bridges: 2 chars at POWER_BRIDGE_CHAR_BASE.
;=======================================================================================
tileset_power_bridges:
        ; fcm_bridge_power_h
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $18,$18,$18,$1A,$1A,$18,$18,$18    ; water + ripple
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; horizontal wire
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; horizontal wire
        .byte $18,$1A,$1A,$18,$18,$18,$18,$18    ; water + ripple
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        ; fcm_bridge_power_v
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$18,$22,$1A,$1A,$22,$18,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$1A,$22,$18,$18,$22,$1A,$18
        .byte $18,$1A,$22,$18,$18,$22,$1A,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18
        .byte $18,$18,$22,$1A,$1A,$22,$18,$18
        .byte $18,$18,$22,$18,$18,$22,$18,$18

; Stamp each bridge bitmap into its char slot. Road bridges go into the city-
; tileset slots 21/22 (the city DMA put placeholder content there; we
; overwrite it). Power bridges go into the dedicated POWER_BRIDGE_CHAR_BASE
; slots at the top of char RAM.
tileset_power_bridges_end:
        .cerror tileset_power_bridges_end - tileset_power_bridges != POWER_BRIDGE_CELL_COUNT * 64, "power bridge chars must match POWER_BRIDGE_CELL_COUNT"

        .fill (RAIL_CHAR_BASE * 64) - (tileset_power_bridges_end - tileset_start), $00

;=======================================================================================
; Rail tiles: 17 chars at RAIL_CHAR_BASE.
;=======================================================================================
tileset_rails:
        ; fcm_rail_h
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        ; fcm_rail_v
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        ; fcm_rail_4way
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Curves use a stair-step arc on the outer rail (e.g. NW outer col 5 -> row 5
; transitions via cols 4,5 at row 3 and cols 3,4 at row 4). The inner rail
; (col 2 -> row 2) still corners sharply -- 2px is too tight for an arc at
; this resolution.
        ; fcm_rail_curve_nw
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $21,$21,$21,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        ; fcm_rail_curve_ne
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$21,$21
        .byte $13,$13,$21,$21,$13,$13,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        ; fcm_rail_curve_sw
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $21,$21,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        ; fcm_rail_curve_se
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$21,$21,$21
        .byte $13,$13,$13,$13,$21,$21,$13,$13
        .byte $13,$13,$13,$21,$21,$13,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; T-junctions: 3 sides open, 1 closed. T_N connects N+E+W, closed S.
        ; fcm_rail_t_n
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        ; fcm_rail_t_s
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $13,$13,$13,$13,$13,$13,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        ; fcm_rail_t_e
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        ; fcm_rail_t_w
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Power crossings: rail + perpendicular power line. Rail $21 wins at the rail
; rows/cols; wire $22 fills the rest of the wire column/row.
        ; fcm_rail_h_power
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $24,$13,$22,$13,$24,$22,$24,$13
        .byte $24,$13,$22,$13,$24,$22,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        .byte $13,$13,$22,$13,$13,$22,$13,$13
        ; fcm_rail_v_power
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $22,$22,$21,$22,$22,$21,$22,$22
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $22,$22,$21,$22,$22,$21,$22,$22
        .byte $13,$13,$21,$24,$24,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13

; Bridges: rail over water. Dark railing flanking the brown deck, mirroring
; the road bridge idiom so shorelines visually flow under both.
        ; fcm_rail_bridge_h
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; dark railing
        .byte $21,$21,$21,$21,$21,$21,$21,$21    ; top rail
        .byte $24,$13,$24,$13,$24,$13,$24,$13    ; ties on the deck
        .byte $24,$13,$24,$13,$24,$13,$24,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21    ; bottom rail
        .byte $22,$22,$22,$22,$22,$22,$22,$22    ; dark railing
        .byte $18,$18,$18,$18,$18,$18,$18,$18    ; water
        ; fcm_rail_bridge_v
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18
        .byte $18,$22,$21,$24,$24,$21,$22,$18
        .byte $18,$22,$21,$13,$13,$21,$22,$18

; Road crossings: rail + perpendicular road. RAIL_H_ROAD = horizontal rail
; (rails at rows 2/5) with a vertical road band (asphalt $20 at cols 2..5);
; RAIL_V_ROAD is the mirror. Cell value lives in the rail range and city.asm
; creates these atomically when the player paints rail on a straight road
; (or road on a straight rail). The engine treats them as sticky.
        ; fcm_rail_h_road
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $21,$21,$21,$21,$21,$21,$21,$21
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        .byte $13,$13,$20,$20,$20,$20,$13,$13
        ; fcm_rail_v_road
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $20,$20,$21,$20,$20,$21,$20,$20
        .byte $13,$13,$21,$13,$13,$21,$13,$13
        .byte $13,$13,$21,$13,$13,$21,$13,$13
tileset_rails_end:
        .cerror tileset_rails_end - tileset_rails != RAIL_CELL_COUNT * 64, "rail chars must match RAIL_CELL_COUNT"

        .fill (DEBRIS_CHAR_BASE * 64) - (tileset_rails_end - tileset_start), $00

;=======================================================================================
; Debris tile: 1 char at DEBRIS_CHAR_BASE.
;=======================================================================================
tileset_debris:
        ; fcm_debris
        .byte $13,$13,$24,$24,$13,$13,$24,$13
        .byte $13,$24,$24,$13,$0B,$24,$24,$13
        .byte $24,$24,$0B,$24,$24,$24,$13,$24
        .byte $13,$0B,$24,$24,$13,$24,$24,$0B
        .byte $13,$13,$24,$0B,$24,$13,$0B,$24
        .byte $24,$24,$13,$13,$24,$24,$24,$13
        .byte $13,$13,$24,$24,$0B,$24,$13,$13
        .byte $24,$0B,$24,$13,$13,$24,$24,$13
tileset_debris_end:
        .cerror tileset_debris_end - tileset_debris != DEBRIS_CELL_COUNT * 64, "debris chars must match DEBRIS_CELL_COUNT"

        .fill (PARK_CHAR_BASE * 64) - (tileset_debris_end - tileset_start), $00

;=======================================================================================
; Park structure: 16 chars at PARK_CHAR_BASE in row-major structure order.
;=======================================================================================
tileset_park:
        ; fcm_park_tree
        .byte $02,$02,$02,$03,$03,$02,$02,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Grass with yellow ($06) dandelion-style flowers (variant A).
        ; fcm_park_grass_a
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Grass with white ($0F) flowers (variant B) -- different positions.
        ; fcm_park_grass_b
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$0F,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0F,$02,$02
        .byte $02,$0F,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$0F,$02,$02,$02

; Fountain TL quadrant: stone in the NW, water spreading out toward SE so the
; four quadrants mesh into a circular pool with stone rim.
        ; fcm_park_tree
        .byte $02,$02,$02,$03,$03,$02,$02,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Grass with yellow ($06) dandelion-style flowers (variant A).
        ; fcm_park_grass_b
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$0F,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0F,$02,$02
        .byte $02,$0F,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$0F,$02,$02,$02

; Fountain TL quadrant: stone in the NW, water spreading out toward SE so the
; four quadrants mesh into a circular pool with stone rim.
        ; fcm_park_fnt_tl
        .byte $02,$02,$0B,$0B,$0C,$0C,$0C,$0C
        .byte $02,$0B,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0C,$0C,$18,$18,$18
        .byte $0C,$0C,$0C,$0C,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18

; Fountain TR quadrant (mirror horizontally of TL).
        ; fcm_park_fnt_tr
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0B,$02
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B
        .byte $18,$18,$18,$0C,$0C,$0C,$0C,$0B
        .byte $18,$18,$18,$18,$0C,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$18,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C

; Fountain BL quadrant (mirror vertically of TL).
        ; fcm_park_grass_a
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Grass with white ($0F) flowers (variant B) -- different positions.
        ; fcm_park_grass_a
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Grass with white ($0F) flowers (variant B) -- different positions.
        ; fcm_park_fnt_bl
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$18,$18,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$18,$18,$18,$18,$18
        .byte $0C,$0C,$0C,$0C,$18,$18,$18,$18
        .byte $0B,$0C,$0C,$0C,$0C,$18,$18,$18
        .byte $0B,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $02,$0B,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $02,$02,$0B,$0B,$0C,$0C,$0C,$0C

; Fountain BR quadrant (mirror both axes).
        ; fcm_park_fnt_br
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$18,$0C,$0C
        .byte $18,$18,$18,$18,$18,$0C,$0C,$0C
        .byte $18,$18,$18,$18,$0C,$0C,$0C,$0C
        .byte $18,$18,$18,$0C,$0C,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0B,$02
        .byte $0C,$0C,$0C,$0C,$0B,$0B,$02,$02

; Load the 16 park chars. Each cell of the 4x4 footprint gets its own char id
; (PARK_CHAR_BASE+0 through +15) but the actual bitmap reuses one of 7 shared
; templates -- corners use the same tree, edges alternate between grass_a/b,
; centre uses the four fountain quadrants in NW/NE/SW/SE positions.
;
; 4x4 char layout (row-major, same order structure_stamp writes cells):
;     +0  +1  +2  +3       tree  gA   gB   tree
;     +4  +5  +6  +7       gB    fTL  fTR  gA
;     +8  +9 +10 +11       gA    fBL  fBR  gB
;    +12 +13 +14 +15       tree  gB   gA   tree
        ; fcm_park_grass_b
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$0F,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0F,$02,$02
        .byte $02,$0F,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$0F,$02,$02,$02

; Fountain TL quadrant: stone in the NW, water spreading out toward SE so the
; four quadrants mesh into a circular pool with stone rim.
        ; fcm_park_tree
        .byte $02,$02,$02,$03,$03,$02,$02,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Grass with yellow ($06) dandelion-style flowers (variant A).
        ; fcm_park_grass_b
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$0F,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$0F,$02,$02
        .byte $02,$0F,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$0F,$02,$02,$02

; Fountain TL quadrant: stone in the NW, water spreading out toward SE so the
; four quadrants mesh into a circular pool with stone rim.
        ; fcm_park_grass_a
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Grass with white ($0F) flowers (variant B) -- different positions.
        ; fcm_park_tree
        .byte $02,$02,$02,$03,$03,$02,$02,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$03,$07,$07,$07,$07,$03,$02
        .byte $02,$02,$03,$07,$07,$03,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Grass with yellow ($06) dandelion-style flowers (variant A).
tileset_park_end:
        .cerror tileset_park_end - tileset_park != PARK_CELL_COUNT * 64, "park chars must match PARK_CELL_COUNT"

        .fill (POLICE_CHAR_BASE * 64) - (tileset_park_end - tileset_start), $00

;=======================================================================================
; Police department structure: 9 chars at POLICE_CHAR_BASE.
;=======================================================================================
tileset_police:
        ; fcm_pol_tl
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $0F,$08,$08,$08,$08,$08,$08,$08   ; white left edge + blue body
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        ; fcm_pol_tc
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        ; fcm_pol_tr
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F

; Row 1: middle of building. ML has the white left edge; centre has PD letters;
; MR has the white right edge. Bottom row of each is the white south edge of
; the building (the building ends here -- row 2 is grass below).
        ; fcm_pol_ml
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white south edge

; Centre cell with "PD" in white on blue.
;   col:  0   1   2   3   4   5   6   7
; row 0:  .   .   .   .   .   .   .   .
; row 1:  .   P   P   P   .   D   D   .       PPP DD
; row 2:  .   P   .   P   .   D   .   D       P P D D
; row 3:  .   P   P   P   .   D   .   D       PPP D D
; row 4:  .   P   .   .   .   D   .   D       P   D D
; row 5:  .   P   .   .   .   D   D   .       P   DD
; row 6:  .   .   .   .   .   .   .   .
; row 7:  white south edge
        ; fcm_pol_c
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $08,$0F,$0F,$0F,$08,$0F,$0F,$08
        .byte $08,$0F,$08,$0F,$08,$0F,$08,$0F
        .byte $08,$0F,$0F,$0F,$08,$0F,$08,$0F
        .byte $08,$0F,$08,$08,$08,$0F,$08,$0F
        .byte $08,$0F,$08,$08,$08,$0F,$0F,$08
        .byte $08,$08,$08,$08,$08,$08,$08,$08
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        ; fcm_pol_mr
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $08,$08,$08,$08,$08,$08,$08,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; Row 2: grass ($02) with yellow ($06) flower dots; centre cell has a dark
; ($0B) driveway approaching the building from the south.
        ; fcm_pol_bl
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_pol_bc
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$06,$0B,$0B,$0B,$0B,$06,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        ; fcm_pol_br
        .byte $02,$02,$02,$06,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$06,$02,$02,$02,$02

; 3x3 char layout (row-major, same order structure_stamp writes cells):
;     +0  +1  +2       tl   tc   tr            (building roof)
;     +3  +4  +5       ml   c    mr            (building middle + "PD")
;     +6  +7  +8       bl   bc   br            (grounds: grass + driveway)
tileset_police_end:
        .cerror tileset_police_end - tileset_police != POLICE_CELL_COUNT * 64, "police chars must match POLICE_CELL_COUNT"

        .fill (RES_HOUSE_CHAR_BASE * 64) - (tileset_police_end - tileset_start), $00

;=======================================================================================
; Residential houses: 9 chars at RES_HOUSE_CHAR_BASE.
;=======================================================================================
tileset_residential_houses:
        ; fcm_res_house
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$0D,$0D,$0D,$0D,$02,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$0F,$00,$00,$00,$00,$0F,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Center cell: small dark-green ($03) tree with a brown ($04) trunk on a
; grass ($02) field. Different from corner trees so the center reads as a
; deliberate yard / common, not just more landscape.
        ; fcm_res_grass
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_res_house
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$0D,$0D,$0D,$0D,$02,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$0F,$00,$00,$00,$00,$0F,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Center cell: small dark-green ($03) tree with a brown ($04) trunk on a
; grass ($02) field. Different from corner trees so the center reads as a
; deliberate yard / common, not just more landscape.
        ; fcm_res_grass
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_res_yard
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$03,$03,$03,$02,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$03,$03,$03,$03,$03,$02,$02
        .byte $02,$02,$03,$03,$03,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02
        .byte $02,$02,$02,$04,$04,$02,$02,$02

; Edge cell: plain grass with a couple of yellow ($06) flower dots. Reused
; across all 4 edge positions; the pattern reads as "grass" without obvious
; tiling seams against either the corner house or the centre yard.
        ; fcm_res_grass
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_res_house
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$0D,$0D,$0D,$0D,$02,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$0F,$00,$00,$00,$00,$0F,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Center cell: small dark-green ($03) tree with a brown ($04) trunk on a
; grass ($02) field. Different from corner trees so the center reads as a
; deliberate yard / common, not just more landscape.
        ; fcm_res_grass
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_res_house
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$0D,$0D,$0D,$0D,$02,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0D,$0D,$0D,$0D,$0D,$0D,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$0F,$00,$00,$00,$00,$0F,$02
        .byte $02,$0F,$0F,$0F,$0F,$0F,$0F,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02

; Center cell: small dark-green ($03) tree with a brown ($04) trunk on a
; grass ($02) field. Different from corner trees so the center reads as a
; deliberate yard / common, not just more landscape.
tileset_residential_houses_end:
        .cerror tileset_residential_houses_end - tileset_residential_houses != RES_HOUSE_CELL_COUNT * 64, "residential-house chars must match RES_HOUSE_CELL_COUNT"

        .fill (APT_CHAR_BASE * 64) - (tileset_residential_houses_end - tileset_start), $00

;=======================================================================================
; Residential apartments: 9 chars at APT_CHAR_BASE.
;=======================================================================================
tileset_apartments:
        ; fcm_apt_building
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02   ; row 0: roof top
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 1: roof
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 2: top of wall
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 3: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 4: between floors
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 5: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 6: bottom of wall
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 7: foundation

; Pavement: solid road-gray, no markings (street/lot fill between buildings).
        ; fcm_apt_pavement
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

; Courtyard: pavement border around a small grass patch with dark-green
; shrubs forming a hollow square. Sits between the 4 corner apartments.
        ; fcm_apt_building
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02   ; row 0: roof top
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 1: roof
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 2: top of wall
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 3: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 4: between floors
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 5: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 6: bottom of wall
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 7: foundation

; Pavement: solid road-gray, no markings (street/lot fill between buildings).
        ; fcm_apt_pavement
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

; Courtyard: pavement border around a small grass patch with dark-green
; shrubs forming a hollow square. Sits between the 4 corner apartments.
        ; fcm_apt_court
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$02,$02,$02,$02,$02,$02,$05
        .byte $05,$02,$03,$03,$03,$03,$02,$05
        .byte $05,$02,$03,$02,$02,$03,$02,$05
        .byte $05,$02,$03,$02,$02,$03,$02,$05
        .byte $05,$02,$03,$03,$03,$03,$02,$05
        .byte $05,$02,$02,$02,$02,$02,$02,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        ; fcm_apt_pavement
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

; Courtyard: pavement border around a small grass patch with dark-green
; shrubs forming a hollow square. Sits between the 4 corner apartments.
        ; fcm_apt_building
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02   ; row 0: roof top
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 1: roof
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 2: top of wall
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 3: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 4: between floors
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 5: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 6: bottom of wall
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 7: foundation

; Pavement: solid road-gray, no markings (street/lot fill between buildings).
        ; fcm_apt_pavement
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05
        .byte $05,$05,$05,$05,$05,$05,$05,$05

; Courtyard: pavement border around a small grass patch with dark-green
; shrubs forming a hollow square. Sits between the 4 corner apartments.
        ; fcm_apt_building
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02   ; row 0: roof top
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 1: roof
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 2: top of wall
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 3: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 4: between floors
        .byte $02,$0C,$00,$0C,$0C,$00,$0C,$02   ; row 5: windows
        .byte $02,$0C,$0C,$0C,$0C,$0C,$0C,$02   ; row 6: bottom of wall
        .byte $02,$0B,$0B,$0B,$0B,$0B,$0B,$02   ; row 7: foundation

; Pavement: solid road-gray, no markings (street/lot fill between buildings).
tileset_apartments_end:
        .cerror tileset_apartments_end - tileset_apartments != APT_CELL_COUNT * 64, "apartment chars must match APT_CELL_COUNT"

        .fill (IND_HEAVY_CHAR_BASE * 64) - (tileset_apartments_end - tileset_start), $00

;=======================================================================================
; Industrial heavy: 9 chars at IND_HEAVY_CHAR_BASE.
;=======================================================================================
tileset_industrial_heavy:
        ; fcm_ind_factory
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 0: smokestack top
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 1: smokestack
        .byte $09,$09,$0B,$0B,$0B,$0B,$0B,$09   ; row 2: roof + stack base
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 3: roof
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 4: top of walls
        .byte $09,$0C,$00,$0C,$00,$0C,$0C,$09   ; row 5: windows
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 6: walls
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 7: foundation
        ; fcm_ind_pavement
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        ; fcm_ind_factory
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 0: smokestack top
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 1: smokestack
        .byte $09,$09,$0B,$0B,$0B,$0B,$0B,$09   ; row 2: roof + stack base
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 3: roof
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 4: top of walls
        .byte $09,$0C,$00,$0C,$00,$0C,$0C,$09   ; row 5: windows
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 6: walls
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 7: foundation
        ; fcm_ind_pavement
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        ; fcm_ind_silo
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$0B,$0B,$0B,$09,$09   ; silo top
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09   ; silo wall (LG=$0C)
        .byte $09,$0B,$0C,$0F,$0F,$0C,$0B,$09   ; silo + white reflection
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09
        .byte $09,$0B,$0C,$0C,$0C,$0C,$0B,$09
        .byte $09,$09,$0B,$0B,$0B,$0B,$09,$09   ; silo bottom
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        ; fcm_ind_pavement
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        ; fcm_ind_factory
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 0: smokestack top
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 1: smokestack
        .byte $09,$09,$0B,$0B,$0B,$0B,$0B,$09   ; row 2: roof + stack base
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 3: roof
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 4: top of walls
        .byte $09,$0C,$00,$0C,$00,$0C,$0C,$09   ; row 5: windows
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 6: walls
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 7: foundation
        ; fcm_ind_pavement
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $09,$09,$0B,$09,$09,$0B,$09,$09   ; small dark markers
        .byte $09,$09,$09,$09,$09,$09,$09,$09
        .byte $0B,$0B,$0B,$0B,$0B,$0B,$0B,$0B   ; loading-dock stripe
        ; fcm_ind_factory
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 0: smokestack top
        .byte $09,$09,$09,$09,$09,$0B,$0B,$09   ; row 1: smokestack
        .byte $09,$09,$0B,$0B,$0B,$0B,$0B,$09   ; row 2: roof + stack base
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 3: roof
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 4: top of walls
        .byte $09,$0C,$00,$0C,$00,$0C,$0C,$09   ; row 5: windows
        .byte $09,$0C,$0C,$0C,$0C,$0C,$0C,$09   ; row 6: walls
        .byte $09,$0B,$0B,$0B,$0B,$0B,$0B,$09   ; row 7: foundation
tileset_industrial_heavy_end:
        .cerror tileset_industrial_heavy_end - tileset_industrial_heavy != IND_HEAVY_CELL_COUNT * 64, "industrial-heavy chars must match IND_HEAVY_CELL_COUNT"

        .fill (COM_HEAVY_CHAR_BASE * 64) - (tileset_industrial_heavy_end - tileset_start), $00

;=======================================================================================
; Commercial heavy: 9 chars at COM_HEAVY_CHAR_BASE.
;=======================================================================================
tileset_commercial_heavy:
        ; fcm_com_shop
        .byte $0C,$08,$08,$08,$08,$08,$08,$0C   ; row 0: blue awning
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 1: signboard
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 2: windows
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 3: windows
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 4: between
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 5: big shop window
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 6: big shop window
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; row 7: sidewalk

; Sidewalk: light-grey with a darker grey tile pattern.
        ; fcm_com_sidewalk
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C

; Plaza: sidewalk frame around a small blue fountain in the centre.
        ; fcm_com_shop
        .byte $0C,$08,$08,$08,$08,$08,$08,$0C   ; row 0: blue awning
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 1: signboard
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 2: windows
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 3: windows
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 4: between
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 5: big shop window
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 6: big shop window
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; row 7: sidewalk

; Sidewalk: light-grey with a darker grey tile pattern.
        ; fcm_com_sidewalk
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C

; Plaza: sidewalk frame around a small blue fountain in the centre.
        ; fcm_com_plaza
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$0B,$0C
        .byte $0C,$0B,$0C,$0C,$0C,$0C,$0B,$0C
        .byte $0C,$0B,$0C,$01,$01,$0C,$0B,$0C   ; blue fountain
        .byte $0C,$0B,$0C,$01,$01,$0C,$0B,$0C
        .byte $0C,$0B,$0C,$0C,$0C,$0C,$0B,$0C
        .byte $0C,$0B,$0B,$0B,$0B,$0B,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        ; fcm_com_sidewalk
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C

; Plaza: sidewalk frame around a small blue fountain in the centre.
        ; fcm_com_shop
        .byte $0C,$08,$08,$08,$08,$08,$08,$0C   ; row 0: blue awning
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 1: signboard
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 2: windows
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 3: windows
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 4: between
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 5: big shop window
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 6: big shop window
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; row 7: sidewalk

; Sidewalk: light-grey with a darker grey tile pattern.
        ; fcm_com_sidewalk
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0C,$0B,$0C,$0C,$0B,$0C,$0C,$0B
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
        .byte $0B,$0C,$0C,$0B,$0C,$0C,$0B,$0C

; Plaza: sidewalk frame around a small blue fountain in the centre.
        ; fcm_com_shop
        .byte $0C,$08,$08,$08,$08,$08,$08,$0C   ; row 0: blue awning
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 1: signboard
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 2: windows
        .byte $0C,$0F,$00,$0F,$0F,$00,$0F,$0C   ; row 3: windows
        .byte $0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C   ; row 4: between
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 5: big shop window
        .byte $0C,$0F,$00,$00,$00,$00,$0F,$0C   ; row 6: big shop window
        .byte $0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C   ; row 7: sidewalk

; Sidewalk: light-grey with a darker grey tile pattern.
tileset_commercial_heavy_end:
        .cerror tileset_commercial_heavy_end - tileset_commercial_heavy != COM_HEAVY_CELL_COUNT * 64, "commercial-heavy chars must match COM_HEAVY_CELL_COUNT"

        .fill (FIRESTATION_CHAR_BASE * 64) - (tileset_commercial_heavy_end - tileset_start), $00

;=======================================================================================
; Fire department structure: 9 chars at FIRESTATION_CHAR_BASE. Same 3x3 shape
; as police but red ($0D) body instead of blue, white ($0F) trim, and "FD"
; lettering in the centre cell.
;=======================================================================================
tileset_firestation:
        ; fcm_fire_tl
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D   ; white left edge + red body
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        ; fcm_fire_tc
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white top edge
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        ; fcm_fire_tr
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F

; Row 1: building middle, with white "FD" letters on the centre cell.
        ; fcm_fire_ml
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F   ; white south edge

; Centre cell with "FD" in white on red.
;   col:  0   1   2   3   4   5   6   7
; row 0:  .   .   .   .   .   .   .   .
; row 1:  .   F   F   F   .   D   D   .       FFF DD
; row 2:  .   F   .   .   .   D   .   D       F   D D
; row 3:  .   F   F   F   .   D   .   D       FFF D D
; row 4:  .   F   .   .   .   D   .   D       F   D D
; row 5:  .   F   .   .   .   D   D   .       F   DD
; row 6:  .   .   .   .   .   .   .   .
; row 7:  white south edge
        ; fcm_fire_c
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0D,$0F,$0F,$0F,$0D,$0F,$0F,$0D
        .byte $0D,$0F,$0D,$0D,$0D,$0F,$0D,$0F
        .byte $0D,$0F,$0F,$0F,$0D,$0F,$0D,$0F
        .byte $0D,$0F,$0D,$0D,$0D,$0F,$0D,$0F
        .byte $0D,$0F,$0D,$0D,$0D,$0F,$0F,$0D
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
        ; fcm_fire_mr
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0F
        .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F

; Row 2: grounds (grass $02 with yellow $06 flower dots; centre cell has a
; dark $0B driveway approaching the building from the south).
        ; fcm_fire_bl
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$06,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        ; fcm_fire_bc
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$06,$0B,$0B,$0B,$0B,$06,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        .byte $02,$02,$0B,$0B,$0B,$0B,$02,$02
        ; fcm_fire_br
        .byte $02,$02,$02,$06,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$06,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$06,$02,$02,$02,$02,$02
        .byte $02,$06,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$02,$02
        .byte $02,$02,$02,$02,$02,$02,$06,$02
        .byte $02,$02,$02,$06,$02,$02,$02,$02

tileset_firestation_end:
        .cerror tileset_firestation_end - tileset_firestation != FIRESTATION_CELL_COUNT * 64, "fire station chars must match FIRESTATION_CELL_COUNT"

;=======================================================================================
; Traffic road animation: display-only variants for plain straight roads.
;=======================================================================================
tileset_traffic_roads:
        .cerror tileset_traffic_roads - tileset_start != TRAFFIC_ROAD_H_BASE * 64, "traffic road chars must start at TRAFFIC_ROAD_H_BASE"
        ; TRAFFIC_ROAD_H_BASE + 0: horizontal road, black car at x 0-1
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$21,$21,$21,$21,$20,$20
        .byte $00,$00,$20,$20,$20,$20,$20,$20
        .byte $00,$00,$20,$20,$20,$20,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$23,$23,$23,$23,$23,$23,$23
        ; TRAFFIC_ROAD_H_BASE + 1: horizontal road, black car at x 2-3
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$21,$21,$21,$21,$20,$20
        .byte $20,$20,$00,$00,$20,$20,$20,$20
        .byte $20,$20,$00,$00,$20,$20,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$23,$23,$23,$23,$23,$23,$23
        ; TRAFFIC_ROAD_H_BASE + 2: horizontal road, black car at x 4-5
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$21,$21,$21,$21,$20,$20
        .byte $20,$20,$20,$20,$00,$00,$20,$20
        .byte $20,$20,$20,$20,$00,$00,$20,$20
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$23,$23,$23,$23,$23,$23,$23
        ; TRAFFIC_ROAD_H_BASE + 3: horizontal road, black car at x 6-7
        .byte $1F,$1F,$1F,$1F,$1F,$1F,$1F,$1F
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$20,$20
        .byte $20,$20,$21,$21,$21,$21,$20,$20
        .byte $20,$20,$20,$20,$20,$20,$00,$00
        .byte $20,$20,$20,$20,$20,$20,$00,$00
        .byte $22,$22,$22,$22,$22,$22,$22,$22
        .byte $23,$23,$23,$23,$23,$23,$23,$23

        ; TRAFFIC_ROAD_V_BASE + 0: vertical road, black car at y 0-1
        .byte $23,$22,$00,$00,$20,$20,$20,$1F
        .byte $23,$22,$00,$00,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        ; TRAFFIC_ROAD_V_BASE + 1: vertical road, black car at y 2-3
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$00,$00,$21,$20,$20,$1F
        .byte $23,$22,$00,$00,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        ; TRAFFIC_ROAD_V_BASE + 2: vertical road, black car at y 4-5
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$00,$00,$21,$20,$20,$1F
        .byte $23,$22,$00,$00,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        ; TRAFFIC_ROAD_V_BASE + 3: vertical road, black car at y 6-7
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$20,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$20,$20,$21,$20,$20,$1F
        .byte $23,$22,$00,$00,$20,$20,$20,$1F
        .byte $23,$22,$00,$00,$20,$20,$20,$1F
tileset_traffic_roads_end:
        .cerror tileset_traffic_roads_end - tileset_traffic_roads != TRAFFIC_ROAD_CHAR_COUNT * 64, "traffic road chars must match TRAFFIC_ROAD_CHAR_COUNT"

tileset_end:
        .cerror tileset_end - tileset_start != TILESET_ASSET_SIZE, "tileset asset must match TILESET_ASSET_SIZE"
