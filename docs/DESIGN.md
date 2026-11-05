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
- Each material has a density; the ship's total mass, center of mass, and spin resistance are summed from its pixels. \[Locked\]
- Fuel has mass and burns off, so ships get lighter and more agile as they fly. \[Locked\]
- Staging: drop empty tanks or used heat shields to save mass; dropped parts become debris. \[Leaning\]
- Repairs and customization happen at the pixel level, so patched plating shows on the hull. Liveries and paint use the agency palette. \[Leaning\]

Destruction: \[Locked\]

- Impact damage depends on both masses and the impact speed.
- Damage erases pixels. After each hit, a connectivity check splits off any piece no longer attached.
- Detached chunks become physics bodies with their own orbits; single pixels are visual particles only.
- Losing a module changes how the ship flies: a missing thruster gives off-center thrust and spin, a punctured tank vents and pushes the ship.
- A debris budget caps active pieces; tiny ones fade or burn up.

Archetypes that emerge from the physics: \[Leaning\]

| Archetype | Good at | Pays for it with |
| --- | --- | --- |
| Light probe | Huge range, cheap burns | Fragile, can't land on heavy or hot worlds |
| Moon hopper | Nimble, cheap | Low-gravity bodies only |
| Heavy lander | Survives heat, high gravity, rough landings | Heavy, sluggish, short range |
| Hauler | Big cargo capacity | Handles like a fridge, fuel-hungry |

Taking off from a world requires thrust greater than the ship's weight there (thrust-to-weight above 1). Owning several ships matters because gigs demand different ones.

## Physics

Patched conics first (the ship feels only the dominant body's gravity), behind a swappable interface so restricted n-body can replace it later. \[Locked\]

Gravity model interface: \[Locked\]

- `GravityModel.get_acceleration(position, time)`
- `GravityModel.propagate(ship_state, dt)`
- `GravityModel.predict_trajectory(ship_state, duration)`
- `PatchedConicsModel` ships first; `NBodyModel` (ship feels every body, planets stay on rails) plugs in later. Nothing else in the game knows which is running.

Celestial bodies: \[Locked\]

- Planets and moons move on Kepler rails, computed from time, not simulated. Deterministic and time-warp friendly.
- Each body's mass sets its gravity and its sphere of influence.
- Planets never pull on each other.

Ship: \[Locked\]

- Coasting orbits are closed-form ellipses, so time warp and fold-to-coast cost almost nothing.
- Thrust, collisions, and torque use the ship's live mass and center of mass.
- Ship mass does not change its orbit, only how it responds to pushes.
- Tier 0 turning has angular momentum: A and D change the spin at a fixed rate, and the spin lasts until the opposite key cancels it. Torque from live mass arrives with modular ships. \[Leaning\]

Scale and precision: \[Leaning\]

- Planets around 1/10 real scale, tuned for play.
- Floating origin re-centered on the ship to avoid jitter.
- Physics math in 64-bit, either in native code or a double-precision engine build.

Trajectory preview: computed on a background thread, in chunks, and cached while the player drags a maneuver. \[Leaning\]

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
| Star heat | Too close to a star | Heat shielding, radiators | 1 |
| Cold and dark | Inverse-square sunlight far out | Different power and thermal builds | 1 |
| Comms blackout | No line of sight to a relay | Plan uplinks; no updates or uplink while hidden | 1 |
| Radiation belts | Magnetic planets, gas giants | Pass through fast or route around | 2 |
| Solar flares | Warned stellar events | Shelter behind a planet | 2 |
| Rings and debris | Ring systems, belts, your own wrecks | Avoid or thread carefully | 2 |
| Surface conditions | Molten, icy, high-gravity worlds | Reinforced gear, enough thrust-to-weight | 2 |
| Depressurization | Cracked canopy or breached room | Eject, patch, or race the suit timer | 2-3 |
| Tidal forces | Black holes, neutron stars | Keep your distance | 4 |

## Camera, zoom, and landing

One continuous top-down camera with six zoom tiers. Landing is just zooming in: there are no loading screens between space and a surface. \[Locked\]

| Tier | View | Shows |
| --- | --- | --- |
| 1 | Galaxy | Star systems, nebulae, your next destination |
| 2 | Star system | Star, planet orbits, transfers |
| 3 | Planet and moons | Local orbits, spheres of influence |
| 4 | Orbit | Your ship's orbit, maneuver planning |
| 5 | Approach | Curved horizon, atmosphere glow, re-entry |
| 6 | Surface | Flat ground, terrain, pads, the pilot through the canopy |

- In 2D a planet is a circle, so zooming in turns its rim into the horizon you land on. \[Locked\]
- Zooming changes what is drawn, never the pixel size: each tier swaps detail levels on a fixed pixel grid. \[Locked\]
- Terrain detail is generated only when you zoom in close. \[Leaning\]
- Far zooms show ships as clean icons; close zooms show the pilot. \[Leaning\]
- Interiors use an FTL-style cutaway: zoom in and the roof comes off, with top-down movement inside. \[Locked for design, built in Tier 3\]
- Inside derelicts and stations: zero-g movement, flashlight cones in darkness, per-room pressure (a room graph, not per-pixel air), loot and logs. Destruction can create new entrances. \[Leaning\]

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
- Backgrounds are always very dark, never pure black.
- Background stars are a seeded shader with three parallax layers. Real stars would barely shift; the parallax is there so motion reads in empty space. \[Leaning\]

Readability rules: \[Locked\]

- Human-made objects get a 1 px dark outline.
- Telemetry cyan and agency orange belong to the agency: trajectories, warnings, and your ship's markers. Space generation avoids exact matches.
- Black holes get real drama: pixelated gravitational lensing of the background stars.

Art pipeline: \[Leaning\]

1. Describe the asset to Gemini for concept images.
2. Recreate it by hand, or hand the image to Claude to turn into a clean sprite.
3. Clean up in Aseprite: snap to grid, force the agency palette, fix edges.
4. Ship modules are drawn on the fixed module grid, since their pixels are collision and damage.
5. Planets and space are shaders and code, not hand-drawn sprites.

## Tech

Godot 4, with GDScript for gameplay and the physics core in C++ through GDExtension. No custom engine. \[Leaning\]

Godot 4.7.2 with the Compatibility renderer, since the game is 2D and needs no compute shaders. Changing renderer is a one-line project setting. \[Leaning\]

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
- [ ] Exact internal pixel resolutions for the inner and cover screens. Published specs: inner 2448 x 1848 (4:3, not near-square), cover 1972 x 1248 (16:10); confirm on the device. Placeholder: 3x, so 816 x 616 inner. A fixed base size drops the cover screen to 2x with black bars, so each screen needs its size set at runtime.
- [ ] Module grid size (64 x 64 px is a starting guess)
- [ ] Touch controls for burns, rotation, and maneuver planning
- [ ] Economy numbers: gig pay, ship prices, repair costs, tow cost
- [x] C# on Android stable yet, or stay with C++ GDExtension? Still experimental in Godot 4.7 (checked 2026-11-05); stay with C++
- [ ] Starting conditions: first ship, starting money, home station

Parking lot:

- A story or mystery that surfaces through uncharted signals and derelict logs \[Cut for now: pure sandbox\]
- Multiplayer or co-op \[Cut: single player\]
- Half-folded Mission Control console \[Cut: no Flex Mode on Fold 8; revisit for Fold 8 Ultra or later\]
- Full n-body physics, Lagrange points, free-return loops \[Tier 4, behind the gravity interface\]
- NASApunk print texture on space \[Cut: NASApunk stays in hardware and UI\]
