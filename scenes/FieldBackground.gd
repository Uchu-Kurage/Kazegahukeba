class_name FieldBackground
extends Node2D
## 散策画面の背景（実装指示 第6弾 §5）。差し替え前提。
##
## bg_path の PNG があればそれを画面いっぱいに貼る（Nano Banana Pro 出力の 16:9 をそのまま）。
## 無ければコード描画のプレースホルダを出す（絵が未着でも動く）。後日ドット絵を
## 「同じ画面ID・同じ表示サイズ・同じ道の位置」で差し替えれば、コードを触らず絵だけ入替可。
##
## roads は、プレースホルダ時に「歩ける帯（道）」を薄く見せるための参考（当たり判定は Player 側）。

const W := 1152
const H := 648

var bg_path := ""
var roads: Array = []          # Array[Rect2]（プレースホルダで道を可視化するため）
var field_id := "riverbank"    # プレースホルダの絵柄の出し分けに使う


func _ready() -> void:
	z_index = -10
	if bg_path != "" and ResourceLoader.exists(bg_path):
		var tex := load(bg_path) as Texture2D
		if tex != null:
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			# 画面サイズにフィット（PNGの解像度に依らず 1152x648 に合わせる）。
			var ts := tex.get_size()
			if ts.x > 0 and ts.y > 0:
				spr.scale = Vector2(float(W) / ts.x, float(H) / ts.y)
			add_child(spr)
			return
	queue_redraw()  # PNG が無ければプレースホルダを描く


func _draw() -> void:
	# --- プレースホルダの絵柄（河原と土手）。PNG 差し替えで置き換わる。---
	if field_id == "riverbank":
		draw_rect(Rect2(0, 0, W, H), Color(0.34, 0.46, 0.28))         # 土手の草
		draw_rect(Rect2(0, 70, W, 150), Color(0.30, 0.52, 0.72))      # 奥の川
		draw_rect(Rect2(0, 66, W, 5), Color(0.80, 0.78, 0.60))        # 水際
		for i in 8:
			draw_circle(Vector2(90 + i * 140, 250), 9.0, Color(0.5, 0.5, 0.52))  # 石
	else:
		draw_rect(Rect2(0, 0, W, H), Color(0.40, 0.50, 0.34))         # 汎用の草地

	# 歩ける帯（道）を土色で薄く敷く＝どこを歩けるかの目安（PNG では絵が道を示す）。
	for r in roads:
		draw_rect(r, Color(0.74, 0.66, 0.48, 0.9))
		draw_rect(r, Color(0.55, 0.47, 0.33), false, 3.0)
