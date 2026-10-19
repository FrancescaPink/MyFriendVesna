extends Control

# ============================================================
#  Sfondo animato del menu: il martelletto del giudice che batte.
#
#  Tutto è disegnato con forme vettoriali (_draw), non con immagini:
#  non essendoci pixel da ingrandire, non può esserci sfarfallio/tremolio.
#  Viene renderizzato dentro un SubViewport a doppia risoluzione e ridotto
#  a schermo, così anche i bordi in rotazione restano lisci (supersampling).
# ============================================================

signal impact   # emesso nell'istante esatto del colpo (per il suono)

# --- tempi del ciclo (secondi) ---
const CYCLE         := 5.0
const T_RAISE_END   := 1.30   # solleva
const T_HOLD_END    := 1.62   # trattiene (attesa)
const T_STRIKE_END  := 1.74   # colpo!
const T_SETTLE_END  := 2.25   # rimbalzo/assestamento
# da T_SETTLE_END a CYCLE resta fermo appoggiato

# --- angoli (radianti, positivo = martelletto sollevato) ---
const ANG_REST := 0.0
const ANG_UP   := 0.62
const ANG_HIT  := -0.035  # leggera compressione sul colpo

# --- geometria (unità a 720p, scalata automaticamente) ---
const BLOCK_W := 196.0
const BLOCK_H := 34.0
const HEAD_W  := 56.0
const HEAD_H  := 92.0
const HANDLE_LEN := 205.0
const HANDLE_TH  := 17.0
const HEAD_GAP := 8.0   # stacco del martelletto dal basamento a riposo

# --- colori ---
const C_WOOD_HEAD  := Color(0.40, 0.24, 0.13)
const C_WOOD_LIGHT := Color(0.55, 0.36, 0.20)
const C_BRASS      := Color(0.82, 0.63, 0.33)
const C_HANDLE     := Color(0.48, 0.30, 0.17)
const C_BLOCK      := Color(0.35, 0.21, 0.11)
const C_BLOCK_TOP  := Color(0.48, 0.31, 0.16)
const C_GLOW       := Color(1.0, 0.78, 0.42)

var _t := 0.0
var _fired := false
var _angle := 0.0
var _shake := 0.0
var _flash := 0.0
var _rings: Array = []    # [radius, alpha]
var _sparks: Array = []   # [angle, dist, alpha]

var _bg_tex: GradientTexture2D
var _glow_tex: GradientTexture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_textures()

func _build_textures() -> void:
	# sfondo: gradiente verticale caldo e scuro (nessun dettaglio fine = nessun tremolio)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(0.045, 0.040, 0.050),
		Color(0.105, 0.080, 0.065),
		Color(0.050, 0.040, 0.038),
	])
	_bg_tex = GradientTexture2D.new()
	_bg_tex.gradient = g
	_bg_tex.width = 8
	_bg_tex.height = 256
	_bg_tex.fill_from = Vector2(0, 0)
	_bg_tex.fill_to = Vector2(0, 1)

	# alone caldo dietro al martelletto
	var gg := Gradient.new()
	gg.offsets = PackedFloat32Array([0.0, 1.0])
	gg.colors = PackedColorArray([Color(1, 0.78, 0.42, 0.20), Color(1, 0.78, 0.42, 0.0)])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.gradient = gg
	_glow_tex.width = 256
	_glow_tex.height = 256
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)

