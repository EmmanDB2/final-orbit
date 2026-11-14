# Brief: the comet's look

Written 2026-11-14 by Opus, from Manny's calls, for the builder agent (Sonnet).

## What and why

Manny, on the passing comets: "its trail doesn't even change direction and the comet itself looks like
a placeholder." The tail points straight away from the star, which is 45 million units off, so during a
flyby it never visibly turns, and the nucleus is two flat polygons. This gives the comet the look of a
real one: two tails, a dust tail that curves along where it's been and sweeps round as it swings past
the planet, and a straight ion tail away from the star; a tumbling, lit, cratered nucleus with gas jets;
and everything drawn in chunky game pixels with banded, dithered glow, the way the engine flame is. It
lives in DESIGN.md, "Mid-flight events" (passing comets). Gameplay doesn't change: the scan reach,
countdown, pay, and the nucleus not being solid all stay as they are.

## Decided

- Two tails. The **ion tail** is straight, away from the star, thin and pale blue, with streamers that
  ripple outward over time. The **dust tail** is wider, cream, and follows the comet's own path back
  from the nucleus, measured against the planet it's passing, bending away from the star as it goes. As
  the comet swings round the planet the dust tail sweeps with it, so the two tails split apart and come
  together during a pass. This is a game choice over strict physics, made so the tail reads as motion.
- The dust tail is as long, along its path, as `dust_length` (new, 60,000 units); the ion tail is as
  long as `tail_length` (90,000, unchanged).
- The coma stays as wide as the scan's reach (`scan_reach`), brightest at the nucleus, a little brighter
  on the star's side.
- Glow is drawn in **5 alpha bands with a 4 x 4 Bayer dither** between neighbours, per game pixel, never
  as a smooth gradient. The nucleus uses the same dither between its tones.
- The nucleus is a lumpy rock, shaded as a lumpy sphere lit by the star, in a 5-tone ramp built from its
  colors: near-black shadow, `dust_color`, a midtone, `nucleus_color`, and a highlight. Its outline,
  craters, and spin come from the comet's name, so the same comet always looks the same (determinism
  rule). It tumbles: one turn every 3 to 6 minutes of game time, either way round, picked from the name.
  The terminator stays toward the star while the surface turns under it.
