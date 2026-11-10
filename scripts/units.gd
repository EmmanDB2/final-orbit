# units.gd: turns world units into real ones for the readouts. The pilot sets the scale: they're
# 1.85 m tall and 37 px, so one world unit, one pixel at the closest zoom, is 5 cm. Physics stays
# in world units, and only what's shown changes.
# From DESIGN.md, "Scale and precision" and "Player" (the pilot sets the scale of everything).
class_name Units

## How tall the pilot is drawn, in world units, with the model's height in meters.
const PILOT_HEIGHT_UNITS: float = 37.0
const METERS_PER_UNIT: float = AstronautModel.HEIGHT / PILOT_HEIGHT_UNITS


static func meters(units: float) -> float:
	return units * METERS_PER_UNIT


## A distance as a number and its unit, apart, for readouts that show the unit on its own line:
## meters up to 10 km, then kilometers, with a decimal while they're short.
static func distance_parts(units: float) -> PackedStringArray:
	var m: float = meters(units)
	if absf(m) < 10000.0:
		return PackedStringArray([grouped(roundi(m)), "M"])
	if absf(m) < 100000.0:
		return PackedStringArray(["%.1f" % (m / 1000.0), "KM"])
	return PackedStringArray([grouped(roundi(m / 1000.0)), "KM"])


## A distance with its unit, such as "1,500 M" or "30.0 KM".
static func distance_text(units: float) -> String:
	var parts: PackedStringArray = distance_parts(units)
	return "%s %s" % [parts[0], parts[1]]


## A speed in meters per second, as a number only: two decimals under 10, so docking speeds read,
## one under 100, and whole above.
static func speed_number(units_per_second: float) -> String:
	var m: float = meters(units_per_second)
	if absf(m) < 10.0:
		return "%.2f" % m
	if absf(m) < 100.0:
		return "%.1f" % m
	return grouped(roundi(m))


## A speed with its unit, such as "250 M/S".
static func speed_text(units_per_second: float) -> String:
	return "%s M/S" % speed_number(units_per_second)


## A mass from a gravitational parameter in world units, in kilograms, since mu scales with length
## cubed.
static func kilograms_from_mu(mu_units: float, gravitational_constant: float) -> float:
	return mu_units * METERS_PER_UNIT * METERS_PER_UNIT * METERS_PER_UNIT / gravitational_constant


## Thousands split with commas.
static func grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var text: String = ""
	while digits.length() > 3:
		text = "," + digits.substr(digits.length() - 3) + text
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + text
