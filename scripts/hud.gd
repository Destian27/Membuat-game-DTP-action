extends CanvasLayer
# HUD berbasis gambar: crosshair, hitmarker, bar darah, senjata first-person (animasi
# recoil/goyang/reload + muzzle flash), kill feed, kontrol sentuh (joystick + tombol).

signal restart_pressed
signal menu_pressed
signal zombie_chosen(ztype: String)

const Fx = preload("res://scripts/fx.gd")
const Weapons = preload("res://scripts/weapons.gd")
const SkillFx = preload("res://scripts/skillfx.gd")
const RoundFx = preload("res://scripts/roundfx.gd")
const CaHud = preload("res://scripts/ca_hud.gd")
const A := "res://assets/"
const JOY_R := 90.0
var muzzle_frac := Vector2(0.011, 0.038) # posisi ujung laras di gambar senjata (diganti per senjata)
var swing := 0.0
var hand_t := 0.0
var hand_frame := 0

var cur_panel: Panel          # tombol senjata tunggal (klik -> pilihan senjata)
var cur_icon: TextureRect
var cur_ammo: Label
var menu_open := false
var zombie_mode := false
var btn_skill: TextureRect
var skill_label: Label
var choice_layer: Control
var skillfx: Control        # efek layar skill (dibuat dari kode)
var heavy_t := 0.0          # animasi tebasan berat samurai di tangan first-person

var slot_panels: Array = []
var slot_icons: Array = []
var slot_ammo: Array = []

var player
var is_mobile := OS.has_feature("android") or OS.has_feature("ios")

var root: Control
var crosshair: TextureRect
var hitmarker: TextureRect
var vignette: TextureRect
var weapon: TextureRect
var muzzle: TextureRect
var hp_icon: TextureRect
var hp_bg: TextureRect
var hp_fill: TextureRect
var hp_label: Label
var ammo_icon: TextureRect
var ammo_label: Label
var score_label: Label   # "KILL x MATI y" kecil di bawah skor tim
var team_icon_r: TextureRect
var team_icon_b: TextureRect
var score_r: Label
var score_b: Label
var target_label: Label
var coin_icon: TextureRect
var dia_icon: TextureRect
var coin_label: Label
var dia_label: Label
var btn_menu: Button
var center_label: Label
var round_label: Label
var roundfx: Control
var ca                       # HUD gaya Crisis Action (CaHud, mode Zombie)
var cur_round := 1
var zt_total := 14
var feed_box: VBoxContainer
var joy_base: TextureRect
var joy_knob: TextureRect
var btn_fire: TextureRect
var btn_reload: TextureRect
var btn_jump: TextureRect
var result_layer: Control
var result_title: Label
var result_stats: Label
var result_reward: Label
var result_total: Label
var result_coin_icon: TextureRect
var result_dia_icon: TextureRect
var result_open := false

var coin_frames: Array = []
var dia_frames: Array = []
var icon_t := 0.0
var coin_pop := 0.0
var dia_pop := 0.0
var my_team := "red"

