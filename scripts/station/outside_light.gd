# outside_light.gd: one light seen on a station from outside: a nav light, the strobe, a docking
# collar's approach light, or its floodlight. From DESIGN.md, "Lighting" (outside).
class_name OutsideLight
extends Resource

const NAV_RED: String = "nav_red"
const NAV_GREEN: String = "nav_green"
const STROBE: String = "strobe"
const APPROACH: String = "approach"
const FLOOD: String = "flood"

## Where it is on its module's canvas, in pixels.
@export var point: Vector2 = Vector2.ZERO
@export_enum("nav_red", "nav_green", "strobe", "approach", "flood") var kind: String = "nav_red"
## For approach lights and floodlights, which port's collar they belong to.
@export var port_name: String = ""
