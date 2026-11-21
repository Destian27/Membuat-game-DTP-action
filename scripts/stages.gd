extends RefCounted
# Data stage Crisis Action DTP (v0.0.2). File ini dibuat otomatis dari generator;
# kalau mau tambah stage 3/4/5 (v0.0.3), salin salah satu fungsi _stageN() dan ubah isinya,
# lalu daftarkan di get_stage() dan naikkan Game.MAX_STAGE_OPEN.

const ZOMBIE_STAGE := 101   # Kota Mati malam
const ZOMBIE_MORNING_STAGE := 102   # Distrik Pagi

static func get_stage(id: int) -> Dictionary:
	match id:
		1:
			return _stage1()
		2:
			return _stage2()
		101:
			return _stage_zombie()
		102:
			return _stage_zombie_morning()
	return {}


# Peta Zombie: dua area kota luas dengan waktu dan tata kota berbeda.
static func _stage_zombie() -> Dictionary:
	var lamps: Array[Vector2] = []
	for p in [-150.0, -75.0, 0.0, 75.0, 150.0]:
		lamps.append(Vector2(p, -144.0))
		lamps.append(Vector2(p, 144.0))
	for p in [-100.0, 0.0, 100.0]:
		lamps.append(Vector2(-144.0, p))
		lamps.append(Vector2(144.0, p))
	return {
		"id": 101,
		"name": "Kota Mati - Malam",
		"city_variant": "night",
		"arena": 200,
		"floor": "asphalt", "wall": "wall_night", "sky": "sky_night",
		"ambient_src": "color", "ambient_color": Color(0.25, 0.29, 0.40), "ambient_energy": 0.82,
		"sun_color": Color(0.58, 0.68, 0.94), "sun_energy": 0.20,
		"fog": true, "fog_color": Color(0.10, 0.13, 0.20), "fog_density": 0.0016,
		"lamp_color": Color(1.0, 0.82, 0.58),
		"target": 0, "team_size": 7, "skill": 1.15,
		"win_coins": 120, "win_diamonds": 12, "lose_coins": 25, "lose_diamonds": 1,
		"lamps": lamps,
		"blocks": [],
		"spawns": {"red": [Vector3(0, 0.1, -180)], "blue": [Vector3(0, 0.1, 180)]},
		"waypoints": [],
		"coins": [], "diamonds": [],
	}


static func _stage_zombie_morning() -> Dictionary:
	return {
		"id": 102,
		"name": "Distrik Pagi",
		"city_variant": "morning",
		"arena": 200,
		"floor": "asphalt", "wall": "concrete", "sky": "sky",
		"ambient_src": "sky", "ambient_color": Color(0.62, 0.68, 0.78), "ambient_energy": 0.95,
		"sun_color": Color(1.0, 0.94, 0.82), "sun_energy": 1.05,
		"fog": false,
		"target": 0, "team_size": 7, "skill": 1.15,
		"win_coins": 120, "win_diamonds": 12, "lose_coins": 25, "lose_diamonds": 1,
		"lamp_color": Color(1.0, 0.90, 0.72),
		"lamps": [],
		"blocks": [],
		"spawns": {"red": [Vector3(0, 0.1, -180)], "blue": [Vector3(0, 0.1, 180)]},
		"waypoints": [],
		"coins": [], "diamonds": [],
	}


