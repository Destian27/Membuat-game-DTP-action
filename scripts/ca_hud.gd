extends Control
# Lapisan HUD gaya Crisis Action untuk mode Zombie (v0.0.3.2):
# papan skor atas, minimap, pesan tengah, tombol Otomatis, foto + HP + bar kedua, level zombie (LV / HP+),
# hitung mundur virus, emblem TERINFEKSI, dan cahaya hijau-teal di pandangan zombie.
# Semua digambar lewat kode (_draw), jadi tidak butuh gambar baru selain face_*.png.

const A := "res://assets/"
const ORANGE := Color(1.0, 0.62, 0.16)
const GREEN := Color(0.55, 0.95, 0.25)
const PANEL := Color(0.07, 0.08, 0.1, 0.82)

var player
var arena := 150.0
var road_lines: Array = []
var road_w := 9.0
var buildings: Array = []          # Rect2 (x, z) dari main.gd
var humans := 0
var zombies := 0
var humans_total := 14
var time_left := 0.0
var round_no := 1
var role := "human"
var feed: Array = []               # [teks, warna, umur]
var virus_left := 0
var infect_t := 0.0
var lvl_t := 0.0
var t := 0.0
var auto_rect := Rect2()
var faces := {}
var mm_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["hero", "civil", "biasa", "induk", "gendut", "suster", "samurai"]:
		var path := A + "face_%s.png" % k
		if ResourceLoader.exists(path):
			faces[k] = load(path)


# ------------------------------------------------------------------ API dari hud.gd / main.gd
func set_map(a: float, lines: Array, rw: float, rects: Array) -> void:
	arena = a
	road_lines = lines
	road_w = rw
	buildings = rects


func set_info(h: int, z: int, tl: float, rn: int, r: String, total: int) -> void:
	humans = h
	zombies = z
	time_left = tl
	round_no = rn
	role = r
	humans_total = maxi(total, 1)


func add_feed(text: String, col: Color) -> void:
	feed.append([text, col, 0.0])
	while feed.size() > 3:
		feed.pop_front()


func level_up() -> void:
	lvl_t = 2.6


func infected_flash() -> void:
	infect_t = 2.2


func set_virus(n: int) -> void:
	virus_left = n


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	infect_t = maxf(infect_t - delta, 0.0)
	lvl_t = maxf(lvl_t - delta, 0.0)
	for f in feed:
		f[2] += delta
	while not feed.is_empty() and float(feed[0][2]) > 5.0:
		feed.pop_front()
	queue_redraw()


# ------------------------------------------------------------------ gambar
func _txt(font: Font, pos: Vector2, text: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, ol := 4) -> void:
	draw_string_outline(font, pos, text, align, width, fs, ol, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, align, width, fs, col)


func _poly(pts: Array, col: Color, line_col: Color = Color(0, 0, 0, 0), w := 2.0) -> void:
	var p := PackedVector2Array(pts)
	draw_colored_polygon(p, col)
	if line_col.a > 0.0:
		var q := PackedVector2Array(pts)
		q.append(pts[0])
		draw_polyline(q, line_col, w, true)


func _draw() -> void:
	if player == null:
		return
	var s := size
	var font := ThemeDB.fallback_font
	if role == "zombie":
		_draw_shafts(s)
	_draw_scoreboard(s, font)
	_draw_minimap(s)
	_draw_feed(s, font)
	_draw_auto(s, font)
	_draw_portrait(s, font)
	_draw_level(s, font)
	_draw_virus(s, font)
	_draw_infect(s, font)


func _draw_shafts(s: Vector2) -> void:
	# berkas cahaya hijau-teal di pandangan zombie (seperti Crisis Action)
	for i in 9:
		var x := (0.03 + i * 0.118 + 0.012 * sin(t * 0.6 + i * 1.7)) * s.x
		var w := s.x * (0.02 + 0.012 * float(i % 3))
		var a := 0.13 + 0.05 * sin(t * 1.3 + i)
		var c := Color(0.1, 0.85, 0.72, a)
		_poly([Vector2(x + 26.0, 0), Vector2(x + 26.0 + w, 0), Vector2(x + w, s.y), Vector2(x, s.y)], c)


