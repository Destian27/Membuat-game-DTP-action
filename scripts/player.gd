extends CharacterBody3D
# Pemain FPS: gerak, lihat, tembak (raycast), reload, darah.
# Kontrol PC : WASD, Spasi (lompat), R (reload), klik kiri (tembak), Esc (lepas mouse)
# Kontrol HP : joystick kiri, geser kanan untuk membidik, tombol tembak/reload/lompat

const Fx = preload("res://scripts/fx.gd")
const Weapons = preload("res://scripts/weapons.gd")

signal died
signal health_changed(hp: int)
signal ammo_changed(mag: int, reserve: int)
signal fired
signal hit_confirmed(killed: bool, headshot: bool)
signal damaged
signal weapon_changed(slot: int)
signal infected            # mode Zombie: manusia terkena serangan zombie -> pilih jenis zombie
signal role_changed(role: String)
signal skill_used
signal leveled_up(level: int)       # zombie: berhasil menginfeksi -> LV naik, HP bertambah
signal infect_made                 # zombie: emblem TERINFEKSI di HUD
signal skill_fx(kind: String)   # "run" / "shield" / "heavy" / "shield_end" / "ready" -> animasi & suara skill di HUD

const SPEED := 6.5
const JUMP_V := 5.6
const GRAVITY := 16.0
const MAX_HP := 100
const AIM_ASSIST_CONE := 0.07   # sekitar 4 derajat
const AIM_ASSIST_RANGE := 35.0

# ---- mode Zombie (angka bisa diubah di sini) ----
const ZOMBIE_HP := {"induk": 2300, "induk_gendut": 3400, "biasa": 850, "gendut": 1250, "suster": 1000}   # induk = zombie pertama; lainnya bukan induk
const SAMURAI_HP := 5200
const ZOMBIE_LEVEL_HP := 120      # tiap menginfeksi 1 manusia: LV +1 dan HP maks +120 (gaya Crisis Action)
const ZOMBIE_LEVEL_MAX := 9
const HERO_HP := 130              # HERO: HP lebih besar + armor yang menahan infeksi
const HERO_ARMOR := 100
const ARMOR_HIT := 50             # tiap serangan zombie mengurangi armor 50 (hero tahan 2 serangan)
const SKILL_CD := 40.0          # cooldown semua skill zombie (detik)
const RUN_TIME := 7.0           # skill lari cepat (Induk & Zombie biasa)
const RUN_MULT := 1.7
const SHIELD_TIME := 9.0        # skill perisai Zombie gendut
const MIST_TIME := 8.0          # skill kabut virus Zombie suster (menghilang dari pandangan bot)
const SHIELD_REDUCE := 0.95     # perisai kurangi damage 95%
const HEAVY_DMG := 800          # samurai: serangan lambat
const HEAVY_CD := 1.8
const ZOMBIE_W := {
	"id": "claw", "name": "CAKAR", "short": "CAKAR", "fp": "zombie_hands_0.png", "icon": "icon_knife.png",
	"melee": true, "auto": true, "mag": 0, "reserve": 0, "delay": 0.8, "reload": 0.0, "dmg": 300,
	"spread": 0.0, "recoil": 0.0, "range": 2.4, "muzzle": Vector2(0.0, 0.0),
	"sfx": "res://assets/sfx/hit.wav", "sfx_pitch": 0.6,
}
const SAMURAI_W := {
	"id": "katana", "name": "SAMURAI", "short": "KATANA", "fp": "katana_fp.png", "icon": "icon_knife.png",
	"melee": true, "auto": true, "mag": 0, "reserve": 0, "delay": 0.4, "reload": 0.0, "dmg": 250,
	"spread": 0.0, "recoil": 0.0, "range": 2.8, "muzzle": Vector2(0.0, 0.0),
	"sfx": "res://assets/sfx/hit.wav", "sfx_pitch": 1.6,
}

var is_mobile := OS.has_feature("android") or OS.has_feature("ios")

var team := "red"   # diset main.gd (pilihan di menu)

