extends Control
# Layar pilih mode (tab BATTLE) sebelum masuk lobi, mengikuti screenshot referensi:
# 2 kartu tinggi di kiri + 3x2 kartu di kanan. Mode terkunci menampilkan gembok + level yang dibutuhkan.

const Ui = preload("res://scripts/ui.gd")
const TopBarScript = preload("res://scripts/topbar.gd")
const TabBarScript = preload("res://scripts/tabbar.gd")
const Fx = preload("res://scripts/fx.gd")
const A := "res://assets/"

# kunci "go": "lobby" = ke lobi dengan mode itu, "soon" = belum ada fiturnya
const CARDS := {
	"ranking": {"title": "RANKING MATCH", "cap": "PERTANDINGAN PERINGKAT", "lv": 10, "color": Color(0.75, 0.5, 0.15), "art": "char_red", "go": "soon"},
	"pve": {"title": "MODE TANTANGAN", "cap": "PVE MODE", "lv": 15, "color": Color(0.2, 0.4, 0.8), "art": "char_samurai", "go": "soon"},
	"zombie": {"title": "MODE ZOMBIE", "cap": "HAVOC REBIRTH", "lv": 1, "color": Color(0.45, 0.35, 0.2), "art": "char_zombie", "go": "lobby", "mode": "zombie"},
	"creation": {"title": "MODE KREASI", "cap": "CREATION MODE", "lv": 22, "color": Color(0.2, 0.45, 0.6), "art": "crate.png", "go": "soon"},
	"mech": {"title": "PERANG MEKA", "cap": "MECH", "lv": 20, "color": Color(0.25, 0.3, 0.5), "art": "container.png", "go": "soon"},
	"fun": {"title": "ARENA HIBURAN", "cap": "ENTERTAINMENT", "lv": 15, "color": Color(0.7, 0.4, 0.15), "art": "diamond_0.png", "go": "soon"},
	"training": {"title": "LATIHAN SOLO", "cap": "TRAINING", "lv": 1, "color": Color(0.1, 0.55, 0.65), "art": "char_blue", "go": "lobby", "mode": "training"},
	"lobby": {"title": "LOBI TEMPUR", "cap": "LOBBY", "lv": 1, "color": Color(0.2, 0.35, 0.6), "art": "team_blue.png", "go": "lobby", "mode": ""},
}

var anim_arts: Array = []     # [TextureRect, [frames]] untuk kartu bergambar karakter
var cards := {}
var t := 0.0
var going := false
var hint: Control
var arrow: Polygon2D


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
	dim.color = Color(0, 0, 0, 0.4)
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
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)
	mid.add_child(_card("ranking", 1.3))
	mid.add_child(_card("pve", 1.3))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 3.0
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	mid.add_child(grid)
	for k in ["zombie", "creation", "mech", "fun", "training", "lobby"]:
		grid.add_child(_card(k, 1.0))

	var tabs := TabBarScript.new()
	tabs.current = "BATTLE"
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.tab_pressed.connect(_on_tab)
	root.add_child(tabs)

	if not Game.hint_done:
		_build_hint.call_deferred()


