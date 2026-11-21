extends Node3D
# Crisis Action DTP - mode Pelatihan (Tim Merah vs Tim Biru lawan bot) dan mode Zombie.
# Arena dibangun lewat kode dari data di scripts/stages.gd; tampilan memakai gambar di res://assets/.
# Tidak ada koin / diamond di dalam gameplay (hanya hadiah akhir match).

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
const HudScript = preload("res://scripts/hud.gd")
const StagesScript = preload("res://scripts/stages.gd")
const Fx = preload("res://scripts/fx.gd")
const HouseDoorScript = preload("res://scripts/house_door.gd")

const BOT_RESPAWN := 4.0

# ---- mode Zombie (angka bisa diubah di sini) ----
const ZOMBIE_TOTAL := 14            # jumlah pemain (kamu + bot); lebih banyak dari mode Pelatihan
const ZOMBIE_ROUND_TIME := 180.0    # manusia menang kalau ada yang bertahan sampai waktu habis
const ZOMBIE_RESPAWN := 6.0
const ZOMBIE_WEAPON_MULT := 10.0    # damage senjata manusia x10 karena HP zombie ribuan
const ZOMBIE_HEAD_MULT := 1.85      # headshot +85%
const ROUNDS_TO_WIN := 3              # poin ronde yang dibutuhkan untuk memenangkan match
const ROUND_RESULT_TIME := 5.0      # lama animasi menang antar ronde (detik)
const INFECT_AUTO := 10.0           # detik; kalau tidak memilih jenis zombie, otomatis Zombie biasa

var cfg: Dictionary = {}
var arena := 24.0
var city_spawn_points: Array = []
var building_bounds: Array = []
var city_road_lines: Array = []      # untuk minimap HUD
var city_road_w := 9.0
var induk_spawned := true             # Induk muncul setelah hitung mundur virus
var virus_left := 0.0
var first_blood := false
const VIRUS_DELAY := 5.0
const ZNAMES := ["KingJack", "growywow", "ZombieKiller13", "NightWolf", "Rayhan_ID", "BangJago", "DewiSurvivor", "Kakek_Zombie", "AnakMalam", "Sniper_Kota", "BuDe_Pro", "SiLincah"]
var city_material_cache: Dictionary = {}
var city_tree_records: Array[Dictionary] = []
var city_blocked_objects: Array[Vector3] = []
var city_prop_collision_root: StaticBody3D
var player
var hud
var my_team := "red"
var enemy_team := "blue"
var score := {"red": 0, "blue": 0}
var target_score := 20
var kills := 0
var deaths := 0
var finished := false

var zmode := false
var time_left := 0.0
var samurai_done := false
var round_no := 1
var pts_human := 0
var pts_zombie := 0
var round_over := false
var round_t := 0.0
var music: AudioStreamPlayer
var infect_token := 0
var hud_tick := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	zmode = Game.mode == "zombie"
	my_team = "human" if zmode else Game.team
	enemy_team = Game.enemy_of(my_team)
	var zombie_stage_id := StagesScript.ZOMBIE_MORNING_STAGE if Game.zombie_map == "morning" else StagesScript.ZOMBIE_STAGE
	cfg = StagesScript.get_stage(zombie_stage_id if zmode else Game.stage)   # mode Zombie memiliki pilihan map sendiri
	if cfg.is_empty():
		Game.stage = 1
		cfg = StagesScript.get_stage(1)
	arena = float(cfg["arena"])
	target_score = int(cfg["target"])

	_build_environment()
	_build_arena()

	player = PlayerScript.new()
	player.team = my_team
	player.zmode = zmode
	if zmode:
		player.base_dmg_mult = ZOMBIE_WEAPON_MULT
		player.head_mult = ZOMBIE_HEAD_MULT
	player.add_to_group("player")
	player.add_to_group("team_" + my_team)
	add_child(player)
	player.respawn(_spawn_point(my_team))
	player.died.connect(_on_player_died)

	hud = HudScript.new()
	add_child(hud)
	hud.setup(player)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(_to_menu)

	if zmode:
		_start_zombie()
	else:
		_start_training()


func _start_training() -> void:
	_update_score()
	hud.show_center("%s  -  TIM %s  -  TARGET %d KILL" % [cfg["name"].to_upper(), Game.team_name(my_team), target_score], 3.5)
	var team_size: int = int(cfg["team_size"])
	for i in team_size - 1:
		_spawn_bot(my_team)
	for i in team_size:
		_spawn_bot(enemy_team)


# ------------------------------------------------------------------ input
func _setup_input() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("reload", [KEY_R])
	_add_action("skill", [KEY_E])
	_add_action("weapon_1", [KEY_1])
	_add_action("weapon_2", [KEY_2])
	_add_action("weapon_3", [KEY_3])
	_add_action("weapon_last", [KEY_Q])
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", ev)


func _add_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action_name, e)


