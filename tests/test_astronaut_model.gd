# test_astronaut_model.gd: checks the 3D pilot is put together the way the game expects.
# Run with: godot --headless --path . --script tests/test_astronaut_model.gd
extends SceneTree

const MODEL_SCRIPT: String = "res://scripts/pilot/astronaut_model.gd"

# Each joint and the joint it hangs from.
const JOINT_PARENTS: Dictionary[StringName, StringName] = {
	&"pelvis": &"root",
	&"spine": &"pelvis",
	&"chest": &"spine",
	&"neck": &"chest",
	&"head": &"neck",
	&"backpack": &"chest",
	&"shoulder_l": &"chest",
	&"elbow_l": &"shoulder_l",
	&"wrist_l": &"elbow_l",
	&"shoulder_r": &"chest",
	&"elbow_r": &"shoulder_r",
	&"wrist_r": &"elbow_r",
	&"hip_l": &"pelvis",
	&"knee_l": &"hip_l",
	&"ankle_l": &"knee_l",
	&"hip_r": &"pelvis",
	&"knee_r": &"hip_r",
	&"ankle_r": &"knee_r",
}

# Each marker and the joint it rides on.
const MARKER_PARENTS: Dictionary[StringName, StringName] = {
	&"visor": &"head",
	&"jet_nozzle_l": &"backpack",
	&"jet_nozzle_r": &"backpack",
	&"hand_l": &"wrist_l",
	&"hand_r": &"wrist_r",
	&"sole_l": &"ankle_l",
	&"sole_r": &"ankle_r",
}

var _checks: int = 0
var _failures: int = 0


