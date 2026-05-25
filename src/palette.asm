;=======================================================================================
; SimCity-classic palette (sampled from reference screenshot).
;
; STANDALONE / NOT INTEGRATED. This file is intentionally left out of the include
; list and the build. To try it, include it AFTER assets.asm (so the SET_COLOR
; macro and set_palette_color are defined) and call palette_simcity in place of
; tiles_init_palette.
;
; Values are 4-bit per channel (0-15), matching the codebase's current palette
; convention. The source image colors are 8-bit; the comment after each entry
; shows the approximate 8-bit RGB it stands in for. Several near-identical shades
; in the screenshot collapse onto one 4-bit slot, so this is 16 representative
; colors rather than a 1:1 copy of every pixel value.
;
; Slot legend (what each index represents in the screenshot):
;   0  black        status bar / outlines
;   1  white        text, zone letters (R/C/I)
;   2  panel gray    light toolbar panel
;   3  road gray     roads, concrete
;   4  dark gray     shadows, building bodies, road edges
;   5  ground tan    dirt terrain (dominant map color)
;   6  ground brown  dirt shading / bare soil
;   7  grass green   light grass / parks
;   8  forest green  trees / dense forest
;   9  water blue    river water
;  10  deep water    water shadow / deep channel
;  11  red           power plant roof, fire/alerts
;  12  orange        industrial accents, brick
;  13  yellow        UI text highlights, industrial zone (I)
;  14  commercial    commercial zone (C) blue
;  15  light green   residential zone (R) highlight
;=======================================================================================

palette_simcity:
        #SET_COLOR 0,  0,  0,  0     ; black            (0,0,0)
        #SET_COLOR 1, 15, 15, 15     ; white            (255,255,255)
        #SET_COLOR 2, 13, 13, 13     ; panel light gray (210,210,210)
        #SET_COLOR 3,  9,  9,  9     ; road gray        (145,145,145)
        #SET_COLOR 4,  4,  4,  4     ; dark gray        (65,65,65)
        #SET_COLOR 5, 12, 10,  6     ; ground tan       (195,165,100)
        #SET_COLOR 6,  8,  6,  3     ; ground brown     (130,100,50)
        #SET_COLOR 7,  5, 11,  3     ; grass green      (80,180,50)
        #SET_COLOR 8,  2,  7,  2     ; forest green     (35,115,35)
        #SET_COLOR 9,  3,  6, 12     ; water blue       (50,100,200)
        #SET_COLOR 10, 1,  3,  9     ; deep water       (20,50,150)
        #SET_COLOR 11,13,  2,  2     ; red              (210,35,35)
        #SET_COLOR 12,13,  7,  1     ; orange           (210,115,20)
        #SET_COLOR 13,14, 13,  2     ; yellow           (230,215,35)
        #SET_COLOR 14, 3,  9, 14     ; commercial blue  (50,150,225)
        #SET_COLOR 15, 8, 13,  5     ; light green      (130,210,85)
        rts
