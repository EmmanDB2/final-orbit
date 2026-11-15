# Art brief: kapteyn_3, round 2 (props, hatch, and outside at the originals' detail)

Written 2026-11-14 by Opus, from Manny's calls, for Gemini through `agy`, to run when Gemini's quota
resets (about 2026-11-21). It follows `kapteyn_3_shells_art.md` and `station_props_art.md`; their sizes,
layers, ids, exports, and rules for every `agy` prompt all still hold. Only the level of detail changes.

## What Manny said

- On the round 1 concept: "Are station props final or concepts? All of those need work but generally I
  like the station look. Just make sure from the outside it looks detailed like the original."
- The rule, now \[Locked\] in DESIGN.md, "Art direction": "whatever 'bit' (like 16x, 32x, etc) the
  original lander and station were are what we should aim for in every sprite/texture."

So: **the layout, rooms, sizes, and overall look are OK'd; keep them.** Redraw the props, the hatch
pieces, and the outside (roofs, collars, truss, solar wings) at the originals' detail per metre, at
5 cm a pixel. Manny hasn't said more about the props than "need work"; don't redesign what they are,
only bring their detail up.

## The reference

In the drop folder:

- `reference/hub.png`, `comms.png`, `crew_hab.png`, `eva_hab.png`, `suit_room.png`,
  `ship_refueling.png`: the original station's outside, drawn at **10 cm a pixel** (each pixel is two
  of ours, so its features are twice as big in our pixels).
- `reference/ship_lander.png` and `reference/lander/`: the original lander, at 5 cm a pixel, our scale.
- `round2_reference_exterior_3x.png`: the same 12.8 x 8.8 m side by side: the original hub's outside
  (scaled to 5 cm), round 1's concourse roof, and the original lander.

What the originals have, per metre, that round 1 doesn't:

- **Shapes, not boxes:** octagonal and chamfered hulls, a round docking ring with stepped rims, gold foil
  corners, trusses with cross-bracing, handrails, clamps. Round 1's outside is rectangles on a regular
  1 m grid.
- **Panels of different sizes:** seams that break the plating unevenly, with rivets and fastener rows
  along some of them. Round 1 has one even grid of lines.
- **Small machinery everywhere:** vents, valves, hatches, antennas, sensor pods, lights, cable runs,
  RCS-like nubs, labels and stencils. Round 1 has almost none.
- **Colors:** the originals use 15 to 18 palette colors per piece; round 1's roofs use 8 to 11 and most
  props about 5 to 8.
- Measured outline length per square metre is about the same (old station 4.2 to 4.9, round 1's roofs
  4.3 to 5.4), because round 1's grid lines are long and straight; the originals spend the same lines on
  many small features. Aim for the lander's 10 or so per square metre on the outside, made of small
  features, not more grid.

## What each piece lacks

Props (`props/*.png` in round 1):

- Screens (gig board, service terminal, console, directory sign) are flat color stripes: give them UI
  pixels (text rows, a map, gauges), bezels, buttons, keys, and mounting brackets.
- The med bed: no mattress shape, pillow, rails, IV pole, or controls. The bunk: no blanket folds,
  pillow, ladder, curtain, or frame posts.
- The locker (nearly blank at 12 x 12): door seam, vents, handle, label plate, hinge pixels. The suit
  rack: the suit's helmet, gloves, backpack, and hoses read from above.
- Crates and the cargo cage: straps, stencils, corner guards, latches, mesh.
- The galley counter and table: sink, hob, cups, trays, stool shapes.
- The planter: leaves as shapes (not a green square with dots), a pot rim, a grow light.
- Pipes, cable tray, beam, light panel: flanges, valves, brackets, bolts, clips, a lamp housing round
  the glow.
- The comms rack and breaker panel: switch rows, status lights, cable entries, labels.

The hatch (`hatch_*.png`, `docking_ring_roof.png`):

- The side walls are plain white bars: give them frame ribs, pressure seals, control panels by the
  door, and the door pockets.
- The door leaves are plain bars with one orange pixel: edge seals, chevron warning marks, a window
  slit, handles.
- The roof is flat stripes: ribs, clamps, handrails, a light.
- The docking ring is flat: a round ring with petals or latches, guide markings, the approach lights in
  housings, and the floodlight as a fitting.

The outside (`kapteyn_3_exterior.png`): every roof, the collars, the truss, the solar wings (cells,
bus bars, hinges, a gimbal), the antenna, and the nav lights, all to the reference's density.
Keep the window and light positions from `concept_numbers.txt`.

Inside floors and walls were OK'd as they are; where a wall or floor is still one big flat area, give
it the same treatment lightly (seams, access panels, a vent), without moving anything.

## From Manny's play test (2026-11-14)

- **No ceiling light fixtures in the art** ("Hide the light fixtures on the roof and just 'imply'
  there's a light above"). Drop `light_panel`; overhead art has no lamp housings. The game draws only
  the light's pool on the floor. Screens, signs, and status lamps still glow.
- **Light lines up with the room**: each room's fixtures are strips laid on a grid, their long axis at
  right angles to the line you walk in on from the room's main door. Leave floor space for the pools
  in rows: don't put tall props or markings that fight a regular row of light down the room's middle.
- **The docking rings are seen from inside too** ("else the ship looks like it's floating"): while
  the roof is off, each docking ring past its collar stays drawn under the docked ship. Draw the ring so
  it reads as the solid join between the station and a ship, next to the interior, at the originals'
  detail.

## Still true

Flat (no painted light, shade, or highlights: detail is drawn shapes, not shading), no dithering, the
agency palette only, a 1 px 0E0F12 outline, real pixel art from Python scripts, the same sizes and
footprints so the game's data still fits. Then the editor step from `kapteyn_3_shells_art.md`, with
Manny's OK on the flat exterior.

## How Opus runs it

From the drop folder, continuing round 1's scripts (`art_lib.py`, `build_props.py`,
`build_station.py`), so the layout and placements stay exactly as they are:
`agy -p "<prompt>" --sandbox --effort high`, with the prompt pointing at this brief and the reference
folder, asking it to redraw the pieces above, save round 2 beside round 1 with `_r2` in the names, and
make the same 3x and 4x previews, plus a side by side of each prop round 1 vs round 2. Show Manny the
previews; nothing goes into the editor until he OKs them.