# Runs on the first frame, not in _initialize, because the root window has to be in the
# tree before a model can be seen entering it.
func _process(_delta: float) -> bool:
	var model: Node3D = _new_model(null)
	_test_joints(model)
	_test_markers(model)
	_test_size(model)
	_test_triangles(model)
	_test_colors()
	_test_same_every_time(model)
	if OS.get_cmdline_user_args().has("--positions"):
		_print_positions(model)
	model.free()
	print("%d checks, %d failed" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
	return true


func _check(label: String, actual: float, expected: float, tolerance: float) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures += 1
		print("FAIL %s: got %s, wanted %s" % [label, actual, expected])


func _check_true(label: String, passed: bool) -> void:
	_checks += 1
	if not passed:
		_failures += 1
		print("FAIL %s" % label)


func _new_model(palette: Resource) -> Node3D:
	var model: Node3D = (load(MODEL_SCRIPT) as GDScript).new()
	model.set("palette", palette)
	# Asking for a joint builds the model, without it ever joining a scene tree.
	model.call("joint", &"root")
	return model


func _test_joints(model: Node3D) -> void:
	var root_joint: Node3D = model.call("joint", &"root")
	_check_true("root exists", root_joint != null)
	_check_true("root hangs from the model", root_joint != null and root_joint.get_parent() == model)
	_check("root is on the ground", _place(root_joint, model).origin.length(), 0.0, 0.0001)
	for joint_name: StringName in JOINT_PARENTS:
		var joint: Node3D = model.call("joint", joint_name)
		_check_true("%s exists" % joint_name, joint != null)
		if joint == null:
			continue
		_check_true("%s is named right" % joint_name, joint.name == joint_name)
		_check_true("%s hangs from %s" % [joint_name, JOINT_PARENTS[joint_name]], joint.get_parent() == model.call("joint", JOINT_PARENTS[joint_name]))
		_check("%s rests unturned" % joint_name, joint.rotation.length(), 0.0, 0.0)
	_check_true("an unknown joint is null", model.call("joint", &"tail") == null)
	# The left side mirrors the right, with the right hand on +X.
	for limb_joint: String in ["shoulder", "elbow", "wrist", "hip", "knee", "ankle"]:
		var left: Vector3 = _place(model.call("joint", StringName(limb_joint + "_l")), model).origin
		var right: Vector3 = _place(model.call("joint", StringName(limb_joint + "_r")), model).origin
		_check_true("%s_r is on +X" % limb_joint, right.x > 0.0)
		_check("%s mirrors" % limb_joint, left.distance_to(Vector3(-right.x, right.y, right.z)), 0.0, 0.0001)
	# The sizes the sprite was measured at.
	_check("hips height", _place(model.call("joint", &"hip_r"), model).origin.y, 0.65, 0.03)
	_check("knee height", _place(model.call("joint", &"knee_r"), model).origin.y, 0.35, 0.03)
	_check("shoulder height", _place(model.call("joint", &"shoulder_r"), model).origin.y, 1.2, 0.05)


func _test_markers(model: Node3D) -> void:
	for marker_name: StringName in MARKER_PARENTS:
		var marker: Marker3D = model.call("marker", marker_name)
		_check_true("%s exists" % marker_name, marker != null)
		if marker == null:
			continue
		_check_true("%s is named right" % marker_name, marker.name == marker_name)
		_check_true("%s rides on %s" % [marker_name, MARKER_PARENTS[marker_name]], marker.get_parent() == model.call("joint", MARKER_PARENTS[marker_name]))
	_check_true("an unknown marker is null", model.call("marker", &"tail") == null)
	for side: String in ["_l", "_r"]:
		var sole: Marker3D = model.call("marker", StringName("sole" + side))
		_check("sole%s is on the ground" % side, _place(sole, model).origin.y, 0.0, 0.0001)
		# -Y has to point out of the nozzle, so nothing of the pack may be below it.
		var nozzle: Marker3D = model.call("marker", StringName("jet_nozzle" + side))
		_check("jet_nozzle%s points down" % side, _place(nozzle, model).basis.y.dot(Vector3.UP), 1.0, 0.0001)
		var pack_bottom: float = _bounds(model.call("joint", &"backpack"), model).position.y
		_check("jet_nozzle%s is at the pack's bottom" % side, _place(nozzle, model).origin.y, pack_bottom, 0.001)
		var hand: Marker3D = model.call("marker", StringName("hand" + side))
		_check("hand%s hangs at about 0.7 m" % side, _place(hand, model).origin.y, 0.7, 0.05)
	# The visor is on the front, which is -Z, and only its highlight is in front of it.
	var visor: Marker3D = model.call("marker", &"visor")
	var glass: AABB = _bounds(model.call("joint", &"head").get_node("visor_glass"), model)
	_check("visor is on the glass", _place(visor, model).origin.z, glass.position.z, 0.005)
	_check("visor is the front of the model", _place(visor, model).origin.z, _bounds(model, model).position.z, 0.02)
	_check("visor height", _place(visor, model).origin.y, 1.5, 0.05)
	_check("visor is centered", _place(visor, model).origin.x, 0.0, 0.0001)


func _test_size(model: Node3D) -> void:
	var all: AABB = _bounds(model, model)
	_check("soles at y = 0", all.position.y, 0.0, 0.0001)
	_check("helmet top at 1.85 m", all.end.y, 1.85, 0.0001)
	_check("left and right match", all.position.x, -all.end.x, 0.0001)
	var helmet: AABB = _bounds(model.call("joint", &"head").get_node("helmet"), model)
	_check("helmet height", helmet.size.y, 0.6, 0.001)
	_check("helmet width", helmet.size.x, 0.62, 0.001)
	var pack: AABB = _bounds(model.call("joint", &"backpack").get_node("pack"), model)
	_check("pack width", pack.size.x, 0.6, 0.001)
	_check("pack depth", pack.size.z, 0.35, 0.001)
	_check("pack bottom", pack.position.y, 0.6, 0.001)
	# The pack's front meets the back of the helmet without going into it.
	_check_true("pack clears the helmet", pack.position.z >= helmet.end.z)
	_check("pack touches the helmet", pack.position.z, helmet.end.z, 0.01)
	var shoulders: AABB = _bounds(model.call("joint", &"shoulder_l").get_node("shoulder_cap"), model).merge(_bounds(model.call("joint", &"shoulder_r").get_node("shoulder_cap"), model))
	_check("width across the shoulders", shoulders.size.x, 0.75, 0.04)
	# The dark boot, without the ankle's ring on top of it.
	var ankle: Node3D = model.call("joint", &"ankle_r")
	var boot: AABB = _bounds(ankle.get_node("boot_sole"), model).merge(_bounds(ankle.get_node("boot_toe"), model)).merge(_bounds(ankle.get_node("boot_shaft"), model))
	_check("boot length", boot.size.z, 0.35, 0.001)
	_check("boot height", boot.size.y, 0.25, 0.05)
	# The glove and cuff hang clear of the hips.
	var glove: AABB = _bounds(model.call("joint", &"wrist_r"), model)
	var hips: AABB = _bounds(model.call("joint", &"pelvis").get_node("pelvis_block"), model)
	_check_true("glove clears the hips", glove.position.x > hips.end.x)
	# The legs stand a little apart, all the way down.
	_check_true("legs don't touch", _bounds(model.call("joint", &"hip_r"), model).position.x > 0.0)


func _test_triangles(model: Node3D) -> void:
	var triangles: int = 0
	for piece: MeshInstance3D in _pieces(model):
		triangles += piece.mesh.get_faces().size() / 3
		# Every patch built by hand has to face outward: away from the helmet's middle.
		if piece.mesh is ArrayMesh:
			var faces: PackedVector3Array = piece.mesh.get_faces()
			var inward: int = 0
			for i: int in range(0, faces.size(), 3):
				var facing: Vector3 = (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i])
				var middle: Vector3 = (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
				# Skirt triangles stand on edge, so only the ones that face out or in count.
				if facing.normalized().dot(middle.normalized()) < -0.3:
					inward += 1
			_check("%s faces outward" % piece.name, inward, 0, 0)
	print("%d triangles" % triangles)
	_check_true("under 2,000 triangles", triangles < 2000)


func _test_colors() -> void:
	# With no palette, the built-in colors. With one, the palette's.
	var plain: Node3D = _new_model(null)
	var palette: Resource = load("res://data/agency_palette.tres")
	var painted: Node3D = _new_model(palette)
	var outline: Color = palette.get("hull_darkest")
	for model: Node3D in [plain, painted]:
		var seen: Dictionary[Color, bool] = {}
		for piece: MeshInstance3D in _pieces(model):
			var material: StandardMaterial3D = piece.get_surface_override_material(0)
			_check_true("%s has a flat material" % piece.name, material != null and material.albedo_texture == null and material.metallic == 0.0 and material.roughness == 1.0 and material.metallic_specular == 0.0)
			if material == null:
				continue
			seen[material.albedo_color] = true
			_check_true("%s isn't the outline's color" % piece.name, not _same_color(material.albedo_color, outline))
			var in_palette: bool = false
			for property: Dictionary in palette.get_property_list():
				if property["type"] == TYPE_COLOR and _same_color(palette.get(property["name"]), material.albedo_color):
					in_palette = true
			_check_true("%s is a palette color" % piece.name, in_palette)
		_check("ten colors in use", seen.size(), 10, 0)
	# Orange is on the left arm and blue on the right.
	_check_true("orange patch on the left", _same_color(_patch_color(painted, &"shoulder_l"), palette.get("agency_orange")))
	_check_true("blue patch on the right", _same_color(_patch_color(painted, &"shoulder_r"), palette.get("agency_blue")))
	plain.free()
	painted.free()


func _test_same_every_time(model: Node3D) -> void:
	var again: Node3D = _new_model(null)
	_check_true("builds the same way twice", _fingerprint(model) == _fingerprint(again))
	again.free()
	# Joining a scene tree builds it too, and only once.
	var joined: Node3D = (load(MODEL_SCRIPT) as GDScript).new()
	root.add_child(joined)
	_check_true("builds on entering the tree", joined.get_child_count() == 1 and _fingerprint(joined) == _fingerprint(model))
	root.remove_child(joined)
	root.add_child(joined)
	_check_true("builds only once", joined.get_child_count() == 1)
	joined.free()


# The same color once both are rounded to 8 bits a channel, as the palette file's are.
func _same_color(a: Color, b: Color) -> bool:
	return a.to_html(false) == b.to_html(false)


func _patch_color(model: Node3D, shoulder: StringName) -> Color:
	var patch: MeshInstance3D = model.call("joint", shoulder).get_node("patch")
	return (patch.get_surface_override_material(0) as StandardMaterial3D).albedo_color


func _pieces(under: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if under is MeshInstance3D:
		found.append(under)
	for child: Node in under.get_children():
		found.append_array(_pieces(child))
	return found


# Where a node sits in the model's space. Worked out by hand, since the model is
# measured without ever joining a scene tree.
func _place(node: Node3D, model: Node3D) -> Transform3D:
	var place := Transform3D.IDENTITY
	var step: Node3D = node
	while step != model:
		place = step.transform * place
		step = step.get_parent()
	return place


# The box around every piece under a node, in the model's space.
func _bounds(under: Node, model: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for piece: MeshInstance3D in _pieces(under):
		var place: Transform3D = _place(piece, model)
		for corner: Vector3 in piece.mesh.get_faces():
			var point: Vector3 = place * corner
			if first:
				box = AABB(point, Vector3.ZERO)
				first = false
			else:
				box = box.expand(point)
	return box


# Lists where every joint and marker rests, to keep the model's header table honest.
func _print_positions(model: Node3D) -> void:
	for joint_name: StringName in JOINT_PARENTS:
		print("%-13s %s" % [joint_name, _place(model.call("joint", joint_name), model).origin.snappedf(0.001)])
	for marker_name: StringName in MARKER_PARENTS:
		print("%-13s %s" % [marker_name, _place(model.call("marker", marker_name), model).origin.snappedf(0.001)])


func _fingerprint(model: Node3D) -> String:
	var lines: PackedStringArray = []
	for piece: MeshInstance3D in _pieces(model):
		lines.append("%s %s %s" % [model.get_path_to(piece), _place(piece, model), piece.mesh.get_faces()])
	return "\n".join(lines).sha256_text()
