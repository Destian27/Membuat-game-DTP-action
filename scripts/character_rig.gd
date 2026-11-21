extends Node3D

const ANIMATION_CULL_DISTANCE_SQ := 1600.0

var skeleton: Skeleton3D
var root: Node3D
var parts: Dictionary = {}
var role := "human"
var ztype := ""
var character_type := "civil"
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
var locomotion_direction := Vector2.ZERO
var locomotion_strength := 0.0
var locomotion_speed := 0.0
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_playback: AnimationNodeStateMachinePlayback
var active_locomotion_state := ""
var gait_phase := 0.0
var animation_culled := false


func setup(p_role: String, p_ztype: String, p_team: String, p_scale: float = 1.0,
		p_character_type: String = "civil") -> void:
	role = p_role
	ztype = p_ztype
	team = p_team
	scale_factor = p_scale
	character_type = p_character_type
	skeleton = Skeleton3D.new()
	skeleton.name = "CrisisActionSkeleton"
	add_child(skeleton)
	_create_bones()
	_create_model()
	_setup_locomotion_animation()
	apply_role(role, ztype, character_type)


func _create_pose_animation(direction: Vector2) -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	var direction_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(direction_track, NodePath(".:locomotion_direction"))
	animation.track_insert_key(direction_track, 0.0, direction)
	animation.track_insert_key(direction_track, 1.0, direction)
	return animation


func _setup_locomotion_animation() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	library.add_animation("idle", _create_pose_animation(Vector2.ZERO))

	var directions := {
		"forward": Vector2(0.0, 1.0),
		"backward": Vector2(0.0, -1.0),
		"left": Vector2(-1.0, 0.0),
		"right": Vector2(1.0, 0.0),
		"forward_left": Vector2(-0.707107, 0.707107),
		"forward_right": Vector2(0.707107, 0.707107),
		"backward_left": Vector2(-0.707107, -0.707107),
		"backward_right": Vector2(0.707107, -0.707107),
	}
	var walk_blend := AnimationNodeBlendSpace2D.new()
	var run_blend := AnimationNodeBlendSpace2D.new()
	walk_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	run_blend.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	for direction_name in directions:
		var direction: Vector2 = directions[direction_name]
		for mode in ["walk", "run"]:
			var animation_name := "%s_%s" % [mode, direction_name]
			library.add_animation(animation_name, _create_pose_animation(direction))
			var animation_node := AnimationNodeAnimation.new()
			animation_node.animation = "locomotion/" + animation_name
			var blend := walk_blend if mode == "walk" else run_blend
			blend.add_blend_point(animation_node, direction)

	var state_machine := AnimationNodeStateMachine.new()
	var idle_node := AnimationNodeAnimation.new()
	idle_node.animation = "locomotion/idle"
	state_machine.add_node("Idle", idle_node)
	state_machine.add_node("Walk", walk_blend)
	state_machine.add_node("Run", run_blend)
	animation_player.add_animation_library("locomotion", library)
	add_child(animation_player)
	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	animation_tree.tree_root = state_machine
	animation_tree.anim_player = NodePath("../AnimationPlayer")
	add_child(animation_tree)
	animation_tree.active = true
	state_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if state_playback != null:
		state_playback.start("Idle")
	active_locomotion_state = "Idle"


func _set_locomotion(direction: Vector2, strength: float, speed: float) -> void:
	locomotion_direction = direction.limit_length(1.0)
	locomotion_strength = clampf(strength, 0.0, 1.0)
	locomotion_speed = maxf(speed, 0.0)
	var next_state := "Idle"
	if moving and locomotion_strength > 0.01:
		next_state = "Run" if running else "Walk"
	if next_state != active_locomotion_state:
		active_locomotion_state = next_state
		if state_playback != null:
			state_playback.start(next_state)
	if animation_tree == null:
		return
	if next_state == "Walk":
		animation_tree.set("parameters/Walk/blend_position", locomotion_direction)
	elif next_state == "Run":
		animation_tree.set("parameters/Run/blend_position", locomotion_direction)


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


