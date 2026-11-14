# service_prices.gd: what a station charges to refuel and repair a ship, and how far into the red the
# agency lets a pilot go, as data. From DESIGN.md, "Core loop" (the agency doesn't insure your ship;
# repairs and replacements are your money) and "Prices".
class_name ServicePrices
extends Resource

## Engine fuel and RCS propellant, in credits a kilogram.
@export var fuel_per_kg: float = 0.15
@export var rcs_per_kg: float = 0.5
## What rebuilding a whole module costs, by its kind. A damaged one costs that much for the share of it
## that's gone.
@export var module_prices: Dictionary = {"cockpit": 6000, "engine": 4000, "tank": 2500, "rcs": 1500, "leg": 1000}
## A module of a kind not listed.
@export var other_module_price: int = 1000
## The least a repair costs, so a scratch isn't free.
@export var smallest_repair: int = 50
## How far below zero credits the agency lets a pilot go, so nobody is stranded at a station.
@export var credit_line: int = 5000

@export_group("Med bay")
## What waking up in the med bay costs: a flat part, and up to this much more the worse the death was,
## rounded to a hundred credits.
@export var med_bay_flat: int = 1500
@export var med_bay_most: int = 6000
## What towing a ship home to Kapteyn-3 costs, when its pilot can't fly it back.
@export var tow_price: int = 1500