var hp := MAX_HP
var max_hp := MAX_HP
var zmode := false          # diset main.gd: mode Zombie
var role := "human"         # "human" / "zombie" / "samurai" (zombie & samurai hanya serang jarak dekat)
var ztype := ""             # "induk" / "biasa" / "gendut"
var zlevel := 0             # level zombie (naik tiap berhasil menginfeksi)
var htype := "hero"         # jenis manusia di mode Zombie: "hero" / "civil"
var armor := 0              # armor manusia hero (menahan infeksi)
var auto_fire := false      # tombol Otomatis di HUD: menembak/menyerang otomatis kalau bidikan kena musuh
var base_dmg_mult := 1.0    # pengali damage senjata manusia (mode Zombie: HP zombie besar)
var head_mult := 2.0        # pengali headshot
var spd_mult := 1.0
var skill_cd := 0.0
var invis_t := 0.0
var was_air := false
var run_t := 0.0
var shield_t := 0.0
var heavy_cd := 0.0
var skill_req := false
var pending := false        # menunggu pemain memilih jenis zombie
var hurt_snd_t := 0.0       # throttle suara kena (zombie / samurai)
var groan_t := 6.0          # jeda erangan zombie berikutnya
# slot senjata: 0 = utama, 1 = pistol, 2 = pisau (data di scripts/weapons.gd)
var slot := 0
var last_slot := 1
var w: Dictionary = Weapons.get_weapon(0)
var mags := [30, 12, 0]
var reserves := [120, 60, 0]
var mag := 30
var reserve := 120
var reload_token := 0
var fire_held := false
var dead := false
var reloading := false
var cooldown := 0.0
var since_hit := 0.0
var regen_acc := 0.0
var recoil := 0.0
var pitch := 0.0
var bob_t := 0.0
var shake := 0.0            # getar kamera (tebasan berat samurai)
var was_shield := false
var was_cd_zombie := false
var was_cd_heavy := false

# diisi oleh HUD (kontrol sentuh)
var move_input := Vector2.ZERO
var look_delta := Vector2.ZERO
var touch_fire := false
var jump_req := false
var reload_req := false

var mouse_sens := 0.0025
var touch_sens := 0.0045

var head: Node3D
var cam: Camera3D


