extends HBoxContainer
# Tab bawah: MAIN / BATTLE / ENHANCE / SOCIAL (seperti di screenshot).

const Ui = preload("res://scripts/ui.gd")

signal tab_pressed(tab_name: String)

var current := "MAIN"
const TABS := ["MAIN", "BATTLE", "ENHANCE", "SOCIAL"]


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	for tab_name in TABS:
		var b := Button.new()
		b.text = tab_name
		b.custom_minimum_size = Vector2(200, 62)
		b.add_theme_font_size_override("font_size", 26)
		var on: bool = (tab_name == current)
		Ui.style_button(b, Color(0.1, 0.4, 0.78, 0.96) if on else Color(0.1, 0.11, 0.16, 0.92),
				Color(0.5, 0.8, 1.0) if on else Color(1, 1, 1, 0.15), 3 if on else 2, 4)
		b.pressed.connect(func(): tab_pressed.emit(tab_name))
		add_child(b)
		if tab_name == "BATTLE":
			var badge := Ui.label("NEW", 14, Color.WHITE, false)
			badge.add_theme_stylebox_override("normal", Ui.box(Color(0.25, 0.65, 0.2), Color(0, 0, 0, 0), 0, 3))
			badge.position = Vector2(10, -8)
			b.add_child(badge)
