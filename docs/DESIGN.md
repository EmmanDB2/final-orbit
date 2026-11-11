# Final Orbit — Game Design Doc

Nov 4, 2026 · @Emmanuel

## How to use this doc

This is a living doc: every decision carries a status tag, so anything can be added, changed, or cut without rewriting the rest.

- **\[Locked\]** Decided. Build against it. Changing it needs a reason and a change-log line.
- **\[Leaning\]** Current best answer. Fine to build a prototype on, expect tweaks.
- **\[Open\]** Undecided. Lives in Open questions until resolved.
- **\[Cut\]** Removed. Kept in the parking lot with the reason, so it is not re-argued from scratch.

Rules for keeping it flexible:

- One idea per bullet, so a single line can change status without touching its neighbors.
- Systems talk through named interfaces (see Tech), so the doc and the code can swap one system without rewriting others.
- New ideas go to the parking lot first, then get promoted into a section and a tier.

Change log (newest first):

| Date | Change |
| --- | --- |
| 2026-11-10 | Auto-hide turned off on Manny's call: only the tab at the left hides and shows the controls. The gig tracker folds only when tapped, apart from the controls. Gig board rows keep one title size, with the pay on the second line when titles run long. The tap that opens a board can no longer take a gig \[Leaning\] |
| 2026-11-10 | Survey gigs built: a spot on the planet's dry land or the moon; land within 80 m, SCAN SITE for 8 seconds while landed, and the data uplinks and pays once Kapteyn-3 or a base is in line of sight; losing the ship first loses the data \[Leaning\] |
| 2026-11-10 | Active-gig tracker built from Manny's mockup, top left under the readouts, folding into an orange GIG tab; taking a gig makes its destination the target \[Leaning\] |
| 2026-11-10 | Cargo delivery on the context menu: arriving offers UNLOAD CARGO from the cockpit, pointing at the pad or the docking port, as a second row under BOARD STATION when docked; unloading pays \[Leaning\] |
| 2026-11-10 | Gig board built from Manny's mockup: USE TERMINAL at Kapteyn-3's gig board or a base's mission computer opens it over the flight, with gigs on the left and the picked one's pay, destination, cargo, hazards, description, and requirements on the right, and ACCEPT GIG \[Leaning\] |
| 2026-11-10 | Gigs begun, on Manny's call from his mockups: cargo and survey gigs first, picked at gig boards; cargo rides in the cockpit and weighs; credits start at 0 and pay on delivery; one active gig at a time; the station is renamed Kapteyn-3. Ticket 1 built: gig types as data, boards filled the same way for the same seed, requirements and hazards, loading, and payout \[Leaning\] |
| 2026-11-10 | Context menu labels move to stay out of the way, on Manny's call: they keep off the ship, the pilot, and where the pilot's heading, going above when beside won't do, and the line to the thing runs straight or diagonal like the hold card's \[Leaning\] |
| 2026-11-10 | In-world context menus replace the action button, from Manny's mockup: corner brackets on the thing itself (the cockpit for BOARD SHIP, a hatch, a door, a console), a dotted line out to a label with a diamond, and a tap on the label. The same menu serves ships, stations, doors, and boards, a row per choice \[Leaning\] |
| 2026-11-10 | Nose fins for the lander cut, on Manny's call after seeing them drawn in the asset editor: he didn't like how they look. The lander's tilt in air stays as piloting \[Cut\] |
| 2026-11-10 | STAB measures along the path against the turning ground inside a body's landing zone, like the speed readout and dial, so against the path is what a landing burn cancels and the nose stays in the airflow; higher up, against the body as before. The forecast holds the same. Manny's call. The lander's tilt in air is left as piloting for now, and Manny will give it fins as a module from the asset editor \[Leaning\] |
| 2026-11-10 | Landing prediction built: while the ship's on its way down, a forecast of the landing with no more burns is flown on another thread four times a second, with the same air as the real flight. The path line shows it through the air, drawn against the turning ground, with the landing zone on the ground and a SAFE, HARD, CRASH, or BURN-UP label and speed at its end, and the comms line reads the same. Gravity interface gains `predict_descent`, `get_hold_headings`, `get_body_spin`, and `get_entry_altitude`, since the forecast flies through the interface and holds STAB's headings the way the ship does \[Leaning\] |
| 2026-11-10 | Aerodynamics built: the air pushes on each piece of the outline that faces it, giving drag, lift, a turning force about the live center of mass, and spin damping, with heat taken from the hottest piece. The RCS loses to the air deep and fast, and the comms line says AIR OVERPOWERING RCS. The old one-box drag stays behind `FeatureFlags.AERODYNAMICS`. **The lander doesn't fall engine-first by itself as hoped:** its shape settles it tilted 46 to 69 degrees off engine-first, and what to do about that is a new open question, along with which frame STAB holds in air \[Leaning\] |
| 2026-11-10 | Aerodynamics and landing prediction decided, on Manny's call, to be built by Fable from `docs/briefs/aerodynamics_and_landing_prediction.md`: forces on each exposed part of the outline, with stability, lift, and spin damping coming from shape and mass rather than being chosen; the RCS kept at its strength, so the air overpowers it when you come in too fast; and a predicted path through the air that flies hands-off, with a landing zone between least and most drag and a SAFE, HARD, CRASH, or BURN-UP label at the end \[Leaning\] |
| 2026-11-10 | Time warp built, on Manny's call: 0.5, 1, 2, 5, and 10× any time, and 50 and 100× while coasting, which drop back to 10× when the coast ends. A tap on the fast forward button by the clock steps up, holding it resets to 1×, and a tap on the readout steps down. Out of the parking lot \[Leaning\] |
| 2026-11-10 | HUD rearranged to Manny's mockup: the top bar splits into a readouts box and a clock box with the middle open, the pad moves bottom left, ENGINE, ASST, STAB, the lever, and new F and R gauges go bottom right, EVA and LEGS sit side by side over a restyled dial with a spin readout, and the auto-hide tab is always there at the left, tapped to hide or show \[Leaning\] |
| 2026-11-10 | BURN becomes ENGINE, an on/off switch, on Manny's call (his brother's idea): the throttle sets how hard it pushes and 0 idles, so long burns are hands-free. It cuts out on touchdown, docking, the pilot leaving, or running dry. W flips it on the Mac \[Leaning\] |
| 2026-11-10 | The RCS has its own propellant tank, apart from the engine's fuel, on Manny's call: 2,400 kg on the lander, two minutes flat out. Empty, the ship can't turn or translate. Docking and landing at home refill it \[Leaning\] |
| 2026-11-10 | A landed ship that settles or tips against a building slides along the ground out of it, instead of leaning into it \[Leaning\] |
| 2026-11-10 | Moon base built from Manny's asset editor sprites and placed on the moon's near side, 190 m from the point facing the planet: hangar, tanks and service tower, a pad set flush into the ground, and a sealed two-floor hab, all walk-in like the launch base. A building can now be marked not solid, for pads \[Leaning\] |
| 2026-11-10 | Launch base art replaced with the cleaned-up sprites from Manny's asset editor, used at 5 cm a pixel, so the buildings are about a fifth smaller, with doors about the pilot's height. Floors, ladders, doors, terminals, and the layout re-marked to match; the old slicer is gone \[Leaning\] |
| 2026-11-10 | Moon base planned, on Manny's call: the launch base's three buildings again, built for an airless moon, with sandbagged roofs, a sealed hab entered through an airlock, a lighter tower with propellant tanks, and a pad of fused moon dust. Its pad is the moon's landing pad for cargo \[Leaning\] |
| 2026-11-10 | Walking into the launch base's buildings: ENTER at a door fades the front wall off, floors and ladders inside, terminals, and EXIT \[Leaning\] |
| 2026-11-10 | Launch base buildings solid to ships, except the tower's swing arms; the pilot walks in front of them \[Leaning\] |
| 2026-11-10 | Launch base placed on the home planet on level ground made by the physics core, with its pad flush with the ground, a dot from far out, and a card, focus, and target \[Leaning\] |
| 2026-11-10 | Launch base art cut into sprites at 5 cm a pixel, scaled by its doors: assembly building, tower and pad, and mission control, each building's outside and cutaway lined up on one canvas \[Leaning\] |
| 2026-11-10 | First place on a world planned, on Manny's call: a launch base on the home planet, with an assembly building, a launch and landing tower beside a pad, and mission control with the mission computer, drawn from Gemini art as outsides and cutaways at the pilot's scale. It comes ahead of the moon's landing pad \[Leaning\] |
| 2026-11-10 | Scale set by the pilot, on Manny's call: one world unit is 5 cm, since the 1.85 m pilot is 37 px. Readouts show real units, with the unit beside each name in the top bar, replacing 1 unit as 1 m \[Locked\] |
| 2026-11-10 | On EVA the 3D pilot floats upright, seen from above, and leans into a push until nearly flat, seen from the back, on Manny's call. Turning keeps it upright. The far-side shading is only for the side view \[Leaning\] |
| 2026-11-09 | EVA steers like the ship, on Manny's call: rotate buttons turn the pilot and letting go stops it, the arrows push relative to the pilot, and a drag points them, replacing arrows by the screen. The 3D pilot is seen from the back on EVA, and the jetpack puffs cold gas from the pack's corners like the ship's RCS, replacing flames \[Leaning\] |
| 2026-11-09 | The 3D pilot is drawn in the game, on for now so Manny can try it: rendered live at 1 px per 5 cm, snapped to the palette, outlined round the outside and between overlapping parts, the far side a shade darker, and posed by code. Seen from the side on worlds and in space, and from above at the station's pixel size inside \[Open\] |
| 2026-11-09 | The 3D pilot's model is built: 1.85 m tall, 19 joints, 7 attachment points, about 1,900 triangles, in the agency palette. Its visor wraps round to the sides of the helmet, wider than planned, so it shows from the side the way the sprite's does. The renderer, the shader, and the animation are still to come \[Open\] |
| 2026-11-09 | Trying a low-poly 3D pilot, rendered live at the pilot's pixel size and snapped to the palette with an outline, against the sprite sheets. If it wins, it replaces the [Locked] top-down sprite line, and one model gives every view \[Open\] |
| 2026-11-09 | Walking on worlds built: EVA from a landed ship puts the pilot on foot beside it, seen from the side. They walk, jump, and ride the ground as the world turns. The jetpack fires on a second press in the air, too weak to fly against either world's gravity. A soft EVA landing puts them on foot, and BOARD SHIP works anywhere along a landed ship's width \[Leaning\] |
| 2026-11-09 | Side-view pilot sheet cut from Manny's Gemini sheet: 29 frames, about 36 px tall, in the suit's palette colors only \[Leaning\] |
| 2026-11-09 | Places on worlds decided: outposts are walked into from the side with the front wall cut away, not menus; menus are what terminals show; built in stages starting with the pilot walking on worlds, which needs a side-view sprite sheet \[Leaning\] |
| 2026-11-06 | App icon set. Orbit lines are blue and gravity rings gold. Rotate moves to the D-pad's corners, replacing the switch. The pilot uses Manny's animated sprite sheet \[Leaning\] |
| 2026-11-06 | EVA and station boarding built ahead of gigs, on Manny's call: jetpack, walking inside with the roof off, airlocks, boarding from a docked ship, and a gig board terminal to walk up to. Moves those parts of Tier 2 and Tier 3 up, behind feature flags \[Leaning\] |
| 2026-11-06 | UI reworked from Manny's mockups: thin outlined instruments with no plates, one layout for both screens, a comms line along the bottom with a log, a FLIGHT menu, the TRANS / ROT switch everywhere, ASSIST on the button, and a card on holding a finger on anything, with SET TARGET and FOCUS. Tap still focuses. The home system is named KEPLA-2 \[Leaning\] |
| 2026-11-06 | Tap anything to focus the camera on it at every zoom, replacing the center depending only on the zoom. The dossier card loses the tap and needs another gesture \[Open\] |
| 2026-11-06 | Camera turns so down is down from the Orbit view in, and stays a fixed map farther out, replacing the fixed camera \[Leaning\] |
| 2026-11-06 | Docking built, with the ship's nose as the hatch, free refueling and repair, and a speed readout against the station. The station now turns with its orbit, replacing holding still \[Leaning\] |
| 2026-11-06 | Station made solid: the ship bounces off it, and takes damage above its safe speed \[Leaning\] |
| 2026-11-06 | First edge marker, for the station, with its label beside the dot when zoomed out \[Leaning\] |
| 2026-11-06 | Home Station in orbit: on rails with no gravity, holding still, with its room layout and start position \[Leaning\] |
| 2026-11-06 | Station art cut into clean sprites by a new tool, with stations drawn at 2 game pixels per art pixel as a third exception to the fixed pixel size \[Leaning\]. All 25 listed agency colors now in the palette data |
| 2026-11-06 | Engine flame now drawn by code from throttle, air, and damage, replacing the sprite. Procedural burn animation leaves the parking lot \[Leaning\] |
| 2026-11-06 | Re-entry rebuilt: the hull visibly heats from the hot side, hot air hugs its real outline, and flames stream off its edges, replacing a fixed arc \[Leaning\] |
| 2026-11-06 | Surfaces rebuilt up close: a pixel grid fixed to the ground, a seeded skyline that ships really collide with, new detail at each zoom, a cross-section of the ground, dithered sky bands, surface props by biome, engine dust, a ship shadow, and far-off mountains \[Leaning\] |
| 2026-11-06 | Planets reworked to read as pixel art: flat colors, clean clusters, and bigger pixels from far out, which is a second exception to the fixed pixel size \[Leaning\] |
| 2026-11-06 | Planets redrawn: seas and wandering coasts, day and night from the real star, clouds, ice at the pole, and craters on the moon \[Leaning\]. The home planet now starts with the ship on its day side. Landing on water is added to the parking lot |
| 2026-11-06 | Connectivity now goes by pixels actually touching instead of 3 x 3 cells, so loose pixels drop off instead of floating \[Leaning\] |
| 2026-11-06 | Inside layers built from Manny's frame and systems drawings: damage strips the skin first, then the systems, then the frame. Material strengths halved so a crash costs about what it did, with the skin going first \[Leaning\] |
| 2026-11-06 | Landing legs built, with a LEGS button. They swing down, take harder landings, and can break off, leaving the ship leaning. The ship now stands on its feet with them down, which replaces always resting on the bell \[Leaning\] |
| 2026-11-06 | Ships are now built from one PNG per module, placed by the ship's data file, with working pixels marked so damage knows the real parts. Engines weaken as the bell goes instead of working or not \[Leaning\] |
| 2026-11-06 | Damage reads better: hits spread across the art with a glowing edge instead of blinking out, every lost pixel flies off as a longer-lived spark, and chunks crumble into sparks instead of vanishing \[Leaning\] |
| 2026-11-05 | Damage built: pixels are collision, hits and heat erase them, pieces break off as debris with their own orbits, lost modules change how the ship flies, and tanks leak. Losing the cockpit loses the ship. RESTART added. CRASH now starts at 250 units/s instead of 500 \[Leaning\] |
| 2026-11-05 | The lander's fuel doubled to 40 t, with engine and RCS raised so a full tank feels the same \[Leaning\] |
| 2026-11-05 | Re-entry heat built, shown as hot gas around the ship. It does no damage yet \[Leaning\] |
| 2026-11-05 | Atmospheres built: the home planet has air that moves with its spin, drag that depends on the ship's shape and mass, and a stepped glow that becomes the sky up close \[Leaning\]. The path line ignores the air for now |
| 2026-11-05 | Planets and moons spin. Landing now means matching the ground's speed, and launching with the spin gives a boost \[Leaning\] |
| 2026-11-05 | Real star built: it's body 0, with the planet on rails around it and the moon on rails around the planet. Star tint now comes from it. SYS shows a planet and its moons, and a second press shows the whole system \[Leaning\]. Reaching the star takes about 40 minutes without time warp |
| 2026-11-05 | The ship sprite has no minimum size: it stays at true scale until the icon takes over at the Orbit view \[Leaning\] |
| 2026-11-05 | RCS puffs built, firing from the side nubs and tail nozzles on the art \[Leaning\] |
| 2026-11-05 | Time warp put in the parking lot for now |
| 2026-11-05 | RCS pad and translation built. The inner screen's right panel widens to 140 game pixels to fit 44-pixel buttons, and its pad needs no ROT / TRANS switch, since it shows rotate and translate at once. The cover screen's panel only rises as far as its controls need \[Leaning\] |
| 2026-11-05 | Fuel built: it has mass and burns off, and the main engine and RCS both use it, so ASS and STAB cost fuel. Lander numbers set \[Leaning\]. Fuel gauge and delta-v readout added. Landing on the planet refills the tanks until stations exist \[Leaning\] |
| 2026-11-05 | Tier 0 finished and Tier 1 started. Module grid set at 64 x 64 px \[Leaning\]. Ships are defined in data, with mass, center of mass, and spin resistance measured from pixels. Materials go by art color \[Leaning\] |
| 2026-11-05 | The view center now follows the zoom directly, so zooming has no jumps. The ship icon only shows at the Orbit view and farther. Closer in, the sprite scales to true size, which is an exception to the never-change-pixel-size rule, at Manny's request, so the zoom reads as one clean move \[Leaning\] |
| 2026-11-05 | First real UI built for Tier 0: top bar, throttle lever, BURN under its cover, ASS and STAB buttons, zoom buttons, heading dial, drag to point, and auto-hide with side tabs. Replaces the throwaway touch controls and rough readout. Smooth zoom built \[Leaning\]. Gravity interface gains `get_body_velocity` and `get_orbit_apsides` |
| 2026-11-05 | STAB picks its direction automatically, from whichever is closest to where the nose points \[Leaning\] |
| 2026-11-05 | Clean landing limit lowered from 150 to 50 \[Leaning\] |
| 2026-11-05 | Readouts show 1 world unit as 1 m \[Leaning\]. STAB added as a flight mode that holds the nose on a chosen direction \[Leaning\], so the PRO and RETRO buttons become part of it. ASS stays spin-only |
| 2026-11-05 | UI decisions refined. Heading dial adopted, so the direction of travel marker leaves the parking lot. Hidden panels come back by dragging a side tab, replacing tap anywhere. Zoom buttons are SYS, ORBIT, and SHIP, and zoom moves smoothly with no outer limit \[Leaning\]. Throttle sets thrust and BURN activates it. Touch targets are measured in game pixels. Right panel rule reworded to fit the full-height panel |
| 2026-11-05 | UI section gains turning and RCS controls and edge markers, including a full-height right panel on the inner screen \[Leaning\] |
| 2026-11-05 | UI section added, with planet info as a subsection: UI principles, top bar, side panels, and auto-hide \[Locked\], cover screen and menus \[Leaning\], planet info \[Locked for design, Tier 1\] |
| 2026-11-05 | Screen fitting rule replaces fixed sizes and settles the resolution question: the game fills any landscape screen on whole-number pixels \[Leaning\]. UI goes in a safe area that avoids cutouts \[Leaning\]. Still Android only, built for the Fold |
| 2026-11-05 | Two moon capture aids added to the parking lot, not built: Manny likes the difficulty as it is |
| 2026-11-05 | Landing works in Tier 0, with no damage yet \[Leaning\]. Zoom goes to seven tiers: a Descent tier at 1/8 sits between Surface and Approach, because the 128x jump was too big to land with. Landing line built, moved out of the parking lot \[Leaning\]. Rough altitude and speed readout added \[Leaning\]. Gravity interface gains `predict_entry_heights`, `get_altitude`, and `get_surface_velocity`, the one place ground speed comes from |
| 2026-11-05 | Rotating planets and atmospheres added for Tier 1 \[Leaning\]. Landing line idea added to the parking lot |
| 2026-11-05 | Moon on Kepler rails and sphere of influence switching work. Gravity interface gains body queries and `find_encounter`, because the view and preview need them and every model will have bodies. Orbit view now centers on the dominant body. Preview now also refreshes while coasting and draws encounters around the moon's future position \[Leaning\]. Moon set up in `data/moon.tres` so a burn right at the start reaches it \[Leaning\] |
| 2026-11-05 | Throwaway touch controls added for testing on the phone. The touch controls and UI question stays open |
| 2026-11-05 | Trajectory preview added for the ship's current path, updating only on burns. The background thread waits for maneuver planning \[Leaning\] |
| 2026-11-05 | First orbit works, with the physics core in C++. Gravity interface changed to take 64-bit x and y, because Godot's Vector2 is 32-bit. Tier 0 planet set far below 1/10 scale so a low orbit takes under 4 minutes without time warp \[Leaning\]. Four of the six zoom tiers built, with far tiers centered on the planet \[Leaning\] |
| 2026-11-05 | Star tint kept and moved out of the parking lot \[Leaning\]. Never-pure-black rule changed to match: pure black now only happens far from any star \[Leaning\] |
| 2026-11-05 | Star tint prototyped behind a feature flag, with a fake star and faint stars washing out in the glare |
| 2026-11-05 | Star tint idea added to the parking lot |
| 2026-11-05 | First Android build runs on the Fold. Screen sizes confirmed on the device. Android export approach added under Tech \[Leaning\] |
| 2026-11-05 | SAS renamed ASS, for Attitude Stabilization System \[Locked\] |
| 2026-11-05 | SAS staying spin-only is now \[Locked\], after flight testing |
| 2026-11-05 | Two flight modes added, RAW and SAS (Ship Assist Systems), with SAS cancelling spin only \[Leaning\]. All-rounder archetype added; the Tier 0 lander is that ship, with thrust tuned to 300 px/s² \[Leaning\] |
| 2026-11-05 | Tier 0 turning changed to angular momentum, replacing the fixed turn rate \[Leaning\] |
| 2026-11-05 | Background stars set to a seeded shader with three parallax layers \[Leaning\] |
| 2026-11-05 | Tier 0 turning set to a fixed turn rate, no angular momentum \[Leaning\] |
| 2026-11-05 | Tier 0 started. Engine set to Godot 4.7.2 with the Compatibility renderer \[Leaning\]. C# re-checked: Godot 4.7 docs still call Android support experimental, so the physics core stays C++. Published Fold 8 screen sizes added to the resolution question, with a 3x placeholder |
| 2026-11-05 | Named Final Orbit. Pixel scale locked: pilot about 35 x 40 px (concept art at native scale), canopy 40-48 px, modules about 64 x 64 px, small craft about 100 x 200 px |
| 2026-11-04 | First draft from brainstorm |

