extends CharacterBody3D
# Bot tim merah / biru: sprite gambar beranimasi (idle/jalan/tembak/mati), patroli,
# mencari musuh terdekat (pemain atau bot tim lawan), mengejar, menembak.

const Fx = preload("res://scripts/fx.gd")

signal died(bot, headshot: bool, by_player: bool)
signal converted(bot, by_player: bool)   # mode Zombie: manusia berubah jadi zombie

const SPEED := 3.6
const GRAVITY := 18.0
const SIGHT := 40.0
const HEIGHT := 1.9
const SCAN_EVERY := 0.3

# ---- mode Zombie (samakan dengan player.gd) ----
const ZOMBIE_HP := {"induk": 2300, "induk_gendut": 3400, "biasa": 850, "gendut": 1250, "suster": 1000}   # induk = zombie pertama; lainnya bukan induk
const SAMURAI_HP := 5200
const ZOMBIE_LEVEL_HP := 120      # tiap menginfeksi: LV +1, HP maks +120
const ZOMBIE_LEVEL_MAX := 9
const HERO_HP := 130
const HERO_ARMOR := 100
const ARMOR_HIT := 50
const ZOMBIE_DMG := 300
const SAMURAI_FAST := 250
const SAMURAI_HEAVY := 800
const SKILL_CD := 40.0
const RUN_TIME := 7.0
const RUN_MULT := 1.7
const SHIELD_TIME := 9.0
const SHIELD_REDUCE := 0.95
const MIST_TIME := 8.0
const JUMP_V := 5.6
const REACH := 2.0
const DOOR_DMG := 120   # damage cakaran zombie/samurai ke pintu rumah (HP pintu 450 -> ~4 cakaran)

var team := "blue"          # diset main.gd sebelum add_child
var waypoints: Array = []
var map_limit := 24.0
var skill := 1.0
var door_hit_t := 0.0     # jeda antar cakaran ke pintu
var vault_t := 0.0        # jeda antar lompatan melewati ambang rendah
var hp := 100
var max_hp := 100
var dead := false

var zmode := false          # diset main.gd (mode Zombie)
var role := "human"         # "human" / "zombie" / "samurai"
var ztype := ""             # "induk" / "biasa" / "gendut"
var skin := ""              # folder gambar karakter: "red" / "blue"
var htype := "civil"        # mode Zombie, manusia: "hero" / "civil"
var hskin := "civil"        # folder gambar manusia: hero / civil / civil2 / civil3 (diset main.gd)
var zlevel := 0             # level zombie
var armor := 0              # armor hero (menahan infeksi)
var uname := ""             # nama pemain (untuk pesan 'darah pertama')
var dmg_mult := 1.0         # pengali damage tembakan bot manusia ke zombie
var hh := HEIGHT            # tinggi sprite (zombie gendut / induk lebih besar)
var skill_cd := 0.0
var run_t := 0.0
var shield_t := 0.0
var invis_t := 0.0          # kabut virus zombie suster: tak terlihat oleh musuh
var skill_anim := 0.0       # animasi pose skill
var jump_req := false
var was_air := false
var atk_timer := 0.0
var heavy_cd := 0.0
var wander_t := 0.0
var wander_dir := Vector3.ZERO

var sprite: Sprite3D
var bar_bg: Sprite3D
var bar_fg: Sprite3D
var frames := {}
var anim_t := 0.0
var shoot_flash := 0.0
var hurt_flash := 0.0
var wp := Vector3.ZERO
var has_wp := false
var wp_timer := 0.0
var steer_dir := Vector3.ZERO
var steer_timer := 0.0
var strafe := 1.0
var strafe_timer := 0.0
var react := 0.0
var burst_left := 3
var fire_timer := 1.0
var seen_before := false
var check_timer := 0.0
var last_pos := Vector3.ZERO
var moving := false
var base_tint := Color.WHITE

var groan_t := 3.0          # jeda sampai erangan khas zombie berikutnya
var step_t := 0.0           # langkah berat zombie gendut
var hurt_snd_t := 0.0       # throttle suara kena
var lunge_t := 0.0          # animasi menerjang saat menyerang
var lunge_len := 0.3

var target = null           # musuh yang sedang dibidik (pemain / bot lawan)
var sees := false
var scan_timer := 0.0


