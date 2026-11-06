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

## Player

You are a pilot inside the ship, not the ship itself. Mission control is the voice on the radio, not you. \[Locked\]

- The pilot sprite is about 35 x 40 px, seen top-down: gold visor, helmet, shoulder patches, backpack. Sized to match Gemini concept art at its native pixel scale; 6 x 8 and 16 x 16 px were too small to read as a person. \[Locked\]
- The pilot sets the scale of everything else, so ships are built around the cockpit. \[Locked\]
- The cockpit canopy is about 40-48 px wide, made of breakable glass pixels with the pilot visible underneath. \[Leaning\]
- A cracked canopy depressurizes the cockpit and starts a suit-only timer. \[Leaning\]
- Escape pod: a hard crash can eject the pilot into a tiny, flyable pod. Surviving keeps any already-delivered pay. \[Leaning\]
- EVA: the pilot leaves the ship on a jetpack to patch breaches, grab salvage, or reattach floating parts. Same sprite scale inside and outside. \[Locked for design, built in Tier 2\]
- The suit has its own limits: oxygen, temperature, jetpack fuel. \[Leaning\]
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
- Each material has a strength, the energy to destroy one of its pixels: hull and paint 500 kJ, steel 1.5 MJ, glass 200 kJ, foil 100 kJ. The whole lander is worth about 7 GJ.
- Flat ground crushes from the side that hits, in a jagged line. Debris knocks a dent around where it touches.
- As a guide, with a light tank: 100 units/s scratches the engine bell, 150 takes about 3% of the ship, and 250 takes the engine. A full tank hits about three times as hard.
- A connectivity check groups pixels into 3 x 3 cells, and touching cells count as attached, so the art's small gaps hold together. The piece with the most cockpit stays the ship.
- A hit counts at once for mass, thrust, and everything else, but the art catches up over up to about 0.4 seconds: pixels go a few at a time from where the hit landed, and the edge about to go glows in the thrust and fire colors. A crushed ship sinks to where it now rests, and the art shakes briefly. \[Leaning\]
- Every lost pixel becomes a spark, thrown away from the hit, up to 800 pixels in one hit. Past that, sparks stand in for 2 x 2 blocks, and past 3,000 for 3 x 3 blocks. Sparks live 1.6 to 4.5 seconds and flicker out at the end. Near the ground they fall and bounce, and elsewhere they drift, slowed by any air. There can be 1,500 at once. \[Leaning\]
- Pieces under 30 pixels are just sparks. There can be 12 chunks at once. Under 200 pixels, one crumbles into sparks after 30 seconds or burns up in the air. Any chunk crumbles after 60 seconds on the ground, or at once if it hits the ground faster than 120 units/s.
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
- Air resistance grows with the air's density, the square of speed, and how much of the ship faces the air, and shrinks with mass, so side-on slows harder and a full tank punches through further. Each ship's shape sets it, and the width and length come from its pixels. \[Leaning\]
- The home planet's air ends at 15,000 units and thins by a factor of e every 2,000. A lander coming from low orbit reaches the ground at about 300 units/s, so it still needs a burn to land. \[Leaning\]
- Landing means matching the ground's rotational speed.
- Launching in the direction of spin gives a free speed boost, like real rockets launching east.
- Outside the atmosphere, momentum is conserved and the ship does not slow down.
- Airless bodies have no moving air, so a hovering ship stays put while the ground slides past underneath.
- Coasting stays closed-form above the atmosphere. Inside it the ship is simulated step by step, which limits time warp and fold-to-coast there and needs the preview's background thread.
- Re-entry heat grows with the square root of air density and the cube of speed, and shows as a bow shock and streaks of gas in the thrust and fire colors. A gentle return from low orbit reads about 0.2 on a scale where 1.0 is the limit, and a steep return from high up goes past 1.0. \[Leaning\]
- The hull warms toward the heat over about 6 seconds, so a short spike does no harm. Past 1.0 it burns away from the hot side, at 200 MJ a second for each whole step past, about 3% of the lander. Heat shields come with more modules. \[Leaning\]
- For now the path line ignores the air, so inside the atmosphere it shows where the ship would go with no drag and updates every tick. Drawing the drag into it waits for the background thread. \[Leaning\]

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
- The name ASS, for Attitude Stabilization System, is final. \[Locked\]
- ASS uses the same thrusters as manual turning, at the same strength, so from Tier 1 it should burn the same fuel.
- The ship starts in ASS, with STAB off. On the Mac, T switches ASS and RAW, and R switches STAB.