func _card(key: String, ratio: float) -> Button:
	var info: Dictionary = CARDS[key]
	var locked: bool = Game.player_level() < int(info["lv"])
	var col: Color = info["color"]
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = ratio
	b.custom_minimum_size = Vector2(120, 100)
	b.clip_contents = true
	Ui.style_button(b, col.darkened(0.55), Color(1, 1, 1, 0.35), 2, 6)
	b.pivot_offset = Vector2(100, 100)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	b.add_child(vb)

	# gambar: folder karakter (2 frame idle bergantian lewat kode) atau satu PNG
	var art_name: String = str(info["art"])
	var art := Ui.icon(Vector2(10, 10))
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if art_name.ends_with(".png"):
		art.texture = load(A + art_name)
	else:
		var frames: Array = []
		for i in 2:
			frames.append(load(A + "%s/idle_%d.png" % [art_name, i]))
		art.texture = frames[0]
		anim_arts.append([art, frames, randf() * 2.0])
	art.modulate = Color(0.4, 0.4, 0.46) if locked else Color.WHITE
	vb.add_child(art)

	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 74)
	banner.add_theme_stylebox_override("panel", Ui.box(col.darkened(0.1), Color(0, 0, 0, 0), 0, 0))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", -2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(bv)
	var tl := Ui.label(str(info["title"]), 26 if ratio > 1.0 else 22)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(tl)
	var cl := Ui.label(str(info["cap"]), 13, Color(0.85, 0.9, 1.0, 0.8), false)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(cl)
	vb.add_child(banner)

	if locked:
		var ov := CenterContainer.new()
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov.offset_bottom = -74.0
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ob := VBoxContainer.new()
		ob.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lk := Ui.icon(Vector2(64, 64), load(A + "icon_lock.png"))
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ob.add_child(lk)
		var ll := Ui.label("LV.%d TERBUKA" % int(info["lv"]), 20, Color(1.0, 0.9, 0.5))
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ob.add_child(ll)
		ov.add_child(ob)
		b.add_child(ov)

	b.pressed.connect(_on_card.bind(key, b))
	cards[key] = b
	return b


func _on_card(key: String, b: Button) -> void:
	if going:
		return
	var info: Dictionary = CARDS[key]
	if Game.player_level() < int(info["lv"]):
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0, 0.7)
		Ui.toast(self, "%s terbuka di Level %d (kamu Level %d)" % [str(info["title"]), int(info["lv"]), Game.player_level()])
		_shake(b)
		return
	if str(info["go"]) == "soon":
		Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0, 0.9)
		Ui.toast(self, "%s segera hadir" % str(info["title"]))
		_shake(b)
		return
	going = true
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -2.0, 1.2)
	if info.has("mode") and str(info["mode"]) != "":
		Game.mode = str(info["mode"])
	Game.hint_done = true
	Game.save_game()
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.06, 1.06), 0.1)
	tw.tween_property(b, "scale", Vector2(0.97, 0.97), 0.08)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://lobby.tscn"))


func _shake(b: Control) -> void:
	var tw := b.create_tween()
	for i in 3:
		tw.tween_property(b, "rotation", 0.025, 0.04)
		tw.tween_property(b, "rotation", -0.025, 0.04)
	tw.tween_property(b, "rotation", 0.0, 0.04)


# gelembung petunjuk + panah naik-turun di atas kartu Latihan Solo (seperti referensi)
func _build_hint() -> void:
	var b: Button = cards["training"]
	var p := PanelContainer.new()
	var sb := Ui.box(Color(0.04, 0.1, 0.2, 0.95), Color(0.3, 0.7, 1.0), 3, 8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(Ui.label("Pilih Latihan Solo", 24, Color.WHITE, false))
	add_child(p)
	hint = p
	arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(0, 22)])
	arrow.color = Color(0.4, 0.8, 1.0)
	add_child(arrow)
	var psz: Vector2 = p.get_combined_minimum_size()
	p.position = Vector2(b.global_position.x + b.size.x * 0.5 - psz.x * 0.5, b.global_position.y - 4.0)
	arrow.position = Vector2(b.global_position.x + b.size.x * 0.5, p.position.y + 60.0)


func _process(delta: float) -> void:
	t += delta
	for e in anim_arts:
		var frames: Array = e[1]
		(e[0] as TextureRect).texture = frames[int((t + float(e[2])) * 2.0) % frames.size()]
	if arrow != null and is_instance_valid(arrow):
		var base_y: float = hint.position.y + 60.0
		arrow.position.y = base_y + absf(sin(t * 4.0)) * 14.0
	if Game.hint_done and hint != null and is_instance_valid(hint):
		hint.queue_free()
		arrow.queue_free()
		hint = null
		arrow = null


func _on_tab(tab_name: String) -> void:
	Fx.sfx2d(self, "res://assets/sfx/click.wav", -4.0)
	Ui.go_tab(self, "BATTLE", tab_name)
