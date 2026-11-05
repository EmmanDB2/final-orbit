# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing".
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom
# stays at 1 and its position stays at 0,0. Instead, this signals the current view and
# each system places itself on screen from that.
extends Camera2D

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)

## Zoom tiers from closest to farthest, in screen pixels per world unit.
@export var tier_scales: PackedFloat64Array = PackedFloat64Array([1.0, 1.0 / 128.0, 1.0 / 800.0, 1.0 / 2400.0])
## Whether each tier centers on the ship. The others center on the planet.
@export var tier_follows_ship: Array[bool] = [true, true, false, false]
## The tier the game starts in.
@export var tier: int = 2


func _on_ship_world_position_changed(x: float, y: float) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		tier = maxi(tier - 1, 0)
	if Input.is_action_just_pressed("zoom_out"):
		tier = mini(tier + 1, tier_scales.size() - 1)

	var follows_ship: bool = tier_follows_ship[tier]
	view_changed.emit(x if follows_ship else 0.0, y if follows_ship else 0.0, tier_scales[tier])
