# astronaut_model.gd: the pilot as a low-poly 3D astronaut, built in code from simple shapes
# on a joint hierarchy. The game renders it at 1 px per 5 cm, snaps every pixel to the agency
# palette and outlines it, so only the silhouette and the big blocks of color matter.
# From DESIGN.md, "Player" (the 3D pilot being tried against the sprite sheets).
#
# +Y is up, the astronaut faces -Z, and their right hand is on +X. Units are meters.
# In the rest pose every joint's rotation is zero. The pieces are rigid, never skinned:
# each limb ends inside a ball at its joint, so no gap opens when the joint turns.
#
# Joint rest positions, in meters from root:
#
#   joint        parent           x       y       z
#   root         (this node)    0.000   0.00    0.00    ground level, between the boot soles
#   pelvis       root           0.000   0.72    0.00
#   spine        pelvis         0.000   0.82    0.00    the waist hinge
#   chest        spine          0.000   1.02    0.00
#   neck         chest          0.000   1.25   -0.06    the collar ring
#   head         neck           0.000   1.55   -0.08    the middle of the helmet
#   backpack     chest          0.000   1.10    0.41    the middle of the pack
#   shoulder_l   chest         -0.265   1.19    0.03
#   elbow_l      shoulder_l    -0.335   0.97    0.03
#   wrist_l      elbow_l       -0.360   0.79   -0.01
#   shoulder_r   chest          0.265   1.19    0.03
#   elbow_r      shoulder_r     0.335   0.97    0.03
#   wrist_r      elbow_r        0.360   0.79   -0.01
#   hip_l        pelvis        -0.140   0.65    0.00
#   knee_l       hip_l         -0.140   0.35    0.00
#   ankle_l      knee_l        -0.140   0.20    0.00
#   hip_r        pelvis         0.140   0.65    0.00
#   knee_r       hip_r          0.140   0.35    0.00
#   ankle_r      knee_r         0.140   0.20    0.00
#
# Markers, in meters from root (the _l ones are the same with x negated):
#
#   marker         parent        x       y       z
#   visor          head         0.000   1.52   -0.41    the middle of the visor's front
#   jet_nozzle_r   backpack     0.170   0.52    0.41    -Y points out of the nozzle
#   hand_r         wrist_r      0.315   0.70   -0.03    the palm, which faces the leg
#   sole_r         ankle_r      0.140   0.00   -0.045   the middle of the boot's bottom
class_name AstronautModel
extends Node3D

## Boot soles to helmet top, in meters.
const HEIGHT: float = 1.85

const PELVIS := Vector3(0.0, 0.72, 0.0)
const SPINE := Vector3(0.0, 0.82, 0.0)
const CHEST := Vector3(0.0, 1.02, 0.0)
const NECK := Vector3(0.0, 1.25, -0.06)
const HEAD := Vector3(0.0, 1.55, -0.08)
const BACKPACK := Vector3(0.0, 1.10, 0.41)
# The right side. The left side is the same with x negated.
const SHOULDER := Vector3(0.265, 1.19, 0.03)
const ELBOW := Vector3(0.335, 0.97, 0.03)
const WRIST := Vector3(0.36, 0.79, -0.01)
const HIP := Vector3(0.14, 0.65, 0.0)
const KNEE := Vector3(0.14, 0.35, 0.0)
const ANKLE := Vector3(0.14, 0.20, 0.0)

# The helmet is a slightly squashed ball: this far across, and this tall.
const HELMET_RADIUS: float = 0.31
const HELMET_HEIGHT: float = 0.60
# The visor is a rounded rectangle wrapped onto the helmet, a little below its middle.
const VISOR_ELEVATION_DEGREES: float = -5.0
const VISOR_LIFT: float = 0.024
const VISOR_ROUNDING: float = 2.4
const VISOR_SKIRT: float = 0.02

const LIMB_SIDES: int = 8

# Used when no palette is set. Never hull_darkest: that one is the outline's.
const FALLBACK_COLORS: Dictionary[StringName, Color] = {
	&"hull_lightest": Color("e8e4da"),
	&"hull_lighter": Color("a9adb3"),
	&"hull_light": Color("6b7079"),
	&"hull_mid": Color("3d4148"),
	&"hull_dark": Color("23262b"),
	&"gold": Color("d4a23a"),
	&"gold_light": Color("f2d27a"),
	&"gold_dark": Color("9c6b1e"),
	&"agency_orange": Color("d9541e"),
	&"agency_blue": Color("2f5d8c"),
}

