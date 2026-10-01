class_name AcquireIcon
extends Node2D
## 入手演出で頭上に掲げるアイコン（道具／風物詩）。丸い和紙の台座＋その上の小さな絵。
##
## 絵は assets/icons/<id>.png があればそれを貼り、無ければ _draw() で簡単な絵を描く
## （道具は id ごと、風物詩はジャンルごと）。絵を差し替えるときはコードを触らず PNG を置くだけ。

const ICON_PATH := "res://assets/icons/%s.png"
const RADIUS := 24.0   ## 台座の半径（px）
const ART := 34.0      ## PNG を貼るときの一辺（px）

var kind := ""  ## "item" / "fubutsushi"
var id := ""
var _tex: Texture2D
var _genre := ""


func setup(p_kind: String, p_id: String) -> void:
	kind = p_kind
	id = p_id
	var path := ICON_PATH % id
	if ResourceLoader.exists(path):
		_tex = load(path) as Texture2D
	if kind == "fubutsushi":
		_genre = String(Fubutsushi.entry_of(id).get("genre", ""))
	queue_redraw()


func _draw() -> void:
	# 台座：和紙の丸。どんな背景の上でも絵が読めるように。
	draw_circle(Vector2(0, 2), RADIUS + 1.0, UITheme.SHADOW)
	draw_circle(Vector2.ZERO, RADIUS, UITheme.WASHI)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, UITheme.BORDER, 2.0, true)
	if _tex != null:
		draw_texture_rect(_tex, Rect2(-ART * 0.5, -ART * 0.5, ART, ART), false)
		return
	if kind == "item":
		_draw_item()
	else:
		_draw_genre()


# --- 道具の絵 ---------------------------------------------------------

func _draw_item() -> void:
	match id:
		"mugiwara": _draw_hat()
		"mushi_ami": _draw_net()
		"hanabi": _draw_sparkler()
		"aoi_shell": _draw_shell()
		_: _draw_sparkle(Color("e0b04a"))


## 麦わら帽子：つば（楕円）＋山＋赤いリボン。
func _draw_hat() -> void:
	_ellipse(Vector2(0, 5), 17.0, 6.0, Color("d9b25c"))
	_ellipse(Vector2(0, 4), 15.0, 4.5, Color("ecc977"))
	draw_circle(Vector2(0, 0), 9.0, Color("ecc977"))
	draw_rect(Rect2(-9, 0, 18, 4), Color("ecc977"))
	draw_rect(Rect2(-9, 0, 18, 3), Color("c0463a"))


## 虫取り網：柄＋輪＋網の袋。
func _draw_net() -> void:
	draw_line(Vector2(3, 3), Vector2(14, 15), Color("9a6b3f"), 3.0, true)
	_ellipse(Vector2(-4, -6), 10.0, 6.0, Color("f8f6ef"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -5), Vector2(5, -5), Vector2(-2, 8), Vector2(-6, 8),
	]), Color(0.9, 0.93, 0.95, 0.9))
	for x in [-9.0, -4.0, 1.0]:
		draw_line(Vector2(x, -4), Vector2(-4, 7), Color("b8c4cc"), 1.0, true)
	draw_arc(Vector2(-4, -6), 10.0, 0.0, TAU, 24, Color("5f8fae"), 2.0, true)


## 手持ち花火：束ねた棒＋先の火花。
func _draw_sparkler() -> void:
	var cols := [Color("d2553f"), Color("3f86c4"), Color("e0b04a")]
	for i in 3:
		var dx := float(i - 1) * 4.0
		draw_line(Vector2(dx * 0.5, 15), Vector2(dx - 2.0, -4), cols[i], 3.0, true)
	for a in 8:
		var ang := TAU * float(a) / 8.0
		draw_line(Vector2(-2, -9), Vector2(-2, -9) + Vector2.from_angle(ang) * 8.0, Color("f2a93b"), 1.5, true)
	draw_circle(Vector2(-2, -9), 2.5, Color("fff2c0"))


## 貝殻：扇形＋筋。
func _draw_shell() -> void:
	var pts := PackedVector2Array([Vector2(0, 12)])
	for i in 9:
		pts.append(Vector2(0, 12) + Vector2.from_angle(PI + PI * float(i) / 8.0) * 16.0)
	draw_colored_polygon(pts, Color("f3d3c6"))
	for i in 7:
		var ang := PI + PI * float(i + 1) / 8.0
		draw_line(Vector2(0, 12), Vector2(0, 12) + Vector2.from_angle(ang) * 15.0, Color("d9a796"), 1.0, true)


