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
	_test_depth()
	_test_no_floaters()
	_test_engine_exit()
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
	var module := ModuleData.new()
	module.texture = ImageTexture.create_from_image(image)
	var design := ShipDesign.new()
	design.cell_size = 5
	design.modules = [module]
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
	for module: int in body.module_masses:
		module_total += body.module_masses[module]
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
	var module := ModuleData.new()
	module.texture = ImageTexture.create_from_image(image)
	var design := ShipDesign.new()
	design.cell_size = 20
	design.modules = [module]
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
	for index in range(cut._density.size()):
		var x: float = cut.position_of(index).x
		if x >= -2.0 and x < 6.0:
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
	var dent_erased: Dictionary = dented.dent(Vector2(-10.0, -8.0), 40.0, 1)
	var farthest_x: float = -10.0
	for point: Vector2 in dent_erased["points"]:
		farthest_x = maxf(farthest_x, point.x)
	_check("a dent stays near the point", 1.0 if farthest_x < 0.0 else 0.0, 1.0, 0.0)
	_check("and leaves the far end alone", 1.0 if dented.has_pixel(Vector2(9.5, -8.5)) else 0.0, 1.0, 0.0)


func _test_lander_damage() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	_check("the whole lander counts as one piece", body.split_off().size(), 0.0, 0.0)
	_check("every module starts whole", body.module_share(0), 1.0, 0.0)
	_check("it rests on its engine bell", body.reach(Vector2.ZERO, Vector2.DOWN), 105.0, 1.0)

	# Crushing the bottom takes the engine first and leaves the cockpit alone.
	body.crush(Vector2.DOWN, 1.0e9, 3)
	var engine_share: float = body.module_share(6)
	var cockpit_share: float = body.module_share(0)
	_check("a crash from below hurts the engine", 1.0 if engine_share < 0.8 else 0.0, 1.0, 0.0)
	_check("and leaves the cockpit whole", cockpit_share, 1.0, 0.0)
	_check("the ship gets shorter", 1.0 if body.reach(Vector2.ZERO, Vector2.DOWN) < 105.0 else 0.0, 1.0, 0.0)
	_test_real_parts()


# A module's job depends on its working pixels, not on how much of the cell is left.
func _test_real_parts() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var rcs_left: int = 2
	_check("the layers add up to the lander's mass", body.mass, 19485.0, 40.0)
	_check("and every pixel's there", body.pixel_count, 14337.0, 0.0)
	_check("the RCS nozzle starts working", body.nozzle_share(rcs_left), 1.0, 0.0)
	_check("and its module", body.working_share(rcs_left), 1.0, 0.0)

	# Take most of the module's hull and leave the nozzle.
	for index in range(body._density.size()):
		if body._module_of[index] == rcs_left and body._is_nozzle[index] == 0 and body.position_of(index).x > -30.0:
			body._erase(index)
	body._refresh()
	_check("hull can go with the nozzle untouched", 1.0 if body.module_share(rcs_left) < 0.8 and body.nozzle_share(rcs_left) == 1.0 else 0.0, 1.0, 0.0)
	_check("and the RCS still works", body.working_share(rcs_left), 1.0, 0.0)

	# Now take only the nozzle from a whole ship.
	var other: ShipBody = ShipBody.measure(design)
	for index in range(other._density.size()):
		if other._module_of[index] == rcs_left and other._is_nozzle[index] == 1:
			other._erase(index)
	other._refresh()
	_check("the nozzle gone means the RCS is gone", other.working_share(rcs_left), 0.0, 0.0)
	_check("with nearly all the module left", 1.0 if other.module_share(rcs_left) > 0.95 else 0.0, 1.0, 0.0)

	# Puts the pieces back together and compares them with the original drawing.
	var whole: ShipBody = ShipBody.measure(design)
	var art: Image = (load("res://art/ship_lander.png") as Texture2D).get_image()
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	var differences: int = 0
	var drawn: int = 0
	for y in range(art.get_height()):
		for x in range(art.get_width()):
			var from_art: Color = art.get_pixel(x, y)
			if from_art.a < 0.5:
				continue
			drawn += 1
			var grid_at := Vector2i(x, y) + Vector2i(8, 22)
			var found: bool = false
			for layer in whole._layers:
				var on_art: Vector2i = grid_at - layer.top_left
				if on_art.x >= 0 and on_art.y >= 0 and on_art.x < layer.image.get_width() and on_art.y < layer.image.get_height():
					var here: Color = layer.image.get_pixel(on_art.x, on_art.y)
					if here.a > 0.5 and here.is_equal_approx(from_art):
						found = true
			if not found:
				differences += 1
	_check("the pieces match the drawing exactly", differences, 0.0, 0.0)
	_check("and nothing's extra", whole.pixel_count, drawn, 0.0)


