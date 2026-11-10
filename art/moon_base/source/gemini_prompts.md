# Moon base: Gemini prompts

The moon version of the launch base: the same three buildings, built by the same agency for an airless
moon at 0.3 g. One image each. For every prompt, attach three images:

1. `moon_reference.png` (this folder): the astronaut, the colors, the lander, and a plan of the whole
   base at true scale.
2. That building's template (this folder): `assembly_template.png`, `tower_template.png`, or
   `mission_control_template.png`.
3. The same building at the home planet's launch base, for the style (in `art/launch_base/source/`):
   `vehicle_assembly.png`, `launch_pad.png`, or `mission_control.png`.

Then paste the prompt. Save the results here as `assembly.png`, `tower.png`, and `mission_control.png`.

If a result comes back with the outside and the cutaway not matching, ask for them as two images:
first "Draw only the OUTSIDE", then "Draw only the CUTAWAY of the same building", attaching the first
result to the second. If it copies the third image too closely, say "Make it look built for the moon:
sandbags on the roof, rounded sealed walls, gold foil" and try again.

---

## 1. Hangar (vehicle assembly)

Create a pixel-art building for a 2D side-view sci-fi game: the vehicle assembly hangar of a 1970s
NASA-style base on an airless gray moon. Off-white panels, gray steel, orange and blue agency stripes,
gold foil insulation, and chunky, readable shapes.

The third attached image is the assembly building at the same agency's base on its home planet. Match
its style exactly: the same pixel size, outline weight, colors, and level of detail. But this is the moon
version, so give it the shape and details described here, not that building's.

The second attached image is the template to fill. It has two panels side by side: OUTSIDE and CUTAWAY.
Both show the same building at the same size, standing on the same white ground line.

OUTSIDE: a tall hangar with a curved, arched roof, built to shelter ships from dust, sun, and tiny
meteorites. It isn't airtight: there's no air on the moon to keep in.

- The arched roof is covered in a thick layer of stacked gray sandbags filled with moon dust, as
  shielding. Keep the roof and sandbags inside the template's box.
- A huge segmented vehicle door at the right end, where the tall dashed box is, running nearly the full
  height, with orange-and-white warning stripes on its frame.
- A small door at the lower left, where the small dashed box is.
- A wide orange and blue stripe across the wall, with no lettering.
- A white radiator panel on one side of the roof, a few warning lights along the roof edge, and gold
  foil wrapped round the pipes on the outside walls.

CUTAWAY: the same building with its front wall removed, so the inside shows. The outline, roof, side
walls, and floor stay exactly as in OUTSIDE, and only the front wall is gone.

- One tall bay. On the floor where the box marked SHIP is, a low ship assembly cradle with clamps and
  hoses. Leave the space above the cradle empty: no rocket or ship.
- An overhead gantry crane rail under the roof, spanning the bay, with a hook hanging from a trolley.
- On the left, two catwalks with railings at the heights of the dashed lines, joined to the floor by a
  ladder where the box marked LADDER is.
- Where the box marked BOOTH is, on the upper catwalk: a small sealed control booth, a boxy pressurized
  room with rounded corners, a round-cornered hatch, a thick window looking out over the bay, and a
  console inside.
- Tool racks, parts crates, and gas bottles along the back wall on the floor.
- The vehicle door, seen from inside, is closed.
- Floors and catwalks are solid, flat, continuous slabs, so a person could walk along them.

Size: the off-white box marked PILOT in the template is one astronaut standing, 1.85 m tall. Draw an
astronaut there, in the style of the attached one, standing on the ground line, as a size reference.
The small door is a little taller than the astronaut.

Pixel-art rules:

- Seen exactly from the side, straight on, like an architectural elevation: no perspective, and no top
  or side faces showing.
- True pixel art on a crisp, uniform pixel grid: every pixel is a clean square block of the same size.
- No anti-aliasing, blur, gradients, glow, soft shadows, or noise. Light comes from the upper left.
- Use only these colors: #0E0F12, #23262B, #3D4148, #6B7079, #A9ADB3, #E8E4DA, #D9541E, #F28A3A,
  #7A2E12, #C8302C, #1B2E4A, #2F5D8C, #6FA3C8, #5A3E12, #9C6B1E, #D4A23A, #F2D27A, #2A4A55, #8FC7CF,
  and for small indicator lights only #6BCB5A and #F2B33A.