func apply_role(p_role: String, p_ztype: String, p_character_type: String = "civil") -> void:
	role = p_role
	ztype = p_ztype
	character_type = p_character_type
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
		p_shield: bool, p_running: bool, p_invisible: bool, p_dead: bool, p_floor: bool,
		p_direction: Vector2 = Vector2.ZERO, p_speed_ratio: float = 0.0,
		p_actual_speed: float = 0.0) -> void:
	moving = p_moving
	shooting = p_shooting
	attacking = p_attacking
	hurt = p_hurt
	shield = p_shield
	running = p_running
	invisible = p_invisible
	dead = p_dead
	on_floor = p_floor
	_set_locomotion(p_direction, p_speed_ratio, p_actual_speed)


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
	var gendut := role == "zombie" and (ztype == "gendut" or ztype == "induk_gendut")
	var classic_zombie := role == "zombie" and (ztype == "biasa" or ztype == "kurus" or ztype == "classic")
	var nurse_zombie := role == "zombie" and ztype == "suster"
	var agile_human := role == "human" and character_type == "hero"
	var gait_length := 2.2 if running else 1.35
	if agile_human:
		gait_length *= 1.1
	if gendut:
		gait_length *= 1.35
	elif classic_zombie:
		gait_length *= 1.15
	gait_phase += TAU * locomotion_speed / gait_length * delta
	var phase := gait_phase
	var stride := sin(phase) * locomotion_strength
	var forward_amount := locomotion_direction.y
	var side_amount := locomotion_direction.x
	var bob := absf(sin(phase)) * 0.035 * locomotion_strength if moving else sin(anim_time * 2.0) * 0.012
	if gendut:
		stride *= 0.48
	elif classic_zombie:
		stride *= 0.68
	elif nurse_zombie:
		stride *= 0.82
	var gait_amplitude := stride * 0.48

	var root_y := bob
	if dead:
		fall = minf(fall + delta * 1.8, 1.55)
		root_y = maxf(0.18 - fall * 0.12, 0.04)
	if not on_floor:
		root_y += 0.18

	var s := scale_factor
	position.y = root_y
	rotation.z = lerpf(rotation.z, fall if dead else sin(anim_time * 1.7) * (0.04 if gendut else 0.015), minf(1.0, delta * 8.0))

	var hip := Vector3(side_amount * sin(phase) * 0.025 * s * locomotion_strength, 0.82 * s, 0.0)
	var torso := Vector3(side_amount * -0.035 * s * locomotion_strength, 1.18 * s, forward_amount * 0.025 * s * locomotion_strength)
	var head := Vector3(0.0, 1.62 * s, 0.0)
	if classic_zombie:
		torso.y -= 0.035 * s
	elif gendut:
		torso.y -= 0.025 * s
	if skeleton != null:
		skeleton.set_bone_pose_position(skeleton.find_bone("hips"), hip)
		skeleton.set_bone_pose_position(skeleton.find_bone("spine"), torso)
		skeleton.set_bone_pose_position(skeleton.find_bone("head"), head)
	var left_shoulder := Vector3(-0.38 * s, 1.34 * s, 0.0)
	var right_shoulder := Vector3(0.38 * s, 1.34 * s, 0.0)

	parts["hips"].position = hip
	parts["torso"].position = torso
	parts["head"].position = head

	var arm_swing := stride * 0.8
	if agile_human:
		arm_swing *= 1.12
	if attacking or shooting:
		arm_swing = -0.95
	var arm_stride := Vector3(side_amount * stride * 0.13, 0.0, forward_amount * stride * 0.18)
	if classic_zombie:
		arm_swing *= 0.4
	var left_elbow := left_shoulder + Vector3(-0.10 * s, -0.38 * s, sin(arm_swing) * 0.14) - arm_stride * s
	var right_elbow := right_shoulder + Vector3(0.10 * s, -0.38 * s, sin(-arm_swing) * 0.14) + arm_stride * s
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
	var left_step := gait_amplitude * Vector3(side_amount, 0.0, -forward_amount)
	var right_step := -left_step
	var left_lift := maxf(sin(phase), 0.0) * 0.12 * locomotion_strength
	var right_lift := maxf(sin(phase + PI), 0.0) * 0.12 * locomotion_strength
	var left_knee := left_hip + left_step * s + Vector3(0.0, -0.42 * s + left_lift * s, 0.0)
	var right_knee := right_hip + right_step * s + Vector3(0.0, -0.42 * s + right_lift * s, 0.0)
	var left_foot := left_knee + left_step * 0.55 * s + Vector3(0.0, -0.44 * s + left_lift * 0.45 * s, 0.0)
	var right_foot := right_knee + right_step * 0.55 * s + Vector3(0.0, -0.44 * s + right_lift * 0.45 * s, 0.0)
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
	var camera := get_viewport().get_camera_3d()
	if camera != null and global_position.distance_squared_to(camera.global_position) > ANIMATION_CULL_DISTANCE_SQ:
		if not animation_culled and animation_tree != null:
			animation_tree.active = false
			animation_culled = true
		return
	if animation_culled and animation_tree != null:
		animation_tree.active = true
		animation_culled = false
	_update_pose(delta)
