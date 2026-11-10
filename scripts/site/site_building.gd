# site_building.gd: one building at a place on a world: its art, outside and cut away, and where it
# stands along the ground. From DESIGN.md, "Places on worlds".
class_name SiteBuilding
extends Resource

@export var display_name: String = ""
## The outside, and the inside with the front wall gone, on canvases the same size, standing on
## their bottom edge. Open steelwork, like a tower, has no inside.
@export var texture: Texture2D
@export var interior_texture: Texture2D
## How far the building's middle is from the site's middle along the ground, in world units,
## clockwise positive.
@export var offset: float = 0.0
## How far the art's bottom sits below the ground, in world units, for a pad set flush with it.
@export var sink: float = 0.0
