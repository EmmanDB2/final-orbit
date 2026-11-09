# Asset editor handoff

The prompt Manny gives GPT to start building the Final Orbit Asset Editor, with the practical notes it needs. Written by Claude, which builds the game, on November 9, 2026.

---

You're building the **Final Orbit Asset Editor**, a desktop app for making the game's ships, station rooms, and planets. Manny (Emmanuel Walters) owns the project. Claude builds the game itself, in the same repository. You build the editor. The plan is `docs/ASSET_EDITOR_DESIGN.md`, revised after review on November 9; it's the source of truth for this work.

## Read first

1. `CLAUDE.md`: the project's rules. Its conventions apply to you too: GDScript style guide, typed variables, a header comment on every new script naming the design section it comes from, small commits with clear messages, and a `docs/LEARNING_LOG.md` entry per ticket, prefixed "Asset editor:". Manny learns the engine from that log, so keep entries to one line per concept.
2. `docs/ASSET_EDITOR_DESIGN.md`, all of it. Sections 3, 7.1, 12, 19, 20, and 21 matter most to start.
3. In `docs/DESIGN.md`: Ships, Art direction (the locked agency palette and the art pipeline), and Camera, zoom, and landing.

## Where you work

- Make your own branch and worktree, so you never share a working copy with Claude:

  ```bash
  git worktree add "../Final Orbit Asset Editor" -b asset-editor tier-1
  ```

  `tier-1` is where the game is now; `main` is behind it. Manny merges.
- The native physics library isn't committed. Copy it into your worktree's `bin/` from the main checkout, or build it per `native/README.md` after `git submodule update --init`:

  ```bash
  cp "../Final Orbit/bin/libfinalorbit.macos.template_debug.arm64.dylib" bin/
  ```

- Godot 4.7.2 is on the PATH as `godot`, with the Compatibility renderer. Run `godot --headless --path . --import` after adding assets.
- You own `editor/`, `core/`, and `tests/core/`. Read and reuse the game's folders (`scripts/`, `scenes/`, `data/`, `shaders/`, `native/`, `art/`, `tests/`), but don't edit them. If you need a game change, add a row to the requests table in section 20 of the design, or ask Manny.
- In `project.godot` and `export_presets.cfg`, only add the editor's `asset_editor` feature overrides and its macOS export preset, and add `editor/*` to the Android preset's `exclude_filter`.

## Things that will bite

- **No autoloads.** The game has none, and anything you add runs inside the phone build too.
- **`class_name` is global.** Prefix editor classes `Editor` and core classes `Core`. The game already uses: AgencyPalette, BodyData, BurnButton, CommsLine, CommsLog, ContextCard, DamageWave, DebrisField, EngineFlame, FeatureFlags, FlightHud, FlightMenu, GroundEffects, HeadingDial, MaterialData, ModuleData, Pilot, PilotData, RcsButton, RcsPuffs, ReentryGlow, ShipBody, ShipDesign, SidePanel, SideTab, SparkField, StarData, StationDesign, StationLayout, StationRoom, StationView, SurfaceProps, TargetMarkers, ThrottleLever, TopBar, TurnGuide, UiButton, UiStyle, UiWidget, WorldCatalog.
- **Window settings.** The game's viewport is 816 × 616 with integer stretch, and its `ScreenFit` node resizes it at runtime. Your main scene should set its own window and stretch at startup, or use `asset_editor` feature overrides.
- **Data maps aren't textures.** Load material and mask PNGs with `Image.load_from_file`, never through the importer, which may compress or filter them. Game sprites are imported with Nearest filtering; never resize sprites with smoothing.
- **`.tres` files.** `Color("hex")` doesn't parse in a `.tres`; write `Color(r, g, b, 1)`. Typed arrays look like `Array[ExtResource("id")]([...])`. Opening the project in the Godot editor re-saves files, dropping default values and adding UIDs. That's harmless, but keep those re-saves out of your commits.
- **Headless runs** get a 64 × 64 window, so anything that sizes itself from the screen needs setting by hand in tests.
- **The palette has 25 colors**, not the 26 the docs say. Use the resource's actual entries.

## Tests

The game's tests run headless and print `N checks, M failed`:

```bash
godot --headless --path . --script tests/test_ship_body.gd
godot --headless --path . --script tests/test_gravity_model.gd
godot --headless --path . --script tests/test_station.gd
```

They must keep passing. Put the core's tests in `tests/core/` in the same style.

## First milestone: Phase 1 of the design

Build `core/` with the smallest versioned document and bundle format for explicit materials, component identity, and blueprint placement, plus `editor/cli.gd` to drive it headless:

```bash
godot --headless --path . --script res://editor/cli.gd -- <command>
```

Convert the current lander (`data/lander_design.tres`, art in `art/lander/`) and one station room (`data/station_1.tres`, art in `art/station_1/`) through the CLI. Section 19 lists what has to hold. The lander's numbers to match are about 19,491 kg dry, 40,000 kg of fuel, 300 m/s² full, and 16,738 m/s of delta-v full.

The game won't load your bundles until Claude integrates them, so prove the round trip in `tests/core/`. Note anything the game side will need to change in the requests table.

After that comes Phase 2: generalize `tools/slice_station.gd` and `tools/slice_pilot.gd` into `import.*` commands. They already recover a fake-pixel grid, drop backgrounds and stars, snap to the palette in Oklab, smooth speckle, restore outlines, and line frames up on an anchor. That's what the game needs most, because its next work, cargo gigs, needs new ship modules and station rooms.

## How to work with Manny

- He's a solo developer and a computer science student, and he's new to Godot. Keep replies short: what changed, which files, and how to test it.
- Ask only when a design decision is genuinely ambiguous, and point out conflicts with the design docs before writing code.
- When something gets decided, update `docs/ASSET_EDITOR_DESIGN.md` with a change-log row, and tell him.
- Section 21's first open decision, the game's scale, is his to make. Don't pick one for him.
