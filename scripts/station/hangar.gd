# hangar.gd: the station's hangar, for now a stand-in for the ship mall to come. It knows which ships
# can be flown, and keeps each one as it was left, its damage and its tanks, while another's flown, so
# trading ships doesn't repair or refuel anything. A ship never flown comes new, whole and full. From
# DESIGN.md, "Ships" (the hangar).
class_name Hangar
extends RefCounted

var ships: Array[ShipDesign] = []
# How each ship was left, by its design's path.
var _kept: Dictionary = {}


func _init(list: ShipList) -> void:
	ships = list.ships


## Whether a ship's been flown and left here, rather than new.
func has_kept(design: ShipDesign) -> bool:
	return _kept.has(design.resource_path)


## Puts the ship being flown away and brings out another, in its place. Cargo stays aboard.
func swap(ship: Node2D, to: ShipDesign) -> void:
	if to == ship.design:
		return
	_kept[ship.design.resource_path] = ship.hangar_state()
	ship.change_design(to)
	if _kept.has(to.resource_path):
		ship.apply_hangar_state(_kept[to.resource_path])
		_kept.erase(to.resource_path)


func save_state() -> Dictionary:
	return {"kept": _kept.duplicate(true)}


func restore_state(saved: Dictionary) -> void:
	_kept = saved.get("kept", {}).duplicate(true)
