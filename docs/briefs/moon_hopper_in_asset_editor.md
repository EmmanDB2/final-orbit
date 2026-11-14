# Brief: build the Moon Hopper in the Asset Editor

For a session working in Manny's **Asset Editor**, the sibling project at
`/Users/emmanuelwalters/Projects/Final Orbit Asset Editor`. Written 2026-11-14 by the game's main
session (Opus), from Manny's calls. Manny has approved a concept picture from Gemini; your job is to
build the ship from it properly, on the pixel grid, in the palette, with layers, materials, and
components, and export the game's PNGs. The Lander Mk II was built the same way from
`game/ships/lander_mk2/` in the editor; it's your best reference.

## Before you start

1. You work **only in the Asset Editor**. Read its `AGENTS.md` first and follow it; never edit anything
   in the game project. This brief and the concept carry everything the game needs.
2. Read the editor's `README.md`, `ASSET_EDITOR_DESIGN.md`, and `docs/CLI.md`, the command line you'll
   build with. Then `game/ships/lander_mk2/README.md` and `lander_mk2.json`, the ship you're following.
   Leave everything in `game/ships/lander/` and `game/ships/lander_mk2/` as it is.
3. Put your work in `game/ships/moon_hopper/` and its exports in `exports/moon_hopper/`.
4. The editor's own tests must stay green (`docs/CLI.md`, "Verification and handoff"). If the editor
   can't do something you need, say so in your report instead of working around it.

## What the game is

Final Orbit is a 2D pixel-art space game on a folding phone, in a "NASApunk" style: 1960s–70s space
agency hardware, Apollo-era but original. Ships are seen from the side, nose up, at 5 cm a pixel; the
pilot is about 36 px tall. **A ship's pixels are its collision and its damage**: hits erase them layer by
layer, a part stops working when it loses enough, and loose pieces fly off. The game lights ships by the
star from their own outline, so **draw everything flat**: base colors, stripes, and panel lines, but no
painted light, shade, or highlights.

## The ship

A small one-seat moon hopper, cheap and nimble, that only flies on low-gravity worlds. Manny picked the
**bubble cab** look: a round glass bubble cockpit in the middle on top with a small docking hatch ring at
its very top, RCS clusters on short outriggers at both top shoulders, two round gold-foil fuel tanks low
on the sides, one small engine bell at the bottom center, and two landing legs splayed wide with broad
round foot pads. Follow the concept's shape and spirit; the rules below win where they disagree with it.

- Hull white and light gray, structure dark gray, agency orange and navy stripes, gold foil on the
  tanks, glass bubble. Solid, clean silhouette with no one-pixel antennas or loose bits: every pixel
  touches the ship, since pixels are collision.
- The cab must be big enough for a seated 36 px pilot.

### Layout, which the game's loader depends on

- **Body canvas 192 x 128**: 3 columns by 2 rows of 64 x 64 cells. **Every module's pixels stay inside
  its own cell**, since the game loads one picture per module per layer.

  | Cell (col, row) | Module kind | Game name | PNG base name |
  | --- | --- | --- | --- |
  | (0, 0) | rcs | RCS, left | `rcs_left` |
  | (1, 0) | cockpit | Cockpit | `cockpit` |
  | (2, 0) | rcs | RCS, right | `rcs_right` |
  | (0, 1) | tank | Fuel tank, left | `tank_left` |
  | (1, 1) | engine | Main engine | `engine` |
  | (2, 1) | tank | Fuel tank, right | `tank_right` |

- **Mirror-symmetric** about x = 96: the middle column symmetric in itself, the right column the mirror
  of the left.
- **Three layers**, each on the same silhouette: exterior (skin), systems, and frame. Systems and frame
  only exist under the exterior. Thickness 0.4 / 0.2 / 0.225. Systems should read at a glance: the
  seat and controls in the cab, round tanks, plumbing from the tanks to the engine, RCS feed lines.
- Each round tank centered in its cell, since the game puts each tank's fuel at its cell's center.
- **Legs**: two separate part documents, thickness 1.0, each drawn **stowed**, folded against the side
  of its tank, with a hinge, a travel, and a fold the way `lander_mk2.json` has them. Deployed, the feet
  must be the ship's lowest pixels, at least 4 px below the bell, and spread wide enough to stand on
  about 30 degrees of slope.
