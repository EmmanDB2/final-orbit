# ui_style.gd: how the flight UI draws: thin outlined boxes floating over space, stencil text, and
# cyan for whatever's on. From DESIGN.md, "UI" (agency palette only).
class_name UiStyle

const FONT_CHARACTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz:+-.,()/%?'!×Δ°⁰¹²³⁴⁵⁶⁷⁸⁹"
## Raised digits are thinner than the rest, so these advance less.
const NARROW_CHARACTERS: String = "⁰¹²³⁴⁵⁶⁷⁸⁹"
const PALETTE: AgencyPalette = preload("res://data/agency_palette.tres")
const FONT: Texture2D = preload("res://art/hud_font.png")


static func palette() -> AgencyPalette:
	return PALETTE


## The dark behind a box, thin enough to let a little of space show through.
static func box_fill() -> Color:
	var fill: Color = PALETTE.hull_darkest
	fill.a = 0.82
	return fill


## A box with stepped corners, all on whole pixels.
static func draw_box(canvas: CanvasItem, rect: Rect2, line: Color, fill: Color = Color(0.0, 0.0, 0.0, 0.0), thickness: int = 1) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	if fill.a > 0.0:
		canvas.draw_rect(Rect2(r.position.x + 3.0, r.position.y, r.size.x - 6.0, r.size.y), fill)
		canvas.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 3.0, r.size.x - 2.0, r.size.y - 6.0), fill)
		canvas.draw_rect(Rect2(r.position.x, r.position.y + 3.0, 1.0, r.size.y - 6.0), fill)
		canvas.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 3.0, 1.0, r.size.y - 6.0), fill)
		for corner_x: float in [r.position.x + 1.0, r.end.x - 3.0]:
			canvas.draw_rect(Rect2(corner_x, r.position.y + 1.0, 2.0, 2.0), fill)
			canvas.draw_rect(Rect2(corner_x, r.end.y - 3.0, 2.0, 2.0), fill)
	for i in range(thickness):
		var at: Rect2 = r.grow(-float(i))
		canvas.draw_rect(Rect2(at.position.x + 3.0, at.position.y, at.size.x - 6.0, 1.0), line)
		canvas.draw_rect(Rect2(at.position.x + 3.0, at.end.y - 1.0, at.size.x - 6.0, 1.0), line)
		canvas.draw_rect(Rect2(at.position.x, at.position.y + 3.0, 1.0, at.size.y - 6.0), line)
		canvas.draw_rect(Rect2(at.end.x - 1.0, at.position.y + 3.0, 1.0, at.size.y - 6.0), line)
		for step: Vector2 in [Vector2(1.0, 2.0), Vector2(2.0, 1.0)]:
			canvas.draw_rect(Rect2(at.position + step, Vector2.ONE), line)
			canvas.draw_rect(Rect2(at.end.x - 1.0 - step.x, at.position.y + step.y, 1.0, 1.0), line)
			canvas.draw_rect(Rect2(at.position.x + step.x, at.end.y - 1.0 - step.y, 1.0, 1.0), line)
			canvas.draw_rect(Rect2(at.end.x - 1.0 - step.x, at.end.y - 1.0 - step.y, 1.0, 1.0), line)


## Stencil text. pixel_size 2 is the chunky size and 1 is small labels. Slanted leans it over.
static func draw_text(canvas: CanvasItem, text: String, top_left: Vector2, color: Color, pixel_size: int = 2, slanted: bool = false) -> void:
	var x: float = top_left.x
	for character: String in text:
		var index: int = FONT_CHARACTERS.find(character)
		if index >= 0:
			if slanted:
				# One row at a time, each shifted over a little more toward the top.
				for row in range(7):
					var lean: float = floorf((6 - row) / 3.0) * pixel_size
					var place := Rect2(x + lean, top_left.y + row * pixel_size, 5.0 * pixel_size, float(pixel_size))
					canvas.draw_texture_rect_region(FONT, place, Rect2(index * 10, row * 2, 10, 2), color)
			else:
				var size := Vector2(5 * pixel_size, 7 * pixel_size)
				canvas.draw_texture_rect_region(FONT, Rect2(Vector2(x, top_left.y), size), Rect2(index * 10, 0, 10, 14), color)
		x += (4 if NARROW_CHARACTERS.contains(character) else 6) * pixel_size


static func text_width(text: String, pixel_size: int = 2) -> float:
	var width: int = 0
	for character: String in text:
		width += 4 if NARROW_CHARACTERS.contains(character) else 6
	return width * pixel_size
