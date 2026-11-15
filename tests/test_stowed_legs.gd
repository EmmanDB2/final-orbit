# test_stowed_legs.gd: checks landing legs that stow inside the hull: stowed, they don't count in the
# ship's outline, standing width, or hits; deployed, the feet are what touches the ground.
# From DESIGN.md, "Ships" (modules, landing legs). Run with:
#   godot --headless --path . -s tests/test_stowed_legs.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_lander()
	_test_deployed()
	_test_exposed_when_the_hull_goes()
	_test_other_ships()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	var ok: bool = absf(actual - expected) <= tolerance
	if not ok:
		_failures += 1
	print("%s %s: got %s, expected %s" % ["PASS" if ok else "FAIL", label, String.num_scientific(actual), String.num_scientific(expected)])


# The same design with its legs taken off.
func _without_legs(design: ShipDesign) -> ShipDesign:
	var bare: ShipDesign = design.duplicate()
	var kept: Array[ModuleData] = []
	for module: ModuleData in design.modules:
		if module.kind != "leg":
			kept.append(module)
	bare.modules = kept
	return bare


func _leg_pixels(body: ShipBody) -> PackedInt32Array:
	var found := PackedInt32Array()
	for index in range(body._density.size()):
		if body.modules[body._module_of[index]].kind == "leg":
			found.append(index)
	return found


