# MEGA-SimCity — Known Issues / TODO

Tracking known issues. Severity from the code review; line numbers are on
`master` and may drift as the code changes — re-grep if they look off.

## High

- [ ] **POT read can spin forever.** `mouse_read_pot_x` / `mouse_read_pot_y`
      (`src/mouse.asm` ~line 274 and ~281) loop until two identical POT reads
      agree. If the mouse is unplugged, noisy, in the wrong mode, or jitters
      under NCM load, the game can lock inside an `sei` section.
      *Fix:* add a retry cap and fall back to the previous sample on timeout.

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
