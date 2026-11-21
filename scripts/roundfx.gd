extends Control
# Animasi hasil ronde (mode Zombie), digambar dari KODE + gambar tangan zombie yang sudah ada:
#  - ZOMBIE MENANG : layar menggelap merah, tiga cakaran menyayat, darah menetes, tangan zombie naik dari bawah, teks hijau bergetar
#  - MANUSIA MENANG: sinar emas berputar, konfeti jatuh, kilau, teks emas membesar (pop)
# Dipanggil dari hud.gd -> play(...)

var active := false
var t := 0.0
var dur := 5.0
var humans_win := false
var title := ""
var sub := ""
var info := ""
var hands_tex: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	hands_tex = load("res://assets/zombie_hands_1.png")


func play(h_win: bool, sub_text: String, info_text: String, seconds: float) -> void:
	humans_win = h_win
	title = "MANUSIA MENANG" if h_win else "ZOMBIE MENANG"
	sub = sub_text
	info = info_text
	dur = seconds
	t = 0.0
	active = true
	visible = true


func stop() -> void:
	active = false
	visible = false


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	if t > dur:
		stop()
		return
	queue_redraw()


func _hash(i: int, salt: int) -> float:
	return float((i * 7919 + salt * 104729) % 1000) / 1000.0


func _draw() -> void:
	if not active:
		return
	var s := size
	var c := s / 2.0
	var fade_out := clampf((dur - t) / 0.5, 0.0, 1.0)
	if humans_win:
		_draw_human(s, c, fade_out)
	else:
		_draw_zombie(s, c, fade_out)
	_draw_texts(s, c, fade_out)


func _draw_zombie(s: Vector2, c: Vector2, fo: float) -> void:
	var k := clampf(t / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.12, 0.0, 0.02, 0.6 * k * fo), true)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.35, 0.05, 0.12 * k * fo), true)
	# tiga cakaran menyayat diagonal
	for i in 3:
		var p := clampf((t - 0.12 * float(i)) / 0.3, 0.0, 1.0)
		if p <= 0.0:
			continue
		var off := Vector2(s.x * (0.28 + 0.2 * float(i)), 0.0)
		var a := Vector2(-s.x * 0.05, -s.y * 0.1) + off
		var b := a + Vector2(s.x * 0.38, s.y * 1.2) * p
		draw_line(a, b, Color(0.5, 0.03, 0.04, 0.9 * fo), 16.0, true)
		draw_line(a + Vector2(6, 0), b + Vector2(6, 0), Color(0.9, 0.12, 0.1, 0.9 * fo), 6.0, true)
	# darah menetes dari atas
	var dp := clampf((t - 0.2) / 1.3, 0.0, 1.0)
	for i in 26:
		var x := s.x * (float(i) + 0.5) / 26.0
		var l := (30.0 + _hash(i, 3) * 140.0) * dp
		draw_line(Vector2(x, 0), Vector2(x, l), Color(0.55, 0.02, 0.04, 0.9 * fo), 8.0 + _hash(i, 5) * 6.0)
		draw_circle(Vector2(x, l), 6.0 + _hash(i, 5) * 3.0, Color(0.55, 0.02, 0.04, 0.9 * fo))
	# tangan zombie naik dari bawah
	if hands_tex != null:
		var rise := clampf((t - 0.3) / 0.6, 0.0, 1.0)
		rise = 1.0 - pow(1.0 - rise, 3.0)
		var w := minf(s.x * 0.75, 760.0)
		var h := w * float(hands_tex.get_height()) / float(hands_tex.get_width())
		var y := s.y - h * 0.85 * rise + sin(t * 3.0) * 6.0 * rise
		draw_texture_rect(hands_tex, Rect2(c.x - w / 2.0, y, w, h), false, Color(1, 1, 1, fo))


