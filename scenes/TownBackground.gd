extends Node2D
class_name TownBackground
## 街の地図の背景を _draw() で描く。草地・川・田んぼ・道。
##
## アートを使わず、図形描画だけで田舎町の地図を作っている。
## 後で本物のタイルマップ(TileMapLayer)や一枚絵に差し替えても、
## 場所アイコン(PlaceIcon)や選択ロジックはそのまま使える。


func _ready() -> void:
	z_index = -10  # 場所アイコンより奥に
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.29, 0.43, 0.27))  # 草地
	_draw_river()
	_draw_fields()
	_draw_roads()


## 左端を流れる川。少しうねらせる。
func _draw_river() -> void:
	var right_bank := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / float(steps)
		var y := t * 648.0
		var w := 70.0 + sin(t * PI * 3.0) * 22.0
		right_bank.append(Vector2(w, y))

	var poly := PackedVector2Array()
	poly.append(Vector2(0, 0))
	for p in right_bank:
		poly.append(p)
	poly.append(Vector2(0, 648))
	draw_colored_polygon(poly, Color(0.28, 0.50, 0.72))
	draw_polyline(right_bank, Color(0.78, 0.84, 0.72), 3.0, true)  # 川岸


## 中央の田んぼ（畦道で区切ったマス）。
func _draw_fields() -> void:
	var origin := Vector2(330, 350)
	var cols := 4
	var rows := 3
	var cw := 95.0
	var ch := 70.0
	for r in rows:
		for c in cols:
			var x := origin.x + c * cw
			var y := origin.y + r * ch
			var tint := 0.04 * float((r + c) % 2)
			var rect := Rect2(x, y, cw - 6.0, ch - 6.0)
			draw_rect(rect, Color(0.34 + tint, 0.50 + tint, 0.30))
			draw_rect(rect, Color(0.24, 0.32, 0.18), false, 2.0)  # 畦道


## 場所どうしを結ぶ道。座標は Locations から取るので配置とズレない。
func _draw_roads() -> void:
	var road := Color(0.80, 0.73, 0.55)
	var edge := Color(0.55, 0.48, 0.34)
	var segs := [
		[Locations.pos_of("riverside"), Locations.pos_of("shop")],
		[Locations.pos_of("shop"), Locations.pos_of("shrine")],
		[Locations.pos_of("shop"), Locations.pos_of("home")],
		[Locations.pos_of("shrine"), Locations.pos_of("home")],
	]
	for s in segs:
		draw_line(s[0], s[1], edge, 20.0)  # 道の縁
	for s in segs:
		draw_line(s[0], s[1], road, 14.0)  # 道の中
