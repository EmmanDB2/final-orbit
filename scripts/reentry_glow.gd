# reentry_glow.gd: draws hot gas around the ship as the air heats it, a bow shock in front
# and streaks trailing behind.
# From DESIGN.md, "Hazards" (atmospheres: drag and re-entry heat). Purely cosmetic for now:
# ship.gd says how hot it is, and this node's "up" points the way the ship is moving through
# the air. Heat damage comes with the damage ticket.
class_name ReentryGlow
extends Node2D

## Below this heat there's nothing to see, where 1.0 is the top of the scale.
const FIRST_SHOWS: float = 0.03
## Heat where the gas starts burning white at the front.
const WHITE_HOT: float = 0.5
## Radius of the bow shock, in art pixels, and the least it can be on screen.
const SHOCK_RADIUS: float = 130.0
const SMALLEST_SHOCK: float = 6.0
## How far around the front the shock reaches on each side, in radians.
const SHOCK_SWEEP: float = 1.4
## Longest the streaks get at full heat, in art pixels, and on screen when zoomed far out.
const TRAIL_LENGTH: float = 420.0
const SMALLEST_TRAIL: float = 40.0
const TRAIL_LANES: int = 25
const FRAMES_PER_SECOND: float = 30.0

var _heat: float = 0.0
var _art_scale: float = 1.0
var _time: float = 0.0
var _frame: int = 0


## Says how hot the ship is, and how big the art is on screen.
func set_heat(heat: float, art_scale: float) -> void:
	var was_showing: bool = _heat >= FIRST_SHOWS
	_heat = heat
	_art_scale = art_scale
	if was_showing and _heat < FIRST_SHOWS:
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var frame: int = int(_time * FRAMES_PER_SECOND)
	if frame != _frame and _heat >= FIRST_SHOWS:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if _heat < FIRST_SHOWS:
		return
	var strength: float = minf(_heat, 1.0)
	var palette: AgencyPalette = UiStyle.palette()
	var hot: Color = palette.thrust_white if _heat >= WHITE_HOT else palette.thrust_yellow
	var pixel: float = maxf(2.0 * _art_scale, 1.0)
	var radius: float = maxf(SHOCK_RADIUS * _art_scale, SMALLEST_SHOCK)
	_draw_shock(radius, pixel, strength, [hot, palette.thrust_yellow, palette.thrust_red])
	_draw_trail(radius, pixel, strength, [hot, palette.thrust_yellow, palette.thrust_red])


# A speckled arc around the front, thickest at the middle.
func _draw_shock(radius: float, pixel: float, strength: float, colors: Array) -> void:
	var angle: float = -SHOCK_SWEEP
	while angle <= SHOCK_SWEEP:
		var middle: float = 1.0 - absf(angle) / SHOCK_SWEEP
		for layer in range(colors.size() * 2):
			var chance: float = (0.35 + 0.65 * strength) * (middle + 0.3) * (1.0 - layer * 0.12)
			if RcsPuffs.speckle(angle * 40.0, float(layer), _frame) < chance:
				var distance: float = radius + layer * pixel
				var spot := Vector2(sin(angle), -cos(angle)) * distance
				draw_rect(Rect2(spot.round(), Vector2.ONE * pixel), colors[layer / 2])
		angle += pixel / radius


# Streaks flowing back past the ship from its middle, longest in the middle, cooling as
# they go. The sprite draws over the start of them.
func _draw_trail(radius: float, pixel: float, strength: float, colors: Array) -> void:
	var longest: float = maxf(TRAIL_LENGTH * _art_scale, SMALLEST_TRAIL) * strength
	for lane in range(TRAIL_LANES):
		var across: float = float(lane) / (TRAIL_LANES - 1) * 2.0 - 1.0
		var x: float = across * radius
		var flicker: float = RcsPuffs.speckle(float(lane), 3.0, _frame)
		var reach: float = longest * (1.0 - across * across * 0.8) * (0.55 + 0.45 * flicker)
		var along: float = 0.0
		while along < reach:
			var share: float = along / reach
			if RcsPuffs.speckle(float(lane), along, _frame) > share * 0.8:
				var spot := Vector2(x, along)
				draw_rect(Rect2(spot.round(), Vector2(pixel, pixel * 2.0)), colors[mini(int(share * colors.size()), colors.size() - 1)])
			along += pixel * 2.0