func _draw_human(s: Vector2, c: Vector2, fo: float) -> void:
	var k := clampf(t / 0.4, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.08, 0.2, 0.55 * k * fo), true)
	# sinar emas berputar
	var origin := Vector2(c.x, c.y * 0.9)
	var rad := s.length()
	for i in 16:
		var a0 := float(i) * TAU / 16.0 + t * 0.35
		var a1 := a0 + TAU / 32.0
		var pts := PackedVector2Array([origin, origin + Vector2(cos(a0), sin(a0)) * rad, origin + Vector2(cos(a1), sin(a1)) * rad])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, 0.16 * k * fo))
	draw_circle(origin, s.y * (0.28 + 0.02 * sin(t * 4.0)), Color(1.0, 0.9, 0.5, 0.12 * k * fo))
	# konfeti jatuh
	var cols := [Color(1, 0.85, 0.3), Color(0.4, 0.8, 1), Color(1, 0.4, 0.5), Color(0.5, 1, 0.5)]
	for i in 70:
		var x := s.x * _hash(i, 1) + sin(t * 2.0 + float(i)) * 20.0
		var sp := 90.0 + _hash(i, 2) * 160.0
		var y := fposmod(t * sp + _hash(i, 4) * s.y, s.y + 40.0) - 20.0
		var col: Color = cols[i % 4]
		col.a = 0.9 * fo
		draw_set_transform(Vector2(x, y), t * (2.0 + _hash(i, 6) * 4.0), Vector2.ONE)
		draw_rect(Rect2(-5, -3, 10, 6), col, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# kilau bintang
	for i in 10:
		var p := Vector2(s.x * _hash(i, 8), s.y * (0.15 + 0.5 * _hash(i, 9)))
		var tw := 0.5 + 0.5 * sin(t * 5.0 + float(i) * 1.9)
		var r := 10.0 + 14.0 * tw
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color(1, 1, 0.8, 0.9 * tw * fo), 3.0)
		draw_line(p - Vector2(0, r), p + Vector2(0, r), Color(1, 1, 0.8, 0.9 * tw * fo), 3.0)


func _draw_texts(s: Vector2, c: Vector2, fo: float) -> void:
	var f := get_theme_default_font()
	if f == null:
		return
	var pop := 0.0
	if t > 0.3:
		pop = exp(-(t - 0.3) * 4.5) * 0.45
	var sc := clampf((t - 0.15) / 0.25, 0.0, 1.0) * (1.0 + pop)
	var shake := Vector2.ZERO
	if not humans_win and t < 1.2:
		shake = Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, 4.0))
	var col := Color(1.0, 0.85, 0.3, fo) if humans_win else Color(0.55, 1.0, 0.25, fo)
	var size_t := clampi(int(s.x * 0.075), 40, 110)
	draw_set_transform(Vector2(c.x, c.y * 0.82) + shake, 0.0, Vector2(sc, sc))
	draw_string_outline(f, Vector2(-s.x / 2.0, 0), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, size_t, 14, Color(0, 0, 0, fo))
	draw_string(f, Vector2(-s.x / 2.0, 0), title, HORIZONTAL_ALIGNMENT_CENTER, s.x, size_t, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 0.6:
		var a := clampf((t - 0.6) / 0.4, 0.0, 1.0) * fo
		var st := clampi(int(s.x * 0.026), 18, 36)
		draw_string_outline(f, Vector2(0, c.y * 0.82 + size_t * 0.8), sub, HORIZONTAL_ALIGNMENT_CENTER, s.x, st, 8, Color(0, 0, 0, a))
		draw_string(f, Vector2(0, c.y * 0.82 + size_t * 0.8), sub, HORIZONTAL_ALIGNMENT_CENTER, s.x, st, Color(1, 1, 1, a))
		draw_string_outline(f, Vector2(0, c.y * 0.82 + size_t * 0.8 + st * 1.6), info, HORIZONTAL_ALIGNMENT_CENTER, s.x, st, 8, Color(0, 0, 0, a))
		draw_string(f, Vector2(0, c.y * 0.82 + size_t * 0.8 + st * 1.6), info, HORIZONTAL_ALIGNMENT_CENTER, s.x, st, Color(1.0, 0.9, 0.5, a))