var touches := {}
var joy_index := -1
var joy_center := Vector2.ZERO
var joy_home := Vector2.ZERO
var weapon_base := Vector2.ZERO
var kick := 0.0
var bob_t := 0.0
var flash_t := 0.0
var hit_t := 0.0
var vig := 0.0
var reload_drop := 0.0
var hp_cur := 100
var center_token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = _img("vignette.png", Vector2(100, 100))
	vignette.modulate.a = 0.0
	weapon = _img("weapon.png", Vector2(100, 100))
	muzzle = _img("muzzle.png", Vector2(170, 170))
	muzzle.visible = false
	crosshair = _img("crosshair.png", Vector2(56, 56))
	crosshair.pivot_offset = crosshair.size / 2.0
	hitmarker = _img("hitmarker.png", Vector2(56, 56))
	hitmarker.modulate.a = 0.0

	hp_icon = _img("icon_hp.png", Vector2(46, 46))
	hp_bg = _img("bar_bg.png", Vector2(300, 30))
	hp_fill = _img("bar_fill.png", Vector2(294, 24))
	hp_label = _label(20, Color.WHITE)
	hp_label.text = "100"
	root.add_child(hp_label)
	ammo_icon = _img("icon_ammo.png", Vector2(46, 46))
	ammo_label = _label(34, Color(1.0, 0.92, 0.6))
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.text = "30 / 120"
	root.add_child(ammo_label)
	score_label = _label(22, Color.WHITE)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score_label)
	team_icon_r = _img("team_red.png", Vector2(46, 46))
	team_icon_b = _img("team_blue.png", Vector2(46, 46))
	score_r = _label(40, Game.team_color("red"))
	score_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(score_r)
	score_b = _label(40, Game.team_color("blue"))
	root.add_child(score_b)
	target_label = _label(20, Color(0.9, 0.9, 0.9))
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(target_label)

	for i in 8:
		coin_frames.append(load(A + "coin_%d.png" % i))
		dia_frames.append(load(A + "diamond_%d.png" % i))
	coin_icon = _img("coin_0.png", Vector2(44, 44))
	coin_icon.pivot_offset = coin_icon.size / 2.0
	coin_label = _label(30, Color(1.0, 0.88, 0.35))
	root.add_child(coin_label)
	dia_icon = _img("diamond_0.png", Vector2(44, 44))
	dia_icon.pivot_offset = dia_icon.size / 2.0
	dia_label = _label(30, Color(0.55, 0.9, 1.0))
	root.add_child(dia_label)

	# koin & diamond tidak ada di gameplay
	for n in [coin_icon, dia_icon, coin_label, dia_label]:
		n.visible = false

	btn_menu = Button.new()
	btn_menu.text = "MENU"
	btn_menu.focus_mode = Control.FOCUS_NONE
	btn_menu.custom_minimum_size = Vector2(110, 40)
	btn_menu.size = Vector2(110, 40)
	btn_menu.pressed.connect(func(): menu_pressed.emit())
	root.add_child(btn_menu)
	center_label = _label(54, Color(1.0, 0.9, 0.4))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	round_label = _label(22, Color(1.0, 0.88, 0.4))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.visible = false
	root.add_child(round_label)
	feed_box = VBoxContainer.new()
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed_box)

	joy_base = _img("joystick_base.png", Vector2(220, 220))
	joy_knob = _img("joystick_knob.png", Vector2(100, 100))
	btn_fire = _img("btn_fire.png", Vector2(190, 190))
	btn_reload = _img("btn_reload.png", Vector2(110, 110))
	btn_jump = _img("btn_jump.png", Vector2(110, 110))
	btn_skill = _img("btn_jump.png", Vector2(110, 110))
	skill_label = _label(20, Color.WHITE)
	skill_label.size = Vector2(110, 110)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_skill.add_child(skill_label)
	btn_skill.visible = false
	skillfx = SkillFx.new()
	skillfx.button = btn_skill
	root.add_child(skillfx)
	for n in [joy_base, joy_knob, btn_fire, btn_reload, btn_jump]:
		n.visible = is_mobile

	_build_slots()
	_build_current_button()
	_build_choice()
	ca = CaHud.new()
	ca.visible = false
	root.add_child(ca)
	roundfx = RoundFx.new()
	root.add_child(roundfx)
	_build_result()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _img(file: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(A + file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(t)
	return t


func _label(sz: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", maxi(2, int(sz / 8.0)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_result() -> void:
	result_layer = Control.new()
	result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.visible = false
	root.add_child(result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	result_title = _label(70, Color.WHITE)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_title)
	result_stats = _label(28, Color(0.9, 0.9, 0.9))
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_stats)

	var rbox := HBoxContainer.new()
	rbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rbox.add_theme_constant_override("separation", 10)
	box.add_child(rbox)
	result_coin_icon = TextureRect.new()
	result_coin_icon.custom_minimum_size = Vector2(52, 52)
	result_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rbox.add_child(result_coin_icon)
	result_reward = _label(36, Color(1.0, 0.9, 0.4))
	rbox.add_child(result_reward)
	result_dia_icon = TextureRect.new()
	result_dia_icon.custom_minimum_size = Vector2(52, 52)
	result_dia_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_dia_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rbox.add_child(result_dia_icon)

	result_total = _label(24, Color(0.85, 0.85, 0.85))
	result_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(result_total)

	var bbox := HBoxContainer.new()
	bbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bbox.add_theme_constant_override("separation", 20)
	box.add_child(bbox)
	var btn := Button.new()
	btn.text = "MAIN LAGI"
	btn.custom_minimum_size = Vector2(280, 76)
	btn.add_theme_font_size_override("font_size", 30)
	btn.pressed.connect(func(): restart_pressed.emit())
	bbox.add_child(btn)
	var btn2 := Button.new()
	btn2.text = "MENU"
	btn2.custom_minimum_size = Vector2(220, 76)
	btn2.add_theme_font_size_override("font_size", 30)
	btn2.pressed.connect(func(): menu_pressed.emit())
	bbox.add_child(btn2)


func setup(p) -> void:
	player = p
	my_team = p.team
	Game.currency_changed.connect(_on_currency)
	_on_currency(false)
	p.health_changed.connect(_on_health)
	p.ammo_changed.connect(_on_ammo)
	p.fired.connect(_on_fired)
	p.hit_confirmed.connect(_on_hit)
	p.damaged.connect(_on_damaged)
	p.weapon_changed.connect(_on_weapon_changed)
	p.role_changed.connect(_on_role_changed)
	p.skill_fx.connect(_on_skill_fx)
	skillfx.player = p
	ca.player = p
	p.leveled_up.connect(func(_lv: int) -> void: ca.level_up())
	p.infect_made.connect(func() -> void: ca.infected_flash())
	_on_health(p.hp)
	_on_weapon_changed(p.slot)
	_on_ammo(p.mag, p.reserve)


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	vignette.size = s
	vignette.position = Vector2.ZERO

	var wtex: Texture2D = weapon.texture
	var ratio: float = float(wtex.get_height()) / float(wtex.get_width())
	var ww: float = minf(s.x * (0.5 if is_mobile else 0.42), 620.0)
	weapon.size = Vector2(ww, ww * ratio)
	weapon.pivot_offset = weapon.size * Vector2(0.85, 0.9)
	if is_mobile:
		weapon_base = Vector2(s.x * 0.40, s.y - weapon.size.y + 20.0)
	else:
		weapon_base = Vector2(s.x - weapon.size.x + 20.0, s.y - weapon.size.y + 30.0)
	muzzle.pivot_offset = muzzle.size / 2.0

	crosshair.position = s / 2.0 - crosshair.size / 2.0
	hitmarker.position = s / 2.0 - hitmarker.size / 2.0

	hp_icon.position = Vector2(20, 16)
	hp_bg.position = Vector2(74, 24)
	hp_fill.position = hp_bg.position + Vector2(3, 3)
	hp_label.position = hp_bg.position + Vector2(12, -2)
	ammo_icon.position = Vector2(s.x - 250, 14)
	ammo_label.position = Vector2(s.x - 190, 12)
	ammo_label.size = Vector2(170, 50)
	var cx := s.x / 2.0
	team_icon_r.position = Vector2(cx - 232, 8)
	score_r.position = Vector2(cx - 180, 4)
	score_r.size = Vector2(110, 52)
	target_label.position = Vector2(cx - 60, 18)
	target_label.size = Vector2(120, 30)
	score_b.position = Vector2(cx + 70, 4)
	score_b.size = Vector2(110, 52)
	team_icon_b.position = Vector2(cx + 186, 8)
	score_label.position = Vector2(cx - 250, 58)
	score_label.size = Vector2(500, 30)
	round_label.position = Vector2(cx - 300, 88)
	round_label.size = Vector2(600, 30)
	coin_icon.position = Vector2(22, 70)
	coin_label.position = Vector2(74, 70)
	coin_label.size = Vector2(160, 44)
	dia_icon.position = Vector2(22, 118)
	dia_label.position = Vector2(74, 118)
	dia_label.size = Vector2(160, 44)
	btn_menu.position = Vector2(20, 172)
	center_label.position = Vector2(0, s.y * 0.26)
	center_label.size = Vector2(s.x, 80)
	feed_box.position = Vector2(s.x - 360, 76)
	feed_box.size = Vector2(340, 140)
	if zombie_mode:
		# tata letak gaya Crisis Action: MENU di pojok kiri atas, minimap di bawahnya, ammo turun dari pojok kanan atas
		btn_menu.position = Vector2(12, 8)
		ammo_icon.position = Vector2(s.x - 250, 96)
		ammo_label.position = Vector2(s.x - 190, 94)

	cur_panel.position = Vector2(cx - 52.0, s.y - 78.0)
	for k in 3:
		slot_panels[k].position = Vector2(cx - 52.0, s.y - 78.0 - (k + 1) * 72.0)
	_set_center(btn_skill, Vector2(s.x - 270, s.y - 300))

	joy_home = Vector2(190, s.y - 190)
	if joy_index == -1:
		_place_joy(joy_home, Vector2.ZERO)
	_set_center(btn_fire, Vector2(s.x - 170, s.y - 170))
	_set_center(btn_jump, Vector2(s.x - 100, s.y - 350))
	_set_center(btn_reload, Vector2(s.x - 350, s.y - 110))
	_update_hp_bar()


func _set_center(c: Control, pos: Vector2) -> void:
	c.position = pos - c.size / 2.0


func _place_joy(center: Vector2, offset: Vector2) -> void:
	joy_base.position = center - joy_base.size / 2.0
	joy_knob.position = center + offset - joy_knob.size / 2.0


# ------------------------------------------------------------------ slot senjata
func _build_slots() -> void:
	for k in 3:
		var d := Weapons.get_weapon(k)
		var p := Panel.new()
		p.size = Vector2(104, 66)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		var ic := TextureRect.new()
		ic.texture = load(A + str(d["icon"]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(88, 40)
		ic.position = Vector2(8, 2)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		var key := _label(16, Color(1, 1, 1, 0.85))
		key.text = str(k + 1)
		key.position = Vector2(6, -2)
		p.add_child(key)
		var am := _label(17, Color(1.0, 0.92, 0.6))
		am.size = Vector2(100, 22)
		am.position = Vector2(2, 40)
		am.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(am)
		slot_panels.append(p)
		slot_icons.append(ic)
		slot_ammo.append(am)


func _build_current_button() -> void:
	cur_panel = Panel.new()
	cur_panel.size = Vector2(104, 66)
	cur_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cur_panel)
	cur_icon = TextureRect.new()
	cur_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cur_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cur_icon.size = Vector2(88, 40)
	cur_icon.position = Vector2(8, 2)
	cur_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur_panel.add_child(cur_icon)
	cur_ammo = _label(17, Color(1.0, 0.92, 0.6))
	cur_ammo.size = Vector2(100, 22)
	cur_ammo.position = Vector2(2, 40)
	cur_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cur_panel.add_child(cur_ammo)
	cur_panel.add_theme_stylebox_override("panel", _slot_style(true))


func _set_menu(open: bool) -> void:
	menu_open = open
	_refresh_slots()


const CHOICE_TIME := 10.0
const ZOMBIE_CARDS := [
	{"id": "biasa", "name": "ZOMBIE BIASA", "img": "portrait_biasa.png", "hp": 850, "skill": "Lari: kecepatan naik 7 detik"},
	{"id": "gendut", "name": "ZOMBIE GENDUT", "img": "portrait_gendut.png", "hp": 1250, "skill": "Perisai: damage -95% 9 detik"},
	{"id": "suster", "name": "ZOMBIE SUSTER", "img": "portrait_suster.png", "hp": 1000, "skill": "Kabut virus: menghilang 8 detik"},
]
var choice_cards: Array = []
var choice_sel := 0
var choice_left := 0.0
var choice_btn: Button


func _card_style(sel: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.92)
	sb.set_border_width_all(5 if sel else 2)
	sb.border_color = Color(1.0, 0.75, 0.1) if sel else Color(0.35, 0.4, 0.45)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	return sb


func _build_choice() -> void:
	choice_layer = Control.new()
	choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.visible = false
	root.add_child(choice_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.05, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var t := _label(34, Color(0.7, 0.95, 0.3))
	t.text = "KAMU TERINFEKSI!  Pilih jenis zombie"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	choice_cards.clear()
	for i in ZOMBIE_CARDS.size():
		var d: Dictionary = ZOMBIE_CARDS[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 0)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("panel", _card_style(false))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var pic := TextureRect.new()
		pic.texture = load(A + str(d["img"]))
		pic.custom_minimum_size = Vector2(242, 290)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pic)
		var nm := _label(22, Color(1, 1, 1))
		nm.text = str(d["name"])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		var info := _label(17, Color(0.78, 0.8, 0.82))
		info.text = "HP %d\n%s\nCooldown 40 detik" % [int(d["hp"]), str(d["skill"])]
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(info)
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if choice_sel == i:
					_confirm_choice()
				else:
					_select_choice(i))
		row.add_child(card)
		choice_cards.append(card)
	choice_btn = Button.new()
	choice_btn.focus_mode = Control.FOCUS_NONE
	choice_btn.custom_minimum_size = Vector2(300, 52)
	choice_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choice_btn.add_theme_font_size_override("font_size", 26)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.95, 0.72, 0.25)
	bs.set_corner_radius_all(4)
	choice_btn.add_theme_stylebox_override("normal", bs)
	choice_btn.add_theme_stylebox_override("hover", bs)
	choice_btn.add_theme_stylebox_override("pressed", bs)
	choice_btn.add_theme_color_override("font_color", Color(0.35, 0.15, 0.0))
	choice_btn.add_theme_color_override("font_hover_color", Color(0.35, 0.15, 0.0))
	choice_btn.add_theme_color_override("font_pressed_color", Color(0.35, 0.15, 0.0))
	choice_btn.pressed.connect(_confirm_choice)
	box.add_child(choice_btn)
	_select_choice(0)


func _select_choice(i: int) -> void:
	choice_sel = clampi(i, 0, ZOMBIE_CARDS.size() - 1)
	for k in choice_cards.size():
		choice_cards[k].add_theme_stylebox_override("panel", _card_style(k == choice_sel))
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -6.0)


