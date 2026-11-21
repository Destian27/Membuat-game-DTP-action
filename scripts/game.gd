extends Node
# Autoload "Game": data global (koin, diamond, tim, stage), simpan/muat progres.

signal currency_changed

var Weapons = load("res://scripts/weapons.gd")   # load (bukan preload) agar tidak saling-mengunci dengan weapons.gd yang memakai Game
const VERSION := "v0.0.3.2"
const SAVE_PATH := "user://crisis_action_save.json"
const STAGE_COUNT := 5
# Stage yang sudah terbuka. v0.0.2 = Stage 1 & 2. Di v0.0.3 ganti jadi 5.
const MAX_STAGE_OPEN := 2
const UNLOCK_VERSION := "v0.0.3"

const STAGE_INFO := [
	{"id": 1, "name": "Gudang Siang", "thumb": "stage1.png"},
	{"id": 2, "name": "Kota Malam", "thumb": "stage2.png"},
	{"id": 3, "name": "???", "thumb": "stage_locked.png"},
	{"id": 4, "name": "???", "thumb": "stage_locked.png"},
	{"id": 5, "name": "???", "thumb": "stage_locked.png"},
]

var coins := 0
var diamonds := 0
var team := "red"   # "red" atau "blue"
var stage := 1
var zombie_map := "night"   # "night" atau "morning"
var wins := {}      # "1": jumlah menang
var aim_assist := true   # diatur di lobi (Aim Assist OFF/ON)
var player_name := "Uptodown"
var focus_weapon := ""   # id senjata yang dibuka di layar Enhance (tidak disimpan)
var hint_done := false   # petunjuk "pilih latihan" di layar mode
var owned: Array = ["rifle", "pistol", "knife"]       # senjata yang dimiliki
var equipped: Array = ["rifle", "pistol", "knife"]   # senjata terpasang per slot (utama, pistol, pisau)
var wlevels := {}        # id senjata -> level enhance
var mode := "training"   # "training" (Pelatihan, lawan bot) atau "zombie"; "classic" (online) belum hadir

const MODES := ["training", "zombie", "classic"]
const MODE_NAMES := {"training": "PELATIHAN", "zombie": "ZOMBIE", "classic": "CLASSIC"}


func _ready() -> void:
	load_game()


func player_level() -> int:
	var n := 0
	for k in wins:
		n += int(wins[k])
	return 1 + n / 3


func has_weapon(id: String) -> bool:
	return owned.has(id)


func weapon_level(id: String) -> int:
	return clampi(int(wlevels.get(id, 0)), 0, 8)


func equipped_id(slot: int) -> String:
	if slot < 0 or slot >= equipped.size():
		return ""
	return str(equipped[slot])


# beli senjata dengan koin; true kalau berhasil
func buy_weapon(id: String) -> bool:
	var d: Dictionary = Weapons.base_by_id(id)
	var price := int(d["price"])
	if owned.has(id) or coins < price:
		return false
	coins -= price
	owned.append(id)
	currency_changed.emit()
	save_game()
	return true


# pasang senjata ke slot-nya
func equip_weapon(id: String) -> bool:
	if not owned.has(id):
		return false
	var d: Dictionary = Weapons.base_by_id(id)
	equipped[int(d["slot"])] = id
	save_game()
	return true


# naikkan level enhance 1x; true kalau berhasil
func enhance_weapon(id: String) -> bool:
	if not owned.has(id):
		return false
	var lv := weapon_level(id)
	var cost: int = Weapons.enhance_cost(lv)
	if lv >= Weapons.MAX_LV or coins < cost:
		return false
	coins -= cost
	wlevels[id] = lv + 1
	currency_changed.emit()
	save_game()
	return true


func is_stage_open(id: int) -> bool:
	return id >= 1 and id <= MAX_STAGE_OPEN


func enemy_of(t: String) -> String:
	if t == "human":
		return "zombie"
	if t == "zombie":
		return "human"
	return "blue" if t == "red" else "red"


func team_name(t: String) -> String:
	match t:
		"human":
			return "MANUSIA"
		"zombie":
			return "ZOMBIE"
	return "MERAH" if t == "red" else "BIRU"


func team_color(t: String) -> Color:
	match t:
		"human":
			return Color(0.45, 1.0, 0.55)
		"zombie":
			return Color(0.7, 0.95, 0.3)
	return Color(1.0, 0.36, 0.36) if t == "red" else Color(0.4, 0.62, 1.0)


func add_coins(n: int) -> void:
	coins += n
	currency_changed.emit()


func add_diamonds(n: int) -> void:
	diamonds += n
	currency_changed.emit()


func record_win(id: int) -> void:
	var k := str(id)
	wins[k] = int(wins.get(k, 0)) + 1


func save_game() -> void:
	var data := {
		"version": VERSION,
		"coins": coins,
		"diamonds": diamonds,
		"team": team,
		"stage": stage,
		"wins": wins,
		"aim_assist": aim_assist,
		"mode": mode,
		"zombie_map": zombie_map,
		"hint_done": hint_done,
		"owned": owned,
		"equipped": equipped,
		"wlevels": wlevels,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		coins = 5000   # bekal awal untuk beli & enhance senjata
		currency_changed.emit()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	diamonds = int(parsed.get("diamonds", 0))
	var t = str(parsed.get("team", "red"))
	team = t if (t == "red" or t == "blue") else "red"
	var s := int(parsed.get("stage", 1))
	stage = s if is_stage_open(s) else 1
	var w = parsed.get("wins", {})
	wins = w if typeof(w) == TYPE_DICTIONARY else {}
	aim_assist = bool(parsed.get("aim_assist", true))
	var m := str(parsed.get("mode", "training"))
	mode = m if (m == "training" or m == "zombie") else "training"
	var zm := str(parsed.get("zombie_map", "night"))
	zombie_map = zm if (zm == "night" or zm == "morning") else "night"
	hint_done = bool(parsed.get("hint_done", false))
	var ow = parsed.get("owned", [])
	if typeof(ow) == TYPE_ARRAY:
		for id in ow:
			if Weapons.base_by_id(str(id))["id"] == str(id) and not owned.has(str(id)):
				owned.append(str(id))
	var eq = parsed.get("equipped", [])
	if typeof(eq) == TYPE_ARRAY and eq.size() == 3:
		for i in 3:
			var wid := str(eq[i])
			if owned.has(wid) and int(Weapons.base_by_id(wid)["slot"]) == i:
				equipped[i] = wid
	var wl = parsed.get("wlevels", {})
	if typeof(wl) == TYPE_DICTIONARY:
		for k in wl:
			wlevels[str(k)] = clampi(int(wl[k]), 0, 8)
	currency_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()
