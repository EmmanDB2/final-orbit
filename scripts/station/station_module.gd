# station_module.gd: one module of a station built from modules: four layers of art on one canvas,
# where its floors are, its named ports, and what's in it. Modules bolt together port to port through
# a standard hatch. From DESIGN.md, "Universe generation" (stations) and "Lighting".
class_name StationModule
extends Resource

@export var display_name: String = ""
## Which earlier module this bolts onto, or -1 for the first, which everything hangs from.
@export var bolts_to_module: int = -1
## The name of that module's port it bolts onto, and of its own port that does the bolting.
@export var bolts_to_port: String = ""
@export var own_port: String = ""
## How big the canvas is, in pixels. Left at zero, it's the floor picture's size.
@export var canvas_size: Vector2i = Vector2i.ZERO
## The four layers, all on the module's canvas: the floor under everyone, the walls, which are solid,
## the overhead pipes and lintels the pilot passes under, and the roof outside.
@export var floor_texture: Texture2D
@export var walls_texture: Texture2D
@export var overhead_texture: Texture2D
@export var roof_texture: Texture2D
## Where someone can stand, as rectangles on the canvas, before the walls and props take their parts out.
@export var floors: Array[Rect2i] = []
@export var ports: Array[StationPort] = []
@export var props: Array[PropPlacement] = []
## The port you walk into the room by, and the long axis of its ceiling strips ("east_west" or
## "north_south"), at right angles to the line you walk in on.
@export var main_port: String = ""
@export_enum("east_west", "north_south") var light_axis: String = ""
## Lights set on the module itself, apart from the ones its props carry.
@export var fixtures: Array[LightFixture] = []
## Window rectangles on the roof layer. They glow warm while the station's powered.
@export var windows: Array[Rect2i] = []
@export var outside_lights: Array[OutsideLight] = []
## Doors inside the module that aren't a joint to another one, such as an airlock's inner door: where
## the leaves meet (the port's point, in canvas pixels), which way the door runs (its face: the way
## someone goes through it), and the name of the airlock port it belongs to. The art is in the layers.
@export var doors: Array[StationPort] = []


## The canvas's size in pixels.
func size() -> Vector2i:
	if canvas_size != Vector2i.ZERO:
		return canvas_size
	return Vector2i(floor_texture.get_size()) if floor_texture != null else Vector2i.ZERO


## The port with this name, or nothing.
func port_named(wanted: String) -> StationPort:
	for port: StationPort in ports:
		if port.port_name == wanted:
			return port
	return null