Scale and precision: \[Leaning\]

- Planets around 1/10 real scale, tuned for play.
- Readouts show 1 world unit as 1 m, so distances read big, with bigger planets and distances to come. \[Leaning\]
- Tier 1's star has 5,000 times the planet's mass and sits 45 million units away, so a lap of the planet around it takes about 3.5 hours at about 22,000 units/s. About three quarters of a full tank can drop from low orbit almost to the star, in about 40 minutes. That's the longest trip that works without time warp. These live in `data/home_star.tres` and `data/home_planet.tres`. \[Leaning\]
- The Tier 0 planet is far smaller for now, so a low orbit takes under 4 minutes without time warp: radius 150,000 px and surface gravity 200 px/s², or about 1/850 real scale if the 35 px pilot is 1.75 m. Revisit once time warp exists. These live in `data/home_planet.tres`. \[Leaning\]
- Floating origin re-centered on the ship to avoid jitter.
- Physics math in 64-bit, either in native code or a double-precision engine build.

Trajectory preview: computed on a background thread, in chunks, and cached while the player drags a maneuver. \[Leaning\]

The preview draws the ship's current path as a 1 px telemetry cyan line: one full lap on a closed orbit, otherwise up to six hours ahead or until it hits a surface. Closed-form paths are cheap, so it runs on the main thread. It updates on a burn, on a change of dominant body, and every tick while orbiting a moving body or on a path that doesn't close, so no flown part lingers behind the ship. A closed orbit updates twice a second, to catch encounters as the moon moves. The background thread can wait until maneuvers exist. \[Leaning\]

Around a moon, the line is drawn around the moon as it is now. An upcoming encounter is drawn around the moon as it will be on arrival, with a ring showing where that is, so the line has a kink where it enters the moon's frame. The line ends on leaving a moon's or planet's sphere; the path after that shows once you get there. \[Leaning\]

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

World structure: \[Leaning\]

- Seeded galaxy; systems are generated only when approached.
- Off-screen, nothing simulates except the rails math.
- Stations and colonies are hubs for gigs, fuel, and repairs; NPC traffic is ambiance, not a simulated economy.

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
- Tiers 2 to 7 are built. Star system centers on the star, Planet on the planet you're around, Orbit on whichever body you're orbiting, and Approach, Descent, and Surface on the ship. In between, the center slides steadily with the zoom. Out in deep space, the ship stands in for the planet and orbited body. \[Leaning\]
- The far tiers draw each body's rails and sphere of influence in dark canopy glass from the agency palette, behind the bodies. An orbit line stops at that body's sphere of influence ring, and rails or rings too small to read aren't drawn. \[Leaning\]
- A ship rests on its engine bell, and on the ground it settles upright and the turn keys do nothing, so thrust always lifts it straight off. \[Leaning\]
- A touchdown reports LANDED (up to 50 units/s and within about 30 degrees of upright), HARD LANDING, or CRASH (over 250 units/s), on top of any damage. \[Leaning\]
- Up close, patches of the next color speckle the ground so you can see drift. \[Leaning\]
- Zooming changes what is drawn, never the pixel size: each tier swaps detail levels on a fixed pixel grid. \[Locked\]
- One exception: closer than the Orbit view, the ship is its normal sprite at true scale, with no smoothing and no minimum size, so it can shrink out of sight just before the icon takes over. At the Orbit view and farther it's a clean icon, and very far out it's a dot. \[Leaning\]
- Terrain detail is generated only when you zoom in close. \[Leaning\]
- Zoom moves smoothly and has no outer limit, so the ship can shrink to a single dot. The tiers set what detail is drawn at each distance. \[Leaning\]
- Interiors use an FTL-style cutaway: zoom in and the roof comes off, with top-down movement inside. \[Locked for design, built in Tier 3\]
- Inside derelicts and stations: zero-g movement, flashlight cones in darkness, per-room pressure (a room graph, not per-pixel air), loot and logs. Destruction can create new entrances. \[Leaning\]

