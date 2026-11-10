# site_data.gd: a place built on a world, like a launch base: which world and where on it, the level
# ground under it, its buildings, and its landing pad. From DESIGN.md, "Places on worlds".
class_name SiteData
extends Resource

@export var display_name: String = ""
## The short name on its marker, and what kind of place its card says it is.
@export var callsign: String = ""
@export var chip: String = "OUTPOST"
## Which world it's on, and which column of that world's rim its middle stands on. A column is two
## world units of ground.
@export var world: BodyData
@export var column: int = 0
## How far the level ground reaches each side of the middle, and how far past that it blends back
## into the terrain, in world units.
@export var half_width: float = 700.0
@export var blend: float = 160.0
@export var buildings: Array[SiteBuilding] = []
## The landing pad: how far its middle is from the site's middle, and how wide it is, in world
## units. No width means no pad.
@export var pad_offset: float = 0.0
@export var pad_width: float = 0.0
## What it offers, for its card.
@export var services: PackedStringArray = PackedStringArray()
