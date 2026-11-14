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
| 2026-11-14 | Settings built, on Manny's pick: SETTINGS on the title, no longer marked SOON, and on the FLIGHT menu, opens one screen: each sound channel's volume in tenths, haptics, the helmet lamp (AUTO, ON, or OFF), and hiding the controls when idle, off by default. Kept in their own file, for normal play and Zen alike \[Leaning\] |
| 2026-11-14 | Lighting begun, on Manny's call, for tense derelicts: art is shaded by stepping each pixel down its own ramp in the agency palette, dithered between steps, so it never leaves the palette; lights and screens glow. Ticket 1 built: Kapteyn-3's insides lit by ceiling lamps. A derelict's lamps are off. Walls blocking light, the helmet lamp, and hiding what's out of sight come next. Gemini's pitch to shade hulls the same way is answered under Lighting \[Leaning\] |
| 2026-11-14 | The pilot is the same size inside a station as outside, on Manny's call: inside they'd been drawn at the station's art pixel size, twice their real size. Walking inside already used their real size. Their pixels are now half the size of the station's \[Leaning\] |
| 2026-11-14 | Death settled further, on Manny's calls: losing the ship counts as death only when the pilot dies with it, and the med bay's bill depends on how badly they died. The creature became the goo: a huge black mass that absorbs and digests what it touches, chases, stalks, grabs, and pulls itself along walls in large derelicts \[Leaning\] |
| 2026-11-14 | Death and the med bay planned, on Manny's call: dying never wipes the world, since starting over is a motivation killer. The pilot wakes in a med bay and gets the bill; whatever the credits can't cover, the agency's repo squad settles by selling the player's ships, so they leave debt free with whatever's left. EVA deaths are driven by physics: impact bands, burning up in air, the star, hard hits, and a suit breach that leaks air against an O2 gauge. The pilot feels air like debris does. The visor crack from the first sketch is dropped: at 37 px the visor is a few pixels, so frost, a plume of frozen air, and going limp carry it instead \[Leaning\] |
| 2026-11-14 | Rare station-dwelling alien creatures parked as Manny's idea for a first threat: one procedural, tentacled creature in one derelict, for investigation, pursuit, and escape rather than combat, with warning signs and behavior that can be learned. Waits for derelicts \[Leaning\] |
| 2026-11-14 | Zen Mode gets gigs and pay back, on Manny's call: "Zen mode should let the player do as they want just stress free". Fuel, propellant, gas, repairs, and the hangar stay free, and only the calm events come up: signals and comets. Replaces "no gigs, no pay" in the locked Zen line \[Locked\] |
| 2026-11-14 | Mid-flight events planned, on Manny's call: they're opportunities, never forced on the pilot; each is picked up far enough out to change course for; and the ones that can be come back to stay listed and focusable until they're done. Uncharted signals, distress beacons, and passing comets come first. A stranded astronaut is rescued by grabbing their hand on EVA and jetpacking them back to the ship. Derelicts wait for salvage in Tier 2. Solar flares wait for Tier 2 too, as the hazards table has them, since sheltering from one needs radiation and crew health, which don't exist yet \[Leaning\] |
| 2026-11-12 | Landing legs reworked, on Manny's call: each leg has a shock absorber with its own stroke and how hard a landing it soaks up, so a ship's safe landing speed comes from its working legs; they squeeze on touchdown, spring back to a sag, and on uneven ground each meets its own ground so the ship sits nearer level. How wide a ship stands is measured from its feet \[Leaning\] |
| 2026-11-14 | Moon Hopper added as a third ship, the first through the Gemini concept → Asset Editor → game pipeline. The game measures its dry mass at 14.3 t against the editor's 8.1 t, since colors set materials in the game; Manny accepted the game's figure \[Leaning\] |
| 2026-11-12 | The Lander Mk II added as a second ship, designed by Fable in the Asset Editor from a brief, with a stand-in hangar on Manny's call: a SHIPS tab on the station's terminal trades the docked ship for another, free for now. Each ship waits in the hangar as it was left. A ship mall where ships are bought, walked through like a dealership, is the plan for later \[Leaning\] |
| 2026-11-12 | Landing at home no longer refills the tanks, on Manny's call: the launch base's Vehicle Assembly building has a paid service terminal instead, the same screen as the station's. Each terminal only serves a ship docked there or on its pad \[Leaning\] |
| 2026-11-12 | Prices built, on Manny's call, from his sketch of the service terminal: docking no longer refuels or repairs; a terminal in the docking room sells both, in REFUEL and REPAIRS tabs, with the ship drawn and a tooltip on each tank or damaged part. First numbers: fuel 0.15 Cr/kg, RCS propellant 0.5 Cr/kg, repairs by part, and a 5,000 Cr credit line so nobody is stranded at the station. Free in Zen Mode \[Leaning\] |
| 2026-11-12 | Zen Mode built: its own world and save, swapped in behind the title; fuel, RCS propellant, and jetpack gas never run out; no gigs or pay; a lost ship isn't kept, so the next Zen flight starts fresh; and ambient music from a track list waiting for Manny's Suno tracks. Time warp works as in normal play \[Leaning\] |
| 2026-11-12 | The title copied exactly from Manny's mockup, on his call: its letters and orbit measured off the mockup in its own pixels. Sharp stencil letters, cut where the mockup cuts them, with only the O and the bowls of R and B round; the orbit is the ellipse fitted to the mockup's, crossing over ORBIT and passing behind the word, showing only at its ends. The title and menu sit 48 px in, as in the mockup \[Leaning\] |
| 2026-11-12 | The title's lettering and orbit redrawn as pixel art, on Manny's call: painted at a third of the game's resolution and drawn scaled up, with rounded bowls, one-pixel stencil gaps, shaded bottoms, and outlines, and an orbit with stepped edges, thicker in front, that weaves in front of the O and behind the other letters \[Leaning\] |
| 2026-11-11 | Title screen built to Manny's mockup: FINAL ORBIT in stencil letters with an orange orbit, the menu with two taps, the saved moment frozen behind it framed on its body, NEW FLIGHT swapping a fresh start in behind the menu and back, and going in sliding everything off and zooming into the ship. RESTART is now TITLE. ZEN MODE and SETTINGS show dimmed, marked SOON. The HUD font gets a middle dot \[Leaning\] |
| 2026-11-11 | Saving built: one file per world, written every 10 seconds aboard, when docking, landing, stepping out, or losing the ship, and when the app goes to the background; credits and gigs save the moment they change. A flight comes back where it was: in orbit, landed without touching down again, docked, or lost. Until the title screen, RESTART starts a new flight and throws the save away \[Leaning\] |
| 2026-11-11 | Saving and the title screen decided, on Manny's call, from his title screen mockup: the game saves only while the pilot's aboard, with credits and gigs saved whenever they change; a lost ship is saved as it is and left to the player; normal play and Zen Mode are separate worlds; the title screen is the saved moment frozen behind a menu that takes two taps, and going in zooms into the ship \[Leaning\] |
| 2026-11-11 | Crash sounds built, building with how bad the hit is: a knock for a bump, a thud and grinding then the frame groaning for damage, a crack for each part lost with debris rattling after, and for a lost ship one huge impact, then silence but for radio static. Outside, crashes are heard only across air. Sound is done for now; the wind waits for planets to get their real environments \[Leaning\] |
| 2026-11-11 | The cockpit's buttons are silent except ENGINE, on Manny's call; the wind is a darker, softer whoosh at about half its old loudness \[Leaning\] |
| 2026-11-11 | No breathing in the suit, on Manny's call: on foot it played nonstop and sounded like the RCS \[Cut\] |
| 2026-11-10 | Sound tickets 3 and 4 built: air opens the muffled sound up with its density, with wind from moving through it, a breeze standing in it, a roar growing with re-entry heat, and the ship's engine heard across it from outside; on EVA or on foot, the pilot breathes, the jetpack hisses, and the suit's microphone is clearer than the hull \[Leaning\] |
| 2026-11-10 | Sound ticket 2 built: the ship through its hull, muffled, with the engine's rumble deepening and swelling with the throttle, RCS hiss, leg motors, touchdown thuds, crunches, and docking clunks, all silent once the pilot's out in vacuum; the phone buzzes on touchdowns and hits and purrs faintly while the engine burns \[Leaning\] |
| 2026-11-10 | Sound planned and begun, on Manny's call: space is silent, so you hear what the pilot hears, through the hull, the suit, or real air; cockpit clicks and radio sounds; music in Zen Mode; haptics. Sounds are made by the game until recordings are dropped in. Ticket 1 built: the sound director, channels, clicks, and radio \[Leaning\] |
| 2026-11-10 | Context menus get smaller zoomed out, on Manny's call: full size at 1/2 and closer, a compact one with small text out to 1/32, and none past that \[Leaning\] |
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

