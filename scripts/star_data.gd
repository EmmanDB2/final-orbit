# star_data.gd: the numbers that describe a star: a body at the center of the system,
# plus its light.
# From DESIGN.md, "Universe generation" (a star's type sets its light color and
# luminosity) and "Art direction" (star tint).
class_name StarData
extends BodyData

## How hot its surface is, in kelvin.
@export var temperature: float = 5800.0
## The color of the star's light, which tints the space around it.
@export var color: Color = Color.WHITE
## Distance at which the star's light has dropped to half. Bigger means a brighter star.
@export var falloff_distance: float = 4000.0
## Distance at which its heat reaches the top of a hull's scale, past which hulls burn.
@export var heat_distance: float = 6000000.0
