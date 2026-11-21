extends Control
# Lobi (tab BATTLE): slot pemain kiri (Tim Merah | Tim Biru), panel kanan berisi peta, jumlah pemain,
# Aim Assist OFF/ON, Quick Chat, HUNT, Start, Invite Player. Tata letak mengikuti screenshot lobi.

const Ui = preload("res://scripts/ui.gd")
const TopBarScript = preload("res://scripts/topbar.gd")
const TabBarScript = preload("res://scripts/tabbar.gd")
const StagesScript = preload("res://scripts/stages.gd")
const Fx = preload("res://scripts/fx.gd")
const A := "res://assets/"

const CHATS := ["Siap tempur!", "Ikuti aku!", "Tolong cover!", "Ayo menangkan ini!", "Awas dari kiri!"]

const ZOMBIE_TOTAL := 14    # jumlah pemain mode Zombie (lebih banyak dari Pelatihan)

var team_size := 4
var filled := {}            # "red_0" / "p_0" -> nama
var bot_count := 0
var starting := false
var heads_box: HBoxContainer
var mode_btns := {}
var chat_i := 0

var slot_grid: GridContainer
var chat_box: VBoxContainer
var map_pic: TextureRect
var map_name: Label
var players_label: Label
var aim_off: Button
var aim_on: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := TextureRect.new()
	bg.texture = load(A + "menu_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := TopBarScript.new()
	top.settings_pressed.connect(func(): Ui.toast(self, "Pengaturan segera hadir"))
	root.add_child(top)

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	root.add_child(mid)
	mid.add_child(_build_slots_panel())
	mid.add_child(_build_right_panel())

	var tabs := TabBarScript.new()
	tabs.current = "BATTLE"
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.tab_pressed.connect(_on_tab)
	root.add_child(tabs)

	_set_stage(Game.stage)
	_refresh_aim()
	_refresh_modes()


# ------------------------------------------------------------------ slot pemain
func _build_slots_panel() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.6
	col.add_theme_constant_override("separation", 8)

	heads_box = HBoxContainer.new()
	heads_box.add_theme_constant_override("separation", 10)
	col.add_child(heads_box)

	slot_grid = GridContainer.new()
	slot_grid.columns = 2
	slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 10)
	slot_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(slot_grid)

	var chat_panel := PanelContainer.new()
	chat_panel.add_theme_stylebox_override("panel", Ui.box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.2), 2, 8))
	chat_panel.custom_minimum_size = Vector2(0, 92)
	chat_box = VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 0)
	chat_panel.add_child(chat_box)
	col.add_child(chat_panel)
	return col


func _slot_key(tm: String, row: int) -> String:
	return "%s_%d" % [tm, row]


func _total() -> int:
	return ZOMBIE_TOTAL if Game.mode == "zombie" else team_size * 2


func _my_key() -> String:
	return "p_0" if Game.mode == "zombie" else _slot_key(Game.team, 0)


