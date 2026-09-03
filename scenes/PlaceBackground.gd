extends Node2D
class_name PlaceBackground
## 各場所の中(Place)の背景を _draw() で描く。場所ごとに地面や小物を変えて、
## 「どこにいるか」が見た目で分かるようにする。アート不要（後でタイルや一枚絵に差し替え可）。

var place_id := ""


func _ready() -> void:
	z_index = -10
	queue_redraw()


func _draw() -> void:
	match place_id:
		"riverside":
			_riverside()
		"shrine":
			_shrine()
		"shop":
			_shop()
		_:
			_home()


func _riverside() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.30, 0.44, 0.28))       # 河川敷の草
	draw_rect(Rect2(0, 360, 1152, 288), Color(0.28, 0.50, 0.72))     # 川
	draw_rect(Rect2(0, 356, 1152, 6), Color(0.80, 0.78, 0.60))       # 水際
	for i in 6:
		draw_circle(Vector2(120 + i * 180, 340), 10.0, Color(0.5, 0.5, 0.52))  # 石


func _shrine() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.36, 0.40, 0.34))       # 石畳の地面
	# 鳥居（赤）
	var red := Color(0.78, 0.22, 0.18)
	draw_rect(Rect2(360, 90, 432, 26), red)
	draw_rect(Rect2(392, 128, 368, 16), red)
	draw_rect(Rect2(410, 96, 26, 150), red)
	draw_rect(Rect2(716, 96, 26, 150), red)
	# 燈籠
	draw_rect(Rect2(150, 300, 40, 90), Color(0.55, 0.55, 0.5))
	draw_rect(Rect2(962, 300, 40, 90), Color(0.55, 0.55, 0.5))


func _shop() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.62, 0.56, 0.44))       # 通り
	draw_rect(Rect2(0, 120, 1152, 40), Color(0.30, 0.55, 0.50))      # 店の軒（帯）
	for i in 6:
		var x := 60 + i * 190
		draw_rect(Rect2(x, 120, 120, 40), Color(0.85, 0.35, 0.30) if i % 2 == 0 else Color(0.9, 0.9, 0.86))
		draw_rect(Rect2(x + 20, 60, 80, 60), Color(0.50, 0.42, 0.34))  # 店先


func _home() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.55, 0.58, 0.40))       # 畳
	for r in 4:
		for c in 6:
			draw_rect(Rect2(40 + c * 180, 90 + r * 130, 176, 126), Color(0.30, 0.32, 0.22), false, 2.0)
	draw_rect(Rect2(500, 300, 150, 90), Color(0.45, 0.32, 0.22))     # ちゃぶ台
