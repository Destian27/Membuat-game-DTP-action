extends StaticBody3D
# Pintu rumah yang BISA DIRUSAK (v0.0.3.1).
# Sebelumnya pintu membuka otomatis saat pemain mendekat; sekarang pintu selalu tertutup
# dan harus dihancurkan: ditembak, ditebas/dicakar (pemain & zombie), atau dipukul bot zombie.
# Pintu masuk grup "house_door" supaya player.gd / bot.gd bisa mengenalinya tanpa terikat
# ke fungsi take_damage() milik karakter (agar tidak muncul efek darah di pintu kayu).

const Fx = preload("res://scripts/fx.gd")

const MAX_HP := 450
const SFX_HIT := "res://assets/sfx/hit.wav"
const SFX_BREAK := "res://assets/sfx/g_punch.wav"

var hp := MAX_HP
var broken := false
# Diisi oleh main.gd sebelum add_child().
var leaf_mesh: MeshInstance3D          # daun pintu (diganti material "retak" saat HP < 50%)
var weak_material: Material            # material kayu gelap/retak
var plank_material: Material           # material serpihan kayu saat pintu pecah


func _ready() -> void:
	add_to_group("house_door")


# Dipanggil player.gd (tembakan/tebasan) dan bot.gd (cakaran zombie).
# Mengembalikan true kalau pintu hancur oleh serangan ini.
func damage_door(amount: int, hit_pos: Vector3 = Vector3.ZERO) -> bool:
	if broken:
		return false
	hp -= maxi(amount, 1)
	var fx_pos := hit_pos if hit_pos != Vector3.ZERO else global_position + Vector3(0.0, 1.1, 0.0)
	# Serpihan kayu kecil + suara tiap kali kena.
	Fx.puff(get_parent(), fx_pos, "res://assets/spark.png", 0.32, 0.22, Color(0.80, 0.55, 0.30, 0.95))
	Fx.sfx3d(get_parent(), SFX_HIT, fx_pos, -8.0, randf_range(0.65, 0.8))
	if hp <= 0:
		_break()
		return true
	if float(hp) <= float(MAX_HP) * 0.5 and leaf_mesh != null and weak_material != null:
		leaf_mesh.material_override = weak_material
	return false


func _break() -> void:
	broken = true
	# Collision dimatikan lewat set_deferred: aman walau dipanggil di tengah physics callback.
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", true)
		elif child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var center := global_position + Vector3(0.0, 1.1, 0.0)
	Fx.sfx3d(get_parent(), SFX_BREAK, center, -2.0, 0.75)
	Fx.puff(get_parent(), center, "res://assets/spark.png", 1.6, 0.35, Color(0.85, 0.6, 0.35, 0.9))
	_spawn_planks()


# Serpihan papan jatuh sebentar lalu hilang sendiri (hanya visual, tanpa collision).
func _spawn_planks() -> void:
	var parent := get_parent()
	if parent == null or plank_material == null:
		return
	for i in range(6):
		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.12, 0.2), randf_range(0.45, 0.95), 0.05)
		plank.mesh = bm
		plank.material_override = plank_material
		parent.add_child(plank)
		var start := position + Vector3(randf_range(-0.7, 0.7), randf_range(0.5, 2.0), 0.0)
		plank.position = start
		var end := start + Vector3(randf_range(-0.9, 0.9), 0.0, randf_range(-0.9, 0.9))
		end.y = 0.06 + randf() * 0.03
		var end_rot := Vector3(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6), randf_range(-1.6, 1.6))
		var tw := plank.create_tween()
		tw.tween_property(plank, "position", end, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(plank, "rotation", end_rot, 0.5)
		tw.tween_interval(6.0)
		tw.tween_callback(plank.queue_free)
