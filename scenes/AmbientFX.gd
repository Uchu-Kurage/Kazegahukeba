class_name AmbientFX
extends Node2D
## 散策画面の環境演出（背景の上の小さな動き）。一枚絵の背景を「その場で息をしている」ように見せる。
##
## FieldAmbience（データ）の一覧を受け取り、手続き描画で重ねる。画像素材は使わない（ライセンス不要）。
## 地面の層（水面のきらめき・雲の影）と空の層（トンボ・チョウ・葉・木漏れ日・蛍）に分けて2つ置く：
##   ・地面の層 … 背景の直上・キャラの後ろ（z_index = GROUND_Z）
##   ・空の層   … キャラの手前・天気の色オーバーレイ(20)の下（z_index = AIR_Z）
## 当たり判定・進行には関与しない。天気・昼夜で出し分ける（FieldAmbience の説明を参照）。

const GROUND_Z := -5
const AIR_Z := 15
## 夜の空の層（蛍）は、夜の暗幕（WeatherFX＝25）の上に出して光らせる。歩行デバッグ(50)の下。
const NIGHT_AIR_Z := 26

## 雲の影の濃さと流れる速さ（px/秒）。影は「地面がふっと翳る」程度に薄く。
const SHADOW_ALPHA := 0.10
const SHADOW_SPEED := 14.0

## トンボ・チョウの描画倍率（キャラの背丈に対して小さすぎず、目で追える大きさ）。
const INSECT_SCALE := 1.6
## きらめきが「光っている」のは周期のうちこの割合だけ（残りは消えて次の場所へ）。
const GLINT_DUTY := 0.3
const DRAGONFLY_BODY := Color(0.72, 0.24, 0.16)      # 赤とんぼの胴
const DRAGONFLY_WING := Color(0.92, 0.96, 1.0, 0.45) # 透けた翅
const BUTTERFLY_COLORS := [Color(0.97, 0.97, 0.93), Color(0.98, 0.90, 0.45)]  # モンシロ・キチョウ
const LEAF_COLORS := [Color(0.38, 0.62, 0.26), Color(0.52, 0.70, 0.30), Color(0.30, 0.50, 0.22)]
const GLINT := Color(1.0, 1.0, 0.96)
const LIGHT := Color(1.0, 0.97, 0.82)
const FIREFLY := Color(0.85, 1.0, 0.55)

var _t := 0.0
var _glints: Array = []       # { rect, n, seeds: Array }
var _dragonflies: Array = []  # { area, pos, from, to, dash, wait, face }
var _butterflies: Array = []  # { area, pos, vel, col, ph }
var _leaves: Array = []       # { area, floor, pos, rot, spin, ph, col }
var _lights: Array = []       # { rect, motes: Array }
var _fireflies: Array = []    # { area, pos, ph, speed }


## 演出を組み立てる。ground=true で地面の層、false で空の層だけを担当する。
## 雲の影は切り取りが要るので、子の Control（clip_contents）として別に置く。
func setup(specs: Array, weather_id: String, night: bool, ground: bool) -> void:
	z_index = GROUND_Z if ground else (NIGHT_AIR_Z if night else AIR_Z)
	for c in get_children():
		c.queue_free()
	_glints.clear(); _dragonflies.clear(); _butterflies.clear()
	_leaves.clear(); _lights.clear(); _fireflies.clear()
	if weather_id in FieldAmbience.WET_WEATHERS:
		set_process(false)
		queue_redraw()
		return
	var sunny := not (weather_id in FieldAmbience.NO_SUN_WEATHERS)
	for spec in specs:
		var kind := String(spec.get("kind", ""))
		if (kind in FieldAmbience.GROUND_KINDS) != ground:
			continue
		if night != (kind == "fireflies"):
			continue  # 夜は蛍だけ、昼は蛍以外
		match kind:
			"glint":
				if sunny:
					_add_glints(spec)
			"cloud_shadow":
				if sunny:
					_add_cloud_shadow(spec["rect"])
			"dragonfly":
				for i in int(spec.get("count", 2)):
					_dragonflies.append(_new_dragonfly(spec["rect"]))
			"butterfly":
				for i in int(spec.get("count", 2)):
					_butterflies.append(_new_butterfly(spec["rect"]))
			"leaves":
				for i in int(spec.get("count", 6)):
					var lf := _new_leaf(spec["rect"], float(spec.get("floor", 640.0)))
					var p0: Vector2 = lf["pos"]
					p0.y = randf_range(p0.y, float(lf["floor"]))  # 最初から縦に散らしておく
					lf["pos"] = p0
					_leaves.append(lf)
			"light":
				if sunny:
					_add_light(spec["rect"])
			"fireflies":
				var area: Rect2 = spec["rect"]
				for i in int(spec.get("count", 20)):
					_fireflies.append({
						"area": area, "pos": _rand_in(area),
						"ph": randf_range(0.0, TAU), "speed": randf_range(0.6, 1.4),
					})
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for d in _dragonflies:
		_step_dragonfly(d, delta)
	for b in _butterflies:
		_step_butterfly(b, delta)
	for lf in _leaves:
		_step_leaf(lf, delta)
	for l in _lights:
		_step_motes(l, delta)
	for f in _fireflies:
		f["ph"] = float(f["ph"]) + delta * float(f["speed"])
		var area: Rect2 = f["area"]
		var fp: Vector2 = f["pos"] + Vector2(sin(float(f["ph"]) * 0.7), cos(float(f["ph"]) * 0.9)) * 9.0 * delta
		f["pos"] = fp.clamp(area.position, area.end)
	queue_redraw()