func _confirm_choice() -> void:
	if not choice_layer.visible:
		return
	zombie_chosen.emit(str(ZOMBIE_CARDS[choice_sel]["id"]))


func _update_choice_btn() -> void:
	var t := int(ceil(maxf(choice_left, 0.0)))
	choice_btn.text = "Memilih   %02d:%02d" % [t / 60, t % 60]


func _unhandled_input(ev: InputEvent) -> void:
	if choice_layer != null and choice_layer.visible and ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1, KEY_2, KEY_3:
				_select_choice(ev.keycode - KEY_1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_confirm_choice()


func show_infect_choice() -> void:
	choice_left = CHOICE_TIME
	_select_choice(0)
	_update_choice_btn()
	choice_layer.visible = true
	if player != null:
		player.touch_fire = false
		player.move_input = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_infect_choice() -> void:
	choice_layer.visible = false


# poin ronde mode Zombie: "RONDE 2/3   POIN  MANUSIA 1 - 0 ZOMBIE"
func set_round_info(round_no: int, to_win: int, human_pts: int, zombie_pts: int) -> void:
	cur_round = round_no
	round_label.visible = not zombie_mode
	round_label.text = "RONDE %d    POIN   MANUSIA %d  -  %d ZOMBIE    (menang di %d poin)" % [round_no, human_pts, zombie_pts, to_win]


func play_round_result(humans_win: bool, reason: String, round_no: int, human_pts: int, zombie_pts: int, seconds: float) -> void:
	show_center("")
	roundfx.play(humans_win, reason, "RONDE %d   MANUSIA %d  :  %d ZOMBIE" % [round_no, human_pts, zombie_pts], seconds)


func stop_round_result() -> void:
	roundfx.stop()


func enter_zombie_mode() -> void:
	zombie_mode = true
	ca.visible = true
	for n in [hp_icon, hp_bg, hp_fill, hp_label, score_label, target_label, score_r, score_b, round_label, feed_box, coin_icon, coin_label, dia_icon, dia_label]:
		if n != null:
			n.visible = false
	_layout()
	team_icon_r.visible = false
	team_icon_b.visible = false
	score_r.add_theme_color_override("font_color", Game.team_color("human"))
	score_b.add_theme_color_override("font_color", Game.team_color("zombie"))


func set_map(a: float, lines: Array, rw: float, rects: Array) -> void:
	ca.set_map(a, lines, rw, rects)


func set_virus(n: int) -> void:
	ca.set_virus(n)


func set_zombie_info(humans: int, zombies: int, time_left: float, role: String, k: int, d: int) -> void:
	zt_total = maxi(zt_total, humans + zombies)
	ca.set_info(humans, zombies, time_left, cur_round, role, zt_total)
	score_r.text = str(humans)
	score_b.text = str(zombies)
	var t := int(ceil(time_left))
	target_label.text = "%d:%02d" % [t / 60, t % 60]
	var rn := "MANUSIA"
	if role == "zombie":
		rn = "ZOMBIE"
	elif role == "samurai":
		rn = "SAMURAI"
	score_label.text = "MANUSIA %d  vs  ZOMBIE %d    (%s)    KILL %d    MATI %d" % [humans, zombies, rn, k, d]
	score_label.add_theme_color_override("font_color", Game.team_color("zombie" if role == "zombie" else "human"))


func _on_role_changed(r: String) -> void:
	menu_open = false
	weapon.modulate = Color.WHITE
	hand_frame = 0
	btn_skill.visible = (r == "zombie" or r == "samurai")
	if r == "samurai":
		btn_skill.self_modulate = Color(1.2, 0.5, 0.5)
	elif player != null and player.ztype == "gendut":
		btn_skill.self_modulate = Color(0.5, 0.7, 1.25)
	elif player != null and player.ztype == "suster":
		btn_skill.self_modulate = Color(0.6, 1.2, 0.7)
	else:
		btn_skill.self_modulate = Color(1.25, 0.8, 0.4)
	_on_weapon_changed(0)   # sinkronkan gambar tangan/senjata dengan peran baru (cakar, kepalan, katana)
	_refresh_slots()
	_update_hp_bar()


func _on_skill_fx(kind: String) -> void:
	skillfx.trigger(kind)
	if kind == "heavy":
		heavy_t = 1.0


func _slot_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.11, 0.75)
	sb.border_color = Color(1.0, 0.85, 0.3) if active else Color(1, 1, 1, 0.25)
	sb.set_border_width_all(4 if active else 2)
	sb.set_corner_radius_all(8)
	return sb


