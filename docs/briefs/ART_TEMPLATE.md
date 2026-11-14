# Art brief: <asset>

Written <date> by Opus, from Manny's calls, for Gemini through the Antigravity CLI (`agy`). Copy this
file to `docs/briefs/<asset>_art.md` and fill it in. Gemini does all the art: the template, the
concept, and the finished asset in the Asset Editor. Sonnet only brings the export into the game, from
the game brief's ticket. The Moon Hopper (`docs/briefs/moon_hopper_in_asset_editor.md`, 2026-11-14) is
the worked example, from before Gemini took over the editor step.

## How Opus runs it

Everything Gemini reads or makes outside the editor lives in the **drop folder**,
`/Users/emmanuelwalters/Projects/Final Orbit Art Drop/<asset>/`, outside both projects, since the
editor's `AGENTS.md` bars reading game files. Opus copies this brief there.

1. **Template and concept**, run from the drop folder, with the template's numbers in the prompt:
   `cd "<drop>/<asset>" && agy -p "<prompt>; save them here as <asset>_template.png and <asset>_concept.png" --sandbox --effort high`.
   Show Manny the concept; nothing goes on until he OKs it.
2. **Exterior in the editor**, run from the editor's folder with the drop folder added:
   `cd "/Users/emmanuelwalters/Projects/Final Orbit Asset Editor" && agy -p "<prompt>" --sandbox --effort high --add-dir "<drop>"`,
   pointing at this brief and the concept by absolute path. It stops after the flat exterior preview.
   Show Manny; he OKs it or asks for changes.

   Headless `agy` can't ask for permission, so what it needs is saved, with Manny's OK (2026-11-14), in
   `~/.gemini/antigravity-cli/settings.json`: the editor and the drop folder as trusted workspaces;
   reading the editor; writing only its `game/` and `exports/`; reading and writing the drop folder;
   and the commands `godot *` and `python3 *` (which may run outside agy's sandbox). Reads outside the
   working folder are always refused headless, whatever the rules say, hence `--add-dir`. Anything
   else is passed for one run only, such as a commit in the editor once Manny allows it:
   `--settings '{"permissions":{"allow":["command(git add *)","command(git commit *)"]}}'`. A denied
   tool ends the run with "a tool required the "<name>" permission": add exactly that rule and run
   again, or continue the same conversation with `agy -c -p "..." --effort high` so it keeps its work. Always run Gemini at `--effort high` (Manny, 2026-11-14).

   **Put these rules in every `agy` prompt** (learned on the cargo pod test, 2026-11-14):
   - Never use RunWorkflow or any built-in Python tool (refused headless); write `.py` files and run
     them with `python3`.
   - Run each command as one plain command starting with `python3` or `godot`, with relative paths
     from the working folder: no `cd`, no `&&`, `;`, or pipes, no other programs (do `ls`, `mkdir`
     and the like inside Python). Anything else doesn't match the saved rules and is refused.
   - Its sandbox can't take the space in these folder names ("globs not supported"), so the allowed
     commands run outside it; the saved rules are what limit them.
   - Ask for the concept as **real pixel art drawn by a Python script** on the template (8 screen px
     per art px), not from the image generator: the editor then reads it back pixel for pixel, with no
     redrawing. The cargo pod's concept took 2 minutes and was exact.
3. **The rest in the editor**, a second run from the same folder: inside layers, materials,
   components, checks, exports, and the JSON. Then Opus checks the stats and shows Manny the previews.
   The cargo pod test took about 15 minutes in the editor, including one refused run.
4. **Into the game**, with Manny's OK: the builder (Sonnet) copies the PNGs and writes the data file,
   then the checker screenshots it.

This session never edits the editor's files itself; Gemini does, from inside the editor's folder, under
the editor's `AGENTS.md`.

## What it is

What the asset is, what it's for in the game, and Manny's calls on its look, quoted where his words
decided something. The DESIGN.md section it comes from.

## The template

The image Gemini draws the concept on, so the concept comes out at the right shape and scale:

- the asset's canvas, `<cols> x 64` by `<rows> x 64` px for a ship on the module grid, drawn at 8 screen
  px per art px, with the 64 px cells outlined in thin lines;
- a 36 px pilot standing beside it at the same scale, on the same ground line;
- a flat, plain background, and nothing else.

## The concept

Drawn on the template, inside the canvas, nose up, seen from the side:

- the look in a few lines, and what it must have (cockpit, tanks, bell, legs...);
- a second view beside the first where it has moving parts: legs **stowed**, as the game draws them
  before they fold out;
- colors only from the palette below, flat, with no gradients, painted light, shade, or highlights: the
  game lights ships and buildings by the star from their outline;
- a 1 px near-black outline (0E0F12) around everything human-made.

## Layout, for the editor

- The canvas, its cells, and which module kind and game name sits in each, with its PNG base name.
- Symmetry, if any, and the layers (exterior, systems, frame) with their thicknesses.
- Parts off the grid (legs) and how they move: hinge, travel, fold, drawn stowed.
- Points (hatch, EVA exit, cockpit) and components (working and nozzle rectangles, nozzle points,
  tanks).

## Colors and what they weigh

The game reads each pixel's material **from its color**, by this table (`data/materials/`); the
editor's own material map doesn't reach it. So set the editor's materials to match the colors, and
reach the mass by choosing colors: every dark gray, the outline included, is steel, three times as
heavy as the hull. On the hopper, materials set apart from color made it 8.1 t in the editor and
14.3 t in the game.

| Material | Colors | Density | Strength |
| --- | --- | --- | --- |
| Hull aluminum | E8E4DA A9ADB3 | 1.0 | 250 kJ |
| Painted hull | 7A2E12 D9541E F28A3A C8302C 1B2E4A 2F5D8C 6FA3C8 | 1.0 | 250 kJ |
| Structural steel | 6B7079 3D4148 23262B 0E0F12 | 3.0 | 750 kJ |
| Gold foil | 5A3E12 9C6B1E D4A23A F2D27A | 0.25 | 50 kJ |
| Canopy glass | 2A4A55 8FC7CF | 0.6 | 100 kJ |
| Lights and glow | FFF3C4 FFB347 F2B33A | 0.25 | |

Telemetry cyan 7FE3D6 and green 6BCB5A have no material in the game; keep them off unless this brief
says otherwise.

## Numbers to aim for

A target mass (not only a range), its center, and anything the game's physics needs, measured the
game's way: by the table above, times each layer's thickness. Work the target out from the art, not by
guess: a mostly filled 64 x 64 module with three layers at 0.4 / 0.2 / 0.225 weighs about 2 t (the
cargo pod test; it was asked for 700 kg, which its look couldn't reach). Better still, set numbers that
depend on mass from the game's own measure afterward, as the Moon Hopper's brief did.

## Exports

- One PNG per module per layer, 64 x 64 and transparent outside the module, named the game's way, in
  the editor's `exports/<asset>/game_pngs/`; parts off the grid at their own size.
- `game/<kind>/<asset>/<asset>.json` with what the documents can't hold: cells, part positions, hinges,
  travel and fold, points, and rectangles, in the units the game brief names; plus the mass and center,
  measured by the color table.
- Previews at 1x and 4x: the exterior, the systems cut away, the frame, moving parts both ways, beside
  the 36 px pilot.
- `exports/` is in the editor's `.gitignore`; a commit, when Manny allows one, needs `git add -f`.
