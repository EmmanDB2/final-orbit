# flight_view.gd: decides where the camera looks and how far out it is.
# From DESIGN.md, "Camera, zoom, and landing".
#
# Zooming changes what gets drawn, never the pixel size, so the Camera2D's own zoom
# stays at 1 and its position stays at 0,0. Instead, this signals the current view and
# each system places itself on screen from that.
extends Camera2D

## What a zoom tier keeps in the middle of the screen.
enum Focus {
	SHIP,
	DOMINANT_BODY,
	SYSTEM_CENTER,
}

## Emitted every physics tick with the world point at the middle of the screen, and
## the zoom in screen pixels per world unit.
signal view_changed(center_x: float, center_y: float, pixels_per_unit: float)

## Zoom tiers from closest to farthest, in screen pixels per world unit.
@export var tier_scales: PackedFloat64Array = PackedFloat64Array([1.0, 1.0 / 8.0, 1.0 / 128.0, 1.0 / 800.0, 1.0 / 2400.0])
## What each tier keeps centered.
@export var tier_focus: Array[Focus] = [Focus.SHIP, Focus.SHIP, Focus.SHIP, Focus.DOMINANT_BODY, Focus.SYSTEM_CENTER]
## The tier the game starts in.
@export var tier: int = 3

var _gravity_model: GravityModel
var _state: ShipState


## Starts following a flight.
func start_view(gravity_model: GravityModel, state: ShipState) -> void:
	_gravity_model = gravity_model
	_state = state


func _on_ship_world_position_changed(x: float, y: float) -> void:
	if Input.is_action_just_pressed("zoom_in"):
		tier = maxi(tier - 1, 0)
	if Input.is_action_just_pressed("zoom_out"):
		tier = mini(tier + 1, tier_scales.size() - 1)

	var center_x: float = 0.0
	var center_y: float = 0.0
	match tier_focus[tier]:
		Focus.SHIP:
			center_x = x
			center_y = y
		Focus.DOMINANT_BODY:
			var body: int = _gravity_model.get_dominant_body(x, y, _state.time)
			var body_position: PackedFloat64Array = _gravity_model.get_body_position(body, _state.time)
			center_x = body_position[0]
			center_y = body_position[1]
	view_changed.emit(center_x, center_y, tier_scales[tier])
