# Brief: the new Kapteyn-3 (modular stations, props, planned lighting)

Written 2026-11-14 by Opus, from Manny's calls, for the builder agent (Sonnet).

## What and why

Manny: "let's start work on a new (better) space station as a replacement (to the current) and template
for the future. Better rooms, properly planned lighting, etc", and "I want things to look cleaner than
before and not like you're walking on a png." The new Kapteyn-3 is built from **modules** in data, each
drawn in **layers** (floor under the pilot, walls that are solid, overhead over the pilot, roof outside),
furnished with **props** from a shared library, joined by one **standard hatch** with sliding doors, and
lit by **fixtures placed in data**, each with its own tint and power circuit. It keeps everything the
old station does (docking, gig board, service terminal with REFUEL/REPAIRS/SHIPS, the med bay wake-up)
and its name, callsign, and orbit, so gigs, targets, and saves carry over. DESIGN.md: "Universe
generation" (stations), "Camera, zoom, and landing" (interiors), "Lighting", "Saving and the title
screen", "Ships" (the hangar).

## Decided

- **Scale:** the new station's art is 5 cm a pixel, `art_pixel_size = 1.0`, the same as ships and the
  pilot (Manny: "It's more drawing but it's worth it for details and to maintain our scale"). The pilot
  inside is drawn at its own normal size, so its pixels now match the station's.
- **View:** straight from above, as now. Tall props have a 2 to 4 px front lip; standing props, door
  leaves, and the pilot are **y-sorted** by the bottom of their footprint (the pilot's feet).
- **Modules** (art from `docs/briefs/kapteyn_3_shells_art.md`): `concourse` (hub, GIG BOARD),
  `docking_hub` (collars `dock_w`, `dock_e`, `dock_s`, SERVICE terminal), `med_bay` (the `wake` bed),
  `crew_hab`, `eva_prep` (with the airlock, outer hatch `airlock`), `ops` (breaker panel; west port
  capped for a later ship mall). Modules are drawn in their final orientation; the format allows
  quarter turns but Kapteyn-3 uses none.
- **Ports** have a name and a kind: `inner` (bolted to another module through a hatch), `dock` (ships
  dock here only), `airlock` (EVA out and in only, no docking), `capped` (a blank plate, nothing).
  Kapteyn-3 has three docking ports and one airlock (Manny: "1 Airlock and 3 ports is good. Have the
  airlock connect to an EVA room").
- **Hatches:** every inner joint is the standard hatch piece, 48 x 40 px, between the two shells' ports
  (so bolted modules sit 40 px apart). Its doors slide open over 0.25 s when the pilot is within 32 px of
  the hatch's middle and close 0.6 s after they're farther. The passage is always walkable (the doors
  open before the pilot gets there). Docking collars are the hatch plus the docking ring outside, and
  their doors open when a docked ship's port is boarded.
- **Airlock:** EXIT STATION is offered only at the airlock's outer door; using it runs the cycle: the
  inner door closes, the lamps go red, then amber pulsing, then green, 2.5 s in all, the outer door
  opens and the pilot goes out on EVA from the outer hatch. BOARD STATION from outside is offered within
  90 m of the airlock's hatch (not the docking collars) and runs the cycle backward, ending with the
  pilot in the chamber and the inner door open. BOARD SHIP stays at a docked collar. The airlock's
  status lamps show red while closed to space, green when it's open to the station.
- **Docking** only at `dock` ports, with the same reach, speed, and angle rules.
- **Props** are data (`StationProp`): texture, layer (`floor`, `standing`, `overhead`), footprint
  (standing only; it comes off the walkable floor), front-lip height, spot kind (`gig_board`, `service`,
  `wake`, `power`, or none), and an optional light (offset, reach, tint, circuit). Terminals are props:
  USE TERMINAL works off a prop's spot, as spots do now. `power` (the breaker panel) toggles the station's
  power, offered only when `FeatureFlags.LIGHTS_SWITCH` is on.
- **Fixtures** (`LightFixture`): point, reach in metres, tint (`white`, `warm`, `red`), circuit
  (`mains`, `emergency`, `failing`, `always`), brightness (default 1). Behavior:
  - `mains`: on while powered, dark without.
  - `emergency`: dark while powered; without power it pulses as emergency lamps do now (0.675 + 0.325
    sin over 2.4 s), in its tint (red for every emergency fixture on Kapteyn-3).
  - `failing`: powered, it's on but flickers out for 0.05 to 0.15 s at random every 4 to 10 s; without
    power it sputters as failing lamps do now.
  - `always`: screens, signs, and status lamps; on whatever the power.
- **Tints in palette steps:** `white` steps each pixel down its own ramp, as now. `warm` and `red` map
  lit pixels onto that tint's ramp (warm: FFF3C4, F2D27A, D4A23A, 9C6B1E, 5A3E12; red as the emergency
  lamps do now), where that tint is most of the light at the pixel; outlines, the darkest colors, and
  glow colors keep their own, as with emergency light now. Hard bands, no dither. Plant leaves (6BCB5A
  on a prop marked `plant`) get a lit ramp: 6BCB5A, 2A4A55, 23262B.
- A station whose modules set no fixtures falls back to today's automatic lamps and "every 3rd
  emergency, every 7th failing". The old `StationRoom` format and `data/station_1.tres` keep working
  untouched (for derelicts later); **don't edit `data/station_1.tres`** (it has someone's unstaged
  changes).