## UI

The UI is built around seeing space, with NASApunk flight hardware at the screen edges. Mockups for both screens: https://claude.ai/artifact/D1QGC4XQJXpQjdn2XcpQat

UI principles: \[Locked\]

- Space comes first. Seeing space is the point of the game, so the UI never clutters the center of the screen.
- The UI is NASApunk hardware: panels hugging the screen edges, styled as physical 1970s flight equipment in pixel art (metal plates, stencil labels, chunky buttons).
- The UI uses the agency palette only.
- Numbers use a pixel or 7-segment style font.
- All touch targets are at least 44 game pixels.

Top bar: \[Locked\]

- Always visible; it never auto-hides.
- Contains, left to right: the FLIGHT menu button, the comms line (mission control radio text), flight readouts (ALT, SPD, AP, PE, mission clock, delta-v), Master Caution, and the split-flap pending-payout counter.
- Master Caution lives here so warnings are never hidden by auto-hide.

Side panels: \[Locked\]

- Left edge: LED bar gauges for fuel, hull, and heat, plus a notched throttle lever.
- Bottom-left, next to the left panel: zoom buttons. SYS shows the local system, and pressing it again shows the whole star system. ORBIT shows what you're orbiting, and SHIP goes to the closest view of the ship.
- Right side, at the bottom: flight mode buttons (ASS, STAB, NODE) and the BURN button under a red flip-up safety cover.
- The throttle lever sets thrust power, and BURN activates it.
- The first touch lifts BURN's cover and the button fires while held. The cover drops again after 6 seconds with no burning. \[Leaning\]
- The center stays clear for the planet, orbit line, ship, and markers.

Auto-hide: \[Locked\]

- After a few seconds with no input, the side panels shrink into thin strips at the screen edges.
- The strips still show the fuel level and where BURN is.
- A small tab sticks out from each side while the panels are hidden, and dragging in from either side brings them back.
- Zen Mode can hide everything except a minimal top bar. \[Leaning\]

Cover screen (folded): \[Leaning\]

- Same rules with fewer controls.
- The always-visible top bar has FLIGHT, a short comms line, ALT, SPD, delta-v, Master Caution, and payout.
- Fuel and throttle sit bottom-left.
- STAB, NODE, and BURN sit bottom-right.

Menus: \[Leaning\]

- Most menus only exist when docked at a station: gig board, hangar, repairs, refuel, full map, settings. Docking is like walking into the agency office.
- In flight, the FLIGHT button opens a clipboard drawer from the edge with: Pause, Manifest (active gigs and what is still undelivered), Ship (damage schematic), Map, Settings.
- Closing the drawer returns to the space view.

Turning and RCS controls: \[Leaning\]

- Drag to point: dragging anywhere on the space view shows a cyan heading line from the ship toward the thumb, and the ship rotates to face it using RCS physics.
- While turning, a dashed heading ring appears around the ship and fades when released.
- Drag to point works even when the side panels are auto-hidden, and leaves them hidden.
- Two fingers on open space pinch to zoom. \[Leaning\]
- RCS pad (right panel, inner screen): rotate left, rotate right, and four translate arrows (forward, back, left, right).
- Translation moves the ship without turning it and is required for docking and precise landings.
- A ROT / TRANS switch sits above the cover screen's compact pad, flipping its four arrows between rotation and translation, with STAB in the middle. The inner screen's pad shows rotate and translate at once, so it has no switch.
- Heading dial above the pad: nose direction, prograde (cyan) and retrograde (orange) markers, and a rate bar showing spin speed. The markers hide when landed or barely moving, since there's no direction of travel to show. Inner screen only.
- The right panel on the inner screen is full height and 140 game pixels wide: heading dial, RCS pad, modes, then BURN at the bottom. On the cover screen it only rises as far as its controls need.
- Translation gives the lander about 30 m/s² when full and uses RCS fuel. It's too weak to lift off from the planet or the moon, and ASS doesn't cancel it. \[Leaning\]

