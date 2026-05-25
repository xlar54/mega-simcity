;=======================================================================================
; Audio: MEGA65 SID register constants.
;
; The MEGA65 has four SIDs (each the standard 6581/8580 25-register layout,
; repeated every $20 bytes). Stereo routing is set by the MEGA65 audio mixer and
; is configurable, but the conventional default pairs them L/R as noted below;
; verify against the mixer config if precise panning matters.
;
; This file currently defines constants only. Audio code (init, music/SFX
; players) will live here later; wire an audio_init into app_init when added.
;=======================================================================================

; --- SID base addresses (add the register offsets below to one of these) ------
SID1_BASE               = $D400   ; left
SID2_BASE               = $D420   ; right
SID3_BASE               = $D440   ; left
SID4_BASE               = $D460   ; right

; --- Per-voice register offsets -----------------------------------------------
; Voices 1-3 repeat every SID_VOICE_STRIDE bytes from the SID base:
;   voice N register = base + SID_VOICEn + SID_<reg>
SID_VOICE_STRIDE        = $07
SID_VOICE1              = $00
SID_VOICE2              = $07
SID_VOICE3              = $0E

SID_FREQ_LO             = $00     ; voice frequency, low byte
SID_FREQ_HI             = $01     ; voice frequency, high byte
SID_PW_LO               = $02     ; pulse width, low byte
SID_PW_HI               = $03     ; pulse width, high nibble (bits 0-3)
SID_CTRL                = $04     ; control register (waveform + gate, see bits)
SID_AD                  = $05     ; attack (hi nibble) / decay (lo nibble)
SID_SR                  = $06     ; sustain (hi nibble) / release (lo nibble)

; --- Global / filter registers (offsets from a SID base) ----------------------
SID_FC_LO               = $15     ; filter cutoff, low 3 bits
SID_FC_HI               = $16     ; filter cutoff, high 8 bits
SID_RES_FILT            = $17     ; resonance (hi nibble) + filter routing (lo)
SID_MODE_VOL            = $18     ; filter mode (hi nibble) + volume (lo nibble)
SID_POTX                = $19     ; paddle X (read)
SID_POTY                = $1A     ; paddle Y (read)
SID_OSC3                = $1B     ; voice 3 oscillator / noise (read)
SID_ENV3                = $1C     ; voice 3 envelope (read)

; --- Control register bits ($04/$0B/$12) --------------------------------------
SID_CTRL_GATE           = %00000001   ; 1 = start attack, 0 = start release
SID_CTRL_SYNC           = %00000010   ; hard-sync this voice to voice N-1
SID_CTRL_RING           = %00000100   ; ring-modulate with voice N-1
SID_CTRL_TEST           = %00001000   ; reset/hold the oscillator
SID_CTRL_TRIANGLE       = %00010000
SID_CTRL_SAWTOOTH       = %00100000
SID_CTRL_PULSE          = %01000000
SID_CTRL_NOISE          = %10000000

; --- Resonance / filter routing bits ($17) ------------------------------------
SID_FILT_VOICE1         = %00000001   ; route voice 1 through the filter
SID_FILT_VOICE2         = %00000010
SID_FILT_VOICE3         = %00000100
SID_FILT_EXT            = %00001000   ; route external input through the filter
; resonance is the high nibble: value << 4

; --- Filter mode / volume bits ($18) ------------------------------------------
SID_MODE_LP             = %00010000   ; low-pass
SID_MODE_BP             = %00100000   ; band-pass
SID_MODE_HP             = %01000000   ; high-pass
SID_MODE_3OFF           = %10000000   ; disconnect voice 3 from the output
; master volume is the low nibble (0-15)

;=======================================================================================
; Sound effects
;=======================================================================================

; Explosion burst parameters (tweak to taste).
EXPLO_FREQ      = $0600   ; noise pitch: low -> a deep rumble
EXPLO_AD        = $09     ; attack 0 (instant hit), decay 9 (~0.75s fade)
EXPLO_SR        = $00     ; sustain 0, release 0 -> decays to silence on its own

