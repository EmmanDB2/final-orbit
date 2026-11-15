# Art brief: kapteyn_3 (the new station's room shells)

Written 2026-11-14 by Opus, from Manny's calls, for Gemini through the Antigravity CLI (`agy`). Gemini
does all the art: the template, the concept, and the finished asset in the Asset Editor. Sonnet only
brings the exports into the game. Its partner brief is `station_props_art.md` (the prop library and the
standard hatch); both are drawn in the same run so the concept shows the rooms furnished.

## How Opus runs it

The drop folder is `/Users/emmanuelwalters/Projects/Final Orbit Art Drop/kapteyn_3/`. Both briefs are
copied there, with `today/`: the current station's art from the game's `art/station_1/` (outside and
inside of each room), for what **not** to do: one flat picture with the pilot walking over everything.

1. **Template and concept**, from the drop folder: `agy -p "<prompt>" --sandbox --effort high`. Manny
   OKs the concept (through the main session) before anything goes on.
2. **Shells and props in the editor**, from `/Users/emmanuelwalters/Projects/Final Orbit Asset Editor`
   with `--add-dir` for the drop folder: as station-room documents if the editor has them, otherwise as
   building documents with layers. It stops after the flat exterior (the roofs) for Manny's OK.
3. **The rest in the editor**: the layers, checks, exports, and the JSON.
4. **Into the game**: the builder brings the exports in (`docs/briefs/kapteyn_3.md`); the checker tests
   and screenshots it.

Rules for every `agy` prompt (from the cargo pod test):
- Never use RunWorkflow or any built-in Python tool; write `.py` files and run them with `python3`.
- Run each command as one plain command starting with `python3` or `godot`, with relative paths from
  the working folder: no `cd`, no `&&`, `;`, or pipes, no other programs (do `ls`, `mkdir` and the like
  inside Python).
- `python3` here has no PIL: read and write PNGs with `zlib` and `struct`, or with a
  `godot --headless -s` script.
- Draw everything as **real pixel art from a Python script**, pixel for pixel, never from the image
  generator, so the editor reads it back exactly.

## What it is