Edge markers: \[Leaning\]

- Off-screen targets (gig destinations, stations, bodies) show at the screen edge as small agency-orange arrows with a callsign and distance (for example "HOME 236 km").

Control reference: the old mobile game Space Agency (rotate and translate button pads, off-screen target markers).

### Planet info

Tapping a body opens an agency dossier card: typewriter text, stamps, and a pixel portrait that fills in as more is learned. \[Locked for design, Tier 1\]

What the card shows depends on how the player has studied the body: \[Locked for design, Tier 1\]

- Never visited: "UNCHARTED" stamp and a silhouette only.
- Orbited it: mass, radius, gravity, day length (the orbit itself reveals the mass).
- Scanned it (requires a scanner module, which adds mass): atmosphere, surface temperature, radiation, hazards.
- Landed on it: surface type, biome, and a "visited" stamp.

Knowledge and ties to other systems: \[Locked for design, Tier 1\]

- Knowledge is saved permanently once gathered.
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
- Background stars are a seeded shader with three parallax layers. Real stars would barely shift; the parallax is there so motion reads in empty space. \[Leaning\]

Readability rules: \[Locked\]

- Human-made objects get a 1 px dark outline.
- Telemetry cyan and agency orange belong to the agency: trajectories, warnings, and your ship's markers. Space generation avoids exact matches.
- Black holes get real drama: pixelated gravitational lensing of the background stars.

Art pipeline: \[Leaning\]

1. Describe the asset to Gemini for concept images.
2. Recreate it by hand, or hand the image to Claude to turn into a clean sprite.
3. Clean up in Aseprite: snap to grid, force the agency palette, fix edges.
4. Ship modules are drawn on the fixed module grid, one PNG each, since their pixels are collision and damage. Keep gaps within a part to 2 px or less so it counts as one piece.
5. Planets and space are shaders and code, not hand-drawn sprites.

## Tech

Godot 4, with GDScript for gameplay and the physics core in C++ through GDExtension. No custom engine. \[Leaning\]

Godot 4.7.2 with the Compatibility renderer, since the game is 2D and needs no compute shaders. Changing renderer is a one-line project setting. \[Leaning\]

Android builds use Godot's prebuilt template rather than a Gradle build, arm64 only, as a debug build for now. Package name: `com.emmanuelwalters.finalorbit`. \[Leaning\]

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
3. **Tier 2, Pilot:** escape pod, EVA outside the ship, repairs, salvage of floating parts and lost cargo, more hazards, Observatory Mode.
   - Gate: crashing becomes a story, not just a loss.
4. **Tier 3, Interiors:** enterable derelicts and stations, pressure, darkness, loot.
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

Parking lot:

- A story or mystery that surfaces through uncharted signals and derelict logs \[Cut for now: pure sandbox\]
- Multiplayer or co-op \[Cut: single player\]
- Half-folded Mission Control console \[Cut: no Flex Mode on Fold 8; revisit for Fold 8 Ultra or later\]
- Full n-body physics, Lagrange points, free-return loops \[Tier 4, behind the gravity interface\]
- NASApunk print texture on space \[Cut: NASApunk stays in hardware and UI\]
- Time warp: speeding up coasting, which orbits make cheap, since a moon lap takes about 23 minutes at normal speed \[For later: Manny's call on when\]
- Dim line past a moon's sphere of influence: the rest of the orbit keeps drawing faintly beyond the ring, so you can watch it shrink during a capture burn \[Not built: capture is meant to take some skill\]
