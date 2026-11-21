extends Control
# Efek layar untuk skill, dibuat dari KODE (garis, busur, lingkaran) tanpa banyak gambar:
#  - LARI (zombie biasa/induk): garis kecepatan radial + tepi merah + kilat
#  - PERISAI (zombie gendut): bingkai biru berdenyut + cincin gelombang
#  - TEBASAN BERAT (samurai): busur tebasan menyala yang menyapu layar + cincin kejut
#  - Cincin cooldown di tombol skill + kilau saat skill siap lagi
# Suara diputar di player.gd (skill_run.wav, shield_on.wav, shield_off.wav, slash_big.wav, skill_ready.wav).

const PlayerScript = preload("res://scripts/player.gd")

var player
var button: Control          # tombol skill di HUD
var t := 0.0
var run_k := 0.0
var shield_k := 0.0
var slash_t := -1.0          # -1 = tidak aktif, 0..1 = progres tebasan
var slash_dir := 1.0
var shock_t := -1.0
var burst_t := 0.0
var burst_col := Color.WHITE
var ready_t := 0.0
var mist_k := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func trigger(kind: String) -> void:
	match kind:
		"run":
			burst_t = 1.0
			burst_col = Color(1.0, 0.35, 0.25)
		"shield":
			burst_t = 1.0
			burst_col = Color(0.35, 0.65, 1.0)
			shock_t = 0.0
		"mist":
			burst_t = 1.0
			burst_col = Color(0.4, 1.0, 0.5)
			shock_t = 0.0
		"shield_end":
			burst_t = 0.7
			burst_col = Color(0.5, 0.7, 1.0)
		"heavy":
			slash_t = 0.0
			slash_dir = -slash_dir
			shock_t = 0.0
			burst_t = 0.8
			burst_col = Color(1.0, 1.0, 1.0)
		"ready":
			ready_t = 1.0


