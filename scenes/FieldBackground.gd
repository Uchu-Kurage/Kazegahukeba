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
	# --- プレースホルダの絵柄（画面ごとに地の色を変えて識別できるように）。PNGで置換される。---
	_draw_placeholder()

	# 歩ける帯（道）を土色で薄く敷く＝どこを歩けるかの目安（PNG では絵が道を示す）。
	for r in roads:
		draw_rect(r, Color(0.74, 0.66, 0.48, 0.9))
		draw_rect(r, Color(0.55, 0.47, 0.33), false, 3.0)


## 画面ごとの簡易プレースホルダ（地の色＋その場所らしい小物を少しだけ）。
func _draw_placeholder() -> void:
	match field_id:
		"riverbank":
			draw_rect(Rect2(0, 0, W, H), Color(0.34, 0.46, 0.28))         # 土手の草
			draw_rect(Rect2(0, 70, W, 150), Color(0.30, 0.52, 0.72))      # 奥の川
			draw_rect(Rect2(0, 66, W, 5), Color(0.80, 0.78, 0.60))
		"estuary":
			draw_rect(Rect2(0, 0, W, H), Color(0.36, 0.44, 0.30))
			draw_rect(Rect2(0, 40, W, 220), Color(0.42, 0.56, 0.72))      # 広い河口
			draw_rect(Rect2(0, 20, W, 20), Color(0.86, 0.86, 0.82))       # 白い霞（その先）
		"shops":
			draw_rect(Rect2(0, 0, W, H), Color(0.60, 0.55, 0.44))         # 通り
			draw_rect(Rect2(0, 110, W, 44), Color(0.30, 0.55, 0.50))      # 店の軒
		"home":
			draw_rect(Rect2(0, 0, W, H), Color(0.52, 0.56, 0.40))         # 家まわり
			draw_rect(Rect2(460, 120, 240, 150), Color(0.55, 0.42, 0.32)) # 家
		"school":
			draw_rect(Rect2(0, 0, W, H), Color(0.56, 0.58, 0.50))         # 校庭
			draw_rect(Rect2(120, 90, W - 240, 130), Color(0.70, 0.68, 0.62)) # 校舎
		"fields":
			draw_rect(Rect2(0, 0, W, H), Color(0.56, 0.64, 0.36))         # 田んぼ
			for r in 5:
				draw_rect(Rect2(0, 120 + r * 90, W, 3), Color(0.40, 0.42, 0.28))
		"sunflower":
			draw_rect(Rect2(0, 0, W, H), Color(0.50, 0.62, 0.34))
			for i in 14:
				draw_circle(Vector2(80 + i * 78, 200 + (i % 3) * 40), 16.0, Color(0.95, 0.80, 0.20))  # ひまわり
		"shrine":
			draw_rect(Rect2(0, 0, W, H), Color(0.36, 0.42, 0.34))         # 境内
			draw_rect(Rect2(430, 70, 292, 20), Color(0.78, 0.22, 0.18))   # 鳥居（笠木）
			draw_rect(Rect2(452, 90, 20, 130), Color(0.78, 0.22, 0.18))
			draw_rect(Rect2(680, 90, 20, 130), Color(0.78, 0.22, 0.18))
		"hill":
			draw_rect(Rect2(0, 0, W, H), Color(0.44, 0.58, 0.36))         # 丘の草
			draw_rect(Rect2(0, 0, W, 120), Color(0.55, 0.72, 0.90))       # 見晴らす空
		_:
			draw_rect(Rect2(0, 0, W, H), Color(0.40, 0.50, 0.34))
