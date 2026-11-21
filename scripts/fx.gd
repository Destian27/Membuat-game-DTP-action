extends RefCounted
# Helper efek: suara & partikel gambar (Sprite3D billboard). Semua fungsi static.

static func sfx3d(parent: Node, path: String, pos: Vector3, vol: float = 0.0, pitch: float = 1.0) -> void:
	var s = load(path)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	p.unit_size = 10.0
	p.max_distance = 70.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


static func sfx2d(parent: Node, path: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	var s = load(path)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = pitch
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func puff(parent: Node, pos: Vector3, tex_path: String, size: float, life: float = 0.3, tint: Color = Color.WHITE) -> void:
	var tex = load(tex_path)
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.double_sided = true
	s.pixel_size = size / float(tex.get_width())
	s.modulate = tint
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 1.8, life)
	tw.tween_property(s, "modulate:a", 0.0, life)
	tw.chain().tween_callback(s.queue_free)


static func blood_burst(parent: Node, pos: Vector3, amount: int = 14) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.72
	particles.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 3.0, 4.0))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 35.0
	mat.initial_velocity_min = 1.8
	mat.initial_velocity_max = 4.2
	mat.gravity = Vector3(0.0, -9.0, 0.0)
	mat.scale_min = 0.018
	mat.scale_max = 0.045
	mat.color = Color(0.72, 0.025, 0.025)
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


static func impact_spark(parent: Node, pos: Vector3, tint: Color = Color(1.0, 0.75, 0.25), amount: int = 10) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.32
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3.0, 3.0, 3.0))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 70.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0.0, -4.0, 0.0)
	mat.scale_min = 0.025
	mat.scale_max = 0.075
	mat.color = tint
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	particles.draw_pass_1 = mesh
	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


static func skill_ring(parent: Node, pos: Vector3, tint: Color, radius: float = 0.8) -> void:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	mesh_instance.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	parent.add_child(mesh_instance)
	mesh_instance.global_position = pos
	mesh_instance.rotation.x = deg_to_rad(90.0)
	var tw := mesh_instance.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mesh_instance, "scale", Vector3.ONE * 2.8, 0.55)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(mesh_instance.queue_free)


# ------------------------------------------------------------------ suara khas karakter (v0.0.2.4)
const SFX := "res://assets/sfx/"

# kunci karakter: "z" zombie biasa, "g" zombie gendut, "s" samurai, "h" manusia
const VOICES := {
	"z": {"groan": ["z_groan_0", "z_groan_1", "z_groan_2"], "attack": ["z_attack"], "heavy": ["z_attack"],
		"hurt": ["z_hurt"], "die": ["z_die", "z_die_b"], "impact": ["claw_hit"], "step": [], "jump": ["z_jump"]},
	"n": {"groan": ["n_groan_0", "n_groan_1"], "attack": ["n_attack"], "heavy": ["n_attack"],
		"hurt": ["n_hurt"], "die": ["n_die"], "impact": ["claw_hit"], "step": [], "jump": ["n_jump"]},
	"g": {"groan": ["g_groan_0", "g_groan_1"], "attack": ["g_punch"], "heavy": ["g_punch"],
		"hurt": ["g_hurt"], "die": ["g_die", "g_die_b"], "impact": ["claw_hit"], "step": ["g_step"], "jump": ["g_jump"]},
	"s": {"groan": [], "attack": ["s_swing"], "heavy": ["s_heavy"],
		"hurt": ["s_hurt"], "die": ["s_die"], "impact": ["slash_hit"], "step": [], "jump": ["s_jump"]},
	"h": {"groan": [], "attack": [], "heavy": [], "hurt": ["hurt"], "die": ["die"], "impact": ["tick"], "step": []},
}


static func char_key(role: String, ztype: String) -> String:
	if role == "samurai":
		return "s"
	if role == "zombie":
		if ztype == "suster":
			return "n"
		return "g" if (ztype == "gendut" or ztype == "induk_gendut") else "z"
	return "h"


static func _pick(role: String, ztype: String, kind: String) -> String:
	var lst: Array = VOICES[char_key(role, ztype)].get(kind, [])
	if lst.is_empty():
		return ""
	return SFX + str(lst.pick_random()) + ".wav"


# suara 3D dari posisi karakter (bot / zombie lain)
static func voice3d(parent: Node, role: String, ztype: String, kind: String, pos: Vector3, vol: float = 0.0) -> void:
	var path := _pick(role, ztype, kind)
	if path == "":
		return
	var pitch := randf_range(0.93, 1.07)
	if role == "zombie" and (ztype == "induk" or ztype == "induk_gendut"):
		pitch *= 0.88   # Induk Zombie: suara lebih berat
	sfx3d(parent, path, pos, vol, pitch)


# suara 2D untuk pemain sendiri
static func voice2d(parent: Node, role: String, ztype: String, kind: String, vol: float = 0.0) -> void:
	var path := _pick(role, ztype, kind)
	if path == "":
		return
	var pitch := randf_range(0.95, 1.05)
	if role == "zombie" and (ztype == "induk" or ztype == "induk_gendut"):
		pitch *= 0.88
	sfx2d(parent, path, vol, pitch)