## Pitch and pillars

A 2D, top-down, pixel-art NASApunk space sandbox for the Galaxy Z Fold 8: you are a pilot flying gigs for a space agency through a grounded, procedurally generated universe with real orbital mechanics and ships that physically break apart. Name: Final Orbit. \[Locked\]

Pillars:

1. **Real physics, arcade pacing.** Orbits, mass, and momentum are real; time warp, short gigs, and clear goals keep it playable on a phone.
2. **5 minutes or 5 hours.** One gig and done, or a long, greedy flight deep into a system.
3. **Bullshit realistically.** Anything can be weird, but everything has a physical reason.
4. **Damage is gameplay.** Ships are made of pixels; losing pixels changes how the ship flies.
5. **The right ship for the job.** No best ship; every capability costs mass.
6. **Made for the Fold.** Folded, unfolded, and tent states each mean something.

Reference touchstones: Spaceflight Simulator (seamless 2D landing), KSP (patched conics, staging), Lunar Lander (the original arcade loop), FTL (interior cutaway), Greenville on Roblox (gigs, owning and customizing vehicles), Alto's Odyssey (Zen Mode), Starfield (NASApunk hardware and UI).

## Platform: Galaxy Z Fold 8

Android only, built for the Galaxy Z Fold 8. Each physical state of the phone is a mode. \[Locked\]

| Phone state | Mode | What it does | Status |
| --- | --- | --- | --- |
| Unfolded (inner screen, near-square) | The Cockpit | Full game: flight, maneuvers, landing, galaxy view | \[Locked\] |
| Folded (16:10 cover screen) | Compact play | Playable landscape version for quick gigs, docking, hops | \[Leaning\] |
| Tent or stand on cover screen | Observatory Mode | Ambient telemetry view of the ship coasting, like a desk clock | \[Leaning\] |
| Folding mid-flight | Fold to coast | Autopilot plus time warp during long transfers; ping on arrival | \[Leaning\] |

Requirements:

- Seamless fold and unfold with no app restart and no lost state. \[Locked\]
- The unfold is diegetic: the porthole widens into the full viewport. \[Leaning\]
- One internal pixel resolution per screen, each scaling by whole numbers. \[Locked\]
- Screen fitting: the pixel scale is the screen's short side divided by 616, rounded to a whole number, and the game's size is the screen divided by that scale. It fills the screen, leaving at most a couple of pixels on an unusual size, so other screens don't look broken even though the Fold stays the target. Inner screen: 816 x 616 at 3x. Cover screen: 986 x 624 at 2x. \[Leaning\]
- On a screen shorter than 616 game pixels, the Orbit and Planet zoom levels zoom out to match, so the same orbits still fit. \[Leaning\]
- UI goes inside `Hud/SafeArea`, anchored to its corners and edges, so it follows every screen and fold and stays clear of cutouts and system bars. The cover screen's camera cutout takes 104 px on the left in landscape. \[Leaning\]

The Fold 8 has no Flex Mode (the hinge only opens fully or closes fully), so the half-folded Mission Control console idea is \[Cut\]. The Fold 8 Ultra and later models may bring it back; see parking lot.