func _draw_scoreboard(s: Vector2, font: Font) -> void:
	var cx := s.x / 2.0
	var hum_me := role != "zombie"
	var lcol := Color(0.1, 0.1, 0.12, 0.85)
	var lline := ORANGE if hum_me else Color(0.5, 0.5, 0.55)
	var rcol := Color(0.1, 0.1, 0.12, 0.85)
	var rline := GREEN if not hum_me else Color(0.5, 0.5, 0.55)
	# panel kiri (MANUSIA)
	_poly([Vector2(cx - 80, 0), Vector2(cx - 270, 0), Vector2(cx - 252, 46), Vector2(cx - 70, 46)], lcol, lline, 3.0)
	if hum_me:
		_poly([Vector2(cx - 80, 0), Vector2(cx - 270, 0), Vector2(cx - 262, 20), Vector2(cx - 76, 20)], Color(0.85, 0.4, 0.08, 0.55))
	_txt(font, Vector2(cx - 258, 34), "MANUSIA", 22, ORANGE if hum_me else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 3)
	_txt(font, Vector2(cx - 165, 36), str(humans), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 70.0, 4)
	# panel kanan (ZOMBIE)
	_poly([Vector2(cx + 80, 0), Vector2(cx + 270, 0), Vector2(cx + 252, 46), Vector2(cx + 70, 46)], rcol, rline, 3.0)
	if not hum_me:
		_poly([Vector2(cx + 80, 0), Vector2(cx + 270, 0), Vector2(cx + 262, 20), Vector2(cx + 76, 20)], Color(0.2, 0.7, 0.2, 0.5))
	_txt(font, Vector2(cx + 140, 34), "ZOMBIE", 22, GREEN if not hum_me else Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 3)
	_txt(font, Vector2(cx + 100, 36), str(zombies), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 40.0, 4)
	# panel tengah (ronde + waktu)
	_poly([Vector2(cx - 84, 0), Vector2(cx + 84, 0), Vector2(cx + 62, 66), Vector2(cx - 62, 66)], Color(0.05, 0.06, 0.08, 0.92), Color(0.45, 0.47, 0.52), 2.0)
	_txt(font, Vector2(cx - 80, 22), "RONDE %d" % round_no, 16, Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 160.0, 3)
	var tl := int(ceil(time_left))
	_txt(font, Vector2(cx - 80, 54), "%02d:%02d" % [tl / 60, tl % 60], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 4)
	# bar bertingkat di bawah panel
	var segs := 10
	var hf := int(ceil(float(humans) / float(humans_total) * segs))
	var zf := int(ceil(float(zombies) / float(humans_total) * segs))
	for i in segs:
		var x := cx - 250 + i * 17.0
		draw_rect(Rect2(x, 52, 13, 6), ORANGE if i < hf else Color(0.2, 0.2, 0.22, 0.8))
		var x2 := cx + 84 + i * 17.0
		draw_rect(Rect2(x2, 52, 13, 6), GREEN if i < zf else Color(0.2, 0.2, 0.22, 0.8))


func _to_mm(wx: float, wz: float) -> Vector2:
	return mm_rect.position + Vector2((wx / arena * 0.5 + 0.5) * mm_rect.size.x, (wz / arena * 0.5 + 0.5) * mm_rect.size.y)


func _draw_minimap(s: Vector2) -> void:
	var m := clampf(s.y * 0.27, 150.0, 230.0)
	mm_rect = Rect2(12, 58, m, m)
	draw_rect(mm_rect, Color(0.04, 0.05, 0.07, 0.62))
	for r in buildings:
		var rr: Rect2 = r
		var a := _to_mm(rr.position.x, rr.position.y)
		var b := _to_mm(rr.end.x, rr.end.y)
		draw_rect(Rect2(a, b - a), Color(0.42, 0.44, 0.5, 0.75))
	for l in road_lines:
		var p := _to_mm(float(l), 0.0).x
		var q := _to_mm(0.0, float(l)).y
		var rw := road_w / (arena * 2.0) * m
		draw_rect(Rect2(p - rw / 2.0, mm_rect.position.y, rw, m), Color(0.2, 0.22, 0.26, 0.55))
		draw_rect(Rect2(mm_rect.position.x, q - rw / 2.0, m, rw), Color(0.2, 0.22, 0.26, 0.55))
	draw_rect(mm_rect, Color(0.7, 0.72, 0.78, 0.9), false, 2.0)
	# titik rekan / musuh
	var ppos: Vector3 = player.global_position
	for b in get_tree().get_nodes_in_group("bots"):
		if not is_instance_valid(b) or bool(b.get("dead")):
			continue
		var bp: Vector3 = b.global_position
		var ally: bool = str(b.get("team")) == str(player.team)
		if not ally and Vector2(bp.x - ppos.x, bp.z - ppos.z).length() > 38.0:
			continue
		var col := Color(0.3, 0.8, 1.0) if ally else Color(1.0, 0.3, 0.25)
		if role == "zombie" and ally:
			col = Color(0.55, 0.95, 0.25)
		draw_circle(_to_mm(bp.x, bp.z), 3.0, col)
	# pemain + kerucut pandangan
	var pm := _to_mm(ppos.x, ppos.z)
	var yaw: float = player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var left := fwd.rotated(-0.55)
	var right := fwd.rotated(0.55)
	_poly([pm, pm + left * 34.0, pm + right * 34.0], Color(1, 1, 1, 0.22))
	draw_circle(pm, 5.0, Color(1.0, 0.85, 0.25))
	draw_circle(pm, 5.0, Color(0, 0, 0, 0.8), false, 1.5)