func _rebuild_heads() -> void:
	for c in heads_box.get_children():
		c.queue_free()
	if Game.mode == "zombie":
		var l := Ui.label("MODE ZOMBIE", 24, Game.team_color("zombie"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heads_box.add_child(l)
	else:
		for tm in ["red", "blue"]:
			var l := Ui.label("TIM " + Game.team_name(tm), 24, Game.team_color(tm))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heads_box.add_child(l)


func _rebuild_slots() -> void:
	for c in slot_grid.get_children():
		c.queue_free()
	_rebuild_heads()
	if Game.mode == "zombie":
		for i in ZOMBIE_TOTAL:
			slot_grid.add_child(_make_slot("p", i))
	else:
		for row in team_size:
			for tm in ["red", "blue"]:
				slot_grid.add_child(_make_slot(tm, row))
	players_label.text = "Players:   %d" % _total()


func _make_slot(tm: String, row: int) -> Control:
	var key := _slot_key(tm, row)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var zom: bool = (tm == "p")
	p.custom_minimum_size = Vector2(0, 34 if zom else 56)
	if filled.has(key):
		var mine: bool = (key == _my_key())
		var accent := Game.team_color("human") if zom else Game.team_color(tm)
		p.add_theme_stylebox_override("panel", Ui.box(Color(0.1, 0.12, 0.18, 0.92), accent, 3 if mine else 2, 8))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		p.add_child(hb)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(6, 0)
		hb.add_child(pad)
		var em := Ui.icon(Vector2(26, 26) if zom else Vector2(36, 36), load(A + ("icon_hp.png" if zom else "team_%s.png" % tm)))
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(em)
		var nm := Ui.label(str(filled[key]) + ("  (KAMU)" if mine else ""), 17 if zom else 22, Color.WHITE if mine else Color(0.85, 0.88, 0.95))
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(nm)
	else:
		p.add_theme_stylebox_override("panel", Ui.box(Color(0.12, 0.13, 0.17, 0.6), Color(1, 1, 1, 0.14), 2, 8))
		var l := Ui.label("EMPTY", 16 if zom else 22, Color(0.55, 0.57, 0.63), false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
	return p


func _reset_slots() -> void:
	filled.clear()
	bot_count = 0
	filled[_my_key()] = Game.player_name


func _fill_one() -> bool:
	if Game.mode == "zombie":
		for i in ZOMBIE_TOTAL:
			var k := _slot_key("p", i)
			if not filled.has(k):
				bot_count += 1
				filled[k] = "BOT %02d" % bot_count
				return true
		return false
	for row in team_size:
		for tm in ["red", "blue"]:
			var key := _slot_key(tm, row)
			if not filled.has(key):
				bot_count += 1
				filled[key] = "BOT %02d" % bot_count
				return true
	return false


func _is_full() -> bool:
	return filled.size() >= _total()


# ------------------------------------------------------------------ panel kanan
func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_stylebox_override("panel", Ui.box(Color(0.07, 0.09, 0.14, 0.92), Color(1, 1, 1, 0.25), 2, 10))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	# peta + tombol panah
	var maprow := HBoxContainer.new()
	maprow.add_theme_constant_override("separation", 6)
	vb.add_child(maprow)
	maprow.add_child(_arrow_btn("<", -1))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(250, 150)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	maprow.add_child(holder)
	map_pic = TextureRect.new()
	map_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(map_pic)
	map_name = Ui.label("", 24)
	map_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	map_name.offset_top = -36.0
	map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(map_name)
	maprow.add_child(_arrow_btn(">", 1))

	players_label = Ui.label("Players:   8", 24)
	vb.add_child(players_label)

	# Aim Assist OFF / ON
	var aim := HBoxContainer.new()
	aim.add_theme_constant_override("separation", 8)
	vb.add_child(aim)
	var al := Ui.label("Aim Assist:", 24)
	al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aim.add_child(al)
	aim_off = _toggle_btn("OFF", false)
	aim_on = _toggle_btn("ON", true)
	aim.add_child(aim_off)
	aim.add_child(aim_on)

	# password (hiasan, belum dipakai)
	var pw := HBoxContainer.new()
	pw.add_theme_constant_override("separation", 8)
	vb.add_child(pw)
	var pl := Ui.label("Password:", 24)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(pl)
	var le := LineEdit.new()
	le.placeholder_text = "Optional"
	le.custom_minimum_size = Vector2(170, 40)
	pw.add_child(le)

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	vb.add_child(r1)
	r1.add_child(_action_btn("Quick Chat", Color(0.2, 0.45, 0.8), _on_chat, 24))

	# pilihan mode (menggantikan tombol HUNT): Pelatihan / Zombie / Classic
	var r1b := HBoxContainer.new()
	r1b.add_theme_constant_override("separation", 6)
	vb.add_child(r1b)
	for m in Game.MODES:
		var mb := Button.new()
		mb.text = str(Game.MODE_NAMES[m])
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.custom_minimum_size = Vector2(0, 48)
		mb.add_theme_font_size_override("font_size", 17)
		mb.pressed.connect(_set_mode.bind(m))
		r1b.add_child(mb)
		mode_btns[m] = mb

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 10)
	vb.add_child(r2)
	var start := _action_btn("Start", Color(0.95, 0.7, 0.12), _on_start, 30)
	start.custom_minimum_size = Vector2(0, 66)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		start.add_theme_color_override(c, Color(0.25, 0.14, 0.0))
	r2.add_child(start)
	var inv := _action_btn("Invite Player", Color(0.2, 0.45, 0.8), _on_invite, 22)
	inv.custom_minimum_size = Vector2(0, 66)
	r2.add_child(inv)
	return panel


func _arrow_btn(txt: String, dir: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(44, 150)
	b.add_theme_font_size_override("font_size", 30)
	Ui.style_button(b, Color(0.12, 0.14, 0.2, 0.95), Color(1, 1, 1, 0.35), 2, 8)
	b.pressed.connect(func(): _change_stage(dir))
	return b


func _toggle_btn(txt: String, value: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(76, 42)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func(): _set_aim(value))
	return b


func _action_btn(txt: String, col: Color, cb: Callable, fsize: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", fsize)
	Ui.style_button(b, col, Color(1, 1, 1, 0.6), 2, 8)
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ peta / aim assist
func _change_stage(dir: int) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	if Game.mode == "zombie":
		Game.zombie_map = "morning" if Game.zombie_map == "night" else "night"
		Game.save_game()
		_set_stage(Game.stage)
		return
	var n := Game.MAX_STAGE_OPEN
	var id := ((Game.stage - 1 + dir + n) % n) + 1
	_set_stage(id)


func _set_stage(id: int) -> void:
	Game.stage = id
	var cfg: Dictionary = StagesScript.get_stage(id)
	team_size = int(cfg["team_size"])
	if Game.mode == "zombie":
		# Mode Zombie memiliki dua peta terpisah; panah kiri/kanan mengganti waktu dan layout.
		var zid := StagesScript.ZOMBIE_MORNING_STAGE if Game.zombie_map == "morning" else StagesScript.ZOMBIE_STAGE
		var zc: Dictionary = StagesScript.get_stage(zid)
		map_pic.texture = load(A + ("stage_zombie_morning.png" if Game.zombie_map == "morning" else "stage_zombie.png"))
		map_name.text = "ZOMBIE  -  %s" % str(zc["name"])
	else:
		map_pic.texture = load(A + "stage%d.png" % id)
		map_name.text = "Stage %d  -  %s" % [id, str(cfg["name"])]
	_reset_slots()
	_rebuild_slots()


func _set_mode(m: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	if m == "classic":
		Ui.toast(self, "Mode Classic (online) belum hadir")
		return
	Game.mode = m
	Game.save_game()
	_set_stage(Game.stage)
	_refresh_modes()


func _refresh_modes() -> void:
	for m in mode_btns:
		var b: Button = mode_btns[m]
		var sel: bool = (m == Game.mode)
		var col := Color(0.2, 0.6, 0.25) if sel else Color(0.14, 0.16, 0.22)
		if m == "classic":
			col = Color(0.1, 0.11, 0.15)
			b.modulate = Color(1, 1, 1, 0.55)
		Ui.style_button(b, col, Color(1.0, 0.9, 0.4) if sel else Color(1, 1, 1, 0.3), 4 if sel else 2, 6)


func _set_aim(on: bool) -> void:
	Game.aim_assist = on
	Game.save_game()
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	_refresh_aim()


func _refresh_aim() -> void:
	var on: bool = Game.aim_assist
	Ui.style_button(aim_on, Color(0.2, 0.6, 0.25) if on else Color(0.14, 0.16, 0.22),
			Color(1.0, 0.9, 0.4) if on else Color(1, 1, 1, 0.3), 4 if on else 2, 6)
	Ui.style_button(aim_off, Color(0.65, 0.2, 0.2) if not on else Color(0.14, 0.16, 0.22),
			Color(1.0, 0.9, 0.4) if not on else Color(1, 1, 1, 0.3), 4 if not on else 2, 6)


# ------------------------------------------------------------------ tombol aksi
func _post_chat(who: String, msg: String, col: Color) -> void:
	var l := Ui.label("%s: %s" % [who, msg], 18, col)
	chat_box.add_child(l)
	while chat_box.get_child_count() > 3:
		var old := chat_box.get_child(0)
		chat_box.remove_child(old)
		old.queue_free()


func _on_chat() -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	_post_chat(Game.player_name, CHATS[chat_i % CHATS.size()], Game.team_color(Game.team))
	chat_i += 1
	if bot_count > 0:
		var n := randi_range(1, bot_count)
		_post_chat("BOT %02d" % n, CHATS[randi() % CHATS.size()], Color(0.8, 0.85, 0.95))


func _on_invite() -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Ui.toast(self, "Mode offline: belum ada teman online untuk diundang")


func _on_start() -> void:
	if starting:
		return
	starting = true
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -2.0)
	while _fill_one():
		pass
	_rebuild_slots()
	Ui.toast(self, "Pertandingan dimulai!")
	await get_tree().create_timer(0.6).timeout
	Game.save_game()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_tab(tab_name: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	if tab_name == "BATTLE":
		Game.save_game()
		get_tree().change_scene_to_file("res://modes.tscn")   # tab BATTLE = kembali ke pilihan mode
		return
	Ui.go_tab(self, "BATTLE", tab_name)