# Damage goes down through the layers: skin, then systems, then frame.
func _test_depth() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var whole_mass: float = body.mass
	var whole_count: int = body.pixel_count
	var tank: int = 4
	var tank_start: float = body.module_share(tank)

	# A pixel of the tank with all three layers.
	var pixel: int = -1
	for index in range(body._density.size()):
		if body._module_of[index] == tank and body._depth_color[index * 3 + 1].a > 0.5 and body._depth_color[index * 3 + 2].a > 0.5:
			pixel = index
			break
	_check("the tank has pixels with all three layers", 1.0 if pixel >= 0 else 0.0, 1.0, 0.0)

	body._peel(pixel)
	_check("taking the skin leaves the pixel there", body.pixel_count, whole_count, 0.0)
	_check("still solid", 1.0 if body.has_pixel(body.position_of(pixel)) else 0.0, 1.0, 0.0)
	_check("showing what's under it", 1.0 if body._color[pixel] == body._depth_color[pixel * 3 + 1] else 0.0, 1.0, 0.0)
	_check("the art shows it too", 1.0 if body.layer_image(0).get_pixel(body.pixel_x[pixel], body.pixel_y[pixel]) == body._depth_color[pixel * 3 + 1] else 0.0, 1.0, 0.0)
	_check("the mass drops by the skin", whole_mass - body.mass, body._depth_mass[pixel * 3], 1e-3)
	_check("and the tank's not holed", body.module_share(tank), tank_start, 0.0)

	body._peel(pixel)
	_check("the systems go next", body.pixel_count, whole_count, 0.0)
	body._peel(pixel)
	_check("and the frame finishes it", body.pixel_count, whole_count - 1, 0.0)
	_check("now it's gone", 1.0 if body.has_pixel(body.position_of(pixel)) else 0.0, 0.0, 0.0)
	_check("and the tank has a hole", 1.0 if body.module_share(tank) < tank_start else 0.0, 1.0, 0.0)

	# Everything together is the whole ship, down to nothing.
	var all: ShipBody = ShipBody.measure(design)
	for index in range(all._density.size()):
		all._erase(index)
	all._refresh()
	_check("erasing everything leaves nothing", all.pixel_count, 0.0, 0.0)
	_check("and no mass", all.mass, 0.0, 0.05)

	# A hit strips the skin farther than it breaks through.
	var hit: ShipBody = ShipBody.measure(design)
	var erased: Dictionary = hit.dent(Vector2(-50.0, 40.0), 2.0e8, 1)
	var stripped: int = 0
	var gone: int = 0
	for index in range(hit._density.size()):
		if hit._depth[index] >= 3:
			gone += 1
		elif hit._depth[index] > 0:
			stripped += 1
	_check("a hit opens up more than it destroys", 1.0 if stripped > gone else 0.0, 1.0, 0.0)
	_check("and says what's under each pixel", erased["reveals"].size(), erased["pixels"].size(), 0.0)
	print("a 200 MJ hit: %d pixels stripped, %d gone" % [stripped, gone])