## Core loop

A run is one flight: undock, chain gigs, and dock again or die trying. You are paid for the deliverable, not the trip. \[Locked\]

The flight:

1. Pick gigs from a station board and choose a ship that fits them.
2. Undock with the fuel and cargo you can carry.
3. Fly the gigs with real orbital mechanics; random events come up mid-flight.
4. The run ends when you dock, eject, or die.

Payment rules: \[Locked\]

| Gig type | Deliverable | Paid when | Lose the ship, pilot survives |
| --- | --- | --- | --- |
| Cargo and retrieval | Physical cargo | Cargo arrives at destination | Nothing paid |
| Explore, survey, data | Data | Uplink reaches the agency, or drive is carried home | Paid if already delivered |
| Destroy or disable | Target state | Mission control confirms on telemetry | Paid |

- Pilot death always pays nothing. The escape pod counts as surviving.
- The agency does not insure your ship; repairs and replacements are your money.
- Abandoned cargo stays in orbit and can be recovered later, by you or by a salvage gig.
- Data uplink needs line of sight to a relay, so comms blackout matters.

Risk and pacing: \[Leaning\]

- Longer flights pile up undelivered value and risk.
- Fuel is the clock; running dry means a paid tow.
- Mid-flight events: distress beacons, solar flares, passing comets, derelicts, uncharted signals.
- Being first to chart a body or anomaly pays a bonus and stays on your map.

Zen Mode: no gigs, no pay, unlimited fuel, free time warp, ambient music. It doubles as the physics test bed. \[Locked\]

Single player only. Pure sandbox for now, no story. \[Locked\]

## Gigs

Decided 2026-11-10, on Manny's call, from his mockups of the gig board and the active-gig tracker. \[Leaning\]

- Tier 1 starts with cargo and survey gigs. Destroy or disable gigs wait on the open question about combat, and salvage (detaching parts from wrecks) is Tier 2.
- Gigs only go to places that exist: the station Kapteyn-3, the launch base, the moon base, and survey spots on the planet and moon. Lagrange points wait on n-body physics.
- The station is named Kapteyn-3, callsign KAPTEYN-3, from Manny's mockup, replacing Home Station.
- Cargo rides in the lander's cockpit, up to 3 tonnes, and weighs what it says: a 2-tonne load costs about 40 m/s of delta-v and some thrust. A cargo module can come later with its own art.
- Pay is in credits, Cr. A run starts at 0 Cr, and a gig pays when its deliverable arrives, as the payment rules say. Docking stays free until Manny sets prices; economy numbers are still open.
- One active gig at a time to start; chaining several, as the core loop has it, comes once the first gig plays well.
- There's no saving yet, so credits and finished gigs last one flight.

Boards: \[Leaning\]

