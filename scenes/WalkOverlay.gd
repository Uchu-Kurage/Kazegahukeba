class_name WalkOverlay
extends Node2D
## 歩ける領域（walkable_rects）と奥行き基準線を半透明で重ねるデバッグ表示（第6弾 調整用）。
## FieldScene が生成し、キー（debug_walk＝F10）でオン/オフする。数値調整のとき範囲を目で見て詰める用途。

var rects: Array = []       # Array[Rect2]（歩ける帯）
var y_near := 600.0         # 奥行き：手前（最大スケール）の Y
var y_far := 150.0          # 奥行き：奥（最小スケール）の Y


func _draw() -> void:
	# 歩ける矩形（緑の半透明＋縁）。和集合が「石畳の通り」の形になっているかを見る。
	for r in rects:
		draw_rect(r, Color(0.15, 0.85, 0.45, 0.22))
		draw_rect(r, Color(0.10, 0.60, 0.30, 0.9), false, 2.0)
	# 奥行きの基準線（手前＝青／奥＝桃）。キャラ縮尺が手前で最大・奥で最小になる境目。
	draw_line(Vector2(0, y_near), Vector2(1152, y_near), Color(0.20, 0.70, 1.0, 0.85), 2.0)
	draw_line(Vector2(0, y_far), Vector2(1152, y_far), Color(1.0, 0.40, 0.80, 0.85), 2.0)
	var f := ThemeDB.fallback_font
	if f != null:
		draw_string(f, Vector2(10, y_near - 6), "手前 y=%d（最大）" % int(y_near),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.20, 0.70, 1.0))
		draw_string(f, Vector2(10, y_far - 6), "奥 y=%d（最小）" % int(y_far),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.40, 0.80))
		draw_string(f, Vector2(10, 24), "歩行領域オーバーレイ（F10で切替）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 1.0, 0.9))
