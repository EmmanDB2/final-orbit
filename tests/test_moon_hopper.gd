# test_moon_hopper.gd: checks the Moon Hopper's art, mass, balance, thrust, hatch, and nozzles.
# From DESIGN.md, "Ships". Run with:
#   godot --headless --path . --script tests/test_moon_hopper.gd
extends SceneTree

const DESIGN_PATH: String = "res://data/moon_hopper_design.tres"

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var design: ShipDesign = load(DESIGN_PATH)
	var body: ShipBody = ShipBody.measure(design)
	_test_textures(design)
	_test_numbers(design, body)
	_test_hatch_and_nozzles(design, body)
	await _test_in_the_game(design)
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL %s %s" % [label, detail])


# All 20 pictures load: 6 modules (the cockpit and the rest) times 3 layers, and 2 legs.
func _test_textures(design: ShipDesign) -> void:
	var count: int = 0
	for module: ModuleData in design.modules:
		for texture: Texture2D in [module.texture, module.systems_texture, module.frame_texture]:
			if texture != null:
				count += 1
				_check("texture of %s has size" % module.display_name, texture.get_width() > 0)
	_check("20 textures", count == 20, "got %d" % count)


func _test_numbers(design: ShipDesign, body: ShipBody) -> void:
	_check("dry mass between 10,000 and 18,000 kg", body.mass > 10000.0 and body.mass < 18000.0, "got %f" % body.mass)
	_check("center of mass on x = 0", absf(body.center_of_mass.x) <= 0.5, "got %f" % body.center_of_mass.x)
	var home: BodyData = load("res://data/home_planet.tres")
	var moon: BodyData = load("res://data/moon.tres")
	var empty: Dictionary = body.with_fuel(0.0)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var home_ratio: float = design.engine_force / empty["mass"] / home.surface_gravity
	_check("can't lift off home, empty", home_ratio < 0.9, "got %f" % home_ratio)
	var moon_ratio: float = design.engine_force / (full["mass"] + design.cargo_capacity) / moon.surface_gravity
	_check("lifts off the moon full with 1 t cargo", moon_ratio > 1.25, "got %f" % moon_ratio)


func _test_hatch_and_nozzles(design: ShipDesign, body: ShipBody) -> void:
	_check("hatch pixel is there", body.has_pixel(design.hatch_point + Vector2(0.0, 3.0)))
	_check("cockpit point is on the ship", body.has_pixel(design.cockpit_point))
	for index in range(body.modules.size()):
		var module: ModuleData = body.modules[index]
		if module.kind == "engine":
			var points: PackedVector2Array = body.nozzle_points(index)
			_check("engine has two tail nozzles", points.size() == 2)
			if points.size() == 2:
				_check("tail nozzles mirror about x = 0", is_equal_approx(points[0].x, -points[1].x) and is_equal_approx(points[0].y, points[1].y))
				_check("tail nozzles at (-19, 49) and (19, 49)", points[0].is_equal_approx(Vector2(-19.0, 49.0)) and points[1].is_equal_approx(Vector2(19.0, 49.0)), str(points))
			_check("tail nozzle pixels are there", body.nozzle_share(index) == 1.0)
		elif module.kind == "rcs":
			var point: Vector2 = body.nozzle_point(index)
			var expected_x: float = -68.0 if module.cell.x == 0 else 68.0
			_check("RCS nozzle of %s" % module.display_name, point.is_equal_approx(Vector2(expected_x, -22.0)), str(point))
			_check("RCS nozzle pixels of %s are there" % module.display_name, body.nozzle_share(index) == 1.0)


# The real ship, built from the design in the game: its hatch is there for docking.
func _test_in_the_game(design: ShipDesign) -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ship: Node = main.get_node("Ship")
	ship.change_design(design)
	_check("ship has its hatch", ship.has_hatch())
	_check("design changed to the hopper", ship.design == design)
	main.queue_free()