func _draw() -> void:
	for g in _glints:
		_draw_glints(g)
	for l in _lights:
		_draw_light(l)
	for lf in _leaves:
		_draw_leaf(lf)
	for b in _butterflies:
		_draw_butterfly(b)
	for d in _dragonflies:
		_draw_dragonfly(d)
	for f in _fireflies:
		_draw_firefly(f)


static func _rand_in(r: Rect2) -> Vector2:
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


# --- 水面のきらめき ------------------------------------------------------------
# 粒ごとに「光ってすぐ消える」を周期で繰り返し、消えている間に場所を変える（同じ点が光り続けない）。

func _add_glints(spec: Dictionary) -> void:
	var density := float(spec.get("density", 2.0))
	for r in spec.get("rects", []):
		var rect: Rect2 = r
		var n := maxi(3, int(rect.get_area() / 10000.0 * density))
		var seeds: Array = []
		for i in n:
			seeds.append({ "pos": _rand_in(rect), "ph": randf(), "period": randf_range(1.4, 3.2) })
		_glints.append({ "rect": rect, "seeds": seeds })


func _draw_glints(g: Dictionary) -> void:
	for s in g["seeds"]:
		var u := fmod(_t / float(s["period"]) + float(s["ph"]), 1.0)
		if u < 0.02:
			s["pos"] = _rand_in(g["rect"])  # 消えている間に次の場所へ
		if u > GLINT_DUTY:
			continue  # 周期のうち最初の GLINT_DUTY だけ光る
		var k := sin(u / GLINT_DUTY * PI)  # 0→1→0
		var p: Vector2 = s["pos"]
		var c := GLINT
		c.a = 0.95 * k
		var arm := 3.0 + 6.0 * k
		draw_line(p - Vector2(arm, 0), p + Vector2(arm, 0), c, 2.0)
		draw_line(p - Vector2(0, arm * 0.6), p + Vector2(0, arm * 0.6), c, 2.0)
		draw_circle(p, 2.0, c)


# --- 雲の影 --------------------------------------------------------------------
# 範囲の Control で切り取り、その中をぼかした大きな影がゆっくり横切る。

func _add_cloud_shadow(rect: Rect2) -> void:
	var clip := _CloudShadows.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)


class _CloudShadows extends Control:
	var _t := 0.0
	var _tex: GradientTexture2D
	var _clouds: Array = []  # { x, y, w, h, speed }

	func _ready() -> void:
		var g := Gradient.new()
		g.set_color(0, Color(0.10, 0.12, 0.18, AmbientFX.SHADOW_ALPHA))
		g.set_color(1, Color(0.10, 0.12, 0.18, 0.0))
		_tex = GradientTexture2D.new()
		_tex.gradient = g
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.width = 128
		_tex.height = 128
		# 範囲の幅より広い間隔で 3 つ。最初から画面のあちこちに散らしておく。
		for i in 3:
			_clouds.append({
				"x": randf_range(-300.0, size.x), "y": randf_range(0.0, size.y),
				"w": randf_range(380.0, 620.0), "h": randf_range(150.0, 260.0),
				"speed": AmbientFX.SHADOW_SPEED * randf_range(0.8, 1.2),
			})

	func _process(delta: float) -> void:
		for c in _clouds:
			c["x"] += float(c["speed"]) * delta
			if c["x"] > size.x + 40.0:  # 右へ抜けたら左の外から
				c["x"] = -float(c["w"]) - randf_range(40.0, 400.0)
				c["y"] = randf_range(0.0, size.y)
		queue_redraw()

	func _draw() -> void:
		for c in _clouds:
			var w := float(c["w"])
			var h := float(c["h"])
			draw_texture_rect(_tex, Rect2(float(c["x"]), float(c["y"]) - h * 0.5, w, h), false)


# --- トンボ --------------------------------------------------------------------
# 空中で止まる（ホバリング）→ すっと別の点へ飛ぶ、を繰り返す。