; Play a brief explosion on SID 1, voice 1: a noise burst with an instant attack
; that decays to silence. Fire-and-forget -- the SID plays the envelope out in
; hardware, so this returns immediately (no blocking). Call it on the event you
; want the sound for (e.g. a bulldoze).
audio_explosion:
        lda #$0F
        sta SID1_BASE + SID_MODE_VOL                ; master volume up
        lda #<EXPLO_FREQ
        sta SID1_BASE + SID_VOICE1 + SID_FREQ_LO
        lda #>EXPLO_FREQ
        sta SID1_BASE + SID_VOICE1 + SID_FREQ_HI
        lda #EXPLO_AD
        sta SID1_BASE + SID_VOICE1 + SID_AD
        lda #EXPLO_SR
        sta SID1_BASE + SID_VOICE1 + SID_SR
        ; Retrigger the envelope: drop the gate (noise still selected), then raise
        ; it so the attack restarts from zero.
        lda #SID_CTRL_NOISE
        sta SID1_BASE + SID_VOICE1 + SID_CTRL
        lda #(SID_CTRL_NOISE | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE1 + SID_CTRL
        rts

; Road-build blip parameters (tweak to taste).
ROAD_FREQ       = $1800   ; pulse pitch
ROAD_PW         = $0800   ; pulse width ~50% (12-bit; needed or pulse is silent)
ROAD_AD         = $07     ; attack 0 (instant), decay 7 (short tick)
ROAD_SR         = $00     ; sustain 0, release 0 -> decays to silence on its own

; Short blip for placing a road, on SID 1 voice 2 -- a different voice from the
; explosion (voice 1) so the two never cut each other off. Pulse waveform.
; Fire-and-forget (hardware envelope), returns immediately.
audio_road_build:
        lda #$0F
        sta SID1_BASE + SID_MODE_VOL                ; master volume up
        lda #<ROAD_FREQ
        sta SID1_BASE + SID_VOICE2 + SID_FREQ_LO
        lda #>ROAD_FREQ
        sta SID1_BASE + SID_VOICE2 + SID_FREQ_HI
        lda #<ROAD_PW
        sta SID1_BASE + SID_VOICE2 + SID_PW_LO
        lda #>ROAD_PW
        sta SID1_BASE + SID_VOICE2 + SID_PW_HI
        lda #ROAD_AD
        sta SID1_BASE + SID_VOICE2 + SID_AD
        lda #ROAD_SR
        sta SID1_BASE + SID_VOICE2 + SID_SR
        ; Retrigger: drop the gate (pulse still selected), then raise it.
        lda #SID_CTRL_PULSE
        sta SID1_BASE + SID_VOICE2 + SID_CTRL
        lda #(SID_CTRL_PULSE | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE2 + SID_CTRL
        rts

; UI click parameters (tweak to taste).
CLICK_FREQ      = $2800   ; pulse pitch: high -> a crisp tick
CLICK_PW        = $0800   ; pulse width ~50% (must be non-zero or pulse is silent)
CLICK_AD        = $04     ; attack 0 (instant), decay 4 (very short)
CLICK_SR        = $00     ; sustain 0, release 0 -> decays to silence on its own

; Short UI click for selecting a toolbar button, on SID 1 voice 3 -- its own
; voice so it never cuts off the explosion (1) or road blip (2). Pulse waveform.
; Fire-and-forget (hardware envelope), returns immediately.
audio_click:
        lda #$0F
        sta SID1_BASE + SID_MODE_VOL                ; master volume up
        lda #<CLICK_FREQ
        sta SID1_BASE + SID_VOICE3 + SID_FREQ_LO
        lda #>CLICK_FREQ
        sta SID1_BASE + SID_VOICE3 + SID_FREQ_HI
        lda #<CLICK_PW
        sta SID1_BASE + SID_VOICE3 + SID_PW_LO
        lda #>CLICK_PW
        sta SID1_BASE + SID_VOICE3 + SID_PW_HI
        lda #CLICK_AD
        sta SID1_BASE + SID_VOICE3 + SID_AD
        lda #CLICK_SR
        sta SID1_BASE + SID_VOICE3 + SID_SR
        ; Retrigger: drop the gate (pulse still selected), then raise it.
        lda #SID_CTRL_PULSE
        sta SID1_BASE + SID_VOICE3 + SID_CTRL
        lda #(SID_CTRL_PULSE | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE3 + SID_CTRL
        rts

