extends Node3D

var skeleton: Skeleton3D
var root: Node3D
var parts: Dictionary = {}
var role := "human"
var ztype := ""
var team := "blue"
var anim_time := 0.0
var moving := false
var shooting := false
var attacking := false
var on_floor := true
var hurt := false
var shield := false
var running := false
var invisible := false
var dead := false
var fall := 0.0
var scale_factor := 1.0


func setup(p_role: String, p_ztype: String, p_team: String, p_scale: float = 1.0) -> void:
	role = p_role
	ztype = p_ztype
	team = p_team
	scale_factor = p_scale
	skeleton = Skeleton3D.new()
	skeleton.name = "CrisisActionSkeleton"
	add_child(skeleton)
	_create_bones()
	_create_model()
	apply_role(role, ztype)


func _create_bones() -> void:
	var names := [
		"root", "hips", "spine", "head",
		"upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r",
		"upper_leg_l", "lower_leg_l", "upper_leg_r", "lower_leg_r",
	]
	var parents := [-1, 0, 1, 2, 2, 4, 2, 6, 1, 8, 1, 10]
	for i in names.size():
		skeleton.add_bone(names[i])
		skeleton.set_bone_parent(i, parents[i])
		skeleton.set_bone_rest(i, Transform3D())


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.7) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _box(name: String, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	skeleton.add_child(mesh_instance)
	parts[name] = mesh_instance
	return mesh_instance


func _sphere(name: String, radius: float, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	skeleton.add_child(mesh_instance)
	parts[name] = mesh_instance
	return mesh_instance


func _capsule(name: String, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	skeleton.add_child(mesh_instance)
	parts[name] = mesh_instance
	return mesh_instance


func _create_model() -> void:
	_box("hips", Vector3(0.48, 0.22, 0.28), _material(Color(0.12, 0.14, 0.18)))
	_capsule("torso", 0.34, 0.72, _material(Color(0.65, 0.12, 0.11)))
	_sphere("head", 0.22, _material(Color(0.72, 0.50, 0.34)))
	_capsule("upper_arm_l", 0.09, 0.42, _material(Color(0.65, 0.12, 0.11)))
	_capsule("forearm_l", 0.075, 0.38, _material(Color(0.72, 0.50, 0.34)))
	_capsule("upper_arm_r", 0.09, 0.42, _material(Color(0.65, 0.12, 0.11)))
	_capsule("forearm_r", 0.075, 0.38, _material(Color(0.72, 0.50, 0.34)))
	_capsule("upper_leg_l", 0.13, 0.52, _material(Color(0.12, 0.14, 0.18)))
	_capsule("lower_leg_l", 0.11, 0.50, _material(Color(0.12, 0.14, 0.18)))
	_capsule("upper_leg_r", 0.13, 0.52, _material(Color(0.12, 0.14, 0.18)))
	_capsule("lower_leg_r", 0.11, 0.50, _material(Color(0.12, 0.14, 0.18)))


func apply_role(p_role: String, p_ztype: String) -> void:
	role = p_role
	ztype = p_ztype
	var body_color := Color(0.65, 0.12, 0.11)
	var skin_color := Color(0.72, 0.50, 0.34)
	var zombie_green := Color(0.28, 0.48, 0.18)
	if role == "zombie":
		body_color = zombie_green
		skin_color = zombie_green
		if ztype == "gendut" or ztype == "induk_gendut":
			scale_factor = 1.22
		elif ztype == "suster":
			body_color = Color(0.62, 0.70, 0.72)
			skin_color = zombie_green
	elif role == "samurai":
		body_color = Color(0.10, 0.10, 0.13)
		skin_color = Color(0.72, 0.50, 0.34)
	elif team == "blue":
		body_color = Color(0.12, 0.32, 0.72)

	var materials := {
		"torso": body_color,
		"upper_arm_l": body_color,
		"upper_arm_r": body_color,
		"head": skin_color,
		"forearm_l": skin_color,
		"forearm_r": skin_color,
	}
	for part_name in materials:
		var mat := _material(materials[part_name])
		parts[part_name].material_override = mat
	invisible = false


func set_motion(p_moving: bool, p_shooting: bool, p_attacking: bool, p_hurt: bool,
		p_shield: bool, p_running: bool, p_invisible: bool, p_dead: bool, p_floor: bool) -> void:
	moving = p_moving
	shooting = p_shooting
	attacking = p_attacking
	hurt = p_hurt
	shield = p_shield
	running = p_running
	invisible = p_invisible
	dead = p_dead
	on_floor = p_floor


func _orient_segment(mesh_instance: Node3D, start: Vector3, end: Vector3) -> void:
	var direction := end - start
	var distance := direction.length()
	if distance <= 0.001:
		return
	if mesh_instance.mesh is CapsuleMesh:
		mesh_instance.mesh.height = distance
	mesh_instance.position = (start + end) * 0.5
	var q := Quaternion(Vector3.UP, direction.normalized())
	mesh_instance.basis = Basis(q)


func _update_pose(delta: float) -> void:
	anim_time += delta
	var speed := 8.0 if moving else 2.0
	if running:
		speed *= 1.7
	var phase := anim_time * speed
	var stride := sin(phase) * 0.62 if moving else 0.0
	var bob := absf(sin(phase)) * 0.035 if moving else sin(anim_time * 2.0) * 0.012
	var gendut := role == "zombie" and (ztype == "gendut" or ztype == "induk_gendut")
	if gendut:
		stride *= 0.55

	var root_y := bob
	if dead:
		fall = minf(fall + delta * 1.8, 1.55)
		root_y = maxf(0.18 - fall * 0.12, 0.04)
	if not on_floor:
		root_y += 0.18

	var s := scale_factor
	position.y = root_y
	rotation.z = lerpf(rotation.z, fall if dead else sin(anim_time * 1.7) * (0.04 if gendut else 0.015), minf(1.0, delta * 8.0))

	var hip := Vector3(0.0, 0.82 * s, 0.0)
	var torso := Vector3(0.0, 1.18 * s, 0.0)
	var head := Vector3(0.0, 1.62 * s, 0.0)
	if skeleton != null:
		skeleton.set_bone_pose_position(skeleton.find_bone("hips"), hip)
		skeleton.set_bone_pose_position(skeleton.find_bone("spine"), torso)
		skeleton.set_bone_pose_position(skeleton.find_bone("head"), head)
	var left_shoulder := Vector3(-0.38 * s, 1.34 * s, 0.0)
	var right_shoulder := Vector3(0.38 * s, 1.34 * s, 0.0)

	parts["hips"].position = hip
	parts["torso"].position = torso
	parts["head"].position = head

	var arm_swing := stride * 0.75
	if attacking or shooting:
		arm_swing = -0.95
	var left_elbow := left_shoulder + Vector3(-0.10 * s, -0.38 * s, sin(arm_swing) * 0.14)
	var right_elbow := right_shoulder + Vector3(0.10 * s, -0.38 * s, sin(-arm_swing) * 0.14)
	var left_hand := left_elbow + Vector3(0.0, -0.34 * s, cos(arm_swing) * 0.12)
	var right_hand := right_elbow + Vector3(0.0, -0.34 * s, cos(-arm_swing) * 0.12)
	if role == "samurai" and attacking:
		right_hand = right_elbow + Vector3(0.35 * s, -0.12 * s, -0.48 * s)

	_orient_segment(parts["upper_arm_l"], left_shoulder, left_elbow)
	_orient_segment(parts["forearm_l"], left_elbow, left_hand)
	_orient_segment(parts["upper_arm_r"], right_shoulder, right_elbow)
	_orient_segment(parts["forearm_r"], right_elbow, right_hand)

	var left_hip := Vector3(-0.19 * s, 0.70 * s, 0.0)
	var right_hip := Vector3(0.19 * s, 0.70 * s, 0.0)
	var left_knee := left_hip + Vector3(sin(stride) * 0.18, -0.42 * s, cos(stride) * 0.08)
	var right_knee := right_hip + Vector3(sin(-stride) * 0.18, -0.42 * s, cos(-stride) * 0.08)
	var left_foot := left_knee + Vector3(sin(stride) * 0.12, -0.44 * s, cos(stride) * 0.06)
	var right_foot := right_knee + Vector3(sin(-stride) * 0.12, -0.44 * s, cos(-stride) * 0.06)
	_orient_segment(parts["upper_leg_l"], left_hip, left_knee)
	_orient_segment(parts["lower_leg_l"], left_knee, left_foot)
	_orient_segment(parts["upper_leg_r"], right_hip, right_knee)
	_orient_segment(parts["lower_leg_r"], right_knee, right_foot)

	var tint := Color.WHITE
	if hurt:
		tint = Color(1.0, 0.35, 0.35)
	elif shield:
		tint = Color(0.55, 0.82, 1.35)
	elif running:
		tint = Color(1.25, 0.75, 0.70)
	elif invisible:
		tint = Color(0.70, 1.0, 0.75, 0.28)
	for part_name in parts:
		var mat := parts[part_name].material_override as BaseMaterial3D
		if mat != null:
			if part_name == "torso" or part_name.begins_with("upper_arm") or part_name.begins_with("forearm"):
				mat.albedo_color = mat.albedo_color.lerp(tint, 0.0 if tint == Color.WHITE else 0.18)
			mat.albedo_color.a = tint.a


func _process(delta: float) -> void:
	_update_pose(delta)