Zen Mode: gigs and pay as in normal play, but with unlimited fuel, free services, free time warp, ambient music, and only the calm mid-flight events. It doubles as the physics test bed. Gigs came back on 2026-11-14, on Manny's call: Zen lets the player do as they like, stress free. \[Locked\]

How Zen Mode works, built 2026-11-12: \[Leaning\]

- It's its own world with its own save, picked on the title like NEW FLIGHT: the view pulls out, the Zen world comes in behind the menu, and the second tap goes in. The first Zen flight starts where a new flight does, in orbit near Kapteyn-3. TITLE from Zen comes back to the Zen world.
- Fuel and RCS propellant never run out, and nor does the jetpack's gas. A holed tank still loses what's in it, since damage is physics.
- Gigs and pay work as in normal play, with Zen's own credits, since Zen is its own world. Fuel, propellant, repairs, and trading ships are free. (Until 2026-11-14 Zen had no gigs, and its terminals said NO GIGS IN ZEN MODE.)
- Only the calm mid-flight events come up: uncharted signals and passing comets, not distress beacons.
- Time warp is the same as in normal play, which costs nothing already. The fast warps still only run while coasting, since that's what keeps the physics right.
- A lost ship isn't kept: leaving it, the Zen save goes, and the next Zen flight starts fresh. Normal play keeps its wrecks.
- Music plays only here (see Sound).
- Hiding everything but a minimal top bar is still to come.

Single player only. Pure sandbox for now, no story. \[Locked\]

## Gigs

Decided 2026-11-10, on Manny's call, from his mockups of the gig board and the active-gig tracker. \[Leaning\]

- Tier 1 starts with cargo and survey gigs. Destroy or disable gigs wait on the open question about combat, and salvage (detaching parts from wrecks) is Tier 2.
- Gigs only go to places that exist: the station Kapteyn-3, the launch base, the moon base, and survey spots on the planet and moon. Lagrange points wait on n-body physics.
- The station is named Kapteyn-3, callsign KAPTEYN-3, from Manny's mockup, replacing Home Station.
- Cargo rides in the lander's cockpit, up to 3 tonnes, and weighs what it says: a 2-tonne load costs about 40 m/s of delta-v and some thrust. A cargo module can come later with its own art.
- Pay is in credits, Cr. A run starts at 0 Cr, and a gig pays when its deliverable arrives, as the payment rules say. Fuel and repairs cost credits at the station (see Prices).
- One active gig at a time to start; chaining several, as the core loop has it, comes once the first gig plays well.
- Credits, the gig taken, and which gigs are gone from each board are saved (see Saving and the title screen).

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

## Mid-flight events

Decided 2026-11-14, on Manny's call. \[Leaning\]