- **Points**, on the body canvas:
  - the docking hatch at the very top of the bubble, centered on x = 96;
  - the EVA exit on the right side, level with the cab's door, at the silhouette's outer edge;
  - the cockpit point, the middle of the seated pilot.
- **Components:**
  - one per module, of its kind, with its exact pixel regions;
  - each RCS module: a working region (the thruster cluster) and a side nozzle pointing outward, with
    its nozzle point at the mouth;
  - the engine: a working region (the whole bell) and **one tail RCS nozzle on the left of the bell**,
    pointing down. Draw its twin on the right; the game mirrors the left one's data for a centered
    engine, so only the left goes in the JSON;
  - the two tanks, each with a placeholder 3,500 kg of fuel (the game sets the final figure from the
    dry mass);
  - the hatch.

### Numbers to aim for

- Dry mass, body and legs, **6,000 to 8,500 kg**, by the editor's statistics. Reach it with the
  silhouette and materials (foil is light, steel heavy), not the thicknesses.
- Center of mass on the center line, x = 96 ± 0.5, and as low as the look allows. Report it empty and
  with the placeholder fuel.
- Materials are the editor's own (aluminum hull, steel structure, foil, glass, core), set explicitly per
  pixel, never inferred from color.

### Colors

Only the agency palette, with a 1-pixel dark outline (0E0F12) around everything:

| Group | Hex |
| --- | --- |
| Hull | 0E0F12 23262B 3D4148 6B7079 A9ADB3 E8E4DA |
| Gold foil | 5A3E12 9C6B1E D4A23A F2D27A |
| Agency orange | 7A2E12 D9541E F28A3A |
| Agency red | C8302C |
| Agency blue | 1B2E4A 2F5D8C 6FA3C8 |
| Glass | 2A4A55 8FC7CF |
| Telemetry lights | 7FE3D6 6BCB5A F2B33A |

## How to go about it

1. **Exterior silhouette first**, flat colors, with the legs stowed and out, beside a 36 px astronaut.
   Export it at 4x to `exports/moon_hopper/previews/` and send that one path to the game's main session
   for Manny's OK before drawing the other layers. Looks are his call.
2. Draw the rest: exterior detail, systems, and frame for every module, then materials, thicknesses, and
   components. Then the two legs.
3. Check it: no diagnostics on any document, the mass and center within the numbers above, the art
   inside the palette with outlines all round, nothing outside its cell.
4. Export:
   - a bundle for each document, through `asset.export`;
   - previews at 1x and 4x: the exterior; the systems cut away; the frame; the whole ship with legs
     stowed and with legs out beside the 36 px astronaut; and the hopper beside the Mk II;
   - **one PNG per module per layer**, in `exports/moon_hopper/game_pngs/`, each 64 x 64 and
     transparent outside the module: `rcs_left.png`, `rcs_left_systems.png`, `rcs_left_frame.png`, and
     so on for `cockpit`, `rcs_right`, `tank_left`, `engine`, and `tank_right`, plus `leg_left.png` and
     `leg_right.png` at their own size. Twenty files; bringing it into the game is a copy.
5. Write `game/ships/moon_hopper/README.md` like the Mk II's: what's there, the design choices, and the
   statistics. And `moon_hopper.json` with what the documents can't hold:
   - the canvas size and each module's cell;
   - each leg's art position, hinge, travel, and fold, in canvas pixels from the top-left;
   - the hatch, EVA exit, and cockpit points, in canvas pixels;
   - each module's working and nozzle rectangles and nozzle point, in pixels within its own 64 x 64
     cell;
   - the editor's dry mass (body, each leg) and center of mass, empty and with the placeholder fuel.
6. Report back to the game's main session with the preview paths and the statistics.

## After you

The game's builder brings it in once Manny approves: the PNGs into `art/moon_hopper/`, and the numbers
into `data/moon_hopper_design.tres`. Don't do that part. Nothing you make reaches the game until then.
