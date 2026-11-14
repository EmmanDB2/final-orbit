# med_bay.gd: what dying costs. The pilot wakes in Kapteyn-3's med bay with a bill: putting them back
# together, more the worse the death was, and getting a ship back: towing theirs home, or a new one
# if theirs is gone. It's paid from their credits, and whatever they can't cover, the agency's repo
# squad settles, so they leave debt free with whatever's left. There's nothing to sell yet, since
# ships aren't bought, so the rest is written off. Dying never wipes the world. In Zen Mode it's all
# free. From DESIGN.md, "Death and the med bay".
class_name MedBay
extends RefCounted


## The bill: its "lines", each [what, credits]; the "total"; what's "paid" from the credits; what's
## "settled" by the repo squad; and what "killed" them, as the comms line said it.
static func bill(prices: ServicePrices, killed: String, severity: float, ship_lost: bool, replacement: ShipDesign, credits: int, free: bool) -> Dictionary:
	var lines: Array = []
	var rebuild: int = prices.med_bay_flat + roundi(clampf(severity, 0.0, 1.0) * prices.med_bay_most / 100.0) * 100
	lines.append(["RECONSTRUCTION", rebuild])
	if ship_lost:
		lines.append(["NEW %s" % replacement.display_name.to_upper(), ship_value(prices, replacement)])
	else:
		lines.append(["TOW TO KAPTEYN-3", prices.tow_price])
	var total: int = 0
	for line: Array in lines:
		if free:
			line[1] = 0
		total += line[1]
	var paid: int = clampi(total, 0, maxi(credits, 0))
	return {"lines": lines, "total": total, "paid": paid, "settled": total - paid, "killed": killed, "free": free}


## What a ship's worth: each of its parts at its price.
static func ship_value(prices: ServicePrices, design: ShipDesign) -> int:
	var body: ShipBody = ShipBody.measure(design)
	var value: int = 0
	for module: ModuleData in body.modules:
		value += prices.module_prices.get(module.kind, prices.other_module_price)
	return value
