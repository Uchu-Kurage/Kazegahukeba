class_name WeatherFX
extends Node2D
## 天気の専用ビジュアル（第9弾・虹/星空/霧/雨）。空色オーバーレイ（ColorRect）の上に、
## 手続き描画で情景を重ねる。アート未使用でも「その天気の日の一枚」が絵で立つように。
##
## mode を setup() で切り替える：
##   "none"    … 何も描かない
##   "fog"     … 白い霧の帯が横にゆっくり流れる（霧の朝）
##   "rain"    … 斜めの雨脚が降る（雨・夕立・台風）
##   "rainbow" … 雨上がりの薄い虹（半円の七色アーチ）＋弱い雨
##   "stars"   … 夜。暗幕＋またたく星＋天の川の帯（快晴の夜・祭りの夜）
##
## 当たり判定には関与しない純粋な演出。FieldScene が今日の天気/夜に応じて設定する。

const W := 1152
const H := 648

var mode := "none"
var _t := 0.0


func setup(m: String) -> void:
	mode = m
	set_process(mode in ["fog", "rain", "rainbow", "stars"])
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match mode:
		"fog": _draw_fog()
		"rain": _draw_rain()
		"rainbow": _draw_rainbow(); _draw_rain(0.5)
		"stars": _draw_stars()


## 霧：大きな半透明の白い円を重ね、横へゆっくり流す（やわらかい霞）。
func _draw_fog() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.90, 0.93, 0.96, 0.16))
	for i in 26:
		var bx := fmod(i * 165.0 + _t * 16.0, float(W + 360)) - 180.0
		var by := 90.0 + float(i % 6) * 96.0
		draw_circle(Vector2(bx, by), 140.0, Color(0.94, 0.96, 0.99, 0.05))


## 雨：斜めの短い線が上から下へ流れる。scale で本数と濃さを調整（夕立の弱い雨などに流用）。
func _draw_rain(scale: float = 1.0) -> void:
	var n := int(150 * scale)
	var col := Color(0.78, 0.85, 0.97, 0.32 * clampf(scale + 0.3, 0.3, 1.0))
	for i in n:
		var x := fmod(i * 53.0 + _t * 620.0, float(W + 120)) - 60.0
		var y := fmod(i * 71.0 + _t * 940.0, float(H))
		draw_line(Vector2(x, y), Vector2(x - 9, y + 28), col, 2.0)


## 虹：画面下の外に中心を置いた上半円の七色アーチ（薄く）。
func _draw_rainbow() -> void:
	var center := Vector2(576, 760)
	var colors := [
		Color(0.90, 0.30, 0.32), Color(0.95, 0.60, 0.25), Color(0.95, 0.88, 0.35),
		Color(0.45, 0.80, 0.45), Color(0.35, 0.65, 0.90), Color(0.35, 0.45, 0.85),
		Color(0.60, 0.40, 0.80),
	]
	var band := 11.0
	var r := 400.0
	for i in colors.size():
		var c: Color = colors[i]
		c.a = 0.30
		draw_arc(center, r - i * band, PI, TAU, 96, c, band + 1.0, true)


## 星空・天の川：夜の暗幕＋またたく星＋斜めの淡い帯（天の川）。
func _draw_stars() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.07, 0.16, 0.55))  # 夜の暗幕
	# 天の川：左上→右下の淡い帯（多層で幅を持たせる）。
	for k in 5:
		var off := float(k - 2) * 26.0
		var a := PackedVector2Array([
			Vector2(-40 + off, 120), Vector2(60 + off, 60),
			Vector2(W + 40 + off, 380), Vector2(W - 60 + off, 460),
		])
		draw_colored_polygon(a, Color(0.80, 0.85, 1.0, 0.05))
	# 星：位置は index 由来で固定、明るさだけ時間でまたたく。空（上半分）に多め。
	for i in 170:
		var x := float((i * 137) % W)
		var y := float((i * 89) % 420)
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + float(i))
		var s := 1.0 + float(i % 3) * 0.6
		draw_circle(Vector2(x, y), s, Color(1, 1, 1, 0.35 + 0.5 * tw))