func _ready() -> void:
	# Kemiringan ramp tangga rumah harus bisa dilalui sambil berjalan, tanpa perlu lompat.
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.8
	floor_stop_on_slope = true
	collision_layer = 2
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.55
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 480.0 if zmode else 200.0
	head.add_child(cam)
	cam.current = true
	_init_weapons()
	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if is_mobile or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative, mouse_sens)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		var step := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 2
		switch_weapon((slot + step) % 3)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _rotate_view(rel: Vector2, sens: float) -> void:
	rotate_y(-rel.x * sens)
	pitch = clampf(pitch - rel.y * sens, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move_input.length() > 0.12:
		inp = move_input
	if pending:
		inp = Vector2.ZERO
	var dir := global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var k := minf(1.0, 12.0 * delta)
	velocity.x = lerpf(velocity.x, dir.x * SPEED * spd_mult, k)
	velocity.z = lerpf(velocity.z, dir.z * SPEED * spd_mult, k)

	if is_on_floor() and (Input.is_action_just_pressed("jump") or jump_req):
		velocity.y = JUMP_V
		if role != "human":
			Fx.voice2d(self, role, ztype, "jump", -6.0)
	jump_req = false
	if was_air and is_on_floor() and role != "human":
		Fx.sfx2d(self, "res://assets/sfx/land.wav", -8.0)
	was_air = not is_on_floor()
	move_and_slide()

	var spd := minf(Vector2(velocity.x, velocity.z).length() / SPEED, 1.0)
	bob_t += delta * (4.0 + spd * 6.0)
	head.position.y = 1.55 + sin(bob_t * 2.0) * 0.03 * spd if is_on_floor() else 1.55


func _process(delta: float) -> void:
	if look_delta != Vector2.ZERO:
		_rotate_view(look_delta, touch_sens)
		look_delta = Vector2.ZERO
	recoil = move_toward(recoil, 0.0, delta * 0.5)
	head.rotation.x = pitch + recoil
	if dead:
		return

	if pending:
		return
	skill_cd = maxf(skill_cd - delta, 0.0)
	heavy_cd = maxf(heavy_cd - delta, 0.0)
	run_t = maxf(run_t - delta, 0.0)
	shield_t = maxf(shield_t - delta, 0.0)
	invis_t = maxf(invis_t - delta, 0.0)
	var mobf := 1.0
	if role == "human":
		mobf = 0.92 + 0.0016 * float(w.get("mob", 50))   # senjata ringan = sedikit lebih cepat
	spd_mult = (RUN_MULT if run_t > 0.0 else 1.0) * mobf
	cam.fov = lerpf(cam.fov, 88.0 if run_t > 0.0 else 75.0, minf(1.0, 6.0 * delta))   # skill lari: pandangan melebar
	shake = move_toward(shake, 0.0, delta * 2.2)
	head.rotation.z = sin(Time.get_ticks_msec() * 0.06) * 0.035 * shake
	_skill_events()
	if (InputMap.has_action("skill") and Input.is_action_just_pressed("skill")) or skill_req:
		use_skill()
	skill_req = false

	since_hit += delta
	hurt_snd_t = maxf(hurt_snd_t - delta, 0.0)
	if role == "zombie" and not dead and not pending:
		groan_t -= delta
		if groan_t <= 0.0:
			groan_t = randf_range(7.0, 13.0)
			Fx.voice2d(self, role, ztype, "groan", -9.0)   # erangan pelan sesekali saat jadi zombie
	if role == "human" and hp < max_hp and since_hit > 5.0:
		regen_acc += delta * 8.0
		if regen_acc >= 1.0:
			var add := int(regen_acc)
			regen_acc -= add
			hp = mini(max_hp, hp + add)
			health_changed.emit(hp)

	cooldown -= delta
	for k in 3:
		if InputMap.has_action("weapon_%d" % (k + 1)) and Input.is_action_just_pressed("weapon_%d" % (k + 1)):
			switch_weapon(k)
	if InputMap.has_action("weapon_last") and Input.is_action_just_pressed("weapon_last"):
		switch_weapon(last_slot)
	var wants := touch_fire or (not is_mobile and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("fire"))
	if auto_fire and not wants and _auto_target():
		wants = true
	var fresh := wants and not fire_held
	fire_held = wants
	if (Input.is_action_just_pressed("reload") or reload_req):
		start_reload()
	reload_req = false
	var trigger: bool = (wants and bool(w["auto"])) or fresh
	if trigger and cooldown <= 0.0 and not reloading:
		if bool(w["melee"]):
			_melee()
		elif mag > 0:
			_fire()
		else:
			start_reload()


# ------------------------------------------------------------------ senjata
func _init_weapons() -> void:
	for i in 3:
		var d := Weapons.get_weapon(i)
		mags[i] = int(d["mag"])
		reserves[i] = int(d["reserve"])
	slot = 0
	last_slot = 1
	w = Weapons.get_weapon(0)
	mag = int(mags[0])
	reserve = int(reserves[0])
	reload_token += 1


func switch_weapon(i: int) -> void:
	if role != "human" or pending:
		return
	if dead or i < 0 or i > 2 or i == slot:
		return
	mags[slot] = mag
	reserves[slot] = reserve
	last_slot = slot
	slot = i
	w = Weapons.get_weapon(i)
	mag = int(mags[i])
	reserve = int(reserves[i])
	reloading = false
	reload_token += 1
	cooldown = 0.25
	recoil = 0.0
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -6.0, 0.8)
	weapon_changed.emit(slot)
	ammo_changed.emit(mag, reserve)


# tembak raycast; peluru/tebasan menembus rekan satu tim (tidak ada friendly fire)
func _cast(from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var res := {}
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, 1 | 4)
		q.exclude = exclude
		res = space.intersect_ray(q)
		if res.is_empty():
			break
		var c = res.collider
		if c != null and c.has_method("take_damage") and c.get("team") == team:
			exclude.append(c.get_rid())
			res = {}
			continue
		break
	return res


# bantuan bidik (Aim Assist dari lobi): arahkan sedikit ke musuh yang hampir di tengah layar
func _assist(dir: Vector3, from: Vector3) -> Vector3:
	if not Game.aim_assist:
		return dir
	var best := dir
	var best_ang := AIM_ASSIST_CONE
	for e in get_tree().get_nodes_in_group("team_" + Game.enemy_of(team)):
		if not is_instance_valid(e) or e == self or bool(e.get("dead")):
			continue
		var to: Vector3 = e.global_position + Vector3(0.0, 1.2, 0.0) - from
		var dist := to.length()
		if dist < 1.0 or dist > AIM_ASSIST_RANGE:
			continue
		var tdir := to / dist
		var ang := dir.angle_to(tdir)
		if ang < best_ang:
			best_ang = ang
			best = dir.lerp(tdir, 0.65).normalized()
	return best


