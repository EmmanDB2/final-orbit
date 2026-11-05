# star_data.gd: the numbers that describe one star's light.
# From DESIGN.md, "Universe generation" (a star's type sets its light color and
# luminosity) and the star tint idea in the parking lot.
class_name StarData
extends Resource

## The color of the star's light, which tints the space around it.
@export var color: Color = Color.WHITE
## Where the star sits in the world, in pixels.
@export var world_x: float = 0.0
@export var world_y: float = 0.0
## Distance at which the star's light has dropped to half. Bigger means a brighter star.
@export var falloff_distance: float = 4000.0