func _process(delta: float) -> void:
	_t += delta
	if _t >= CYCLE:
		_t -= CYCLE
		_fired = false

	# --- angolo del martelletto lungo il ciclo ---
	if _t < T_RAISE_END:
		var u := _t / T_RAISE_END
		_angle = lerp(ANG_REST, ANG_UP, 1.0 - pow(1.0 - u, 3.0))    # sale morbido
	elif _t < T_HOLD_END:
		_angle = ANG_UP                                             # sospensione
	elif _t < T_STRIKE_END:
		var u := (_t - T_HOLD_END) / (T_STRIKE_END - T_HOLD_END)
		_angle = lerp(ANG_UP, ANG_HIT, u * u)                       # scende accelerando
	elif _t < T_SETTLE_END:
		var u := (_t - T_STRIKE_END) / (T_SETTLE_END - T_STRIKE_END)
		_angle = lerp(ANG_HIT, ANG_REST, 1.0 - pow(1.0 - u, 3.0))   # si assesta
	else:
		_angle = ANG_REST

	# --- istante del colpo ---
	if not _fired and _t >= T_STRIKE_END:
		_fired = true
		_on_impact()

	# --- effetti in dissolvenza ---
	_shake = max(0.0, _shake - 34.0 * delta)
	_flash = max(0.0, _flash - 2.6 * delta)
	for r in _rings:
		r[0] += 340.0 * delta
		r[1] -= 1.5 * delta
	_rings = _rings.filter(func(r): return r[1] > 0.0)
	for sp in _sparks:
		sp[1] += 260.0 * delta
		sp[2] -= 3.0 * delta
	_sparks = _sparks.filter(func(sp): return sp[2] > 0.0)

	queue_redraw()

func _on_impact() -> void:
	_shake = 7.0
	_flash = 1.0
	_rings.append([10.0, 0.85])
	_rings.append([0.0, 0.6])
	for i in 9:
		var a := -PI + randf() * PI     # verso l'alto
		_sparks.append([a, 12.0, 1.0])
	impact.emit()

# -------------------- POSIZIONI --------------------
func _scale() -> float:
	return (size.y / 720.0) * 1.28

func _block_center() -> Vector2:
	return Vector2(size.x * 0.665, size.y * 0.585)

func _pivot() -> Vector2:
	var s := _scale()
	var b := _block_center()
	# il martelletto a riposo sta appena sopra il basamento
	var head_y := b.y - (BLOCK_H * 0.5 + HEAD_H * 0.5 + HEAD_GAP) * s
	return Vector2(b.x + HANDLE_LEN * s, head_y)

# -------------------- DISEGNO --------------------
func _draw() -> void:
	var s := _scale()
	var shake_off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * s

	# sfondo
	draw_texture_rect(_bg_tex, Rect2(Vector2.ZERO, size), false)

	# alone caldo (si accende sul colpo)
	var glow_size := Vector2(900, 900) * s * (1.0 + 0.06 * _flash)
	var glow_col := Color(1, 1, 1, 0.85 + 0.9 * _flash)
	draw_texture_rect(_glow_tex,
		Rect2(_block_center() - glow_size * 0.5 + shake_off, glow_size), false, glow_col)

	var block := _block_center() + shake_off
	_draw_block(block, s)
	_draw_impact_fx(Vector2(block.x, block.y - BLOCK_H * 0.5 * s), s)
	_draw_gavel(_pivot() + shake_off, s)

func _draw_block(c: Vector2, s: float) -> void:
	# ombra appoggiata a terra (ellisse schiacciata, non un disco)
	_ellipse(c + Vector2(0, BLOCK_H * 0.78 * s),
		Vector2(BLOCK_W * 0.60, BLOCK_H * 0.30) * s, Color(0, 0, 0, 0.33))
	# plinto
	_rounded_rect(c + Vector2(0, BLOCK_H * 0.42 * s),
		Vector2(BLOCK_W * 0.78, BLOCK_H * 0.55) * s, 5.0 * s, C_BLOCK.darkened(0.25))
	# corpo
	_rounded_rect(c, Vector2(BLOCK_W, BLOCK_H) * s, 7.0 * s, C_BLOCK)
	# faccia superiore illuminata
	_rounded_rect(c - Vector2(0, BLOCK_H * 0.30 * s),
		Vector2(BLOCK_W * 0.94, BLOCK_H * 0.32) * s, 4.0 * s, C_BLOCK_TOP)