static func _stage1() -> Dictionary:
	return {
		"id": 1,
		"name": "Gudang Siang",
		"arena": 24,
		"floor": "floor", "wall": "brick", "sky": "sky",
		"ambient_src": "sky", "ambient_color": Color(0.5, 0.55, 0.7), "ambient_energy": 0.9,
		"sun_color": Color(1, 1, 1), "sun_energy": 1.1,
		"fog": false,
		"target": 20, "team_size": 4, "skill": 1,
		"win_coins": 50, "win_diamonds": 5, "lose_coins": 10, "lose_diamonds": 0,
		"lamps": [],
		"blocks": [
			[Vector3(-9, 0, -6), Vector3(8, 3, 0.8), "concrete", true, 0.25],
			[Vector3(9, 0, 6), Vector3(8, 3, 0.8), "concrete", true, 0.25],
			[Vector3(0, 0, -14), Vector3(0.8, 3, 8), "concrete", true, 0.25],
			[Vector3(0, 0, 14), Vector3(0.8, 3, 8), "concrete", true, 0.25],
			[Vector3(-16, 0, 8), Vector3(6, 3, 0.8), "concrete", true, 0.25],
			[Vector3(16, 0, -8), Vector3(6, 3, 0.8), "concrete", true, 0.25],
			[Vector3(-3, 0, 3), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(-3, 0, 5), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(3, 0, -3), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(4.8, 0, -3.4), Vector3(1.5, 1.5, 1.5), "crate", false, 0.25],
			[Vector3(-4, 0, -2), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(12, 0, 12), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(-12, 0, -12), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(-12, 0, 13), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(13, 0, -14), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(6, 0, 18), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(-6, 0, -18), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(18, 0, 0), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(-18, 0, 0), Vector3(2, 2, 2), "crate", false, 0.25],
			[Vector3(0, 0, 0), Vector3(3, 3, 3), "crate", false, 0.25],
		],
		"spawns": {
			"red": [Vector3(-20, 0.1, -21), Vector3(-12, 0.1, -21), Vector3(-4, 0.1, -21), Vector3(4, 0.1, -21), Vector3(12, 0.1, -21), Vector3(20, 0.1, -21)],
			"blue": [Vector3(-20, 0.1, 21), Vector3(-12, 0.1, 21), Vector3(-4, 0.1, 21), Vector3(4, 0.1, 21), Vector3(12, 0.1, 21), Vector3(20, 0.1, 21)],
		},
		"waypoints": [Vector3(-20, 0, -20), Vector3(-10, 0, -12), Vector3(10, 0, -12), Vector3(20, 0, -14), Vector3(-10, 0, -2), Vector3(10, 0, 2), Vector3(6, 0, 0), Vector3(-6, 0, 0), Vector3(0, 0, -6), Vector3(0, 0, 6), Vector3(-14, 0, 14), Vector3(14, 0, 14), Vector3(-18, 0, -8), Vector3(18, 0, 8), Vector3(-8, 0, 10), Vector3(8, 0, -10), Vector3(20, 0, 20), Vector3(-20, 0, 20)],
		"coins": [Vector2(-8, -9), Vector2(8, 9), Vector2(-14, 4), Vector2(14, -4), Vector2(-20, -6), Vector2(20, 6), Vector2(-6, 10), Vector2(6, -10), Vector2(-2, -7), Vector2(2, 7), Vector2(-22, 12), Vector2(22, -12)],
		"diamonds": [Vector2(-9, -2), Vector2(9, 2), Vector2(0, -7.5), Vector2(0, 7.5)],
	}


