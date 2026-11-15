# Art brief: station_props (the prop library and the standard hatch)

Written 2026-11-14 by Opus, from Manny's calls, for Gemini through `agy`. The partner of
`kapteyn_3_shells_art.md`, drawn in the same run, in the same drop folder
(`/Users/emmanuelwalters/Projects/Final Orbit Art Drop/kapteyn_3/`), under the same rules for every
`agy` prompt (they're in that brief). This library is shared: every later station and derelict places
props from it.

## What it is

Furniture, machines, decorations, terminals, and the hatch between modules, each a **small sprite of
its own**, so a room is a clean shell with things standing in it, not one flat picture (Manny: "I want
things to look cleaner than before and not like you're walking on a png").

Seen **from straight above**, at **5 cm a pixel**, like the shells. Tall props (lockers, racks,
consoles, bunks) show a 2 to 4 px lip of their front face along their bottom edge, so they read as
standing up; the game draws that lip over the pilot when the pilot is behind the prop (y-sorted), and
the pilot over it when in front. Flat, in the agency palette, no painted light or shade, no
dithering, a 1 px 0E0F12 outline. Screens and lamps in glow colors (FFF3C4, FFB347, F2B33A, 7FE3D6,
6BCB5A), which never darken.

Each prop has a **layer**: `floor` (a decal under the pilot, no collision), `standing` (y-sorted with the
pilot, with a collision footprint), or `overhead` (over the pilot, no collision).

## The sheet

`station_props_sheet.png`: every prop below on a 20 px (1 m) grid, labeled, at 1x, and a 4x preview
`station_props_sheet_4x.png`, with the 37 px standing pilot and the 12 x 16 px top-down pilot beside them
for scale. Each prop also saved alone as `props/<id>.png` at 1x.

| id | Layer | Size, px (m) | Footprint | Terminal / spot | Light |
| --- | --- | --- | --- | --- | --- |
| gig_board | standing, against a wall | 48 x 16 (2.4 x 0.8) | 48 x 12 | `gig_board` | screen, white always, 1.5 m |
| service_terminal | standing, against a wall | 32 x 16 (1.6 x 0.8) | 32 x 12 | `service` | screen, white always, 1.5 m |
| breaker_panel | standing, on a wall | 20 x 8 | 20 x 6 | `power` | a few status pixels |
| directory_sign | standing, on a wall | 24 x 6 | 24 x 4 | none | white always, 1 m |
| med_bed | standing | 42 x 22 (2.1 x 1.1) | 42 x 20 | `wake` on the one the pilot wakes at | none |
| med_cabinet | standing, against a wall | 24 x 12 | 24 x 10 | none | none |
| scanner_arch | overhead, over a bed | 12 x 26 | none | none | a cyan status pixel |
| bunk | standing, stacked double | 42 x 22 | 42 x 20 | none | a warm reading light pixel |
| galley_counter | standing, against a wall | 48 x 16 | 48 x 14 | none | none |
| table | standing, with 2 stools | 28 x 20 | 28 x 18 | none | none |
| locker | standing | 12 x 12 | 12 x 10 | none | none |
| suit_rack | standing, one suit hung on it | 20 x 14 | 20 x 12 | none | none |
| bench | standing | 32 x 10 | 32 x 8 | none | none |
| console | standing, a seat in front | 32 x 18 | 32 x 14 | none (flavor) | screen, white always, 1.5 m |
| comms_rack | standing | 16 x 14 | 16 x 12 | none | blinking status pixels |
| crate | standing | 16 x 18 | 16 x 16 | none | none |
| crate_small | standing | 10 x 12 | 10 x 10 | none | none |
| cargo_cage | standing, a wire cage with crates | 40 x 30 | 40 x 28 | none | none |
| planter | standing, leaves in 6BCB5A, the pot in hull grays | 12 x 14 | 12 x 12 | none | none |
| cable_run | floor, 2 m | 40 x 4 | none | none | none |
| hazard_stripe | floor, 2 m | 40 x 6 | none | none | none |
| grate | floor | 20 x 20 | none | none | none |
| lane_arrow | floor | 10 x 14 | none | none | none |
| pipe_run | overhead, 2 m straight | 40 x 6 | none | none | none |
| pipe_bend | overhead, a corner | 12 x 12 | none | none | none |
| cable_tray | overhead, 2 m | 40 x 8 | none | none | none |
| light_panel | overhead, ceiling light | 24 x 6 | none | none | the fixture itself (set per placement) |
| beam | overhead, a cross beam, 2 m | 40 x 6 | none | none | none |

The planter's leaves are the one non-glowing use of 6BCB5A; the game gives plant props a green ramp.

## The standard hatch

One piece for every joint between modules, seen from above: a short collar tube between two shells,
48 px wide (2.4 m) and 40 px long, with a 32 px (1.6 m) clear opening.

- `hatch_floor.png` (48 x 40): the deck through the collar, hazard stripes at both ends.
- `hatch_walls.png` (48 x 40): the collar's two side walls, 8 px each, solid.
- `hatch_overhead.png` (48 x 40): the frame and lintel over the opening, so the pilot passes under it.
- `hatch_door_left.png`, `hatch_door_right.png` (each 18 x 6): the two leaves of a sliding door that
  meet in the middle of the opening and slide into the side walls; shown closed and open in the sheet.
- `hatch_roof.png` (48 x 40): the collar from outside.
- `docking_ring_roof.png` (64 x 24): the docking ring on the outer end of a collar, with a target
  marking and two amber approach-light spots and a floodlight.
- `capped_plate.png` (48 x 12): a blank hatch plate on a wall, for a capped port.
- The airlock: `airlock_lamp_red.png` and `airlock_lamp_green.png` (4 x 4, glow colors), placed either
  side of each airlock door; the airlock reuses the hatch and doors.

Show the hatch put together, closed and open, with the pilot walking through it, at 4x in
`hatch_4x.png`.

## Exports

- Each prop and hatch piece as its own PNG in the editor's `exports/station_props/game_pngs/`.
- `game/stations/station_props/station_props.json`: per prop its size, layer, footprint rectangle (in
  its own pixels), front-lip height, terminal or spot kind, and any light (offset, reach in m, tint,
  circuit); per hatch piece its size and the door leaves' closed and open offsets.