func _new_dragonfly(area: Rect2) -> Dictionary:
	var p := _rand_in(area)
	return { "area": area, "pos": p, "from": p, "to": p, "dash": 1.0, "wait": randf_range(0.2, 2.0), "face": 1.0 }


func _step_dragonfly(d: Dictionary, delta: float) -> void:
	if float(d["dash"]) < 1.0:
		d["dash"] = minf(1.0, float(d["dash"]) + delta * 2.2)
		var k := 1.0 - pow(1.0 - float(d["dash"]), 3.0)  # すっと出て、ふっと止まる
		d["pos"] = (d["from"] as Vector2).lerp(d["to"], k)
		return
	d["wait"] = float(d["wait"]) - delta
	var from: Vector2 = d["from"]
	d["pos"] += Vector2(sin(_t * 7.0 + from.x), cos(_t * 5.0 + from.y)) * 3.0 * delta  # その場で小さく揺れる
	if float(d["wait"]) <= 0.0:
		var area: Rect2 = d["area"]
		var to: Vector2 = d["pos"] + Vector2(randf_range(-220.0, 220.0), randf_range(-90.0, 90.0))
		to = to.clamp(area.position, area.end)
		d["from"] = d["pos"]
		d["to"] = to
		var dx: float = to.x - (d["pos"] as Vector2).x
		if absf(dx) > 1.0:
			d["face"] = signf(dx)
		d["dash"] = 0.0
		d["wait"] = randf_range(0.8, 2.6)


func _draw_dragonfly(d: Dictionary) -> void:
	var p: Vector2 = d["pos"]
	var f := float(d["face"])
	var u := INSECT_SCALE
	# 翅は細かく羽ばたく（透けた細長い翅を前後2対）。
	var flap := 0.55 + 0.45 * absf(sin(_t * 40.0 + p.x))
	for side in [-1.0, 1.0]:
		for k in [0.0, 1.0]:
			var base := p + Vector2(f * (1.0 - k * 2.0), 0) * u
			var tip := base + Vector2(f * (1.5 - k * 3.0), side * 7.0 * flap) * u
			draw_line(base, tip, DRAGONFLY_WING, 2.5 * u)
	# 胴（頭は進行方向）。
	draw_line(p + Vector2(-f * 9.0, 0.5) * u, p + Vector2(f * 3.0, 0) * u, DRAGONFLY_BODY, 1.6 * u)
	draw_circle(p + Vector2(f * 4.0, 0) * u, 1.6 * u, DRAGONFLY_BODY.darkened(0.2))


# --- チョウ --------------------------------------------------------------------
# ひらひら：向きをゆっくり変えながら漂い、羽ばたきに合わせて上下に揺れる。

func _new_butterfly(area: Rect2) -> Dictionary:
	return {
		"area": area, "pos": _rand_in(area), "vel": Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 28.0,
		"col": BUTTERFLY_COLORS[randi() % BUTTERFLY_COLORS.size()], "ph": randf_range(0.0, TAU),
	}


func _step_butterfly(b: Dictionary, delta: float) -> void:
	b["ph"] = float(b["ph"]) + delta
	var v: Vector2 = (b["vel"] as Vector2).rotated(sin(float(b["ph"]) * 0.9) * 1.6 * delta)
	var area: Rect2 = b["area"]
	var p: Vector2 = b["pos"]
	if not area.has_point(p):
		v = v.lerp((area.get_center() - p).normalized() * 28.0, 2.0 * delta)  # 範囲の外へ出たら戻る
	b["vel"] = v
	b["pos"] = p + v * delta + Vector2(0, sin(_t * 9.0 + float(b["ph"])) * 14.0 * delta)


func _draw_butterfly(b: Dictionary) -> void:
	var p: Vector2 = b["pos"]
	var col: Color = b["col"]
	var open := absf(sin(_t * 11.0 + float(b["ph"]) * 3.0))  # 羽ばたき（0=閉じ 1=開き）
	var u := INSECT_SCALE
	var w := (1.0 + 4.5 * open) * u
	draw_rect(Rect2(p.x - w - 0.5, p.y - 4.0 * u, w, 4.0 * u), col)  # 前翅（左）
	draw_rect(Rect2(p.x + 0.5, p.y - 4.0 * u, w, 4.0 * u), col)      # 前翅（右）
	draw_rect(Rect2(p.x - w * 0.7 - 0.5, p.y, w * 0.7, 3.0 * u), col.darkened(0.08))  # 後翅
	draw_rect(Rect2(p.x + 0.5, p.y, w * 0.7, 3.0 * u), col.darkened(0.08))
	draw_line(p + Vector2(0, -4) * u, p + Vector2(0, 3) * u, Color(0.25, 0.22, 0.2), 1.2)  # 胴