; Construction burst parameters (tweak to taste). All three SID 1 voices fire at
; once for a "busy work-site" sound: a hammer thunk + a saw buzz + a drill whine,
; each decaying to silence (sustain 0). NOTE: this is a one-shot burst, not a
; looping hammer/saw -- a repeating version would need a per-frame ticked player.
CONSTR_HAMMER_FREQ = $0800   ; voice 1: noise thunk (low)
CONSTR_HAMMER_AD   = $08     ; short hit
CONSTR_SAW_FREQ    = $1000   ; voice 2: sawtooth saw buzz (mid)
CONSTR_SAW_AD      = $0A     ; longer buzz (~1.5s fade)
CONSTR_DRILL_FREQ  = $2800   ; voice 3: pulse drill whine (high)
CONSTR_DRILL_PW    = $0400   ; narrow pulse -> reedy
CONSTR_DRILL_AD    = $0A

; Construction sound for placing a residential/commercial/industrial zone: hammer
; (voice 1 noise), saw (voice 2 sawtooth) and drill (voice 3 pulse) together on
; SID 1. Fire-and-forget. Uses all three voices, so it overrides any explosion /
; road / click still ringing -- fine, since these effects don't truly overlap.
audio_construct:
        lda #$0F
        sta SID1_BASE + SID_MODE_VOL
        ; voice 1 -- hammer (noise)
        lda #<CONSTR_HAMMER_FREQ
        sta SID1_BASE + SID_VOICE1 + SID_FREQ_LO
        lda #>CONSTR_HAMMER_FREQ
        sta SID1_BASE + SID_VOICE1 + SID_FREQ_HI
        lda #CONSTR_HAMMER_AD
        sta SID1_BASE + SID_VOICE1 + SID_AD
        lda #$00
        sta SID1_BASE + SID_VOICE1 + SID_SR
        ; voice 2 -- saw (sawtooth)
        lda #<CONSTR_SAW_FREQ
        sta SID1_BASE + SID_VOICE2 + SID_FREQ_LO
        lda #>CONSTR_SAW_FREQ
        sta SID1_BASE + SID_VOICE2 + SID_FREQ_HI
        lda #CONSTR_SAW_AD
        sta SID1_BASE + SID_VOICE2 + SID_AD
        lda #$00
        sta SID1_BASE + SID_VOICE2 + SID_SR
        ; voice 3 -- drill (pulse)
        lda #<CONSTR_DRILL_FREQ
        sta SID1_BASE + SID_VOICE3 + SID_FREQ_LO
        lda #>CONSTR_DRILL_FREQ
        sta SID1_BASE + SID_VOICE3 + SID_FREQ_HI
        lda #<CONSTR_DRILL_PW
        sta SID1_BASE + SID_VOICE3 + SID_PW_LO
        lda #>CONSTR_DRILL_PW
        sta SID1_BASE + SID_VOICE3 + SID_PW_HI
        lda #CONSTR_DRILL_AD
        sta SID1_BASE + SID_VOICE3 + SID_AD
        lda #$00
        sta SID1_BASE + SID_VOICE3 + SID_SR
        ; gate all three off (keeping each waveform), then on together
        lda #SID_CTRL_NOISE
        sta SID1_BASE + SID_VOICE1 + SID_CTRL
        lda #SID_CTRL_SAWTOOTH
        sta SID1_BASE + SID_VOICE2 + SID_CTRL
        lda #SID_CTRL_PULSE
        sta SID1_BASE + SID_VOICE3 + SID_CTRL
        lda #(SID_CTRL_NOISE | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE1 + SID_CTRL
        lda #(SID_CTRL_SAWTOOTH | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE2 + SID_CTRL
        lda #(SID_CTRL_PULSE | SID_CTRL_GATE)
        sta SID1_BASE + SID_VOICE3 + SID_CTRL
        rts
