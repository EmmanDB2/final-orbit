# Art brief: lander_flat

Written 2026-11-14 by Opus, from Manny's call ("start on a flat version of the original lander"), for
Gemini through the Antigravity CLI (`agy`). Gemini does all the art: the template, the concept, and the
finished asset in the Asset Editor. Sonnet only brings the export into the game. The Moon Hopper
(`docs/briefs/moon_hopper_in_asset_editor.md`) and the cargo pod test are the worked examples.

## Status (paused 2026-11-14)

Paused on Manny's call: Gemini's quota ran out mid-way through round 3 of the concept (resets about
2026-11-21), and Claude usage is low too. Work so far is in the drop folder,
`/Users/emmanuelwalters/Projects/Final Orbit Art Drop/lander_flat/` (round-2 concept
`lander_flat_concept.png`, `concept_1x/`, `concept_numbers.txt`, Manny's marks `manny_markup_1.png`).
Nothing has gone into the editor or the game.

- **Round 2 fixed:** the notch in the left side pod (filled, 61 px); the side pods mirrored; the legs
  redrawn and hidden (stowed fully inside the hull, 0 of 290 px outside; deployed feet where today's
  are); stripes in their own colors and gold foil from round 1. Mass 19,502 kg against 19,491 today
  (+0.06%).
- **Still open:** the five red-circled spots are holes in the lower hull with loose specks and stray
  outline strips around them, still there; the legs are spindly, not as sturdy as the Mk II's (now
  allowed up to 1,400 kg for the pair); with the legs stowed low the center of mass is 2.7 px lower
  than today, over the 2 px aim (deployed it's unchanged).
- **Hidden legs:** a per-leg module setting, `stows_inside_hull`, on for this lander and the Lander
  Mk II, not the Moon Hopper (Manny: "Only the Lander MK II should."). For the builder's ticket at
  import: such legs draw behind the hull, their stowed pose is inside the outline, and while fully or
  mostly stowed they don't count in the outline for aero, ground contact, standing width, or hits ahead
  of the hull; their mass still counts. Fit the pivot and swing to `set_parts_out` in
  `scripts/ship/ship_body.gd`. If the Mk II's leg art can't fit inside its outline without a redraw,
  ask Manny before redrawing. `data/lander_design.tres` has older uncommitted changes that aren't this
  work: ask before touching it.
- **Resuming:** when resumed, try a different Gemini model inside agy first. If its results aren't
  usable, a Sonnet session does the pixel fixes from this brief.

## How Opus runs it

The drop folder is `/Users/emmanuelwalters/Projects/Final Orbit Art Drop/lander_flat/`. This brief is
copied there, with today's lander art in `today/` (every PNG from the game's `art/lander/`, exactly as
the game has them, plus `lander_body_exterior_4x.png`, the eight exterior modules put together at 4x).

1. **Template and concept**, from the drop folder:
   `agy -p "<prompt>" --sandbox --effort high`. Manny OKs the concept (through the main session)
   before anything goes on.
2. **Exterior in the editor**, from `/Users/emmanuelwalters/Projects/Final Orbit Asset Editor` with
   `--add-dir` for the drop folder. It stops after the flat exterior preview for Manny's OK.
3. **The rest in the editor**: systems and frame recolored, checks, exports, and the JSON.
4. **Into the game**: the builder copies the PNGs over `art/lander/` under the same names; the checker
   tests and screenshots it.

Rules for every `agy` prompt (from the cargo pod test):
- Never use RunWorkflow or any built-in Python tool; write `.py` files and run them with `python3`.
- Run each command as one plain command starting with `python3` or `godot`, with relative paths from
  the working folder: no `cd`, no `&&`, `;`, or pipes, no other programs (do `ls`, `mkdir` and the like
  inside Python).
- `python3` here has no PIL: read and write PNGs with `zlib` and `struct`, as the cargo pod's
  `generate_art.py` did, or with a `godot --headless -s` script.

## What it is

