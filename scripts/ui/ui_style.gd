# ui_style.gd: draws the UI's 1970s flight hardware: metal plates, chunky buttons, and
# stencil text. From DESIGN.md, "UI" (NASApunk hardware, agency palette only).
class_name UiStyle

const FONT_CHARACTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const PALETTE: AgencyPalette = preload("res://data/agency_palette.tres")
const FONT: Texture2D = preload("res://art/hud_font.png")


static func palette() -> AgencyPalette:
	return PALETTE


## A riveted metal plate.
static func draw_plate(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, PALETTE.hull_darkest)
	var face: Rect2 = rect.grow(-1.0)
	canvas.draw_rect(face, PALETTE.hull_dark)
	canvas.draw_rect(Rect2(face.position, Vector2(face.size.x, 1.0)), PALETTE.hull_mid)
	canvas.draw_rect(Rect2(face.position, Vector2(1.0, face.size.y)), PALETTE.hull_mid)
	for corner: Vector2 in [Vector2(3, 3), Vector2(rect.size.x - 4, 3), Vector2(3, rect.size.y - 4), rect.size - Vector2(4, 4)]:
		canvas.draw_rect(Rect2(rect.position + corner, Vector2.ONE), PALETTE.hull_light)


## A chunky button, raised or pushed in.
static func draw_button(canvas: CanvasItem, rect: Rect2, pressed: bool) -> void:
	canvas.draw_rect(rect, PALETTE.hull_darkest)
	var face: Rect2 = rect.grow(-1.0)
	canvas.draw_rect(face, PALETTE.hull_mid if pressed else PALETTE.hull_light)
	var inner: Rect2 = face.grow(-2.0)
	canvas.draw_rect(inner, PALETTE.hull_dark if pressed else PALETTE.hull_mid)


## Stencil text. pixel_size 2 is the chunky size and 1 is small labels.
static func draw_text(canvas: CanvasItem, text: String, top_left: Vector2, color: Color, pixel_size: int = 2) -> void:
	var size := Vector2(5 * pixel_size, 7 * pixel_size)
	var x: float = top_left.x
	for character: String in text:
		var index: int = FONT_CHARACTERS.find(character)
		if index >= 0:
			canvas.draw_texture_rect_region(FONT, Rect2(Vector2(x, top_left.y), size), Rect2(index * 10, 0, 10, 14), color)
		x += 6 * pixel_size


## A distance for a label, where one world unit is one meter.
static func distance_text(meters: float) -> String:
	if meters < 10000.0:
		return "%d M" % roundi(meters)
	return "%d KM" % roundi(meters / 1000.0)


static func text_width(text: String, pixel_size: int = 2) -> float:
	return text.length() * 6 * pixel_size
