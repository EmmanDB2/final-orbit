# star_light.gd: works out how much of the star's light and heat reach the ship.
# From DESIGN.md, "Art direction" (star tint, behind FeatureFlags.STAR_TINT) and "Hazards"
# (star heat).
#
# The star is body 0, so it sits at the world origin. Light falls off with the square of
# the distance, like real starlight. Adding 1 below keeps the level at a maximum of 1.0
# instead of blowing up at the star itself.
extends Node

## Emitted every physics tick with the star's color and a light level from 0.0 to 1.0.
signal star_light_changed(color: Color, level: float)

## Emitted every physics tick with how much the star is heating the ship, where 1.0 is the
## top of a hull's scale.
signal star_heat_changed(share: float)

## The star lighting this system.
@export var star: StarData


func _on_ship_world_position_changed(x: float, y: float) -> void:
	star_heat_changed.emit(star.heat_distance * star.heat_distance / maxf(x * x + y * y, 1.0))
	if not FeatureFlags.STAR_TINT:
		return

	var dx: float = x / star.falloff_distance
	var dy: float = y / star.falloff_distance
	star_light_changed.emit(star.color, 1.0 / (1.0 + dx * dx + dy * dy))