- Events are opportunities, never forced on the pilot: something to go after for credits and data, or to leave be. Hazards stay what the hazards table says: physical and predictable.
- Each one is picked up far out, at least about 7 km away, since changing course takes planning. It comes in on the comms line, with what it is, where, and how far.
- The ones that can be come back to stay on a list, and can be focused and targeted, until they're done: a signal until it's charted, and an astronaut until they're rescued. A comet only stays while it's passing.
- Events come only while the ship's flying: not docked, and not landed. A roll every so often, more often the longer nothing's come up, and never more than four open at once. Each one of a kind already open halves the chance of another of it, so runs of the same kind are rare. Each roll comes from the seed and how many rolls there have been, so the same seed gives the same events. Event types are data, in `data/events/`.
- Every event can be tapped, focused, and held for a card, like a station, and a card's TARGET makes it the target. Under the gig tracker, an EVENTS list shows each open one, how far it is, and what it needs next, and a tap on a row focuses and targets it. Its header folds it to an EVT tab, like the gig tracker. Open, it shows only as many rows as fit above the panels' tab on the left edge, the target among them, with 2 OF 4 and so on in its header.
- Something new turning up drops the time warp to 1×, so its call isn't gone by before it's heard.
- Uncharted signals: a source on the ground of the planet or the moon, kept off the seas and the bases. Its card knows only that something's there until it's charted. Flying or landing within 300 m offers SCAN SIGNAL; the scan runs whenever the ship's within reach, keeping what it has when it leaves, and once it's whole the data uplinks by itself with a relay in sight, like a survey's. Charting pays for the data, and a bonus for being first to chart it, and the anomaly stays on the map for good, by name.
- Distress beacons: an astronaut adrift in orbit round the world the ship's near, the same way round as the ship, waving, with their suit's beacon blinking red. No air clock: they wait until they're found. Within 100 m the ship's speed reads against them (REL, SURVIVOR CLOSE), and within 20 m the pilot's does. Match their orbit, go out on EVA, and GRAB HAND within 2 m, drifting at under 1.5 m/s against them. Holding hands, they float at the pilot's right with an arm out to each other, and the pilot carries their mass too, so the jetpack pushes half as hard and its gas goes half as far. Boarding the ship takes them aboard, where they weigh 120 kg like cargo, but aren't cargo; LET GO leaves them drifting. Bringing them to Kapteyn-3 or a base, docked, landed on its pad, or in through an airlock or door, pays the rescue, 3,500 Cr. Losing the ship with them aboard loses them. Someone held when the world's saved comes back adrift where they were.
- Passing comets: a lumpy nucleus, lit on the side toward the star, in a faint coma, with a tail streaming straight away from the star, on a flyby of the planet. It's named when it's picked up (C-01, C-02, and so on), 12 to 18 minutes before its closest pass, which comes 2 to 8 km up, and the comms line, the card, and the events list count down to it. Three in four go the same way round as the ship, which makes them far easier to fly through. Inside the coma, within 1 km of the nucleus, with the pilot aboard, it scans by itself, a little at a time: 10 seconds in all, kept between passes. The data uplinks like a signal's, paying 3,000 Cr and 1,000 Cr for being first. Once it's passed and left the planet behind, it's gone, unless its data's still aboard, waiting for a relay. Its colors are its own data, being nature's.
- The nucleus isn't solid yet: the ship flies through it. \[Open\]
- Targeting or focusing a comet or someone adrift draws where they're headed as a dim dotted line: the comet until well past its closest pass, and the astronaut for one lap.
- Later: derelicts, with salvage (Tier 2), and solar flares (Tier 2, as the hazards table has them): sheltering behind a planet only matters once there's radiation and crew health.

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
- Coming down on EVA at 80 units/s or less, the pilot lands on their feet and walks. Faster knocks them down, and faster than 160 kills them (see "Death and the med bay"). \[Leaning\]
- Standing anywhere along a landed ship's width, under it or beside it, offers BOARD SHIP. Away from the ship, the way home marker points to it, and the comms line reads ON FOOT. If the ship isn't landed on the same world, the pilot's stranded and TITLE shows. \[Leaning\]
- Being tried: a low-poly 3D astronaut in place of the sprite sheets, built in code from simple shapes on a joint hierarchy, rendered live into a small canvas at 1 px per 5 cm, with every pixel snapped to the agency palette and a 1 px outline. One model would give the side view on worlds, the view from above in stations, and any angle in space, and code would animate it all the time: the stride from speed, feet planted on slopes, reaching, and tumbling. The risks are pixels flickering as it moves and less detail than the drawings. Claude Fable 5.2 builds the model from `art/pilot/source/model_prompt.md`, and it's compared beside the sprite before deciding. \[Open\]
- The 3D pilot in the game, behind `FeatureFlags.PILOT_3D`, on for now: `scripts/pilot/astronaut_view.gd` renders the model into a 64 x 64 canvas at 1 px per 5 cm, already turned to its angle on screen so its pixels stay square. A shader snaps each pixel to the suit's agency colors and outlines the outside in the darkest gray. A second render of distances adds a line wherever one part passes in front of another, and shades the far side of the body darker, the way pixel artists shade the far arm and leg. Code poses the joints every frame: standing, a stride that follows speed, crouching to jump and land, tucking in the air, a jetpack pose, and a slow drift in space. The jetpack's thrusters are at the corners of the pack and puff cold gas in the ship's RCS colors, not flames: each push fires the corners that trail it. On worlds it's seen from the side, turning through the front when it changes direction. On EVA it floats upright, seen from above with the helmet toward the camera, and leans into a push, not a turn, until it's nearly flat, seen from the back with its head the way it's pushing, and straightens up again when let go. The puffs come from whichever corners of the pack trail the push, and a turn fires the two corners farthest apart. Inside stations it's seen from above at the station's pixel size, 2 game pixels per pixel. Turned off, the sprite sheets come back. \[Open\]
- The 3D pilot's model is built, in `scripts/pilot/astronaut_model.gd`: 1.85 m tall, 19 joints the game turns by name, 7 attachment points (visor, hands, soles, jet nozzles), about 1,900 triangles, and colors from the agency palette. The visor wraps round to the sides of the helmet, about 0.6 m across where the prompt said 0.4, because a visor only on the front is a 2 px sliver from the side and the sprite's covers the front half of the helmet. Each shoulder's patch is a plate on the shoulder itself, and its dark ring sits on the chest round the armhole, so the shoulder stays white from the side. In a rough preview the model read much better with dark lines where one part passes in front of another, not only round the outside, so the shader should try that. Still to come: the pixel renderer, the palette and outline shader, the animation, and the comparison. \[Open\]
- The suit has its own limits: oxygen, temperature, jetpack fuel. Only the jetpack is built so far. An O2 gauge comes with suit breaches (see "Death and the med bay"). \[Leaning\]
- The pilot can carry a name, suit livery, and career record. \[Open\]

