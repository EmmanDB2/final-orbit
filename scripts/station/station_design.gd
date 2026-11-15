# station_design.gd: what a station is made of and where it orbits.
# From DESIGN.md, "Universe generation" (stations are hubs), and CLAUDE.md (data-driven content).
class_name StationDesign
extends Resource

@export var display_name: String = ""
## What kind of station it is, for its card.
@export var chip: String = "STATION"
## The short name it shows on the pilot's markers.
@export var callsign: String = ""
## The first room is the middle of the station, and its middle is the point on the rails.
@export var rooms: Array[StationRoom] = []
## How wide one of its art pixels is, in world units.
@export var art_pixel_size: float = 2.0

@export_group("Modules")
## A station built from modules instead of rooms: the first is the middle of the station, and each
## one bolts onto an earlier module's port through the standard hatch. With none, the rooms above
## are used, as they always were.
@export var modules: Array[StationModule] = []
## The dock port the pilot wakes up beside after the med bay, when no module has a wake bed.
@export var home_port: String = ""
## What an old save's docked port number meant, by name, so the number can be turned into a port:
## the old number is the index here.
@export var legacy_ports: PackedStringArray = PackedStringArray()
## The standard hatch between two modules, one picture a layer, each 48 x 40 pixels, drawn with its
## length running between the ports. It's drawn turned a quarter when the joint runs sideways.
@export var hatch_floor: Texture2D
@export var hatch_walls: Texture2D
@export var hatch_overhead: Texture2D
@export var hatch_roof: Texture2D
## The two leaves of a hatch's sliding door, and where each one's top left corner is on the hatch's
## picture, closed and open.
@export var hatch_door_left: Texture2D
@export var hatch_door_right: Texture2D
@export var door_left_closed: Vector2i = Vector2i(8, 17)
@export var door_left_open: Vector2i = Vector2i(-10, 17)
@export var door_right_closed: Vector2i = Vector2i(22, 17)
@export var door_right_open: Vector2i = Vector2i(40, 17)
## The clear opening through the hatch's floor, on its 48 x 40 picture.
@export var hatch_passage: Rect2i = Rect2i(8, 0, 32, 40)
## The docking ring on the outer end of a docking collar (64 x 24, drawn for a collar facing down),
## and the blank plate over a capped port (48 x 12).
@export var docking_ring_roof: Texture2D
@export var capped_plate: Texture2D

@export_group("Lighting")
## Whether its lamps are on. A derelict's aren't.
@export var powered: bool = true
## With the power off: every this-many lamps is an emergency lamp, pulsing dim red, and every
## this-many is a failing one that sputters. Zero for none.
@export var emergency_every: int = 3
@export var failing_every: int = 7
@export var emergency_brightness: float = 0.5
## How far an emergency lamp's light reaches, as a share of a ceiling lamp's.
@export var emergency_reach_share: float = 0.6
## The light everywhere inside with the power off, from 0 to 1: little more than starlight through
## the windows.
@export var dark_ambient: float = 0.08
## The light everywhere inside, with no lamp near, from 0 to 1, and how bright each lamp is.
@export var ambient_light: float = 0.32
@export var lamp_brightness: float = 0.85

@export_group("Docking")
## How close a ship's hatch has to get to a free port's middle to dock: along the port's line, and
## off to the side of it, in world units.
@export var dock_reach: float = 14.0
@export var dock_across: float = 14.0
## The fastest a hatch can be moving against the port and still dock, in world units per second.
@export var dock_speed: float = 6.0
## How far the nose can point away from the port's line and still dock, in degrees.
@export var dock_angle_degrees: float = 10.0

@export_group("Rails")
## Height above the surface it orbits, in world units.
@export var orbit_altitude: float = 30000.0
@export var orbit_eccentricity: float = 0.0
@export var orbit_argument_of_periapsis: float = 0.0
## Where it starts around its orbit, in radians, clockwise from the right of the body.
@export var orbit_start_angle: float = 0.0
