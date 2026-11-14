# Brief: falling and dying, blended

Written 2026-11-14 by Opus, from Manny's report, for the builder agent (Sonnet).

## What and why

Manny: "When jumping out of the lander the astronaut remains in the top down position and doesn't show
any signs of falling. Only when he hits the ground does he snap and transition to the death position
(which looks ok by itself)." A pilot falling toward a world should be seen from the side from the first
frame off the ship, flailing harder the faster they drop, and on a fatal landing the body should crumple,
topple onto its back, and settle into the existing limp pose, never snap. The same goes for every other
death: no joint, angle, or position jumps between two frames. It lives in DESIGN.md "Player" (the 3D
pilot) and "Death and the med bay". The limp pose itself is fine: keep its numbers.

Why it snaps today (from the explorer): leaving a ship that isn't landed sets `EVA`, and `_show_figure`
(scripts/pilot.gd) gives EVA `Look.EVA`, seen from above, until `_land_on_ground` sets `SURFACE`.
`AstronautView._pose` writes each joint's angle straight from the motion, so any change of motion snaps,
and `limp` arrives on the first frame of death. `_die` drops `state.ground_clearance` from 26 to 6, and
`_show_body` sets `feet_below` to 0, so the body jumps about 12 px down on screen. The looks are
different pivot bases chosen in `_turn`, so switching look snaps the whole model.

## Decided

- Physics and modes don't change: `EVA`, `SURFACE`, the landing bands, causes, severities, and the med
  bay timing stay as they are. This is about what's drawn, plus the dead body's ground contact (ticket 3).
- **The fall view.** On EVA, the pilot is seen from the side (`Look.SIDE`) when all of these hold,
  checked once per physics tick and cached as `_falling_to_world`: the dominant body isn't the star
  (index 0); the low point of their path, `get_orbit_apsides(state)[0]`, is below that world's
  `get_highest_ground(world) + state.ground_clearance` (the same test `ship.gd` uses at about line 923;
  copy its handling of a path that never comes back); and `get_altitude` is below a new
  `PilotData.fall_view_height` = 40000 units (2 km). Otherwise EVA keeps `Look.EVA`. Use only
  `GravityModel` calls.
