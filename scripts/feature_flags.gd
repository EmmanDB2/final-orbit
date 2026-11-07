# feature_flags.gd: on/off switches for systems from later tiers, so the core build
# always runs. From DESIGN.md, "Tech" (feature flags per tier).
class_name FeatureFlags

## Tier 1. Space takes on the star's color, fading toward black far from it.
const STAR_TINT: bool = true
## Moved up from Tier 2. The pilot can leave the ship on a jetpack.
const EVA: bool = true
## Moved up from Tier 3. The pilot can board a station and walk around inside it.
const INTERIORS: bool = true
