# feature_flags.gd: on/off switches for systems from later tiers, so the core build
# always runs. From DESIGN.md, "Tech" (feature flags per tier).
class_name FeatureFlags

## Tier 1. Space takes on the star's color, fading toward black far from it.
const STAR_TINT: bool = true
## Moved up from Tier 2. The pilot can leave the ship on a jetpack.
const EVA: bool = true
## Moved up from Tier 3. The pilot can board a station and walk around inside it.
const INTERIORS: bool = true
## Moved up from Tier 2 with EVA. The pilot can step out of a landed ship and walk on the ground.
const WALKING_ON_WORLDS: bool = true
## Being tried. The pilot is a 3D model drawn as pixel art, instead of the sprite sheets.
const PILOT_3D: bool = true
## Tier 1. The air pushes on each part of the ship's outline, so it has lift, turns to its own trim,
## and can out-turn the RCS. Off, it's the old drag on one box, which never turns the ship.
const AERODYNAMICS: bool = true