- Each place with a gig board shows four gigs that start there: the station's gig board, and the mission computer at each base. A gig taken off a board is replaced by a new one.
- Gigs are made from gig types in data files (`data/gigs/`), each slot from the seed, the place, the slot, and how many times it's been filled, so the same seed always gives the same gigs.
- Pay is a flat part, more for the route's delta-v, and more per tonne carried, rounded to 100 Cr. A route's delta-v is a rough sum, one leg up to the station's orbit and one down: from the planet's surface 400 m/s up and 120 down, from the moon 250 up and 260 down, and 30 to dock. So a run from the launch base to the moon base pays most.
- Each gig lists its requirements, met in green and unmet in red, and a gig can only be taken with all of them met: cargo room, the ship at the place it starts (docked at the station, or landed on the base's pad), and the delta-v the route takes with the cargo aboard.
- Hazards come from the route: the delta-v margin, low, medium, or high risk, and what arriving takes (docking, a landing in air, or an airless landing).
- The board, from Manny's mockup: USE TERMINAL at the gig board or a mission computer opens it over the flight, which keeps running. AGENCY GIG BOARD between warning signs heads it, with where it is and CLOSE [×]. Down the left, the gigs, each with its title, pay, and kind and destination; the one picked is filled orange. Every title is the same size: the pay sits beside it, as in the mockup, or on every row's second line when a title would run into it, as on the inner screen. On the right, the picked gig: its title, payout, destination, cargo, hazards (high in red, medium in amber, low in green), what it is in a sentence, and MIN. REQS, each [x] in green or [ ] in red. [ ACCEPT GIG ] lights once they're all met, and taking a gig closes the board. The balance shows at the bottom. The tap or key that opens the board doesn't count on it, so opening never takes a gig. \[Leaning\]
- While it's up, the pilot doesn't move or use anything. A tap off the panel closes it. On the Mac, up and down pick a gig, F takes it, and Escape closes it.

Tracker: \[Leaning\]

- From Manny's mockup, adapted to the HUD: while a gig's active, a panel under the readouts at the top left shows ACTIVE GIG with a warning sign, the gig's title, its steps, each [x] once done and the one being worked on marked OBJ, how far it is to where that step happens, the cargo aboard, and the pay.
- A tap on its header folds it into an orange GIG tab at the top of the left edge, and a tap on the tab opens it again. Only that changes it, on Manny's call: hiding the controls leaves it as it is. The tab is only there while a gig is.
- Taking a gig makes its destination the target, so the edge marker points the way.
- The context menu keeps off it, and gets first claim on a touch if they ever meet.

Cargo gigs: \[Leaning\]

- Taking one loads the cargo then and there. The steps are LOAD, then DOCK AT the station or LAND ON the base's PAD, then UNLOAD THE CARGO.
- Arriving offers UNLOAD CARGO on the context menu, from the cockpit, pointing at the pad or the docking port. Docked at the station it's a second row, under BOARD STATION. Unloading pays. F picks it on the Mac when nothing else is on offer.
- The context menu gathers its rows from the pilot's own action and from the agency, so a gig can add choices to places without the places knowing about gigs.
- Losing the ship loses the cargo, and the gig pays nothing.

Survey gigs: \[Leaning\]

- A survey is a spot to scan: a crater rim, a ridge line, and so on, on the planet or the moon, picked from the seed like everything on a board. On a world with seas, only on dry land. There's no scanner module yet, so the ship scans from the cockpit.
- Its steps: LAND WITHIN 80 M OF THE SITE, SCAN THE SITE, and UPLINK THE DATA. It asks only for the delta-v there, since nothing's loaded.
- Landed near enough, SCAN SITE shows on the context menu, on the spot. The scan takes 8 seconds and only runs while the ship stays landed there; lifting off pauses it.
- The data uplinks by itself once Kapteyn-3 or a base is in line of sight, with no world in the way, and the gig pays then, as the payment rules say for data. Until then the tracker says NO RELAY IN SIGHT. Losing the ship before the uplink loses the data, and the gig pays nothing.
- The spot is the target, and on screen it gets orange brackets marked SURVEY SITE while it's being found and while the scan runs.
- Pay is a flat part and more for the route's delta-v: a moon survey from the launch base pays most.

## Player

You are a pilot inside the ship, not the ship itself. Mission control is the voice on the radio, not you. \[Locked\]

- The pilot sprite is about 35 x 40 px, seen top-down: gold visor, helmet, shoulder patches, backpack. Sized to match Gemini concept art at its native pixel scale; 6 x 8 and 16 x 16 px were too small to read as a person. \[Locked\]
- The pilot sets the scale of everything else, so ships are built around the cockpit. \[Locked\]
- The cockpit canopy is about 40-48 px wide, made of breakable glass pixels with the pilot visible underneath. \[Leaning\]
- A cracked canopy depressurizes the cockpit and starts a suit-only timer. \[Leaning\]
- Escape pod: a hard crash can eject the pilot into a tiny, flyable pod. Surviving keeps any already-delivered pay. \[Leaning\]
- EVA: the pilot leaves the ship on a jetpack to patch breaches, grab salvage, or reattach floating parts. Same sprite scale inside and outside. \[Locked for design\]
- Built so far, moved ahead of gigs by Manny: the EVA button puts the pilot out beside the cockpit, unless the ship's lost. From a landed ship it puts them on the ground instead, below. The ship takes no orders then, though ASS and STAB keep holding it. On EVA the jetpack steers like the ship's RCS: the rotate buttons turn the pilot and letting go stops the turn, the arrows push relative to them with up toward the helmet, and a drag turns them to face that way. Turning costs a quarter of what pushing does. Walking, inside a station or on the ground, still goes by the screen. The view follows the pilot. The jetpack pushes at 12 units/s² (0.6 m/s²) for 60 seconds, fills up aboard the ship or a station, and obeys orbital mechanics like anything else. Running out of reach of anything, or hitting the ground hard, needs a restart. Patching, salvage, and reattaching are still to come. \[Leaning\]
- While the pilot's out, the top bar and gauge are theirs: delta-v and the gauge read the jetpack. A cyan marker points the way back to the ship, and SHIP on the zoom buttons brings the view back to the pilot. \[Leaning\]
- The EVA sprite comes from Manny's sheet, at about 48 x 50 px: a slow float, walking, and jetting with flames, drawn facing down and right, and mirrored for up and left. Inside a station the pilot only faces those four ways, so the pixels stay square with the floor. In space they turn the rest of the way too. The sheet's helmets have no gold visor, and the drawing's a little bigger than the 35 x 40 above. \[Leaning\]
- Walking on worlds uses a second sheet drawn from the side, facing right and mirrored for left: idle, walking, jumping in low gravity, climbing, using a terminal, and a jetpack hover. Same suit, gold visor. Manny made it with Gemini from reference images in `art/pilot/source/`, and `tools/slice_pilot_side.gd` cuts it to 64 x 64 frames, about 36 px tall, in the suit's own palette colors, with feet on one line. Climbing and using a terminal are cut but not used yet. \[Leaning\]
- Walking on worlds, built: EVA from a landed ship stands the pilot on the ground beside it, on the hatch's side, seen from the side and standing up straight. Left and right walk at 50 units/s, getting going as fast as gravity times 3 allows, so the moon is a little slippery. Up jumps at 70 units/s: about 42 units high on the moon and 12 on the planet. Steps up to 8 units are walked up, and higher ground is a wall. The ground carries the pilot around as the world turns, all in 64-bit. \[Leaning\]
- The jetpack on the ground only fires on a second press of up in the air, steered by left and right, so a jump costs no gas. At 12 m/s² it can't lift against the moon's 60 or the planet's 200, only stretch a jump. More than 400 units up, the pilot's on EVA again. \[Leaning\]
- Coming down on EVA at 80 units/s or less, the pilot lands on their feet and walks. Faster is lost. \[Leaning\]
- Standing anywhere along a landed ship's width, under it or beside it, offers BOARD SHIP. Away from the ship, the way home marker points to it, and the comms line reads ON FOOT. If the ship isn't landed on the same world, the pilot's stranded and RESTART shows. \[Leaning\]
- Being tried: a low-poly 3D astronaut in place of the sprite sheets, built in code from simple shapes on a joint hierarchy, rendered live into a small canvas at 1 px per 5 cm, with every pixel snapped to the agency palette and a 1 px outline. One model would give the side view on worlds, the view from above in stations, and any angle in space, and code would animate it all the time: the stride from speed, feet planted on slopes, reaching, and tumbling. The risks are pixels flickering as it moves and less detail than the drawings. Claude Fable 5.2 builds the model from `art/pilot/source/model_prompt.md`, and it's compared beside the sprite before deciding. \[Open\]
- The 3D pilot in the game, behind `FeatureFlags.PILOT_3D`, on for now: `scripts/pilot/astronaut_view.gd` renders the model into a 64 x 64 canvas at 1 px per 5 cm, already turned to its angle on screen so its pixels stay square. A shader snaps each pixel to the suit's agency colors and outlines the outside in the darkest gray. A second render of distances adds a line wherever one part passes in front of another, and shades the far side of the body darker, the way pixel artists shade the far arm and leg. Code poses the joints every frame: standing, a stride that follows speed, crouching to jump and land, tucking in the air, a jetpack pose, and a slow drift in space. The jetpack's thrusters are at the corners of the pack and puff cold gas in the ship's RCS colors, not flames: each push fires the corners that trail it. On worlds it's seen from the side, turning through the front when it changes direction. On EVA it floats upright, seen from above with the helmet toward the camera, and leans into a push, not a turn, until it's nearly flat, seen from the back with its head the way it's pushing, and straightens up again when let go. The puffs come from whichever corners of the pack trail the push, and a turn fires the two corners farthest apart. Inside stations it's seen from above at the station's pixel size, 2 game pixels per pixel. Turned off, the sprite sheets come back. \[Open\]
- The 3D pilot's model is built, in `scripts/pilot/astronaut_model.gd`: 1.85 m tall, 19 joints the game turns by name, 7 attachment points (visor, hands, soles, jet nozzles), about 1,900 triangles, and colors from the agency palette. The visor wraps round to the sides of the helmet, about 0.6 m across where the prompt said 0.4, because a visor only on the front is a 2 px sliver from the side and the sprite's covers the front half of the helmet. Each shoulder's patch is a plate on the shoulder itself, and its dark ring sits on the chest round the armhole, so the shoulder stays white from the side. In a rough preview the model read much better with dark lines where one part passes in front of another, not only round the outside, so the shader should try that. Still to come: the pixel renderer, the palette and outline shader, the animation, and the comparison. \[Open\]
- The suit has its own limits: oxygen, temperature, jetpack fuel. Only the jetpack is built so far. \[Leaning\]
- The pilot can carry a name, suit livery, and career record. \[Open\]

## Ships

Ships are built from modules, and each module is a small pixel mask where every pixel has a material, a mass, and collision. Trade-offs come from the physics, not from stats. \[Locked\]

Construction:

- Modules snap to a fixed grid (starting guess: about 64 x 64 px cells, scaled to the 35 x 40 px pilot; small craft around 100 x 200 px): cockpit, engines, RCS thrusters, fuel tanks, cargo, hull plating, heat shields, radiators, landing gear, solar panels. \[Leaning\]
- Each module is its own PNG, in a folder per ship such as `art/lander/`, and the ship's data file says which go where, so new ships can reuse parts. The lander's were cut from its whole drawing by `tools/slice_lander.gd`, and put back together they match it pixel for pixel. \[Leaning\]
- A module's data can mark its working pixels, so damage knows the real part. An RCS module works while its nozzle does, however much hull around it is gone, and an engine depends on its half of the bell. \[Leaning\]
- Each material has a density; the ship's total mass, center of mass, and spin resistance are summed from its pixels. \[Locked\]
- A pixel's material goes by its art color, from a table in `data/materials/`, so drawing a part in gold foil makes it light. \[Leaning\]
- Fuel has mass and burns off, so ships get lighter and more agile as they fly. \[Locked\]
- The main engine and RCS both burn fuel, so ASS, STAB, and turning all cost fuel. With none left, neither fires. \[Leaning\]
- The engine's flame is drawn by code in chunky pixels and the fire colors, from what the engine is doing: long with a white-hot core flat out, short and orange throttled back, spreading wide in a vacuum, held narrow by air with bright knots in it, and stopped by the ground. It comes out of what's left of the bell, so a lost engine moves it to one side, and a damaged one sputters. \[Leaning\]
- RCS puffs show from the nozzles on the art. The nozzle opposite the push fires, so the left one turns the nose clockwise or moves the ship right. The two tail nozzles move it forward, and the side nozzles angled forward back it up. Puffs only show on the sprite, and tiny corrections while holding steady don't show. \[Leaning\]
- The lander, as the all-rounder: about 19.5 t dry, 40 t of fuel, 300 m/s² of thrust when full and about 916 when empty, about 16,700 m/s of delta-v, and about 34 seconds of full-throttle burn. Engine and RCS strength are set so a full tank feels the same as it did with half the fuel. These live in `data/lander_design.tres`. \[Leaning\]
- Until stations exist, landing on the planet refills the tanks, and a ship stranded with no fuel means restarting. \[Leaning\]
- Staging: drop empty tanks or used heat shields to save mass; dropped parts become debris. \[Leaning\]
- Repairs and customization happen at the pixel level, so patched plating shows on the hull. Liveries and paint use the agency palette. \[Leaning\]

Destruction: \[Locked\]

- Impact damage depends on both masses and the impact speed.
- Damage erases pixels. After each hit, a connectivity check splits off any piece no longer attached.
- Detached chunks become physics bodies with their own orbits; single pixels are visual particles only.
- Losing a module changes how the ship flies: a missing thruster gives off-center thrust and spin, a punctured tank vents and pushes the ship.
- A debris budget caps active pieces; tiny ones fade or burn up.

How it works in Tier 1: \[Leaning\]

- Pixels are the ship's collision with the ground: whichever pixel reaches the ground first touches it, at any angle. Hitting debris uses the pixels too.
- Up to 50 units/s does nothing. Above that, the energy is half the mass times the square of speed, less the safe speed's share. Against debris, the mass is the two bodies' shared mass.
- Each material has a strength, the energy to destroy a full pixel of it: hull and paint 250 kJ, steel 750 kJ, glass 100 kJ, foil 50 kJ. The whole lander is worth about 5 GJ.
- A pixel has depth where a module has inside art: the hull's skin on top, then the systems (tanks, plumbing, power core), then the bare frame. Damage takes one depth at a time, and a pixel is still solid until the last one goes, so it only counts against a module then. A tank's skin can go without holing it. \[Leaning\]
- Each depth's front runs 12 px behind the one above, so a hit strips the skin well past where it breaks through, and innards show around every hole. \[Leaning\]
- The layers have a thickness, the share of a material's density and strength that a pixel of it has: skin 0.4, systems 0.2, frame 0.225 on the lander. Together they add up to the same 19.5 t as before. Parts with no inside art, such as the legs, count in full. \[Leaning\]
- Flat ground crushes from the side that hits, in a jagged line. Debris knocks a dent around where it touches.
- As a guide, with a light tank and the legs up: 60 units/s scuffs the bell, 100 strips about 280 pixels of skin, 150 strips about 570 and starts breaking through, 200 cuts the engine to about two thirds, and 250 kills it. A full tank hits about three times as hard, so 150 nearly kills the engine.
- Pixels are attached only if they touch, corners included, so nothing is left floating. Gaps the art draws, such as around the engine bell, get welded when the ship is measured: pixels up to 4 px apart across such a gap count as touching for as long as both are there. The piece with the most cockpit stays the ship. \[Leaning\]
- A hit counts at once for mass, thrust, and everything else, but the art catches up over up to about 0.4 seconds: pixels go a few at a time from where the hit landed, and the edge about to go glows in the thrust and fire colors. A crushed ship sinks to where it now rests, and the art shakes briefly. \[Leaning\]
- Every depth lost becomes a spark, thrown away from the hit, up to 800 in one hit. Past that, sparks stand in for 2 x 2 blocks, and past 3,000 for 3 x 3 blocks. Sparks live 1.6 to 4.5 seconds and flicker out at the end. Near the ground they fall and bounce, and elsewhere they drift, slowed by any air. There can be 1,500 at once. \[Leaning\]
- Pieces under 30 pixels drop away as sparks, just after whatever cut them loose. There can be 12 chunks at once. Under 200 pixels, one crumbles into sparks after 30 seconds or burns up in the air. Any chunk crumbles after 60 seconds on the ground, or at once if it hits the ground faster than 120 units/s.
- The ship turns around its new center of mass, which moves as pixels go.
- A module under half its working pixels stops working, and the pilot gets a message. Left RCS gone means no clockwise turn or moving right, and right RCS gone means the reverse. An engine weakens as its bell goes and stops under a quarter of it. One engine module gone means half the thrust, off-center, so the ship spins. The tail nozzles work or fail on their own.
- Fuel is shared across the tanks. A tank can only hold as much as is left of it, so losing pixels loses that share of its fuel at once. What remains leaks at up to 2,000 kg/s depending on the hole, and pushes the ship away from the hole. Lost capacity stays lost, and landing only refills tanks with no holes.
- Cockpit under half its pixels means the ship is lost, until the escape pod in Tier 2. The ship stops responding and stays where it is as a wreck. Touching the star destroys everything.
- RESTART appears when the ship is lost, has no engine, or has no fuel, and starts a new flight.
- A hit stops the ship dead against the ground, with no bounce or slide yet. Venting can still hop a light wreck off the ground.

Archetypes that emerge from the physics: \[Leaning\]

| Archetype | Good at | Pays for it with |
| --- | --- | --- |
| All-rounder | Decent fuel and thrust; feels a bit heavy but still quick | A specialist beats it at any one job |
| Light probe | Huge range, cheap burns | Fragile, can't land on heavy or hot worlds |
| Moon hopper | Nimble, cheap | Low-gravity bodies only |
| Heavy lander | Survives heat, high gravity, rough landings | Heavy, sluggish, short range |
| Hauler | Big cargo capacity | Handles like a fridge, fuel-hungry |

The Tier 0 lander is the all-rounder. Its 300 px/s² of thrust is the feel target for its Tier 1 mass and engine. \[Leaning\]

Taking off from a world requires thrust greater than the ship's weight there (thrust-to-weight above 1). Owning several ships matters because gigs demand different ones.

## Physics

Patched conics first (the ship feels only the dominant body's gravity), behind a swappable interface so restricted n-body can replace it later. \[Locked\]

Gravity model interface: \[Locked\]

- `GravityModel.get_acceleration(x, y, time)`
- `GravityModel.propagate(ship_state, dt)`
- `GravityModel.predict_trajectory(ship_state, duration, samples)`
- `GravityModel.find_encounter(ship_state, duration)`: when the coast next falls under another body's gravity.
- `GravityModel.predict_descent(ship_state, aero_body, flight, duration, samples)`: where and how the ship comes down with no more burns, flown through any air on the way. `get_hold_headings` gives the four headings STAB holds, for the ship and the forecast alike, and `get_body_spin` and `get_entry_altitude` say how fast a body turns and where its landing zone starts.
- Body queries: `get_body_count`, `get_body_parent`, `get_local_root`, `get_body_position(index, time)`, `get_body_radius`, `get_dominant_body(x, y, time)`, `get_sphere_of_influence`, `get_body_orbit_path`. Body 0 is the star at the center of the system, fixed at the world origin. Planets orbit it, and moons orbit planets.
- Positions are separate 64-bit x and y, in `ShipState` or as plain floats, because Godot's Vector2 is 32-bit.
- `PatchedConicsModel` ships first; `NBodyModel` (ship feels every body, planets stay on rails) plugs in later. Nothing else in the game knows which is running.

Celestial bodies: \[Locked\]

- Planets and moons move on Kepler rails, computed from time, not simulated. Deterministic and time-warp friendly.
- Each body's mass sets its gravity and its sphere of influence.
- Planets never pull on each other.

Rotating planets and atmospheres: \[Leaning, Tier 1\]

- Planets spin, and their atmospheres rotate with them. The home planet turns once in about 48 minutes, with its ground moving at 330 units/s, clockwise like the ship's starting orbit. The moon is tidally locked, with its ground moving at 137 units/s. \[Leaning\]
- The speed readout measures against the turning ground inside the landing zone, and against the body itself higher up, so it jumps by the ground speed at the top of the zone. \[Leaning\]
- Inside an atmosphere, air resistance is computed relative to the moving air, so a hovering ship gets dragged along with the rotation.
- Air resistance grows with the air's density, the square of speed, and how much of the ship faces the air, and shrinks with mass, so side-on slows harder and a full tank punches through further. Each ship's shape sets it. Since 2026-11-10 that's worked out piece by piece along the outline, under Aerodynamics below, and the box as wide and long as the ship's pixels is only the old drag behind its flag. \[Leaning\]
- The home planet's air ends at 15,000 units and thins by a factor of e every 2,000. A lander coming from low orbit reaches the ground at about 290 to 360 units/s, depending on how it's turned, so it still needs a burn to land. \[Leaning\]
- Landing means matching the ground's rotational speed.
- Launching in the direction of spin gives a free speed boost, like real rockets launching east.
- Outside the atmosphere, momentum is conserved and the ship does not slow down.
- Airless bodies have no moving air, so a hovering ship stays put while the ground slides past underneath.
- Coasting stays closed-form above the atmosphere. Inside it the ship is simulated step by step, which limits time warp and fold-to-coast there and needs the preview's background thread.
- Re-entry heat grows with the square root of air density and the cube of speed. A gentle return from low orbit reads about 0.2 to 0.3 on a scale where 1.0 is the limit, and a steep return from high up goes past 1.0. \[Leaning\]
- Heat shows on the ship itself, following its real shape: a thin layer of burning air hugs whatever faces the airflow, and flames stream back, longest off its edges. The hull glows from the hot side in, from dull red through orange to nearly white, with the color and depth following hull temperature. It stays on the side that soaked it up, and cools over a few seconds after leaving the air. So the hull's color is a heat gauge with no extra UI. All in the thrust and fire colors. From far out, where the art is too small, it's a little comet. \[Leaning\]
- The hull warms toward the heat over about 6 seconds, so a short spike does no harm. Past 1.0 it burns away from the hot side, at 200 MJ a second for each whole step past, about 4% of the lander. Heat shields come with more modules. \[Leaning\]
- The path line shows the air's drag since 2026-11-10: see Landing prediction below. \[Leaning\]

Aerodynamics, decided 2026-11-10 on Manny's call and built the same day: \[Leaning\]

- The air pushes on each exposed part of the ship's outline, by how squarely it faces the airflow, with the airflow at each part including the ship's own spin. The pushes add up to drag, lift, and a turning force, around the live center of mass. Nothing about how the ship flies in air is chosen by hand: it comes from shape and mass, the most realistic way.
- How it's worked out: each layer's outline, the hull's and each leg's where it is now, is cut into pieces 8 px long, and cut again whenever damage or the legs change it. A piece moving into the air is pushed straight back along the way it faces, by half a coefficient times the air's density, the square of the speed it meets the air at, and its length. A piece with another layer between it and the oncoming air feels nothing. The coefficient is 1.8, the usual figure for a blunt body at speed, where 2.0 would stop every bit of air that hits it. Both numbers are in the ship's design data. The working is in the physics core, in `AeroBody`, so the landing prediction can share it.
- So stability comes out of the physics. With the center of mass ahead of where the air pushes, a ship turns to lead with that end, like a dart, and a dart-shaped test ship does exactly that from any start.
- **The lander doesn't fall engine-first by itself**, which this doc had hoped it would. Its hull narrows toward the nose, so falling engine-first, everything behind the center of mass sits in the wide tank section's shadow, and all the air lands on the engine end, ahead of the center of mass: a dart thrown backward. Nose-first is no better, since its mass is low. Left alone it settles between the two, engine end leading but tilted: 46 degrees with full tanks, 69 with empty ones, and nearly broadside, about 85, with the legs down. Its swing dies out. Real boosters have the same trouble and carry grid fins at the top for it. It's left as piloting: nose fins were drawn in the asset editor and cut on Manny's call, 2026-11-10, since he didn't like how they look. \[Cut: fins\]
- Draining the tanks raises the center of mass and widens the tilt. Damage changes the shape: with its right side crushed, the lander has one way to settle where it had two. A tilted ship gets lift and slides sideways: held 35 degrees off, about 170 units/s after 6 seconds.
- Spin is damped by the air, since a spinning ship's parts push into it.
- The RCS keeps its strength. The air's turning force grows with density times speed squared, so high or slow the RCS wins, and deep and fast the air does. Losing that fight means coming in too fast or too steep: piloting, not a rule. STAB, ASS, and drag to point hit the same limit, and the comms line says AIR OVERPOWERING RCS when they can't hold: once, after a fifth of a second of losing, and not again until the RCS has held for 4 seconds. Real craft work this way: the Shuttle handed over from thrusters to wings as the air thickened, and boosters steer with grid fins in air.
- STAB can hold the lander engine-first through a gentle return from the start orbit, staying within 2 degrees, because near engine-first the air's turning force starts small. That costs about 100 kg of RCS propellant. Pushed well off engine-first while deep and fast, or on a steeper return, it loses and the ship swings round to its tilt.
- ASS holding the ship still against the air fires the whole time it's being pushed, so a hands-off descent with ASS on costs about 350 kg of RCS propellant, and RAW costs none.
- Heating follows what faces the airflow: it's taken from the piece of the outline that meets the air hardest, on the same scale as before, and the hot side of the hull is the side those pieces face. The flames still trail the way the ship's going.
- A long tick under time warp is flown in steps of a sixtieth of a second, or shorter when the air's thick and fast, so a descent at 10× comes down within 2 m of the same descent at 1×. A step that would hand energy back to the ship is shrunk, so the air only ever slows the ship's motion through it. A tick costs about 1 microsecond on the Fold, and about 10 at 10×.
- From the start orbit with nearly empty tanks, a lander held engine-first reaches the ground at about 360 units/s, and hands-off, tilted, at about 290. The old drag gave 287 held engine-first, because its box caught too much air whenever the ship wasn't square to it.
- `FeatureFlags.AERODYNAMICS` off brings back the old drag on one box, which never turns the ship, to compare.

Ship: \[Locked\]

- Coasting orbits are closed-form ellipses, so time warp and fold-to-coast cost almost nothing.
- Thrust, collisions, and torque use the ship's live mass and center of mass.
- Ship mass does not change its orbit, only how it responds to pushes.
- Tier 0 turning has angular momentum: A and D change the spin at a fixed rate, and the spin lasts until the opposite key cancels it. Torque from live mass arrives with modular ships. \[Leaning\]

Flight modes: \[Leaning\]

- RAW: your inputs only. Spin and drift last until you counter them yourself.
- ASS (Attitude Stabilization System): when you let go of the turn keys, the RCS fires against the spin until the ship stops turning.
- ASS never brakes velocity, because cutting velocity would break orbits. \[Locked\]
- STAB: the RCS holds the nose on one of four directions: along the trajectory line or toward the body you're orbiting, each with the nose first or the thruster first. \[Leaning\]
- STAB picks automatically, whichever of the four is closest to where the nose is pointing. On the north side of a clockwise orbit, those are right along the path, left against it, down toward the planet, and up away from it. \[Leaning\]
- Inside a body's landing zone, along and against the path are measured against the turning ground, like the speed readout and the dial, so against the path is what the landing burn cancels, and in air the nose stays in the airflow (within about 1.5 degrees on a descent, where the body's frame was up to 37 off). Higher up they're measured against the body, as before. Nearly still over the ground, under 0.5 units/s, there's no path to point along, so they fall back on the body's. The landing forecast holds the same directions. Manny's call, 2026-11-10. \[Leaning\]
- The name ASS, for Attitude Stabilization System, is final. \[Locked\]
- ASS uses the same thrusters as manual turning, at the same strength, so from Tier 1 it should burn the same fuel.
- The ship starts in ASS, with STAB off. On the Mac, T switches ASS and RAW, and R switches STAB.

Scale and precision: \[Leaning\]

- One world unit is 5 cm, set by the pilot: 1.85 m tall and 37 px, so one unit is one pixel at the closest zoom. Physics stays in world units, and `scripts/units.gd` turns them into meters for every readout: the top bar shows each unit small beside its name (M, KM, M/S), and cards and markers say m, km, and m/s. Manny's call, settling the open scale question. \[Locked\]
- At that scale the home planet is 7.5 km across its radius with Earth's gravity (200 units/s² is 10 m/s²), the moon 1.5 km at 0.3 g and 30 km away, and the star 2,265 km off. A low orbit is 1.5 km up at about 250 m/s, the lander is 10.5 m tall with 837 m/s of delta-v and 1.5 g of thrust when full, and the jetpack gives 0.6 m/s² and 36 m/s, close to a real crewed jetpack. Walking is 2.5 m/s and a moon hop about 2 m. Small worlds, like Kerbal Space Program's but smaller, tuned for play.
- Elsewhere in this doc, numbers are world units unless they say otherwise. Lines written before 2026-11-10 that say m or m/s mean world units.
- Tier 1's star has 5,000 times the planet's mass and sits 45 million units away, so a lap of the planet around it takes about 3.5 hours at about 22,000 units/s. About three quarters of a full tank can drop from low orbit almost to the star, in about 40 minutes. That's the longest trip that works without time warp. These live in `data/home_star.tres` and `data/home_planet.tres`. \[Leaning\]
- The Tier 0 planet is far smaller for now, so a low orbit takes under 4 minutes without time warp: radius 150,000 px and surface gravity 200 px/s², or about 1/850 real scale if the 35 px pilot is 1.75 m. Revisit once time warp exists. These live in `data/home_planet.tres`. \[Leaning\]
- Floating origin re-centered on the ship to avoid jitter.
- Physics math in 64-bit, either in native code or a double-precision engine build.

Trajectory preview: computed on a background thread, in chunks, and cached while the player drags a maneuver. \[Leaning\]

The preview draws the ship's current path as a 1 px telemetry cyan line: one full lap on a closed orbit, otherwise up to six hours ahead or until it hits a surface. Closed-form paths are cheap, so it runs on the main thread. It updates on a burn, on a change of dominant body, and every tick while orbiting a moving body or on a path that doesn't close, so no flown part lingers behind the ship. A closed orbit updates twice a second, to catch encounters as the moon moves. The part of a path that goes through air is flown on a background thread since 2026-11-10: see Landing prediction below. \[Leaning\]

Around a moon, the line is drawn around the moon as it is now. An upcoming encounter is drawn around the moon as it will be on arrival, with a ring showing where that is, so the line has a kink where it enters the moon's frame. The line ends on leaving a moon's or planet's sphere; the path after that shows once you get there. \[Leaning\]

Landing prediction, decided 2026-11-10 on Manny's call and built the same day: \[Leaning\]

- Through the air, the path is flown ahead step by step, off the main thread, with the same aerodynamics as the real flight, so it's where the ship really goes. Above the air the line is the exact coast, as before, cut off where it meets the air, and the flown line carries on from there in amber. In the air the flown line is the whole path, starting from the ship.
- The main line is hands off: no more burns, even if the engine's on now, the ship turning as the air turns it, and STAB and ASS doing what they're set to, with the turn keys and drag to point let go. It's flown a tick at a time, exactly as the real flight is. Two more runs, held end-on, whichever end slows it least, and held broadside, mark a landing zone on the ground: you'll come down in there, depending on how you fly. It's drawn along the ground with a mark at each end, 5 m wider at each end than the runs, since a forecast is only that good.
- The line through the air is drawn against the turning ground, not against space, so it ends on the ground the ship comes down on, and straight down looks straight down. In the air that's the ground as it is now. Above the air it's the ground as it will be when the ship reaches the air, so the line has no kink there, and the ground still turns under the far end until then. This was decided while building it, since the ground moves 330 units a second and a line drawn against space ended hundreds of meters from where the ship lands.
- The line's end says what touching down there means, in small stencil text with the speed beside it: SAFE at or under the safe speed for the legs as they are, on ground the ship can stand on; HARD up to 250 units/s; CRASH above that; or BURN-UP if the hull passes the top of the heat scale on the way. Speeds are measured against the turning ground. Ground is too steep to stand on when the ship's center of mass would be outside its feet: about 11 degrees on the engine bell and 30 on the legs. The comms line reads the same, as SAFE TRAJECTORY, HARD TRAJECTORY, CRASH TRAJECTORY, or BURN-UP TRAJECTORY, in place of IMPACT TRAJECTORY.
- With no more burns assumed, most descents read CRASH until you burn, which is true: a lander from orbit still needs its landing burn.
- On an airless body the coast is left as it is, with the same label at its end from the impact speed, and no landing zone, since nothing spreads it.
- A pass that dips into the air and leaves again is drawn to where it leaves, with no label. Where it goes after that shows once it's there.
- A new forecast starts every quarter of a second while the ship's on its way down, on a worker thread, and each is swapped in when it's ready. The flight never waits for one. On the Fold a forecast takes 6 to 15 ms from the top of the air and about 1 ms near the ground, and the game holds 120 frames a second through the air with them running. In the air the coast isn't worked out at all any more, which used to happen every tick.
- How close it is: made at the top of the air, the forecast lands within 2 m of where the real hands-off flight then comes down, at the same speed. Made from the start orbit, half a lap earlier, it lands within a meter, but with ASS on its speed can be 15 units/s out, since small differences in where ASS loses its hold on the way down change how the ship ends up turned.
- It doesn't know about damage on the way, leaking tanks, or legs still moving.
- Future burns join the line with maneuver planning, which isn't built.

Landing line: the part of the line inside a body's landing zone, and everything below it, is drawn in telemetry amber, so you can see where a path starts coming down. The zone starts at the top of the atmosphere, or at a set height on an airless body, and both live in the body's data file. \[Leaning\]

Black holes are faked convincingly, not simulated with relativity: stronger close-range gravity, time dilation on the mission clock, tidal stress, visual lensing. \[Leaning\]

## Universe generation

Procedural, but every result is a chain of physical causes: the dice roll inside physics, and anything strange needs a reason. \[Locked\]

Generation chain (each step only reads earlier steps): \[Locked\]

1. **Star:** type picked with realistic odds (mostly dim red dwarfs, rare blue giants). Type sets luminosity and light color.
2. **Zones:** luminosity sets the inner scorched zone, the habitable (Goldilocks) zone, the frost line, and the outer dark.
3. **Composition:** rocky planets inside the frost line, gas and ice giants outside it.
4. **Mass and size:** set gravity and whether the planet can hold an atmosphere (small, hot planets lose theirs).
5. **Atmosphere:** adjusts surface temperature (a thick one traps heat, like Venus).
6. **Surface:** temperature, atmosphere, and water decide the biome.
7. **Colors:** rolled last, from the star's light and the planet's composition.

Exotic but explained: \[Locked\]

- Lush, alien life (purple oceans, orange forests) only in the habitable zone, with an atmosphere and liquid water.
- Life colors follow the star's light; plants around red dwarfs skew dark purple or black.
- Rare exceptions need a cause: hot Jupiters (giants that migrated inward), eyeball planets (tidally locked near red dwarfs, with a living twilight ring), ocean moons (icy moons warmed by tidal heating), rogue planets (no star).

Terrain and biomes per body: \[Leaning\]

- A body's data file sets its ground: how tall its mountains, hills, roughness, and rocks get, how deep its craters go and how many there are, how tall its cliff steps are, and how tall its far-off peaks are. Its seed sets the rest, so the same seed always gives the same ground.
- The same file sets what the ground is made of (dirt, rock, deep rock, core) and what stands on low, middle, and high ground (`boulder`, `plant`, `ice`, `crater`, or `lava`), which is how a biome shows up close.
- The surface map and the rim use the same noise, so the rim's color at any spot matches what you saw from orbit.
- These are set by hand for the home planet and moon. The generation chain above fills them in once systems are generated.

\1

- Seeded galaxy; systems are generated only when approached.
- Off-screen, nothing simulates except the rails math.
- Stations and colonies are hubs for gigs, fuel, and repairs; NPC traffic is ambiance, not a simulated economy.
- The first station is a hub with four ports and five rooms that bolt on port to port: comms, crew hab, EVA hab, suit room, and ship refueling. Each room has an outside and an inside sprite on the same canvas, lined up on its ports; the insides wait for Tier 3. \[Leaning\]
- It rides rails around the home planet like a moon does, but with no gravity of its own, at the height the ship starts, 2,600 m ahead of it. It turns with its orbit so its bottom always faces the planet, the way a real station can be held, so two ships on the same orbit nearby stay put against it. Comms is on top, crew hab on the right, suit room then EVA hab on the left, and ship refueling on the bottom, leaving four ports free. \[Leaning\]
- Its pixels are solid. The ship bounces off, keeping a quarter of its speed, and crushes on the side that hit above its safe speed of 50 m/s, the same as hitting the ground. The ship's outline is what touches, and the station can't be damaged for now. \[Leaning\]
- Docking: the ship's nose is the hatch, and it docks at any free port. The hatch has to come within 14 m of the port's middle, slower than 6 m/s against it, with the nose within 10 degrees of straight in. A dashed line shows from the nearest free port once the hatch is within 700 m, amber until those are all met and then green. Otherwise it's only a bump, and the pilot is told TOO FAST TO DOCK or LINE UP TO DOCK. A ship with its nose gone can't dock. \[Leaning\]
- Docking draws the ship the last bit into place, then fills the tanks and repairs the hull, for free until money exists. UNDOCK, or U on the Mac, lets it drift off backward at 3 m/s. \[Leaning\]
- Within 2,000 m of a station, the speed readout turns to REL and it and the dial's markers read against the station, including its turning. \[Leaning\]
- Boarding: BOARD STATION takes the pilot in from a docked ship, or from outside within 90 m of a free port's hatch. Inside, at a free port's inner door it's EXIT STATION, and at the port the ship's docked to it's BOARD SHIP. Nothing's checked for speed at a station's hatch, since the jetpack's slow. \[Leaning\]
- A station's terminals are spots set per room in the data. The first is the gig board, in the hub's console room on the upper right, which only says no gigs are posted until gigs exist. USE TERMINAL shows when the pilot's next to it. This is what gigs will be picked from. \[Leaning\]

Places on worlds: \[Leaning\]

- Planets stay continuous terrain, with no separate levels or loading screens. Places worth landing at are points on a body's surface: outposts with services and gigs, landing pads for cargo, survey points for data gigs, and later wrecks and anomalies. Each shows as a marker once charted, has a card, can be targeted, and has its ground flattened so it's fair to land on.
- Outposts are walked into, not menus. A planet's surface is the edge of a disc in the same flat world as everything else, so a building on it is cut the same way: seen from the side, floors stacked, with gravity pulling down. Walking in fades its front wall off, the way a station's roof comes off. Manny's call, over opening a menu on landing.
- Menus are what a terminal shows, at a station or an outpost alike: the gig board, cargo manifest, repairs, and refueling open as a stylized screen when the pilot uses one.
- Built in stages: first the pilot walks on worlds, from the side (built); then the launch base on the home planet (Manny's call, 2026-11-10); then a moon base with the same three buildings, whose pad is where cargo is unloaded from the cockpit (Manny's call, 2026-11-10); then walk-in outposts with terminals inside.
- Rooms in surface buildings are sized for the pilot, so a room is about 60 px tall next to a 40 px pilot, and the 211 px lander reads as about 10 m tall. Walking around buildings makes the pilot's scale the one players see, which leans the open scale question toward the pilot. \[Leaning\]
- The first place on a world is a launch base on the home planet, on Manny's call, ahead of the moon's landing pad. It has three buildings: a vehicle assembly building, a launch and landing tower beside a pad, and mission control, which houses the mission computer. \[Leaning\]
- Each building is Gemini concept art cut into sprites, the way the station's rooms are: its outside and a cutaway with the front wall gone, on one canvas, at the pilot's scale of 5 cm a pixel. A reference astronaut drawn in each image sets the scale when it's cut. Floors, ladders, doors, and terminals are marked in data, the way station rooms mark their floors. The prompts, templates, and references are in `art/launch_base/source/`. \[Leaning\]
- Art, 2026-11-10: the sprites come from Manny's asset editor, which cleaned up the same Gemini images at 2 source pixels to a sprite pixel: magenta and its spill keyed out, the reference astronauts removed, windows and truss gaps see-through, agency colors only, and outlined. Manny's call, replacing the first cut by `tools/slice_launch_base.gd`, which is gone. They're used at 5 cm a pixel like the ships and pilot, never resized, so the buildings came out about a fifth smaller than that first cut: the assembly building 242 x 354 px (12 x 17.5 m), the tower and pad 264 x 364 px, and mission control 240 x 176 px, with its floors 2.5 m apart and about 2.2 m of headroom. Doors are about the pilot's height. \[Leaning\]
- Placed, 2026-11-10: the base stands on the home planet about 1.8 km along the ground from where the ship starts above it, on dry land at column 17,940. The physics core levels the ground there to its average height across the base's 69 m, blending back into the terrain over 8 m each side, so physics and drawing agree. Props keep off it. The tower's art sits 1.7 m into the ground, so the pad's slab is flush and ships and the pilot step straight onto it. A site's data says which world, which column, its buildings and where each stands, and its pad. From far out it's an orange dot on the rim, and it can be tapped, focused, carded, and targeted like the station. \[Leaning\]
- The buildings are solid to ships, like the station: a ship bounces off what it touches and takes damage above its safe speed, with a BUILDING COLLISION warning. A landed ship that settles or tips against one slides along the ground out of it, never up off the ground, so it ends up beside the wall, not in it. The tower's swing arms aren't solid, since they swing clear of a ship coming down onto the pad. The pilot isn't stopped by them: in a side view they stand behind the ground the pilot walks along, so the pilot passes in front and goes in through doors. \[Leaning\]
- Walking in, built: at a building's door, ENTER takes the pilot inside and its front wall fades off, the way a station's roof does. Inside, floors are level and their ends are the walls. Up and down climb a ladder, seen from behind, and left or right steps off onto a floor it reaches. Terminals offer USE TERMINAL, and the door offers EXIT, back onto the ground outside. Each building's floors, ladders, door, and terminals are marked on its art in the site's data. Mission control's mission computer is upstairs, and says NO MISSIONS POSTED YET until gigs exist; the assembly building's control booth is on its top catwalk. No jumping indoors. The comms line says which building the pilot's in. \[Leaning\]
- Layout, left to right: the assembly building, 12 m wide and 17.5 m tall, with its vehicle door toward the pad; 6 m of apron; the 12.5 m pad, with the 16 m tower at its left end, 8 m clear beside it for a ship, and its crew and fuel arms reaching over a landed one; a 10 m gap; and mission control, 11 m wide and two floors tall, with a dish on the roof. About 51 m end to end, or 21 seconds on foot. Each building is placed by the site's data, so the spacing can change without new art. \[Leaning\]
- What each does at first: the pad is where ships land at the base, on flattened ground; the mission computer is a terminal, like the station's gig board; the assembly building can be walked into, and later becomes where player-built ships are made, behind a flag. The tower's crew arm is art for now. \[Leaning\]
- Moon base, planned on Manny's call: the launch base's three buildings, built by the same agency for an airless moon. The hangar shelters ships from dust, sun, and tiny meteorites but isn't airtight, with a sealed control booth on its top catwalk. The tower is a lighter truss, since gravity's weak, with a sealed boarding room on its crew arm, gold-foiled fuel lines, and round propellant tanks at its foot; the pad is moon dust fused into a slab, with no flame trench. Mission control is a sealed two-floor hab entered through an airlock, with small thick windows. Roofs carry sandbags of moon dust as shielding, with solar panels, radiators, and a dish aimed at the home planet. Same sizes as the launch base, so the lander fits the hangar, but the pad stands about 10 to 13 m clear of the buildings, since a landing sprays dust. Gemini draws each one with the launch base's matching image attached for style. The prompts, templates, and reference are in `art/moon_base/source/`. \[Leaning\]
- Moon base, built 2026-11-10 from the asset editor's cleaned-up sprites of Manny's Gemini art, at 5 cm a pixel like the launch base. It stands at column 73,681, about 190 m from the point that faces the planet, so the planet hangs in its sky, on ground levelled across 76 m. Left to right: the assembly hangar, 12 m wide and 17.5 m tall, with catwalks, a ladder, and the control booth up top; 10 m of ground; the propellant tanks and service tower, with crew and fuel arms reaching over the pad; the pad, a slab set flush into the ground with 8.75 m to land on; 13 m of ground; and mission control, a rounded sealed hab 12 m wide with two floors 4.5 m apart, its lower floor and airlock hatch half a meter off the ground. About 70 m end to end. The sheet drew the pad apart from the tower, so `tools/split_moon_pad.gd` cuts it into its own sprite, without resizing, and it's marked not solid, since ships land on the ground it's flush with. The card counts only solid buildings, so it still says three. \[Leaning\]

## Hazards

Every hazard is physical, visible, and predictable: you die because you were greedy, never because the game rolled a 1. \[Locked\]

| Hazard | Cause | Counterplay | Tier |
| --- | --- | --- | --- |
| Delta-v | Limited fuel, rocket equation | Efficient transfers, staging, lighter ships | 1 |
| Impact | Approach speed and mass | Slow docking and landing, better gear | 1 |
| Atmospheres | Drag and re-entry heat | Correct entry angle, heat shields | 1 |
| Star heat | Too close to a star: hulls burn inside 6 million units of the home star | Heat shielding, radiators | 1 |
| Cold and dark | Inverse-square sunlight far out | Different power and thermal builds | 1 |
| Comms blackout | No line of sight to a relay | Plan uplinks; no updates or uplink while hidden | 1 |
| Radiation belts | Magnetic planets, gas giants | Pass through fast or route around | 2 |
| Solar flares | Warned stellar events | Shelter behind a planet | 2 |
| Rings and debris | Ring systems, belts, your own wrecks | Avoid or thread carefully | 2 |
| Surface conditions | Molten, icy, high-gravity worlds | Reinforced gear, enough thrust-to-weight | 2 |
| Depressurization | Cracked canopy or breached room | Eject, patch, or race the suit timer | 2-3 |
| Tidal forces | Black holes, neutron stars | Keep your distance | 4 |

## Camera, zoom, and landing

One continuous top-down camera with seven zoom tiers. Landing is just zooming in: there are no loading screens between space and a surface. \[Locked\]

| Tier | View | Shows |
| --- | --- | --- |
| 1 | Galaxy | Star systems, nebulae, your next destination |
| 2 | Star system | Star, planet orbits, transfers |
| 3 | Planet and moons | Local orbits, spheres of influence |
| 4 | Orbit | Your ship's orbit, maneuver planning |
| 5 | Approach | Curved horizon, atmosphere glow, re-entry |
| 6 | Descent | The ground coming up, as the ship icon, for judging a landing |
| 7 | Surface | Flat ground, terrain, pads, the pilot through the canopy |

- In 2D a planet is a circle, so zooming in turns its rim into the horizon you land on. \[Locked\]
- Tiers 2 to 7 are built. Whatever was tapped last is the focus and stays in the middle at every zoom: the home planet at the SYS zoom to start with, or a ship, station, moon, or the star. The zoom buttons land on the same stops as before, and SHIP also brings the focus back to the ship. A body can't be zoomed past filling the screen, since its middle has nothing to see. Only out past the Planet tier does the middle slide to the star, so the whole system fits. The smallest thing under a tap wins, and brackets show what was picked. This was Manny's call, and replaces the center depending only on the zoom. \[Leaning\]
- From the Orbit view in, the view turns so that down on screen is really down at whatever's in focus: toward the body below, or a nearby station's bottom within 2,000 m. The ground and stations stay flat, and the ship turning shows against them. The screen's pixels stay square, and only what they show turns. It takes a moment to swing to a new down, and farther out than Orbit, or with a body in focus, it settles back to a fixed map. This was Manny's call, and replaces the fixed camera. \[Leaning\]
- The far tiers draw each body's orbit line in agency blue and the edge of its gravity, its sphere of influence, in dark gold, both dim and behind the bodies. Manny asked for them to be told apart. An orbit line stops at that body's ring, and rails or rings too small to read aren't drawn. \[Leaning\]
- A ship rests on whatever's lowest: its feet with the legs down, or its engine bell with them up. On the ground the turn keys do nothing, and it settles upright if it's whole, so thrust lifts it straight off. A damaged ship settles on whichever side of its outline it can balance on, nearest upright, so losing a leg leaves it leaning. \[Leaning\]
- The LEGS button, or L on the Mac, swings the legs down over 2 seconds or back up. They start up, and they won't go up on the ground. Nothing deploys them for you, so forgetting means landing on the engine. \[Leaning\]
- With both legs fully down and working, a landing is clean up to 80 units/s instead of 50. Harder than that, the feet go first because they're lowest. Their pixels are real, and the struts holding them out have no pixels of their own. \[Leaning\]
- A touchdown reports LANDED (at a safe speed and within about 30 degrees of upright), HARD LANDING, or CRASH (over 250 units/s), on top of any damage. \[Leaning\]
- Close to a body, its surface sits on a grid fixed to the ground: columns around the rim and rows up from it, starting at 2 world units each. Cells double as you zoom out, so they're always 2 to 4 game pixels wide, and they don't swim as the ship or planet moves. \[Leaning\]
- Each body's rim has a seeded height all the way around: mountains in ranges with plains between them, hills, terraced cliffs, rough ground, rocks, and craters, in whole world pixels. The sea stays flat. It's invisible from orbit and fades in between 400 and 128 world units per pixel. Only the drawing fades: the ground is the same height from everywhere. \[Leaning\]
- The physics core owns those heights and hands the shader the stretch in view, so the skyline you see is exactly the ground you hit. A ship touches with whichever of its pixels meets the ground first, leans with the slope when it's resting, and ALT reads from the ground under it. \[Leaning\]
- Each zoom shows new detail: continents from orbit, then hills, then rocks. Patches of the next color come in as tiers from 4,800 units across down to about 19, and the skyline's smaller bumps come in the same way. It's also what lets you see drift up close. \[Leaning\]
- From about 300 world units per pixel in, a side view of the ground grows down from the skyline over the orbital map, filling the screen by 32: the surface color at that spot on the rim, then dirt, banded rock, deep rock, and a dark core, with stones in them. Where the map shows sea, it's water down to a bed. \[Leaning\]
- Inside an atmosphere the sky is flat bands that thin with height, from a horizon color up through the air's color into space, with pixel-pattern edges and no smooth gradients. It goes dark on the night side and warm around sunrise and sunset. Airless bodies keep a black sky. \[Leaning\]
- Seeded pixel sprites stand along the rim from 1/16 zoom in, chosen by the ground: plants, boulders, and ice on the home planet, boulders and crater rims on the moon. They're placeholder shapes, and scenery only, with no collision. \[Leaning\]
- The engine blows dust off the ground from 260 units up, in the ground's own colors. The ship's shadow lies along the terrain from 800 units up, shifted away from the star, thinning as it climbs, and gone at night. A far-off line of peaks stands behind the skyline and goes by at 0.3 of the ground's speed. \[Leaning\]
- Zooming changes what is drawn, never the pixel size: each tier swaps detail levels on a fixed pixel grid. \[Locked\]
- A second exception: from far out, a planet or moon is drawn in bigger pixels, up to 4 game pixels wide, so it reads like a sprite. Manny's call, after comparing it with one fixed pixel size. \[Leaning\]
- A third exception: a station's art pixels are 2 game pixels wide. The concept art's astronaut is 20 art pixels tall, so that's what puts it at the pilot's 40 px and makes the rooms the right size for the ship. Manny's to confirm. \[Leaning\]
- One exception: closer than the Orbit view, the ship is its normal sprite at true scale, with no smoothing and no minimum size, so it can shrink out of sight just before the icon takes over. At the Orbit view and farther it's a clean icon, and very far out it's a dot. \[Leaning\]
- Terrain detail is generated only when you zoom in close. \[Leaning\]
- Zoom moves smoothly and has no outer limit, so the ship can shrink to a single dot. The tiers set what detail is drawn at each distance. \[Leaning\]
- Interiors use an FTL-style cutaway with top-down movement inside. Built for stations, moved ahead of gigs by Manny: the roof comes off while the pilot's inside, rather than on zooming in, and goes back when they leave. \[Leaning\]
- Inside stations, the pilot walks: arrows or a drag move them at 120 units/s with no jetpack, stopping when let go. Manny's word was walks, which replaces zero-g movement inside for now. Walls are rectangles of floor set per room in the data, and rooms packed with machines are closed off. Flashlight cones in darkness, per-room pressure (a room graph, not per-pixel air), loot and logs, and destruction making new entrances are still to come. \[Leaning\]

## UI

The UI is built around seeing space, with thin NASApunk instruments floating at the screen edges. Manny reworked it on 2026-11-06 from his own mockups, which replace the earlier ones at https://claude.ai/artifact/D1QGC4XQJXpQjdn2XcpQat

UI principles: \[Locked\]

- Space comes first. Seeing space is the point of the game, so the UI never clutters the center of the screen.
- The UI is thin outlined instruments over open space, with no metal plates behind them: cyan for what's on, agency orange for BURN and targets, and stencil labels. Manny's rework, replacing the metal plates. \[Leaning\]
- The UI uses the agency palette only.
- Numbers use a pixel or 7-segment style font.
- All touch targets are at least 44 game pixels.

Top bar: \[Locked\]

- Always visible; it never auto-hides.
- Two boxes hanging from the top edge, leaving the middle open: ALT, SPD, AP, PE, and delta-v on the left, split by thin dividers, with AP and PE in orange; and the mission clock on the right, then the comms log button and the FLIGHT menu button. Manny's mockup, 2026-11-10, replacing one bar across. \[Leaning\]
- Master Caution and the pending-payout counter are still to come, once what feeds them exists. \[Open\]

Time warp: \[Leaning\]

- Built on Manny's call, 2026-11-10. Time runs at 0.5, 1, 2, 5, or 10× any time, burning included, and at 50 or 100× only while coasting, on rails: no steering or RCS then.
- The fast warps drop back to 10× by themselves, with a comms note saying why, when the coast ends: the engine on, the RCS used, near the station (within 2,000 m), in air, under 500 m over the ground, landed, docked, the pilot out, or a new body's gravity taking over. They won't start under the same conditions.
- The control sits in the clock's box: the speed, then a fast forward button. A tap on the button steps up, holding it half a second resets to 1×, and a tap on the speed steps down. On the Mac, period steps up, comma steps down, and slash resets.
- Everything simulated speeds up, the T+ clock included, while the panels, comms line, camera, and fades keep to real time.
- A moon lap takes about 14 seconds at 100×, and the star about 24.

Side panels: \[Locked\]

- Laid out to Manny's mockup, 2026-11-10, with the controls in the corners. \[Leaning\]
- Bottom right: the F and R gauges, engine fuel in orange and RCS propellant in cyan, each red when nearly gone; the notched throttle lever in a boxed track; then STAB, ASST, and ENGINE stacked. Hull and heat gauges are still to come.
- Bottom left: the RCS pad, above the zoom buttons.
- Top right, under the comms log and FLIGHT buttons: EVA and LEGS side by side, then the heading dial.
- Bottom-left zoom buttons: SYS shows the local system, and pressing it again shows the whole star system. ORBIT shows what you're orbiting, and SHIP goes to the closest view of the ship. Whichever one the zoom is on is lit.
- Along the bottom, from the zoom buttons to the gauges: the comms line, reading COMMS: and how the flight stands, like ORBIT STABLE, DOCKED, or IMPACT TRAJECTORY. Each thing that happens takes it over for a few seconds, in order, and the comms log button at the top lists them with their times. All pilot messages go here now, so the center stays clear. \[Leaning\]
- NODE joins STAB and ASST when it's built.
- Out of the ship, the only controls are the arrows and the context menu on whatever's near. On the Mac, V is EVA and F picks the menu's choice. \[Leaning\]

Context menus: \[Leaning\]

- What can be done with something nearby shows on the thing itself, from Manny's mockup, 2026-11-10, replacing the action button under the top bar: gold corner brackets around it, a dotted line out to a label, and the label with a gold diamond and the choice, such as BOARD SHIP. Tapping the label does it.
- The brackets go around what the choice is about, not the pilot: the cockpit for BOARD SHIP, a station's hatch for BOARD STATION, its inner door for EXIT STATION, a building's door for ENTER and EXIT, and the console for USE TERMINAL. They follow it as it moves and turns, and never get smaller than 18 game pixels, so something far out still shows.
- The label isn't fixed to one side, on Manny's call: each frame it tries spots all round the thing, near and farther out, and takes the one that covers least of the ship, the pilot, where the pilot's heading (the way they're being pushed, or else how they're drifting), and the thing itself. Walk toward it and it moves, usually above. Docked, it goes above or below the ship rather than over it. Beside the thing is first choice, the right before the left, then above, then below, which on a world is the dirt. \[Leaning\]
- It only moves to a new spot when that's clearly better, and it slides there, so it doesn't flicker. It always stays inside the part of the view the panels leave clear, below UNDOCK and RESTART when they're up.
- The line runs like the hold card's: straight out of the label's side that faces the thing, then straight to the brackets at whatever angle that takes. It's dotted gold with a dark edge, so it reads over a pale hull.
- The same menu serves ships, stations, doors, and boards. It can hold several choices, a row each, for when something offers more than one, like a gig board.
- UNDOCK and RESTART stay as buttons under the top bar, since they aren't about a thing in the world.
- ENGINE is orange, and hatched over while its safety cover is down. It's an on/off switch, lit solid while the engine's on, and the throttle lever sets how hard it pushes, with 0 idling. Manny's call (his brother's idea), 2026-11-10, replacing BURN, which fired while held: long burns are hands-free now, which time warp needs, and the RCS still makes small nudges. \[Leaning\]
- The first touch lifts ENGINE's cover, and each touch after that flips the switch. The cover drops again 6 seconds after the engine's off. W flips it on the Mac. \[Leaning\]
- The engine cuts out by itself on touchdown, on docking, when the pilot leaves, and when the fuel or the engine's gone, so it's never left on by mistake. \[Leaning\]
- The center stays clear for the planet, orbit line, ship, and markers.