func _refresh_slots() -> void:
	if player == null or slot_panels.is_empty() or cur_panel == null:
		return
	var human: bool = (player.role == "human")
	cur_panel.visible = human
	var cd: Dictionary = player.w
	cur_icon.texture = load(A + str(cd["icon"]))
	if bool(cd["melee"]):
		cur_ammo.text = "--"
	else:
		cur_ammo.text = "%d/%d" % [player.mag, player.reserve]
	for k in 3:
		slot_panels[k].visible = human and menu_open
		var active: bool = (k == player.slot)
		slot_panels[k].add_theme_stylebox_override("panel", _slot_style(active))
		slot_icons[k].modulate = Color.WHITE if active else Color(0.7, 0.7, 0.75)
		if bool(Weapons.get_weapon(k)["melee"]):
			slot_ammo[k].text = "--"
		else:
			var m: int = player.mag if active else int(player.mags[k])
			var r: int = player.reserve if active else int(player.reserves[k])
			slot_ammo[k].text = "%d/%d" % [m, r]


func _on_weapon_changed(_s: int) -> void:
	var d: Dictionary = player.w if player != null else Weapons.get_weapon(0)
	weapon.texture = load(A + str(d["fp"]))
	muzzle_frac = d["muzzle"]
	swing = 0.0
	_refresh_slots()