func _ready() -> void:
	if skin == "":
		skin = team
	add_to_group("bots")
	add_to_group("team_" + team)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

	frames = {
		"idle": _load_frames("idle", 2),
		"walk": _load_frames("walk", 4),
		"shoot": _load_frames("shoot", 2),
		"die": _load_frames("die", 4),
		"jump": _load_frames("jump", 2),
		"skill": _load_frames("skill", 2),
	}
	base_tint = Color.from_hsv(0.0, 0.0, randf_range(0.88, 1.0))

	sprite = Sprite3D.new()
	var idle: Array = frames["idle"]
	if not idle.is_empty():
		sprite.texture = idle[0]
		sprite.pixel_size = HEIGHT / float(sprite.texture.get_height())
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = false
	sprite.double_sided = true
	sprite.position.y = HEIGHT / 2.0
	add_child(sprite)

	# bayangan di tanah
	var shadow_tex = load("res://assets/shadow.png")
	if shadow_tex != null:
		var sh := Sprite3D.new()
		sh.texture = shadow_tex
		sh.axis = Vector3.AXIS_Y
		sh.pixel_size = 1.3 / float(shadow_tex.get_width())
		sh.shaded = false
		sh.position.y = 0.03
		add_child(sh)

	# lambang tim di atas kepala
	var emb = null if zmode else load("res://assets/team_%s.png" % team)
	if emb != null:
		var mk := Sprite3D.new()
		mk.texture = emb
		mk.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mk.shaded = false
		mk.pixel_size = 0.4 / float(emb.get_width())
		mk.position.y = HEIGHT + 0.62
		add_child(mk)

	# bar darah kecil di atas kepala
	var img := Image.create(40, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(img)
	bar_bg = Sprite3D.new()
	bar_bg.texture = white
	bar_bg.pixel_size = 0.02
	bar_bg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar_bg.shaded = false
	bar_bg.modulate = Color(0, 0, 0, 0.7)
	bar_bg.position.y = HEIGHT + 0.25
	bar_bg.visible = false
	add_child(bar_bg)
	bar_fg = Sprite3D.new()
	bar_fg.texture = white
	bar_fg.pixel_size = 0.02
	bar_fg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar_fg.shaded = false
	bar_fg.centered = false
	bar_fg.offset = Vector2(-20, -2)
	bar_fg.modulate = Color(0.3, 1.0, 0.3)
	bar_fg.position.y = HEIGHT + 0.25
	bar_fg.set("render_priority", 1)
	bar_fg.visible = false
	add_child(bar_fg)

	last_pos = global_position
	strafe = 1.0 if randf() < 0.5 else -1.0
	scan_timer = randf() * SCAN_EVERY
	if zmode:
		set_role(role, ztype)


func _melee_role() -> bool:
	return role == "zombie" or role == "samurai"


func cur_speed() -> float:
	var m := 1.0
	if role == "zombie":
		m = 1.1
	elif role == "samurai":
		m = 1.2
	if run_t > 0.0:
		m *= RUN_MULT
	return SPEED * m


# ganti peran (mode Zombie): tampilan, HP, grup tim
func set_role(r: String, zt: String = "") -> void:
	var changed := (r != role) and is_inside_tree()
	if r != "zombie" or role != "zombie":
		zlevel = 0
	role = r
	ztype = zt
	remove_from_group("team_" + team)
	team = "zombie" if r == "zombie" else "human"
	add_to_group("team_" + team)
	var scl := 1.0
	match r:
		"zombie":
			max_hp = int(ZOMBIE_HP.get(zt, 850)) + zlevel * ZOMBIE_LEVEL_HP
			skin = "zombie"
			base_tint = Color.WHITE
			if zt == "gendut" or zt == "induk_gendut":
				skin = "gendut"
				scl = 1.15
			if zt == "suster":
				skin = "suster"
			if zt == "induk" or zt == "induk_gendut":
				scl = 1.2
				base_tint = Color(1.0, 0.78, 0.78)   # induk sedikit kemerahan dan lebih besar
		"samurai":
			max_hp = SAMURAI_HP
			skin = "samurai"
			base_tint = Color.WHITE
		_:
			max_hp = HERO_HP if htype == "hero" else 100
			skin = hskin
			base_tint = Color.from_hsv(0.0, 0.0, randf_range(0.92, 1.0))
	hp = max_hp
	armor = HERO_ARMOR if (r == "human" and htype == "hero") else 0
	frames = {
		"idle": _load_frames("idle", 2),
		"walk": _load_frames("walk", 4),
		"shoot": _load_frames("shoot", 2),
		"die": _load_frames("die", 4),
		"jump": _load_frames("jump", 2),
		"skill": _load_frames("skill", 2),
	}
	hh = HEIGHT * scl
	var idle: Array = frames["idle"]
	if not idle.is_empty():
		sprite.texture = idle[0]
		sprite.pixel_size = hh / float(sprite.texture.get_height())
	sprite.position.y = hh / 2.0
	bar_bg.position.y = hh + 0.25
	bar_fg.position.y = hh + 0.25
	bar_fg.scale.x = 1.0
	bar_fg.modulate = Color(0.3, 1.0, 0.3)
	bar_bg.visible = r != "human"
	bar_fg.visible = r != "human"
	skill_cd = 0.0
	run_t = 0.0
	shield_t = 0.0
	invis_t = 0.0
	skill_anim = 0.0
	atk_timer = 0.0
	heavy_cd = 0.0
	target = null
	sees = false
	has_wp = false
	scan_timer = 0.0
	groan_t = randf_range(1.5, 5.0)
	if changed:
		var at := global_position + Vector3(0.0, 1.0, 0.0)
		if r == "samurai":
			Fx.sfx3d(get_parent(), Fx.SFX + "s_unsheathe.wav", at, 0.0, 1.0)
		elif r == "zombie":
			Fx.voice3d(get_parent(), "zombie", zt, "groan", at, 1.5)


# zombie bot berhasil menginfeksi: LV naik, HP maks +120
func level_up() -> void:
	if role != "zombie" or zlevel >= ZOMBIE_LEVEL_MAX:
		return
	zlevel += 1
	max_hp += ZOMBIE_LEVEL_HP
	hp = mini(hp + ZOMBIE_LEVEL_HP, max_hp)
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	bar_fg.scale.x = ratio
	bar_fg.modulate = Color(1.0 - ratio, ratio, 0.2)


func _load_frames(prefix: String, n: int) -> Array:
	var arr := []
	for i in n:
		var t = load("res://assets/char_%s/%s_%d.png" % [skin, prefix, i])
		if t != null:
			arr.append(t)
	return arr


# ------------------------------------------------------------------ cari musuh
func _scan() -> void:
	var enemy_group := "team_" + Game.enemy_of(team)
	var best_vis = null
	var best_vis_d := SIGHT
	var best_any = null
	var best_any_d := 9999.0
	for n in get_tree().get_nodes_in_group(enemy_group):
		if n.dead:
			continue
		var d: float = global_position.distance_to(n.global_position)
		var inv = n.get("invis_t")
		if inv != null and float(inv) > 0.0 and d > 3.0:
			continue   # target sedang berkabut: tidak terlihat
		if d < best_any_d:
			best_any_d = d
			best_any = n
		if d < best_vis_d and _line_of_sight(n.global_position):
			best_vis_d = d
			best_vis = n
	if best_vis != null:
		target = best_vis
		sees = true
	else:
		target = best_any
		sees = false


func _line_of_sight(tpos: Vector3) -> bool:
	var from := global_position + Vector3(0.0, 1.5, 0.0)
	var to := tpos + Vector3(0.0, 1.3, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if dead:
		return
	hurt_snd_t = maxf(hurt_snd_t - delta, 0.0)
	if role == "zombie":
		# erangan khas: zombie biasa serak melengking, zombie gendut berat dan dalam
		groan_t -= delta
		if groan_t <= 0.0:
			groan_t = randf_range(2.5, 5.0) if sees else randf_range(5.0, 11.0)
			Fx.voice3d(get_parent(), role, ztype, "groan", global_position + Vector3(0.0, 1.5, 0.0), -1.0)
		if (ztype == "gendut" or ztype == "induk_gendut") and moving:
			step_t -= delta
			if step_t <= 0.0:
				step_t = 0.42 if run_t <= 0.0 else 0.28
				Fx.voice3d(get_parent(), role, ztype, "step", global_position, -3.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif jump_req:
		velocity.y = JUMP_V
		if role != "human":
			Fx.voice3d(get_parent(), role, ztype, "jump", global_position + Vector3(0.0, 1.0, 0.0), -5.0)
	else:
		velocity.y = 0.0
	jump_req = false
	if was_air and is_on_floor() and role != "human":
		Fx.sfx3d(get_parent(), "res://assets/sfx/land.wav", global_position, -9.0)
	was_air = not is_on_floor()
	invis_t = maxf(invis_t - delta, 0.0)
	skill_anim = maxf(skill_anim - delta, 0.0)
	if _melee_role() and target != null and is_on_floor() and randf() < 0.25 * delta:
		jump_req = true   # zombie / samurai sesekali meloncat saat mengejar

	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_EVERY
		_scan()
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
		sees = false

	var tpos := Vector3.ZERO
	var dist := 9999.0
	var to_t := Vector3.ZERO
	if target != null:
		tpos = target.global_position
		to_t = tpos - global_position
		to_t.y = 0.0
		dist = to_t.length()

	var desired := Vector3.ZERO
	fire_timer -= delta
	strafe_timer -= delta
	wp_timer -= delta
	skill_cd = maxf(skill_cd - delta, 0.0)
	atk_timer = maxf(atk_timer - delta, 0.0)
	heavy_cd = maxf(heavy_cd - delta, 0.0)
	run_t = maxf(run_t - delta, 0.0)
	shield_t = maxf(shield_t - delta, 0.0)
	wander_t -= delta

	if _melee_role() and target != null:
		# zombie / samurai: kejar musuh terdekat dan serang jarak dekat
		desired = to_t
		desired.y = 0.0
		_melee_ai(dist)
		if dist <= REACH * 0.85:
			desired = Vector3.ZERO
	elif sees and target != null:
		if not seen_before:
			seen_before = true
			react = 0.55 / skill
		react -= delta
		var fwd := to_t.normalized()
		var side := fwd.cross(Vector3.UP) * strafe
		if strafe_timer <= 0.0:
			strafe_timer = randf_range(0.8, 2.0)
			if randf() < 0.5:
				strafe = -strafe
		if dist > 14.0:
			desired = fwd
		elif dist < 5.0:
			desired = -fwd + side * 0.5
		else:
			desired = side
		if react <= 0.0 and fire_timer <= 0.0:
			_shoot(dist)
	else:
		seen_before = false
		if not has_wp or wp_timer <= 0.0 or Vector2(global_position.x - wp.x, global_position.z - wp.z).length() < 1.6:
			_pick_waypoint(tpos, target != null)
		desired = wp - global_position
		desired.y = 0.0

	if wander_t > 0.0 and _melee_role():
		desired = wander_dir
	steer_timer -= delta
	if desired.length() > 0.01:
		var dn := desired.normalized()
		if steer_timer <= 0.0:
			steer_dir = _steer(dn)
			steer_timer = 0.15
		var sp := cur_speed()
		velocity.x = steer_dir.x * sp
		velocity.z = steer_dir.z * sp
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	moving = Vector2(velocity.x, velocity.z).length() > 0.3

	# FITUR PINTU RUSAK + JENDELA: zombie/samurai yang menabrak pintu rumah akan merusaknya,
	# dan melompat kalau terhalang benda rendah (ambang jendela 0.55 m) saat mengejar target.
	if _melee_role():
		door_hit_t = maxf(door_hit_t - delta, 0.0)
		vault_t = maxf(vault_t - delta, 0.0)
		for ci in range(get_slide_collision_count()):
			var sc := get_slide_collision(ci)
			var sc_col = sc.get_collider()
			if sc_col != null and sc_col.is_in_group("house_door"):
				if door_hit_t <= 0.0:
					door_hit_t = 0.8
					shoot_flash = 0.2
					sc_col.damage_door(DOOR_DMG, sc.get_position())
			elif target != null and vault_t <= 0.0 and is_on_floor() \
					and sc.get_position().y - global_position.y < 0.75 and absf(sc.get_normal().y) < 0.3:
				vault_t = 0.7
				jump_req = true

	# deteksi macet
	check_timer += delta
	if check_timer >= 0.7:
		check_timer = 0.0
		if moving and global_position.distance_to(last_pos) < 0.25:
			has_wp = false
			strafe = -strafe
			steer_timer = 0.0
			jump_req = true   # macet: loncat
			if _melee_role():
				wander_t = 1.0
				wander_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		last_pos = global_position


func _melee_ai(dist: float) -> void:
	if role == "zombie" and skill_cd <= 0.0 and sees and dist > 4.0 and dist < 22.0:
		skill_cd = SKILL_CD
		var spos := global_position + Vector3(0.0, 1.0, 0.0)
		skill_anim = 0.7
		if ztype == "suster":
			invis_t = MIST_TIME
			Fx.sfx3d(get_parent(), "res://assets/sfx/n_skill.wav", spos, 0.0)
			Fx.puff(get_parent(), spos, "res://assets/spark.png", 3.2, 0.9, Color(0.4, 1.0, 0.5, 0.7))
		elif ztype == "gendut":
			shield_t = SHIELD_TIME
			Fx.sfx3d(get_parent(), "res://assets/sfx/shield_on.wav", spos, 0.0)
			Fx.puff(get_parent(), spos, "res://assets/spark.png", 2.4, 0.6, Color(0.4, 0.7, 1.0, 0.85))
		else:
			run_t = RUN_TIME
			Fx.sfx3d(get_parent(), "res://assets/sfx/skill_run.wav", spos, 0.0)
			Fx.puff(get_parent(), spos, "res://assets/spark.png", 2.0, 0.5, Color(1.0, 0.4, 0.3, 0.85))
	if dist > REACH or atk_timer > 0.0 or target == null or not is_instance_valid(target):
		return
	var dmg := ZOMBIE_DMG
	if role == "samurai":
		if heavy_cd <= 0.0:
			dmg = SAMURAI_HEAVY
			heavy_cd = 1.8
			skill_anim = 0.5
			atk_timer = 0.9
		else:
			dmg = SAMURAI_FAST
			atk_timer = 0.4
	else:
		atk_timer = 0.8
	shoot_flash = 0.2
	lunge_t = 0.3 if dmg < SAMURAI_HEAVY else 0.5
	lunge_len = lunge_t
	var apos := global_position + Vector3(0.0, 1.0, 0.0)
	Fx.voice3d(get_parent(), role, ztype, "heavy" if dmg >= SAMURAI_HEAVY else "attack", apos, 1.0)
	if role == "samurai" and dmg >= SAMURAI_HEAVY:
		Fx.sfx3d(get_parent(), "res://assets/sfx/slash_big.wav", apos, 0.0)
		Fx.puff(get_parent(), apos + Vector3(0.0, 0.2, 0.0), "res://assets/spark.png", 2.6, 0.35, Color(0.8, 0.95, 1.0, 0.9))
	Fx.voice3d(get_parent(), role, ztype, "impact", apos, -2.0)
	var was_human: bool = zmode and role == "zombie" and str(target.get("role")) == "human"
	if target.is_in_group("player"):
		target.take_damage(dmg, global_position)
	else:
		target.take_damage(dmg, false, global_position, false)
	if was_human and is_instance_valid(target) and (str(target.get("role")) == "zombie" or bool(target.get("pending"))):
		level_up()   # berhasil menginfeksi


func _pick_waypoint(tpos: Vector3, has_target: bool) -> void:
	has_wp = true
	wp_timer = randf_range(4.0, 8.0)
	if has_target and randf() < 0.5:
		# memburu: menuju sekitar posisi musuh terdekat
		wp = tpos + Vector3(randf_range(-6.0, 6.0), 0.0, randf_range(-6.0, 6.0))
		wp.x = clampf(wp.x, -map_limit, map_limit)
		wp.z = clampf(wp.z, -map_limit, map_limit)
	elif not waypoints.is_empty():
		wp = waypoints.pick_random()
	else:
		wp = global_position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))


func _steer(dir: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 0.6, 0.0)
	for ang in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8]:
		var d := dir.rotated(Vector3.UP, ang)
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 2.0, 1)
		var steer_hit := space.intersect_ray(q)
		# Zombie/samurai menganggap pintu rumah bukan penghalang: ditabrak lalu dirusak.
		if steer_hit.is_empty() or (_melee_role() and steer_hit.collider.is_in_group("house_door")):
			return d
	return -dir