func _draw_gavel(pivot: Vector2, s: float) -> void:
	draw_set_transform(pivot, _angle, Vector2(s, s))

	# --- manico ---
	_capsule(Vector2(-HANDLE_LEN + 26.0, 0), Vector2(24.0, 0), HANDLE_TH * 0.5, C_HANDLE)
	# riflesso sul manico
	_capsule(Vector2(-HANDLE_LEN + 34.0, -HANDLE_TH * 0.18),
		Vector2(16.0, -HANDLE_TH * 0.18), HANDLE_TH * 0.16, C_WOOD_LIGHT)
	# pomello dell'impugnatura
	draw_circle(Vector2(26.0, 0), HANDLE_TH * 0.72, C_HANDLE, true)
	draw_circle(Vector2(26.0, 0), HANDLE_TH * 0.72, C_WOOD_HEAD, false, 2.0, true)

	# --- testa ---
	var hc := Vector2(-HANDLE_LEN, 0)
	_rounded_rect(hc, Vector2(HEAD_W, HEAD_H), 9.0, C_WOOD_HEAD)
	# ghiere in ottone alle due estremità (facce che battono)
	_rounded_rect(hc + Vector2(0, -HEAD_H * 0.5 + 9.0), Vector2(HEAD_W + 3.0, 15.0), 5.0, C_BRASS)
	_rounded_rect(hc + Vector2(0,  HEAD_H * 0.5 - 9.0), Vector2(HEAD_W + 3.0, 15.0), 5.0, C_BRASS)
	# venatura chiara centrale
	_rounded_rect(hc + Vector2(-HEAD_W * 0.22, 0), Vector2(7.0, HEAD_H * 0.52), 3.0,
		C_WOOD_LIGHT.darkened(0.1))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_impact_fx(p: Vector2, s: float) -> void:
	# onde d'urto
	for r in _rings:
		var rad: float = r[0]
		var alpha: float = clampf(r[1], 0.0, 1.0)
		draw_arc(p, rad * s, 0.0, TAU, 64, Color(1.0, 0.85, 0.55, alpha * 0.55), 2.5 * s, true)
	# scintille/schegge di luce
	for sp in _sparks:
		var ang: float = sp[0]
		var dist: float = sp[1]
		var a: float = clampf(sp[2], 0.0, 1.0)
		var dir := Vector2(cos(ang), sin(ang))
		var from: Vector2 = p + dir * dist * s
		var to: Vector2 = p + dir * (dist + 16.0) * s
		draw_line(from, to, Color(1.0, 0.88, 0.6, a * 0.7), 2.0 * s, true)

# -------------------- PRIMITIVE --------------------
func _rounded_rect(center: Vector2, sz: Vector2, r: float, col: Color) -> void:
	r = min(r, min(sz.x, sz.y) * 0.5)
	var hx := sz.x * 0.5 - r
	var hy := sz.y * 0.5 - r
	var pts := PackedVector2Array()
	var steps := 6
	var corners := [
		[Vector2(hx, -hy), -PI * 0.5, 0.0],
		[Vector2(hx, hy), 0.0, PI * 0.5],
		[Vector2(-hx, hy), PI * 0.5, PI],
		[Vector2(-hx, -hy), PI, PI * 1.5],
	]
	for c in corners:
		var cc: Vector2 = c[0]
		var a0: float = c[1]
		var a1: float = c[2]
		for i in range(steps + 1):
			var a: float = lerp(a0, a1, float(i) / steps)
			pts.append(center + cc + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)

func _ellipse(center: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 40
	for i in range(steps):
		var a := TAU * float(i) / steps
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, col)

func _capsule(a: Vector2, b: Vector2, r: float, col: Color) -> void:
	draw_line(a, b, col, r * 2.0, true)
	draw_circle(a, r, col, true)
	draw_circle(b, r, col, true)
