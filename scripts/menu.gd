extends Control
# Beranda (MAIN): karakter di kiri, menu ROLE / RANKED MATCH / EQUIP / CREATION / TASK / RANK
# di kanan, tombol QUICK BATTLE, tab bawah MAIN-BATTLE-ENHANCE-SOCIAL. Tata letak mengikuti screenshot.

const Ui = preload("res://scripts/ui.gd")
const TopBarScript = preload("res://scripts/topbar.gd")
const TabBarScript = preload("res://scripts/tabbar.gd")
const Fx = preload("res://scripts/fx.gd")
const A := "res://assets/"

var char_frames := {}     # "red"/"blue" -> {"idle": [...], "walk": [...]}
var hero: TextureRect
var t := 0.0
var role_cards := {}
var role_status := {}
var role_pics := {}
var role_icon: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for tm in ["red", "blue"]:
		var idle := []
		for i in 2:
			idle.append(load(A + "char_%s/idle_%d.png" % [tm, i]))
		var walk := []
		for i in 4:
			walk.append(load(A + "char_%s/walk_%d.png" % [tm, i]))
		char_frames[tm] = {"idle": idle, "walk": walk}

	var bg := TextureRect.new()
	bg.texture = load(A + "menu_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
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
	mid.add_theme_constant_override("separation", 18)
	root.add_child(mid)
	mid.add_child(_build_side_icons())
	mid.add_child(_build_hero())
	mid.add_child(_build_right())

	var tabs := TabBarScript.new()
	tabs.current = "MAIN"
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.tab_pressed.connect(_on_tab)
	root.add_child(tabs)

	var shop := Button.new()
	shop.text = "SHOP\nGo>>"
	shop.add_theme_font_size_override("font_size", 26)
	shop.add_theme_color_override("font_color", Color(0.3, 0.12, 0.0))
	shop.add_theme_color_override("font_hover_color", Color(0.3, 0.12, 0.0))
	shop.add_theme_color_override("font_pressed_color", Color(0.3, 0.12, 0.0))
	Ui.style_button(shop, Color(1.0, 0.75, 0.15), Color(1.0, 0.95, 0.6), 5, 60)
	shop.anchor_left = 1.0
	shop.anchor_right = 1.0
	shop.anchor_top = 1.0
	shop.anchor_bottom = 1.0
	shop.offset_left = -150.0
	shop.offset_right = -30.0
	shop.offset_top = -150.0
	shop.offset_bottom = -30.0
	shop.pressed.connect(func(): Ui.toast(self, "Toko segera hadir"))
	add_child(shop)


# ------------------------------------------------------------------ bagian layar
func _build_side_icons() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(96, 0)
	var items := [
		["Event", "spark.png", Color(0.75, 0.15, 0.15)],
		["Hot", "icon_hp.png", Color(0.15, 0.4, 0.8)],
		["First Recharge", "diamond_0.png", Color(0.15, 0.45, 0.85)],
		["Mail", "coin_0.png", Color(0.3, 0.35, 0.5)],
	]
	for it in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 84)
		Ui.style_button(b, (it[2] as Color), Color(1, 1, 1, 0.7), 2, 14)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		var ic := Ui.icon(Vector2(44, 40), load(A + str(it[1])))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ic)
		var cap := Ui.label(str(it[0]), 14 if str(it[0]).length() > 6 else 17)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(cap)
		var nm: String = str(it[0])
		b.pressed.connect(func(): Ui.toast(self, "%s segera hadir" % nm))
		col.add_child(b)
	return col


func _build_hero() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	col.add_theme_constant_override("separation", 6)
	hero = TextureRect.new()
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.custom_minimum_size = Vector2(300, 320)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.texture = char_frames[Game.team]["idle"][0]
	col.add_child(hero)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(chips)
	for c in [["Sign Up", Color(0.2, 0.4, 0.75)], ["LUCKY DRAW", Color(0.25, 0.3, 0.5)], ["LIVE", Color(0.75, 0.15, 0.15)]]:
		var b := Button.new()
		b.text = str(c[0])
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 18)
		Ui.style_button(b, (c[1] as Color), Color(1, 1, 1, 0.6), 2, 4)
		var nm: String = str(c[0])
		b.pressed.connect(func(): Ui.toast(self, "%s segera hadir" % nm))
		chips.add_child(b)
	return col