# ------------------------------------------------------------------ API dari main
func set_score(red: int, blue: int, target: int, k: int, d: int) -> void:
	score_r.text = str(red)
	score_b.text = str(blue)
	target_label.text = "target %d" % target
	score_label.text = "TIM %s    KILL %d    MATI %d" % [Game.team_name(my_team), k, d]
	score_label.add_theme_color_override("font_color", Game.team_color(my_team))


func _on_currency(pop: bool = true) -> void:
	coin_label.text = str(Game.coins)
	dia_label.text = str(Game.diamonds)
	if pop:
		coin_pop = 1.0
		dia_pop = 1.0


func add_feed(text: String, col: Color = Color.WHITE) -> void:
	if zombie_mode:
		ca.add_feed(text, col)
		return
	var l := _label(22, col)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed_box.add_child(l)
	while feed_box.get_child_count() > 4:
		var old := feed_box.get_child(0)
		feed_box.remove_child(old)
		old.queue_free()
	get_tree().create_timer(4.0).timeout.connect(_free_if_valid.bind(l))


func _free_if_valid(n: Node) -> void:
	if is_instance_valid(n):
		n.queue_free()


func show_center(text: String, seconds: float = 0.0) -> void:
	center_token += 1
	center_label.text = text
	if seconds > 0.0:
		var token := center_token
		await get_tree().create_timer(seconds).timeout
		if token == center_token:
			center_label.text = ""