- **Outside:** windows (roof-layer rectangles) are drawn in their glass color; while powered the game
  draws window pixels in FFB347 (warm, glowing), without power as dark glass 2A4A55 lit by the star.
  Nav lights: steady red (west) and green (east) glow pixels. Strobe: white FFF3C4 for 0.1 s every
  1.5 s. Approach lights at each docking collar: amber F2B33A while free, green 6BCB5A while a ship's
  docking guide to that port is green, off while a ship's docked there. A floodlight per collar lights
  the hull round it out to 6 m, white, through the hull lighting (as the engine flame does for ships).
  Outside lights go dark without power except nav lights and the strobe (on batteries).
- **Saves:** `VERSION` goes to 4. The station saves its docked port by **name** (`"docked_port":
  "dock_s"`), and a version-3 save's number is upgraded through the design's `legacy_ports`: old 0
  (Comms top) → `dock_s`, 1 (Crew hab right) → `dock_e`, 2 (EVA hab left) → `dock_w`, 3 (Ship refueling
  bottom) → `dock_s`. A name the station doesn't have is dropped (undocked), as an out-of-range number
  is now.
- **Home port and waking:** `StationDesign.home_port` (`dock_s` on Kapteyn-3) replaces the hard-coded
  port 0 in `main.gd`'s `_wake_up`. The pilot wakes standing beside the `wake` bed, facing down, not at a
  hatch. A station with no `wake` spot wakes them at the home port's inner door, as now.
- Names: the station is still "Kapteyn-3", callsign KAPTEYN-3, chip STATION, the same orbit
  (`orbit_altitude` 30000, `orbit_start_angle` -1.556352). The card's rooms list shows module display
  names.
- **Out of scope:** the ship mall, pressure and air per room, damage to the station, rooms unseen until
  entered, NPCs, sitting or sleeping.
- **Don't touch** `scripts/ship.gd`, `scripts/ship/ship_body.gd`, or leg data (the lander session is
  there), `data/station_1.tres`, or the other unstaged files. Stage only your files, by path.
- `scenes/main.tscn` has someone's unstaged changes. The station swap is one line there (the station
  ExtResource path). Stage only that line: make a one-hunk patch with `git diff scenes/main.tscn`, keep
  only your hunk, and `git apply --cached` it. Never stage or revert the rest of that file.

## Tickets

Each is about an evening of work and one commit, logged in `docs/LEARNING_LOG.md`.

### 1. Modules in data, and the layout

- **Does:** a station can be described as modules joined by hatches, with props and fixtures, and the
  layout builds it: images per layer, the walkable floor, named ports, spots, and fixtures. Nothing
  visible changes in the game yet.