Death and the med bay, decided 2026-11-14 on Manny's call. Nothing built yet. \[Leaning\]

- Dying never wipes the world: starting over is brutal and a motivation killer. The run ends, as the core loop says, but the world goes on.
- The pilot wakes in a med bay at Kapteyn-3 and gets the bill, in the agency's cheerful voice. Whatever the credits can't cover, the agency's repo squad settles by selling the player's ships, and later anything else they own, so they leave debt free, with whatever's left. In Zen Mode it's free.
- Death is saved the moment it happens. Today the flight only saves while the pilot's aboard, so dying on EVA would otherwise come back as the moment they stepped out.
- Deaths come from physics, never a canned animation. At the moment of death the pilot becomes a body on the same physics as everything else, so each one plays out differently: it tumbles at the spin it had, slides and settles lying along the ground, or drifts off on its orbit. Only three things are made by hand: a limp pose, a burst at the moment that depends on the cause, and the radio cutting to static.
- Landing bands on EVA, in data: up to 4 m/s, on their feet; 4 to 8 m/s, a hard landing that knocks them down and scrapes the suit into a slow leak; over 8 m/s, fatal, with a dust burst sized by the speed. That's a fall of about 3 m on the planet or 11 m on the moon, and the jetpack can't hold anyone up against either, so stepping out of a hovering ship is a real decision.
- The pilot feels air like debris does: drag, and the same burn-up rule. Out of orbit into air, they glow in the ship's re-entry colors, streak like a little comet, and burn up in sparks. Slowed by the air, they still die on landing.
- Into an airless world from orbit it's a landing at full speed: the biggest dust burst, the body thrown tumbling. The star overheats the suit long before contact: a glow to white, then a flash.
- A hard hit in space, into the station or the ship or by debris, knocks them away limp and spinning, with a puff of frost where it hit. Softer hits scrape the suit instead.
- Suit breaches, from hard landings, debris, or later creatures: a white plume from the hole that pushes like a leaking thruster, and an O2 gauge counting down while the visor frosts over. At zero the thrusters stop, they go limp, and the plume dies away. Getting inside the ship, the station, or a base stops it. A crack shows on the HUD's suit gauge, not on the visor, which is a few pixels at 37 px.
- Built, ticket 1: dying. Landings on EVA and falls on foot go by the bands: up to 4 m/s on their feet, to 8 m/s a hard landing that knocks them down, past that dead, the body stopped dead by the ground and settling there, lying on its back, limp. A fall of about 3 m on the planet kills. The pilot feels air like a debris chunk: falling through the planet's air near the ground holds them to about 16 m/s, and coming in at orbital speed they burn up in sparks and nothing's left. Too near the star they burn up too. A hit on the station past the fatal speed kills. Dying throws dust up from the ground, a puff of frost in space, or sparks; the radio goes to static; the comms line says SIGNAL LOST and the cause, such as IMPACT 20.1 M/S; and anyone held is let go. How bad it was is kept, from 0.3 for a death just past the fatal speed up to 1 for burning up, for the bill.
- Built, ticket 2: the suit's air. A hard landing, or a knock on the station between the safe and fatal speeds, puts a hole in the suit: SUIT BREACHED · O2 LEAKING. Each hole leaks the suit's air, 90 seconds of it for one hole and half that for two, and vents a white plume that pushes like a small thruster going the other way. With the suit leaking, an O2 bar takes the R bar's place beside the throttle, and the visor frosts over in two steps as the air goes, pale and then white. Boarding the ship, the station, or a base's building patches the suit and fills it up. Out of air, they die: AIR RAN OUT, the cheapest death, at 0.1, since the body's whole. Breathing alone doesn't run the suit down yet.
- Built, tickets 3 and 4: the med bay. About four and a half seconds after dying, the med bay screen comes up over everything: MED BAY, KAPTEYN-3 // RECOVERY, WELCOME BACK, PILOT!, what they were lost to, NOW LET'S TALK FEES!, and the bill: RECONSTRUCTION, 1,500 Cr plus up to 6,000 more the worse the death, and TOW TO KAPTEYN-3, 1,500 Cr, or a NEW LANDER at its parts' worth, 30,000 Cr, if their ship's gone. Their savings pay what they can, and THE REPO SQUAD SETTLED the rest: YOU'RE OUT OF HERE DEBT FREE! A DREAM COME TRUE! In Zen Mode it's on the house. Dying fails the gig under way, with its cargo. [ BACK TO WORK ] (or F) puts them in Kapteyn-3 by the docking port, their ship towed home and docked there, or the new one, and the suit patched. The death, and the bill once charged, are saved the moment they happen, so closing the app comes back to the med bay, charged only once. The prices are in `data/service_prices.tres`.
- Out of jetpack gas is still stranded, not dead.
- Every death ends the same: radio static, SIGNAL LOST and the cause on the comms line (IMPACT 12 M/S, BURNED UP, AIR RAN OUT), the HUD fading, and the camera pulling out slowly.
- Losing the ship counts as death only when the pilot dies with it: a destroyed cockpit, the way a ship's lost now, or the star. Manny's call. Built, ticket 5: a cockpit destroyed with the pilot aboard kills them, CRUSHED, at 0.8, or BURNED UP near the star, and the med bay bills a new ship. \[Leaning\]
- The bill depends on how badly they died, on Manny's call. \[Leaning\] How it's measured, proposed: the med bay rebuilds the pilot, so the less that's left, the more it costs. At the moment of death the physics already knows how bad it was, and that sets a share from 0 to 1: air running out leaves the body whole, the cheapest; an impact scales with how far over the fatal speed it was, or the hit's energy for a crushed cockpit; burning up or the star leaves nothing, the dearest. The bill is a flat part plus that share of a top-up, in data with the other prices, and it comes itemized in the agency's cheerful voice. Manny agreed 2026-11-14. \[Leaning\]
- With no ships to sell, the rest is written off: until ships are bought, at the ship mall, nothing's the player's to sell, so the repo squad takes the credits there are and the agency writes off the rest. They leave at 0 credits, debt free; a debt they already had stays. \[Leaning\]
- A fall forecast for the pilot (SAFE, HARD, or FATAL), like the ship's landing forecast. \[Not built: a piloting aid, only if Manny wants it\]

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
- The Lander Mk II, the second ship: the Lander's shape cleaned up and made symmetric, with a capsule cockpit, RCS clusters standing clear of the hull, foil tank drums, and sturdier legs with broad foot pads that stand on about 32 to 36 degrees of slope. Same engine, RCS, fuel, and nearly the same mass (19,386 kg dry against 19,491) and center, so it flies the same, turning about 5% slower with its legs up and 12% with them down. Fable drew it pixel by pixel in Manny's Asset Editor from `docs/briefs/lander_mk2_in_asset_editor.md`. Its art is in `art/lander_mk2/` and its design in `data/lander_mk2_design.tres`. \[Leaning\]
- The Moon Hopper, the third ship, and the first through the Gemini concept, then Asset Editor, then game pipeline: a bubble-cab one-seater on a squat 3 x 2 grid, with side tanks, a single centered bell with a tail nozzle each side, and wide legs. The game measures it at 14.3 t dry (body 12.7 t, legs 1.65 t) because dark grays read as steel, while the editor's own figure was 8.1 t with explicit materials; Manny accepted the game's figure on 2026-11-14. Fuel 14,400 kg in two tanks, 10,400 m/s of delta-v, engine 2,436 kN: 0.85 of the home planet's pull empty, so it can't lift off home, and 1.37 times the moon's pull full with its 1 t of cargo. It turns 1.5 times as fast as the Mk II full, legs up, and slides sideways at a quarter of its engine force. Legs are the original Lander's cheaper shocks (6 px, soaking 62.5). Its art is in `art/moon_hopper/` and its design in `data/moon_hopper_design.tres`, from `docs/briefs/moon_hopper.md`. \[Leaning\]

