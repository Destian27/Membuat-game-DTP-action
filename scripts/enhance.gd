extends Control
# Layar ENHANCE (tab bawah): daftar senjata per slot, beli senjata baru, enhance (naik level),
# pasang senjata, lihat statistik sebelum -> sesudah. Efek enhance dibuat lewat kode (pop, kilat, percikan).

const Ui = preload("res://scripts/ui.gd")
const TopBarScript = preload("res://scripts/topbar.gd")
const TabBarScript = preload("res://scripts/tabbar.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Fx = preload("res://scripts/fx.gd")
const A := "res://assets/"

var cat := 0                 # slot yang ditampilkan: 0 utama, 1 pistol, 2 pisau
var sel := "rifle"           # id senjata terpilih
var list_box: GridContainer
var tab_btns: Array = []
var detail_host: VBoxContainer
var fx_layer: Control
var preview: TextureRect
var pop := 0.0
var t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sel = Game.equipped_id(0)
	if Game.focus_weapon != "":
		sel = Game.focus_weapon
		cat = int(Weapons.base_by_id(sel)["slot"])
		Game.focus_weapon = ""

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
	mid.add_child(_build_left())
	mid.add_child(_build_right())

	var tabs := TabBarScript.new()
	tabs.current = "ENHANCE"
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.tab_pressed.connect(_on_tab)
	root.add_child(tabs)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	_refresh()


# ------------------------------------------------------------------ kerangka
func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Ui.box(Color(0.06, 0.08, 0.13, 0.92), Color(1, 1, 1, 0.25), 2, 10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _build_left() -> Control:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.0
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)
	for i in 3:
		var b := Button.new()
		b.text = str(Weapons.SLOT_NAMES[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_set_cat.bind(i))
		row.add_child(b)
		tab_btns.append(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	list_box = GridContainer.new()
	list_box.columns = 2
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("h_separation", 10)
	list_box.add_theme_constant_override("v_separation", 10)
	sc.add_child(list_box)
	return p


func _build_right() -> Control:
	var p := _panel()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.25
	detail_host = VBoxContainer.new()
	detail_host.add_theme_constant_override("separation", 8)
	p.add_child(detail_host)
	return p


# ------------------------------------------------------------------ isi
func _set_cat(i: int) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	cat = i
	var ids: Array = Weapons.ids_of_slot(cat)
	if not ids.has(sel):
		sel = Game.equipped_id(cat)
	_refresh()


func _refresh() -> void:
	for i in 3:
		var on: bool = (i == cat)
		Ui.style_button(tab_btns[i], Color(0.1, 0.4, 0.78, 0.96) if on else Color(0.12, 0.14, 0.2, 0.9),
				Color(0.5, 0.8, 1.0) if on else Color(1, 1, 1, 0.2), 3 if on else 2, 6)
	for c in list_box.get_children():
		c.queue_free()
	for id in Weapons.ids_of_slot(cat):
		list_box.add_child(_weapon_card(str(id)))
	_build_detail()


func _weapon_card(id: String) -> Button:
	var d: Dictionary = Weapons.base_by_id(id)
	var owned: bool = Game.has_weapon(id)
	var chosen: bool = (id == sel)
	var b := Button.new()
	b.custom_minimum_size = Vector2(230, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Ui.style_button(b, Color(0.1, 0.12, 0.18, 0.95), Color(1.0, 0.85, 0.3) if chosen else Color(1, 1, 1, 0.25), 4 if chosen else 2, 8)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)
	var ic := Ui.icon(Vector2(200, 80), load(A + str(d["icon"])))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color.WHITE if owned else Color(0.45, 0.45, 0.5)
	vb.add_child(ic)
	var nl := Ui.label(str(d["name"]), 20)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var status := ""
	var scol := Color(0.8, 0.85, 0.95)
	if not owned:
		status = "HARGA %d" % int(d["price"])
		scol = Color(1.0, 0.88, 0.35)
	elif Game.equipped_id(int(d["slot"])) == id:
		status = "Lv.%d  TERPASANG" % Game.weapon_level(id)
		scol = Color(0.5, 1.0, 0.5)
	else:
		status = "Lv.%d" % Game.weapon_level(id)
	var sl := Ui.label(status, 17, scol, false)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	b.pressed.connect(func():
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
		sel = id
		_refresh())
	return b


func _build_detail() -> void:
	for c in detail_host.get_children():
		c.queue_free()
	var base: Dictionary = Weapons.base_by_id(sel)
	var owned: bool = Game.has_weapon(sel)
	var lv: int = Game.weapon_level(sel)
	var maxed: bool = lv >= Weapons.MAX_LV

	var head := HBoxContainer.new()
	detail_host.add_child(head)
	var nm := Ui.label(str(base["name"]), 32, Color(1.0, 0.9, 0.5))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(Ui.label("Lv.%d / %d" % [lv, Weapons.MAX_LV] if owned else "BELUM DIMILIKI", 26,
			Color(0.6, 1.0, 0.6) if owned else Color(1.0, 0.6, 0.5)))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	detail_host.add_child(body)

	# statistik sebelum >> sesudah
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for r in Weapons.stat_rows(base, lv):
		var name_l := Ui.label(str(r[0]), 20, Color(0.8, 0.85, 0.95), false)
		name_l.custom_minimum_size = Vector2(150, 0)
		grid.add_child(name_l)
		grid.add_child(Ui.label(str(r[1]), 20))
		var up: bool = bool(r[3]) and owned and not maxed
		grid.add_child(Ui.label(">>" if up else "", 20, Color(0.4, 0.9, 1.0), false))
		grid.add_child(Ui.label(str(r[2]) if up else "", 20, Color(0.5, 1.0, 0.5)))

	# gambar senjata + titik level
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	preview = Ui.icon(Vector2(300, 150), load(A + str(base["icon"])))
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.modulate = Color.WHITE if owned else Color(0.45, 0.45, 0.5)
	right.add_child(preview)
	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 6)
	for i in Weapons.MAX_LV:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 24)
		var filled: bool = i < lv
		pip.add_theme_stylebox_override("panel", Ui.box(Color(1.0, 0.8, 0.2) if filled else Color(0.15, 0.17, 0.24),
				Color(1, 1, 1, 0.7) if filled else Color(1, 1, 1, 0.2), 2, 6))
		pips.add_child(pip)
	right.add_child(pips)

	var desc := Ui.label(str(base["desc"]), 18, Color(0.82, 0.86, 0.95), false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_host.add_child(desc)

	# biaya + tombol
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	detail_host.add_child(cost_row)
	var cost := 0
	var cost_txt := ""
	if not owned:
		cost = int(base["price"])
		cost_txt = "Harga beli: %d" % cost
	elif maxed:
		cost_txt = "Level sudah maksimal"
	else:
		cost = Weapons.enhance_cost(lv)
		cost_txt = "Biaya enhance: %d" % cost
	if cost > 0:
		cost_row.add_child(Ui.icon(Vector2(34, 34), load(A + "coin_0.png")))
	cost_row.add_child(Ui.label(cost_txt, 24, Color(1.0, 0.88, 0.35) if Game.coins >= cost else Color(1.0, 0.45, 0.4)))

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	detail_host.add_child(btns)
	if not owned:
		btns.add_child(_btn("BELI", Color(0.95, 0.7, 0.12), _buy, true))
	else:
		if not maxed:
			btns.add_child(_btn("ENHANCE", Color(0.2, 0.5, 0.85), _enhance.bind(false), false))
			btns.add_child(_btn("1 KLIK", Color(0.95, 0.7, 0.12), _enhance.bind(true), true))
		if Game.equipped_id(int(base["slot"])) == sel:
			var tag := Ui.label("TERPASANG", 24, Color(0.5, 1.0, 0.5))
			tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btns.add_child(tag)
		else:
			btns.add_child(_btn("PASANG", Color(0.2, 0.6, 0.25), _equip, false))


func _btn(txt: String, col: Color, cb: Callable, dark_text: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 26)
	if dark_text:
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, Color(0.25, 0.14, 0.0))
	Ui.style_button(b, col, Color(1, 1, 1, 0.6), 2, 8)
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ aksi
func _buy() -> void:
	var d: Dictionary = Weapons.base_by_id(sel)
	if Game.coins < int(d["price"]):
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0, 0.7)
		Ui.toast(self, "Koin kurang (butuh %d). Menangkan pertandingan untuk dapat koin." % int(d["price"]))
		return
	if Game.buy_weapon(sel):
		Fx.sfx2d(self, "res://assets/sfx/buy.wav", -2.0)
		Game.equip_weapon(sel)
		Ui.toast(self, "%s dibeli dan dipasang" % str(d["name"]))
		_refresh()
		_burst()


