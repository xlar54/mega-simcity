# MEGA-SimCity — Memory Map

Where everything lives in the MEGA65's 28-bit address space. Addresses are
physical (28-bit) unless noted. Keep this in sync when you move a region — it is
the project's authoritative layout (see also the constants in `src/platform.asm`).

The MEGA65 has three memory areas this project uses:
- **Chip/fast RAM** — 384 KB, `$00000-$5FFFF` (banks 0-5). CPU-addressable; the
  VIC-IV fetches screen/char data from here.
- **Attic / HyperRAM** — 8 MB, `$08000000+` (MB `$80+`). Not directly
  CPU-addressable: reach it via DMA or 45GS02 32-bit indirect addressing. The
  VIC-IV **cannot** read it.
- **Colour RAM** — 32 KB at `$FF80000` (VIC-IV attribute RAM).

## Chip / fast RAM ($00000-$5FFFF)

| Region | Address | Contents |
|---|---|---|
| Zero page | `$F6-$FF` | pointers (see below) |
| Stack | `$0100-$01FF` | CPU stack |
| Text screen | `$0800` | legacy C65 text screen (BASIC mode only) |
| BASIC stub | `$2001` | `SYS 8210` one-liner that launches the game |
| Program | `$2012-~$4639` | game code + data (grows; stays well below `$6000`) |
| **Bank 1** | `$10000-$11FFF` | **RESERVED — C65 KERNAL/DOS workspace, do not use** |
| FCM screen | `$16000` | `SCREEN_RAM` — char-code matrix the VIC-IV displays |
| **Bank 4** | `$40000` | `CHAR_DATA` — FCM glyph bitmaps (64 bytes/char) |
| **Bank 5** | `$50000` | boot asset staging buffer (`TILESET_STAGE_BANK`) |

Char data detail: bank 4 holds 64 KB / 64 = **1024 chars**; ~174 used (city
tiles, zone cells, cursor, UI chrome, font, toolbar buttons). See `TODO.md`
"Stream tiles from Attic" for the plan when this fills up.

Boot asset staging: `tileset` / `uitiles` are KERNAL-LOADed into bank 5
(`$50000`), then DMA-copied up to Attic. Bank 5 (top of the 384 KB) keeps the
buffer clear of program code in bank 0. See `src/assets.asm`.

## Zero page pointers

All are in the base page (page 0). The 32-bit ones are used with `[zp],z`
(45GS02 32-bit indirect) to reach beyond bank 0.

| Addr | Name | Width | Use |
|---|---|---|---|
| `$F6-$F9` | `MAP_PTR` | 32-bit | world-map cell pointer into Attic; survives `set_fcm_char` |
| `$FA-$FB` | `PTR2` | 16-bit | scratch; char-bitmap source in `create_fcm_char` |
| `$FC-$FF` | `PTR` | 32-bit | scratch; clobbered by `set_fcm_char` |

The runtime never calls KERNAL (only boot loading does), so the KERNAL zp range
is free for the game after boot — that's why `MAP_PTR` can sit at `$F6`.

## Attic / HyperRAM ($08000000+)

| Region | Address | MB | Size | Contents |
|---|---|---|---|---|
| Tile/asset library | `$08000000` | `$80` | 2 MB reserved | `tileset` `$08000000` (1792 B), `uitiles` `$08001000` (7040 B) |
| **World map** | `$08200000` | `$82` | 48,000 B | `ATTIC_MAP_PHYS` — 240x200 cell array, 1 byte/cell |

World map: 120x100 tiles = 240x200 cells (a 16x16 tile = 2x2 cells). Read/written
with 32-bit indirect via `MAP_PTR` (`city_cell_ptr` builds the address); filled at
boot by a single DMA fill (`city_fill_ground`). Placed 2 MB in to leave the first
2 MB for the asset library to grow.

## Colour RAM

`$FF80000` — 32 KB VIC-IV attribute/colour RAM (set up in
`src/graphics/fcm_screen.asm`, cleared by `clear_color_ram_fcm`). The cleared
state leaves the per-char NCM bit off, so chars render as full-byte FCM pixels.

## Planned (not yet allocated)

- **Simulation overlay layers** (power, population, traffic, pollution, land
  value, crime, coverage) — coarse-resolution, ~20 KB combined, recomputed each
  sim tick. Candidate for **chip RAM** (fast direct access), not Attic. See
  `TODO.md` "World map & simulation".
