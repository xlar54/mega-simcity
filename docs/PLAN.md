MEGA-SimCity Plan
=================

Goal
----

Build a native MEGA65 city-builder in NCM mode at 320x200 pixels. The base display
is a 40x25 grid of 8x8 NCM cells. City terrain uses 16x16 tiles composed of four
NCM cells, so the fixed top/left UI can coexist with a scrolling 17x10-tile main
viewport.

Current Scaffold
----------------

- `src/graphics/ncm_screen.asm`: minimal MEGA65 VIC-IV setup for NCM40 only.
- `src/graphics/ncm_core.asm`: NCM character upload, screen placement, clear, and
  color-RAM setup from the local `m65-fcm` library.
- `src/tiles.asm`: initial city tile palette and 8x8 NCM tile art.
- `src/assets.asm`: boot-time disk load from `tileset` into Attic RAM.
- `src/assets/tileset.asm`: first 16x16 city tiles, assembled as a separate disk
  asset.
- `src/ui.asm`: static top bar and left tool/status rail tiles.
- `src/title.asm`: NCM title screen with an Enter prompt and skyline.
- `src/city.asm`: map storage, cursor state, tile painting, and simulation tick
  placeholder.
- `src/render.asm`: static UI plus scrolling viewport redraw and cursor overlay.
- `src/input.asm`: KERNAL keyboard polling for movement and tile placement.

Phase 1: Playable Tile Editor
-----------------------------

Make the city view comfortable before adding simulation. Add tile highlighting
that preserves the underlying tile, a small status strip, better road/water/zone
tiles, and tile placement rules.

Phase 2: Core Simulation
------------------------

Add the first real city systems:

- funds and monthly budget tick
- roads as connectivity graph
- residential, commercial, and industrial demand counters
- simple population/jobs growth
- power coverage from power plants through roads or wires
- bulldoze and terrain costs

Phase 3: UI and Game Loop
-------------------------

Add a tool palette, budget/readout area, keyboard shortcuts, pause/speed modes,
and a monthly/yearly tick cadence. Keep the main screen functional on real
hardware first, then add polish.

Phase 4: Larger City
--------------------

Replace the current redraw-based viewport scroll with region-aware NCM scrolling.
The `m65-fcm` scroll helper already supports row bands; we need to extend the
column start/end handling so the top bar and left rail stay fixed while the main
window smooth-scrolls.

Phase 5: Persistence and Polish
-------------------------------

Add disk save/load, generated terrain, disasters, better zone graphics, sound,
and title/options screens. At that point the project may want overlays or
banked data like `mega-elite`, but the scaffold deliberately avoids that until
the game needs it.
