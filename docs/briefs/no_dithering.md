# Brief: no dithering

Written 2026-11-14 by Opus, from Manny's calls, for the builder agent (Sonnet).

## What and why

Manny: "I'm not really messing with the 'dithering' (the pixel cross patterns) literally anywhere they
are. Can we remove them from like everything? Planets, Comets, Stations, etc". So every ordered dither,
Bayer pattern and checker of pixels between two tones or two alpha bands goes. What stays is the banded,
palette-stepped look: the same band counts, the same ramps, the same lighting, with each pixel snapped
to its nearest step and a clean hard edge where one band meets the next. Lives in DESIGN.md, "Lighting"
and "Art direction", and the comet line in "Mid-flight events".

## Decided

- **The rule:** wherever a pixel picks between two neighbouring steps with a pattern (a Bayer threshold,
  `mod(x + y, 2)`, a per-pixel hash compared to a band fraction), replace the pattern with its average,
  0.5. `floor(level) + (fract(level) > bayer)` becomes `floor(level + 0.5)`: the nearest step, so
  average brightness and band positions stay where they were.
- A checker added as a small bias (`+ checker * k`) is dropped outright, not replaced.
- Band counts, ramps, colors, light directions, and every other number stay as they are.
- Don't touch hand-drawn pixel art in `art/`. Random noise that is texture, not a between-steps pick
  (starfield star placement, cloud cover, the flame's 2 px chunks, flicker and hash breakup at its tail,
  the RCS puffs' and re-entry glow's `speckle()`, surface speckle), stays.
- **The pilot burning up** (`astronaut_pixels.gdshader`) can't take the 0.5 rule, since its dither is a
  dissolve over time and 0.5 would make the whole suit flip at once. Instead both `flare` and `dissolve`
  sweep down the sprite as a hard line from the head to the feet: a pixel flares when
  `flare > UV.y` and drops out when `dissolve > UV.y` (top of the texture first). Keep the
  lighter-is-hotter color pick as it is.
- Remove the `sky_dither` uniform from `planet.gdshader`. Its `shader_parameter/sky_dither` lines in
  `scenes/main.tscn` stay (harmless; that file has someone else's uncommitted changes, so never stage it).
- `PaletteLight.lit_color` loses its `x` and `y` parameters, and `bayer4`/`BAYER` are deleted wherever
  nothing else uses them.
- Comments and header comments that say "dither", "Bayer" or "checker" are rewritten to say hard bands.

## Tickets

### 1. Palette lighting without dither

- **Does:** lit hulls, the station outside and inside, and anything else stepped down the palette shade
  in hard bands; the emergency red light ends in a clean edge.
- **Touches:** `shaders/palette_light.gdshaderinc` (`bayer4`, the step pick in the palette-lit function),
  `scripts/palette_light.gd` (`BAYER`, `lit_color`), its caller `scripts/ship/hull_light.gd:101`,
  `shaders/interior_light.gdshader` (`red > bayer4(pixel)` becomes `red > 0.5`), `shaders/hull_light.gdshader`
  if it has its own, and tests that call `lit_color` or expect the dither.
- **How:** the rule. `palette_lit(art, light, pixel)` may keep its `pixel` argument only if something
  still needs it; otherwise drop it and update callers.
- **Check:** all test suites pass; a throwaway check that `lit_color` at light 0.55 gives the same color
  at every x, y.

### 2. Sky, planets, star, re-entry and comet without dither

- **Does:** the planet's sky bands, air-glow day side, sunsets, day/dusk/night steps from far out, the
  ground cross-section's edge, the star's glow rings, the re-entry glow, and the comet's glow bands and
  nucleus tones are all hard-edged bands.
- **Touches:** `shaders/planet.gdshader` (`dither()`, `pattern` in `air_day`, sky `level`, `sunset`,
  `in_section`'s `(pattern - 0.5) * 40.0` which becomes 0, the daylight `checker`; the `sky_dither`
  uniform), `shaders/star.gdshader` (glow `checker`), `shaders/reentry.gdshader` (the `+ 0.04` checker),
  `shaders/comet_glow.gdshader` and `shaders/comet_nucleus.gdshader` (`bayer4`; also drop the nucleus's
  `hash * 0.06` light jitter before quantising, which would only rag the band edges), and the header comment in
  `scripts/event/comet_view.gd`.
- **How:** the rule. For the sky, with the pattern at 0.5 and the old 0.4 folded in, `level` is
  `floor(reach * reach * steps + 0.8)`.
- **Check:** all test suites pass.

### 3. The pilot burning up without dither, and a last sweep

- **Does:** a burning pilot flares and breaks up as a hard line moving head to feet.
- **Touches:** `scripts/pilot/astronaut_pixels.gdshader` (`bayer`, the flare and dissolve picks, its
  comments), the doc comment on `burn` in `scripts/pilot/astronaut_view.gd`.
- Also the ship's ground shadow, `scripts/ground_effects.gd` (~line 140): higher up it skips every other
  column, then three in four, which reads as a pattern. Instead the strip narrows with hard ends, keeping
  only its middle: all of it below `fade` 0.35, the middle 60% of its columns above 0.35, the middle 30%
  above 0.7 (rows stay 3 or 2 as now).
- **How:** as Decided. Then grep the whole project (`scripts/`, `shaders/`, `tools/`, `tests/`, scenes) for
  `bayer`, `dither`, `checker`, `mod(` and `% 2` and fix anything left that picks between steps by pattern.
- **Check:** all test suites pass; the grep finds nothing outside `docs/` and `art/`.

## Working in a shared checkout

Another session is working in this checkout on the lander's legs: stay out of `scripts/ship.gd`,
`scripts/ship/ship_body.gd` and module data. Stage only the files you changed, by path (never `git add -A`
or `.`). Leave the older uncommitted files alone: `data/*.tres`, `scenes/main.tscn`, the
`ship_lander_*.png` files in the root, `data/test_star.tres`, `tests/test_moon_hopper.gd.uid`. Commit after
each ticket.

## When it's done

- DESIGN.md: "Lighting" and "Art direction" say hard bands, nearest step, no dither; the comet line drops
  "dithered"; a change-log row: dithering cut everywhere, on Manny's call, 2026-11-14 [Locked].
- The checker screenshots the planet (far and close, sky and cross-section), the station outside and
  inside, a lit ship, the comet close up and whole, and the pilot, looking for any cross or checker
  pattern left.
- Manny tries it on the Fold: fly past the planet, dock, and catch a comet.