func _draw_feed(s: Vector2, font: Font) -> void:
	var y := s.y * 0.2
	for f in feed:
		var a := clampf(1.0 - (float(f[2]) - 3.8) / 1.2, 0.0, 1.0)
		var c: Color = f[1]
		c.a = a
		_txt(font, Vector2(0, y), str(f[0]), 24, c, HORIZONTAL_ALIGNMENT_CENTER, s.x, 4)
		y += 30.0


func _draw_auto(s: Vector2, font: Font) -> void:
	var on: bool = bool(player.auto_fire)
	auto_rect = Rect2(12, s.y * 0.47, 160, 34)
	draw_rect(auto_rect, Color(0.05, 0.06, 0.08, 0.7))
	draw_rect(auto_rect, Color(0.6, 0.6, 0.65, 0.8), false, 1.5)
	_txt(font, auto_rect.position + Vector2(8, 25), "Otomatis", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 3)
	var sw := Rect2(auto_rect.position + Vector2(92, 4), Vector2(64, 26))
	draw_rect(sw, ORANGE if on else Color(0.35, 0.35, 0.38))
	draw_rect(sw, Color(0, 0, 0, 0.7), false, 1.5)
	var kx := sw.position.x + (sw.size.x - 28.0 if on else 2.0)
	draw_rect(Rect2(kx, sw.position.y + 2, 26, 22), Color(0.92, 0.92, 0.9))
	_txt(font, sw.position + Vector2(on_off_x(on), 20), "ON" if on else "OFF", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 40.0, 2)


func on_off_x(on: bool) -> float:
	return 6.0 if on else 32.0


func _face_key() -> String:
	if role == "zombie":
		var z: String = str(player.ztype)
		if z.begins_with("induk"):
			return "induk"
		return z if faces.has(z) else "biasa"
	if role == "samurai":
		return "samurai" if faces.has("samurai") else "hero"
	return "hero" if str(player.htype) == "hero" else "civil"


func _draw_portrait(s: Vector2, font: Font) -> void:
	var px := 330.0
	var py := s.y - 122.0
	var key := _face_key()
	# lencana peran (segi enam)
	var label := "BIASA"
	if role == "zombie":
		label = "INDUK" if str(player.ztype).begins_with("induk") else str(player.ztype).to_upper()
		if label == "":
			label = "ZOMBIE"
	elif role == "samurai":
		label = "SAMURAI"
	else:
		label = "HERO" if str(player.htype) == "hero" else "BIASA"
	var bc := Vector2(px + 52, py - 28)
	var hex := [bc + Vector2(-56, 0), bc + Vector2(-42, -20), bc + Vector2(42, -20), bc + Vector2(56, 0), bc + Vector2(42, 20), bc + Vector2(-42, 20)]
	_poly(hex, Color(0.12, 0.14, 0.3, 0.92), Color(0.55, 0.62, 1.0), 2.5)
	_txt(font, bc + Vector2(-56, 8), label, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 112.0, 3)
	var pr := Rect2(px, py, 108, 108)
	draw_rect(pr, Color(0.05, 0.05, 0.07, 0.9))
	if faces.has(key):
		draw_texture_rect(faces[key], pr, false)
	draw_rect(pr, Color(0.8, 0.82, 0.9, 0.9), false, 2.0)
	# HP (kuning) + bar kedua (abu-abu)
	var bx := px + 118.0
	var hp := float(player.hp)
	var mx := float(maxi(player.max_hp, 1))
	var r := clampf(hp / mx, 0.0, 1.0)
	draw_rect(Rect2(bx, py + 8, 190, 24), Color(0.08, 0.08, 0.1, 0.85))
	draw_rect(Rect2(bx, py + 8, 190.0 * r, 24), Color(0.98, 0.78, 0.1))
	draw_rect(Rect2(bx, py + 8, 190, 24), Color(0, 0, 0, 0.8), false, 1.5)
	_txt(font, Vector2(bx + 6, py + 28), "+", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 20.0, 3)
	_txt(font, Vector2(bx, py + 28), str(int(hp)), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 184.0, 3)
	var v2 := 0.0
	var t2 := "0"
	if role == "zombie":
		var cd: float = float(player.skill_cd)
		v2 = 1.0 - clampf(cd / 40.0, 0.0, 1.0)
		t2 = "SIAP" if cd <= 0.0 else str(int(ceil(cd)))
	else:
		var ar := float(player.armor)
		v2 = clampf(ar / 100.0, 0.0, 1.0)
		t2 = str(int(ar))
	draw_rect(Rect2(bx, py + 42, 190, 24), Color(0.08, 0.08, 0.1, 0.85))
	draw_rect(Rect2(bx, py + 42, 190.0 * v2, 24), Color(0.72, 0.74, 0.78))
	draw_rect(Rect2(bx, py + 42, 190, 24), Color(0, 0, 0, 0.8), false, 1.5)
	_txt(font, Vector2(bx + 6, py + 62), "SKILL" if role == "zombie" else "ARMOR", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 80.0, 2)
	_txt(font, Vector2(bx, py + 62), t2, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 184.0, 3)
	# FPS asli (bukan ping: game ini offline)
	_txt(font, Vector2(px, s.y - 6), "FPS %d" % Engine.get_frames_per_second(), 14, Color(0.9, 0.9, 0.5), HORIZONTAL_ALIGNMENT_LEFT, 100.0, 2)