static func _stage2() -> Dictionary:
	return {
		"id": 2,
		"name": "Kota Malam",
		"arena": 26,
		"floor": "asphalt", "wall": "wall_night", "sky": "sky_night",
		"ambient_src": "color", "ambient_color": Color(0.36, 0.42, 0.66), "ambient_energy": 0.9,
		"sun_color": Color(0.55, 0.64, 1), "sun_energy": 0.5,
		"fog": true,
		"target": 30, "team_size": 5, "skill": 1.25,
		"win_coins": 90, "win_diamonds": 10, "lose_coins": 20, "lose_diamonds": 1,
		"lamps": [Vector2(-18, -12), Vector2(18, 12), Vector2(-17, 16), Vector2(17, -16)],
		"blocks": [
			[Vector3(-10, 0, -5), Vector3(7, 2.6, 2.4), "container", true, 0.4],
			[Vector3(10, 0, 5), Vector3(7, 2.6, 2.4), "container", true, 0.4],
			[Vector3(-12, 0, 12), Vector3(2.4, 2.6, 7), "container", true, 0.4],
			[Vector3(12, 0, -12), Vector3(2.4, 2.6, 7), "container", true, 0.4],
			[Vector3(0, 0, 0), Vector3(2.4, 2.6, 6), "container", true, 0.4],
			[Vector3(-21, 0, -9), Vector3(2.4, 2.6, 6), "container", true, 0.4],
			[Vector3(21, 0, 9), Vector3(2.4, 2.6, 6), "container", true, 0.4],
			[Vector3(0, 0, -16), Vector3(6, 2.6, 2.4), "container", true, 0.4],
			[Vector3(0, 0, 16), Vector3(6, 2.6, 2.4), "container", true, 0.4],
			[Vector3(-5, 0, -11), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(5, 0, 11), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(16, 0, -19), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(-16, 0, 19), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(-23, 0, 3), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(23, 0, -3), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(-6, 0, 5), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(6, 0, -5), Vector3(1.8, 1.8, 1.8), "container", true, 0.5],
			[Vector3(-17, 0, 1), Vector3(0.8, 1.3, 5), "concrete_dark", true, 0.25],
			[Vector3(17, 0, -1), Vector3(0.8, 1.3, 5), "concrete_dark", true, 0.25],
			[Vector3(-4, 0, 10), Vector3(4, 1.3, 0.8), "concrete_dark", true, 0.25],
			[Vector3(4, 0, -10), Vector3(4, 1.3, 0.8), "concrete_dark", true, 0.25],
			[Vector3(-18, 0, -12), Vector3(0.3, 4.4, 0.3), "concrete_dark", true, 0.25],
			[Vector3(18, 0, 12), Vector3(0.3, 4.4, 0.3), "concrete_dark", true, 0.25],
			[Vector3(-17, 0, 16), Vector3(0.3, 4.4, 0.3), "concrete_dark", true, 0.25],
			[Vector3(17, 0, -16), Vector3(0.3, 4.4, 0.3), "concrete_dark", true, 0.25],
		],
		"spawns": {
			"red": [Vector3(-20, 0.1, -23), Vector3(-12, 0.1, -23), Vector3(-5, 0.1, -23), Vector3(5, 0.1, -23), Vector3(12, 0.1, -23), Vector3(20, 0.1, -23)],
			"blue": [Vector3(-20, 0.1, 23), Vector3(-12, 0.1, 23), Vector3(-5, 0.1, 23), Vector3(5, 0.1, 23), Vector3(12, 0.1, 23), Vector3(20, 0.1, 23)],
		},
		"waypoints": [Vector3(-20, 0, -18), Vector3(20, 0, -18), Vector3(-8, 0, -15), Vector3(8, 0, -15), Vector3(-16, 0, -6), Vector3(16, 0, 6), Vector3(-8, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, -8), Vector3(0, 0, 8), Vector3(-16, 0, 8), Vector3(16, 0, -8), Vector3(-8, 0, 18), Vector3(8, 0, -18), Vector3(-22, 0, 20), Vector3(22, 0, -20), Vector3(-20, 0, 14), Vector3(20, 0, -14), Vector3(-4, 0, -6), Vector3(4, 0, 6), Vector3(-20, 0, 22), Vector3(20, 0, 22)],
		"coins": [Vector2(-8, -9), Vector2(8, 9), Vector2(-15, -2), Vector2(15, 2), Vector2(-22, -16), Vector2(22, 16), Vector2(-8, 14), Vector2(8, -14), Vector2(-2, -8), Vector2(2, 8), Vector2(-23, 9), Vector2(23, -9), Vector2(-4, -13.2), Vector2(4, 13.2)],
		"diamonds": [Vector2(-9, 3), Vector2(9, -3), Vector2(0, -10), Vector2(0, 10)],
	}