func _equip() -> void:
	if Game.equip_weapon(sel):
		Fx.sfx2d(self, "res://assets/sfx/equip.wav", -2.0)
		Ui.toast(self, "%s dipasang" % str(Weapons.base_by_id(sel)["name"]))
		_refresh()


func _enhance(multi: bool) -> void:
	var lv0: int = Game.weapon_level(sel)
	if lv0 >= Weapons.MAX_LV:
		return
	var n := 0
	while Game.enhance_weapon(sel):
		n += 1
		if not multi:
			break
	if n == 0:
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0, 0.7)
		Ui.toast(self, "Koin kurang (butuh %d)" % Weapons.enhance_cost(lv0))
		return
	Fx.sfx2d(self, "res://assets/sfx/enhance_ok.wav", -1.0)
	Ui.toast(self, "Naik ke Level %d" % Game.weapon_level(sel))
	_refresh()
	_burst()


# efek enhance dari kode: gambar senjata membesar sebentar, kilat putih, percikan spark.png
func _burst() -> void:
	pop = 1.0
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.35)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	await get_tree().process_frame
	if preview == null or not is_instance_valid(preview):
		return
	var p := CPUParticles2D.new()
	p.texture = load(A + "spark.png")
	p.one_shot = true
	p.amount = 28
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color = Color(1.0, 0.9, 0.4)
	fx_layer.add_child(p)
	p.global_position = preview.global_position + preview.size / 2.0
	p.emitting = true
	p.finished.connect(p.queue_free)


func _process(delta: float) -> void:
	t += delta
	pop = move_toward(pop, 0.0, delta * 3.0)
	if preview != null and is_instance_valid(preview):
		preview.pivot_offset = preview.size / 2.0
		preview.scale = Vector2.ONE * (1.0 + 0.02 * sin(t * 2.0) + 0.25 * pop)
		preview.rotation = sin(t * 1.3) * 0.02


func _on_tab(tab_name: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Ui.go_tab(self, "ENHANCE", tab_name)