The game's original lander, the ship the pilot starts with (DESIGN.md, "Ships"), remade **flat**. Its
art has light and shade painted in, lit from the left, and the game now lights hulls by the star from
their own outline (DESIGN.md, "Lighting", outside ticket 1), so today it's lit twice. Manny asked for a
flat version, like the Lander Mk II and the Moon Hopper.

**This is a repaint, not a redesign.** Same silhouette, same modules in the same cells, same parts, same
legs, same stripes, windows, foil, panel lines and details. Only the painted light, shade, highlights and
gradients go, replaced by flat fills. Manny cut nose fins: there are none. He doesn't want the lander's
mass moved.

How the game's lighting works, so the flat fills are right: it only ever **darkens**. Each pixel steps
down its own ramp in the palette, and the side toward the star stays full. So paint every surface in
the **lightest** color it has today, the color its lit side shows, and let the game do the rest. The
ramps, lightest first:

- hull: E8E4DA, A9ADB3, 6B7079, 3D4148, 23262B, 0E0F12
- gold: F2D27A, D4A23A, 9C6B1E, 5A3E12
- orange: F28A3A, D9541E, 7A2E12; red: C8302C
- blue: 6FA3C8, 2F5D8C, 1B2E4A
- glass: 8FC7CF, 2A4A55

