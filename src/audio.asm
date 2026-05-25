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
