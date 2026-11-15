# station_port.gd: a named opening on a station module, and what it's for. From DESIGN.md,
# "Universe generation" (stations are hubs) and the new Kapteyn-3's ports.
class_name StationPort
extends Resource

## The kinds a port can be: bolted to another module through a hatch, a ship docks here only, EVA goes
## out and in here only, or a blank plate with nothing behind it.
const INNER: String = "inner"
const DOCK: String = "dock"
const AIRLOCK: String = "airlock"
const CAPPED: String = "capped"

## What saves and the layout call it, such as "dock_s". Unique in a station.
@export var port_name: String = ""
## The outermost pixel of the port on its module's canvas: the middle of its wall, on the outside.
@export var point: Vector2i = Vector2i.ZERO
## Which way it faces, out of the module: one of (1, 0), (-1, 0), (0, 1), (0, -1).
@export var face: Vector2i = Vector2i.DOWN
@export_enum("inner", "dock", "airlock", "capped") var kind: String = "inner"