## The agency colors. Without one, the suit uses the same colors from a built-in list.
## Changing it later recolors the suit.
@export var palette: AgencyPalette:
	set(value):
		palette = value
		for color_name: StringName in _materials:
			_materials[color_name].albedo_color = _color(color_name)

var _built: bool = false
var _joints: Dictionary[StringName, Node3D] = {}
var _markers: Dictionary[StringName, Marker3D] = {}
var _materials: Dictionary[StringName, StandardMaterial3D] = {}
# Where each joint sits at rest, measured from root. Pieces are placed from these.
var _rest: Dictionary[StringName, Vector3] = {}


func _enter_tree() -> void:
	_build()


## The joint with this name, such as &"elbow_l", or null. Rotate it to pose the astronaut.
func joint(joint_name: StringName) -> Node3D:
	_build()
	return _joints.get(joint_name)


## The attachment point with this name, such as &"visor", or null.
func marker(marker_name: StringName) -> Marker3D:
	_build()
	return _markers.get(marker_name)


func _build() -> void:
	if _built:
		return
	_built = true
	_build_joints()
	_build_torso()
	_build_backpack()
	_build_head()
	_build_arm(-1.0, "_l", &"agency_orange")
	_build_arm(1.0, "_r", &"agency_blue")
	_build_leg(-1.0, "_l")
	_build_leg(1.0, "_r")


func _build_joints() -> void:
	_add_joint(&"root", &"", Vector3.ZERO)
	_add_joint(&"pelvis", &"root", PELVIS)
	_add_joint(&"spine", &"pelvis", SPINE)
	_add_joint(&"chest", &"spine", CHEST)
	_add_joint(&"neck", &"chest", NECK)
	_add_joint(&"head", &"neck", HEAD)
	_add_joint(&"backpack", &"chest", BACKPACK)
	for side: float in [-1.0, 1.0]:
		var tag: String = "_l" if side < 0.0 else "_r"
		_add_joint(StringName("shoulder" + tag), &"chest", _mirror(SHOULDER, side))
		_add_joint(StringName("elbow" + tag), StringName("shoulder" + tag), _mirror(ELBOW, side))
		_add_joint(StringName("wrist" + tag), StringName("elbow" + tag), _mirror(WRIST, side))
		_add_joint(StringName("hip" + tag), &"pelvis", _mirror(HIP, side))
		_add_joint(StringName("knee" + tag), StringName("hip" + tag), _mirror(KNEE, side))
		_add_joint(StringName("ankle" + tag), StringName("knee" + tag), _mirror(ANKLE, side))


# Three blocks stacked up the body. The two hinges are drums lying across it, hidden inside
# the blocks until the waist or chest bends, when they fill the wedge that opens.
func _build_torso() -> void:
	_add_piece(&"pelvis", "pelvis_block", _box(Vector3(0.52, 0.17, 0.42)), &"hull_lightest", Vector3(0.0, 0.735, 0.0))
	var across := Basis(Vector3.BACK, PI * 0.5)
	_add_piece(&"spine", "waist_hinge", _tube(0.17, 0.17, 0.34, LIMB_SIDES, true), &"hull_lighter", SPINE, across)
	_add_piece(&"spine", "abdomen", _box(Vector3(0.36, 0.22, 0.40)), &"hull_lighter", Vector3(0.0, 0.91, 0.0))
	_add_piece(&"chest", "chest_hinge", _tube(0.17, 0.17, 0.34, LIMB_SIDES, true), &"hull_lighter", CHEST, across)
	_add_piece(&"chest", "chest_block", _box(Vector3(0.38, 0.24, 0.46)), &"hull_lightest", Vector3(0.0, 1.11, 0.01))
	_add_piece(&"chest", "control_box", _box(Vector3(0.24, 0.17, 0.08)), &"hull_lighter", Vector3(0.0, 1.09, -0.25))
	_add_piece(&"chest", "control_readout", _box(Vector3(0.14, 0.05, 0.02)), &"hull_light", Vector3(0.0, 1.125, -0.292))


