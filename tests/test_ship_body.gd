# test_ship_body.gd: checks mass, center of mass, and spin resistance from pixels.
# From DESIGN.md, "Ships". Run with:
#   godot --headless --path . --script tests/test_ship_body.gd
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_two_pixels()
	_test_lander()
	_test_erasing()
	_test_lander_damage()
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


# A simple bar: a 20 x 4 block of one material, so every answer can be worked out by hand.
func _bar_design(strength: float) -> ShipDesign:
	var color := Color8(10, 20, 30)
	var image := Image.create(20, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var material := MaterialData.new()
	material.density = 2.0
	material.strength = strength
	material.colors = PackedColorArray([color])
	var design := ShipDesign.new()
	design.texture = ImageTexture.create_from_image(image)
	design.materials = [material]
	return design


func _test_erasing() -> void:
	var body: ShipBody = ShipBody.measure(_bar_design(10.0))
	_check("the bar starts whole", body.pixel_count, 80.0, 0.0)
	_check("the bar's width comes from its pixels", body.width, 20.0, 0.0)
	_check("the bar reaches its end", body.reach(Vector2.ZERO, Vector2.RIGHT), 10.0, 0.0)

	# Crushing from the right with enough energy for 8 pixels takes about two columns.
	var erased: Dictionary = body.crush(Vector2.RIGHT, 80.0, 1)
	_check("energy buys pixels", erased["points"].size(), 8.0, 0.0)
	_check("mass drops", body.mass, 144.0, 1e-3)
	_check("center of mass moves away from the hit", 1.0 if body.center_of_mass.x < -0.05 else 0.0, 1.0, 0.0)
	_check("nothing's split off yet", body.split_off().size(), 0.0, 0.0)

	# A cut right through the middle leaves two pieces.
	var cut: ShipBody = ShipBody.measure(_bar_design(10.0))
	for y in range(4):
		for x in range(8, 16):
			var index: int = y * 20 + x
			if cut._density[index] > 0.0:
				cut._erase(index)
	cut._refresh()
	var pieces: Array[Dictionary] = cut.split_off()
	_check("a cut splits off one piece", pieces.size(), 1.0, 0.0)
	_check("the bigger piece stays", cut.pixel_count, 32.0, 0.0)
	_check("the small one leaves", pieces[0]["pixel_count"], 16.0, 0.0)
	_check("its mass goes with it", pieces[0]["mass"], 32.0, 1e-3)
	_check("its picture is its size", pieces[0]["image"].get_width(), 4.0, 0.0)
	_check("and it's in the right place", pieces[0]["center"].x, 8.0, 1e-3)
	_check("the ship's mass drops too", cut.mass, 64.0, 1e-3)

	var dented: ShipBody = ShipBody.measure(_bar_design(10.0))
	var dent_erased: Dictionary = dented.dent(Vector2(-10.0, 0.0), 40.0, 1)
	var farthest_x: float = -10.0
	for point: Vector2 in dent_erased["points"]:
		farthest_x = maxf(farthest_x, point.x)
	_check("a dent stays near the point", 1.0 if farthest_x < 0.0 else 0.0, 1.0, 0.0)
	_check("and leaves the far end alone", 1.0 if dented.has_pixel(Vector2(9.5, 0.5)) else 0.0, 1.0, 0.0)


func _test_lander_damage() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	_check("the whole lander counts as one piece", body.split_off().size(), 0.0, 0.0)
	_check("every module starts whole", body.module_share(0), 1.0, 0.0)
	_check("it rests on its engine bell", body.reach(Vector2.ZERO, Vector2.DOWN), 105.5, 1.0)

	# Crushing the bottom takes the engine first and leaves the cockpit alone.
	body.crush(Vector2.DOWN, 1.0e9, 3)
	var engine_share: float = body.module_share(6)
	var cockpit_share: float = body.module_share(0)
	_check("a crash from below hurts the engine", 1.0 if engine_share < 0.8 else 0.0, 1.0, 0.0)
	_check("and leaves the cockpit whole", cockpit_share, 1.0, 0.0)
	_check("the ship gets shorter", 1.0 if body.reach(Vector2.ZERO, Vector2.DOWN) < 105.0 else 0.0, 1.0, 0.0)
