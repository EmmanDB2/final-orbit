# ship_numbers.gd: prints a ship design's measured numbers (mass, fuel, center of mass, spin
# resistance, delta-v, thrust over weight), so a new ship's engine and RCS values can be set from
# its art. From DESIGN.md, "Ships". Reads what's on disk. Run with:
#   godot --headless --path . -s tools/ship_numbers.gd -- res://data/lander_design.tres
extends SceneTree

const HOME_PATH: String = "res://data/home_planet.tres"
const MOON_PATH: String = "res://data/moon.tres"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: godot --headless --path . -s tools/ship_numbers.gd -- res://data/<design>.tres")
		quit(1)
		return
	var design: ShipDesign = load(args[0]) as ShipDesign
	if design == null:
		print("couldn't load a ShipDesign from %s" % args[0])
		quit(1)
		return
	var home: BodyData = load(HOME_PATH)
	var moon: BodyData = load(MOON_PATH)
	var body: ShipBody = ShipBody.measure(design)

	var leg_mass: float = 0.0
	for index: int in body.module_masses:
		if body.modules[index].kind == "leg":
			leg_mass += body.module_masses[index]
	var empty: Dictionary = body.with_fuel(0.0)
	var full: Dictionary = body.with_fuel(body.fuel_capacity)
	var cargo: float = design.cargo_capacity
	var full_cargo_mass: float = full["mass"] + cargo

	print("design: %s" % args[0])
	print("dry mass: %.0f kg (body %.0f, legs %.0f)" % [body.mass, body.mass - leg_mass, leg_mass])
	print("fuel capacity: %.0f kg, cargo capacity: %.0f kg" % [body.fuel_capacity, cargo])
	print("center of mass empty: (%.2f, %.2f) px" % [empty["center_of_mass"].x, empty["center_of_mass"].y])
	print("center of mass full:  (%.2f, %.2f) px" % [full["center_of_mass"].x, full["center_of_mass"].y])
	print("spin resistance empty, legs up: %.0f" % empty["spin_resistance"])
	print("spin resistance full, legs up:  %.0f" % full["spin_resistance"])
	if design.exhaust_velocity > 0.0 and empty["mass"] > 0.0:
		print("delta-v: %.0f m/s" % (design.exhaust_velocity * log(full["mass"] / empty["mass"])))
	print("engine force: %.0f N, exhaust velocity: %.0f" % [design.engine_force, design.exhaust_velocity])
	if home != null:
		var accel: float = design.engine_force / empty["mass"]
		print("thrust/weight at home (g %.0f), empty: %.2f" % [home.surface_gravity, accel / home.surface_gravity])
		print("thrust/weight at home, full: %.2f" % (design.engine_force / full["mass"] / home.surface_gravity))
	if moon != null:
		print("thrust/weight at moon (g %.0f), full with %.0f kg cargo: %.2f" % [moon.surface_gravity, cargo, design.engine_force / full_cargo_mass / moon.surface_gravity])
	quit()
