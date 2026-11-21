extends Control
# Layar PERLENGKAPAN (tile EQUIP di beranda), mengikuti screenshot referensi: panel statistik senjata di kiri
# (damage, kecepatan, akurasi, dst. + bonus enhance), kotak senjata milik di kanan, tombol PASANG.

const Ui = preload("res://scripts/ui.gd")
const TopBarScript = preload("res://scripts/topbar.gd")
const TabBarScript = preload("res://scripts/tabbar.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Fx = preload("res://scripts/fx.gd")
const A := "res://assets/"

const TABS := ["SENJATA", "ARMOR", "LAINNYA", "KOMPONEN", "KOTAK HADIAH"]

var sel := "rifle"
var tab := 0
var left_host: VBoxContainer
var grid_host: Control
var tab_btns: Array = []
var big_icon: TextureRect
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sel = Game.equipped_id(0)

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
	mid.add_theme_constant_override("separation", 14)
	root.add_child(mid)

	var lp := _panel()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.0
	left_host = VBoxContainer.new()
	left_host.add_theme_constant_override("separation", 6)
	lp.add_child(left_host)
	mid.add_child(lp)

	var rp := _panel()
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.35
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	rp.add_child(rv)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 4)
	rv.add_child(trow)
	for i in TABS.size():
		var b := Button.new()
		b.text = str(TABS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_set_tab.bind(i))
		trow.add_child(b)
		tab_btns.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(sc)
	grid_host = VBoxContainer.new()
	grid_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid_host)
	mid.add_child(rp)

	var tabs := TabBarScript.new()
	tabs.current = "MAIN"
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.tab_pressed.connect(_on_tab)
	root.add_child(tabs)
	_refresh()


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Ui.box(Color(0.06, 0.08, 0.13, 0.92), Color(1, 1, 1, 0.25), 2, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _set_tab(i: int) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	tab = i
	_refresh()


func _refresh() -> void:
	for i in tab_btns.size():
		var on: bool = (i == tab)
		Ui.style_button(tab_btns[i], Color(0.1, 0.4, 0.78, 0.96) if on else Color(0.12, 0.14, 0.2, 0.9),
				Color(0.5, 0.8, 1.0) if on else Color(1, 1, 1, 0.2), 3 if on else 2, 4)
	_build_grid()
	_build_stats()


# ------------------------------------------------------------------ kotak senjata (kanan)
func _build_grid() -> void:
	for c in grid_host.get_children():
		c.queue_free()
	if tab != 0:
		var l := Ui.label("Belum ada item di kategori ini", 24, Color(0.7, 0.75, 0.85), false)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(0, 200)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid_host.add_child(l)
		return
	var g := GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	grid_host.add_child(g)
	for slot in 3:
		for id in Weapons.ids_of_slot(slot):
			if Game.has_weapon(str(id)):
				g.add_child(_item_card(str(id)))


func _item_card(id: String) -> Button:
	var d: Dictionary = Weapons.base_by_id(id)
	var chosen: bool = (id == sel)
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 130)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.style_button(b, Color(0.14, 0.15, 0.2, 0.95), Color(1.0, 0.85, 0.3) if chosen else Color(1, 1, 1, 0.22), 4 if chosen else 2, 4)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var nl := Ui.label(str(d["name"]), 17, Color(0.9, 0.9, 0.95), false)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var ic := Ui.icon(Vector2(170, 64), load(A + str(d["icon"])))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var cap := Ui.label(str(Weapons.SLOT_SHORT[int(d["slot"])]), 16, Color(1.0, 0.85, 0.4), false)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	var lvb := Ui.label("Lv.%d" % Game.weapon_level(id), 16, Color(0.6, 1.0, 0.6))
	lvb.position = Vector2(8, 4)
	b.add_child(lvb)
	if Game.equipped_id(int(d["slot"])) == id:
		var eb := Ui.label("PASANG", 14, Color.WHITE, false)
		eb.add_theme_stylebox_override("normal", Ui.box(Color(0.2, 0.6, 0.25), Color(0, 0, 0, 0), 0, 3))
		eb.anchor_left = 1.0
		eb.anchor_right = 1.0
		eb.offset_left = -62.0
		eb.offset_top = 4.0
		b.add_child(eb)
	b.pressed.connect(func():
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
		sel = id
		_refresh())
	return b


