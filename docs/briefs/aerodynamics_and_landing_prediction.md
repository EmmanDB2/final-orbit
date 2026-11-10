# Brief: aerodynamics and landing prediction

For a Claude Fable 5.2 session working in this repo. Written 2026-11-10 by the build session, with
every design decision below settled by Manny (the owner). Build against them; ask Manny only if
something here turns out to be impossible or contradicts `docs/DESIGN.md`.

## Before you start

1. Read `CLAUDE.md`, then `docs/DESIGN.md`, especially "Physics" (rotating planets and atmospheres,
   the new "Aerodynamics" and "Landing prediction" blocks, trajectory preview, landing line),
   "Hazards", "UI" (time warp, comms line, heading dial), and "Scale and precision".
2. You're in a **build session** (CLAUDE.md, "How we work"): write all the code, keep replies short,
   commit after each ticket, append a `docs/LEARNING_LOG.md` entry per ticket, record anything new in
   `docs/DESIGN.md` with a tag and a change-log row (newest first, right under `| --- | --- |`), and
   tell Manny what changed. End commit messages with the attribution line your session gives you.
3. Don't push `tier-1`. Don't touch Manny's uncommitted files: `data/agency_palette.tres`,
   `data/home_planet.tres`, `data/lander_design.tres`, `data/starfield.tres`, `data/station_1.tres`,
   `scenes/main.tscn`, `data/test_star.tres`, and the root `ship_lander_*.png` files. New tuning
   values go in script `@export` defaults (or new data files) so those `.tres` files stay untouched.
   Never edit anything in the sibling `Final Orbit Asset Editor` project.
4. Manny wants flying to take skill. Build what's asked; offer piloting aids as ideas, don't add them.

## Setup

- Godot 4.7.2, Compatibility renderer. The physics core is C++ GDExtension in `native/`; its built
  libraries in `bin/` aren't committed. In a fresh checkout or worktree: `git submodule update --init`,
  then `scons -C native platform=macos arch=arm64 target=template_debug -j8`. For the phone:
  `ANDROID_HOME=~/Library/Android/sdk scons -C native platform=android arch=arm64 target=template_debug -j8`.
- After adding a `class_name`, run `godot --headless --path . --import` once.
- Test suites (all must stay green): `godot --headless --path . --script tests/<name>.gd` for
  `test_gravity_model`, `test_ship_body`, `test_station`, `test_astronaut_model`.
- Headless runs have a 64 x 64 window: set `root.size` once the scene's running if layout matters.
  Headless frames run faster than real time, so wait on real time (`Time.get_ticks_msec()`) or physics
  ticks, never frame counts, for anything timed. Hold scripted key presses for 100 ms or more, or no
  physics tick sees them.
- Windowed captures: `godot --path . --always-on-top --resolution 986x624 --script <script>`. The
  inner screen is 816 x 616 and the cover screen 986 x 624, in game pixels.
- Phone (Galaxy Z Fold 8 over adb at `~/Library/Android/sdk/platform-tools/adb`): rebuild the Android
  library if `native/src` changed, export with
  `godot --headless --path . --export-debug "Android" build/final-orbit-debug.apk`, then **always**
  `git checkout -- project.godot` (export reorders it), `adb wait-for-device`, and
  `adb install -r build/final-orbit-debug.apk`. Manny wants every committed build installed,
  whatever's on the phone's screen. If adb sees no device, build the APK and say so.

## Where things are

- `scripts/ship.gd`: the ship. `_physics_process` does attitude (turn keys, drag to point, STAB,
  ASS; all RCS, from the separate `rcs_fuel` tank), the ENGINE switch, translation, then
  `_push_through_air` (today: one-box drag from `body.width` and `body.length` against the turning
  air, and `heat_share` with `_heat_heading`), `_heat_hull`, legs, `_touch_terrain`, and
  `_gravity_model.propagate`. Mass properties come from `_update_performance()` (`_mass_now`,
  `_spin_resistance_now`, live center of mass via `body.with_fuel`). `_steer_toward` and
  `_stab_heading` are the autopilots. `_safe_impact_speed()` gives the safe touchdown speed for the
  legs as they are. Telemetry goes out in `_report_telemetry` as `flight_data_changed`.