# --- 風物詩（ジャンル）の絵 -------------------------------------------

func _draw_genre() -> void:
	match _genre:
		"sound": _draw_furin()
		"sky": _draw_stars()
		"taste": _draw_watermelon()
		"play": _draw_uchiwa()
		"creature": _draw_dragonfly()
		"scene": _draw_hill()
		_: _draw_sparkle(Color("9b7fd1"))


## 音＝風鈴：ガラスの椀＋舌＋短冊。
func _draw_furin() -> void:
	draw_line(Vector2(0, -15), Vector2(0, -10), Color("6b6357"), 1.0)
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(Vector2.from_angle(PI + PI * float(i) / 8.0) * 9.0 + Vector2(0, -1))
	draw_colored_polygon(pts, Color(0.62, 0.82, 0.92, 0.95))
	draw_line(Vector2(-9, -1), Vector2(9, -1), Color("5ba3d0"), 1.5)
	draw_line(Vector2(0, -1), Vector2(0, 6), Color("6b6357"), 1.0)
	draw_rect(Rect2(-3, 6, 6, 10), Color("c0463a"))


## 空と光＝きらめく星。
func _draw_stars() -> void:
	_star(Vector2(-3, 1), 11.0, Color("e8b93e"))
	_star(Vector2(10, -9), 5.0, Color("f2cf6b"))
	_star(Vector2(-12, -10), 3.5, Color("f2cf6b"))


## 味＝西瓜：半月の赤＋緑の皮＋種。
func _draw_watermelon() -> void:
	var rind := PackedVector2Array()
	var flesh := PackedVector2Array()
	for i in 11:
		var ang := PI * float(i) / 10.0
		rind.append(Vector2(0, -6) + Vector2.from_angle(ang) * 16.0)
		flesh.append(Vector2(0, -6) + Vector2.from_angle(ang) * 13.0)
	draw_colored_polygon(rind, Color("4c9a4a"))
	draw_colored_polygon(flesh, Color("e0534a"))
	for p in [Vector2(-6, -1), Vector2(0, 2), Vector2(6, -1)]:
		draw_circle(p, 1.3, Color("2b2622"))


## 遊びと行事＝団扇：丸い扇面＋柄。
func _draw_uchiwa() -> void:
	draw_line(Vector2(0, 4), Vector2(0, 17), Color("9a6b3f"), 3.0)
	draw_circle(Vector2(0, -5), 11.0, Color("f7f1e2"))
	draw_arc(Vector2(0, -5), 11.0, 0.0, TAU, 28, Color("3f86c4"), 2.0, true)
	draw_circle(Vector2(-3, -7), 4.0, Color("e0534a"))  # 金魚の赤
	draw_arc(Vector2(3, -2), 4.0, 0.2, 2.6, 10, Color("3f86c4"), 1.5, true)  # 水の輪


## 生きもの＝蜻蛉：胴＋二対の翅。
func _draw_dragonfly() -> void:
	var wing := Color(0.75, 0.88, 0.95, 0.9)
	_ellipse(Vector2(-7, -5), 8.0, 3.0, wing)
	_ellipse(Vector2(7, -5), 8.0, 3.0, wing)
	_ellipse(Vector2(-6, 0), 7.0, 2.6, wing)
	_ellipse(Vector2(6, 0), 7.0, 2.6, wing)
	draw_line(Vector2(0, -8), Vector2(0, 15), Color("c0563f"), 3.0, true)
	draw_circle(Vector2(0, -9), 3.0, Color("5a4a3f"))


## 情景＝夏の丘：入道雲・太陽・丘。
func _draw_hill() -> void:
	draw_circle(Vector2(8, -8), 5.0, Color("f2a93b"))
	draw_circle(Vector2(-7, -8), 5.0, Color("ffffff"))
	draw_circle(Vector2(-2, -10), 6.0, Color("ffffff"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 12), Vector2(-6, -1), Vector2(3, 6), Vector2(10, 0), Vector2(17, 12),
	]), Color("5e9e52"))


## 予備：ひかりの粒（絵の無い道具・特別枠）。
func _draw_sparkle(col: Color) -> void:
	_star(Vector2.ZERO, 13.0, col)
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.9))


# --- 図形ヘルパ -------------------------------------------------------

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)


## 四芒星（きらめき）。r は先端までの長さ。
func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * float(i) / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(c + Vector2.from_angle(ang) * rr)
	draw_colored_polygon(pts, col)
