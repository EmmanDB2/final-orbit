# Brief: design and build the Lander Mk II in the Asset Editor

For a Claude Fable session working in Manny's **Asset Editor**, the sibling project at
`/Users/emmanuelwalters/Projects/Final Orbit Asset Editor`. Written 2026-11-12 by the game's build
session, at Manny's request. Manny (the owner) wants you to design and draw an updated version of
the game's ship, the lander, yourself, pixel by pixel, through the editor. Concept art from image
generators hasn't worked out.

## Before you start

1. You work **only in the Asset Editor**. Read its `AGENTS.md` first and follow it: never edit
   anything in the game project, and ask Manny before reading any game file. This brief carries
   everything the game needs, so you shouldn't have to.
2. Then read the editor's `README.md`, `ASSET_EDITOR_DESIGN.md`, and `docs/CLI.md`, the command line
   you'll build with. Also read `game/ships/lander/README.md` and `game/ships/lander/lander.json`: the
   **current** lander as editor documents, with its numbers. Use it as your reference, and leave
   everything in `game/ships/lander/` as it is.
3. Put your work in `game/ships/lander_mk2/` and its exports in `exports/lander_mk2/`. Ask Manny
   before committing anything to the editor's repo.
4. The editor's own tests must stay green (`docs/CLI.md`, "Verification and handoff"). If the editor
   can't do something you need, tell Manny instead of working around it.

## What the game is

Final Orbit is a 2D pixel-art space game on a folding phone. Its style is "NASApunk": 1960s–70s space
agency hardware, Apollo-era but original. Ships are seen from the side, nose up, at 5 cm a pixel. The
pilot is about 36 px tall. **A ship's pixels are its collision and its damage.** Hits erase them, layer
by layer. Losing enough of a part stops it working, and pieces that come loose fly off as debris. The
game also shows the systems layer in its refuelling screen, cut away, and wherever the skin is
damaged.

## The ship to make

An updated lander that keeps the current one's identity and size, but reads better. You decide the
look within these rules:

- **Keep:** a white and light gray hull with agency orange and blue stripes, gold foil on the tank
  section, glass cockpit windows, one engine bell at the bottom, and two landing legs.
- **Improve:** a clearer cockpit with real windows, distinct RCS thruster clusters, sturdier legs with
  broad foot pads, a better-shaded engine bell, and a systems layer that reads at a glance: round
  tanks, plumbing to the engine, and seats and controls in the cockpit.
- **No fins.** Manny cut nose fins on 2026-11-10 because he didn't like how they look.
- **Silhouette:** solid and clean, with no one-pixel antennas or loose bits. Every pixel touches the
  hull, since the pixels are collision.

### Layout, which the game's loader depends on

- **Body canvas:** 128 x 256, the game's grid of 64 x 64 cells, 2 columns by 4 rows. Each row is one
  pair of modules, left (column 0) and right (column 1). **Every module's pixels stay inside its own
  cell**, since the game loads one picture per module per layer.

  | Row | Module kind | Game name (left, right) |
  | --- | --- | --- |
  | 0 | cockpit | Cockpit, left / right |
  | 1 | rcs | RCS and hull, left / right |
  | 2 | tank | Fuel tank, left / right |
  | 3 | engine | Engine, left / right |

- **Mirror-symmetric** about x = 64, with the right column the mirror of the left.
- **Three layers**, each on the same silhouette: exterior (skin), systems, and frame. Systems and
  frame only exist under the exterior. Thickness 0.4 / 0.2 / 0.225.
- **Legs** are two separate part documents, each drawn **stowed**, folded flat against the tank
  section, with a hinge, a travel, and a fold, the way the current ones are in `lander.json`. The
  current legs are 14 x 44, hinged at about (19, 143) and (106, 143), and travel (-19, 60) and
  (19, 60). Yours can differ, but deployed, the feet must be the ship's lowest pixels, below the
  engine bell, and spread wide enough to stand on about 30 degrees of slope. Leg thickness is 1.0.
- **Points**, on the body canvas (the current ones in brackets):
  - the docking hatch at the very top of the nose, centered [62.5, 22];
  - the EVA exit beside the cockpit [126, 68];
  - the cockpit point [62.5, 58].
- **Components:**
  - one per module, of its kind, with its exact pixel regions;
  - RCS nozzles on both sides of row 1, plus the two tail nozzles beside the bell on row 3, as the
    current lander has them;
  - engine nozzle regions and a nozzle point on each engine half, the bell split down the middle,
    thrusting straight down;
  - tanks of 20,000 kg each, at their module's center;
  - the hatch.

### Numbers to stay near

The game's physics is tuned to the current lander. Its engine force (17,847,305), exhaust velocity
(15,000), RCS torque (173,796,437), RCS translate force (1,784,730), RCS fuel rate (20), and RCS tank
(2,400 kg) stay as they are, so your mass has to stay close:

- dry mass within 10% of 19,491 kg: body 18,390 kg, and legs 554 + 547 kg;
- fuel 40,000 kg;
- center of mass on the center line (x = 64 ± 0.5) and about as low: dry about y = 136, fueled
  about y = 153.

Use the editor's statistics to check. Materials are the editor's own (aluminum hull, steel structure,
foil, glass, core), set explicitly per pixel, never inferred from color.

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

1. **Silhouettes first.** Make two or three outline options as art-only previews, exterior only and
   flat colors, each beside a 36 px astronaut for scale. Show them to Manny and let him pick before
   you draw the rest. Looks are his call.
2. Draw the chosen one: exterior, systems, and frame for every module, then materials, thicknesses,
   and components. Then the two legs.
3. Check it: no diagnostics on any document, the mass and center within the numbers above, and the
   art inside the palette with outlines all round.
4. Export:
   - a bundle for each document, through `asset.export`;
   - previews at 1x and 4x: the exterior; the systems cut away; the frame; the whole ship with legs
     stowed and with legs out, beside the 36 px astronaut; and the current lander beside yours;
   - **one PNG per module per layer, named the way the game names them**, in
     `exports/lander_mk2/game_pngs/`. Each is 64 x 64 and transparent outside the module:
     `cockpit_left.png`, `cockpit_left_systems.png`, `cockpit_left_frame.png`, and so on for
     `rcs_*`, `tank_*`, and `engine_*`, plus `leg_left.png` and `leg_right.png`. That way bringing it
     into the game is a copy.
5. Write `game/ships/lander_mk2/README.md`, like the current lander's: what's there, the design
   choices, and the statistics against the current lander. Also write `lander_mk2.json` with what the
   documents can't hold:
   - each leg's art position, hinge, travel, and fold;
   - the hatch, EVA exit, and cockpit points;
   - each module's working and nozzle rectangles, in pixels within its own 64 x 64 cell.
6. Tell Manny it's ready, with the previews.

## After you

The game's build session brings it into the game once Manny approves: the PNGs into `art/lander/`, and
the numbers into the game's ship design. Don't do that part yourself. Nothing you make reaches the game
until then.
