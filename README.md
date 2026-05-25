MEGA-SimCity
============

A native MEGA65 city-builder scaffold inspired by SimCity. The display uses FCM
mode (Full Colour Mode: 8x8 chars, one byte per pixel = an 8-bit palette index)
at 320x200 pixels: 40 columns by 25 rows of 8x8 full-color cells. City tiles are
16x16 pixels (a 2x2 block of FCM cells). An 18x12-tile viewport scrolls over a
64x32-tile city map, framed by a top status bar and a left tool rail.

Build
-----

Run `build.bat` from this directory. It assembles `src/main.asm` with 64tass and
writes `target/mega-simcity.d81`. It also assembles `src/assets/tileset.asm` and
`src/assets/ui_tiles.asm` as separate disk files named `tileset` and `uitiles`.

Run
---

Run `run.bat` to build and launch the D81 in Xemu.

Controls
--------

Mouse-first (a 1351-compatible mouse in control port 1):

- Move the mouse to move the pointer. Push the pointer against a screen edge to
  scroll the map.
- Click a tool icon in the left rail to select it; the black selector box moves to
  the chosen tool.
- Hold the left button over the map to paint the selected tile.

Keyboard shortcuts:

- `0`-`6`: pick and paint a tile type (water, grass, road, residential,
  commercial, industrial, power)
- `Space`: paint the current tile at the cursor
- `Q`: restore the default screen and return to BASIC

Architecture
------------

At boot, `tileset` and `uitiles` are loaded from disk into a chip-RAM staging
buffer, DMA-copied to Attic RAM, then DMA-copied into VIC-visible FCM character
RAM. The graphics layer (`src/graphics/`) vendors a minimal MEGA65 FCM screen
setup plus FCM character helpers.

The runtime is split into focused modules, with the master loop and region
dispatch in `main.asm`:

- `platform.asm` — hardware register and layout constants
- `mouse.asm` — 1351 device driver: reads motion/buttons into state
- `viewport.asm` — map geometry: pointer hit-testing, tile/cursor, edge-scroll
- `toolbar.asm` — tool-rail rendering and click-to-select-tool
- `sprites.asm` — all VIC sprite hardware and positioning
- `render.asm` — static chrome and map-tile rendering
- `city.asm` — city map state
- `input.asm` — keyboard
- `assets.asm`, `src/assets/` — tile/UI tile data and the shared palette

Each frame: read input -> dispatch by region (toolbar / map / off-map) -> tick ->
render -> reflect state onto sprites. Three sprites are used: 0 = mouse pointer,
1 = yellow map cursor, 2 = black tool selector.

Note: this is a 45GS02 target. `STZ` stores the Z register (not zero) on this CPU;
use `LDA #0 / STA`. See `.claude/CLAUDE.md` for MEGA65 notes and gotchas,
`docs/PLAN.md` for the build-out plan, `MEMORY.md` for the memory map, and
`TODO.md` for known issues and deferred/scaling work.