func _shoot(dist: float) -> void:
	shoot_flash = 0.14
	var mpos := global_position + Vector3(0.0, 1.3, 0.0)
	Fx.sfx3d(get_parent(), "res://assets/sfx/bot_shot.wav", mpos, -2.0, randf_range(0.9, 1.1))
	Fx.puff(get_parent(), mpos, "res://assets/muzzle.png", 0.5, 0.08)
	var chance := clampf((0.66 - dist * 0.024) * skill, 0.08, 0.75)
	if target != null and is_instance_valid(target):
		var tv = target.get("velocity")
		if tv is Vector3 and Vector2(tv.x, tv.z).length() > 2.0:
			chance *= 0.75   # target bergerak lebih sulit kena
	if target != null and is_instance_valid(target):
		if randf() < chance:
			var dmg := int(float(randi_range(5, 9)) * dmg_mult)
			if target.is_in_group("player"):
				target.take_damage(dmg, global_position)
			else:
				target.take_damage(dmg, false, global_position, false)
		else:
			_miss_effect(mpos)
	burst_left -= 1
	if burst_left <= 0:
		burst_left = randi_range(3, 5)
		fire_timer = randf_range(0.9, 1.6) / skill
	else:
		fire_timer = 0.13


# peluru meleset: percikan jatuh di sekitar target (terlihat) + garis jejak singkat
func _miss_effect(from_pos: Vector3) -> void:
	var tpos: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	var off := Vector3(randf_range(-1.4, 1.4), randf_range(-0.9, 0.8), randf_range(-1.4, 1.4))
	var space := get_world_3d().direct_space_state
	var end := tpos + off
	var q := PhysicsRayQueryParameters3D.create(from_pos, from_pos + (end - from_pos).normalized() * 80.0, 1)
	var res := space.intersect_ray(q)
	if not res.is_empty():
		end = res.position + res.normal * 0.05
	for i in range(1, 4):
		Fx.puff(get_parent(), from_pos.lerp(end, i / 4.0), "res://assets/spark.png", 0.12, 0.08)
	Fx.puff(get_parent(), end, "res://assets/spark.png", 0.45, 0.2)
	if target.is_in_group("player") and (end - tpos).length() < 3.0:
		Fx.sfx3d(get_parent(), "res://assets/sfx/tick.wav", end, -2.0, 0.7)