Hiding the controls: \[Locked, auto-hide off\]

- Auto-hide is off, on Manny's call, 2026-11-10: the controls stay up until the tab at the left hides them. What follows is what hiding does, by the tab, and auto-hide can come back as a setting. \[Leaning\]

- Hidden, the pad slides off the left and the bottom-right group off the right, leaving a thin strip. The zoom buttons drop away. The top boxes, EVA, LEGS, and the dial stay.
- The strip still shows the fuel level and where ENGINE is. The comms line stays where it is.
- A small tab at the left edge is always there: tapping it hides or shows the panels, and dragging in from it brings them back. Manny's call, 2026-11-10, replacing tabs that only showed while hidden. \[Leaning\]
- Zen Mode can hide everything except a minimal top bar. \[Leaning\]

Cover screen (folded): \[Leaning\]

- Same layout and same controls as the inner screen, since both are about the same height. It just has more open space across the middle.

Menus: \[Leaning\]

- Most menus only exist when docked at a station: gig board, hangar, repairs, refuel, full map, settings. Docking is like walking into the agency office.
- In flight, the FLIGHT button opens a menu. It has Pause and Restart so far, and Manifest (active gigs and what is still undelivered), Ship (damage schematic), Map, and Settings join it as they're built. Pausing stops the flight and leaves only the way back working. \[Leaning\]
- Closing the drawer returns to the space view.

