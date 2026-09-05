class_name UraBackground
extends Node2D
## 裏エンド専用の背景（実装指示 第5弾 §5）。
##
## これまで「序盤＝青が鮮やか／終盤＝色が抜けた」で世界の終わりを表現してきた。
## 裏エンドは、その先の「秋の高い空」（褪せた白でも鮮烈な夏でもない、澄んだ高い青）を
## 新トーンとして用意する。＝救済＝季節が戻ったことが視覚で伝わる。
## _draw() で上下グラデーションを描くだけ（アート不要・後で一枚絵に差し替え可）。

const W := 1152
const H := 648

var tone := "dawn"


## トーンごとの空の色（上→下）。秋の澄んだ空を基調に、場面で少しずつ表情を変える。
static func _colors(t: String) -> Array:
	match t:
		"dawn":     return [Color(0.32, 0.52, 0.82), Color(0.80, 0.88, 0.94)]  # 秋の朝・高い青
		"town":     return [Color(0.40, 0.60, 0.86), Color(0.86, 0.90, 0.92)]  # 昼の秋空
		"reunion":  return [Color(0.44, 0.62, 0.84), Color(0.90, 0.88, 0.82)]  # やや暖かい昼
		"places":   return [Color(0.46, 0.58, 0.80), Color(0.92, 0.84, 0.72)]  # 午後の傾いた光
		"mourn":    return [Color(0.36, 0.38, 0.56), Color(0.86, 0.62, 0.52)]  # 夕暮れ
		"forward":  return [Color(0.30, 0.54, 0.86), Color(0.82, 0.90, 0.96)]  # また高い青（希望）
	return [Color(0.32, 0.52, 0.82), Color(0.80, 0.88, 0.94)]


func _ready() -> void:
	z_index = -10


func set_tone(t: String) -> void:
	tone = t
	queue_redraw()


func _draw() -> void:
	var cols := _colors(tone)
	var top: Color = cols[0]
	var bottom: Color = cols[1]
	var bands := 48
	var bh := float(H) / float(bands)
	for i in bands:
		var k := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * bh, W, bh + 1.0), top.lerp(bottom, k))
	# 遠い稜線（町の輪郭）をうっすら置いて、空の高さを際立たせる。
	var ridge := bottom.darkened(0.35)
	draw_rect(Rect2(0, H - 90, W, 90), ridge)