func show_result(win: bool, stats: String, reward_coins: int, reward_dia: int) -> void:
	result_title.text = "MENANG!" if win else "KALAH"
	result_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if win else Color(1.0, 0.4, 0.4))
	result_stats.text = stats
	result_reward.text = "Hadiah  +%d koin    +%d diamond" % [reward_coins, reward_dia]
	result_total.text = "Total: %d koin, %d diamond" % [Game.coins, Game.diamonds]
	result_layer.visible = true
	result_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Fx.sfx2d(self, "res://assets/sfx/win.wav" if win else "res://assets/sfx/lose.wav", -2.0)


# ------------------------------------------------------------------ event pemain
func _on_health(hp: int) -> void:
	hp_cur = hp
	hp_label.text = str(hp)
	_update_hp_bar()


func _update_hp_bar() -> void:
	var mx := 100.0
	if player != null:
		mx = float(player.max_hp)
	var r := clampf(float(hp_cur) / mx, 0.0, 1.0)
	hp_fill.size.x = maxf(294.0 * r, 1.0)
	hp_fill.modulate = Color(1.0, 0.35, 0.35) if r < 0.35 else Color.WHITE


func _on_ammo(mag: int, reserve: int) -> void:
	if player != null and bool(player.w["melee"]):
		ammo_label.text = "--"
	else:
		ammo_label.text = "%d / %d" % [mag, reserve]
	_refresh_slots()


func _on_fired() -> void:
	if player != null and bool(player.w["melee"]):
		swing = 1.0
		kick = 0.2
		return
	kick = 1.0
	flash_t = 0.05
	muzzle.rotation = randf() * TAU
	muzzle.scale = Vector2.ONE * randf_range(0.8, 1.2)


