# feature_flags.gd: on/off switches for systems from later tiers, so the core build
# always runs. From DESIGN.md, "Tech" (feature flags per tier).
class_name FeatureFlags

## Tier 1. Space takes on the star's color, fading toward black far from it.
const STAR_TINT: bool = true