What counts as painted shading here (look at `today/lander_body_exterior_4x.png`): the light-gray
A9ADB3 and darker-gray bands down the right-hand side of each white hull face; the darker ends and
undersides of the side pods and tanks; the light-to-dark gradient across the canopy glass and its
glints; the light-to-dark gradient and highlights across the gold foil; the gradient down the engine
bell and RCS bells; the darker right-hand ends of the orange and blue stripes. What stays, as drawn
detail, not shading: panel lines and rivets, the stripes themselves in their own paint (each stripe
takes the color its left, lit end has today, so agency orange D9541E stays D9541E and the navy band
stays 1B2E4A; a stripe isn't moved to the lightest of its ramp), window frames, the foil as D4A23A with
its crinkle lines in 9C6B1E, even over the whole tank, not darker toward one side, and parts that are a different color because they're a different part
(dark steel bells, the gray side pods if they're gray all round, dark gaps between modules).

## Manny's changes to the first concept (2026-11-14)

His marked-up concept is `manny_markup_1.png` in the drop folder. His words: "Remove all the little
details circled in the red, Make the legs proper like the rest of the ships (We're removing the
original lander), and Fix the inconsistencies circled in green (left tank shouldn't actually have a
chip and right isn't painted symetrically)". These win over "a repaint, not a redesign" below.

1. **Red circles, five spots:** the small dark marks low on the body, at the bottom corners of the tank
   wings and just above and below the lower outer corners of the engine modules (about canvas
   (2-8, 183-192), (16-24, 183-192) and (16-24, 194-201) on the left, (92-100, 183-192) and
   (112-120, 183-192) on the right). They turned out to be transparent holes in the hull with loose
   specks and stray outline strips around them: fill the holes with flat E8E4DA, delete the specks and
   strips, and outline the clean edge. The exterior must be one connected piece, with no piece under
   30 px.
2. **Green boxes, the gray side pods on the RCS modules:** the left pod has a notch cut into its outer
   edge near its bottom (about canvas x 14-18, y 114-136): fill it to a clean straight edge (this adds a
   few pixels; the only place the silhouette may grow). The right pod's vertical panel lines don't
   mirror the left's: make the two pods exact mirror images, lines and all. More generally, make the
   left and right columns mirror images wherever they differ by accident.
3. **New legs**, replacing the original lander's for good, in the style and construction of the Lander
   Mk II's (`reference/mk2_leg_left.png`, `mk2_leg_right.png`, and the 6x sheet with the Hopper's): a
   broad foot pad, a sturdy strut with a shock-absorber collar, a round pivot joint at the hinge, a
   bracket, a 1 px 0E0F12 outline, flat fills (E8E4DA and A9ADB3 hull, steel only for joints, the
   collar and the pivot). They have to fit the lander's leg code and placement:
   - **hidden when stowed** (Manny: "Is it possible to put the legs UNDER the ship? So they aren't
     visible when folded?"): the game draws these legs behind the hull, so stowed, every leg pixel
     must lie inside the lower body's outline (the wide tank-wing skirt and the engine modules),
     covered by solid hull pixels; they show only when they come down;
   - how the game moves a leg: it's drawn **stowed**, and coming out its hinge slides by the leg's
     `travel` while the art flips **vertically** about the hinge (y mirrored, x unchanged, no
     rotation). So the stowed art is the deployed leg upside down: foot pad at the **top**, pivot at
     the bottom, and anything leaning outward stowed leans outward deployed;
   - deployed, the hinge lands where today's does, canvas (0, 203) on the left, and the foot pad's top
     edge sits 42 px above the hinge in the stowed art (so 42 px below it deployed), as today: the feet
     land where today's do, below the engine bell, the ship's lowest pixels, and as wide;
   - pick the stowed hinge inside the left skirt so the whole stowed leg fits under the hull there;
     its travel is then (0, 203) minus the stowed hinge. The right leg is the exact mirror of the left
     (x' = 127 - x), deployed hinge (127, 203);
   - a strut about 5-7 px wide with its outline and a foot pad about 16-20 px wide: the first try at
     1,100 kg for the pair came out spindly, so the pair may weigh up to 1,400 kg (a leg pixel weighs
     its density times 1.0: hull 1 kg, steel 3 kg). Hiding the legs low under the skirt moves the
     stowed center of mass down about 3 px; that's the price of hiding them, and it's reported, not
     hidden.
   Save each leg's size, art position (its top-left on the canvas, stowed), stowed hinge and travel in `concept_numbers.txt`;
   the game's design data takes them from there.

## The template

- The canvas: 2 x 64 by 4 x 64 px (128 x 256), the lander's grid, drawn at 8 screen px per art px
  (1024 x 2048), with the 64 px cells outlined in thin lines.
- A 36 px pilot (288 screen px) standing beside it on the same ground line, the canvas's bottom edge.
- To the right of the canvas, room for the two legs at their own size: left leg 14 x 44, right leg
  16 x 45, at the same scale.
- A flat, plain background, and nothing else.

## The concept

Drawn on the template, as **real pixel art drawn by a Python script, 8 screen px per art px**, so the
editor reads it back pixel for pixel. Build it from today's pixels: read the PNGs in `today/`, put the
eight exterior modules on the canvas in their cells (row 0 cockpit, row 1 RCS, row 2 tank, row 3
engine; column 0 `_left`, column 1 `_right`), and recolor them flat by the rules above and below. Then
the two legs, recolored the same way, beside the canvas: the game draws them stowed, as they are in
these PNGs, so one view is enough.

- **The silhouette doesn't move by a pixel.** Every pixel that's solid today stays solid, every clear
  one stays clear, in every PNG. Pixels are collision.
- Colors only from the ramps above (no telemetry cyan 7FE3D6 or green 6BCB5A), flat, with no gradients,
  painted light, shade, or highlights.
- A 1 px near-black outline, 0E0F12, on the outer silhouette's edge pixels (recolor the edge pixels;
  never add pixels outside). Gaps between modules that are dark today stay dark.
- Keep it symmetric where today's art is symmetric apart from its shading.
- Save it as `lander_flat_template.png` and `lander_flat_concept.png`, and the plain 1x recolored PNGs
  under today's names in `concept_1x/` (exterior only: `cockpit_left.png` ... `engine_right.png`,
  `leg_left.png`, `leg_right.png`), plus the numbers below printed and saved to `concept_numbers.txt`.

## Layout, for the editor

Nothing about the layout changes. The editor already has today's lander as documents, pixel for pixel
and with the game's materials, in `game/ships/lander/` (`lander.foasset` for the body on the 128 x 256
grid with its systems and frame layers, `leg_left.foasset`, `leg_right.foasset`, `lander.json`,
`README.md`). **Leave those as they are.** Make the flat version as copies in `game/ships/lander_flat/`
(the body and the two legs; no fins), and recolor them there.

- Cells: row 0 cockpit, row 1 rcs, row 2 tank, row 3 engine; column 0 left, column 1 right. PNG base
  names `<kind>_<left|right>`.
- Layers on the body: exterior 0.4, systems 0.2, frame 0.225 thick. Legs: one layer, counted at 1.0.
- Legs, points, components, and numbers: as in `game/ships/lander/lander.json`, unchanged.
- **Systems and frame layers**: recolor flat the same way, with **every pixel keeping its material**
  (only swap colors within one row of the table below). They're seen only where the hull's shot away.

## Colors and what they weigh

The game reads each pixel's material **from its color**; the editor's own material map doesn't reach
it. Set the editor's materials to match the colors.

| Material | Colors | Density | Strength |
| --- | --- | --- | --- |
| Hull aluminum | E8E4DA A9ADB3 | 1.0 | 250 kJ |
| Painted hull | 7A2E12 D9541E F28A3A C8302C 1B2E4A 2F5D8C 6FA3C8 | 1.0 | 250 kJ |
| Structural steel | 6B7079 3D4148 23262B 0E0F12 | 3.0 | 750 kJ |
| Gold foil | 5A3E12 9C6B1E D4A23A F2D27A | 0.25 | 50 kJ |
| Canopy glass | 2A4A55 8FC7CF | 0.6 | 100 kJ |
| Lights and glow | FFF3C4 FFB347 F2B33A | 0.25 | |

A pixel weighs its density times its layer's thickness, in kg: an exterior steel pixel 1.2 kg, an
exterior hull pixel 0.4 kg; a leg steel pixel 3 kg, a leg hull pixel 1 kg.

Most of the repaint is free: every shade of a material is the same material. Two things move mass, and
should cancel:
- The near-black outline turns hull-white and light-gray edge pixels into steel (about +0.8 kg each in
  the exterior, +2 kg on a leg).
- Painted shade bands in steel grays (6B7079, 3D4148, 23262B) on white hull faces become hull white
  (about -0.8 kg each).
Canopy panes painted 6FA3C8 may become glass 8FC7CF if they're glass (-0.16 kg each).

## Numbers to aim for

Today, measured by the game (`tools/ship_numbers.gd`):

| | Today | Aim |
| --- | --- | --- |
| Dry mass | 19,491 kg (body 18,390, legs 1,101) | within 2% (390 kg), better within 1% |
| Center of mass, empty | (-0.87, 7.51) px from the grid's middle; (63.13, 135.51) on the 128 x 256 canvas | within 2 px each way |
| Center of mass, full | (-0.28, 23.98) px | within 2 px each way |
| Spin resistance, empty, legs up | 67,032,911 | within 3% |

Measure the game's way, by the color table times each layer's thickness, and print today's numbers and
the flat version's side by side. If the mass is off, balance it by which shade bands go white, evenly
left and right. Fuel, cargo, engine and RCS numbers don't change.

## Exports

- One PNG per module per layer, 64 x 64 and transparent outside the module, under the game's names,
  in the editor's `exports/lander_flat/game_pngs/`: `cockpit_left.png`, `cockpit_left_systems.png`,
  `cockpit_left_frame.png`, and so on for `rcs`, `tank`, `engine`, left and right; `leg_left.png`
  (14 x 44) and `leg_right.png` (16 x 45). 26 files, each the same size and alpha as today's.
- `game/ships/lander_flat/lander_flat.json`: the same placements and numbers as `lander.json`, plus the
  flat version's mass and center, measured by the color table, beside today's.
- Previews at 1x and 4x: the exterior, the systems cut away, the frame, beside the 36 px pilot.
- `exports/` is in the editor's `.gitignore`; a commit, when Manny allows one, needs `git add -f`.
