# Brief: the Moon Hopper, a third ship

Written 2026-11-14 by Opus, from Manny's calls, for the builder agent (Sonnet). The art comes first,
from `docs/briefs/moon_hopper_in_asset_editor.md`, through the Asset Editor.

## What and why

The ship table in DESIGN.md "Ships" has a moon hopper: "Nimble, cheap", paid for with "Low-gravity
bodies only". This makes it the third ship in the station's SHIPS tab: a small one-seat craft that flies
well on the moon (60 units/s²) and can't lift off the home planet (200 units/s²) even empty. Manny's calls
on 2026-11-14: a **bubble cab** look (a glass bubble cockpit on a squat body, round tanks on the sides,
a small bell, wide legs), on a **squat 3 x 2 grid**, low and wide so it sits steady on rough ground. It's
also the first ship through the full pipeline: Gemini concept, Asset Editor, game.

## Decided

- Name "Moon Hopper", chip "YOUR SHIP", third in `data/ship_list.tres` after the Lander and the Mk II.
  The Lander stays the starting ship.
- Grid 3 columns x 2 rows of 64 x 64 cells, a 192 x 128 canvas, so the middle of the grid is (96, 64).
  Modules, mirror-symmetric about x = 96:

  | Cell | Kind | display_name | PNG base name |
  | --- | --- | --- | --- |
  | (0, 0) | rcs | RCS, left | `rcs_left` |
  | (1, 0) | cockpit | Cockpit | `cockpit` |
  | (2, 0) | rcs | RCS, right | `rcs_right` |
  | (0, 1) | tank | Fuel tank, left | `tank_left` |
  | (1, 1) | engine | Main engine | `engine` |
  | (2, 1) | tank | Fuel tank, right | `tank_right` |

  Each has `<name>.png`, `<name>_systems.png`, and `<name>_frame.png`, plus `leg_left.png` and
  `leg_right.png`, all in `art/moon_hopper/`, imported with filter Nearest.
- One engine, so losing it loses all thrust (the loader already does this: working engines over engine
  count). One cockpit. The loader already takes a 3-wide grid, a centered engine with no sideways
  thrust, and RCS sides from cell x (explorer, 2026-11-14).
- Numbers come from the hopper's dry mass **D** as the game measures it (body and legs, no fuel, no RCS
  propellant, no cargo), so they hold whatever the art weighs:
  - `fuel_capacity` D / 2 in each tank, rounded to 100 kg, so about D in all and a delta-v of about
    15,000 x ln 2 = 10,400 m/s. That's a round trip from the station to the moon (about 1,200 out,
    2,100 to land straight in, the same back, with gravity losses) with about 2,500 to spare for hops.
  - `engine_force` = 170 x D, rounded to 1,000 N. Empty it's 170 units/s², 0.85 of the home planet's
    pull, so it never lifts off at home, even with a few pixels shot off. Full it's about 85, 1.4 times
    the moon's; with 1 t of cargo about 1.3.
  - `exhaust_velocity` 15,000, the same engine family as the Lander.
  - `rcs_translate_force` = 0.25 x `engine_force` (the Lander's is 0.1): it slides sideways briskly for
    a ship its size.
  - `rcs_torque`: full of fuel with legs up, it turns 1.5 times as fast as the Mk II full. So
    `rcs_torque` = 173,796,437 x 1.5 x (spin resistance of the hopper full / of the Mk II full), from the
    ticket 2 tool. Nimble comes from turning and sliding, since its engine can't outpull the Lander's.
  - `rcs_fuel_rate` = 20 x `rcs_translate_force` / 1,784,730, and `rcs_capacity` = 120 x
    `rcs_fuel_rate`, two minutes flat out like the Lander.
  - `cargo_capacity` 1,000 kg, a third of the Lander's, so some cargo gigs need a bigger ship.
  - `flame_length` 90, for its small bell. Thicknesses 0.4 / 0.2 / 0.225 like the Mk II.
    `safe_impact_speed` 50.
  - Legs: the original Lander's cheaper shocks, `stroke` 6 and `soak_speed` 62.5, `folds` true, so a
    safe landing of about 80. Everything else at its default.
- Points come from the editor's `moon_hopper.json` in canvas pixels; subtract (96, 64) for
  `hatch_point`, `eva_exit`, and `cockpit_point`. Leg `art_position`, `hinge`, and `travel` go in as the
  JSON gives them (canvas pixels from the top-left), like the Mk II's.
- "Cheap" needs nothing built: ships are free in the stand-in hangar, and it shows as small fuel and
  repair bills, since both go by kilograms and pixels.
- Out of scope: ship prices, the ship mall, and whether the moon base sells fuel (still open in
  DESIGN.md; the hopper's delta-v is set so it doesn't need it).

## Tickets

Each is about an evening of work and one commit.

### 1. A centered engine's tail nozzles

- **Does:** a ship with one engine in the middle column shows its forward RCS puffs from both sides of
  the bell, and its tail nozzles work or fail together.
- **Touches:** `scripts/rcs_puffs.gd` (`set_nozzles`), `scripts/ship/ship_body.gd` (`nozzle_share`,
  `nozzle_point`, or wherever the rect is read), `scripts/ship.gd` (the module loop around line 1466
  counts `tail_nozzles`; leave the count per engine as it is).
- **How:** a module is centered when `cell.x + 0.5` equals the grid's column middle (the same
  `columns_middle` as `ship.gd`). Its `nozzle_rect` and `nozzle_point` describe the **left** tail
  nozzle; mirror them across the module's own center (x' = 64 − x − w for the rect, 64 − x for the
  point). Puffs show at both points. `nozzle_share` counts the pixels of both rects together. Ships
  with two engine halves don't change.
