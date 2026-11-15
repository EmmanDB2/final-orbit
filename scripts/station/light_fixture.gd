# light_fixture.gd: one light placed in a station's data: where it is, how far it reaches, what color
# its light is, which power circuit feeds it, and whether it glows red when the power's out. From DESIGN.md, "Lighting" (planned lighting for
# stations).
class_name LightFixture
extends Resource

## The tints a fixture can have.
const WHITE: String = "white"
const WARM: String = "warm"
const RED: String = "red"
## The circuits: on while powered; on but flickering out now and then (and sputtering with the power
## off); and on whatever the power. Emergency light isn't a circuit: a fixture is on_emergency or not.
const MAINS: String = "mains"
const FAILING: String = "failing"
const ALWAYS: String = "always"
## How far an emergency fixture's red pool reaches, as a share of its reach.
const EMERGENCY_REACH_SHARE: float = 0.6

## Where it is, in pixels from the top left of what it belongs to: a module's canvas, or a prop's
## picture.
@export var point: Vector2 = Vector2.ZERO
## How far its light reaches, in metres.
@export var reach_metres: float = 3.0
@export_enum("white", "warm", "red") var tint: String = "white"
@export_enum("mains", "failing", "always") var circuit: String = "mains"
## With the power out, this one glows red at its own spot, pulsing, with a pool 0.6 of its reach.
@export var on_emergency: bool = false
## Whether it's a ceiling strip: its pool is a stadium along its room's light axis, 2.4 m long plus its
## reach, not a circle. Screens, signs, and status lamps are points.
@export var strip: bool = false
## How bright it is at its middle, from 0 to 1.
@export var brightness: float = 1.0