# A pixel with nothing touching it can't stay on the ship.
func _test_no_floaters() -> void:
	# One pixel cut off in the middle of the bar, right next to the rest.
	var bar: ShipBody = ShipBody.measure(_bar_design(10.0))
	_check("the bar starts in one piece", bar.split_off().size(), 0.0, 0.0)
	var lone := Vector2(-0.5, -8.5)
	for index in range(bar._density.size()):
		var at: Vector2 = bar.position_of(index)
		if at != lone and absf(at.x - lone.x) <= 1.0 and absf(at.y - lone.y) <= 1.0:
			bar._erase(index)
	bar._refresh()
	var whole_count: int = bar.pixel_count
	var pieces: Array[Dictionary] = bar.split_off()
	var lone_found: bool = false
	for piece: Dictionary in pieces:
		if piece["pixel_count"] == 1 and piece["points"][0] == lone:
			lone_found = true
	_check("a pixel with nothing around it drops off", 1.0 if lone_found else 0.0, 1.0, 0.0)
	_check("and it's gone from the ship", 1.0 if bar.has_pixel(lone) else 0.0, 0.0, 0.0)
	_check("nothing else leaves with it", bar.pixel_count, whole_count - 1.0, 0.0)
	_check("and a second look finds nothing new", bar.split_off().size(), 0.0, 0.0)

	# Touching at a corner still counts as attached.
	var corner: ShipBody = ShipBody.measure(_bar_design(10.0))
	for index in range(corner._density.size()):
		var at: Vector2 = corner.position_of(index)
		if at != Vector2(-0.5, -8.5) and at.x >= -1.5 and at.x <= 0.5 and at.y >= -9.5 and at.y <= -7.5 and at != Vector2(0.5, -7.5):
			corner._erase(index)
	corner._refresh()
	_check("a corner still holds", corner.split_off().size(), 0.0, 0.0)

	# The whole lander, with its drawn gaps, is one piece, and the gaps are welded.
	var design: ShipDesign = load("res://data/lander_design.tres")
	var lander: ShipBody = ShipBody.measure(design)
	_check("the lander starts in one piece", lander.split_off().size(), 0.0, 0.0)
	_check("with welds across the art's gaps", 1.0 if lander._welds.size() > 0 else 0.0, 1.0, 0.0)

	# Weld partners gone: the RCS nozzle, drawn with a gap, comes off.
	var rcs_left: int = 2
	lander._count_pieces(false)
	var nozzle_pixel: int = -1
	for index in range(lander._density.size()):
		if lander._is_nozzle[index] == 1 and lander._module_of[index] == rcs_left:
			nozzle_pixel = index
			break
	var nozzle_piece: int = lander._piece_of(nozzle_pixel)
	var nozzle_cells := {}
	for i in range(0, lander._welds.size(), 2):
		var a: int = lander._welds[i]
		var b: int = lander._welds[i + 1]
		if lander._piece_of(a) == nozzle_piece and lander._piece_of(b) != nozzle_piece:
			nozzle_cells[b] = true
		if lander._piece_of(b) == nozzle_piece and lander._piece_of(a) != nozzle_piece:
			nozzle_cells[a] = true
	_check("the nozzle is welded on", 1.0 if nozzle_cells.size() > 0 else 0.0, 1.0, 0.0)
	var before_nozzle: float = lander.nozzle_share(rcs_left)
	for partner: int in nozzle_cells:
		lander._erase(partner)
	lander._refresh()
	var parts: Array[Dictionary] = lander.split_off()
	_check("lose what it's welded to and the nozzle drops", 1.0 if parts.size() >= 1 and lander.nozzle_share(rcs_left) < before_nozzle else 0.0, 1.0, 0.0)

	# After a beating, no pixel is left floating.
	var beaten: ShipBody = ShipBody.measure(design)
	var spots: Array[Vector2] = [Vector2(-50.0, 30.0), Vector2(40.0, -60.0), Vector2(-20.0, 10.0), Vector2(35.0, 45.0), Vector2(-40.0, -30.0), Vector2(5.0, 70.0), Vector2(0.0, -20.0)]
	var dropped: int = 0
	var worst_usec: int = 0
	for i in range(spots.size()):
		beaten.dent(spots[i], 2.5e8, i)
		var started: int = Time.get_ticks_usec()
		for piece: Dictionary in beaten.split_off():
			dropped += piece["pixel_count"]
		worst_usec = maxi(worst_usec, Time.get_ticks_usec() - started)
	var floating: int = 0
	var welded := {}
	for i in range(0, beaten._welds.size(), 2):
		if beaten._density[beaten._welds[i]] > 0.0 and beaten._density[beaten._welds[i + 1]] > 0.0:
			welded[beaten._welds[i]] = true
			welded[beaten._welds[i + 1]] = true
	for index in range(beaten._density.size()):
		if beaten._density[index] <= 0.0 or welded.has(index):
			continue
		var cell: int = beaten._cell_of[index]
		var cx: int = cell % beaten._canvas.x
		var cy: int = cell / beaten._canvas.x
		var touching: bool = false
		for ny in range(cy - 1, cy + 2):
			for nx in range(cx - 1, cx + 2):
				if (nx != cx or ny != cy) and nx >= 0 and ny >= 0 and nx < beaten._canvas.x and ny < beaten._canvas.y:
					var other: int = beaten._pixel_at[ny * beaten._canvas.x + nx]
					if other >= 0 and beaten._density[other] > 0.0:
						touching = true
		if not touching:
			floating += 1
	_check("after a beating nothing's left floating", floating, 0.0, 0.0)
	_check("and the ship is one piece", beaten._count_pieces(true), 1.0, 0.0)
	var started_empty: int = Time.get_ticks_usec()
	beaten._needs_split_check = true
	beaten.split_off()
	print("a beating dropped %d loose pixels, slowest check %d us, a check with nothing loose %d us" % [dropped, worst_usec, Time.get_ticks_usec() - started_empty])


