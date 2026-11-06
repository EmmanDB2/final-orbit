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
## Height where the path line turns amber: the top of the atmosphere, or a set height on
## an airless body. In world units.
@export var landing_line_altitude: float = 0.0

@export_group("Rails")
## Average distance from the body this one orbits. Zero for the body at the center.
@export var orbit_semi_major_axis: float = 0.0
## How stretched the orbit is: 0 is a circle, close to 1 is a long ellipse.
@export var orbit_eccentricity: float = 0.0
## Direction of the orbit's closest point, in radians.
@export var orbit_argument_of_periapsis: float = 0.0
## How far along its orbit the body starts, as a mean anomaly in radians.
@export var orbit_start_angle: float = 0.0


## Gravitational parameter: how strongly the body pulls at any distance.
func get_mu() -> float:
	return surface_gravity * radius * radius