- `scripts/ship/ship_body.gd`: the ship measured pixel by pixel: `mass`, `center_of_mass`,
  `spin_resistance`, `tanks`, `outline_now()` and `outline_samples_now(spacing)` (in art pixels from
  the grid's middle), `reach()`, `with_fuel()`, and damage (`crush`, `dent`, `split_off`). The shape
  changes with damage and as the legs move (`set_parts_out`).
- `scripts/ship/ship_design.gd`: per-ship data (`drag_coefficient`, `heat_limit`, `rcs_torque`,
  `safe_impact_speed`, `legs_safe_impact_speed`, ...). Add new aerodynamic coefficients here.
- `scripts/reentry_glow.gd`: heat visuals from `heat_share` and the hot side.
- `native/src/patched_conics_model.{h,cpp}`: the C++ core behind the `GravityModel` interface
  (`native/src/gravity_model.h`): `propagate` (closed-form coasting, `coast_to_surface` for impact),
  `predict_trajectory`, `predict_entry_heights` (the amber landing-zone stretches),
  `get_air_density` (exponential, ends at the body's air top), `get_surface_velocity` (the turning
  ground and air), `get_ground_strip` and terrain, `get_orbit_apsides`.
- `scripts/trajectory_preview.gd`: draws the path line, the amber landing-zone stretches, and the
  encounter ring. It runs on the main thread today.
- `scripts/time_warp.gd`: warp is 10x at most in air (the "IN AIR" drop), so a physics tick in air
  can be up to 1/6 s. `TimeWarp.on_rails()` is true above 10x.
- `scripts/ui/comms_line.gd`: the comms line and its statuses ("IMPACT TRAJECTORY" when periapsis is
  below ground). `scripts/ui/heading_dial.gd`: nose, prograde and retrograde, and spin.
- `scripts/feature_flags.gd`: flags for systems that might need switching off.

## Rules that can't bend

- Everything about gravity and coasting goes through `GravityModel`; never call
  `PatchedConicsModel` directly. Adding methods to the interface (both the C++ base and its
  implementation) is fine.
- Physics math in 64-bit (positions are separate doubles in `ShipState`; Godot's `Vector2` is 32-bit).
  Deterministic: the same inputs give the same flight.
- One world unit is 5 cm; readouts go through `scripts/units.gd`.
- UI uses the agency palette only (`data/agency_palette.tres` via `UiStyle.palette()`): telemetry
  cyan for trajectories, amber for the landing zone, agency orange for targets.

## Ticket 1: aerodynamics

Replace the one-box drag with forces on each exposed part of the outline. Decided by Manny: the
most realistic model, with nothing about stability chosen by hand.

- Split the current outline into short segments with outward normals (rebuild only when the shape
  changes: damage, legs moving). For each segment facing into the local airflow, push along the
  normal by how squarely it faces it, scaled by air density and the local air speed squared. The
  local airflow at a segment is the ship's velocity against the turning air plus the segment's speed
  from the ship's own spin, so spinning damps itself. A Newtonian-style flat-plate model is enough;
  keep the coefficients in `ShipDesign`.
- Sum the pushes into a force (drag and lift together) and a torque about the live center of mass
  (tanks drain, so it moves). Apply them to the velocity and `angular_velocity`.
- Stability then falls out: center of mass ahead of the center of pressure means the ship turns to
  lead with that end. The lander's low engine and tanks should make it fall engine-first, the way a
  returning booster does. Check that it does; if it doesn't, say why before changing anything.
- The RCS keeps its strength. When the air's torque beats `rcs_torque`, the autopilots lose. Raise
  the comms message AIR OVERPOWERING RCS (amber, through `warning_raised`) when STAB, ASS, or drag to
  point can't hold, not every tick.
- Keep heating driven by what faces the airflow: compute `heat_share` and the hot side from the same
  segments, keeping today's scale (a gentle return from low orbit reads about 0.2, a steep one from
  high up passes 1.0).
- Stable at any tick length up to 1/6 s (10x warp in air): substep the aero, or damp implicitly. No
  NaNs, and the air must never add energy relative to itself.
- Cheap enough for every tick on the phone. Measure it; aim for well under a millisecond a tick.
- Optionally behind `FeatureFlags.AERODYNAMICS` (default on) so Manny can compare with the old model.

Checks to write (a new `tests/test_aerodynamics.gd` suite where possible, plus scripted flights):

- A lander dropped engine-first into the home planet's air stays engine-first; dropped broadside or
  nose-first, it turns engine-first and settles, with the swing dying out.
- Spinning in air with no RCS slows the spin.
- At a slow speed high up, STAB can hold broadside; fast and low it can't, and the comms says so.
- A lander with one side damaged trims at an angle or tumbles; one with drained tanks is less stable
  than with full ones (longer swing or a wider angle).
- Tilted, it drifts sideways (lift).
- From the start orbit, a hands-off engine-first descent reaches the ground at roughly today's speed
  (about 300 world units/s); report the number.
- Same descent at 1x and 10x warp lands within a small distance; no blow-ups.
- Airless moon: no aero forces at all.

## Ticket 2: landing prediction

Draw the drag into the path line, and say what the landing means. Decided by Manny:

- Inside the air, fly the path ahead step by step with the **same** aerodynamics as ticket 1, off the
  main thread (in C++ through the `GravityModel` interface, run from a `WorkerThreadPool` task or a
  `Thread`), and swap in each result when it's ready. Above the air keep the closed-form path as it
  is. Refresh a few times a second in air.
- The main line is **hands off**: no more burns, the ship turning as the air turns it, and STAB and
  ASS doing what they're set to now. Share the autopilot logic with `ship.gd` rather than writing a
  second copy that can drift from it. If the logic has to move to C++ for the predictor, move it.
- Two more runs, **least drag** (end-on) and **most drag** (broadside), mark a **landing zone** on the
  ground between their touchdown points: a bracket on the surface, in amber.
- The line's end gets a label, in the UI's stencil text, small:
  - **SAFE** if the touchdown speed against the turning ground is under `_safe_impact_speed()` for
    the legs as they are and the ground there isn't too steep for the ship to stand on;
  - **HARD** if it's under the hard-landing speed (`hard_touchdown_speed` in `comms_line.gd`);
  - **CRASH** above that;
  - **BURN-UP** if the hull would overheat on the way down.
  Show the touchdown speed beside it, through `Units`. Update the comms status to match (for
  example CRASH TRAJECTORY instead of IMPACT TRAJECTORY in air); keep the wording short.
- With no more burns assumed, most descents will read CRASH until the pilot burns. That's correct.
- Out of scope: future burns (they come with maneuver planning, not built) and any "start burning
  here" mark (a piloting aid Manny hasn't asked for; it's in the parking lot).

Checks:

- From a scripted descent, the hands-off prediction made at the top of the air lands within a small
  distance of where the real hands-off flight touches down (report how close, in meters), and the
  real touchdown falls inside the landing zone.
- A gentle, slow touchdown predicts SAFE; the start-orbit hands-off descent predicts CRASH; a steep
  fast entry predicts BURN-UP.
- The main thread never waits on the predictor; frame time on the phone doesn't jump in air.
- The moon (no air) keeps its closed-form path, with the same end labels from the impact speed.

## Report back

For each ticket: what changed and in which files, the numbers you measured (touchdown speeds, swing
damping, prediction error, per-tick cost on the phone), anything that needed a design call, and how
Manny can try it on the Fold. Keep it short.
