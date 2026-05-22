MEGA-SimCity
============

A native MEGA65 city-builder scaffold inspired by SimCity. The display uses NCM
mode at 320x200 pixels: 40 columns by 25 rows of 8x8 full-color cells. The city
map is built from 16x16 tiles, each made from four NCM cells.

Build
-----

Run `build.bat` from this directory. It assembles `src/main.asm` with 64tass and
creates `target/mega-simcity.d81`. The build also assembles `src/assets/tileset.asm`
as a separate disk file named `tileset`.

Run
---

Run `run.bat` to build and launch the D81 in Xemu. The script follows the local
MEGA65 emulator path used by the reference repos.

Current Controls
----------------

- `Enter`: leave the title screen and enter the city
- `WASD` or cursor keys: move the tile cursor; the main city window scrolls when
  the cursor reaches the viewport edge
- `0`: water
- `1`: grass
- `2`: road
- `3`: residential
- `4`: commercial
- `5`: industrial
- `6`: power
- `Space`: paint the currently selected tile
- `Q`: restore the default screen and return to BASIC

Architecture
------------

The graphics layer is intentionally small. It vendors only the MEGA65 FCM/NCM
screen setup and NCM character helpers derived from `C:\Users\scott\repos\m65-fcm`.
At boot, `tileset` is loaded from disk into a chip-RAM staging buffer, DMA-copied
to Attic RAM, then DMA-copied into VIC-visible NCM character RAM for rendering.
The top bar and left tool rail are static; the main 17x10 tile viewport scrolls
over a larger city map.

See `docs/PLAN.md` for the build-out plan.