func _process(delta: float) -> void:
	t += delta
	if player != null and is_instance_valid(player):
		run_k = move_toward(run_k, 1.0 if player.run_t > 0.0 else 0.0, delta * 4.0)
		shield_k = move_toward(shield_k, 1.0 if player.shield_t > 0.0 else 0.0, delta * 4.0)
		mist_k = move_toward(mist_k, 1.0 if player.invis_t > 0.0 else 0.0, delta * 3.0)
	if slash_t >= 0.0:
		slash_t += delta / 0.45
		if slash_t > 1.0:
			slash_t = -1.0
	if shock_t >= 0.0:
		shock_t += delta / 0.6
		if shock_t > 1.0:
			shock_t = -1.0
	burst_t = move_toward(burst_t, 0.0, delta * 3.0)
	ready_t = move_toward(ready_t, 0.0, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	var s := size
	var c := s / 2.0
	var diag := s.length()

	if burst_t > 0.01:
		draw_rect(Rect2(Vector2.ZERO, s), Color(burst_col.r, burst_col.g, burst_col.b, 0.25 * burst_t), true)

	# garis kecepatan (skill lari)
	if run_k > 0.01:
		var n := 34
		var seed_t := int(t * 18.0)
		for i in n:
			var h := float((i * 73 + seed_t * 31) % 100) / 100.0
			var ang := TAU * float(i) / float(n) + h * 0.2
			var r0 := diag * (0.22 + h * 0.12)
			var r1 := r0 + diag * (0.16 + h * 0.2)
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(c + dir * r0, c + dir * r1, Color(1.0, 0.45, 0.35, 0.5 * run_k * (0.4 + h * 0.6)), 2.0 + h * 3.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.2, 0.1, 0.08 * run_k), true)

	# kabut virus hijau (zombie suster): gumpalan kabut melayang + tepi hijau
	if mist_k > 0.01:
		for i in 14:
			var ph := float(i) * 1.7
			var mx := s.x * (0.5 + 0.55 * sin(t * 0.35 + ph))
			var my := s.y * (0.5 + 0.5 * cos(t * 0.27 + ph * 1.3))
			draw_circle(Vector2(mx, my), s.y * (0.16 + 0.05 * sin(t + ph)), Color(0.35, 0.95, 0.45, 0.07 * mist_k))
		for i in 8:
			var m2 := 7.0 * float(i)
			draw_rect(Rect2(Vector2(m2, m2), s - Vector2(m2, m2) * 2.0), Color(0.3, 1.0, 0.45, (1.0 - float(i) / 8.0) * 0.22 * mist_k), false, 7.0)

	# bingkai perisai (zombie gendut)
	if shield_k > 0.01:
		var pulse := 0.6 + 0.25 * sin(t * 6.0)
		for i in 12:
			var f := float(i) / 12.0
			var m := 6.0 * float(i)
			var rc := Rect2(Vector2(m, m), s - Vector2(m, m) * 2.0)
			draw_rect(rc, Color(0.35, 0.65, 1.0, (1.0 - f) * 0.35 * shield_k * pulse), false, 6.0)
		draw_arc(c, diag * 0.2 + sin(t * 3.0) * 8.0, 0.0, TAU, 48, Color(0.5, 0.8, 1.0, 0.12 * shield_k), 3.0, true)

	# tebasan berat samurai: busur menyala yang menyapu
	if slash_t >= 0.0:
		var p := slash_t
		var reveal := clampf(p * 2.2, 0.0, 1.0)
		var fade := clampf(1.6 - p * 1.6, 0.0, 1.0)
		var tail := clampf(p * 1.2 - 0.2, 0.0, 1.0)
		var rad := diag * 0.34
		var origin := c + Vector2(0.0, diag * 0.1)
		var a0 := deg_to_rad(195.0)
		var a1 := deg_to_rad(345.0)
		var pts := PackedVector2Array()
		var steps := 40
		for i in steps + 1:
			var f := float(i) / float(steps)
			var u := lerpf(tail, reveal, f)
			var a := lerpf(a0, a1, u)
			var v := Vector2(cos(a) * rad * slash_dir, sin(a) * rad * 0.8)
			pts.append(origin + v.rotated(-0.35 * slash_dir))
		if pts.size() >= 2 and reveal > tail:
			draw_polyline(pts, Color(0.5, 0.85, 1.0, 0.25 * fade), 46.0, true)
			draw_polyline(pts, Color(0.8, 0.95, 1.0, 0.6 * fade), 20.0, true)
			draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95 * fade), 7.0, true)

	# cincin kejut (perisai menyala / tebasan berat)
	if shock_t >= 0.0:
		var k := shock_t
		draw_arc(c, diag * (0.05 + 0.5 * k), 0.0, TAU, 64, Color(burst_col.r, burst_col.g, burst_col.b, 0.6 * (1.0 - k)), 8.0 * (1.0 - k) + 2.0, true)

	_draw_button_ring()


# cincin cooldown di sekeliling tombol skill + denyut saat siap
func _draw_button_ring() -> void:
	if button == null or not is_instance_valid(button) or not button.visible or player == null:
		return
	var bc: Vector2 = button.position + button.size / 2.0
	var rad: float = button.size.x * 0.58
	var total := PlayerScript.HEAVY_CD
	var cd: float = player.heavy_cd
	if player.role == "zombie":
		total = PlayerScript.SKILL_CD
		cd = player.skill_cd
	var frac := 1.0 - clampf(cd / total, 0.0, 1.0)
	draw_arc(bc, rad, 0.0, TAU, 40, Color(0, 0, 0, 0.45), 6.0, true)
	if frac > 0.001:
		draw_arc(bc, rad, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(1.0, 0.85, 0.3) if cd <= 0.0 else Color(0.7, 0.75, 0.85), 6.0, true)
	if cd <= 0.0:
		draw_arc(bc, rad + 6.0 + 6.0 * absf(sin(t * 4.0)), 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.5), 3.0, true)
	if player.role == "zombie":
		var act: float = 0.0
		if player.run_t > 0.0:
			act = player.run_t / PlayerScript.RUN_TIME
		elif player.shield_t > 0.0:
			act = player.shield_t / PlayerScript.SHIELD_TIME
		elif player.invis_t > 0.0:
			act = player.invis_t / PlayerScript.MIST_TIME
		if act > 0.0:
			draw_arc(bc, rad - 9.0, -PI / 2.0, -PI / 2.0 + TAU * act, 40, Color(0.4, 1.0, 0.5), 5.0, true)
	if ready_t > 0.0:
		draw_circle(bc, rad * (1.0 + (1.0 - ready_t) * 0.6), Color(1.0, 1.0, 0.6, 0.4 * ready_t))