# --- 舞い落ちる葉 --------------------------------------------------------------

func _new_leaf(area: Rect2, floor_y: float) -> Dictionary:
	return {
		"area": area, "floor": floor_y, "pos": _rand_in(area), "rot": randf_range(0.0, TAU),
		"spin": randf_range(-2.0, 2.0), "ph": randf_range(0.0, TAU),
		"fall": randf_range(18.0, 34.0), "col": LEAF_COLORS[randi() % LEAF_COLORS.size()],
	}


func _step_leaf(lf: Dictionary, delta: float) -> void:
	lf["ph"] = float(lf["ph"]) + delta * 1.6
	lf["rot"] = float(lf["rot"]) + float(lf["spin"]) * delta
	lf["pos"] += Vector2(sin(float(lf["ph"])) * 26.0 + 8.0, float(lf["fall"])) * delta  # 揺れながら落ち、そよ風で少し右へ
	var p: Vector2 = lf["pos"]
	if p.y > float(lf["floor"]) or p.x > 1180.0:  # 地面に着いたら茂みから次の一枚
		var area: Rect2 = lf["area"]
		lf["pos"] = Vector2(randf_range(area.position.x, area.end.x), area.position.y + randf_range(0.0, area.size.y * 0.5))


func _draw_leaf(lf: Dictionary) -> void:
	var p: Vector2 = lf["pos"]
	var r := float(lf["rot"])
	var flip := 0.35 + 0.65 * absf(sin(float(lf["ph"]) * 1.3))  # 裏返りながら落ちる（幅が伸び縮み）
	var ax := Vector2(cos(r), sin(r))
	var ay := Vector2(-ax.y, ax.x) * flip
	var pts := PackedVector2Array([p - ax * 6.5, p + ay * 3.0, p + ax * 6.5, p - ay * 3.0])
	draw_colored_polygon(pts, lf["col"])


# --- 木漏れ日（光の筋と漂う塵）---------------------------------------------------

func _add_light(rect: Rect2) -> void:
	var motes: Array = []
	for i in 26:
		motes.append({ "pos": _rand_in(rect), "ph": randf_range(0.0, TAU) })
	_lights.append({ "rect": rect, "motes": motes })


## 塵：ゆっくり沈みながら左右に揺れ、下に抜けたら上から。
func _step_motes(l: Dictionary, delta: float) -> void:
	var r: Rect2 = l["rect"]
	for m in l["motes"]:
		m["ph"] = float(m["ph"]) + delta * 0.25
		var p: Vector2 = m["pos"] + Vector2(sin(float(m["ph"]) * 6.0) * 9.0, 7.0) * delta
		if p.y > r.end.y:
			p = Vector2(randf_range(r.position.x, r.end.x), r.position.y)
		m["pos"] = p


func _draw_light(l: Dictionary) -> void:
	var r: Rect2 = l["rect"]
	# 左上から右下へ傾いた光の筋を数本。上が明るく、下へ向かって消える。ゆっくり明滅する。
	var shafts := [[0.08, 90.0, 0.0], [0.30, 60.0, 1.7], [0.50, 120.0, 3.1], [0.72, 55.0, 4.4]]
	for s in shafts:
		var x0 := r.position.x + r.size.x * float(s[0])
		var wdt := float(s[1])
		var a := 0.12 + 0.05 * sin(_t * 0.5 + float(s[2]))
		var slant := r.size.y * 0.45
		var top := LIGHT
		top.a = a
		var bottom := LIGHT
		bottom.a = 0.0
		draw_polygon(
			PackedVector2Array([
				Vector2(x0, r.position.y), Vector2(x0 + wdt, r.position.y),
				Vector2(x0 + wdt * 1.8 + slant, r.end.y), Vector2(x0 + slant, r.end.y),
			]),
			PackedColorArray([top, top, bottom, bottom]))
	# 光の中を漂う塵（ちらちら光る。動きは _step_motes）。
	for m in l["motes"]:
		var p: Vector2 = m["pos"]
		var c := LIGHT
		c.a = 0.25 + 0.35 * absf(sin(_t * 1.7 + float(m["ph"]) * 9.0))
		draw_circle(p, 1.3, c)


# --- 夜の蛍 --------------------------------------------------------------------

func _draw_firefly(f: Dictionary) -> void:
	var glow := 0.5 + 0.5 * sin(_t * 2.2 + float(f["ph"]) * 4.0)
	if glow < 0.15:
		return
	var p: Vector2 = f["pos"]
	var halo := FIREFLY
	halo.a = 0.18 * glow
	draw_circle(p, 6.0, halo)
	var core := FIREFLY
	core.a = 0.9 * glow
	draw_circle(p, 1.8, core)
