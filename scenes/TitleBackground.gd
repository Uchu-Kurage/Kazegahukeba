extends Node2D
class_name TitleBackground
## タイトルの背景を _draw() で描く。夕暮れの空のグラデーション・沈む陽・山の稜線・田んぼ。
## 静止画（アニメは Fireflies が別に担当）。アート不要、後で一枚絵に差し替えても可。

const HORIZON := 430.0


func _ready() -> void:
	z_index = -20
	queue_redraw()


func _draw() -> void:
	_sky()
	# 沈む陽（山に隠れるよう、地面より先に描く）
	draw_circle(Vector2(760, HORIZON - 4), 66.0, Color(0.99, 0.82, 0.48))
	_land()


func _sky() -> void:
	var top := Color(0.12, 0.13, 0.30)
	var mid := Color(0.44, 0.27, 0.42)
	var low := Color(0.93, 0.58, 0.36)
	var bands := 64
	for i in bands:
		var t := float(i) / float(bands)
		var c: Color = top.lerp(mid, t / 0.6) if t < 0.6 else mid.lerp(low, (t - 0.6) / 0.4)
		var y0 := HORIZON * float(i) / float(bands)
		var y1 := HORIZON * float(i + 1) / float(bands)
		draw_rect(Rect2(0, y0, 1152, y1 - y0 + 1.0), c)


func _land() -> void:
	# 遠くの山（稜線）
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, HORIZON), Vector2(220, HORIZON - 70), Vector2(430, HORIZON - 20),
		Vector2(700, HORIZON - 80), Vector2(980, HORIZON - 30), Vector2(1152, HORIZON - 60),
		Vector2(1152, HORIZON), Vector2(0, HORIZON),
	]), Color(0.20, 0.20, 0.32))

	# 手前の地面（田んぼ）
	draw_rect(Rect2(0, HORIZON, 1152, 648 - HORIZON), Color(0.12, 0.16, 0.18))
	for i in 7:
		var y := HORIZON + 24.0 + i * 30.0
		draw_line(Vector2(0, y), Vector2(1152, y), Color(0.16, 0.22, 0.20), 2.0)