func _same_points(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not a[i].is_equal_approx(b[i]):
			return false
	return true


func _test_lander() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var bare: ShipBody = ShipBody.measure(_without_legs(design))
	body.set_parts_out(0.0)
	var legs: PackedInt32Array = _leg_pixels(body)
	_check("the lander has leg pixels", 1.0 if legs.size() > 0 else 0.0, 1.0, 0.0)
	var shielded: int = 0
	for index in legs:
		shielded += body._shielded[index]
	_check("stowed, every leg pixel is behind the hull", shielded, legs.size(), 0.0)
	_check("the outline is the same as with no legs", 1.0 if _same_points(body.outline_now(), bare.outline_now()) else 0.0, 1.0, 0.0)
	_check("the polygons the air pushes on have no legs", body.outline_polygons_now().filter(func(p: PackedVector2Array) -> bool: return p.size() > 0).size(), bare.outline_polygons_now().filter(func(p: PackedVector2Array) -> bool: return p.size() > 0).size(), 0.0)
	_check("the size is the same", body.width, bare.width, 1e-6)
	_check("and the length", body.length, bare.length, 1e-6)
	_check("it rests on the engine bell as before", body.reach(Vector2.ZERO, Vector2.DOWN), bare.reach(Vector2.ZERO, Vector2.DOWN), 1e-6)
	# Standing width is measured from the center of mass, which the legs' weight nudges a little.
	_check("the standing width is the same as with no legs", body.stance_half_width(), bare.stance_half_width(), 0.5)
	_check("and it tips the same", body.rest_angle(), bare.rest_angle(), 0.05)

	# The legs still weigh what they weigh.
	_check("the legs' mass is in", body.mass - bare.mass, 1378.0, 5.0)

	# A hit aimed at a stowed leg's pixel takes the hull pixel in front of it.
	var target: int = legs[legs.size() / 2]
	var point: Vector2 = body.position_of(target)
	_check("a hit there finds a pixel", 1.0 if body.has_pixel(point) else 0.0, 1.0, 0.0)
	var erased: Dictionary = body.dent(point, 3.0e7, 1)
	var hit_hull: int = 0
	var hit_leg: int = 0
	for index: int in erased["pixels"]:
		if body.pixel_layer[index] == 0:
			hit_hull += 1
		else:
			hit_leg += 1
	_check("it damaged the hull", 1.0 if hit_hull > 0 else 0.0, 1.0, 0.0)
	_check("and no leg pixel", hit_leg, 0.0, 0.0)
	_check("the leg pixel's still there", 1.0 if body._density[target] > 0.0 else 0.0, 1.0, 0.0)
	var crushed: ShipBody = ShipBody.measure(design)
	var crush_hit: Dictionary = crushed.crush(Vector2.DOWN, 3.0e7, 2)
	var crush_leg: int = 0
	for index: int in crush_hit["pixels"]:
		if crushed.modules[crushed._module_of[index]].kind == "leg":
			crush_leg += 1
	_check("a crush from below takes no stowed leg either", crush_leg, 0.0, 0.0)


func _test_deployed() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var stowed_mass: float = body.mass
	var stowed_center: Vector2 = body.center_of_mass
	body.set_parts_out(1.0)
	_check("the mass is the same deployed", body.mass, stowed_mass, 1e-6)
	_check("and the center of mass", body.center_of_mass.distance_to(stowed_center), 0.0, 1e-6)

	var lowest: float = -INF
	var widest: float = 0.0
	for index in _leg_pixels(body):
		var at: Vector2 = body.position_of(index)
		if at.y > lowest:
			lowest = at.y
	for index in _leg_pixels(body):
		var at: Vector2 = body.position_of(index)
		if at.y >= lowest - 2.0:
			widest = maxf(widest, absf(at.x - body.center_of_mass.x))
	_check("deployed, the ground is met by the feet", body.reach(Vector2.ZERO, Vector2.DOWN), lowest + 0.5, 1.0)
	_check("and they're below the engine bell", 1.0 if lowest > 105.0 else 0.0, 1.0, 0.0)
	_check("the standing width is the feet apart", body.stance_half_width(), widest + 0.5, 1.5)
	var feet_out: int = 0
	for index in _leg_pixels(body):
		if body._shielded[index] == 0:
			feet_out += 1
	_check("some of each leg is out in the open", 1.0 if feet_out > 100 else 0.0, 1.0, 0.0)

	body.set_parts_out(0.0)
	_check("and stowed again, the mass hasn't moved", body.mass, stowed_mass, 1e-6)
	var shielded: int = 0
	for index in _leg_pixels(body):
		shielded += body._shielded[index]
	_check("and every leg pixel is behind the hull again", shielded, _leg_pixels(body).size(), 0.0)


func _test_exposed_when_the_hull_goes() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var legs: PackedInt32Array = _leg_pixels(body)
	var target: int = legs[legs.size() / 2]
	var cell: int = body._cell_of[target]
	var front: int = body._pixel_at[cell]
	_check("the hull pixel in front owns the place", body.pixel_layer[front], 0.0, 0.0)
	var outline_size: int = body.outline_now().size()
	body._erase(front)
	body._refresh()
	_check("with the hull pixel gone the leg pixel's exposed", body._shielded[target], 0.0, 0.0)
	_check("and it's in the outline", 1.0 if body.outline_now().size() > outline_size else 0.0, 1.0, 0.0)
	_check("and it owns the place, so the ship stays in one piece", body._pixel_at[cell], target, 0.0)
	_check("nothing comes off", body.split_off().size(), 0.0, 0.0)
	var erased: Dictionary = body.dent(body.position_of(target), 3.0e7, 3)
	var took_leg: bool = false
	for index: int in erased["pixels"]:
		if index == target:
			took_leg = true
	_check("and now a hit there takes the leg pixel", 1.0 if took_leg else 0.0, 1.0, 0.0)


func _test_other_ships() -> void:
	var hopper_design: ShipDesign = load("res://data/moon_hopper_design.tres")
	var hopper: ShipBody = ShipBody.measure(hopper_design)
	var shielded: int = 0
	for index in _leg_pixels(hopper):
		shielded += hopper._shielded[index]
	_check("the Moon Hopper's legs are never shielded", shielded, 0.0, 0.0)
	var bare: ShipBody = ShipBody.measure(_without_legs(hopper_design))
	_check("and its stowed outline has its legs in", 1.0 if hopper.outline_now().size() > bare.outline_now().size() else 0.0, 1.0, 0.0)