- **Check:** all six suites in `tests/` stay green. A throwaway check builds a 3 x 2 test design (the
  Lander's PNGs will do as stand-ins) with a centered engine carrying a nozzle and proves two rear
  points mirrored about x = 0, and that erasing one nozzle's pixels halves the share.

### 2. A ship numbers tool

- **Does:** `godot --headless --path . -s tools/ship_numbers.gd -- res://data/<design>.tres` prints a
  design's dry mass (body, legs), fuel, center of mass empty and full, spin resistance empty and full
  with legs up, delta-v, and thrust over weight at the home planet empty and on the moon full with its
  full cargo.
- **Touches:** new `tools/ship_numbers.gd`, with a header comment.
- **How:** build a `ShipBody` from the design the way `tests/test_ship_body.gd` does; spin resistance
  and `with_fuel` already exist in `ship_body.gd`. Read the two gravities from `data/home_planet.tres`
  and `data/moon.tres`, not typed in.
- **Check:** run it on `lander_design.tres` and `lander_mk2_design.tres`; their dry masses come out
  near 19,491 and 19,386 kg, and thrust over weight at home near 1.5 full.

### 3. Bring in the Moon Hopper

Waits on Manny's OK for the Asset Editor's export.

- **Does:** the SHIPS tab offers the Moon Hopper, and FLY puts it on the station's port.
- **Touches:** copy `exports/moon_hopper/game_pngs/*.png` from the Asset Editor
  (`/Users/emmanuelwalters/Projects/Final Orbit Asset Editor`; read only, never write there) into
  `art/moon_hopper/`; new `data/moon_hopper_design.tres`, modeled on `data/lander_mk2_design.tres`;
  `data/ship_list.tres`; new `tests/test_moon_hopper.gd`.
- **How:** write the design with the editor's JSON for points and rects and placeholder engine
  numbers, run the ticket 2 tool on it for D and spin resistance, then set the numbers by the rules
  above and run the tool again.
- **Check:** all suites green, plus `tests/test_moon_hopper.gd`: all 20 textures load; dry mass within
  the editor's figure ±5%; center of mass on x = 0 ± 0.5 px; thrust over weight at home, empty with no
  RCS propellant, under 0.9; on the moon, full with 1 t of cargo, over 1.25; the hatch pixel is there
  (`has_hatch`); and it docks, the way `tests/test_station.gd` docks a ship, if that's cheap to reuse.

## Art

The whole art brief, for the Asset Editor session, is `docs/briefs/moon_hopper_in_asset_editor.md`,
with Gemini's concept, made with `agy`, in `art/moon_hopper/source/`. Until the export arrives,
tickets 1 and 2 need no art.

## When it's done

- DESIGN.md "Ships": a [Leaning] line for the Moon Hopper after the Mk II's, with its measured dry
  mass, fuel, delta-v, thrust over weight at home and on the moon, cargo, and turning against the
  Mk II, and where its art and data live. Change-log row: "Moon Hopper added as a third ship, the
  first through the Gemini concept → Asset Editor → game pipeline".
- The checker screenshots: the SHIPS tab card; the hopper flying near the station with its legs up;
  landed on the moon near the moon base, legs out, feet on the ground; and lit by the star, once on the
  day side and once in the moon's or planet's shadow. It looks for the outline, the flat art taking the
  star's shading, both tail puffs, and the feet below the bell.
- Tell Manny to try on the Fold: pick the hopper in SHIPS, fly it to the moon, land and hop, and try a
  liftoff from the home planet's surface to feel that it can't.