func _draw_level(s: Vector2, font: Font) -> void:
	var x := s.x - 270.0
	var key := _face_key()
	var pr := Rect2(s.x - 76, 8, 64, 64)
	draw_rect(pr, Color(0.05, 0.05, 0.07, 0.85))
	if faces.has(key):
		draw_texture_rect(faces[key], pr, false)
	draw_rect(pr, Color(0.8, 0.82, 0.9, 0.9), false, 2.0)
	var lv := 0
	var bonus := "Pelindung %d" % int(player.armor)
	if role == "zombie":
		lv = int(player.zlevel)
		bonus = "HP+%d" % (lv * 120)
	elif role == "samurai":
		bonus = "HP %d" % int(player.max_hp)
	else:
		lv = Game.player_level()
	_txt(font, Vector2(x, 28), "LV.%d" % lv, 20, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 3)
	_txt(font, Vector2(x, 54), bonus, 22, Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_RIGHT, 180.0, 3)
	for i in 10:
		var on := i < mini(lv, 10)
		draw_rect(Rect2(x + 16 + i * 16.0, 62, 12, 6), (GREEN if role == "zombie" else ORANGE) if on else Color(0.22, 0.22, 0.25, 0.85))


func _draw_virus(s: Vector2, font: Font) -> void:
	if virus_left <= 0 or role == "zombie":
		return
	var a := "Virus biokimia setelah "
	var d := str(virus_left)
	var b := " detik menyebar......"
	var fs := 30
	var wa := font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wd := font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wb := font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (s.x - (wa + wd + wb)) / 2.0
	var y := s.y * 0.66
	_txt(font, Vector2(x, y), a, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	_txt(font, Vector2(x + wa, y), d, fs, Color(0.4, 1.0, 0.2), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	_txt(font, Vector2(x + wa + wd, y), b, fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)


func _draw_infect(s: Vector2, font: Font) -> void:
	if lvl_t > 0.0:
		var c := Color(1, 1, 1, clampf(lvl_t / 0.6, 0.0, 1.0))
		_txt(font, Vector2(0, s.y * 0.66), "Lv naik, HP bertambah!", 30, c, HORIZONTAL_ALIGNMENT_CENTER, s.x, 4)
	if infect_t <= 0.0:
		return
	var k := minf(1.0, (2.2 - infect_t) / 0.18)           # membesar cepat saat muncul
	var sc := lerpf(1.6, 1.0, k) * (1.0 + 0.02 * sin(t * 12.0))
	var al := clampf(infect_t / 0.5, 0.0, 1.0)
	var c0 := Vector2(s.x / 2.0, s.y * 0.77)
	var R := 62.0 * sc
	var pts: Array = []
	for i in 6:
		var an := PI / 6.0 + i * PI / 3.0
		pts.append(c0 + Vector2(cos(an), sin(an)) * R)
	_poly(pts, Color(0.2, 0.22, 0.2, 0.92 * al), Color(0.6, 0.65, 0.6, al), 4.0)
	var pts2: Array = []
	for i in 6:
		var an2 := PI / 6.0 + i * PI / 3.0
		pts2.append(c0 + Vector2(cos(an2), sin(an2)) * R * 0.82)
	_poly(pts2, Color(0.1, 0.13, 0.1, 0.95 * al), Color(0.35, 0.8, 0.2, al), 3.0)
	# cakaran hijau
	for i in 3:
		var o := (i - 1) * 20.0 * sc
		_poly([c0 + Vector2(o - 30 * sc, -46 * sc), c0 + Vector2(o - 16 * sc, -46 * sc), c0 + Vector2(o + 34 * sc, 46 * sc), c0 + Vector2(o + 18 * sc, 46 * sc)], Color(0.45, 0.9, 0.15, 0.85 * al))
	_txt(font, c0 + Vector2(-150.0 * sc, 10 * sc), "TERINFEKSI", int(30 * sc), Color(0.7, 1.0, 0.25, al), HORIZONTAL_ALIGNMENT_CENTER, 300.0 * sc, 5)