func eff_mult() -> float:
	return base_dmg_mult if role == "human" else 1.0


# deteksi perubahan status skill -> suara + sinyal animasi (perisai habis, skill siap dipakai lagi)
func _skill_events() -> void:
	if was_shield and shield_t <= 0.0:
		Fx.sfx2d(self, "res://assets/sfx/shield_off.wav", -4.0)
		skill_fx.emit("shield_end")
	was_shield = shield_t > 0.0
	var cd_z: bool = role == "zombie" and skill_cd > 0.0
	if was_cd_zombie and not cd_z and role == "zombie":
		Fx.sfx2d(self, "res://assets/sfx/skill_ready.wav", -6.0)
		skill_fx.emit("ready")
	was_cd_zombie = cd_z
	var cd_h: bool = role == "samurai" and heavy_cd > 0.0
	if was_cd_heavy and not cd_h and role == "samurai":
		Fx.sfx2d(self, "res://assets/sfx/skill_ready.wav", -6.0, 1.2)
		skill_fx.emit("ready")
	was_cd_heavy = cd_h


func use_skill() -> void:
	if dead or pending:
		return
	if role == "zombie" and skill_cd <= 0.0:
		skill_cd = SKILL_CD
		if ztype == "suster":
			invis_t = MIST_TIME
			Fx.sfx2d(self, "res://assets/sfx/n_skill.wav", -2.0)
			skill_fx.emit("mist")
		elif ztype == "gendut":
			shield_t = SHIELD_TIME
			Fx.sfx2d(self, "res://assets/sfx/shield_on.wav", -2.0)
			skill_fx.emit("shield")
		else:
			run_t = RUN_TIME
			Fx.sfx2d(self, "res://assets/sfx/skill_run.wav", -2.0)
			skill_fx.emit("run")
		Fx.voice2d(self, role, ztype, "groan", 2.0)   # raungan saat skill (lari / perisai)
		skill_used.emit()
	elif role == "samurai" and heavy_cd <= 0.0 and cooldown <= 0.0:
		heavy_cd = HEAVY_CD
		Fx.sfx2d(self, "res://assets/sfx/slash_big.wav", -2.0)
		shake = 1.0
		skill_fx.emit("heavy")
		_melee(HEAVY_DMG)


func _melee(dmg_override: int = -1) -> void:
	cooldown = 0.7 if dmg_override >= 0 else float(w["delay"])
	fired.emit()
	if role == "human":
		Fx.sfx2d(self, str(w["sfx"]), -8.0, float(w["sfx_pitch"]))
	else:
		# suara khas: zombie biasa mencakar, zombie gendut memukul, samurai menebas (berat = kiai)
		Fx.voice2d(self, role, ztype, "heavy" if dmg_override >= 0 else "attack", -3.0)
	var b := cam.global_transform.basis
	var from := cam.global_position
	var reach := float(w["range"])
	var hit := {}
	for off in [0.0, -0.18, 0.18]:
		var dir: Vector3 = (-b.z + b.x * off).normalized()
		var res := _cast(from, dir, reach)
		if res.is_empty():
			continue
		var c = res.collider
		if c != null and c.has_method("take_damage"):
			hit = res
			break
		if hit.is_empty():
			hit = res
	if hit.is_empty():
		return
	var col = hit.collider
	# FITUR PINTU RUSAK: tebasan/cakaran (termasuk skill heavy) merusak pintu rumah.
	if col != null and col.is_in_group("house_door"):
		var door_dmg: int = dmg_override if dmg_override >= 0 else int(float(w["dmg"]) * eff_mult())
		col.damage_door(door_dmg, hit.position)
		return
	if col != null and col.has_method("take_damage"):
		var md: int = dmg_override if dmg_override >= 0 else int(float(w["dmg"]) * eff_mult())
		var was_human: bool = zmode and role == "zombie" and str(col.get("role")) == "human"
		var killed: bool = col.take_damage(md, false, global_position, true)
		if was_human and str(col.get("role")) == "zombie":
			level_up()   # berhasil menginfeksi
		Fx.puff(get_parent(), hit.position, "res://assets/blood.png", 0.7, 0.3)
		if role == "human":
			Fx.sfx2d(self, "res://assets/sfx/tick.wav", -4.0, 0.8)
		else:
			Fx.voice2d(self, role, ztype, "impact", -2.0)
		hit_confirmed.emit(killed, false)
	else:
		Fx.puff(get_parent(), hit.position + hit.normal * 0.05, "res://assets/spark.png", 0.3, 0.15)


