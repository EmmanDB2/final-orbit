# landing_path.gd: draws the part of the ship's path that's flown through air, and the landing zone
# on the ground at the end of it, both in telemetry amber.
# From DESIGN.md, "Physics" (Landing prediction and Landing line).
#
# Everything here is measured from the body's middle, in world units, against the ground as it
# was when the forecast's line through the air begins. The trajectory preview puts this node on
# the body's middle, scales it to the view, and turns it with the ground, so the line stays on the
# ground it comes down on without being worked out again each tick.
class_name LandingPath
extends Node2D

## How tall the marks at each end of the landing zone are, on screen, in pixels.
const ZONE_END_HEIGHT: float = 7.0

var color: Color = Color.WHITE
## The path, and how far along it the ship has got: the line is drawn from where the ship is now,
## through the points from this one on. A negative start means the ship isn't on it yet, and the
## whole path is drawn.
var points: PackedVector2Array = PackedVector2Array()
var from_index: int = -1
var from_point: Vector2 = Vector2.ZERO
## The ground between the two ends of the landing zone.
var zone: PackedVector2Array = PackedVector2Array()
## How many screen pixels a world unit is, to keep the zone's end marks one size.
var pixels_per_unit: float = 1.0


func clear() -> void:
	points = PackedVector2Array()
	zone = PackedVector2Array()
	from_index = -1
	queue_redraw()


func _draw() -> void:
	# A width of -1 draws a true one-pixel line, whatever the node's scale.
	if from_index < 0:
		if points.size() >= 2:
			draw_polyline(points, color, -1.0)
	elif from_index < points.size():
		var line := PackedVector2Array([from_point])
		line.append_array(points.slice(from_index))
		draw_polyline(line, color, -1.0)

	if zone.size() >= 2:
		draw_polyline(zone, color, -1.0)
		var height: float = ZONE_END_HEIGHT / maxf(pixels_per_unit, 0.0000001)
		for end: Vector2 in [zone[0], zone[zone.size() - 1]]:
			# Straight up from the ground, which is away from the body's middle.
			draw_line(end, end + end.normalized() * height, color, -1.0)
