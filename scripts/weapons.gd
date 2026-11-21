extends RefCounted
# Data senjata v0.0.2.5. 3 slot: 0 = senjata utama, 1 = pistol, 2 = pisau.
# Tiap slot punya beberapa pilihan senjata (daftar ALL). Yang dipakai di battle = yang dipasang (Game.equipped),
# lengkap dengan bonus level enhance. Mau ubah damage / peluru / harga? Edit angka di ALL.

const SLOT_NAMES := ["SENJATA UTAMA", "PISTOL", "PISAU"]
const SLOT_SHORT := ["RIFLE", "PISTOL", "PISAU"]
const MAX_LV := 8
const DMG_PER_LV := 0.05      # +5% damage per level enhance
const SPREAD_PER_LV := 0.04   # -4% sebaran peluru per level (akurasi naik)
const RECOIL_PER_LV := 0.05   # -5% recoil per level (stabilitas naik)
const ENHANCE_BASE := 400     # biaya enhance = ENHANCE_BASE x (level sekarang + 1) koin

const ALL := [
	{
		"id": "rifle", "slot": 0, "name": "AK DTP", "short": "RIFLE",
		"desc": "Senapan serbu klasik. Seimbang untuk semua jarak.",
		"fp": "weapon.png", "icon": "icon_rifle.png",
		"melee": false, "auto": true, "mag": 30, "reserve": 120,
		"delay": 0.1, "reload": 1.7, "dmg": 22,
		"spread": 0.004, "recoil": 0.012, "range": 120.0,
		"acc": 71, "stab": 66, "mob": 34,
		"muzzle": Vector2(0.011, 0.038),
		"sfx": "res://assets/sfx/shot.wav", "sfx_pitch": 1.0, "price": 0,
	},
	{
		"id": "m4a1", "slot": 0, "name": "M4A1 ELANG", "short": "M4A1",
		"desc": "BARU. Laju tembak tinggi, recoil rendah, ada optik.",
		"fp": "m4a1_fp.png", "icon": "icon_m4a1.png",
		"melee": false, "auto": true, "mag": 30, "reserve": 150,
		"delay": 0.085, "reload": 1.6, "dmg": 20,
		"spread": 0.0035, "recoil": 0.009, "range": 130.0,
		"acc": 78, "stab": 80, "mob": 40,
		"muzzle": Vector2(0.018, 0.044),
		"sfx": "res://assets/sfx/shot.wav", "sfx_pitch": 1.12, "price": 3000,
	},
	{
		"id": "pistol", "slot": 1, "name": "PISTOL", "short": "PISTOL",
		"desc": "Pistol standar, ringan dan cepat dikeluarkan.",
		"fp": "pistol_fp.png", "icon": "icon_pistol.png",
		"melee": false, "auto": false, "mag": 12, "reserve": 60,
		"delay": 0.2, "reload": 1.2, "dmg": 30,
		"spread": 0.003, "recoil": 0.02, "range": 90.0,
		"acc": 74, "stab": 60, "mob": 58,
		"muzzle": Vector2(0.27, 0.19),
		"sfx": "res://assets/sfx/shot.wav", "sfx_pitch": 1.35, "price": 0,
	},
	{
		"id": "deagle", "slot": 1, "name": "DESERT EAGLE", "short": "DEAGLE",
		"desc": "BARU. Satu tembakan keras, peluru sedikit.",
		"fp": "deagle_fp.png", "icon": "icon_deagle.png",
		"melee": false, "auto": false, "mag": 7, "reserve": 49,
		"delay": 0.35, "reload": 1.4, "dmg": 55,
		"spread": 0.003, "recoil": 0.04, "range": 100.0,
		"acc": 70, "stab": 42, "mob": 52,
		"muzzle": Vector2(0.283, 0.201),
		"sfx": "res://assets/sfx/deagle.wav", "sfx_pitch": 1.0, "price": 2500,
	},
	{
		"id": "knife", "slot": 2, "name": "PISAU", "short": "KNIFE",
		"desc": "Pisau tempur standar. Tanpa peluru.",
		"fp": "knife_fp.png", "icon": "icon_knife.png",
		"melee": true, "auto": true, "mag": 0, "reserve": 0,
		"delay": 0.55, "reload": 0.0, "dmg": 60,
		"spread": 0.0, "recoil": 0.0, "range": 2.4,
		"acc": 0, "stab": 0, "mob": 90,
		"muzzle": Vector2(0.0, 0.0),
		"sfx": "res://assets/sfx/hit.wav", "sfx_pitch": 1.6, "price": 0,
	},
	{
		"id": "karambit", "slot": 2, "name": "KARAMBIT", "short": "KARAMBIT",
		"desc": "BARU. Tebasan cepat dan damage besar.",
		"fp": "karambit_fp.png", "icon": "icon_karambit.png",
		"melee": true, "auto": true, "mag": 0, "reserve": 0,
		"delay": 0.45, "reload": 0.0, "dmg": 85,
		"spread": 0.0, "recoil": 0.0, "range": 2.4,
		"acc": 0, "stab": 0, "mob": 96,
		"muzzle": Vector2(0.0, 0.0),
		"sfx": "res://assets/sfx/s_swing.wav", "sfx_pitch": 1.5, "price": 2000,
	},
]