Turning and RCS controls: \[Leaning\]

- Drag to point: dragging anywhere on the space view shows a cyan heading line from the ship toward the thumb, and the ship rotates to face it using RCS physics.
- While turning, a dashed heading ring appears around the ship and fades when released.
- Drag to point works even when the side panels are auto-hidden, and leaves them hidden.
- Two fingers on open space pinch to zoom. \[Leaning\]
- RCS pad (bottom left), on every screen: four arrows in a cross that translate (forward, back, left, right), with rotate left and rotate right in the cross's top corners. Manny's call, replacing the TRANS / ROT switch. \[Leaning\]
- Translation moves the ship without turning it and is required for docking and precise landings.
- The button for ASS reads ASST, and RAW when it's off. LEGS lights up amber while the legs move and cyan when they're down, and STAB is cyan when on. \[Leaning\]
- Heading dial at the top right, on every screen, drawn like a compass to Manny's mockup: ticks every 10 degrees inside the ring, a dim crosshair, the nose as a cyan arrowhead, prograde as a cyan ring and retrograde as an orange one with a cross, spin as an amber arc along the rim, and the spin rate in degrees a second underneath. The markers hide when landed or barely moving, since there's no direction of travel to show.
- The right column is 132 game pixels wide. Buttons can be drawn smaller than 44 game pixels as long as what a finger can touch isn't.
- Translation gives the lander about 30 m/s² when full. It's too weak to lift off from the planet or the moon, and ASS doesn't cancel it. \[Leaning\]
- The RCS has its own propellant tank, apart from the engine's fuel, like Apollo's: 2,400 kg on the lander, two minutes of firing flat out. Turning, translating, STAB, ASSIST, and drag to point all use it, and with it empty the ship can't turn or translate, though the engine still burns. It refills with the fuel, at a station's port or landing at home. Manny's call, 2026-11-10. \[Leaning\]