func _test_engine_exit() -> void:
	var design: ShipDesign = load("res://data/lander_design.tres")
	var body: ShipBody = ShipBody.measure(design)
	var whole: Dictionary = body.engine_exit(0.25)
	_check("the flame starts near the ship's middle", whole["middle"].x, 0.0, 4.0)
	_check("at the bottom of the bell", 1.0 if whole["middle"].y > 90.0 else 0.0, 1.0, 0.0)
	_check("as wide as a bell", 1.0 if whole["half_width"] > 5.0 else 0.0, 1.0, 0.0)

	# Shave the bottom off the bell, and the flame moves up to what's left.
	var shaved: ShipBody = ShipBody.measure(design)
	for index in range(shaved._density.size()):
		if shaved._is_working[index] == 1 and shaved._home[index].y > whole["middle"].y - 6.0:
			var kind: String = design.modules[shaved._module_of[index]].kind
			if kind == "engine":
				shaved._density[index] = 0.0
	var shorter: Dictionary = shaved.engine_exit(0.25)
	_check("a crushed bell moves it up", shorter["middle"].y, whole["middle"].y - 6.0, 1.0)

	# Take out one engine module, and the flame goes off to the other side.
	var engines: Array[int] = []
	for i in range(design.modules.size()):
		if design.modules[i].kind == "engine":
			engines.append(i)
	_check("the lander has two engine modules", engines.size(), 2.0, 0.0)
	var one: ShipBody = ShipBody.measure(design)
	for index in range(one._density.size()):
		if one._module_of[index] == engines[0]:
			one._density[index] = 0.0
	var off_side: Dictionary = one.engine_exit(0.25)
	_check("losing one engine narrows it", 1.0 if off_side["half_width"] < whole["half_width"] else 0.0, 1.0, 0.0)
	_check("and moves it aside", 1.0 if absf(off_side["middle"].x - whole["middle"].x) > 2.0 else 0.0, 1.0, 0.0)

	# With no engines left, there's no flame.
	for index in range(one._density.size()):
		if one._module_of[index] == engines[1]:
			one._density[index] = 0.0
	_check("no engines, no flame", one.engine_exit(0.25).size(), 0.0, 0.0)
