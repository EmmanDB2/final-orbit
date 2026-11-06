# test_ship_body.gd: checks mass, center of mass, and spin resistance from pixels.
# From DESIGN.md, "Ships". Run with:
#   godot --headless --path . --script tests/test_ship_body.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_two_pixels()
	_test_lander()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	var ok: bool = absf(actual - expected) <= tolerance
	if not ok:
		_failures += 1
	print("%s %s: got %s, expected %s" % ["PASS" if ok else "FAIL", label, String.num_scientific(actual), String.num_scientific(expected)])


# Two pixels of known materials, four pixels apart, where the answer is known exactly.
func _test_two_pixels() -> void:
	var light := Color8(10, 20, 30)
	var heavy := Color8(200, 100, 50)
	var image := Image.create(5, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, light)
	image.set_pixel(4, 0, heavy)
	var material_a := MaterialData.new()
	material_a.density = 1.0
	material_a.colors = PackedColorArray([light])
	var material_b := MaterialData.new()
	material_b.density = 3.0
	material_b.colors = PackedColorArray([heavy])
	var design := ShipDesign.new()
	design.texture = ImageTexture.create_from_image(image)
	design.materials = [material_a, material_b]
	var body: ShipBody = ShipBody.measure(design)
	_check("mass adds up", body.mass, 4.0, 0.0)
	# Pixels sit at x = -2 and x = +2 from the middle, so the center is at 1.
	_check("center of mass leans to the heavy side", body.center_of_mass.x, 1.0, 1e-4)
	# 1 kg at distance 3 and 3 kg at distance 1 from that center: 9 + 3.
	_check("spin resistance", body.spin_resistance, 12.0, 1e-3)


func _test_lander() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var module_total: float = 0.0
	for cell: Vector2i in body.module_masses:
		module_total += body.module_masses[cell]
	_check("every module has pixels", body.module_masses.size(), design.modules.size(), 0.0)
	_check("modules add up to the whole ship", module_total, body.mass, 1e-6)
	_check("lander's center of mass is near its middle", body.center_of_mass.x, 0.0, 2.0)
	_check("and low, from the heavy engine", 1.0 if body.center_of_mass.y > 0.0 else 0.0, 1.0, 0.0)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var empty: Dictionary = body.with_fuel(0.0)
	_check("the tanks hold their fuel", body.fuel_capacity, 40000.0, 0.0)
	_check("full tanks add their mass", full["mass"], body.mass + 40000.0, 1e-6)
	_check("empty tanks leave the dry mass", empty["mass"], body.mass, 1e-6)
	_check("empty tanks leave the dry spin resistance", empty["spin_resistance"], body.spin_resistance, 1e-2)
	_check("full tanks are harder to spin", 1.0 if full["spin_resistance"] > empty["spin_resistance"] else 0.0, 1.0, 0.0)
	_check("thrust is the tuned feel when full", design.engine_force / full["mass"], 300.0, 1.0)
	_check("turning is the tuned feel when full", design.rcs_torque / full["spin_resistance"], 1.5, 0.01)