Edge markers: \[Leaning\]

- Off-screen targets (gig destinations, stations, bodies) show at the screen edge as small agency-orange arrows with a callsign and distance (for example "KAPTEYN-3 236 km").
- There's one target at a time, set from a card. The first station starts as the target. The marker stays inside the part of the view the panels leave clear, and it goes away once part of the target could be in view. Zoomed out until it's small, the callsign and distance show beside it instead. \[Leaning\]

Control reference: the old mobile game Space Agency (rotate and translate button pads, off-screen target markers).

### Planet info

A tap on open space focuses the camera on what's under it. Holding a finger there for 0.4 seconds opens that thing's card instead, for anything that can be focused: the star, planets, moons, stations, and ships. This was Manny's call. It replaces the typewriter dossier look with a small card, beside the thing with a line to it, and a tap away closes it. \[Leaning\]

Each card has a name, a chip saying what kind of thing it is, rows of what's known, and two buttons: SET TARGET and FOCUS. Your own ship has no target button. \[Leaning\]

- A planet or moon shows its size, mass, gravity, temperature, atmosphere, moons, and day length. Gravity reads against the home planet's, which is 1.00 g.
- The star shows its size, mass, temperature, planets, and distance.
- A station shows what it orbits, its height and period, its rooms, free ports, services, and distance.
- Your ship shows its mass, fuel, RCS propellant, delta-v, hull, engine, and legs.
- The home system is named KEPLA-2, with KEPLA-2b as the home planet and KEPLA-2b I its moon. \[Leaning\]