- In the fall view, `body_angle` still follows `facing` (rotate buttons and drags still turn them, now
  rolling them in the side plane), there's no EVA lean, and `feet_below` is 0, so they turn about their
  middle. Which way they face: latched in `_fall_facing_right`. On leaving a ship it's the hatch side,
  worked out as `_step_out_onto_ground` does; after that it follows their sideways speed against the
  ground (along the world's right, from `get_surface_velocity`) once it passes 20 units/s the other way.
  It's carried into `_facing_right` when they land, so landing never flips them.
- **The flail.** New motion `&"fall"`, with a new `AstronautView.flail` from 0 to 1:
  `smoothstep(flail_from_speed, flail_full_speed, descent)`, where descent is their speed toward the
  world's middle relative to the ground's own motion. New `PilotData` fields: `flail_from_speed` = 60.0
  and `flail_full_speed` = 200.0 (units/s, i.e. 3 and 10 m/s). Used by EVA in the fall view when the
  jetpack isn't firing (firing still shows `&"jet"`), and by SURFACE in the air when descent passes
  `flail_from_speed` (otherwise it stays `&"air"`). Manny wants flying to take skill: this is an honest
  body reacting, not a forecast, so no number, color, or HUD reads the flail.
- The fall pose, a starting point to tune by screenshot (radians, same names as `_pose`; `w` is a
  windmill rate of `lerpf(4.0, 9.0, flail)` rad/s, advanced in its own `_flail_phase`):
  - at flail 0, the `&"air"` pose with `rise_share` -1 (legs a little bent, arms a little out);
  - toward flail 1, arms windmilling out of step: `arm_l = 1.2 + 1.3 * sin(p)`,
    `arm_r = 1.2 + 1.3 * sin(p + 2.5)`, `arm_out = 0.6 + 0.4 * sin(p * 0.7)`,
    `elbow = 0.6 + 0.3 * sin(p + 1.0)`; legs pedaling: `hip_l = 0.4 + 0.5 * sin(p * 1.3)`,
    `hip_r = 0.4 - 0.5 * sin(p * 1.3)`, knees `-(0.4 + 0.6 * max(cos(p * 1.3), 0))` and its mirror;
    `lean = -0.15` (arching back); no breath.
  - Mix the two by `flail`. It must read as falling and panicking at 37 px tall, from the side.
- **Every pose blends.** `AstronautView` keeps the shown value of each pose number (the hips, knees,
  each arm's swing and out, each elbow, lean, drop, breathe) with a velocity, and moves it toward the
  motion's target with a damped spring each frame. A new
  `static func spring_step(value, velocity, target, omega, zeta, delta) -> Vector2` (returns the new
  value and velocity; semi-implicit, stable for `delta` up to 0.1 at `omega` 30). The default spring is
  `omega` 30, `zeta` 1 (settles in under 0.15 s, so walking and climbing still look like they do now).
  A new `AstronautView.pose_spring := Vector2(omega, zeta)` lets the pilot change it. A new
  `jolt(kick: float)` adds velocity to the limbs, flinging them: arms +8·kick rad/s, hips +5·kick,
  knees -6·kick, lean -3·kick.
- **Every look blends.** When `look` changes, `_turn` blends from the basis it showed last frame to the
  new look's basis over 0.35 s (quaternion slerp, eased with smoothstep), then follows the new look
  exactly. A change mid-blend starts a new blend from what's shown. The depth model follows the same
  basis.
- **Deaths, by cause** (set in pilot.gd when `_die` runs; `pose_spring` goes back to (30, 1) in
  `wake_in_station`):
  - IMPACT on a world: `pose_spring` (16, 0.35), floppy, and `jolt(clampf(speed / fatal, 1, 3) / 3)`.
  - IMPACT in space (station): `pose_spring` (12, 0.5) and the same jolt.
  - AIR RAN OUT: `pose_spring` (3.5, 1), a slow slump; on the ground the topple waits 0.35 s while
    the knees go.
  - BURNED UP: no body is left, but it doesn't vanish on one frame: over 0.4 s the figure goes to the
    ship's re-entry glow colors (find them in the ship's re-entry code, all agency palette) and
    dissolves through an ordered dither, then the node hides as `_die` hides it now. It stays inside
    the palette.
  - CRUSHED: dies aboard, nothing's drawn. No change.
- **The topple.** A dead body resting on a world falls over onto its back, the way a stiff body tips
  about its feet, not at a fixed turn rate. Its lying angle is latched once, when it first rests:
  `up_heading - PI/2` if facing right, `+ PI/2` if facing left (on their back), unless the body is
  already tilted more than 0.6 rad toward the other side, which it then falls to (face down, as
  physics would have it). It tips with angular acceleration `1.5 * g / 37.0 * max(sin(tilt), 0.3)`
  rad/s², `g` being the world's pull there in units/s² (from `get_acceleration`), so the moon tips
  slowly and the planet fast; on reaching flat it bounces back once at 0.2 of its speed and settles. A
  new `static func topple_step(tilt, spin, g, delta) -> Vector2` holds the math, `tilt` measured from
  lying flat.
- **The settle.** The drawn middle never jumps. While dead and resting on a world, the body's middle is
  drawn `max(rest, falling)` above the ground, where `rest = 6 + 12.6 * absf(cos(angle from upright))`
  (lying middle 6 px, standing middle 18.6 px) and `falling` starts at the drawn middle's height when it
  first rests and drops from the impact speed, accelerating at `g`. The view gets this as an offset
  along the world's up on screen (a new `AstronautView.lift`, in pixels, applied with `feet_below`).
  The same easing covers a live EVA landing: the middle drawn 26 px up while falling eases to 18.6 px
  standing in about 0.1 s instead of jumping.
- **A dead body in the air** uses the fall view's rule too: from the side near a world, tumbling with
  its spin, limp; from above in space. Its `ground_clearance` stays `stand_height` until it first
  touches the ground, then is set to 6 with the body put at rest there (velocity = the ground's, as
  `_die_of_impact` does), and the topple and settle start. `_die` only sets 6 at once when the body is
  already on the surface.
- **The plume dies away.** On AIR RAN OUT the leak plumes fade out over 1.5 s (shorter, thinner puffs)
  instead of `leaks` emptying on the frame of death.
- The sprite-sheet fallback (`PILOT_3D` off) is out of scope.

## Tickets

### 1. Blend poses and looks

- **Does:** every change of motion and of look eases in; nothing on the pilot snaps.
- **Touches:** `scripts/pilot/astronaut_view.gd` (`_pose`, `_turn`, new `spring_step`, `pose_spring`,
  `jolt`, `lift`), new `tests/test_pilot_pose.gd`.
- **How:** keep the target values `_pose` computes now, then spring the shown values toward them and
  turn the joints from the shown values. Keep the holding hand and the wave as targets too. Blend the
  pivot basis on a look change as decided.
- **Check:** `test_pilot_pose.gd`: `spring_step` at zeta 1 reaches within 1% of a step in under
  0.2 s at omega 30 without overshooting; at zeta 0.35 it overshoots and still settles within 1 s;
  stable at delta 0.1. All existing suites still pass.

### 2. The fall view and the flail

- **Does:** stepping out of a hovering lander, walking off a ledge, or coming down from orbit, the
  pilot is seen from the side from the first frame, flailing more the faster they drop, and lands
  without flipping or jumping.
- **Touches:** `scripts/pilot.gd` (`_tick_eva` for `_falling_to_world`, `_show_figure`'s EVA and
  SURFACE branches, `_land_on_ground`, `_leave_ship`), `scripts/pilot_data.gd` (three fields),
  `scripts/pilot/astronaut_view.gd` (`&"fall"`, `flail`), `tests/test_pilot_pose.gd`.
- **How:** put the fall-view rule in a static function that takes the numbers (dominant body, low
  point, highest ground plus clearance, altitude, the path never coming back) so it can be tested
  without a scene.
- **Check:** tests for the rule (star: never; low point below ground and under 2 km: yes; in orbit:
  no; above 2 km: no) and for the flail share at 0, 60, 130, 200, 300 units/s.

### 3. Dying blends

- **Does:** a fatal landing crumples, topples onto the back, and settles into the limp pose; air
  running out slumps slowly; a station hit flings them limp; burning up flares and dissolves; the plume
  dies away; a dead body falling near a world tumbles from the side and settles when it lands.
- **Touches:** `scripts/pilot.gd` (`_die`, `_die_of_impact`, `_tick_dead`, `_show_body`,
  `_show_figure` leaks, `wake_in_station`), `scripts/pilot/astronaut_view.gd` (`topple_step`, the burn
  dissolve, plume fade), `tests/test_pilot_pose.gd`.
- **Check:** tests: `topple_step` from upright reaches flat on the planet's g in under 1 s and on the
  moon's in more than the planet's; it bounces once and comes to rest; the settle height never rises
  and never jumps more than a pixel a frame at 60 fps for impacts up to 400 units/s. All suites pass.

## Art

Nothing to draw: it's all posing the existing 3D model.

## When it's done

- DESIGN.md "Player", the 3D pilot bullet: on EVA near a world, falling to it, they're seen from the
  side and flail harder the faster they drop; every pose and view eases into the next. "Death and the
  med bay": a "Built, ticket 6" bullet for the crumple, topple, settle, slump, burn flare, and plume
  fade. A change-log row.
- Checker: frames every 0.1 s through stepping out of a lander hovering about 20 m over the planet, the
  fall, and the fatal landing until the body's still; and through a safe jump off it on the moon. Look
  for: side view from the first frame, flailing, no frame-to-frame jump, lying on the back at the end.
- Manny on the Fold: hover the lander low over the planet and EVA out; then try a short drop that
  survives, and let a breached suit run out of air on the ground.