- Every shape has a 1-pixel near-black outline (#0E0F12).
- The background is flat solid magenta (#FF00FF) everywhere. Draw no ground below the line, and no
  sky, stars, shadows on the ground, text, labels, numbers, or borders.
- The template's white boxes, dashed lines, and labels are guides only. Follow them, but don't draw
  them.

---

## 2. Landing and service tower, with its pad and tanks

Create a pixel-art structure for a 2D side-view sci-fi game: the landing and service tower, propellant
tanks, and landing pad of a 1970s NASA-style base on an airless gray moon. Gray steel, off-white panels,
orange and blue agency stripes, gold foil insulation, and chunky, readable shapes.

The third attached image is the launch tower and pad at the same agency's base on its home planet.
Match its style exactly: the same pixel size, outline weight, colors, and level of detail. But this is
the moon version, so give it the shape and details described here, not that tower's.

The second attached image is the template to fill. This one has a single view, since the tower is open
steelwork.

TOWER, in the tall box:

- A light, open steel truss tower of thin gray girders, more delicate than a tower on a planet, since
  gravity here is weak. Orange-and-white stripes near the top.
- A ladder running up inside it, an open elevator platform, and small platforms every few floors.
- Red warning lights, and an antenna and a floodlight on top.
- Two swing arms reaching right toward where the ship stands, both ending at the left side of the
  dashed box marked SHIP STANDS HERE:
  - At the line marked CREW ARM: a covered walkway ending in a small sealed boarding room, boxy with
    rounded corners and a round-cornered hatch facing the ship.
  - At the line marked FUEL ARM: a thinner arm carrying fuel hoses wrapped in gold foil.

TANKS, in the small box at the left, on the ground:

- Two round propellant tanks on a low steel frame, white with gold foil bands, joined by pipes that run
  along the ground into the foot of the tower.

PAD, in the long flat box along the ground:

- A thick, flat landing slab of dark gray moon dust melted and fused into stone, with a painted orange
  landing mark.
- Small lights along its edge. No flame trench or vent.
- The dashed box marked SHIP STANDS HERE stays empty magenta: no rocket or ship.

Size: the off-white box marked PILOT in the template is one astronaut standing, 1.85 m tall. Draw an
astronaut there, in the style of the attached one, standing on the ground line, as a size reference.

Pixel-art rules:

- Seen exactly from the side, straight on, like an architectural elevation: no perspective, and no top
  or side faces showing.
- True pixel art on a crisp, uniform pixel grid: every pixel is a clean square block of the same size.
- No anti-aliasing, blur, gradients, glow, soft shadows, or noise. Light comes from the upper left.
- Use only these colors: #0E0F12, #23262B, #3D4148, #6B7079, #A9ADB3, #E8E4DA, #D9541E, #F28A3A,
  #7A2E12, #C8302C, #1B2E4A, #2F5D8C, #6FA3C8, #5A3E12, #9C6B1E, #D4A23A, #F2D27A, #2A4A55, #8FC7CF,
  and for small indicator lights only #6BCB5A and #F2B33A.
- Every shape has a 1-pixel near-black outline (#0E0F12).
- The background is flat solid magenta (#FF00FF) everywhere. Draw no ground below the line, and no
  sky, stars, shadows on the ground, text, labels, numbers, or borders.
- The template's white boxes, dashed lines, and labels are guides only. Follow them, but don't draw
  them.

---

## 3. Mission control (the hab)

Create a pixel-art building for a 2D side-view sci-fi game: the mission control hab of a 1970s
NASA-style base on an airless gray moon, which houses the mission computer. Off-white panels, gray
steel, orange and blue agency stripes, gold foil insulation, and chunky, readable shapes.

The third attached image is the mission control building at the same agency's base on its home planet.
Match its style exactly: the same pixel size, outline weight, colors, and level of detail. But this is
the moon version, so give it the shape and details described here, not that building's.

The second attached image is the template to fill. It has two panels side by side: OUTSIDE and CUTAWAY.
Both show the same building at the same size, standing on the same white ground line.

OUTSIDE: a low, wide, two-story sealed hab that holds air inside, so it looks like a pressure vessel:
thick off-white walls with rounded corners, heavy riveted seams, and blue and orange stripes.

- A heavy round-cornered airlock hatch at the lower left, where the dashed box is, with a wheel handle
  and a small status light beside it.
- Small, thick, round-cornered windows along the upper floor, with larger ones at the left end, facing
  the landing pad.
- The roof is covered in a layer of stacked gray sandbags filled with moon dust, as shielding.
- On the roof: a satellite dish aimed up and to the left, a comms mast, a solar panel on a short mast,
  and a white radiator panel.

CUTAWAY: the same building with its front wall removed, so the inside shows. The outline, roof, side
walls, and floors stay exactly as in OUTSIDE, and only the front wall is gone.

- Ground floor: behind the outer hatch, a small airlock where the box marked AIRLOCK is, with an inner
  hatch at its right side. Then a suit room with lockers holding spare spacesuits and a bench, where the
  box marked LOCKERS is.
- Upper floor: the mission control room. A wide bank of consoles with screens, dials, and blinking
  lights, where the box marked MISSION COMPUTER is, facing the windows at the left end (WINDOWS).
- A ladder on the right, where the box marked LADDER is, climbing from the ground floor through a hatch
  to the upper floor.
- The roof slab above, with the sandbags and dish on top.
- Floors are solid, flat, continuous slabs, so a person could walk along them.

Size: the off-white box marked PILOT in the template is one astronaut standing, 1.85 m tall. Draw an
astronaut there, in the style of the attached one, standing on the ground line, as a size reference.
The hatch is a little taller than the astronaut, and each floor is about one and a half astronauts tall
inside.

Pixel-art rules:

- Seen exactly from the side, straight on, like an architectural elevation: no perspective, and no top
  or side faces showing.
- True pixel art on a crisp, uniform pixel grid: every pixel is a clean square block of the same size.
- No anti-aliasing, blur, gradients, glow, soft shadows, or noise. Light comes from the upper left.
- Use only these colors: #0E0F12, #23262B, #3D4148, #6B7079, #A9ADB3, #E8E4DA, #D9541E, #F28A3A,
  #7A2E12, #C8302C, #1B2E4A, #2F5D8C, #6FA3C8, #5A3E12, #9C6B1E, #D4A23A, #F2D27A, #2A4A55, #8FC7CF,
  and for small indicator lights only #6BCB5A and #F2B33A.
- Every shape has a 1-pixel near-black outline (#0E0F12).
- The background is flat solid magenta (#FF00FF) everywhere. Draw no ground below the line, and no
  sky, stars, shadows on the ground, text, labels, numbers, or borders.
- The template's white boxes, dashed lines, and labels are guides only. Follow them, but don't draw
  them.
