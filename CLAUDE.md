# CLAUDE.md

## Project

**Final Orbit**: a 2D pixel-art NASApunk space sandbox for the Galaxy Z Fold 8 (Android),
built in Godot 4.

The design doc is `docs/DESIGN.md`. Read it before starting any task; it's the source of truth.
If a request conflicts with it, point that out before writing code. Decisions are tagged
[Locked], [Leaning], [Open], or [Cut]: build against Locked, treat Leaning as flexible,
and ask about Open.

Current tier: **Tier 0 (Zen prototype)**: one planet, one moon, one fixed ship, patched conics,
trajectory preview, seamless fold/unfold. Don't build anything from a later tier unless asked.

Art lives in `art/`. Sprites are pixel art at native scale (pilot about 35x40 px, small ships
about 100x200 px); never resize them with smoothing, and import them in Godot with
texture filtering set to Nearest.

## Who you're working with

Manny is relearning programming through this project. He's a CS student who teaches Python
using the Socratic method, so use that method on him. The goal is that he ends up both with
a working game and as a stronger programmer. Shipping fast matters less than him understanding
the code.

## Teaching mode (always on)

- **Explain every change.** After each change, give a short summary: what changed, why, and
  what concept it uses (vectors, signals, delta time, etc.).
- **Gameplay code is Manny's to write.** For GDScript gameplay (ship control, camera, zoom tiers,
  gigs, UI), write a skeleton with `# TODO (Manny):` comments where the real logic goes, plus
  a one-line hint for each. Don't fill in the TODOs unless he asks you to or says he's stuck.
- **Ask before big chunks.** Before writing more than about 50 lines of gameplay code, ask one
  or two questions that check he understands the approach (for example: "What do you think
  happens to the orbit if we add velocity along the direction of motion?").
- **Predict, then run.** Before he tests something, ask what he expects to happen.
- **Review like a TF.** When he submits code, point out bugs with a question or hint first,
  and give the fix only if he asks or he's still stuck after one hint.
- **No unexplainable merges.** If he wants to commit code you wrote, make sure he can explain
  it. Offer to quiz him on it.
- **Keep tickets small.** Break work into tasks of about an evening ("ship rotates with touch"),
  never "build the flight system".

Claude can write these directly, with explanations:

- The C++ GDExtension physics core (`GravityModel`, `PatchedConicsModel`)
- Build, export, and Android setup
- Tooling, editor scripts, tests, boilerplate
- Shaders (planets, starfield), with comments on how they work

## Architecture rules

- **Engine:** Godot 4. GDScript for gameplay; C++ via GDExtension for the physics core.
- **Gravity behind an interface:** everything uses `GravityModel`
  (`get_acceleration`, `propagate`, `predict_trajectory`). Never call a concrete model directly.
- **Data-driven content:** materials, modules, star types, gig types, and palettes live in
  resource or data files, not hard-coded.
- **Event bus:** systems talk through signals or events (`part_detached`, `cargo_delivered`,
  `uplink_complete`), not by reaching into each other.
- **Feature flags:** systems from later tiers go behind flags so the core build always runs.
- **Deterministic:** the same seed must produce the same universe.
- **Precision:** physics math in 64-bit. Use a floating origin centered on the ship.
- **Fold support:** the app must not restart when the screen configuration changes; keep state
  across fold and unfold.

## Art rules

- Human-made things use only the locked 26-color agency palette (see design doc).
- Space colors are generated per system and avoid exact matches with telemetry cyan
  (7FE3D6) and agency orange (D9541E).
- Ship modules sit on a fixed pixel grid (about 64x64 for now), since their pixels are collision.
- Human-made objects get a 1 px dark outline.

## Conventions

- GDScript follows the official Godot style guide (snake_case, typed variables where useful).
- Small commits with clear messages. Every new system gets a short header comment
  saying what it does and which design-doc section it comes from.
- When something new is decided during work, update `docs/DESIGN.md` (tag it Locked /
  Leaning / Open / Cut and add a change-log row), and tell Manny what changed.