# A tall box from 0.60 to 1.60 m, with its front against the back of the helmet.
func _build_backpack() -> void:
	_add_piece(&"backpack", "pack", _box(Vector3(0.60, 0.94, 0.35)), &"hull_lightest", Vector3(0.0, 1.07, 0.41))
	_add_piece(&"backpack", "pack_top", _box(Vector3(0.52, 0.05, 0.27)), &"hull_lightest", Vector3(0.0, 1.56, 0.41))
	_add_piece(&"backpack", "pack_top_panel", _box(Vector3(0.40, 0.03, 0.17)), &"hull_lighter", Vector3(0.0, 1.585, 0.41))
	# Fills the space between the pack and the small of the back.
	_add_piece(&"backpack", "pack_mount", _box(Vector3(0.44, 0.40, 0.04)), &"hull_lighter", Vector3(0.0, 0.81, 0.22))
	_add_piece(&"backpack", "pack_back_panel", _box(Vector3(0.42, 0.40, 0.04)), &"hull_lighter", Vector3(0.0, 1.27, 0.585))
	_add_piece(&"backpack", "pack_vent", _box(Vector3(0.42, 0.22, 0.04)), &"hull_light", Vector3(0.0, 0.84, 0.585))
	for side: float in [-1.0, 1.0]:
		var tag: String = "_l" if side < 0.0 else "_r"
		_add_piece(&"backpack", "pack_side_panel" + tag, _box(Vector3(0.04, 0.42, 0.19)), &"hull_lighter", Vector3(side * 0.30, 1.25, 0.41))
		_add_piece(&"backpack", "pack_side_vent" + tag, _box(Vector3(0.04, 0.20, 0.19)), &"hull_light", Vector3(side * 0.30, 0.83, 0.41))
		_add_piece(&"backpack", "nozzle" + tag, _tube(0.05, 0.07, 0.10, LIMB_SIDES, true), &"hull_dark", Vector3(side * 0.17, 0.57, 0.41))
		_add_marker(StringName("jet_nozzle" + tag), &"backpack", Vector3(side * 0.17, 0.52, 0.41))


func _build_head() -> void:
	_add_piece(&"neck", "collar", _tube(0.175, 0.175, 0.06, 12, true), &"hull_mid", Vector3(0.0, 1.255, -0.07))
	_add_piece(&"head", "helmet", _ball(HELMET_RADIUS, HELMET_HEIGHT, 12, 5), &"hull_lightest", HEAD)
	var elevation: float = deg_to_rad(VISOR_ELEVATION_DEGREES)
	# The visor wraps round to the sides, so it shows as well from the side as from the
	# front, and stops there, so none of it shows from behind. The rim is only a band:
	# its middle would be hidden under the glass.
	_add_piece(&"head", "visor_rim", _helmet_patch(0.01, elevation, deg_to_rad(93.0), deg_to_rad(42.0), 16, 1, 0.72), &"gold_dark", HEAD)
	_add_piece(&"head", "visor_glass", _helmet_patch(VISOR_LIFT, elevation, deg_to_rad(86.0), deg_to_rad(34.0), 16, 4), &"gold", HEAD)
	_add_piece(&"head", "visor_highlight", _helmet_patch(0.034, deg_to_rad(8.0), deg_to_rad(60.0), deg_to_rad(8.0), 12, 3), &"gold_light", HEAD)
	_add_marker(&"visor", &"head", HEAD + _helmet_point(0.0, elevation, VISOR_LIFT))


# side is -1 for the left arm and 1 for the right.
func _build_arm(side: float, tag: String, patch_color: StringName) -> void:
	var shoulder: Vector3 = _mirror(SHOULDER, side)
	var elbow: Vector3 = _mirror(ELBOW, side)
	var wrist: Vector3 = _mirror(WRIST, side)
	var shoulder_joint := StringName("shoulder" + tag)
	var elbow_joint := StringName("elbow" + tag)
	var wrist_joint := StringName("wrist" + tag)
	var upper: Basis = _limb_basis(shoulder, elbow)
	var fore: Basis = _limb_basis(elbow, wrist)

	# The shoulder's ring is on the chest, round the armhole, so the arm turns inside it
	# and from the side it frames the shoulder.
	_add_piece(&"chest", "shoulder_ring" + tag, _tube(0.135, 0.135, 0.05, 10, true), &"hull_mid", Vector3(side * 0.205, shoulder.y, shoulder.z), Basis(Vector3.BACK, PI * 0.5))
	_add_piece(shoulder_joint, "shoulder_cap", _ball(0.11, 0.22, LIMB_SIDES, 3), &"hull_lightest", shoulder, upper)
	_add_limb(shoulder_joint, "upper_arm", &"hull_lightest", shoulder, elbow, 0.098, 0.096)
	# A plate on the outside of the shoulder, standing just proud of the cap.
	_add_piece(shoulder_joint, "patch", _box(Vector3(0.10, 0.14, 0.15)), patch_color, shoulder + upper.x * (side * 0.075), upper)

	_add_piece(elbow_joint, "elbow_ring", _ball(0.11, 0.22, LIMB_SIDES, 3), &"hull_mid", elbow, fore)
	_add_limb(elbow_joint, "forearm", &"hull_lightest", elbow, wrist, 0.094, 0.086)

	# The cuff is the wrist's ring, and the glove is a flattened ball hanging from it.
	_add_piece(wrist_joint, "cuff", _tube(0.094, 0.094, 0.06, LIMB_SIDES, true), &"hull_mid", wrist, fore)
	var glove_center: Vector3 = wrist - fore.y * 0.09
	_add_piece(wrist_joint, "glove", _ball(0.08, 0.20, LIMB_SIDES, 3), &"hull_mid", glove_center, fore * Basis.from_scale(Vector3(0.72, 1.0, 1.0)))
	_add_marker(StringName("hand" + tag), wrist_joint, glove_center - fore.x * (side * 0.058))


