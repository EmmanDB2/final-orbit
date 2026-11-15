# station_prop.gd: a piece of furniture, machinery, or decoration from the shared library, seen from
# above. Floor props are painted on the floor, standing props are things the pilot walks around and
# behind, and overhead props hang over the pilot. A prop can be a terminal to use, and can carry a
# light. From DESIGN.md, "Universe generation" (stations) and "Lighting".
class_name StationProp
extends Resource

const FLOOR: String = "floor"
const STANDING: String = "standing"
const OVERHEAD: String = "overhead"

## What a spot is for: the gig board, the ship services terminal, the bed the pilot wakes up beside,
## or the breaker panel that switches the station's power.
const GIG_BOARD: String = "gig_board"
const SERVICE: String = "service"
const WAKE: String = "wake"
const POWER: String = "power"

@export var id: String = ""
@export var texture: Texture2D
@export_enum("floor", "standing", "overhead") var layer: String = "standing"
## For a standing prop, the part of its picture that's solid, so the floor under it can't be walked
## on, in its own pixels. Empty for anything else.
@export var footprint: Rect2i = Rect2i()
## How many pixels at the front (the bottom of the picture) are the prop's tall front lip, which the
## pilot passes behind the top of but in front of the base of. Zero for a flat prop.
@export var lip: int = 0
## What a pilot can do at it: "gig_board", "service", "wake", "power", or nothing.
@export var spot_kind: String = ""
## Where the pilot uses it, in its own pixels. Left at (-1, -1), it's the middle of the footprint.
@export var spot_at: Vector2 = Vector2(-1.0, -1.0)
## A light it carries, with its point in the prop's own pixels, or nothing.
@export var light: LightFixture
## Whether its green leaves are a plant's, which take a green lit ramp instead of staying glowing.
@export var plant: bool = false


## Where the spot is in the prop's own pixels, before any turn.
func spot_point() -> Vector2:
	if spot_at.x >= 0.0 and spot_at.y >= 0.0:
		return spot_at
	if footprint.size != Vector2i.ZERO:
		return Vector2(footprint.position) + Vector2(footprint.size) * 0.5
	return Vector2(texture.get_size()) * 0.5 if texture != null else Vector2.ZERO