Kapteyn-3, the agency station in orbit round the home planet, rebuilt as a better station and the
template for every station after it (DESIGN.md, "Universe generation" stations, "Camera, zoom, and
landing" interiors, "Lighting"). Manny: "a new (better) space station ... Better rooms, properly planned
lighting", and "I want things to look cleaner than before and not like you're walking on a png."

Seen **from straight above**, like FTL: the roof comes off while the pilot's inside. At **5 cm a pixel**,
the same as ships and the pilot (Manny: "It's more drawing but it's worth it for details and to
maintain our scale"). The pilot is 1.85 m, 37 px standing; from above about 12 x 16 px (helmet,
shoulders, backpack).

**Built in layers, not one picture.** Each module is four images on one canvas, lined up pixel for
pixel:

- **floor**: deck plates and floor markings (hazard stripes, grates, lane lines), all under the pilot.
  Nothing on it may look solid or tall: if the pilot could not walk over it, it is not floor.
- **walls**: the module's walls and frame. Every opaque pixel here is solid to the pilot. Walls are
  drawn as their top edges seen from above, about 8 px thick (0.4 m), with a 3 px lip of wall face on
  the inner side of walls whose face looks down the screen, so they read as tall.
- **overhead**: pipes, cable trays, beams, ceiling light panels, and door lintels, drawn over the pilot,
  who passes under them. Sparse: a few runs along the walls and over doorways, never covering more than
  about a tenth of a room, and never over a terminal.
- **roof**: the outside, seen from above with the roof on: hull plates, windows, radiators, markings.
  Its outline is the station's solid shape in space.

Furniture and decorations are **props** from the library (`station_props_art.md`), placed in the
concept but drawn as their own sprites, not painted into the floor or walls.

**Cleaner than before:** big calm areas of flat color, detail where things meet (edges, seams, door
frames, corners), floor markings that mean something (stripes at hatches, lane lines to the terminals),
and no noise or scatter for texture.

## The template

`kapteyn_3_template.png`, drawn at 2 screen px per art px:

- a 1200 x 1000 art px canvas with a 20 px (1 m) grid in thin lines and every 100 px a little darker;
- the module footprints below as labeled outlines;
- for scale, at the bottom left, a 37 px pilot standing (side view) and the 12 x 16 px top-down pilot;
- a flat, plain background, and nothing else.

## The concept

`kapteyn_3_concept.png` (interior, roofs off, props placed, all layers together, with the top-down pilot
standing in the concourse) and `kapteyn_3_exterior.png` (roofs on), each at 1x and a 3x preview
(`*_3x.png`), plus `kapteyn_3_layers_3x.png`: the concourse alone, its four layers side by side. Colors
only from the palette below, flat, no gradients, no painted light or shade, **no dithering** (Manny cut
it everywhere, 2026-11-14): the game lights rooms from fixtures and the outside by the star. A 1 px
near-black outline (0E0F12) round everything human-made.

The modules (floor size inside the walls; shell = floor + 8 px walls each side). Positions are a guide on
the 1200 x 1000 canvas; move by whole grid cells if it helps.

| Module | Floor | Shell (x, y, w, h) | Ports | What's in it |
| --- | --- | --- | --- | --- |
| concourse | 12 x 8 m, 240 x 160 | 472, 432, 256, 176 | N ops, S docking hub, W med bay, E crew hab | the agency office: GIG BOARD on the north wall between the N door and a corner, a directory sign, benches, a planter, the agency logo as a floor marking in the middle, lane lines to the doors |
| docking_hub | 10 x 6 m, 200 x 120 | 492, 648, 216, 136 | N concourse; W, E, S docking collars (outer) | SERVICE terminal on the north wall, crates and a cargo cage, hazard stripes at each collar, a fuel line along a wall |
| med_bay | 8 x 5 m, 160 x 100 | 256, 462, 176, 116 | E concourse | two med beds (the wake-up bed nearest the door), a med cabinet, a scanner arch over one bed (overhead), a red cross floor marking |
| crew_hab | 8 x 5 m, 160 x 100 | 768, 462, 176, 116 | W concourse, N eva_prep | two stacked bunks, a galley counter, a table with stools, lockers |
| eva_prep | 6 x 5 m, 120 x 100, plus the airlock 3 x 3 m, 60 x 60, north of it | 788, 238, 136, 184 | S crew hab; N the airlock's outer hatch (EVA only, no docking) | suit racks with suits, lockers, a bench; the airlock chamber with an inner and an outer hatch, each with red and green lamps |
| ops | 10 x 6 m, 200 x 120 | 492, 256, 216, 136 | S concourse; W capped (a blank hatch plate, kept for a later ship mall) | three consoles facing a long window (on the roof layer), comms racks, the breaker panel on a wall |

Between modules is the **standard hatch** from the props brief, 48 px wide, filling the 40 px gap
between two shells, centered on both ports. The three docking collars are that hatch plus the docking
ring on the outside; the airlock is that hatch with a second door.

The outside (roofs): white and light-gray hull plates with panel seams, agency orange and blue stripes
sparingly, gold foil on a few panels, **windows** (canopy-glass pixels, 8FC7CF) where rooms would have
them: the long Ops window, two in the concourse, one in each hab. Off Ops' north side, a truss with two
solar wings (blue 1B2E4A/2F5D8C cells in a gray frame) about 6 m long each, and an antenna mast with a
strobe pixel at its tip. Nav lights: a red pixel cluster (C8302C) at the west end, green (6BCB5A) at the
east. Mark each docking collar's two approach-light spots in amber (F2B33A) and a floodlight spot.

## Layout, for the editor

- One canvas per module, its shell size plus any outside parts, the four layers on it; the hatch,
  collars, and props are their own documents (props brief).
- Ports: each port's outer pixel (the middle of its wall, on the outside) and facing, with its kind:
  `inner` (to another module), `dock`, `airlock`, or `capped`.
- Floors: the walkable floor as rectangles per module (the floor minus walls; props add their own
  footprints in the game).
- Placements (for the game's data, in each module's own pixels): every prop's id, position (its
  footprint's top-left), and quarter-turn rotation; every light fixture (see "Lights" below).
- Windows: rectangles on the roof layer. Outside lights: points with kind `nav_red`, `nav_green`,
  `strobe`, `approach`, `flood`, and the port they belong to.

## Lights (planned, not painted)

Place fixtures in the data, not as painted light: a ceiling light panel is an overhead sprite in the
glow color FFF3C4 (glows and never darkens), and the light it throws is the game's. Per fixture: point,
reach in m, tint (`white`, `warm`, `red`), circuit (`mains`, `emergency`, `failing`, `always`).

| Module | Fixtures |
| --- | --- |
| concourse | 4 white mains panels, reach 4 m; the gig board's screen, white always, reach 1.5 m; an emergency red by each of the 4 doors, reach 2.5 m |
| docking_hub | a white mains work light over each collar, reach 3.5 m (the south one failing); emergency red by each collar and the N door |
| med_bay | 2 white mains panels over the beds, reach 3.5 m; a warm mains desk lamp by the cabinet, reach 1.5 m; emergency red by the door |
| crew_hab | 3 warm mains lamps, reach 3 m, dimmer; warm always night-lights by the bunks, reach 1 m; emergency red by each door |
| eva_prep | 2 white mains panels over the racks, reach 3.5 m; the airlock's status lamps, always (red and green, reach 1 m); emergency red by each door |
| ops | 2 white mains panels, reach 3 m, dim; each console's screen, white always, reach 1.5 m; a failing white lamp over the breaker panel, reach 2.5 m; emergency red by each door |

## Colors

The agency palette only (DESIGN.md, Art direction), lightest of each ramp first, for flat fills (the
game only ever darkens, down each ramp):

- hull: E8E4DA, A9ADB3, 6B7079, 3D4148, 23262B, 0E0F12
- gold: F2D27A, D4A23A, 9C6B1E, 5A3E12
- orange: F28A3A, D9541E, 7A2E12; red: C8302C
- blue: 6FA3C8, 2F5D8C, 1B2E4A
- glass: 8FC7CF, 2A4A55
- glow (never darkens, for lights and screens only): FFF3C4, FFB347, F2B33A, 7FE3D6, 6BCB5A

Floors darker than walls, so walls read: deck plates 6B7079 with 3D4148 seams and 23262B grates;
wall tops E8E4DA and A9ADB3; hazard stripes D9541E or F2D27A on 23262B. Stations can't be damaged yet,
so color doesn't set any mass here.

## Exports

- Per module, in the editor's `exports/kapteyn_3/game_pngs/`: `<module>_floor.png`,
  `<module>_walls.png`, `<module>_overhead.png`, `<module>_roof.png`, all on the module's canvas,
  transparent where empty.
- `game/stations/kapteyn_3/kapteyn_3.json`: each module's canvas size, ports, floor rectangles, prop
  placements, fixtures, windows and outside lights, in that module's pixels; and how the modules bolt
  (which port to which).
- Previews at 1x and 3x: the whole station inside with props and the pilot, the outside, and the
  concourse's layers apart.