func _build_leg(side: float, tag: String) -> void:
	var hip: Vector3 = _mirror(HIP, side)
	var knee: Vector3 = _mirror(KNEE, side)
	var ankle: Vector3 = _mirror(ANKLE, side)
	var hip_joint := StringName("hip" + tag)
	var knee_joint := StringName("knee" + tag)
	var ankle_joint := StringName("ankle" + tag)

	# Each ring is a ball a little fatter than the limbs that end inside it, so it shows
	# as a dark band about a pixel tall however the joint is turned.
	_add_piece(hip_joint, "hip_ring", _ball(0.139, 0.278, LIMB_SIDES, 3), &"hull_mid", hip)
	_add_limb(hip_joint, "thigh", &"hull_lightest", hip, knee, 0.125, 0.115)
	_add_piece(knee_joint, "knee_ring", _ball(0.128, 0.256, LIMB_SIDES, 3), &"hull_mid", knee)
	_add_limb(knee_joint, "shin", &"hull_lightest", knee, ankle, 0.112, 0.106)

	# The boot: 0.24 m to the top of the ankle ring, 0.35 m heel to toe, on a thick sole.
	_add_piece(ankle_joint, "ankle_ring", _ball(0.12, 0.24, LIMB_SIDES, 3), &"hull_mid", ankle)
	_add_piece(ankle_joint, "boot_shaft", _tube(0.108, 0.112, 0.15, LIMB_SIDES, false), &"hull_dark", Vector3(ankle.x, 0.125, 0.0))
	_add_piece(ankle_joint, "boot_toe", _box(Vector3(0.19, 0.10, 0.20)), &"hull_dark", Vector3(ankle.x, 0.11, -0.115))
	_add_piece(ankle_joint, "boot_sole", _box(Vector3(0.23, 0.07, 0.35)), &"hull_dark", Vector3(ankle.x, 0.035, -0.045))
	_add_marker(StringName("sole" + tag), ankle_joint, Vector3(ankle.x, 0.0, -0.045))


# rest is measured from root, and so is everything else that places a piece or a marker.
# With every rest rotation zero, a joint's own offset is just rest minus its parent's.
func _add_joint(joint_name: StringName, parent_name: StringName, rest: Vector3) -> void:
	var node := Node3D.new()
	node.name = joint_name
	var parent: Node3D = self
	var parent_rest := Vector3.ZERO
	if parent_name != &"":
		parent = _joints[parent_name]
		parent_rest = _rest[parent_name]
	node.position = rest - parent_rest
	parent.add_child(node)
	_joints[joint_name] = node
	_rest[joint_name] = rest


func _add_marker(marker_name: StringName, joint_name: StringName, rest: Vector3) -> void:
	var node := Marker3D.new()
	node.name = marker_name
	node.gizmo_extents = 0.05
	node.position = rest - _rest[joint_name]
	_joints[joint_name].add_child(node)
	_markers[marker_name] = node


func _add_piece(joint_name: StringName, piece_name: String, mesh: Mesh, color_name: StringName, center: Vector3, turned: Basis = Basis.IDENTITY) -> void:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.set_surface_override_material(0, _material(color_name))
	piece.transform = Transform3D(turned, center - _rest[joint_name])
	_joints[joint_name].add_child(piece)


# A tube from one joint to the next. Its open ends sit inside the balls at the joints.
func _add_limb(joint_name: StringName, piece_name: String, color_name: StringName, from: Vector3, to: Vector3, from_radius: float, to_radius: float) -> void:
	var mesh: CylinderMesh = _tube(from_radius, to_radius, from.distance_to(to), LIMB_SIDES, false)
	_add_piece(joint_name, piece_name, mesh, color_name, (from + to) * 0.5, _limb_basis(from, to))


