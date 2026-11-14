# CLAUDE.md

## Project

**Final Orbit**: a 2D pixel-art NASApunk space sandbox for the Galaxy Z Fold 8 (Android),
built in Godot 4.

The design doc is `docs/DESIGN.md`. Read it before starting any task; it's the source of truth.
If a request conflicts with it, point that out before writing code. Decisions are tagged
[Locked], [Leaning], [Open], or [Cut]: build against Locked, treat Leaning as flexible,
and ask about Open.

Current tier: **Tier 1 (Core)**: one star system, modular pixel ships with mass and destruction,
cargo and data gigs, deliverable-based pay, Zen Mode, cover-screen play. Don't build anything from a
later tier unless asked.

Art lives in `art/`. Sprites are pixel art at native scale (pilot about 35x40 px, small ships
about 100x200 px); never resize them with smoothing, and import them in Godot with
texture filtering set to Nearest.

## How we work: build mode (default)

Manny uses separate sessions for building and for learning. Sessions that start normally are
**build sessions**: build the feature, don't teach.

- Write all the code, gameplay included. No TODO gaps, no quizzes, no Socratic questions.
- Keep replies short: what you changed, which files, and how to test it. Skip explanations
  unless asked.
- Ask a question only when a design decision is genuinely ambiguous; otherwise follow the
  design doc and keep going.
- Keep tickets small (about an evening of work, like "ship rotates with touch") and commit
  after each one with a clear message.
- **Leave a trail for teach sessions:** after each ticket, append one entry to
  `docs/LEARNING_LOG.md`: date, ticket, files touched, and 1-3 concepts it used (for example
  "signals", "delta time", "Kepler orbits"). One line per concept, no explanations.

Teach sessions start with the `/teach` command (`.claude/commands/teach.md`). Only switch
to teaching when that command is used or Manny asks.

## Who does what

Manny is on Claude Pro, so usage is tight. He talks only to the main session, on Opus, and it hands
work down:

- **Opus (the main session):** talks with Manny, decides how features work, does the hard math and
  system design, and writes a brief for each feature in `docs/briefs/` from `docs/briefs/TEMPLATE.md`.
  It doesn't do routine coding itself when a helper can.
- **builder** (`.claude/agents/builder.md`, Sonnet): builds the tickets from a brief, commits each,
  logs it, installs on the Fold, and reports back to Opus.
- **checker** (`.claude/agents/checker.md`, Sonnet): runs the tests and checks, takes and looks at
  screenshots, and reports in a few lines, so images and long output stay out of the main session.
- **explorer** (`.claude/agents/explorer.md`, Haiku): answers "where is" and "how does" questions about
  the code without reading it all into the main session.
- **Sprites, in three steps:** (1) Opus writes an art brief (like
  `docs/briefs/lander_mk2_in_asset_editor.md`) with a Gemini prompt for the concept; (2) Manny makes
  the concept in his Gemini app; (3) a separate session working in the Asset Editor project (Sonnet,
  or Opus for hard pieces) builds it there from the brief and the concept, on the pixel grid, in the
  palette, with layers, materials, and components, and exports the game's PNGs. Then this session
  brings them into the game, with Manny's OK. Never edit the editor's project from here. (Fable did
  step 3 until it left the Pro plan in November 2026.)
- **Gemini, through Manny's Gemini app:** concepts for those briefs, a second opinion on screenshots,
  and brainstorming.

Keep the main session to one feature at a time, and start a fresh one for the next: this file,
`docs/DESIGN.md`, the brief, and the learning log carry everything over. Small one-line changes can
still be made directly.

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
