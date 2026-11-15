# Brief: the flat lander in the game, with legs that stow inside the hull

Written 2026-11-15 by Opus, from Manny's calls, for the builder agent (Sonnet).

## What and why

The original lander's art had light and shade painted in, so with the star lighting hulls (DESIGN.md,
"Lighting", outside ticket 1) it was lit twice. Manny had it remade flat (`docs/briefs/lander_flat_art.md`),
with sturdier legs that fold away out of sight: "Is it possible to put the legs UNDER the ship? So they
aren't visible when folded?" He OK'd the concept and the flat exterior ("OK, import it", 2026-11-15).
Hidden legs are for this lander and the Lander Mk II only: "Only the Lander MK II should." The Moon
Hopper keeps its visible legs.

## Decided

- The art is final: the 26 PNGs in
  `/Users/emmanuelwalters/Projects/Final Orbit Asset Editor/exports/lander_flat/game_pngs/` replace the
  ones of the same names in `art/lander/`, as they are (copy; never resize; Nearest filtering, as the
  existing `.import` files already say). The legs are now 20 x 46.
- Lander legs (`data/lander_design.tres`, `Module_leg_0` / `Module_leg_1`): left art position (44, 89),
  hinge (53, 131), travel (-53, 72); right art position (64, 89), hinge (74, 131), travel (53, 72); both
  `folds = true`, stroke 6, soak speed 62.5 as now, and `stows_inside_hull = true`. Deployed, the hinges
  land at (0, 203) and (127, 203), and the feet 42 px below them, where today's are.
- **`data/lander_design.tres` has older uncommitted changes that aren't ours** (a Godot resave: uids and
  reordered lines). Commit only the leg changes, made on top of HEAD's version of the file, and leave
  the older diff in the working tree as it was: build the committed version from
  `git show HEAD:data/lander_design.tres`, stage it with `git hash-object -w` and
  `git update-index --cacheinfo`, and make the same leg edits in the working file. Check with
  `git diff --cached` that only the leg lines are in the commit, and after committing, that
  `git diff data/lander_design.tres` still shows the older resave diff and nothing of ours. Don't stage any other file you didn't
  change (`data/*.tres`, `scenes/main.tscn`, `ship_lander_*.png` in the root, `data/test_star.tres`,
  `tests/test_moon_hopper.gd.uid` are someone else's).
- Engine, RCS, fuel and cargo numbers stay as they are. The ship is 19,826 kg dry (was 19,491, +1.7%).
- `stows_inside_hull` is a per-module setting in `scripts/ship/module_data.gd` (Landing leg group,
  default false), on for the lander's and the Mk II's legs, off for the Moon Hopper's.
- A leg that stows inside the hull:
  - draws **behind** the hull's layers, and so do its struts (`part_struts`), so it shows only where
    it's outside the hull;
  - is **shielded pixel by pixel**: a leg pixel lying over a solid exterior pixel of the body, where it
    is right now, doesn't count in the ship's outline for aero, ground contact, standing width, or hits
    (the hull pixel in front takes the hit; once that's shot away, the leg pixel behind is exposed).
    Its mass always counts. Work out the shielding when the legs move (`set_parts_out`) or the hull
    loses pixels, not every frame;
  - otherwise moves exactly as now: its hinge slides by `travel` and the art flips over the hinge in
    the first half of the way (`set_parts_out` in `scripts/ship/ship_body.gd`).
- **The Mk II**: turn it on for its legs, and set a stowed hinge and travel that tuck each leg fully
  inside its hull outline while leaving its deployed hinge where it is now (today: hinges (27, 184) and
  (100, 184), travel (-22, 16) and (22, 16), so deployed (5, 200) and (122, 200)). If its leg art can't
  fit inside its outline anywhere without being redrawn, don't redraw it: leave the Mk II's legs as they
  are (flag off), and report what doesn't fit with a screenshot path.

## Tickets

### 1. Flat lander art in

- **Does:** the lander flies with the flat art, lit by the star, with its new legs (visible, as legs
  are drawn today, until ticket 2).
- **Touches:** `art/lander/*.png` (26 files), the two leg modules in `data/lander_design.tres` (art
  position, hinge, travel; see above for how to commit it).
- **Check:** all test suites pass; `tools/ship_numbers.gd -- res://data/lander_design.tres` shows about
  19,826 kg dry, body 18,448, legs 1,378, and a center of mass empty near (-1.01, 6.48) px. Put the
  before and after figures in the report. Fix any test that pinned the old lander's mass or leg
  numbers, saying which.

### 2. Legs that stow inside the hull

- **Does:** the lander's legs are out of sight when stowed, slide down and out from behind the hull
  when lowered, and the ship's outline, aero, ground contact, standing width and hits ignore them while
  they're behind the hull.
- **Touches:** `scripts/ship/module_data.gd` (`stows_inside_hull`), `scripts/ship/ship_body.gd` (draw
  order, shielding, outline, standing width, hits), `scripts/ship.gd` if the drawing lives there, the
  hangar's ship picture if it draws legs itself, `data/lander_design.tres` (the flag on both legs).
- **Check:** a new test: with legs stowed, the lander's outline and standing width are the same as with
  no legs at all, and a hit aimed at a stowed leg's pixel takes the hull pixel in front; deployed,
  ground contact is the feet, as before; the mass is the same stowed and deployed. Existing suites pass.

### 3. The Mk II's legs stow inside its hull

- **Does:** as ticket 2, for the Lander Mk II; the Moon Hopper is unchanged.
- **Touches:** `data/lander_mk2_design.tres` (its two leg modules: flag, hinge, travel; its working
  copy has no outside changes, so commit it normally).
- **Check:** every stowed leg pixel is over a solid exterior pixel (print the count outside: 0); the
  deployed feet are where they were; suites pass.

## When it's done

- Export the Android APK and install it on the Fold (it's plugged in), per the builder's usual steps.
- Append one entry per ticket to `docs/LEARNING_LOG.md`.
- Report back: commit hashes, the ship numbers before and after for the lander (and the Mk II if its
  numbers moved), the test results, and anything that didn't fit.
- Opus updates DESIGN.md afterwards; don't edit it.