# Turns a shape's +Y to point from one end of a limb back up to the other.
func _limb_basis(from: Vector3, to: Vector3) -> Basis:
	var up: Vector3 = (from - to).normalized()
	var back: Vector3 = Vector3.RIGHT.cross(up).normalized()
	return Basis(up.cross(back), up, back)


func _mirror(point: Vector3, side: float) -> Vector3:
	return Vector3(point.x * side, point.y, point.z)


func _color(color_name: StringName) -> Color:
	if palette != null:
		return palette.get(color_name)
	return FALLBACK_COLORS[color_name]


# One flat, matte material per color, shared by every piece of that color.
func _material(color_name: StringName) -> StandardMaterial3D:
	if _materials.has(color_name):
		return _materials[color_name]
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(color_name)
	material.metallic = 0.0
	material.roughness = 1.0
	material.metallic_specular = 0.0
	_materials[color_name] = material
	return material


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _ball(radius: float, height: float, around: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = around
	mesh.rings = rings
	return mesh


func _tube(top_radius: float, bottom_radius: float, height: float, around: int, capped: bool) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = around
	mesh.rings = 0
	mesh.cap_top = capped
	mesh.cap_bottom = capped
	return mesh


# A point on the helmet, or lift meters above it, measured from the helmet's middle.
# azimuth turns from straight ahead toward the right hand; elevation tilts up.
func _helmet_point(azimuth: float, elevation: float, lift: float) -> Vector3:
	var across: float = (HELMET_RADIUS + lift) * cos(elevation)
	return Vector3(across * sin(azimuth), (HELMET_HEIGHT * 0.5 + lift) * sin(elevation), -across * cos(azimuth))


# Which way the helmet's surface faces at that point.
func _helmet_normal(azimuth: float, elevation: float) -> Vector3:
	var point: Vector3 = _helmet_point(azimuth, elevation, 0.0)
	var across_squared: float = HELMET_RADIUS * HELMET_RADIUS
	var up_squared: float = HELMET_HEIGHT * HELMET_HEIGHT * 0.25
	return Vector3(point.x / across_squared, point.y / up_squared, point.z / across_squared).normalized()


# A rounded rectangle wrapped onto the front of the helmet, lift meters above the shell.
# It's a fan of loops out from its middle, or a band of them from hole (0 to 1) outward.
# The last loop is a skirt that drops into the shell, so no edge is left floating.
func _helmet_patch(lift: float, elevation: float, half_width: float, half_height: float, segments: int, rings: int, hole: float = 0.0) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# Each loop is how far out it reaches (x, 0 to 1) and its lift (y).
	var loops: Array[Vector2] = []
	var has_middle: bool = hole <= 0.0
	for ring: int in range(1 if has_middle else 0, rings + 1):
		loops.append(Vector2(lerpf(hole, 1.0, float(ring) / float(rings)), lift))
	loops.append(Vector2(1.0, -VISOR_SKIRT))
	if has_middle:
		vertices.append(_helmet_point(0.0, elevation, lift))
		normals.append(_helmet_normal(0.0, elevation))
	for loop: Vector2 in loops:
		var reach: float = loop.x
		var ring_lift: float = loop.y
		for segment: int in range(segments):
			var around: float = TAU * float(segment) / float(segments)
			# How far the rounded rectangle's edge is from its middle, in this direction.
			var edge: float = pow(pow(absf(cos(around)), VISOR_ROUNDING) + pow(absf(sin(around)), VISOR_ROUNDING), -1.0 / VISOR_ROUNDING)
			var azimuth: float = reach * edge * cos(around) * half_width
			var tilt: float = elevation + reach * edge * sin(around) * half_height
			vertices.append(_helmet_point(azimuth, tilt, ring_lift))
			normals.append(_helmet_normal(azimuth, tilt))
	# Godot's front faces wind clockwise, and seen from outside the helmet the segments
	# run clockwise, so each triangle below goes middle, this segment, next segment.
	var first: int = 1 if has_middle else 0
	for segment: int in range(segments):
		var next: int = (segment + 1) % segments
		if has_middle:
			_add_triangle(indices, 0, 1 + segment, 1 + next)
		for band: int in range(loops.size() - 1):
			var inner: int = first + band * segments
			var outer: int = inner + segments
			_add_triangle(indices, inner + segment, outer + segment, outer + next)
			_add_triangle(indices, inner + segment, outer + next, inner + next)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_triangle(indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)