The hangar, a stand-in for now: \[Leaning\]

- The station's service terminal has a third tab, SHIPS, listing the ships in `data/ship_list.tres` with each one's picture and numbers. FLY trades the docked ship for the picked one, free for now. The new ship docks on the same port, with the cargo moved aboard.
- The hangar keeps each ship as it was left, its damage and fuel, so trading doesn't repair or refuel anything. A ship never flown comes new, whole, and full. The save keeps which ship is flown and how the others were left.
- Later, on Manny's call, it becomes a ship mall: a place to walk through, buy a ship, and take it away, like a dealership. \[Open\]
- Fuel is bought, at the station's docking room or the launch base's assembly building (see Prices). Landing at home doesn't refill the tanks any more. \[Leaning\]
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
- Fuel is shared across the tanks. A tank can only hold as much as is left of it, so losing pixels loses that share of its fuel at once. What remains leaks at up to 2,000 kg/s depending on the hole, and pushes the ship away from the hole. Lost capacity stays lost until the ship's repaired.
- Cockpit under half its pixels means the ship is lost, until the escape pod in Tier 2. The ship stops responding and stays where it is as a wreck. Touching the star destroys everything.
- TITLE appears when the ship is lost, has no engine, or has no fuel, and goes back to the title screen, where NEW FLIGHT starts over. It was RESTART, starting a new flight, until the title screen.
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
- The line's end says what touching down there means, in small stencil text with the speed beside it: SAFE at or under the safe speed for the legs as they are, on ground the ship can stand on; HARD up to 250 units/s; CRASH above that; or BURN-UP if the hull passes the top of the heat scale on the way. Speeds are measured against the turning ground. Ground is too steep to stand on when the ship's center of mass would be outside its feet, measured from each ship's own outline: how far its outermost feet reach, or the engine bell's edge with the legs up. The comms line reads the same, as SAFE TRAJECTORY, HARD TRAJECTORY, CRASH TRAJECTORY, or BURN-UP TRAJECTORY, in place of IMPACT TRAJECTORY.
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
- Docking draws the ship the last bit into place. Fuel and repairs are bought at the docking room's terminal (see Prices). UNDOCK, or U on the Mac, lets it drift off backward at 3 m/s. \[Leaning\]
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
- Each leg has a shock absorber, set in its module data: its stroke, how far it squeezes before it bottoms out; how hard a landing it soaks up; and how far it sags under the ship's weight. A ship's safe landing speed adds its working legs' share of what they soak to what its hull takes, so the Lander's two legs (6 px stroke, soaking 62.5) and its 50 hull make 80, losing a leg brings it down toward the hull's, and the Mk II's sturdier legs (8 px, soaking 75) make 90. Harder than the safe speed, the feet go first because they're lowest. Their pixels are real, and the struts holding them out have no pixels of their own. \[Leaning\]
- Each shock absorber is a damped spring. A touchdown squeezes the legs as fast as the ship hit, and they spring back to sag under its weight (about a third of their stroke with full tanks, less as fuel burns), so the hull dips onto its legs and rises a little. A gentle landing squeezes about half the stroke, a firm one most of it, and too hard bottoms them out. In the air they stretch out again. \[Leaning\]
- On uneven ground the leg over higher ground squeezes more and the other less, so the ship sits nearer level than the ground under its feet, as far as the stroke allows: on a slope of 7.5 degrees across its feet the Lander stands at 5. \[Leaning\]
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
- It only moves to a new spot when that's clearly better, and it slides there, so it doesn't flicker. It always stays inside the part of the view the panels leave clear, below UNDOCK and TITLE when they're up.
- The line runs like the hold card's: straight out of the label's side that faces the thing, then straight to the brackets at whatever angle that takes. It's dotted gold with a dark edge, so it reads over a pale hull.
- Zoomed out it gets smaller, like everything else, on Manny's call: full size at 1/2 and closer, then a compact one with small text, a tighter box, and shorter brackets and line, out to 1/32. Past that, at the orbit view and out, where the world's a few pixels, it isn't shown, though F still picks it on the Mac. It steps rather than shrinking smoothly, since the stencil text only comes in whole sizes. \[Leaning\]
- The same menu serves ships, stations, doors, and boards. It can hold several choices, a row each, for when something offers more than one, like a gig board.
- UNDOCK and TITLE stay as buttons under the top bar, since they aren't about a thing in the world.
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
- In flight, the FLIGHT button opens a menu. It has Pause and Title so far, and Manifest (active gigs and what is still undelivered), Ship (damage schematic), Map, and Settings join it as they're built. Pausing stops the flight and leaves only the way back working. \[Leaning\]
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
- The RCS has its own propellant tank, apart from the engine's fuel, like Apollo's: 2,400 kg on the lander, two minutes of firing flat out. Turning, translating, STAB, ASSIST, and drag to point all use it, and with it empty the ship can't turn or translate, though the engine still burns. It refills with the fuel, bought at the station or the launch base. Manny's call, 2026-11-10. \[Leaning\]

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

