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
## How fast the body turns, in radians per second. Positive is clockwise on screen.
@export var spin_rate: float = 0.0
## How much of the height range is under water, from 0 to 1. Zero means no sea.
@export var sea_level: float = 0.0
## How far out from the pole in the middle of the disc the ice reaches, as a share of the
## radius. Zero means none.
@export var ice_cap: float = 0.0
## How much of the ground has a crater at each of two sizes, from 0 to 1. Zero means none.
@export var crater_amount: float = 0.0
## Height where the path line turns amber: the top of the atmosphere, or a set height on
## an airless body. In world units.
@export var landing_line_altitude: float = 0.0

@export_group("Atmosphere")
## How thick the air is at the ground: 1.0 is the home planet, and 0 is airless. The air
## ends at landing_line_altitude.
@export var air_density: float = 0.0
## How quickly the air thins: every this many world units up, it drops by a factor of e.
@export var air_scale_height: float = 2000.0
## The color of the air's glow around the body.
@export var air_color: Color = Color.WHITE
## The color it turns around sunrise and sunset.
@export var air_sunset_color: Color = Color(1.0, 0.6, 0.4)
## How much of the sky has cloud, from 0 to 1. Zero means none.
@export var cloud_amount: float = 0.0
## How fast the clouds turn, in radians per second, a little different from the ground.
@export var cloud_spin_rate: float = 0.0
@export var cloud_color: Color = Color.WHITE

@export_group("Terrain")
## How tall the ground's mountains, hills, roughness, and rocks get, in world units.
@export var terrain_mountains: float = 0.0
@export var terrain_hills: float = 0.0
@export var terrain_rough: float = 0.0
@export var terrain_rocks: float = 0.0
## How deep craters get on the rim, in world units, and how many cells have one, from 0 to 1.
@export var terrain_crater_depth: float = 0.0
@export var terrain_crater_share: float = 0.0
## How tall each cliff step is, in world units. Zero means none.
@export var terrain_cliff_step: float = 0.0

## What's under the ground, from the top down: dirt, rock, deep rock, and the dark core.
@export var strata_colors: PackedColorArray = PackedColorArray()

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