- **Touches:** new `scripts/station/station_module.gd` (`StationModule`), `station_port.gd`
  (`StationPort`: name, point, face, kind), `station_prop.gd` (`StationProp`), `prop_placement.gd`
  (`PropPlacement`: prop, position of the footprint's top-left in module pixels, quarter turns),
  `light_fixture.gd` (`LightFixture`), `outside_light.gd` (`OutsideLight`: point, kind `nav_red`,
  `nav_green`, `strobe`, `approach`, `flood`, port name); `station_design.gd` (add `modules`,
  `hatch` textures, `home_port`, `legacy_ports`); `station_module.gd` holds `bolts_to_module`,
  `bolts_to_port`, `own_port` (port names), canvas size, the four layer textures, `floors`, `ports`,
  `props`, `fixtures`, `windows`, `outside_lights`. `station_layout.gd`: a second build path used when
  `design.modules` isn't empty.
- **How:** place modules as rooms are placed now, but with the 40 px hatch gap between bolted ports and
  a hatch piece placed there (rotated to the joint). Compose: a floor image, a walls image, an overhead
  image, and a roof image for the whole station (hatch pieces in each); floor/overhead props are drawn
  into the floor and overhead images; standing props stay separate (a list of {prop, station pixel
  position, rotation}). The walkable mask is the floor rectangles plus each hatch's passage, minus every
  opaque walls pixel and every standing prop's footprint. Room ids per pixel for the light bake come
  from which module's shell holds it; hatches belong to no room. Ports are kept by name with their kind
  and world point; `free_ports` lists only unbolted `dock` ports, and `airlock_ports` the airlocks.
  Spots come from props.
- **Check:** `tests/test_station.gd` gets a synthetic two-module station built in code (tiny generated
  textures): the gap is 40 px, the hatch passage is walkable, a wall pixel and a standing footprint
  aren't, a floor decal is, ports keep names and kinds, a `dock` port is free and the `airlock` isn't in
  `free_ports`, a prop's spot shows up. The old station_1 tests still pass.

### 2. Layered drawing, props, and doors

- **Does:** inside, the pilot walks on the floor, under pipes and lintels, between furniture they can't
  walk through, behind the tops of lockers and in front of their bases, and hatch doors slide open
  ahead of them. The roof fades as now.
- **Touches:** `station_view.gd` (draw order: floor, then a y-sorted node with the pilot, standing props,
  and door leaves, then overhead, then the roof), `pilot.gd` (inside, the pilot joins the y-sorted node
  or sorts against it; inside, it is drawn at its normal size when `art_pixel_size` is 1), a small
  `hatch_doors.gd` for the door leaves.
- **How:** every interior layer and prop uses the interior light shader, looking the light map up by
  station pixel (per-sprite offset uniform or the sprite's transform, whichever works on the Fold's
  renderer). The helmet lamp's "anything that isn't floor" now means not walkable.
- **Check:** suites pass; a throwaway check walks the pilot into a standing prop (blocked), over a floor
  decal (free), and through a hatch (doors open, then close).

### 3. Planned lighting

- **Does:** each fixture lights its room in its tint; LIGHTS OUT leaves only emergency lamps pulsing
  red, failing lamps sputtering, and screens glowing; with power, failing lamps flicker now and then.
  Warm rooms look warm.
- **Touches:** `station_light.gd` (bake), `shaders/interior_light.gdshader`,
  `shaders/palette_light.gdshaderinc` and `scripts/palette_light.gd` (warm and plant ramps),
  `station_view.gd` (`_lamps_now` per circuit; the `power` spot).
- **How:** bake one channel per circuit (mains, failing, emergency, always) into an RGBA light map, and
  per circuit how much of its light is warm and how much red into a second RGBA map pair (or pack them,
  your call), so pulsing and flicker stay uniforms and nothing re-bakes. Per pixel: each circuit's light
  times its live factor, summed by tint; the larger of warm or red takes the pixel to its ramp when it's
  over half the light, else white. Reach in metres is converted by `art_pixel_size`. Keep the old path
  for stations without fixtures.
- **Check:** a throwaway check bakes the synthetic station: a mains white fixture lights its room, not
  through a wall; a warm one gives warm; emergency is dark while powered and red without. Screenshots
  on and off come in ticket 6.

### 4. Ports, airlock, docking, waking, and the save

- **Does:** ships dock only at the three collars; EVA goes out and in through the airlock with its
  cycle; after dying the pilot wakes beside the med bed; a save docked at the old Kapteyn-3 loads docked
  at the new one.
- **Touches:** `station_view.gd` (docking over `dock` ports, `save_state`/restore by name, airlock cycle
  and lamps), `pilot.gd` (EXIT STATION and BOARD STATION at the airlock), `main.gd` (`_wake_up` uses
  `home_port` and the `wake` spot), `scripts/save/save_game.gd` (VERSION 4 and the upgrade step:
  turn a numeric `station.docked_port` into a name through the station's `legacy_ports`; `_upgrade` is
  static, so pass the mapping in or do the number-to-name step in the station's restore, your call, as
  long as a version-3 save loads docked), `tests/test_gigs.gd` (its docked port 0).
- **Check:** suites pass; tests: a v3 save with `docked_port: 3` loads docked at `dock_s`; a ship's hatch
  at the airlock can't dock; wake puts the pilot by the bed.

### 5. Outside lights

- **Does:** from outside, the station's windows glow warm while it's powered and go dark without; nav
  lights and a strobe blink; each collar's approach lights show free (amber), lined up (green), or
  taken (off), and its floodlight lights the hull round it.
- **Touches:** `station_view.gd` (`_light_outside`), the hull light shader and `scripts/ship/hull_light.gd`
  if the floodlight needs point lights there (don't change how ships are lit), the docking guide's state.
- **Check:** suites pass; a throwaway check reads the approach light states as a ship lines up and docks.

### 6. Bring in the art and swap the station

- **Does:** the game's Kapteyn-3 is the new station.
- **Touches:** new `tools/import_station.gd` (reads the editor's JSON for the station and the props and
  writes `data/kapteyn_3.tres` and `data/station_props/<id>.tres`, so later stations come in the same
  way), `art/kapteyn_3/` and `art/station_props/` (PNGs from the editor's exports, imported with
  Nearest filtering), `scenes/main.tscn` (the one line, staged as Decided says), `tests/test_station.gd`
  (Kapteyn-3: 6 modules, 3 free docking ports, 1 airlock, a gig board, a service terminal, a wake bed,
  a power panel, every prop footprint on floor, every port on the art).
- **Check:** suites pass; the checker screenshots docking, the concourse, each room, LIGHTS OUT, and
  the outside lit and in shadow; install on the Fold.

Tickets 1 to 5 use the synthetic station in tests; ticket 6 waits for the art (Manny's OK on the
concept and the flat exterior, then the exports).

## Art

`docs/briefs/kapteyn_3_shells_art.md` (the six modules: floor, walls, overhead, roof) and
`docs/briefs/station_props_art.md` (the prop library, the standard hatch, the docking ring, the capped
plate, the airlock lamps), all top-down at 5 cm a pixel, flat, in the agency palette, with a 1 px
outline. Gemini draws all of it; ticket 6 brings the exports in. Until then, tests use generated
placeholder textures.

## When it's done

- DESIGN.md: replace the first-station bullets (the hub and five rooms) with the new Kapteyn-3, the
  module/prop/hatch/fixture format, the layers, 5 cm pixels for stations (replacing the 2 game px
  exception), the airlock, waking in the med bay, and planned lighting replacing "every third, every
  seventh" for stations with fixtures. Change-log row, [Leaning].
- The checker: the concourse with the pilot behind a locker top and under a pipe, a hatch mid-slide,
  LIGHTS OUT, the crew hab's warm light, the airlock cycle, docking at each collar, and outside lit and
  in a world's shadow.
- Tell Manny to try: dock at each collar, walk every room, use the gig board and service terminal,
  LIGHTS OUT, go out and back in through the airlock, and die to wake in the med bay.
