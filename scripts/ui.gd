extends RefCounted
# Helper UI bersama (menu & lobi): label, ikon, gaya tombol, toast, popup.

const A := "res://assets/"


static func label(text: String, fsize: int, col: Color = Color.WHITE, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", maxi(2, int(fsize / 8.0)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func icon(sz: Vector2, tex: Texture2D = null) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = sz
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = tex
	return r


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


static func style_button(btn: Button, bg: Color, border: Color, width: int = 2, radius: int = 10) -> void:
	btn.add_theme_stylebox_override("normal", box(bg, border, width, radius))
	btn.add_theme_stylebox_override("hover", box(bg.lightened(0.12), border, width, radius))
	btn.add_theme_stylebox_override("pressed", box(bg.darkened(0.15), border, width, radius))
	btn.add_theme_stylebox_override("disabled", box(bg.darkened(0.4), border.darkened(0.4), width, radius))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.focus_mode = Control.FOCUS_NONE


# Pesan singkat di bawah layar (hilang sendiri).
static func toast(host: Control, text: String) -> void:
	var old = host.get_meta("toast", null)
	if old != null and is_instance_valid(old):
		old.queue_free()
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.alignment = BoxContainer.ALIGNMENT_END
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := box(Color(0, 0, 0, 0.85), Color(1, 1, 1, 0.3), 2, 12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label(text, 24, Color.WHITE, false))
	holder.add_child(panel)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 120)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gap)
	host.add_child(holder)
	host.set_meta("toast", holder)
	var tw := holder.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(holder, "modulate:a", 0.0, 0.4)
	tw.tween_callback(holder.queue_free)


# Jendela popup di tengah layar dengan tombol tutup. Mengembalikan layer-nya.
static func popup(host: Control, title: String, content: Control) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	var sb := box(Color(0.08, 0.1, 0.16, 0.98), Color(1, 0.85, 0.3, 0.9), 3, 16)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tl := label(title, 32, Color(1.0, 0.9, 0.5))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := Button.new()
	close.text = "TUTUP"
	close.custom_minimum_size = Vector2(120, 48)
	close.add_theme_font_size_override("font_size", 22)
	style_button(close, Color(0.6, 0.15, 0.15), Color(1, 1, 1, 0.5))
	close.pressed.connect(layer.queue_free)
	head.add_child(close)
	vb.add_child(content)
	return layer


# Pindah layar lewat tab bawah (MAIN / BATTLE / ENHANCE / SOCIAL).
static func go_tab(host: Control, from_tab: String, to_tab: String) -> void:
	if to_tab == from_tab:
		return
	var scenes := {"MAIN": "res://menu.tscn", "BATTLE": "res://modes.tscn", "ENHANCE": "res://enhance.tscn"}
	if not scenes.has(to_tab):
		toast(host, "%s segera hadir" % to_tab)
		return
	Game.save_game()
	host.get_tree().change_scene_to_file(str(scenes[to_tab]))