func _fire() -> void:
	mag -= 1
	cooldown = float(w["delay"])
	recoil = minf(recoil + float(w["recoil"]), 0.14)
	ammo_changed.emit(mag, reserve)
	fired.emit()
	Fx.sfx2d(self, str(w["sfx"]), -4.0, float(w["sfx_pitch"]) * randf_range(0.95, 1.05))

	var b := cam.global_transform.basis
	var sp := float(w["spread"]) + clampf(Vector2(velocity.x, velocity.z).length() / SPEED, 0.0, 1.0) * 0.012
	var dir := (-b.z + b.x * randf_range(-sp, sp) + b.y * randf_range(-sp, sp)).normalized()
	var from := cam.global_position
	dir = _assist(dir, from)
	var res := _cast(from, dir, float(w["range"]))
	if res.is_empty():
		return
	var col = res.collider
	# FITUR PINTU RUSAK: peluru merusak pintu rumah (house_door.gd), tanpa efek darah.
	if col != null and col.is_in_group("house_door"):
		col.damage_door(int(float(w["dmg"]) * eff_mult()), res.position)
		return
	if col != null and col.has_method("take_damage"):
		var local_y: float = res.position.y - col.global_position.y
		var head_shot: bool = local_y > 1.45
		var dmg: int = int(float(w["dmg"]) * eff_mult() * (head_mult if head_shot else 1.0))
		var killed: bool = col.take_damage(dmg, head_shot, global_position, true)
		Fx.puff(get_parent(), res.position, "res://assets/blood.png", 0.55, 0.3)
		Fx.sfx2d(self, "res://assets/sfx/tick.wav", -6.0, 1.3 if head_shot else 1.0)
		hit_confirmed.emit(killed, head_shot)
	else:
		Fx.puff(get_parent(), res.position + res.normal * 0.05, "res://assets/spark.png", 0.4, 0.2)


func start_reload() -> void:
	if bool(w["melee"]) or reloading or dead or mag == int(w["mag"]) or reserve <= 0:
		return
	reloading = true
	var token := reload_token
	Fx.sfx2d(self, "res://assets/sfx/reload.wav", -3.0, 1.2 if slot == 1 else 1.0)
	await get_tree().create_timer(float(w["reload"])).timeout
	if token != reload_token:
		return   # ganti senjata / respawn: status reload sudah diurus di sana
	if dead or not reloading:
		reloading = false
		return
	var take := mini(int(w["mag"]) - mag, reserve)
	mag += take
	reserve -= take
	reloading = false
	ammo_changed.emit(mag, reserve)


func add_ammo(n: int) -> void:
	# bonus peluru masuk ke senjata yang sedang dipegang; kalau pisau, masuk ke senjata utama
	if bool(w["melee"]):
		reserves[0] = int(reserves[0]) + n
	else:
		reserve += n
	ammo_changed.emit(mag, reserve)


func take_damage(amount: int, _from_pos: Vector3 = Vector3.ZERO) -> void:
	if dead or pending:
		return
	if zmode and role == "human" and armor > 0:
		# HERO: armor menahan serangan zombie (tidak terinfeksi selama armor masih ada)
		armor = maxi(armor - ARMOR_HIT, 0)
		since_hit = 0.0
		Fx.sfx2d(self, "res://assets/sfx/hurt.wav", -2.0, randf_range(0.9, 1.1))
		damaged.emit()
		return
	if zmode and role == "human":
		# kena serang zombie: tidak mati, langsung diminta memilih jenis zombie
		pending = true
		touch_fire = false
		move_input = Vector2.ZERO
		Fx.sfx2d(self, "res://assets/sfx/infect.wav", 0.0, 1.0)   # jeritan terinfeksi
		damaged.emit()
		infected.emit()
		return
	if shield_t > 0.0:
		amount = maxi(int(float(amount) * (1.0 - SHIELD_REDUCE)), 1)
	hp = maxi(hp - amount, 0)
	since_hit = 0.0
	health_changed.emit(hp)
	damaged.emit()
	if role == "human":
		Fx.sfx2d(self, "res://assets/sfx/hurt.wav", -2.0, randf_range(0.9, 1.1))
	elif hurt_snd_t <= 0.0:
		hurt_snd_t = 0.35
		Fx.voice2d(self, role, ztype, "hurt", -1.0)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	reloading = false
	touch_fire = false
	move_input = Vector2.ZERO
	if role == "human":
		Fx.sfx2d(self, "res://assets/sfx/die.wav", -2.0, 1.0)
	else:
		Fx.voice2d(self, role, ztype, "die", 0.0)   # suara mati khas zombie / samurai
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(head, "position:y", 0.35, 0.5)
	tw.tween_property(head, "rotation:z", 0.9, 0.5)
	died.emit()