func _on_hit(killed: bool, headshot: bool) -> void:
	hit_t = 1.2
	hitmarker.modulate = Color(1.0, 0.2, 0.2) if (killed or headshot) else Color.WHITE


func _on_damaged() -> void:
	vig = 0.9


# ------------------------------------------------------------------ animasi
func _process(delta: float) -> void:
	if choice_layer != null and choice_layer.visible:
		choice_left -= delta
		_update_choice_btn()
		if choice_left <= 0.05:
			_confirm_choice()   # waktu habis: pakai pilihan yang sedang disorot
	if player == null:
		return
	bob_t += delta
	icon_t += delta
	coin_pop = move_toward(coin_pop, 0.0, delta * 2.5)
	dia_pop = move_toward(dia_pop, 0.0, delta * 2.5)
	var ci := int(icon_t * 11.0) % 8
	var di := int(icon_t * 9.0) % 8
	coin_icon.texture = coin_frames[ci]
	dia_icon.texture = dia_frames[di]
	result_coin_icon.texture = coin_frames[ci]
	result_dia_icon.texture = dia_frames[di]
	coin_icon.scale = Vector2.ONE * (1.0 + coin_pop * 0.4)
	dia_icon.scale = Vector2.ONE * (1.0 + dia_pop * 0.4)
	if btn_skill.visible:
		var scd: float = player.skill_cd if player.role == "zombie" else player.heavy_cd
		var snm := "BERAT"
		if player.role == "zombie":
			snm = "PERISAI" if player.ztype == "gendut" else ("KABUT" if player.ztype == "suster" else "LARI")
		skill_label.text = (snm if scd <= 0.0 else str(int(ceil(scd)))) + ("" if is_mobile else "\n[E]")
		btn_skill.modulate.a = 1.0 if scd <= 0.0 else 0.45
	var vel: Vector3 = player.velocity
	var spd: float = Vector2(vel.x, vel.z).length() / 6.5
	kick = move_toward(kick, 0.0, delta * 8.0)
	var reloading: bool = player.reloading
	reload_drop = lerpf(reload_drop, 150.0 if reloading else 0.0, minf(1.0, delta * 9.0))
	var bob := Vector2(cos(bob_t * 7.0) * 7.0, absf(sin(bob_t * 7.0)) * 9.0) * spd
	weapon.position = weapon_base + bob + Vector2(kick * 10.0, kick * 22.0 + reload_drop)
	swing = move_toward(swing, 0.0, delta * 4.0)
	var sw := sin(swing * PI)
	var zrot := 0.0
	if player.role == "zombie":
		# tangan zombie bergerak-gerak terus (2 gambar bergantian); makin cepat kalau berjalan
		hand_t += delta * (1.0 + spd * 2.0)
		var fi := int(hand_t / 0.25) % 2
		# gambar tangan sesuai karakter: 0/1 bergantian, 2 = loncat, 3 = sedang skill
		var skill_on: bool = player.run_t > 0.0 or player.shield_t > 0.0 or player.invis_t > 0.0
		if skill_on:
			fi = 3
		elif not player.is_on_floor():
			fi = 2
		if fi != hand_frame:
			hand_frame = fi
			var nm := "zombie_hands_%d.png"
			if player.ztype == "gendut":
				nm = "gendut_fists_%d.png"
			elif player.ztype == "suster":
				nm = "suster_hands_%d.png"
			weapon.texture = load(A + (nm % fi))
		# gerak tangan terus-menerus: pelari mengais liar, gendut mengayun berat
		if player.ztype == "gendut":
			weapon.position += Vector2(sin(hand_t * 2.6) * 14.0, absf(sin(hand_t * 2.6)) * 16.0)
		else:
			weapon.position += Vector2(sin(hand_t * 5.3) * 20.0, cos(hand_t * 7.1) * 12.0)
			zrot = sin(hand_t * 6.0) * 0.07
	if player.role == "zombie" and player.ztype == "gendut":
		# zombie gendut: pukulan lurus ke depan
		weapon.position += Vector2(0.0, -sw * 120.0)
		weapon.rotation = 0.0
		weapon.scale = Vector2.ONE * (1.0 + sw * 0.4)
	else:
		weapon.scale = Vector2.ONE
		weapon.position += Vector2(-sw * 90.0, -sw * 30.0)
		weapon.rotation = -kick * 0.035 - sw * 0.6 + zrot
		if player.role == "samurai":
			weapon.position += Vector2(-sw * 60.0, sw * 10.0)
			weapon.rotation = -kick * 0.035 - sw * 1.1 + sin(bob_t * 1.8) * 0.03   # tebasan pedang + goyang napas

	# animasi skill di tangan first-person (satu gambar + kode): tebasan berat, getar saat lari, kilau perisai
	heavy_t = move_toward(heavy_t, 0.0, delta * 1.8)
	if heavy_t > 0.0 and player.role == "samurai":
		var hs := sin(heavy_t * PI)
		weapon.position += Vector2(-hs * 150.0, -hs * 70.0)
		weapon.rotation -= hs * 1.3
		weapon.scale = Vector2.ONE * (1.0 + hs * 0.25)
	if player.run_t > 0.0:
		weapon.position += Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
	var wm := Color.WHITE
	if player.run_t > 0.0:
		wm = Color(1.35, 0.7, 0.65)
	elif player.shield_t > 0.0:
		wm = Color(0.65, 0.85, 1.4).lerp(Color.WHITE, 0.2 + 0.25 * (0.5 + 0.5 * sin(bob_t * 8.0)))
	if player.invis_t > 0.0:
		wm = Color(0.8, 1.15, 0.85, 0.8)
	weapon.modulate = wm

	flash_t -= delta
	muzzle.visible = flash_t > 0.0
	muzzle.position = weapon.position + weapon.size * muzzle_frac - muzzle.size / 2.0

	hit_t = maxf(hit_t - delta * 4.0, 0.0)
	hitmarker.modulate.a = clampf(hit_t, 0.0, 1.0)
	var spread := 1.0 + spd * 0.5 + kick * 0.6
	crosshair.scale = Vector2.ONE * spread

	vig = move_toward(vig, 0.0, delta * 0.9)
	var low := 0.0
	if hp_cur > 0 and float(hp_cur) / float(player.max_hp) < 0.3:
		low = 0.3 + 0.15 * sin(bob_t * 6.0)
	vignette.modulate.a = maxf(vig, low)