func take_damage(amount: int, headshot: bool = false, _from_pos: Vector3 = Vector3.ZERO, by_player: bool = false) -> bool:
	if dead:
		return false
	if zmode and role == "human" and armor > 0:
		# HERO: armor menahan serangan zombie (belum terinfeksi)
		armor = maxi(armor - ARMOR_HIT, 0)
		hurt_flash = 0.12
		return false
	if zmode and role == "human":
		# manusia kena serang zombie -> berubah jadi zombie (pilihan jenis acak untuk bot)
		Fx.sfx3d(get_parent(), Fx.SFX + "infect.wav", global_position + Vector3(0.0, 1.5, 0.0), 1.0, randf_range(0.9, 1.15))
		set_role("zombie", ["gendut", "suster", "biasa", "biasa"].pick_random())
		converted.emit(self, by_player)
		return false
	if shield_t > 0.0:
		amount = maxi(int(float(amount) * (1.0 - SHIELD_REDUCE)), 1)
	hp -= amount
	hurt_flash = 0.12
	if hurt_snd_t <= 0.0 and hp > 0 and role != "human":
		hurt_snd_t = 0.35
		Fx.voice3d(get_parent(), role, ztype, "hurt", global_position + Vector3(0.0, 1.2, 0.0), 0.0)
	if role != "human":
		Fx.sfx3d(get_parent(), Fx.SFX + "flesh_hit.wav", global_position + Vector3(0.0, 1.2, 0.0), -4.0, randf_range(0.9, 1.15))
	bar_bg.visible = true
	bar_fg.visible = true
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	bar_fg.scale.x = ratio
	bar_fg.modulate = Color(1.0 - ratio, ratio, 0.2)
	# bot yang ditembak langsung mencari musuh lagi
	has_wp = false
	scan_timer = 0.0
	if hp <= 0:
		_die(headshot, by_player)
		return true
	return false