What the card shows depends on how the player has studied the body: \[Locked for design, Tier 1\]

- Never visited: its numbers show ??? and the card says Orbit to reveal. The UNCHARTED stamp and silhouette wait on the dossier look coming back, if it does. \[Leaning\]
- Orbited it: mass, radius, gravity, day length (the orbit itself reveals the mass).
- Scanned it (requires a scanner module, which adds mass): atmosphere, surface temperature, radiation, hazards.
- Landed on it: surface type, biome, and a "visited" stamp.

Knowledge and ties to other systems: \[Locked for design, Tier 1\]

- Knowledge is saved permanently once gathered. There's no saving yet, so for now it lasts one flight.
- First to chart pays the discovery bonus.
- Survey gigs are scanning jobs.
- Landing somewhere unscanned means flying in without knowing its surface temperature or atmosphere.

## Art direction

Pixel art. NASApunk lives in the hardware and UI (Starfield's take); space itself stays clean, with no print texture. The palette is split: humans are locked, space is generated. \[Locked\]

Agency palette (locked, 26 colors) for ships, stations, suits, cockpit, and UI: \[Locked\]

| Group | Hex |
| --- | --- |
| Hull and structure | 0E0F12, 23262B, 3D4148, 6B7079, A9ADB3, E8E4DA |
| Gold foil | 5A3E12, 9C6B1E, D4A23A, F2D27A |
| Agency orange | 7A2E12, D9541E, F28A3A |
| Agency red | C8302C |
| Agency blue | 1B2E4A, 2F5D8C, 6FA3C8 |
| Canopy glass | 2A4A55, 8FC7CF |
| Telemetry | 7FE3D6 (cyan), 6BCB5A (green), F2B33A (amber) |
| Thrust and fire | FFF3C4, FFB347, E8501F |

Space palette (generated per system): \[Locked\]

- Each system rolls a small palette from its seed; each planet uses about 6 colors from it.
- Star colors come from real temperature; anomaly systems may roll colors that make no physical sense.
- Backgrounds are always very dark. Pure black only happens far from any star. \[Leaning\]
- Star tint: space takes on a slight tint of the system star's color, deeper near the star and fading toward black far from it, so the color of space shows your distance from the star. Faint stars wash out in the glare near the star and reappear far from it. It's measured from the real star at the center of the system. \[Leaning\]
- The star is a boiling disc, white hot in the middle and taking on its color toward the rim, with a stepped glow. Far out it stays at least 3 px in radius, and planets at least 2 px, so they can be found. \[Leaning\]
- The camera looks down on a planet's spinning pole, so the middle of the disc is the pole and the rim is the equator, where you fly and land. Ice sits around the middle. \[Leaning\]
- A planet's six colors split into three for the sea and three for the land, with a sea level in its data file, and coasts wander instead of forming round blobs. Colors are flat with hard edges, like the ship's art, and detail too small to read is left out so land forms clean clusters. \[Leaning\]
- The real star lights each body from one side in flat steps (day, dusk, and night), with a checker of pixels at each step from far out, so there's a day side and a night side. The night side stays readable enough to land on, and the air glows on the day side and turns warm around sunrise and sunset. Human-made things aren't shaded, so they stay on the agency palette. \[Leaning\]
- Clouds are one flat color and turn at their own speed, in bands that twist around the pole. They fade out as you come in to land. \[Leaning\]
- Airless bodies get craters at two sizes, with dark floors, bright rims, and an inside wall that catches the star. \[Leaning\]
- All of this lives in each body's data file: colors, `sea_level`, `ice_cap`, `cloud_amount`, `crater_amount`, and the air's colors. \[Leaning\]
- Background stars are a seeded shader with three parallax layers. Real stars would barely shift; the parallax is there so motion reads in empty space. \[Leaning\]

Readability rules: \[Locked\]

- Human-made objects get a 1 px dark outline.
- Telemetry cyan and agency orange belong to the agency: trajectories, warnings, and your ship's markers. Space generation avoids exact matches.
- Black holes get real drama: pixelated gravitational lensing of the background stars.

Art pipeline: \[Leaning\]

1. Describe the asset to Gemini for concept images.
2. Recreate it by hand, or hand the image to Claude to turn into a clean sprite.
3. Clean up in Aseprite: snap to grid, force the agency palette, fix edges.
3b. A concept sheet with fake pixels can go through a tool instead, like `tools/slice_station.gd`: it cuts out each drawing, drops the background and stars, reads the fake pixels back to real ones, forces the agency palette, and gives back the 1 px dark outline.
4. Ship modules are drawn on the fixed module grid, one PNG each, since their pixels are collision and damage. Small gaps in the art are fine, since they get welded when the ship is measured.
5. Inside art is drawn at the same size as the hull: a systems drawing and a bare frame drawing. Only what sits under the hull is used, since the hull's outline is the ship's.
6. Planets and space are shaders and code, not hand-drawn sprites.

## Tech

Godot 4, with GDScript for gameplay and the physics core in C++ through GDExtension. No custom engine. \[Leaning\]

Godot 4.7.2 with the Compatibility renderer, since the game is 2D and needs no compute shaders. Changing renderer is a one-line project setting. \[Leaning\]

Android builds use Godot's prebuilt template rather than a Gradle build, arm64 only, as a debug build for now. Package name: `com.emmanuelwalters.finalorbit`. \[Leaning\]

The app icon is Manny's mission patch, `art/final_orbit_icon.png`, on a plain dark layer for launchers that use layered icons. `tools/make_icons.gd` makes the layers. \[Leaning\]

Engine options:

| Option | For | Against | Verdict |
| --- | --- | --- | --- |
| Godot 4 | Strong 2D, free and open source, good Android export, double-precision builds available | C# on Android is still labeled experimental | Pick |
| Unity | Mature mobile tooling, C# | Heavier, licensing history | Fallback |
| Bevy (Rust) | ECS suits simulation | Young editor and tooling, rougher Android path | No |
| Defold | Very light 2D mobile engine | Smaller ecosystem, Lua only | No |
| Custom engine | Total control | You build rendering, input, UI, Android, tooling yourself before making a game | No |

Why C++ for the physics core: Godot's docs list C# Android export as experimental with limitations ([source](https://github.com/godotengine/godot-docs/blob/master/tutorials/scripting/c_sharp/index.rst)), while GDExtension is native code on every platform. Re-checked 2026-11-05: the Godot 4.7 docs still list C# on Android as experimental, so the core stays C++. \[Leaning\]

Architecture for flexibility: \[Locked\]

- **Interfaces between systems:** gravity, damage, generation, gigs, and camera only talk through defined interfaces, so any one can be swapped.
- **Data-driven content:** materials, modules, star types, gig types, and palettes live in data files, not code. Adding a part means adding data.
- **Event bus:** systems publish events (part detached, cargo delivered, uplink complete) instead of calling each other directly.
- **Feature flags per tier:** Tier 2-4 systems exist behind flags, so unfinished features never break the core build.
- **Versioned saves:** every save has a version number and migrations, so changing systems never wipes progress.
- **Deterministic seeds:** the same seed always generates the same galaxy, which makes bugs reproducible.

## Scope ladder

Design for all four tiers, build one at a time. Each tier is a complete, playable game, and the next starts only when the current one is fun. \[Locked\]

1. **Tier 0, Zen prototype:** one planet and moon, patched conics, a single fixed ship, trajectory preview, fold and unfold.
   - Gate: flying and landing feel good on the Fold.
2. **Tier 1, Core:** one star system, modular pixel ships with mass and destruction, cargo and data gigs, deliverable-based pay, Zen Mode, cover-screen play.
   - Gate: a single gig is fun, and a long greedy flight is tense.
3. **Tier 2, Pilot:** escape pod, repairs, salvage of floating parts and lost cargo, more hazards, Observatory Mode. The jetpack part of EVA moved up into Tier 1.
   - Gate: crashing becomes a story, not just a loss.
4. **Tier 3, Interiors:** enterable derelicts, pressure, darkness, loot. Walking around a station moved up into Tier 1, since gigs get picked at a terminal.
5. **Tier 4, Big universe:** many star systems, galaxy view, black holes, rogue planets, maybe combat, maybe n-body physics.

## Open questions and parking lot

Open questions:

- [ ] Name of the game: decided, Final Orbit
- [ ] Destroy gigs: real combat with armed ships and AI pilots, or only non-combat targets (dead satellites, derelicts, rogue asteroids)?
- [ ] Pilot identity: named character, customizable, or anonymous?
- [x] Exact internal pixel resolutions for the inner and cover screens: 816 x 616 at 3x on the 2448 x 1848 inner screen and 986 x 624 at 2x on the 1972 x 1248 cover screen, from the screen fitting rule under Platform. Sizes confirmed on the device 2026-11-05.
- [x] Module grid size: 64 x 64 px. The lander fills 2 x 4 cells.
- [ ] Touch controls for maneuver planning. Burns and rotation are settled in the UI section.
- [ ] Economy numbers: gig pay, ship prices, repair costs, tow cost
- [x] C# on Android stable yet, or stay with C++ GDExtension? Still experimental in Godot 4.7 (checked 2026-11-05); stay with C++
- [ ] Starting conditions: first ship, starting money, home station
- [x] The lander doesn't fall engine-first by itself (see Aerodynamics): left as piloting for now, held with STAB while the air allows and turned for the burn once it's slow. Its mass stays where it is. Nose fins were drawn in the asset editor and then cut: Manny didn't like how they look. Manny's call, 2026-11-10.
- [x] STAB's along-the-path direction inside the landing zone: switched to the turning ground's frame, like the dial (see Flight modes). Manny's call, 2026-11-10.

Parking lot:

- A story or mystery that surfaces through uncharted signals and derelict logs \[Cut for now: pure sandbox\]
- Multiplayer or co-op \[Cut: single player\]
- Half-folded Mission Control console \[Cut: no Flex Mode on Fold 8; revisit for Fold 8 Ultra or later\]
- Full n-body physics, Lagrange points, free-return loops \[Tier 4, behind the gravity interface\]
- NASApunk print texture on space \[Cut: NASApunk stays in hardware and UI\]
- Water: the sea is only a color for now, so you can land on it like ground. It could splash down, sink, or be off limits \[For later: Manny's call\]
- Burn point: a mark on the predicted path where the landing burn has to start to touch down safely \[Not built: a piloting aid, only if Manny wants it\]
- Dim line past a moon's sphere of influence: the rest of the orbit keeps drawing faintly beyond the ring, so you can watch it shrink during a capture burn \[Not built: capture is meant to take some skill\]
