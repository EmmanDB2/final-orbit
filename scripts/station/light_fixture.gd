# light_fixture.gd: one light placed in a station's data: where it is, how far it reaches, what color
# its light is, and which power circuit feeds it. From DESIGN.md, "Lighting" (planned lighting for
# stations).
class_name LightFixture
extends Resource

## The tints a fixture can have.
const WHITE: String = "white"
const WARM: String = "warm"
const RED: String = "red"
## The circuits: on while powered, only lit with the power off and pulsing, on but flickering out now
## and then (and sputtering with the power off), and on whatever the power.
const MAINS: String = "mains"
const EMERGENCY: String = "emergency"
const FAILING: String = "failing"
const ALWAYS: String = "always"

## Where it is, in pixels from the top left of what it belongs to: a module's canvas, or a prop's
## picture.
@export var point: Vector2 = Vector2.ZERO
## How far its light reaches, in metres.
@export var reach_metres: float = 3.0
@export_enum("white", "warm", "red") var tint: String = "white"
@export_enum("mains", "emergency", "failing", "always") var circuit: String = "mains"
## How bright it is at its middle, from 0 to 1.
@export var brightness: float = 1.0