# ------------------------------------------------------------------ statistik (kiri)
func _build_stats() -> void:
	for c in left_host.get_children():
		c.queue_free()
	var base: Dictionary = Weapons.base_by_id(sel)
	var lv: int = Game.weapon_level(sel)
	var slot: int = int(base["slot"])

	var head := HBoxContainer.new()
	left_host.add_child(head)
	var badge := Ui.label(str(Weapons.SLOT_SHORT[slot]), 18, Color(1.0, 0.85, 0.3))
	badge.add_theme_stylebox_override("normal", Ui.box(Color(0.3, 0.22, 0.05), Color(1.0, 0.85, 0.3), 2, 12))
	head.add_child(badge)
	var nm := Ui.label(str(base["name"]), 28)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(nm)

	big_icon = Ui.icon(Vector2(300, 120), load(A + str(base["icon"])))
	big_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left_host.add_child(big_icon)

	var sp := Ui.label(str(base["desc"]), 17, Color(0.95, 0.85, 0.5), false)
	sp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_host.add_child(sp)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	left_host.add_child(grid)
	var src: Array = Weapons.ROWS_MELEE if bool(base["melee"]) else Weapons.ROWS_GUN
	for r in src:
		var k: String = str(r[0])
		var v0: float = Weapons.stat_value(base, 0, k)
		var v1: float = Weapons.stat_value(base, lv, k)
		var txt: String = Weapons.stat_text(base, k, v0)
		var bonus: int = int(v1 - v0)
		var name_l := Ui.label(str(r[1]), 17, Color(0.8, 0.85, 0.95), false)
		name_l.custom_minimum_size = Vector2(112, 0)
		grid.add_child(name_l)
		var vl := Ui.label(txt, 18)
		vl.custom_minimum_size = Vector2(70, 0)
		grid.add_child(vl)
		var bl := Ui.label("+%d" % bonus if (bonus > 0 and (k == "dmg" or k == "acc" or k == "stab")) else "", 17, Color(0.5, 1.0, 0.5), false)
		bl.custom_minimum_size = Vector2(40, 0)
		grid.add_child(bl)
		grid.add_child(Control.new())

	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_host.add_child(sp2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	left_host.add_child(row)
	var enh := Button.new()
	enh.text = "ENHANCE"
	enh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enh.custom_minimum_size = Vector2(0, 58)
	enh.add_theme_font_size_override("font_size", 22)
	Ui.style_button(enh, Color(0.2, 0.5, 0.85), Color(1, 1, 1, 0.6), 2, 8)
	enh.pressed.connect(func():
		Game.focus_weapon = sel
		Game.save_game()
		get_tree().change_scene_to_file("res://enhance.tscn"))
	row.add_child(enh)
	var equipped: bool = Game.equipped_id(slot) == sel
	var eq := Button.new()
	eq.text = "TERPASANG" if equipped else "PASANG"
	eq.disabled = equipped
	eq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq.custom_minimum_size = Vector2(0, 58)
	eq.add_theme_font_size_override("font_size", 24)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		eq.add_theme_color_override(c, Color(0.25, 0.14, 0.0))
	Ui.style_button(eq, Color(0.95, 0.7, 0.12), Color(1, 1, 1, 0.6), 2, 8)
	eq.pressed.connect(func():
		if Game.equip_weapon(sel):
			Fx.sfx2d(self, "res://assets/sfx/equip.wav", -2.0)
			_refresh())
	row.add_child(eq)


func _process(delta: float) -> void:
	t += delta
	if big_icon != null and is_instance_valid(big_icon):
		big_icon.pivot_offset = big_icon.size / 2.0
		big_icon.rotation = sin(t * 1.4) * 0.03
		big_icon.scale = Vector2.ONE * (1.0 + 0.02 * sin(t * 2.0))


func _on_tab(tab_name: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Ui.go_tab(self, "MAIN", tab_name)
