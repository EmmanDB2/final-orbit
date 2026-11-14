# sunlight.gd: how much of the star can be seen from a point. The star sits at the world's middle, and
# each world casts a shadow straight away from it, as wide as the world, with a soft edge where the
# star's only partly hidden. Anything lit by the star asks here, so ships, stations, and the pilot all
# go dark together on a world's night side. From DESIGN.md, "Lighting" (outside).
class_name Sunlight
extends RefCounted

## How wide the soft edge of a shadow is, as a share of the world's radius.
const SOFT_EDGE: float = 0.04


## From 0, deep in a world's shadow, to 1, in full starlight.
static func at(gravity_model: GravityModel, x: float, y: float, time: float) -> float:
	var point := Vector2(x, y)
	var seen: float = 1.0
	for body in range(1, gravity_model.get_body_count()):
		var at_body: PackedFloat64Array = gravity_model.get_body_position(body, time)
		var middle := Vector2(at_body[0], at_body[1])
		var away: Vector2 = middle.normalized()
		var from_middle: Vector2 = point - middle
		var behind: float = from_middle.dot(away)
		if behind <= 0.0:
			continue
		var radius: float = gravity_model.get_body_radius(body)
		var off_axis: float = absf(away.cross(from_middle))
		var edge: float = radius * SOFT_EDGE
		seen = minf(seen, smoothstep(radius - edge, radius + edge, off_axis))
	return seen