# baris statistik yang ditampilkan di layar Enhance / Perlengkapan: [kunci, nama]
const ROWS_GUN := [["dmg", "DAMAGE"], ["rate", "KECEPATAN"], ["acc", "AKURASI"], ["stab", "STABILITAS"],
		["mob", "MOBILITAS"], ["range", "JANGKAUAN"], ["mag", "MAGASIN"], ["reload", "RELOAD"]]
const ROWS_MELEE := [["dmg", "DAMAGE"], ["rate", "KECEPATAN"], ["mob", "MOBILITAS"], ["range", "JANGKAUAN"]]


static func base_by_id(id: String) -> Dictionary:
	for d in ALL:
		if str(d["id"]) == id:
			return d
	return ALL[0]


static func ids_of_slot(slot: int) -> Array:
	var out: Array = []
	for d in ALL:
		if int(d["slot"]) == slot:
			out.append(str(d["id"]))
	return out


# salinan data senjata dengan bonus level enhance (dipakai di battle)
static func with_level(base: Dictionary, lv: int) -> Dictionary:
	var d: Dictionary = base.duplicate()
	var l: int = clampi(lv, 0, MAX_LV)
	d["lv"] = l
	d["dmg"] = int(round(float(base["dmg"]) * (1.0 + DMG_PER_LV * l)))
	d["spread"] = float(base["spread"]) * (1.0 - SPREAD_PER_LV * l)
	d["recoil"] = float(base["recoil"]) * (1.0 - RECOIL_PER_LV * l)
	return d


static func get_by_id(id: String) -> Dictionary:
	return with_level(base_by_id(id), Game.weapon_level(id))


# senjata yang sedang dipasang di slot i (0..2)
static func get_weapon(i: int) -> Dictionary:
	return get_by_id(Game.equipped_id(clampi(i, 0, 2)))


static func enhance_cost(lv: int) -> int:
	return ENHANCE_BASE * (lv + 1)


# nilai statistik (angka) untuk level tertentu
static func stat_value(base: Dictionary, lv: int, key: String) -> float:
	var l: int = clampi(lv, 0, MAX_LV)
	match key:
		"dmg":
			return float(int(round(float(base["dmg"]) * (1.0 + DMG_PER_LV * l))))
		"rate":
			return float(int(round(8.0 / float(base["delay"]))))
		"acc":
			return float(mini(100, int(base["acc"]) + l))
		"stab":
			return float(mini(100, int(base["stab"]) + l))
		"mob":
			return float(base["mob"])
		"range":
			return float(base["range"])
		"mag":
			return float(base["mag"])
		"reload":
			return float(base["reload"])
	return 0.0


static func stat_text(base: Dictionary, key: String, v: float) -> String:
	match key:
		"range":
			return "%.1f m" % v if bool(base["melee"]) else "%d m" % int(v)
		"reload":
			return "%.1f s" % v
	return str(int(v))


# [nama, teks sekarang, teks setelah naik level, berubah?]
static func stat_rows(base: Dictionary, lv: int) -> Array:
	var rows: Array = []
	var src: Array = ROWS_MELEE if bool(base["melee"]) else ROWS_GUN
	var nxt: int = mini(lv + 1, MAX_LV)
	for r in src:
		var k: String = str(r[0])
		var a: float = stat_value(base, lv, k)
		var b: float = stat_value(base, nxt, k)
		rows.append([str(r[1]), stat_text(base, k, a), stat_text(base, k, b), b != a])
	return rows
