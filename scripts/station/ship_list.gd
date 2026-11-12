# ship_list.gd: the ships a pilot can fly from the station's hangar, as data. For now every one is free
# to take; the station's ship mall, where they're bought, comes later. From DESIGN.md, "Ships" (the
# hangar).
class_name ShipList
extends Resource

@export var ships: Array[ShipDesign] = []
