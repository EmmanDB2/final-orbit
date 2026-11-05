# body_data.gd: the numbers that describe a planet or moon.
# From DESIGN.md, "Physics" (each body's mass sets its gravity) and "Art direction"
# (each planet uses about 6 colors).
class_name BodyData
extends Resource

@export var display_name: String = ""
## Radius in world units. One world unit is one pixel at the closest zoom.
@export var radius: float = 150000.0
## Gravity at the surface, in world units per second squared.
@export var surface_gravity: float = 200.0
## Six surface colors, lowest ground to highest.
@export var surface_colors: PackedColorArray = PackedColorArray()
## Seed for the surface pattern. The same seed always draws the same planet.
@export var terrain_seed: int = 1


## Gravitational parameter: how strongly the body pulls at any distance.
func get_mu() -> float:
	return surface_gravity * radius * radius