# ------------------------------------------------------------------ kontrol sentuh
func _input(event: InputEvent) -> void:
	if not is_mobile or player == null or result_open or choice_layer.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_t_down(event.index, event.position)
		else:
			_t_up(event.index)
	elif event is InputEventScreenDrag:
		_t_drag(event.index, event.position, event.relative)


func _hit(c: Control, pos: Vector2) -> bool:
	var ctr := c.position + c.size / 2.0
	return pos.distance_to(ctr) <= c.size.x * 0.58


func _t_down(i: int, pos: Vector2) -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if ca.visible and ca.auto_rect.grow(8.0).has_point(pos):
		touches[i] = "btn"
		player.auto_fire = not player.auto_fire
		return
	if cur_panel.visible:
		if menu_open:
			for k in 3:
				if Rect2(slot_panels[k].position, slot_panels[k].size).grow(6.0).has_point(pos):
					touches[i] = "btn"
					player.switch_weapon(k)
					_set_menu(false)
					return
		if Rect2(cur_panel.position, cur_panel.size).grow(6.0).has_point(pos):
			touches[i] = "btn"
			_set_menu(not menu_open)
			return
		if menu_open:
			_set_menu(false)
	if btn_skill.visible and _hit(btn_skill, pos):
		touches[i] = "btn"
		player.skill_req = true
	elif _hit(btn_fire, pos):
		touches[i] = "fire"
		player.touch_fire = true
		btn_fire.modulate.a = 1.0
	elif _hit(btn_reload, pos):
		touches[i] = "btn"
		player.reload_req = true
	elif _hit(btn_jump, pos):
		touches[i] = "btn"
		player.jump_req = true
	elif pos.x < s.x * 0.45 and joy_index == -1:
		joy_index = i
		touches[i] = "joy"
		joy_center = pos
		_place_joy(pos, Vector2.ZERO)
		joy_base.modulate.a = 1.0
	else:
		touches[i] = "look"


func _t_up(i: int) -> void:
	var role: String = touches.get(i, "")
	if role == "fire":
		player.touch_fire = false
		btn_fire.modulate.a = 0.85
	elif role == "joy":
		joy_index = -1
		player.move_input = Vector2.ZERO
		_place_joy(joy_home, Vector2.ZERO)
		joy_base.modulate.a = 0.7
	touches.erase(i)


func _t_drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var role: String = touches.get(i, "")
	if role == "joy":
		var v := pos - joy_center
		if v.length() > JOY_R:
			v = v.normalized() * JOY_R
		player.move_input = v / JOY_R
		_place_joy(joy_center, v)
	elif role == "look" or role == "fire":
		player.look_delta += rel