- It goes dark with the star. When the star is hidden, take how much of it can be seen from the same
  place the hulls get it (`HullLight.aim`'s `sun`, from `scripts/sunlight.gd`), and leave only the
  ambient shadow tone and the coma's faint glow.
- Jets: 2 or 3 per comet, from fixed spots on the nucleus, picked from the name. A jet only sprays while
  its spot faces the star (it turns with the tumble), as a narrow faint fan in the glow color about 4
  nucleus radii long, flickering.
- No outline: it's nature's, and outlines are for human-made things.
- When the nucleus is under 1.5 px across, it's a single 2 x 2 dot in the glow color, not a gray square,
  with the tails and coma still drawn.
- New `EventType` fields, in `data/events/comet.tres` (colors are nature's: never 7FE3D6 or D9541E):
  `ion_color` 9DB8F2, `dust_tail_color` E6D8B8, `dust_length` 60000.0, `dust_lift` 0.35 (how far the
  dust tail's end is pushed away from the star, as a share of its length), `tail_width` 0.16 (each
  tail's widest, at its end, as a share of its length; the ion tail is a third as wide), `jets` 3 (most).
- Out of scope: a solid nucleus, a split nucleus, sounds, and anything about the scan or the countdown.

## Tickets

### 1. The nucleus

- **Does:** close up, the nucleus is a lumpy, cratered rock lit on the star's side in banded, dithered
  tones, slowly tumbling. Far out, it's a small bright dot.
- **Touches:** new `shaders/comet_nucleus.gdshader`; `scripts/event/comet_view.gd` (replace the two
  polygons with a quad drawn with that shader); `scripts/event/event_type.gd` and
  `data/events/comet.tres` for the new fields; `scripts/event/event_scene.gd` if `CometView` needs the
  sunlight or gravity model passed in.
- **How:** draw a quad 2.4 nucleus radii across, in screen pixels, centred on the comet. In the shader,
  turn the fragment's offset by minus the spin angle, then find its angle round the middle and the
  outline's radius there from 18 seeded bulges (0.72 to 1.0, as now), blended smoothly between, not
  joined with straight lines. Outside that, discard. Inside, the height is
  `h = sqrt(1 - (d / r)^2)`, and the normal is `normalize(vec3(offset / r, h))`, then nudged by seeded
  craters: 6 to 10 bowls, each darkening its floor and tilting the normal in on its rim. Light is the
  dot of the normal with the star's direction, turned into the nucleus's own frame (so the lit side
  stays toward the star as it spins), times `sun`, plus 0.08 ambient. Pick a tone from the 5-tone ramp
  with the Bayer dither between neighbouring bands. Pass the seed, the spin angle, the light direction,
  the radius in pixels, and the colors as uniforms. Work out the spin angle in `place()` from
  `event.state.time`, so it follows time warp.
- **Check:** the event test suites still pass. A throwaway check makes a comet with a fixed name and
  confirms the same name gives the same seed, spin period, and craters twice, and a different name gives
  different ones.

### 2. The coma and both tails

- **Does:** the coma, a straight pale-blue ion tail away from the star, a cream dust tail that trails
  back along the comet's path and curves away from the star, and the jets, all in banded, dithered
  pixels. Over a pass, the dust tail visibly sweeps round while the ion tail holds still.
- **Touches:** new `shaders/comet_glow.gdshader`; `scripts/event/comet_view.gd`; whatever passes the
  gravity model in from `scripts/event/event_scene.gd`.
- **How:**
  - **The dust path.** Every 2 seconds of game time, and whenever time jumps by more than that (warp,
    loading), rebuild it: step back from now in age, `propagate` a copy of `event.state` by minus that
    age, and keep where it was relative to the centre of the world in `event.place["world"]` at that
    past time. Take about 24 points, spaced so they add up to `dust_length` along the path (go back in
    steps of `dust_length / 24 / speed against the world`, and stop at 900 seconds whatever happens).
    When drawing, each point is the world's centre now plus that offset, plus
    `away_from_star * dust_lift * dust_length * (s / dust_length)^2`, where `s` is how far along the
    path it is. Hand the points to the shader as a `vec2` array uniform in the quad's pixels.
  - **The quad.** One quad covering the coma, both tails, and the dust path's points, in screen pixels.
  - **The shader.** Add up three glows, each giving a strength from 0 to 1:
    - The coma: falling off from the middle out to `scan_reach`, offset 10 percent of it toward the
      star.
    - The ion tail: along the away-from-star line, as wide as `nucleus_radius` at the head, growing to
      `tail_width / 3` of its length at the end, fading along it. Streamers: scale its brightness with
      1D value noise across the tail, moving outward along it with time, and bending it sideways a
      little further out.
    - The dust tail: the nearest distance to the path's segments and how far along it that is, as wide
      as the nucleus at the head, growing to `tail_width` of `dust_length`, brightest along its inner
      edge (the side toward the star) and fading along it.
    - The jets: for each jet whose spot faces the star, a fan 20 degrees wide out of the nucleus's edge
      in the direction the spot faces, flickering at about 8 times a second.

    Mix the colors by strength (`glow_color` for the coma and jets, `ion_color`, `dust_tail_color`),
    then put the total strength into the 5 alpha bands, with the dither, topping out at 0.45 alpha so
    the stars still show through the tails.
  - Draw the glow first and the nucleus over it. Keep the reach check in `place()` so off-screen comets
    cost nothing, and include the dust path's points in it.
- **Check:** the event test suites still pass. A throwaway check runs a comet through its whole pass
  under warp and records the angle between the two tails at its head every 30 seconds: it should change
  by at least 60 degrees over the pass, while the ion tail's angle changes by under 2.

## Art

None to draw: the comet is all code and shaders, being nature's.

## When it's done

- DESIGN.md, "Mid-flight events": rewrite the passing comets line so it describes the lumpy, tumbling,
  cratered nucleus with jets, and the two tails (ion straight away from the star, dust trailing along
  its path and bent away from the star) \[Leaning\]. Add a change-log row: "The comet gets two tails,
  the dust tail trailing its path round the planet so it turns during a pass, and a tumbling, cratered,
  lit nucleus with jets, all in dithered pixels; Manny's call that the old tail never turned."
- The checker: screenshots of a comet at three zooms (nucleus filling much of the screen, the whole
  coma, the whole tail) and at three times in one pass (coming in, at closest pass, going away), on the
  inner screen. Look for: bands and dither, not smooth gradients; the two tails splitting as it swings
  past; the lit side toward the star; nothing in telemetry cyan or agency orange.
- For Manny on the Fold: wait for a comet (or warp to one), follow it through its closest pass, and
  watch the dust tail swing round while the ion tail holds.