# ------------------------------------------------------------------ dunia
func _build_environment() -> void:
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = load("res://assets/%s.png" % cfg["sky"])
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	if cfg["ambient_src"] == "color":
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = cfg["ambient_color"]
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(cfg["ambient_energy"])
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if cfg["fog"]:
		env.fog_enabled = true
		env.fog_light_color = cfg.get("fog_color", Color(0.1, 0.11, 0.24))
		env.fog_density = float(cfg.get("fog_density", 0.012))
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_color = cfg["sun_color"]
	sun.light_energy = float(cfg["sun_energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0 if zmode else 45.0
	add_child(sun)


func _box(pos: Vector3, size: Vector3, tex_name: String, triplanar: bool = true, tile: float = 0.25) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/%s.png" % tex_name)
	m.roughness = 0.9
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * tile
	mesh.material_override = m
	body.add_child(mesh)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)

	add_child(body)
	body.position = pos


func _build_arena() -> void:
	var span := arena * 2.0
	# lantai
	_box(Vector3(0, -0.5, 0), Vector3(span + 4.0, 1.0, span + 4.0), cfg["floor"], true, 0.25)
	# tembok batas
	var h := 6.0
	var wt: String = cfg["wall"]
	_box(Vector3(0, h / 2.0, -arena - 0.5), Vector3(span + 2.0, h, 1.0), wt, true, 0.25)
	_box(Vector3(0, h / 2.0, arena + 0.5), Vector3(span + 2.0, h, 1.0), wt, true, 0.25)
	_box(Vector3(-arena - 0.5, h / 2.0, 0), Vector3(1.0, h, span + 2.0), wt, true, 0.25)
	_box(Vector3(arena + 0.5, h / 2.0, 0), Vector3(1.0, h, span + 2.0), wt, true, 0.25)

	# tembok, peti, kontainer: [posisi, ukuran, tekstur, triplanar, tile]
	for b in cfg["blocks"]:
		var p: Vector3 = b[0]
		var s: Vector3 = b[1]
		var tex: String = b[2]
		var tri: bool = b[3]
		var tile: float = float(b[4])
		_box(Vector3(p.x, s.y / 2.0, p.z), s, tex, tri, tile)

	# Lampu jalan malam. Collider tiang digabung dalam satu StaticBody agar ringan.
	var lamp_collision_body := StaticBody3D.new()
	lamp_collision_body.name = "StreetLampCollisions"
	lamp_collision_body.collision_layer = 1
	lamp_collision_body.collision_mask = 0
	if not cfg["lamps"].is_empty():
		add_child(lamp_collision_body)
	for lamp_index in range(cfg["lamps"].size()):
		var l: Vector2 = cfg["lamps"][lamp_index]
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.055
		pole_mesh.bottom_radius = 0.12
		pole_mesh.height = 4.6
		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		var pole_mat := StandardMaterial3D.new()
		pole_mat.albedo_color = Color(0.12, 0.14, 0.17)
		pole_mat.roughness = 0.85
		pole.material_override = pole_mat
		add_child(pole)
		pole.position = Vector3(l.x, 2.3, l.y)
		var pole_collision := CollisionShape3D.new()
		var pole_shape := CylinderShape3D.new()
		pole_shape.radius = 0.16
		pole_shape.height = 4.6
		pole_collision.shape = pole_shape
		pole_collision.position = Vector3(l.x, 2.3, l.y)
		lamp_collision_body.add_child(pole_collision)
		# Hanya separuh tiang memakai OmniLight; glow sprite tetap ada di semua tiang.
		if lamp_index % 2 == 0:
			var light := OmniLight3D.new()
			light.light_color = cfg.get("lamp_color", Color(1.0, 0.82, 0.5))
			light.light_energy = 1.25
			light.omni_range = 14.0
			add_child(light)
			light.position = Vector3(l.x, 4.5, l.y)
		var glow := Sprite3D.new()
		glow.texture = load("res://assets/spark.png")
		glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glow.shaded = false
		glow.pixel_size = 2.4 / 64.0
		glow.modulate = cfg.get("lamp_color", Color(1.0, 0.85, 0.5)).lerp(Color(1, 1, 1), 0.3)
		add_child(glow)
		glow.position = Vector3(l.x, 4.5, l.y)

	if zmode:
		_build_zombie_city()


# ------------------------------------------------------------------ kota zombie berskala luas
func _city_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if city_material_cache.has(key):
		return city_material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	city_material_cache[key] = material
	return material


func _city_mesh(parent: Node3D, pos: Vector3, mesh: Mesh, material: Material,
		rotation: Vector3 = Vector3.ZERO) -> void:
	# Semua visual statis rumah/kota digabung per material pada root kota.
	# Collision tetap berada pada StaticBody tiap rumah agar bukaan dan interior akurat.
	var batch_parent: Node3D = parent
	var mesh_pos := pos
	if parent.has_meta("_is_city_building"):
		mesh_pos = parent.position + pos
		batch_parent = self
	if batch_parent.has_meta("_city_mesh_batch"):
		var batches: Dictionary = batch_parent.get_meta("_city_mesh_batch")
		var key := material.get_instance_id()
		var entry: Dictionary
		if batches.has(key):
			entry = batches[key]
		else:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			entry = {"tool": surface, "material": material}
		var tool: SurfaceTool = entry["tool"]
		tool.append_from(mesh, 0, Transform3D(Basis.from_euler(rotation), mesh_pos))
		batches[key] = entry
		batch_parent.set_meta("_city_mesh_batch", batches)
		return

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation = rotation
	parent.add_child(instance)


func _flush_city_mesh_batch(parent: Node3D) -> void:
	if not parent.has_meta("_city_mesh_batch"):
		return
	var batches: Dictionary = parent.get_meta("_city_mesh_batch")
	for entry_value in batches.values():
		var entry: Dictionary = entry_value
		var combined: ArrayMesh = (entry["tool"] as SurfaceTool).commit()
		if combined == null or combined.get_surface_count() == 0:
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = combined
		instance.material_override = entry["material"]
		parent.add_child(instance)
	parent.remove_meta("_city_mesh_batch")


func _city_box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _city_solid_box(parent: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> void:
	_city_mesh(parent, pos, _city_box_mesh(size), material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)


func _city_open_wall_x(parent: StaticBody3D, center: Vector3, span: float, thickness: float,
		full_height: float, opening_width: float, opening_height: float, material: Material,
		sill_height: float = 0.0) -> void:
	var segment := (span - opening_width) * 0.5
	if segment > 0.2:
		_city_solid_box(parent, center + Vector3(-(opening_width + segment) * 0.5, full_height * 0.5, 0.0),
			Vector3(segment, full_height, thickness), material)
		_city_solid_box(parent, center + Vector3((opening_width + segment) * 0.5, full_height * 0.5, 0.0),
			Vector3(segment, full_height, thickness), material)
	var upper_h := full_height - opening_height
	if upper_h > 0.12:
		_city_solid_box(parent, center + Vector3(0.0, opening_height + upper_h * 0.5, 0.0),
			Vector3(opening_width, upper_h, thickness), material)
	# FITUR JENDELA: dinding rendah di bawah bukaan (ambang). Pemain harus LONCAT untuk melewatinya.
	if sill_height > 0.05:
		_city_solid_box(parent, center + Vector3(0.0, sill_height * 0.5, 0.0),
			Vector3(opening_width, sill_height, thickness), material)


func _city_open_wall_z(parent: StaticBody3D, center: Vector3, span: float, thickness: float,
		full_height: float, opening_width: float, opening_height: float, material: Material,
		sill_height: float = 0.0) -> void:
	var segment := (span - opening_width) * 0.5
	if segment > 0.2:
		_city_solid_box(parent, center + Vector3(0.0, full_height * 0.5, -(opening_width + segment) * 0.5),
			Vector3(thickness, full_height, segment), material)
		_city_solid_box(parent, center + Vector3(0.0, full_height * 0.5, (opening_width + segment) * 0.5),
			Vector3(thickness, full_height, segment), material)
	var upper_h := full_height - opening_height
	if upper_h > 0.12:
		_city_solid_box(parent, center + Vector3(0.0, opening_height + upper_h * 0.5, 0.0),
			Vector3(thickness, upper_h, opening_width), material)
	# FITUR JENDELA: dinding rendah di bawah bukaan (ambang). Pemain harus LONCAT untuk melewatinya.
	if sill_height > 0.05:
		_city_solid_box(parent, center + Vector3(0.0, sill_height * 0.5, 0.0),
			Vector3(thickness, sill_height, opening_width), material)


func _city_add_prop_collision(pos: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	if city_prop_collision_root == null:
		city_prop_collision_root = StaticBody3D.new()
		city_prop_collision_root.name = "CityPropCollisions"
		city_prop_collision_root.collision_layer = 1
		city_prop_collision_root.collision_mask = 0
		add_child(city_prop_collision_root)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	collision.rotation = rotation
	city_prop_collision_root.add_child(collision)


func _city_add_tree_collision(pos: Vector3, scale: float) -> void:
	if city_prop_collision_root == null:
		city_prop_collision_root = StaticBody3D.new()
		city_prop_collision_root.name = "CityPropCollisions"
		city_prop_collision_root.collision_layer = 1
		city_prop_collision_root.collision_mask = 0
		add_child(city_prop_collision_root)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25 * scale
	shape.height = 2.1 * scale
	collision.shape = shape
	collision.position = pos + Vector3(0.0, 1.05 * scale, 0.0)
	city_prop_collision_root.add_child(collision)


func _add_residential_building(pos: Vector3, width: float, depth: float, height: float,
		wall_mat: StandardMaterial3D, roof_mat: StandardMaterial3D, levels: int) -> StaticBody3D:
	# Rumah modular dengan detail visual yang dibatch dan collision yang terpisah/rapi.
	var building := StaticBody3D.new()
	building.name = "ResidentialBuilding"
	building.collision_layer = 1
	building.collision_mask = 0
	building.position = pos
	building.set_meta("_is_city_building", true)
	add_child(building)

	var wall_t := 0.34
	var door_w := minf(2.0, width * 0.28)
	var door_h := minf(2.35, height - 0.55)
	var window_w := minf(1.8, depth * 0.24)
	# FITUR JENDELA (v0.0.3.1): jendela punya ambang rendah dan bukaan tinggi supaya bisa dilompati.
	# Hitungan fisika: lompat pemain = JUMP_V 5.6 / GRAVITY 16 -> puncak ~0.98 m. Ambang 0.55 m
	# aman dilewati (sisa 0.43 m), sedangkan kapsul pemain setinggi 1.7 m butuh atap bukaan
	# >= 0.98 + 1.7 = 2.68 m agar kepala tidak membentur -> atap bukaan dibuat 2.8 m.
	var window_sill_h := 0.55
	var window_top := minf(2.8, height - 0.7)
	var window_open_h := window_top - window_sill_h
	var window_mid_y := (window_top + window_sill_h) * 0.5
	var frame_mat := _city_material(Color(0.20, 0.16, 0.13))
	var trim_mat := _city_material(Color(0.56, 0.48, 0.36))
	var door_mat := _city_material(Color(0.24, 0.105, 0.055))
	var glass_mat := _city_material(Color(0.035, 0.075, 0.11))
	var metal_mat := _city_material(Color(0.16, 0.19, 0.21))
	var concrete_mat := _city_material(Color(0.34, 0.33, 0.30))
	var wood_mat := _city_material(Color(0.30, 0.19, 0.12))
	var furniture_mat := _city_material(Color(0.20, 0.22, 0.20))

	# FIX LANTAI BERKEDIP (z-fighting): dulu permukaan atas slab tepat di y=0.0, sama persis dengan
	# permukaan tanah arena (_box lantai: pusat -0.5, tinggi 1.0 -> atas y=0.0), sehingga GPU
	# bergantian menggambar keduanya. Sekarang slab naik 4 cm (atas y=0.04) -> tidak berimpit lagi.
	_city_solid_box(building, Vector3(0.0, -0.03, 0.0), Vector3(width - 0.30, 0.14, depth - 0.30), concrete_mat)
	# Dinding: lubang pintu dan jendela memang kosong, sehingga karakter tidak menabrak bidang transparan.
	_city_open_wall_x(building, Vector3(0.0, 0.0, depth * 0.5), width, wall_t, height, door_w, door_h, wall_mat)
	_city_open_wall_x(building, Vector3(0.0, 0.0, -depth * 0.5), width, wall_t, height, window_w, window_top, wall_mat, window_sill_h)
	for side: float in [-1.0, 1.0]:
		_city_open_wall_z(building, Vector3(side * width * 0.5, 0.0, 0.0), depth, wall_t, height, window_w, window_top, wall_mat, window_sill_h)

	# Fasad detail: lis sudut, lis bawah, lis atas, dan ambang yang tidak menghalangi bukaan.
	for side_x: float in [-1.0, 1.0]:
		for side_z: float in [-1.0, 1.0]:
			_city_mesh(building, Vector3(side_x * (width * 0.5 - 0.10), height * 0.5, side_z * (depth * 0.5 - 0.10)),
				_city_box_mesh(Vector3(0.18, height, 0.18)), trim_mat)
		_city_mesh(building, Vector3(side_x * (width * 0.5 + 0.04), height - 0.16, 0.0),
			_city_box_mesh(Vector3(0.18, 0.22, depth + 0.18)), trim_mat)
	# Lis fondasi dipotong mengikuti bukaan agar ambang tidak menghalangi jalur masuk.
	var front_segment := (width - door_w) * 0.5
	for side: float in [-1.0, 1.0]:
		_city_mesh(building, Vector3(side * (door_w * 0.5 + front_segment * 0.5), 0.12, depth * 0.5 + 0.07),
			_city_box_mesh(Vector3(front_segment, 0.18, 0.14)), concrete_mat)
	var side_segment := (depth - window_w) * 0.5
	for side_x: float in [-1.0, 1.0]:
		for side_z: float in [-1.0, 1.0]:
			_city_mesh(building, Vector3(side_x * (width * 0.5 + 0.04), 0.12,
					side_z * (window_w * 0.5 + side_segment * 0.5)),
				_city_box_mesh(Vector3(0.14, 0.18, side_segment)), concrete_mat)
	_city_mesh(building, Vector3(0.0, height - 0.17, depth * 0.5 + 0.05),
		_city_box_mesh(Vector3(width + 0.15, 0.20, 0.18)), trim_mat)

	# FITUR PINTU RUSAK (v0.0.3.1): pintu kayu berpanel selalu tertutup (tidak lagi membuka otomatis).
	# Pemain harus menembak / menebas pintu sampai hancur (HP pintu di house_door.gd); bot zombie
	# juga merusaknya saat terhalang. Pintu adalah StaticBody3D anak dari rumah (grup "house_door").
	for side: float in [-1.0, 1.0]:
		var jamb_pos := Vector3(side * door_w * 0.5, door_h * 0.5, depth * 0.5 + 0.10)
		_city_mesh(building, jamb_pos, _city_box_mesh(Vector3(0.12, door_h, 0.12)), frame_mat)
		var jamb_collision := CollisionShape3D.new()
		var jamb_shape := BoxShape3D.new()
		jamb_shape.size = Vector3(0.12, door_h, 0.12)
		jamb_collision.shape = jamb_shape
		jamb_collision.position = jamb_pos
		building.add_child(jamb_collision)
	_city_mesh(building, Vector3(0.0, door_h + 0.07, depth * 0.5 + 0.10),
		_city_box_mesh(Vector3(door_w + 0.18, 0.14, 0.12)), frame_mat)
	var door_leaf_w := door_w - 0.10
	var door_leaf_h := door_h * 0.94
	var door_body: StaticBody3D = HouseDoorScript.new()
	door_body.name = "FrontDoor"
	door_body.collision_layer = 1
	door_body.collision_mask = 0
	door_body.position = Vector3(0.0, 0.0, depth * 0.5 + 0.025)
	var door_leaf := MeshInstance3D.new()
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(door_leaf_w, door_leaf_h, 0.12)
	door_leaf.mesh = door_mesh
	door_leaf.material_override = door_mat
	door_leaf.position = Vector3(0.0, door_leaf_h * 0.5, 0.0)
	door_body.add_child(door_leaf)
	var door_collision := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(door_leaf_w, door_leaf_h, 0.12)
	door_collision.shape = door_shape
	door_collision.position = Vector3(0.0, door_leaf_h * 0.5, 0.0)
	door_body.add_child(door_collision)
	# Panel dan pegangan jadi anak pintu: ikut hilang saat pintu hancur.
	var door_detail_tool := SurfaceTool.new()
	door_detail_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	door_detail_tool.append_from(_city_box_mesh(Vector3(door_leaf_w * 0.66, 0.055, 0.025)), 0,
		Transform3D(Basis(), Vector3(0.0, door_h * 0.30, 0.075)))
	door_detail_tool.append_from(_city_box_mesh(Vector3(door_leaf_w * 0.66, 0.055, 0.025)), 0,
		Transform3D(Basis(), Vector3(0.0, door_h * 0.66, 0.075)))
	var door_details := MeshInstance3D.new()
	door_details.mesh = door_detail_tool.commit()
	door_details.material_override = trim_mat
	door_body.add_child(door_details)
	var door_handle := MeshInstance3D.new()
	door_handle.mesh = _city_box_mesh(Vector3(0.055, 0.18, 0.05))
	door_handle.material_override = metal_mat
	door_handle.position = Vector3(door_leaf_w * 0.34, door_h * 0.49, 0.10)
	door_body.add_child(door_handle)
	# Material kayu retak (HP < 50%) dan serpihan papan saat pecah (memakai cache material).
	door_body.set("leaf_mesh", door_leaf)
	door_body.set("weak_material", _city_material(Color(0.13, 0.06, 0.035)))
	door_body.set("plank_material", door_mat)
	building.add_child(door_body)

	# Bingkai jendela: ambang rendah (0.55 m) + bukaan tinggi; pemain melompat untuk melewatinya.
	for side: float in [-1.0, 1.0]:
		var wx: float = side * (width * 0.5 + 0.08)
		for zoff: float in [-window_w * 0.5, window_w * 0.5]:
			var window_jamb_pos := Vector3(wx, window_mid_y, zoff)
			_city_mesh(building, window_jamb_pos,
				_city_box_mesh(Vector3(0.14, window_open_h, 0.14)), glass_mat)
			var window_jamb_collision := CollisionShape3D.new()
			var window_jamb_shape := BoxShape3D.new()
			window_jamb_shape.size = Vector3(0.14, window_open_h, 0.14)
			window_jamb_collision.shape = window_jamb_shape
			window_jamb_collision.position = window_jamb_pos
			building.add_child(window_jamb_collision)
		# Ambang jendela (di atas dinding rendah), lis atas, dan palang atas bukaan.
		_city_mesh(building, Vector3(wx, window_sill_h + 0.02, 0.0), _city_box_mesh(Vector3(0.20, 0.04, window_w + 0.20)), trim_mat)
		_city_mesh(building, Vector3(wx, window_top + 0.05, 0.0), _city_box_mesh(Vector3(0.18, 0.12, window_w + 0.20)), trim_mat)
		_city_mesh(building, Vector3(wx, window_top - 0.08, 0.0), _city_box_mesh(Vector3(0.12, 0.10, window_w)), frame_mat)
	# Ambang + lis atas untuk jendela belakang (dinding z negatif).
	_city_mesh(building, Vector3(0.0, window_sill_h + 0.02, -depth * 0.5 - 0.08), _city_box_mesh(Vector3(window_w + 0.20, 0.04, 0.20)), trim_mat)
	_city_mesh(building, Vector3(0.0, window_top + 0.05, -depth * 0.5 - 0.08), _city_box_mesh(Vector3(window_w + 0.20, 0.12, 0.18)), trim_mat)

	# Jendela lantai atas: kaca gelap berbingkai, panel silang, dan kisi-kisi kecil.
	var upper_y := height * 0.72
	var window_count := 2 if width < 13.0 else 3
	for i in range(window_count):
		var x := (float(i) - float(window_count - 1) * 0.5) * (width / float(window_count + 0.4))
		for face: float in [-1.0, 1.0]:
			var zf: float = face * (depth * 0.5 + 0.19)
			_city_mesh(building, Vector3(x, upper_y, zf), _city_box_mesh(Vector3(1.15, 0.86, 0.10)), glass_mat)
			_city_mesh(building, Vector3(x - 0.62, upper_y, zf + face * 0.07), _city_box_mesh(Vector3(0.10, 1.02, 0.10)), frame_mat)
			_city_mesh(building, Vector3(x + 0.62, upper_y, zf + face * 0.07), _city_box_mesh(Vector3(0.10, 1.02, 0.10)), frame_mat)
			_city_mesh(building, Vector3(x, upper_y - 0.48, zf + face * 0.07), _city_box_mesh(Vector3(1.32, 0.10, 0.10)), frame_mat)
			_city_mesh(building, Vector3(x, upper_y + 0.48, zf + face * 0.07), _city_box_mesh(Vector3(1.32, 0.10, 0.10)), frame_mat)
			_city_mesh(building, Vector3(x, upper_y, zf + face * 0.075), _city_box_mesh(Vector3(0.07, 0.82, 0.06)), trim_mat)

	# Lantai dua dan jalur tangga untuk bangunan bertingkat.
	if levels >= 2:
		var upper_floor_y := height * 0.49
		var stair_width := minf(2.35, width * 0.32)
		var front_z := depth * 0.36
		var back_z := -depth * 0.31
		var run := front_z - back_z
		var rise := upper_floor_y
		var stair_angle := atan2(rise, run)
		var stair_length := sqrt(run * run + rise * rise)
		var stair_x := -width * 0.28
		var floor_t := 0.16
		var floor_mat := _city_material(Color(0.34, 0.31, 0.27))
		# Dua platform sisi + landing belakang: lubang tangga tetap terbuka, karakter tidak menabrak slab.
		var left_edge := -width * 0.5 + 0.18
		var left_end := stair_x - stair_width * 0.5 - 0.18
		if left_end - left_edge > 0.5:
			var left_w := left_end - left_edge
			_city_solid_box(building, Vector3((left_edge + left_end) * 0.5, upper_floor_y - floor_t * 0.5, 0.0),
				Vector3(left_w, floor_t, depth - 0.36), floor_mat)
		var right_start := stair_x + stair_width * 0.5 + 0.18
		var right_edge := width * 0.5 - 0.18
		if right_edge - right_start > 0.5:
			var right_w := right_edge - right_start
			_city_solid_box(building, Vector3((right_start + right_edge) * 0.5, upper_floor_y - floor_t * 0.5, 0.0),
				Vector3(right_w, floor_t, depth - 0.36), floor_mat)
		var rear_min := -depth * 0.5 + 0.18
		var rear_max := back_z - 0.02
		if rear_max - rear_min > 0.5:
			_city_solid_box(building, Vector3(stair_x, upper_floor_y - floor_t * 0.5, (rear_min + rear_max) * 0.5),
				Vector3(stair_width + 0.36, floor_t, rear_max - rear_min), floor_mat)

		# Ramp collision dimulai tepat dari lantai bawah dan berakhir rata dengan lantai dua.
		var ramp_thickness := 0.12
		var ramp_center_y := rise * 0.5 - ramp_thickness * 0.5 * cos(stair_angle)
		var ramp_center_z := (front_z + back_z) * 0.5
		_city_mesh(building, Vector3(stair_x, ramp_center_y, ramp_center_z),
			_city_box_mesh(Vector3(stair_width, ramp_thickness, stair_length)), _city_material(Color(0.27, 0.23, 0.19)),
			Vector3(stair_angle, 0.0, 0.0))
		var ramp_collision := CollisionShape3D.new()
		var ramp_shape := BoxShape3D.new()
		ramp_shape.size = Vector3(stair_width, ramp_thickness, stair_length)
		ramp_collision.shape = ramp_shape
		ramp_collision.position = Vector3(stair_x, ramp_center_y, ramp_center_z)
		ramp_collision.rotation.x = stair_angle
		building.add_child(ramp_collision)
		# Anak tangga visual mengikuti kemiringan ramp; tanpa collider tambahan agar tidak tersangkut.
		var step_count := 10
		var tread_depth := run / float(step_count) + 0.08
		for step_i in range(step_count):
			var f := (float(step_i) + 0.5) / float(step_count)
			var step_z := lerpf(front_z, back_z, f)
			var step_y := upper_floor_y * f + 0.035
			_city_mesh(building, Vector3(stair_x, step_y, step_z),
				_city_box_mesh(Vector3(stair_width + 0.12, 0.07, tread_depth)), _city_material(Color(0.43, 0.35, 0.26)))
		# Pegangan miring sebagai mesh batch dan collision tipis di sisi luar tangga.
		for side: float in [-1.0, 1.0]:
			var rail_pos := Vector3(stair_x + side * (stair_width * 0.5 + 0.10), ramp_center_y + 0.72, ramp_center_z)
			_city_mesh(building, rail_pos, _city_box_mesh(Vector3(0.08, 1.25, stair_length)), frame_mat,
				Vector3(stair_angle, 0.0, 0.0))
			var rail_collision := CollisionShape3D.new()
			var rail_shape := BoxShape3D.new()
			rail_shape.size = Vector3(0.08, 1.20, stair_length)
			rail_collision.shape = rail_shape
			rail_collision.position = rail_pos
			rail_collision.rotation.x = stair_angle
			building.add_child(rail_collision)

	# Atap, lis atap, talang, dan detail ventilasi.
	if levels >= 2:
		_city_mesh(building, Vector3(0.0, height + 0.34, 0.0),
			_city_box_mesh(Vector3(width + 1.0, 0.68, depth + 1.0)), roof_mat)
		for side_x: float in [-1.0, 1.0]:
			_city_mesh(building, Vector3(side_x * (width * 0.5), height + 0.70, 0.0),
				_city_box_mesh(Vector3(0.18, 0.26, depth + 1.0)), frame_mat)
		for side_z: float in [-1.0, 1.0]:
			_city_mesh(building, Vector3(0.0, height + 0.70, side_z * (depth * 0.5)),
				_city_box_mesh(Vector3(width + 1.0, 0.26, 0.18)), frame_mat)
		# Ventilasi atap kecil.
		_city_solid_box(building, Vector3(width * 0.27, height + 0.86, -depth * 0.25),
			Vector3(1.0, 0.30, 0.85), metal_mat)
	else:
		var roof_depth := depth * 0.62
		_city_mesh(building, Vector3(0.0, height + depth * 0.13, -depth * 0.22),
			_city_box_mesh(Vector3(width + 1.0, 0.35, roof_depth)), roof_mat, Vector3(deg_to_rad(27.0), 0.0, 0.0))
		_city_mesh(building, Vector3(0.0, height + depth * 0.13, depth * 0.22),
			_city_box_mesh(Vector3(width + 1.0, 0.35, roof_depth)), roof_mat, Vector3(deg_to_rad(-27.0), 0.0, 0.0))
		_city_mesh(building, Vector3(0.0, height + depth * 0.31, 0.0),
			_city_box_mesh(Vector3(width + 0.55, 0.18, 0.20)), frame_mat)

	# Perabot inti pada sudut kanan: collision penuh, tetapi koridor pintu dan tangga tetap kosong.
	if randf() < 0.58:
		var cabinet_w := minf(1.55, width * 0.18)
		_city_solid_box(building, Vector3(width * 0.31, 0.76, -depth * 0.28),
			Vector3(cabinet_w, 1.52, 0.72), wood_mat)
		_city_mesh(building, Vector3(width * 0.31, 1.18, -depth * 0.28 + 0.38),
			_city_box_mesh(Vector3(cabinet_w * 0.72, 0.07, 0.035)), trim_mat)
	if randf() < 0.36:
		_city_solid_box(building, Vector3(width * 0.30, 0.34, depth * 0.12),
			Vector3(minf(2.0, width * 0.22), 0.68, 0.90), furniture_mat)
		_city_mesh(building, Vector3(width * 0.30, 0.72, depth * 0.12),
			_city_box_mesh(Vector3(minf(2.1, width * 0.23), 0.10, 0.98)), wood_mat)

	# Lampu interior hanya di sebagian rumah, supaya suasana hidup tanpa membebani GPU.
	if randf() < (0.12 if str(cfg.get("city_variant", "night")) == "night" else 0.035):
		var interior_light := OmniLight3D.new()
		interior_light.light_color = Color(1.0, 0.78, 0.48)
		interior_light.light_energy = 0.30
		interior_light.omni_range = 5.5
		interior_light.position = Vector3(width * 0.20, minf(height - 0.45, 3.0), -depth * 0.10)
		building.add_child(interior_light)

	building_bounds.append(Rect2(Vector2(pos.x - width * 0.62, pos.z - depth * 0.62),
		Vector2(width * 1.24, depth * 1.24)))
	return building


func _add_city_tree(pos: Vector3, scale: float = 1.0) -> void:
	# Simpan transform; visual seluruh pepohonan digambar dengan hanya dua MultiMesh.
	city_tree_records.append({"pos": pos, "scale": scale})
	city_blocked_objects.append(pos)
	_city_add_tree_collision(pos, scale)


func _flush_city_tree_multimesh() -> void:
	if city_tree_records.is_empty():
		return
	var trunk_mat := _city_material(Color(0.22, 0.15, 0.10))
	var leaf_mat := _city_material(Color(0.12, 0.22, 0.13))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.1
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.2

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = city_tree_records.size()
	var crown_mm := MultiMesh.new()
	crown_mm.transform_format = MultiMesh.TRANSFORM_3D
	crown_mm.mesh = crown_mesh
	crown_mm.instance_count = city_tree_records.size()
	for i in range(city_tree_records.size()):
		var record: Dictionary = city_tree_records[i]
		var tree_pos: Vector3 = record["pos"]
		var tree_scale: float = float(record["scale"])
		var scaled_basis := Basis().scaled(Vector3.ONE * tree_scale)
		trunk_mm.set_instance_transform(i, Transform3D(scaled_basis, tree_pos + Vector3(0.0, 1.05 * tree_scale, 0.0)))
		crown_mm.set_instance_transform(i, Transform3D(scaled_basis, tree_pos + Vector3(0.0, 2.35 * tree_scale, 0.0)))
	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunk_mm
	trunk_instance.material_override = trunk_mat
	add_child(trunk_instance)
	var crown_instance := MultiMeshInstance3D.new()
	crown_instance.multimesh = crown_mm
	crown_instance.material_override = leaf_mat
	add_child(crown_instance)
	city_tree_records.clear()


func _build_zombie_city() -> void:
	# Visual jalan dan objek kota digabung; collision ditempatkan pada satu StaticBody terpisah.
	set_meta("_city_mesh_batch", {})
	city_spawn_points.clear()
	building_bounds.clear()
	city_material_cache.clear()
	city_tree_records.clear()
	city_blocked_objects.clear()
	city_prop_collision_root = StaticBody3D.new()
	city_prop_collision_root.name = "CityPropCollisions"
	city_prop_collision_root.collision_layer = 1
	city_prop_collision_root.collision_mask = 0
	add_child(city_prop_collision_root)
	var is_morning: bool = str(cfg.get("city_variant", "night")) == "morning"
	var road_lines: Array[float] = [-150.0, -100.0, -50.0, 0.0, 50.0, 100.0, 150.0]
	if is_morning:
		road_lines = [-150.0, -90.0, -30.0, 30.0, 90.0, 150.0]
	var road_width := 10.5 if is_morning else 9.0
	city_road_lines = road_lines.duplicate()
	city_road_w = road_width
	var asphalt_mat := _city_material(Color(0.075, 0.085, 0.095))
	var curb_mat := _city_material(Color(0.40, 0.40, 0.37) if is_morning else Color(0.29, 0.31, 0.34))
	var line_mat := _city_material(Color(0.86, 0.78, 0.48))
	var road_h := _city_box_mesh(Vector3(arena * 2.0 - 8.0, 0.12, road_width))
	var road_v := _city_box_mesh(Vector3(road_width, 0.12, arena * 2.0 - 8.0))
	for lane in road_lines:
		_city_mesh(self, Vector3(0.0, 0.045, lane), road_h, asphalt_mat)
		_city_mesh(self, Vector3(lane, 0.045, 0.0), road_v, asphalt_mat)
		for side: float in [-1.0, 1.0]:
			_city_mesh(self, Vector3(0.0, 0.10, lane + side * (road_width * 0.5 + 1.0)),
				_city_box_mesh(Vector3(arena * 2.0 - 8.0, 0.2, 1.1)), curb_mat)
			_city_mesh(self, Vector3(lane + side * (road_width * 0.5 + 1.0), 0.10, 0.0),
				_city_box_mesh(Vector3(1.1, 0.2, arena * 2.0 - 8.0)), curb_mat)
		for offset in range(-180, 181, 22):
			_city_mesh(self, Vector3(float(offset), 0.115, lane),
				_city_box_mesh(Vector3(5.0, 0.025, 0.28)), line_mat)
			_city_mesh(self, Vector3(lane, 0.115, float(offset)),
				_city_box_mesh(Vector3(0.28, 0.025, 5.0)), line_mat)

	# Distrik pagi memiliki taman kecil di tengah dan blok jalan dengan jarak berbeda.
	if is_morning:
		var grass_mat := _city_material(Color(0.18, 0.31, 0.17))
		_city_mesh(self, Vector3(0.0, 0.055, 0.0), _city_box_mesh(Vector3(23.0, 0.10, 23.0)), grass_mat)
		var path_mat := _city_material(Color(0.55, 0.52, 0.43))
		_city_mesh(self, Vector3(0.0, 0.115, 0.0), _city_box_mesh(Vector3(2.0, 0.06, 23.0)), path_mat)
		_city_mesh(self, Vector3(0.0, 0.115, 0.0), _city_box_mesh(Vector3(23.0, 0.06, 2.0)), path_mat)
		for x: float in [-8.0, 8.0]:
			for z: float in [-8.0, 8.0]:
				_add_city_tree(Vector3(x, 0.0, z), 0.9)

	var wall_colors: Array[Color] = []
	var roof_colors: Array[Color] = []
	if is_morning:
		wall_colors = [Color(0.70, 0.64, 0.51), Color(0.57, 0.62, 0.60), Color(0.67, 0.50, 0.37), Color(0.52, 0.57, 0.48), Color(0.77, 0.72, 0.58)]
		roof_colors = [Color(0.22, 0.24, 0.25), Color(0.34, 0.22, 0.15), Color(0.29, 0.30, 0.27)]
	else:
		wall_colors = [Color(0.43, 0.46, 0.49), Color(0.34, 0.39, 0.43), Color(0.43, 0.39, 0.35), Color(0.32, 0.37, 0.35), Color(0.50, 0.51, 0.49)]
		roof_colors = [Color(0.12, 0.15, 0.19), Color(0.19, 0.16, 0.15), Color(0.21, 0.22, 0.23)]
	var wall_mats: Array[StandardMaterial3D] = []
	var roof_mats: Array[StandardMaterial3D] = []
	for c in wall_colors:
		wall_mats.append(_city_material(c))
	for c in roof_colors:
		roof_mats.append(_city_material(c))
	# Tekstur bata/plester berulang dengan triplanar; detail visual tinggi tanpa tekstur unik per rumah.
	var facade_texture: Texture2D = load("res://assets/brick.png") if is_morning else load("res://assets/concrete.png")
	for facade_mat in wall_mats:
		facade_mat.albedo_texture = facade_texture
		facade_mat.uv1_triplanar = true
		facade_mat.uv1_world_triplanar = true
		facade_mat.uv1_scale = Vector3.ONE * 0.16
	var roof_texture: Texture2D = load("res://assets/concrete.png")
	for roof_mat_item in roof_mats:
		roof_mat_item.albedo_texture = roof_texture
		roof_mat_item.uv1_triplanar = true
		roof_mat_item.uv1_world_triplanar = true
		roof_mat_item.uv1_scale = Vector3.ONE * 0.12

	var block_centers: Array[float] = [-150.0, -100.0, -50.0, 0.0, 50.0, 100.0, 150.0]
	if is_morning:
		block_centers = [-150.0, -90.0, -30.0, 30.0, 90.0, 150.0]
	var landmark_positions: Array[Vector3] = []
	if is_morning:
		landmark_positions = [Vector3(-120.0, 0.0, 120.0), Vector3(120.0, 0.0, -120.0),
			Vector3(-120.0, 0.0, -120.0), Vector3(120.0, 0.0, 120.0), Vector3(0.0, 0.0, 120.0)]
	else:
		landmark_positions = [Vector3(-125.0, 0.0, 125.0), Vector3(125.0, 0.0, -125.0),
			Vector3(-125.0, 0.0, -125.0), Vector3(125.0, 0.0, 125.0), Vector3(0.0, 0.0, 125.0)]

	for bx in block_centers:
		for bz in block_centers:
			# Ruang pusat pada peta pagi disisakan sebagai taman.
			if is_morning and absf(bx) <= 30.0 and absf(bz) <= 30.0:
				continue
			var reserved_for_landmark := false
			for landmark in landmark_positions:
				if absf(bx - landmark.x) < (35.0 if is_morning else 27.0) and absf(bz - landmark.z) < (35.0 if is_morning else 27.0):
					reserved_for_landmark = true
					break
			if reserved_for_landmark:
				continue
			var house_count := 1 if randf() < 0.64 else 2
			if randf() < 0.10:
				house_count = 0
			for index in range(house_count):
				var side_x := -1.0 if index == 0 else 1.0
				var side_z := -1.0 if randf() < 0.5 else 1.0
				var x: float = bx + side_x * randf_range(13.0, 16.0) + randf_range(-2.5, 2.5)
				var z: float = bz + side_z * randf_range(12.0, 15.0) + randf_range(-2.5, 2.5)
				var levels := 2 if randf() < (0.32 if is_morning else 0.42) else 1
				var width := randf_range(8.5, 12.5)
				var depth := randf_range(8.5, 12.0)
				var height := 3.8 if levels == 1 else randf_range(7.3, 8.5)
				_add_residential_building(Vector3(x, 0.0, z), width, depth, height,
					wall_mats.pick_random(), roof_mats.pick_random(), levels)

	# Gedung besar: rumah sakit, pasar, apartemen dan gudang kota.
	for i in range(landmark_positions.size()):
		var landmark: Vector3 = landmark_positions[i]
		var w := 19.0 + float(i % 2) * 3.0
		var d := 17.0 + float((i + 1) % 2) * 2.0
		var h := 10.0 + float(i % 3)
		var landmark_building := _add_residential_building(landmark, w, d, h,
			wall_mats[i % wall_mats.size()], roof_mats[i % roof_mats.size()], 2)
		# Papan fasad sederhana membedakan gedung layanan, pasar, apartemen, dan gudang.
		var sign_colors: Array[Color] = [Color(0.78, 0.80, 0.75), Color(0.72, 0.58, 0.25),
			Color(0.25, 0.40, 0.57), Color(0.52, 0.43, 0.34), Color(0.37, 0.48, 0.39)]
		var sign_mat := _city_material(sign_colors[i % sign_colors.size()])
		_city_mesh(landmark_building, Vector3(0.0, h * 0.78, d * 0.5 + 0.23),
			_city_box_mesh(Vector3(w * 0.58, 0.72, 0.16)), sign_mat)
		if i == 0:
			var cross_mat := _city_material(Color(0.72, 0.16, 0.15))
			_city_mesh(landmark_building, Vector3(0.0, h * 0.78, d * 0.5 + 0.33),
				_city_box_mesh(Vector3(0.72, 0.16, 0.05)), cross_mat)
			_city_mesh(landmark_building, Vector3(0.0, h * 0.78, d * 0.5 + 0.33),
				_city_box_mesh(Vector3(0.16, 0.72, 0.05)), cross_mat)

	# Pohon ditempatkan di halaman/trotoar, bukan di atas bangunan atau jalur jalan.
	var tree_total := 116 if is_morning else 92
	for i in range(tree_total):
		var tree_pos := Vector3(randf_range(-arena + 14.0, arena - 14.0), 0.0,
			randf_range(-arena + 14.0, arena - 14.0))
		var blocked := false
		for lane in road_lines:
			if absf(tree_pos.x - lane) < road_width * 0.5 + 3.0 or absf(tree_pos.z - lane) < road_width * 0.5 + 3.0:
				blocked = true
				break
		if not blocked:
			for rect in building_bounds:
				if rect.has_point(Vector2(tree_pos.x, tree_pos.z)):
					blocked = true
					break
		if not blocked:
			_add_city_tree(tree_pos, randf_range(0.8, 1.3))

	_flush_city_tree_multimesh()

	# Kendaraan ditempatkan di ruas jalan (bukan acak di dalam rumah/pohon), dan punya collision.
	var car_mat := StandardMaterial3D.new()
	car_mat.albedo_texture = load("res://assets/z_car.png")
	car_mat.roughness = 0.9
	var car_total := 24 if is_morning else 20
	var car_mesh := _city_box_mesh(Vector3(4.4, 1.6, 2.2))
	for i in range(car_total):
		var lane: float = road_lines.pick_random()
		var along := randf_range(-arena + 24.0, arena - 24.0)
		var vertical_road := randf() < 0.5
		var car_pos: Vector3
		var car_yaw: float
		var parking_side := -1.0 if randf() < 0.5 else 1.0
		if vertical_road:
			car_pos = Vector3(lane + parking_side * 2.2, 0.8, along)
			car_yaw = PI * 0.5
		else:
			car_pos = Vector3(along, 0.8, lane + parking_side * 2.2)
			car_yaw = 0.0
		_city_mesh(self, car_pos, car_mesh, car_mat, Vector3(0.0, car_yaw, 0.0))
		_city_add_prop_collision(car_pos, Vector3(4.4, 1.6, 2.2), Vector3(0.0, car_yaw, 0.0))
		city_blocked_objects.append(car_pos)

	# Node waypoint menyebar di semua ruas sehingga spawn dan patroli benar-benar acak.
	var offset_limit := int(arena) - 18
	for lane in road_lines:
		for offset in range(-offset_limit, offset_limit + 1, 18):
			var t := float(offset)
			city_spawn_points.append(Vector3(lane + randf_range(-1.2, 1.2), 0.1, t))
			city_spawn_points.append(Vector3(t, 0.1, lane + randf_range(-1.2, 1.2)))
	cfg["waypoints"] = city_spawn_points.duplicate()
	_flush_city_mesh_batch(self)


# ------------------------------------------------------------------ bot & giliran
func _spawn_key(t: String) -> String:
	if t == "human":
		return "blue"
	if t == "zombie":
		return "red"
	return t


func _far(points: Array, nodes: Array) -> Vector3:
	var best: Vector3 = points[0]
	var best_d := -1.0
	for p in points:
		var md := 999.0
		for n in nodes:
			md = minf(md, (n.global_position - p).length())
		md += randf() * 6.0
		if md > best_d:
			best_d = md
			best = p
	return best


func _city_spawn_blocked(point: Vector3) -> bool:
	var position_2d := Vector2(point.x, point.z)
	for obstacle in city_blocked_objects:
		if Vector2(obstacle.x, obstacle.z).distance_to(position_2d) < 5.0:
			return true
	for rect in building_bounds:
		if rect.has_point(position_2d):
			return true
	for block in cfg.get("blocks", []):
		var block_pos: Vector3 = block[0]
		var block_size: Vector3 = block[1]
		if absf(point.x - block_pos.x) < block_size.x * 0.5 + 1.5 and absf(point.z - block_pos.z) < block_size.z * 0.5 + 1.5:
			return true
	return false


func _spawn_point(t: String) -> Vector3:
	if zmode and not city_spawn_points.is_empty():
		var candidates: Array = city_spawn_points.duplicate()
		candidates.shuffle()
		var others: Array = get_tree().get_nodes_in_group("team_human") + get_tree().get_nodes_in_group("team_zombie")
		var fallback: Vector3 = candidates.pick_random()
		for point in candidates:
			if _city_spawn_blocked(point):
				continue
			var safe := true
			for other in others:
				if not is_instance_valid(other) or bool(other.get("dead")):
					continue
				if other.global_position.distance_to(point) < 20.0:
					safe = false
					break
			if safe:
				return point
		return fallback
	var pts: Array = cfg["spawns"][_spawn_key(t)]
	var enemies: Array = get_tree().get_nodes_in_group("team_" + Game.enemy_of(t))
	return _far(pts, enemies)


# ---- mode Pelatihan
func _spawn_bot(t: String) -> void:
	if finished:
		return
	var b = BotScript.new()
	b.team = t
	b.waypoints = cfg["waypoints"]
	b.map_limit = arena - 2.0
	var base: float = float(cfg["skill"])
	b.skill = base + float(maxi(score["red"], score["blue"])) / float(target_score) * 0.4
	add_child(b)
	b.global_position = _spawn_point(t)
	b.died.connect(_on_bot_died)


func _update_score() -> void:
	hud.set_score(score["red"], score["blue"], target_score, kills, deaths)


func _on_bot_died(bot, headshot: bool, by_player: bool) -> void:
	var dead_team: String = bot.team
	var killer_team := Game.enemy_of(dead_team)
	score[killer_team] += 1
	if by_player:
		kills += 1
		player.add_ammo(15)
		if headshot:
			hud.add_feed("HEADSHOT!  musuh tumbang", Color(1.0, 0.85, 0.3))
		else:
			hud.add_feed("Musuh tumbang", Color.WHITE)
	_update_score()
	if score[killer_team] >= target_score:
		_finish(killer_team == my_team)
		return
	await get_tree().create_timer(BOT_RESPAWN).timeout
	if not finished:
		_spawn_bot(dead_team)


# ---- mode Zombie
func _start_zombie() -> void:
	player.infected.connect(_on_player_infected)
	hud.enter_zombie_mode()
	hud.set_map(arena, city_road_lines, city_road_w, building_bounds)
	hud.zombie_chosen.connect(_on_zombie_chosen)
	_begin_round()


func _begin_round() -> void:
	round_over = false
	round_t = 0.0
	samurai_done = false
	time_left = ZOMBIE_ROUND_TIME
	infect_token += 1
	hud.hide_infect_choice()
	hud.stop_round_result()
	hud.set_round_info(round_no, ROUNDS_TO_WIN, pts_human, pts_zombie)
	for i in ZOMBIE_TOTAL - 2:
		_spawn_zbot("human", "")
	# Induk Zombie muncul setelah hitung mundur "Virus biokimia setelah N detik menyebar"
	induk_spawned = false
	virus_left = VIRUS_DELAY
	first_blood = false
	hud.set_virus(int(VIRUS_DELAY))
	hud.show_center("RONDE %d  -  BERTAHAN %d DETIK" % [round_no, int(ZOMBIE_ROUND_TIME)], 4.0)
	_update_zombie_hud()
	_play_music("music_zombie", -9.0)


func _spawn_induk() -> void:
	induk_spawned = true
	hud.set_virus(0)
	_spawn_zbot("zombie", "induk")
	hud.add_feed("Induk Zombie muncul!", Color(0.7, 0.95, 0.3))
	Fx.sfx2d(self, Fx.SFX + "z_roar.wav", 0.0, 1.0)   # raungan Induk Zombie


# musik latar berulang (mode Zombie: gelap & tegang; fase Samurai: taiko & shakuhachi)
func _play_music(track: String, vol: float) -> void:
	var st = load("res://assets/sfx/%s.wav" % track)
	if st == null:
		return
	if music == null:
		music = AudioStreamPlayer.new()
		add_child(music)
		music.finished.connect(func(): music.play())   # cadangan kalau loop bawaan tidak aktif
	if st is AudioStreamWAV:
		st = st.duplicate()
		var bytes := 2 if st.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var chans := 2 if st.stereo else 1
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.data.size() / (bytes * chans))
	music.stream = st
	music.volume_db = vol
	music.play()


func _spawn_zbot(r: String, zt: String) -> void:
	if finished:
		return
	var b = BotScript.new()
	b.zmode = true
	b.role = r
	b.ztype = zt
	b.team = "zombie" if r == "zombie" else "human"
	b.waypoints = cfg["waypoints"]
	b.map_limit = arena - 12.0
	b.skill = float(cfg["skill"])
	b.dmg_mult = ZOMBIE_WEAPON_MULT
	b.uname = ZNAMES.pick_random()
	if r == "human":
		if randf() < 0.3:
			b.htype = "hero"
			b.hskin = "hero"
		else:
			b.htype = "civil"
			b.hskin = ["civil", "civil2", "civil3"].pick_random()
	add_child(b)
	b.global_position = _spawn_point(b.team)
	b.died.connect(_on_zbot_died)
	b.converted.connect(_on_converted)


func _count_humans() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("team_human"):
		if is_instance_valid(h) and not bool(h.get("dead")):
			n += 1
	return n


func _count_zombies() -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group("team_zombie"):
		if is_instance_valid(z) and not bool(z.get("dead")):
			n += 1
	return n


func _update_zombie_hud() -> void:
	hud.set_zombie_info(_count_humans(), _count_zombies(), time_left, player.role, kills, deaths)


func _process(delta: float) -> void:
	if not zmode or finished or round_over:
		return
	round_t += delta
	time_left = maxf(time_left - delta, 0.0)
	if not induk_spawned:
		virus_left -= delta
		hud.set_virus(int(ceil(maxf(virus_left, 0.0))))
		if virus_left <= 0.0:
			_spawn_induk()
	hud_tick -= delta
	if hud_tick > 0.0:
		return
	hud_tick = 0.25
	var humans := _count_humans()
	_update_zombie_hud()
	if humans <= 0:
		_end_round(false, "Semua manusia terinfeksi")
		return
	if induk_spawned and round_t > VIRUS_DELAY + 1.5 and _count_zombies() <= 0:
		_end_round(true, "Semua zombie dimusnahkan")
		return
	if time_left <= 0.0:
		_end_round(true, "Manusia bertahan sampai waktu habis")
		return
	if not samurai_done and humans <= 2:
		samurai_done = true
		for h in get_tree().get_nodes_in_group("team_human"):
			if not is_instance_valid(h) or bool(h.get("dead")):
				continue
			if h == player:
				if player.pending:
					continue
				player.apply_role("samurai")
			else:
				h.set_role("samurai")
		hud.show_center("MANUSIA TERAKHIR JADI SAMURAI!", 3.5)
		_play_music("music_samurai", -7.0)
		hud.add_feed("Samurai HP %d" % player.SAMURAI_HP, Color(1.0, 0.82, 0.45))


func _nearest_zombie_name(pos: Vector3, skip) -> String:
	var best := "Induk Zombie"
	var bd := 1e9
	for z in get_tree().get_nodes_in_group("team_zombie"):
		if not is_instance_valid(z) or z == skip or str(z.get("uname")) == "":
			continue
		var d: float = z.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = str(z.get("uname"))
	return best


func _first_blood(name_: String) -> void:
	if first_blood:
		return
	first_blood = true
	hud.add_feed("%s mendapat darah pertama!" % name_, Color(1.0, 0.85, 0.2))


func _on_converted(_bot, by_player: bool) -> void:
	if by_player:
		kills += 1
	_first_blood("Kamu" if by_player else _nearest_zombie_name(_bot.global_position, _bot))
	hud.add_feed("Manusia berubah jadi zombie", Color(0.7, 0.95, 0.3))
	_update_zombie_hud()


func _on_zbot_died(bot, headshot: bool, by_player: bool) -> void:
	if by_player:
		kills += 1
		hud.add_feed("HEADSHOT!  zombie tumbang" if headshot else "Zombie tumbang", Color(1.0, 0.85, 0.3) if headshot else Color.WHITE)
	_update_zombie_hud()   # zombie yang mati TIDAK muncul lagi


func _on_player_infected() -> void:
	deaths += 1
	infect_token += 1
	var tok := infect_token
	hud.show_infect_choice()
	_first_blood(_nearest_zombie_name(player.global_position, null))
	hud.add_feed("Kamu terinfeksi! Pilih jenis zombie", Color(0.7, 0.95, 0.3))
	await get_tree().create_timer(INFECT_AUTO).timeout
	if tok == infect_token and player.pending:
		_on_zombie_chosen("biasa")


func _on_zombie_chosen(zt: String) -> void:
	if not player.pending:
		return
	infect_token += 1
	player.apply_role("zombie", zt)
	hud.hide_infect_choice()
	if not player.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_zombie_hud()


func _on_player_died() -> void:
	deaths += 1
	if zmode:
		# tumbang = gugur sampai ronde berikutnya (tidak respawn)
		hud.add_feed("Kamu tumbang!", Color(1.0, 0.4, 0.4))
		_update_zombie_hud()
		hud.show_center("KAMU TUMBANG\nMenunggu ronde berikutnya")
		return
	score[enemy_team] += 1
	_update_score()
	hud.add_feed("Kamu tertembak!", Color(1.0, 0.4, 0.4))
	if score[enemy_team] >= target_score:
		_finish(false)
		return
	for i in range(3, 0, -1):
		hud.show_center("RESPAWN  %d" % i)
		await get_tree().create_timer(1.0).timeout
		if finished:
			return
	hud.show_center("")
	player.respawn(_spawn_point(my_team))
	if not player.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---- ronde mode Zombie
func _end_round(humans_win: bool, reason: String) -> void:
	if round_over or finished:
		return
	round_over = true
	if humans_win:
		pts_human += 1
	else:
		pts_zombie += 1
	hud.set_round_info(round_no, ROUNDS_TO_WIN, pts_human, pts_zombie)
	hud.hide_infect_choice()
	# bekukan semua karakter selama animasi
	for c in get_children():
		if c.get_script() == BotScript:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if humans_win:
		Fx.sfx2d(self, "res://assets/sfx/win.wav", -2.0)
	else:
		Fx.sfx2d(self, Fx.SFX + "z_roar.wav", 0.0, 0.9)
		Fx.sfx2d(self, "res://assets/sfx/lose.wav", -4.0)
	hud.play_round_result(humans_win, reason, round_no, pts_human, pts_zombie, ROUND_RESULT_TIME)
	await get_tree().create_timer(ROUND_RESULT_TIME).timeout
	if finished:
		return
	if pts_human >= ROUNDS_TO_WIN or pts_zombie >= ROUNDS_TO_WIN:
		hud.stop_round_result()
		_finish_zombie(pts_human > pts_zombie)
	else:
		_next_round()


func _next_round() -> void:
	round_no += 1
	hud.stop_round_result()
	for c in get_children():
		if c.get_script() == BotScript:
			c.queue_free()
	await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.apply_role("human")
	player.respawn(_spawn_point("human"))
	hud.show_center("")
	if not player.is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_begin_round()
	_play_music("music_zombie", -9.0)


func _finish_zombie(humans_win: bool) -> void:
	if finished:
		return
	var txt := "MANUSIA MENANG" if humans_win else "ZOMBIE MENANG"
	_end_match(humans_win, "%s   %d : %d        Kill: %d     Mati: %d" % [txt, pts_human, pts_zombie, kills, deaths])


func _finish(win: bool) -> void:
	_end_match(win, "MERAH %d  :  %d BIRU        Kill: %d     Mati: %d" % [score["red"], score["blue"], kills, deaths])


func _end_match(win: bool, stats: String) -> void:
	if finished:
		return
	finished = true
	infect_token += 1
	var rc: int = cfg["win_coins"] if win else cfg["lose_coins"]
	var rd: int = cfg["win_diamonds"] if win else cfg["lose_diamonds"]
	Game.add_coins(rc)
	Game.add_diamonds(rd)
	if win:
		Game.record_win(Game.stage)
	Game.save_game()
	hud.show_center("")
	hud.hide_infect_choice()
	hud.show_result(win, stats, rc, rd)
	get_tree().paused = true


func _restart() -> void:
	Game.save_game()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	Game.save_game()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://lobby.tscn")
