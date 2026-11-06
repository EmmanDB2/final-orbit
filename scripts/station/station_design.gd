# station_design.gd: what a station is made of and where it orbits.
# From DESIGN.md, "Universe generation" (stations are hubs), and CLAUDE.md (data-driven content).
class_name StationDesign
extends Resource

@export var display_name: String = ""
## The short name it shows on the pilot's markers.
@export var callsign: String = ""
## The first room is the middle of the station, and its middle is the point on the rails.
@export var rooms: Array[StationRoom] = []
## How wide one of its art pixels is, in world units.
@export var art_pixel_size: float = 2.0

@export_group("Rails")
## Height above the surface it orbits, in world units.
@export var orbit_altitude: float = 30000.0
@export var orbit_eccentricity: float = 0.0
@export var orbit_argument_of_periapsis: float = 0.0
## Where it starts around its orbit, in radians, clockwise from the right of the body.
@export var orbit_start_angle: float = 0.0