func _die(headshot: bool, by_player: bool) -> void:
	dead = true
	remove_from_group("bots")
	remove_from_group("team_" + team)
	collision_layer = 0
	collision_mask = 0
	bar_bg.visible = false
	bar_fg.visible = false
	if role == "human":
		Fx.sfx3d(get_parent(), "res://assets/sfx/die.wav", global_position + Vector3(0.0, 1.0, 0.0), 0.0, randf_range(0.9, 1.1))
	else:
		Fx.voice3d(get_parent(), role, ztype, "die", global_position + Vector3(0.0, 1.0, 0.0), 2.0)
	died.emit(self, headshot, by_player)
	sprite.modulate = base_tint
	var dframes: Array = frames["die"]
	for t in dframes:
		sprite.texture = t
		await get_tree().create_timer(0.14).timeout
	await get_tree().create_timer(2.0).timeout
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	await tw.finished
	queue_free()


func _process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	shoot_flash = maxf(shoot_flash - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	lunge_t = maxf(lunge_t - delta, 0.0)
	var gendut := (role == "zombie" and (ztype == "gendut" or ztype == "induk_gendut"))
	# kecepatan animasi: pelari makin cepat, gendut lamban dan berat, samurai mulus
	var walk_fps := 9.0
	if role == "zombie":
		walk_fps = 5.5 if gendut else 8.0
		if run_t > 0.0:
			walk_fps *= 1.7
	elif role == "samurai":
		walk_fps = 10.0
	var list: Array
	var idx := 0
	var bob := 0.04
	if role == "zombie":
		bob = 0.09 if gendut else 0.06
	var sway := 0.0
	var squash := 1.0
	if not is_on_floor() and not frames["jump"].is_empty():
		list = frames["jump"]
		idx = 0 if velocity.y < -2.0 else 1      # jongkok saat mendarat, melayang saat di udara
	elif skill_anim > 0.0 and not frames["skill"].is_empty():
		list = frames["skill"]
		idx = int(anim_t * 10.0) % maxi(list.size(), 1)
	elif shoot_flash > 0.0:
		list = frames["shoot"]
		idx = int(anim_t * 14.0) % maxi(list.size(), 1)
	elif moving:
		list = frames["walk"]
		idx = int(anim_t * walk_fps) % maxi(list.size(), 1)
		sprite.position.y = hh / 2.0 + absf(sin(anim_t * walk_fps * 0.5 * PI)) * bob * (0.4 if role == "samurai" else 1.0)
		if role == "zombie":
			# jalan terhuyung: badan miring kiri-kanan, gendut menghentak
			sway = sin(anim_t * walk_fps * 0.5 * PI) * (9.0 if gendut else 6.0)
			if gendut:
				squash = 1.0 - 0.035 * absf(cos(anim_t * walk_fps * 0.5 * PI))
	else:
		list = frames["idle"]
		idx = int(anim_t * 2.0) % maxi(list.size(), 1)
		sprite.position.y = hh / 2.0
		if role == "zombie":
			sway = sin(anim_t * 1.7) * 3.0   # berdiri sambil bergoyang
	# napas / terjang saat menyerang
	var lunge := 0.0
	if lunge_t > 0.0:
		lunge = sin(PI * (1.0 - lunge_t / maxf(lunge_len, 0.01)))
	var breathe := 0.012 * sin(anim_t * 2.4)
	var ls := 1.0 + lunge * (0.22 if role == "samurai" else 0.16)
	sprite.scale = Vector3(ls * (1.0 + breathe * 0.5), ls * (squash + breathe), 1.0)
	sprite.offset = Vector2(sway + (randf_range(-6.0, 6.0) if hurt_flash > 0.0 else 0.0), 0.0)
	if list.is_empty():
		return
	sprite.texture = list[idx]
	var tint := base_tint
	if shield_t > 0.0:
		tint = Color(0.55, 0.8, 1.35)    # perisai zombie gendut menyala biru
	elif run_t > 0.0:
		tint = Color(1.25, 0.75, 0.7)    # zombie pelari memerah
	if invis_t > 0.0:
		tint = Color(0.7, 1.0, 0.75, 0.28)   # berkabut: hampir tak terlihat
	sprite.modulate = Color(1.0, 0.45, 0.45) if hurt_flash > 0.0 else tint