func _build_right() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.5
	col.add_theme_constant_override("separation", 12)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var role_tile := _tile("ROLE", "team_%s.png" % Game.team, false, _open_role)
	role_icon = (role_tile.get_child(0) as HBoxContainer).get_child(0) as TextureRect
	grid.add_child(role_tile)
	grid.add_child(_tile("RANKED MATCH", "diamond_0.png", false, func(): Ui.toast(self, "Ranked Match segera hadir")))
	grid.add_child(_tile("EQUIP", "icon_rifle.png", false, _open_equip))
	grid.add_child(_tile("CREATION", "icon_ammo.png", false, func(): Ui.toast(self, "Creation segera hadir")))
	grid.add_child(_tile("TASK", "coin_0.png", true, func(): Ui.toast(self, "Task segera hadir")))
	grid.add_child(_tile("RANK", "icon_hp.png", false, func(): Ui.toast(self, "Rank segera hadir")))

	var qb := Button.new()
	qb.text = "QUICK BATTLE"
	qb.custom_minimum_size = Vector2(0, 92)
	qb.add_theme_font_size_override("font_size", 50)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		qb.add_theme_color_override(c, Color(0.25, 0.14, 0.0))
	Ui.style_button(qb, Color(1.0, 0.78, 0.18), Color(1.0, 0.95, 0.6), 4, 8)
	qb.pressed.connect(_on_quick_battle)
	col.add_child(qb)
	return col


func _tile(title: String, icon_file: String, notif: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 92)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	Ui.style_button(b, Color(0.8, 0.82, 0.88, 0.94), Color(1, 1, 1, 0.9), 2, 8)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 6)
	b.add_child(hb)
	var ic := Ui.icon(Vector2(76, 70), load(A + icon_file))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(ic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", -2)
	hb.add_child(vb)
	var cap := Ui.label("CRISIS ACTION", 13, Color(0.15, 0.4, 0.85), false)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(cap)
	var tl := Ui.label(title, 30 if title.length() < 8 else 26, Color(0.1, 0.12, 0.18), false)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(tl)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(8, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(pad)
	if notif:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", Ui.box(Color(0.95, 0.25, 0.1), Color(1, 1, 1), 2, 9))
		dot.anchor_left = 1.0
		dot.anchor_right = 1.0
		dot.offset_left = -24.0
		dot.offset_right = -6.0
		dot.offset_top = 6.0
		dot.offset_bottom = 24.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(dot)
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ aksi
func _on_tab(tab_name: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Ui.go_tab(self, "MAIN", tab_name)


func _on_quick_battle() -> void:
	Game.save_game()
	get_tree().change_scene_to_file("res://main.tscn")


func _open_role() -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	for tm in ["red", "blue"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(250, 360)
		btn.pressed.connect(_on_role_pressed.bind(tm))
		role_cards[tm] = btn
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		btn.add_child(vb)
		var emblem := Ui.icon(Vector2(56, 56), load(A + "team_%s.png" % tm))
		emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(emblem)
		var pic := Ui.icon(Vector2(220, 220), char_frames[tm]["idle"][0])
		role_pics[tm] = pic
		vb.add_child(pic)
		var nl := Ui.label("TIM " + Game.team_name(tm), 30, Game.team_color(tm))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(nl)
		var st := Ui.label("", 20)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_status[tm] = st
		vb.add_child(st)
		row.add_child(btn)
	Ui.popup(self, "PILIH ROLE / TIM", row)
	_refresh_role()


func _refresh_role() -> void:
	for tm in role_cards.keys():
		if not is_instance_valid(role_cards[tm]):
			continue
		var sel: bool = Game.team == tm
		Ui.style_button(role_cards[tm], Color(0.07, 0.08, 0.13, 0.9),
				Game.team_color(tm) if sel else Color(1, 1, 1, 0.2), 6 if sel else 2, 14)
		role_status[tm].text = "DIPILIH" if sel else "ketuk untuk pilih"
		role_status[tm].add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if sel else Color(0.75, 0.75, 0.8))
		role_pics[tm].modulate = Color.WHITE if sel else Color(0.62, 0.62, 0.68)


func _on_role_pressed(tm: String) -> void:
	Game.team = tm
	Game.save_game()
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	role_icon.texture = load(A + "team_%s.png" % tm)
	_refresh_role()


func _open_equip() -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Game.save_game()
	get_tree().change_scene_to_file("res://inventory.tscn")


# ------------------------------------------------------------------ animasi
func _process(delta: float) -> void:
	t += delta
	var list: Array = char_frames[Game.team]["idle"]
	hero.texture = list[int(t * 2.0) % list.size()]