func apply_role(r: String, zt: String = "") -> void:
	var was_zombie := role == "zombie"
	role = r
	ztype = zt
	if not (r == "zombie" and was_zombie):
		zlevel = 0   # level zombie mulai dari 0 saat baru menjadi zombie; respawn zombie mempertahankan level
	remove_from_group("team_" + team)
	if zmode:
		team = "zombie" if r == "zombie" else "human"
	add_to_group("team_" + team)
	match r:
		"zombie":
			max_hp = int(ZOMBIE_HP.get(zt, 850)) + zlevel * ZOMBIE_LEVEL_HP
		"samurai":
			max_hp = SAMURAI_HP
		_:
			max_hp = HERO_HP if (zmode and htype == "hero") else MAX_HP
	hp = max_hp
	armor = HERO_ARMOR if (r == "human" and zmode and htype == "hero") else 0
	pending = false
	skill_cd = 0.0
	run_t = 0.0
	shield_t = 0.0
	invis_t = 0.0
	heavy_cd = 0.0
	spd_mult = 1.0
	was_shield = false
	was_cd_zombie = false
	was_cd_heavy = false
	if r == "human":
		_init_weapons()
	else:
		slot = 0
		w = SAMURAI_W.duplicate() if r == "samurai" else ZOMBIE_W.duplicate()
		if r == "zombie" and zt == "gendut":
			w["fp"] = "gendut_fists_0.png"   # zombie gendut: tangan mengepal, menyerang dengan memukul
			w["name"] = "PUKUL"
		elif r == "zombie" and zt == "suster":
			w["fp"] = "suster_hands_0.png"   # zombie suster: tangan pucat bercakar
		mag = 0
		reserve = 0
	reloading = false
	fire_held = false
	reload_token += 1
	if is_inside_tree() and not dead:
		if r == "samurai":
			Fx.sfx2d(self, "res://assets/sfx/s_unsheathe.wav", 0.0, 1.0)
		elif r == "zombie":
			Fx.voice2d(self, r, zt, "groan", 1.0)
	health_changed.emit(hp)
	weapon_changed.emit(slot)
	ammo_changed.emit(mag, reserve)
	role_changed.emit(r)


# zombie berhasil menginfeksi manusia: LV naik, HP maks dan HP bertambah 120
func level_up() -> void:
	if role != "zombie":
		return
	infect_made.emit()
	if zlevel >= ZOMBIE_LEVEL_MAX:
		return
	zlevel += 1
	max_hp += ZOMBIE_LEVEL_HP
	hp = mini(hp + ZOMBIE_LEVEL_HP, max_hp)
	health_changed.emit(hp)
	leveled_up.emit(zlevel)


# Otomatis: bidikan tepat di musuh dalam jangkauan senjata
func _auto_target() -> bool:
	if dead or pending or cam == null:
		return false
	var reach := float(w.get("range", 40.0))
	var res := _cast(cam.global_position, -cam.global_transform.basis.z, reach)
	if res.is_empty():
		return false
	var c = res.collider
	return c != null and c != self and c.is_in_group("bots") and not c.is_in_group("team_" + team)


func respawn(pos: Vector3) -> void:
	global_position = pos
	look_at(Vector3(0.0, pos.y, 0.0), Vector3.UP)
	velocity = Vector3.ZERO
	apply_role(role, ztype)
	dead = false
	reloading = false
	cooldown = 0.0
	pitch = 0.0
	recoil = 0.0
	head.position.y = 1.55
	head.rotation.z = 0.0
	health_changed.emit(hp)
	weapon_changed.emit(slot)
	ammo_changed.emit(mag, reserve)