- Knowledge is saved permanently once gathered. For now that's which worlds have been visited.
- First to chart pays the discovery bonus.
- Survey gigs are scanning jobs.
- Landing somewhere unscanned means flying in without knowing its surface temperature or atmosphere.

## Sound

Decided 2026-11-10, on Manny's call. \[Leaning\]

- Space is silent, so you hear what the pilot hears. Aboard, the ship sounds through its hull, muffled and low: the engine's rumble following the throttle, the RCS thrusters, docking, touchdowns, and parts breaking. On EVA, the suit: the jetpack's hiss and the radio. No breathing \[Cut\]. In air, real sound opens up with the air's density: wind, the engine's roar, and re-entry. The moon stays quiet all the way down.
- The cockpit's buttons are silent, except ENGINE: its cover flips up with a snap and its switch clunks. The throttle lever ticks as it moves notch to notch.
- The comms line has a radio: a burst of static and a blip with each message, two falling tones for a caution in amber, an alarm for a loss in red, and a chime when a gig pays.
- Music is ambient, in Zen Mode. Normal flight stays mostly silent, so the engine and alarms land.
- How music is built: the tracks are listed in `data/music_set.tres` (Manny's Suno tracks, to come). They play shuffled, never the same twice in a row, each fading up and away, with 20 to 60 seconds of quiet between them so the music comes and goes. With none listed, Zen is silent but for the ship.
- Crashes build with how bad the hit is, heard as the pilot hears it: a gentle bump knocks through the hull, louder the harder it is; a hit that does damage thuds and grinds, and the frame groans after; each part that breaks off cracks, deeper for a bigger part, with debris rattling against the hull after. Losing the ship is one huge impact, then every ship sound cuts out at once, leaving the radio's static and the alarm. Outside, a crash is heard only across air, like the engine; on the moon it's silent. \[Leaning\]
- The phone buzzes too: touchdowns, a jolt for each hit matched to how hard it was, a stutter of taps for debris, a long one for losing the ship, and a faint purr while the engine burns.
- The wind is a placeholder until planets get their real environments; it's to be redone then, since each world's air will sound different. \[Open\]
- One sound director plays everything by listening to what happens, through signals, so no other system knows sound exists. Four channels, each with its own volume for a settings screen later: Effects for the ship and the world, UI for the cockpit, Radio for the comms, and Music.
- Sounds are data: `data/sound_set.tres` names a sound for each event, and any it leaves empty is made by the game itself (`scripts/audio/sound_synth.gd`), from shaped noise and tones, so the game has sound before it has recordings. Recordings can replace them one at a time.
- How it's built: the Effects channel's filter sits at 650 Hz through the hull and 3,500 Hz through the suit's microphone, and opens toward 9,000 Hz with the square root of the air's density. Wind grows with how fast the ship or pilot moves through the air, a full gale at about 20 m/s at the ground's density; standing outside in air there's a light breeze. The re-entry roar follows the heat. Outside, the ship's engine, RCS, and legs carry across air only, fading out by 100 m. \[Leaning\]
- Every sound the game makes itself is made at start on another thread, so nothing waits for one mid-flight.
- Time warp doesn't change sounds' pitch.

## Settings

Built 2026-11-14, on Manny's pick. \[Leaning\]

- SETTINGS opens one screen, from the title (two taps, like everything there, opening over the title without going in) or from the FLIGHT menu (over the flight, which goes on behind it).
- Sound: EFFECTS, COCKPIT, RADIO, and MUSIC, each in tenths with − and +, on top of each channel's own level in the sound set. At nothing, a channel's muted.
- HAPTICS on or off. HELMET LAMP: AUTO (on by itself where a station's dark), ON, or OFF. HIDE CONTROLS WHEN IDLE, off by default, as Manny has it.
- Every change is kept at once, in a file of its own apart from any world's save, so it holds for normal play and Zen Mode alike. A test run never reads or writes it.
- Later: controls, the screen's layout per fold state, and the dev switches (the LIGHTS test switch is still a feature flag).

## Prices

Decided 2026-11-12, on Manny's call, from his sketch of the service terminal. \[Leaning\]

- Docking doesn't refuel or repair any more, and nor does landing at home. The station's docking room (Ship refueling) has a terminal for both, used like the gig board's, and so does the launch base's Vehicle Assembly building, where the terminal used to say ASSEMBLY BAY EMPTY. Each only serves a ship docked there or standing on the base's pad; otherwise its buttons are dark and it says SHIP NOT DOCKED or SHIP NOT ON THE PAD.
- Its screen has two tabs down the left, REFUEL and REPAIRS, with the tab's name as the title. It opens on REPAIRS if anything needs fixing.
- REPAIRS draws the ship as it is, nose up, with a tooltip on each damaged part, joined by a line to where the damage is: the part, DAMAGED or NOT WORKING with how much of it is gone, and under that what fixing it costs. Down the left, the same list. At the bottom right, REPAIR ALL with the total fixes everything.
- REFUEL draws the ship cut away to its systems layer, with a tooltip on each fuel tank and on the RCS propellant: what it holds, and how full it is or how much a hole has cost it. A fuel meter on the right shows engine fuel in orange and RCS propellant in cyan, what's aboard solid and what filling up would add in light, with a red mark where a holed tank stops. At the bottom right, REFUEL with the cost fills both.
- First numbers, in `data/service_prices.tres`: engine fuel 0.15 Cr/kg (a full 40 t fill is 6,000 Cr, against gigs paying 5,000 to 10,000); RCS propellant 0.5 Cr/kg (1,200 Cr full). Rebuilding a whole part costs, per half: cockpit 6,000, engine 4,000, tank 2,500, RCS 1,500, leg 1,000 Cr, charged for the share of its mass that's gone, 50 Cr at least.
- The agency extends a 5,000 Cr credit line, so the balance can go that far below zero. Without it, a pilot who docked broke with empty tanks could never fly again. Short of the full price, REFUEL fills as much as the credit left buys; REPAIR ALL needs the whole amount.
- In Zen Mode it's all free.
- Still open: tows when a ship runs dry, buying a replacement ship after one's lost, and whether the moon base sells fuel too. \[Open\]

## Saving and the title screen

Decided 2026-11-11, on Manny's call, from his title screen mockup. \[Leaning\]

Saving:

- The game saves only while the pilot is aboard: where the ship is and how it's moving, its damage, both tanks, its cargo and switches, and the clock. It saves every few seconds aboard, and whenever the app goes to the background. Out of the ship, that part of the save holds still, so quitting mid-EVA puts the pilot back in the cockpit at the moment they stepped out.
- Credits, gig progress, and what's been learned about each world save the moment they change, wherever the pilot is, so a delivery is never lost.
- The universe comes from the seed, so planets, stations, and gig boards aren't saved, only what the player changed.
- A lost ship is saved as it is. Nothing rescues, rewinds, or replaces it: the player decides what to do next, continuing into the wreck or starting a new flight. Since 2026-11-14, a ship lost with the pilot in it kills them too, and the med bay replaces it (see "Death and the med bay"); a ship lost while they're out of it stays a wreck, as before.
- Normal play and Zen Mode are separate worlds, with a save each. NEW FLIGHT replaces the normal save.
- Every save carries a version number, and an older save is upgraded, never wiped (see Tech).
- Time warp always comes back at 1x.
- How it's built: `scripts/save/save_game.gd` writes `user://saves/normal.save`, Godot's own binary format, to a spare file first and then swaps it in, so a phone closing the app mid-save keeps the last whole one. Each system says what it needs saved and puts it back itself. Detached parts drifting away aren't saved.

Title screen:

- It opens on the game itself, frozen at the saved moment and framed like the ORBIT view on the body the ship last landed on or began orbiting: the body in a corner and the ship on its path. Frozen, so a ship saved mid-descent doesn't crash behind the menu.
- Drawn from Manny's mockup: FINAL ORBIT in big stencil letters with an orange orbit arc through it, "KEPLA SYSTEM · AGENCY FLIGHT OPERATIONS" under it, the mission clock top right, a comms line along the bottom, and the version. The menu runs down the left: CONTINUE, with where the ship is and the credits under it, then NEW FLIGHT, ZEN MODE, and SETTINGS, as thin outlined boxes over space like the flight HUD. SETTINGS opens the settings over the title (see Settings).
- Everything takes two taps: the first selects, widening the box and turning it orange with corner brackets, and the second goes. It keeps NEW FLIGHT from wiping a save by accident, and gives the background time to change: selecting ZEN MODE pulls the camera out to the whole star system and pushes in to the Zen ship, since both worlds are the same system, and selecting NEW FLIGHT shows the fresh start in orbit near Kapteyn-3.
- CONTINUE is selected when the screen opens, so a returning player is one tap from flying. With no save it's hidden, and NEW FLIGHT starts selected.
- Going in, the menu, title, and clock slide off to their nearest side, left or right; the camera zooms into the ship, as the SHIP button does; the world starts moving; and the flight HUD slides in.
- The FLIGHT menu's RESTART becomes TITLE, back to this screen. Starting over is NEW FLIGHT's job.
- SETTINGS waits on a settings screen, dimmed and marked SOON. \[Open\]
- How it's built: `scripts/ui/title_screen.gd` draws the screen and `scripts/ui/title_lettering.gd` paints the letters and orbit as pixel art into a small image, 149 x 70 art pixels, which the screen draws scaled up by a whole number, 3 on both of the Fold's screens. The shapes are measured off Manny's mockup in its own pixels, 3.76 of them to an art pixel: flat cream stencil pieces with a dark outline, each cut back a pixel where it meets one laid before it. The orbit is the ellipse fitted to the mockup's (within about 1.6 of its pixels), a flat orange band whose near half crosses over the letters and whose far half shows only beyond the O and the L. The view holds the body with its middle just off the bottom-right corner and the ship about 60% of the way across, turned so the ship lies toward the menu. The world runs for a couple of ticks to place everything, then freezes. After a change of world it runs while the view arrives, about a second, before it freezes. Changing worlds loads the game again behind a moment of dark. Saving starts only once the player goes in, so nothing's saved from behind the title.

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

## Lighting

Begun 2026-11-14, on Manny's call: derelicts and the goo need tension, and that won't happen if you can see everything. \[Leaning\]

- Shade never mixes in black. Each pixel steps down its own ramp in the agency palette: white hull through the grays to near black, and orange, gold, blue, red, and glass each down their own, falling into the hull's darkest at the end. Where one step meets the next, a 4x4 Bayer pattern dithers them, like the sky's bands. So lit art stays in the locked palette and stays crisp.
- Lights, screens, and flames (the telemetry and thrust colors) glow and never darken, so in the dark a derelict is its status lights and screens.
- One shared shader include, `shaders/palette_light.gdshaderinc`, does the stepping; each lit thing's own shader only works out how much light reaches a pixel. The ramps are set in one place, `scripts/palette_light.gd`.
- Built, ticket 1: a station's insides are lit by ceiling lamps, each a pool of light fading toward its edge, over a little light everywhere. A room can set its lamps; one that doesn't gets a lamp over each floor big enough, and a row of them down a long corridor, every 40 pixels. Each station says whether it's powered, how bright its lamps are, and how much light there is with no lamp near. Kapteyn-3 is powered and lit; a derelict's lamps are off.
- Built, ticket 2: walls stop the lamps' light. Seen from above, a ceiling lamp lights everything under it, furniture and all, so what stops it is the walls of the room it hangs in: each lamp lights only its own room, and the docking tubes between rooms fall dark. Overlapping pools blend the way light does, brighter together but never past full. It's worked out once into a light map on a worker thread, about a seventh of a second for Kapteyn-3's 87 lamps on the Mac, and until it's ready the lamps light straight through.
- Built, ticket 3: the helmet lamp. A cone where the pilot faces, about 5.5 m long and 70 degrees wide with soft edges, and a little glow round the pilot so they can see their own feet. Shining from head height, it's stopped by anything that isn't floor, once it's gone 5 pixels in, so the sides of what it hits are lit. Worked out per pixel on the GPU, through the picture's floors. Inside a station it comes on by itself where the lamps leave it dark (below 0.5) and goes off where they don't (above 0.62), so it comes on in the tubes between Kapteyn-3's rooms. The pilot is shaded by the light where they stand, and their own lamp lights them a little. A switch for it can come later.
- Built, ticket 4: power. With a station's power off, the light everywhere drops to little more than starlight, every third lamp becomes an emergency lamp that pulses dim red every 2.4 seconds, smaller than a ceiling lamp's pool, and every seventh is a failing lamp that sputters: mostly dark, with bursts of light. Emergency light is red in the palette's own reds, the light red where it's strong and the dark red where it's weaker; outlines, the darkest colors, and glowing colors keep their own. The light map keeps each kind in its own channel, so pulsing and sputtering cost nothing to work out again. All of it is in the station's data.
- For trying it while there are no derelicts: LIGHTS OUT on the FLIGHT menu cuts Kapteyn-3's power, and LIGHTS ON brings it back. Behind `FeatureFlags.LIGHTS_SWITCH`, to be off for release.
- Still to come: what's out of the helmet lamp's sight not being drawn, for creatures; rooms not yet entered staying black; sparks; a switch for the helmet lamp.
- Outside, from Gemini's pitch, planned 2026-11-14 on Manny's go-ahead: hulls shaded by the star through the same palette steps, so ships drawn flat for the engine to shade, like the Lander Mk II, get their volume. The original lander has shading painted in; it's to be remade flat in the Asset Editor. Then a world's shadow, the station's outside and the pilot on EVA lit by the star too, and the engine's flame lighting the hull near it.
- Built, outside ticket 1: ships lit by the star. Across each row of the ship's art, each unbroken run of solid pixels is taken as a cylinder, so side pods, legs, and the bell each curve on their own, for any ship, with no extra art. It's worked out once from the ship as it's built, so holes shot in it don't change its shading. The light comes from the star's side with a little from the front, wrapping round so the shading rolls: the near side and middle full, the far side about three steps down. Legs are lit the same, each turned as it's turned.
- Built, outside ticket 2: a world's shadow. Each world casts a shadow straight away from the star, as wide as the world, with a soft edge 4% of its radius wide where the star's only partly hidden. In it, a ship's hull gets no starlight, only the little light everywhere, so it falls to dark grays with its lights still glowing. Anything lit by the star asks the same place (`scripts/sunlight.gd`), so everything goes dark together on the night side.
- Built, outside ticket 3: the station's outside and the pilot. Each pixel takes the shorter of its two runs, across its row or down its column, as its cylinder, so a station's arms, lying across the view or up and down it, curve the right way; ships come out the same. The station's outside is lit by the star and goes dark in a world's shadow too; its art has some shading drawn in, so the star's is gentler there. The lit side stays full and only the far side darkens, so flat art isn't dithered across its middle. The pilot and anyone adrift are lit from the star's direction on screen, and in a world's shadow lose the star's light but get a little more all round, so they're never lost. Indoors, the pilot's lit by the room.
- Built, outside ticket 4: the engine's flame lights the hull round the bell while it burns, out to about 7.5 m, strongest at the bell, which shows most on a night side. The hangar's ship picture is lit from the upper left, worked out in code with the same palette steps, so a ship drawn flat shows its shape there too.
- Still to come outside: RCS puffs and docking floodlights lighting the hull, light off a lit world below, and the comet lit and shadowed like the rest.

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

- The goo, Manny's idea for a first threat: like Venom, but a lot more of him. A huge black mass that absorbs and digests whatever it touches. It chases, stalks, and reaches out to grab, and gets around by grabbing walls and pulling itself along. It lives in large derelict ships and stations. One creature in one derelict to start; growth comes later. Waits for derelicts (Tier 2). \[Leaning\]
  - Proposed fits with what's built: digesting is the damage the game already has, eating a ship's or station's pixels layer by layer, so it can eat through a hull, and touching the pilot breaches the suit, starting the O2 clock instead of killing outright. A grab is the rescue's GRAB HAND turned round: it pulls, and the jetpack pulls back. Pulling itself along is tentacles anchored to solid pixels. Warning signs: eaten holes in walls, dark residue, and groans and knocks through the hull, which the sound system already makes. It's nature's, so it gets its own near-black colors with a sheen, so it still reads against space. \[Open: ideas for Manny\]
- A story or mystery that surfaces through uncharted signals and derelict logs \[Cut for now: pure sandbox\]
- Multiplayer or co-op \[Cut: single player\]
- Half-folded Mission Control console \[Cut: no Flex Mode on Fold 8; revisit for Fold 8 Ultra or later\]
- Full n-body physics, Lagrange points, free-return loops \[Tier 4, behind the gravity interface\]
- NASApunk print texture on space \[Cut: NASApunk stays in hardware and UI\]
- Water: the sea is only a color for now, so you can land on it like ground. It could splash down, sink, or be off limits \[For later: Manny's call\]
- Burn point: a mark on the predicted path where the landing burn has to start to touch down safely \[Not built: a piloting aid, only if Manny wants it\]
- Dim line past a moon's sphere of influence: the rest of the orbit keeps drawing faintly beyond the ring, so you can watch it shrink during a capture burn \[Not built: capture is meant to take some skill\]
