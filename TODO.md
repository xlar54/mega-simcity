# MEGA-SimCity — Known Issues / TODO

Tracking known issues. Severity from the code review; line numbers are on
`master` and may drift as the code changes — re-grep if they look off.

## High

- [x] **POT read spin-forever fixed.** `mouse_read_pot_x` / `mouse_read_pot_y`
      now cap the stable-read retries at `MOUSE_POT_READ_TRIES` ($20) and fall
      back to the previous sample (that axis registers no movement) instead of
      looping forever inside the `sei` section.

## Medium

- [x] **Spacebar down-scroll diagnostic removed.** Was in `input_poll`
      (`input_space_held` intercept) forcing `INPUT_MOVE_DOWN` on held space and
      blocking the normal space-to-paint path. Removed the intercept, the
      `input_space_held` routine, and its scratch vars; keyboard space now
      reaches `_ip_paint` via the key queue.

- [ ] **Disk loads retry forever on failure.** `src/assets.asm` (~line 14).
      On real hardware a missing tileset/uitiles file or drive fault hangs at
      boot with no visible error.
      *Fix:* add a retry limit + visible error (border color / error screen).

- [ ] **UI tile index file is ignored by the loader.** The index exists in
      `src/assets/ui_tiles.asm` (~line 40), but the runtime loader DMAs using
      hard-coded compile-time offsets in `src/assets.asm` (~line 200). Works
      today, but undermines the index and will break when tiles become
      variable size.
      *Fix:* have the loader actually read the index.

## Low

- [x] **Toolbar slot-0 redraw workaround removed.** Root cause was the 45GS02
      `stz` bug (stores Z, not zero) corrupting render/loop counters. After the
      codebase-wide `stz` -> `lda #0`/`sta` fix, slot 0 renders correctly and the
      redraw-after-loop hack in `toolbar_render` is gone.

## Deferred (scaling)

- [ ] **Stream tiles from Attic when char RAM fills up.** Today every tile is
      DMA'd resident into char RAM at boot (`tiles_load` / `ui_load`,
      `src/assets.asm` Stage 2). Bank 4 holds 64KB / 64 = ~1024 chars; only ~174
      are used, so there's lots of headroom. The VIC-IV **cannot** fetch glyphs
      from Attic, so once the art outgrows the resident budget, keep the master
      library in Attic and DMA only currently-needed tiles into a char-RAM cache
      on demand. The `bank 5 -> Attic -> char RAM` hop already exists for exactly
      this; don't build the cache/eviction logic until needed.
      *When implementing:* add a per-asset index — `id`, `width_chars`,
      `height_chars`, `size_bytes`, `attic_addr`, `attic_bank`, `attic_mb` — to
      describe each tile for the on-demand DMA. (Related: the Medium item about
      the loader ignoring the UI tile index.)

## World map & simulation (planned)

Target map is the classic/Amiga SimCity size: 1920x1600 px = **120x100 tiles**.
At this project's 8x8 cell resolution (1 tile = 2x2 cells) that's **240x200 =
48,000 cells**, 1 byte/cell = **~47 KB**. (Today's map is 64x32 tiles = 128x64
cells = 8 KB, currently `city_cells` at the end of `main.asm`.)

- [ ] **Phase 1 — full world map in Attic (start here).** Move the cell array to
      Attic and grow it to 240x200. Proposed layout: tile/asset library stays at
      Attic start (`$08000000`, MB `$80`, 2 MB reserved); world map at **Attic +
      2 MB = `$08200000` (MB `$82`)**, on a clean megabyte boundary.
      *Access:* the CPU can't reach Attic with normal addressing, so rewrite
      `city_cell_ptr` and the paint/render reads to use 45GS02 32-bit indirect
      addressing (`lda [zp],z` with a 28-bit base) instead of the current 16-bit
      zp-indirect. The renderer is dirty-flag based (~864 cell reads on a full
      viewport redraw, only on scroll/paint), so direct 32-bit Attic access is
      fast enough — no DMA-window cache needed unless profiling says so. If it
      ever is needed, that's the same "Attic master + chip-RAM working window"
      pattern as the tile-streaming item above.

- [ ] **Phase 2+ — simulation overlay layers.** Derived from the main map,
      mostly **coarser** resolution and **recomputed each sim tick** (scratch, not
      save state), so they're small (~20 KB combined) and are good candidates for
      **chip RAM** (fast direct access) rather than Attic. Bring online as the
      RCI growth model is built:
      - **Power grid** — flood-fill from plants along conductive tiles; zones
        won't develop unpowered. Full tile res, bitmap (~1.5 KB). *Needed first,
        alongside zones/roads.*
      - **Population density** — half res (60x50, ~3 KB); feeds traffic, crime,
        growth.
      - **Traffic density** — half res; high traffic suppresses desirability,
        drives road/rail demand.
      - **Pollution** — half res; from industry, traffic, coal plants; lowers
        land value & desirability.
      - **Land value** — half res; distance-to-center + terrain (water/parks
        raise) minus pollution/crime; drives R/C growth.
      - **Crime** — half res; rises with density, falls with police coverage +
        land value.
      - **Police / fire coverage**, **rate of growth** — eighth res (~15x13,
        <1 KB each); station effect radius / growth indicators.
      Core feedback loop: pollution + crime + traffic pull land value down/up ->
      land value + power + RCI demand decide zone growth/decline -> growth feeds
      population density -> density regenerates traffic and pollution.

## Resolved this session

- [x] **45GS02 STZ bug (the big one).** `stz` stores the Z register, not zero
      (see `.claude/CLAUDE.md`). Replaced every `stz` with `lda #0`/`sta`. Root
      cause of the selector "following the mouse" (the left-click edge never
      cleared, so the toolbar handler ran every frame) plus latent counter/flag
      corruption (render loops, tile compute, dirty flags).
- [x] **Sprite alignment.** `SPRITE_SCREEN_X` was 40; correct is 24 (standard
      sprite-X for the screen's left edge). Pointer, map cursor, and selector now
      align to the screen and to clicks.
- [x] **Map / toolbar layout.** `MAP_OVERLAP_LEFT_COLS = 0` so the map starts
      after the toolbar; chrome (`render_ui`) is drawn on top of the viewport.
- [x] **Selector finalized.** Sprite 2 moves only on a confirmed toolbar click,
      sits on the selected tool, is black, and uses a dedicated 17px-wide
      `sprite_selector_shape` (sprite 1 keeps the 16px box).
- [x] **Module split.** `sprites.asm` (all sprite hw/positioning), `viewport.asm`
      (map geometry/scroll), `toolbar.asm` (button render + click->tool), with
      region dispatch in `main.asm`; `mouse.asm` is now the device driver.
- [x] **Temp diagnostics removed.** Cyan selector -> black; border click-test gone.

## Sprite contract (reference)

- Sprite 0 — mouse pointer (positioned in `mouse_position_pointer_sprite`,
  `src/sprites.asm`).
- Sprite 1 — yellow map cursor block (`mouse_position_block_sprite`, 16px box).
- Sprite 2 — toolbox selection block (dedicated 17px `sprite_selector_shape`);
  positioned by `sprite_position_selector` in `src/sprites.asm`, called only
  from `sprites_init` (startup) and `toolbar_handle_click` (a confirmed
  left-click in the toolbar band). Never moves on hover.
