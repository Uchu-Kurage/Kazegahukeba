extends Node2D
class_name PlaceIcon
## 街の地図に置く「場所」マーカー。パーチメント風の丸看板＋簡単なアイコン＋名前。
##
## アートを使わず _draw() で描いている（後でドット絵スプライトに差し替え可）。
## 選択中はリング表示＋ゆっくりした拡大の脈動で「今ここ」を示す。

const RADIUS := 34.0

var location_id := ""
var display_name := ""
var icon_kind := ""

var _selected := false
var _label: Label
var _pulse: Tween


func setup(id: String, disp_name: String, kind: String, pos: Vector2) -> void:
	location_id = id
	display_name = disp_name
	icon_kind = kind
	position = pos


func _ready() -> void:
	_label = Label.new()
	_label.text = display_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(140, 0)
	_label.position = Vector2(-70, RADIUS + 8)
	_label.add_theme_font_size_override("font_size", 20)
	add_child(_label)
	queue_redraw()


func set_selected(v: bool) -> void:
	if _selected == v:
		return
	_selected = v
	queue_redraw()
	if _label:
		_label.modulate = Color(1, 0.95, 0.6) if v else Color(1, 1, 1)
	_update_pulse()


func _update_pulse() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	scale = Vector2.ONE
	if _selected:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2(1.08, 1.08), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	draw_circle(Vector2(0, 4), RADIUS, Color(0, 0, 0, 0.25))                        # 影
	draw_circle(Vector2.ZERO, RADIUS, Color(0.93, 0.90, 0.82))                      # 丸看板
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(0.35, 0.28, 0.20), 3.0, true)
	_draw_icon()
	if _selected:
		draw_arc(Vector2.ZERO, RADIUS + 6.0, 0.0, TAU, 48, Color(1.0, 0.82, 0.25), 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9, -RADIUS - 20), Vector2(9, -RADIUS - 20), Vector2(0, -RADIUS - 8)
		]), Color(1.0, 0.82, 0.25))


func _draw_icon() -> void:
	match icon_kind:
		"house":
			draw_rect(Rect2(-14, -2, 28, 20), Color(0.86, 0.80, 0.66))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-18, -2), Vector2(0, -20), Vector2(18, -2)
			]), Color(0.62, 0.35, 0.28))
			draw_rect(Rect2(-4, 6, 8, 12), Color(0.35, 0.25, 0.18))
		"torii":
			var red := Color(0.80, 0.20, 0.18)
			draw_rect(Rect2(-20, -16, 40, 6), red)
			draw_rect(Rect2(-16, -7, 32, 4), red)
			draw_rect(Rect2(-13, -14, 5, 30), red)
			draw_rect(Rect2(8, -14, 5, 30), red)
		"shop":
			draw_rect(Rect2(-16, -4, 32, 20), Color(0.80, 0.72, 0.55))
			draw_rect(Rect2(-18, -12, 36, 8), Color(0.30, 0.55, 0.50))
			for i in 4:
				var x := -18.0 + float(i) * 9.0 + 4.0
				draw_rect(Rect2(x, -12, 4, 8), Color(0.92, 0.92, 0.88))
			draw_rect(Rect2(-5, 4, 10, 12), Color(0.35, 0.28, 0.20))
		"river", "water":
			var blue := Color(0.30, 0.55, 0.80)
			for row in 3:
				var pts := PackedVector2Array()
				var y := -10.0 + float(row) * 10.0
				for k in 9:
					var x := -18.0 + float(k) * 4.5
					pts.append(Vector2(x, y + sin(float(k) * 0.9) * 3.0))
				draw_polyline(pts, blue, 3.0, true)
		_:
			draw_circle(Vector2.ZERO, 10.0, Color(0.5, 0.5, 0.55))
