extends HBoxContainer
# Bar atas: profil (level, nama), koin & diamond beranimasi, tombol pengaturan.

const Ui = preload("res://scripts/ui.gd")
const A := "res://assets/"

signal settings_pressed

var show_profile := true
var coin_icon: TextureRect
var dia_icon: TextureRect
var coin_label: Label
var dia_label: Label
var coin_frames: Array = []
var dia_frames: Array = []
var lvl_label: Label
var exp_fill: ColorRect
var t := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	custom_minimum_size = Vector2(0, 64)
	for i in 8:
		coin_frames.append(load(A + "coin_%d.png" % i))
		dia_frames.append(load(A + "diamond_%d.png" % i))
	if show_profile:
		_build_profile()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)

	coin_icon = Ui.icon(Vector2(44, 44))
	add_child(coin_icon)
	coin_label = Ui.label("0", 30, Color(1.0, 0.88, 0.35))
	add_child(coin_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
	dia_icon = Ui.icon(Vector2(44, 44))
	add_child(dia_icon)
	dia_label = Ui.label("0", 30, Color(0.55, 0.9, 1.0))
	add_child(dia_label)

	var gear := Button.new()
	gear.text = "ATUR"
	gear.custom_minimum_size = Vector2(84, 46)
	gear.add_theme_font_size_override("font_size", 20)
	Ui.style_button(gear, Color(0.12, 0.14, 0.2, 0.9), Color(1, 1, 1, 0.4))
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(func(): settings_pressed.emit())
	add_child(gear)

	Game.currency_changed.connect(_refresh)
	_refresh()


func _total_wins() -> int:
	var n := 0
	for k in Game.wins:
		n += int(Game.wins[k])
	return n


func _build_profile() -> void:
	var wins := _total_wins()
	var level := Game.player_level()
	var ratio := float(wins % 3) / 3.0
	var team_tex: Texture2D = load(A + "team_%s.png" % Game.team)
	var av := Ui.icon(Vector2(56, 56), team_tex)
	av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(av)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vb)
	lvl_label = Ui.label("VIP  LV.%d" % level, 18, Color(0.75, 0.8, 0.9))
	vb.add_child(lvl_label)
	vb.add_child(Ui.label(Game.player_name, 24, Color.WHITE))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(190, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bg)
	exp_fill = ColorRect.new()
	exp_fill.color = Color(0.55, 0.95, 0.2)
	exp_fill.size = Vector2(maxf(190.0 * ratio, 6.0), 10)
	bar.add_child(exp_fill)
	vb.add_child(bar)


func _refresh() -> void:
	coin_label.text = str(Game.coins)
	dia_label.text = str(Game.diamonds)


func _process(delta: float) -> void:
	t += delta
	coin_icon.texture = coin_frames[int(t * 11.0) % 8]
	dia_icon.texture = dia_frames[int(t * 9.0) % 8]
