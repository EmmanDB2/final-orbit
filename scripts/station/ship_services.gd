# ship_services.gd: a station's refuelling and repairs, as the service terminal offers them: what's wrong
# with the ship and what each fix costs, what its tanks hold and what filling them costs, and doing it
# for credits, as far into the red as the agency's credit line goes. In Zen Mode it's all free. From
# DESIGN.md, "Core loop" (repairs and replacements are your money) and "Prices".
class_name ShipServices
extends RefCounted

var prices: ServicePrices
## Zen Mode: everything's free.
var free: bool = false

var _ship: Node2D
var _agency: Agency
# The ship as it was built, to measure damage against.
var _whole: ShipBody


func _init(ship: Node2D, agency: Agency, service_prices: ServicePrices) -> void:
	_ship = ship
	_agency = agency
	prices = service_prices
	_whole = ShipBody.measure(ship.design)


func credits() -> int:
	return _agency.credits


func ship() -> Node2D:
	return _ship


## Whether this much can be paid, credit line and all.
func can_pay(cost: int) -> bool:
	return free or _agency.credits - cost >= -prices.credit_line


## Each damaged module: its "module" number, its "name", its "state" (DAMAGED or NOT WORKING), how much
## of it is "gone" from 0 to 1, what fixing it "cost"s, and the point on the ship it's "at", from the
## middle of the ship's grid.
func problems() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var body: ShipBody = _ship.body
	for i in range(body.modules.size()):
		var gone: float = 1.0 - body.module_mass_share(i, _whole)
		if gone < 0.002:
			continue
		var module: ModuleData = body.modules[i]
		var price: int = prices.module_prices.get(module.kind, prices.other_module_price)
		var lost_pixels: bool = body.module_share(i) < 1.0
		found.append({
			"module": i,
			"name": module.display_name.to_upper(),
			"state": "NOT WORKING" if body.module_share(i) < _ship.module_dead_share else "DAMAGED",
			"gone": gone,
			"cost": 0 if free else maxi(ceili(price * gone / 10.0) * 10, prices.smallest_repair),
			"at": body.module_hole(i) if lost_pixels else body.module_art_rect(i).get_center(),
		})
	return found


func repair_cost() -> int:
	var total: int = 0
	for problem: Dictionary in problems():
		total += problem["cost"]
	return total


## Fixes everything, if it can be paid for.
func repair() -> bool:
	var cost: int = repair_cost()
	if problems().is_empty() or not can_pay(cost):
		return false
	if not free:
		_agency.spend(cost, prices.credit_line)
	_ship.repair()
	return true


## Each fuel tank: its "name", what it holds now in "kg", the most it can hold now as "room" (less if
## it's holed), what it holds whole as "full", whether it's "holed", and the point it's "at". The RCS
## propellant tank comes last, with "rcs" set, at the first RCS module.
func tanks() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var body: ShipBody = _ship.body
	var fill: float = _ship.fuel / body.fuel_capacity if body.fuel_capacity > 0.0 else 0.0
	for tank: Dictionary in body.tanks:
		found.append({
			"name": body.modules[tank["module"]].display_name.to_upper(),
			"kg": tank["capacity"] * fill,
			"room": tank["capacity"],
			"full": tank["full"],
			"holed": body.module_share(tank["module"]) < 1.0,
			"at": tank["position"],
			"rcs": false,
		})
	for i in range(body.modules.size()):
		if body.modules[i].kind == "rcs":
			found.append({
				"name": "RCS PROPELLANT",
				"kg": _ship.rcs_fuel,
				"room": _ship.design.rcs_capacity,
				"full": _ship.design.rcs_capacity,
				"holed": false,
				"at": body.module_art_rect(i).get_center(),
				"rcs": true,
			})
			break
	return found


func fuel_wanted() -> float:
	return maxf(_ship.body.fuel_capacity - _ship.fuel, 0.0)


func rcs_wanted() -> float:
	return maxf(_ship.design.rcs_capacity - _ship.rcs_fuel, 0.0)


## What filling both tanks costs.
func refuel_cost() -> int:
	if free:
		return 0
	return ceili(fuel_wanted() * prices.fuel_per_kg + rcs_wanted() * prices.rcs_per_kg)


## How much of a full fill can be paid for, from 0 to 1.
func refuel_share() -> float:
	var cost: int = refuel_cost()
	if cost <= 0 or can_pay(cost):
		return 1.0
	return clampf(float(_agency.credits + prices.credit_line) / cost, 0.0, 1.0)


## What the fill that can be paid for costs.
func refuel_paid() -> int:
	return ceili(refuel_cost() * refuel_share())


## Fills the tanks, or as much of them as can be paid for.
func refuel() -> bool:
	var share: float = refuel_share()
	if fuel_wanted() + rcs_wanted() <= 0.01 or share <= 0.0:
		return false
	if not free:
		_agency.spend(refuel_paid(), prices.credit_line)
	_ship.refuel(fuel_wanted() * share, rcs_wanted() * share)
	return true
