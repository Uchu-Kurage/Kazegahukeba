class_name CharacterArt
extends RefCounted
## ドット絵キャラのスプライトを「コードで」生成する。外部の画像素材なしで
## AnimatedSprite2D 用の SpriteFrames（待機／歩き × 下・上・横）を作る。
##
## 後で本物のドット絵（PNGのスプライトシート）を用意したら、build_frames を
## 差し替える（もしくは AnimatedSprite2D にシートを割り当てる）だけで乗り換えられる。

const W := 16
const H := 24
const EYE := Color(0.16, 0.13, 0.13)


## キャラID → 配色。skin/hair/shirt/pants/shoe。
static func palette_for(id: String) -> Dictionary:
	match id:
		"kuma":
			return _pal(Color(0.98, 0.82, 0.68), Color(0.35, 0.22, 0.14), Color(0.86, 0.36, 0.22), Color(0.22, 0.25, 0.34))
		"yuu":
			return _pal(Color(0.96, 0.84, 0.74), Color(0.12, 0.12, 0.16), Color(0.30, 0.45, 0.72), Color(0.30, 0.32, 0.36))
		"natsu":
			return _pal(Color(0.99, 0.85, 0.76), Color(0.42, 0.28, 0.20), Color(0.88, 0.45, 0.60), Color(0.90, 0.90, 0.92))
	# player / default
	return _pal(Color(0.98, 0.83, 0.70), Color(0.15, 0.13, 0.12), Color(0.92, 0.80, 0.32), Color(0.40, 0.30, 0.22))


static func _pal(skin: Color, hair: Color, shirt: Color, pants: Color) -> Dictionary:
	return {
		"skin": skin, "hair": hair, "shirt": shirt,
		"pants": pants, "shoe": pants.darkened(0.4),
	}


## 待機／歩き × 下・上・横 のアニメを持つ SpriteFrames を作る。
static func build_frames(pal: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for dir in ["down", "up", "side"]:
		var idle := "idle_" + dir
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 2.0)
		sf.set_animation_loop(idle, true)
		sf.add_frame(idle, _frame(dir, 0, 0, pal))
		sf.add_frame(idle, _frame(dir, 0, 1, pal))

		var walk := "walk_" + dir
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 7.0)
		sf.set_animation_loop(walk, true)
		sf.add_frame(walk, _frame(dir, 0, 0, pal))
		sf.add_frame(walk, _frame(dir, 1, 1, pal))
	if sf.has_animation("default"):
		sf.remove_animation("default")
	return sf


## 1コマ分の画像を作ってテクスチャで返す。
## dir: "down"/"up"/"side"、phase: 足の位相(0/1)、bob: 上下の弾み(0/1)。
static func _frame(dir: String, phase: int, bob: int, pal: Dictionary) -> ImageTexture:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var yo := -bob  # 弾みで全体を1px上げる

	# 頭（肌）と髪
	_rect(img, 4, 3 + yo, 11, 8 + yo, pal["skin"])
	_rect(img, 4, 2 + yo, 11, 3 + yo, pal["hair"])
	_rect(img, 4, 3 + yo, 4, 5 + yo, pal["hair"])
	_rect(img, 11, 3 + yo, 11, 5 + yo, pal["hair"])

	# 顔（向きで変える）
	match dir:
		"down":
			_px(img, 6, 6 + yo, EYE)
			_px(img, 9, 6 + yo, EYE)
		"side":
			_px(img, 9, 6 + yo, EYE)
			_rect(img, 4, 3 + yo, 5, 7 + yo, pal["hair"])  # 後頭部
		"up":
			_rect(img, 4, 2 + yo, 11, 5 + yo, pal["hair"])  # 後ろ髪で覆う

	# 胴（服）
	_rect(img, 4, 9 + yo, 11, 15 + yo, pal["shirt"])

	# 腕（位相で軽く振る）
	var la := (10 if phase == 1 else 9) + yo
	var ra := (10 if phase == 0 else 9) + yo
	_rect(img, 3, la, 3, 14 + yo, pal["shirt"])
	_rect(img, 12, ra, 12, 14 + yo, pal["shirt"])
	_px(img, 3, 15 + yo, pal["skin"])
	_px(img, 12, 15 + yo, pal["skin"])

	# 脚（位相で片脚を1px短く＝踏み出し）
	var ll := (21 if phase == 1 else 22)
	var rl := (21 if phase == 0 else 22)
	_rect(img, 5, 16 + yo, 7, ll + yo, pal["pants"])
	_rect(img, 8, 16 + yo, 10, rl + yo, pal["pants"])
	_rect(img, 5, ll + yo, 7, ll + yo, pal["shoe"])
	_rect(img, 8, rl + yo, 10, rl + yo, pal["shoe"])

	return ImageTexture.create_from_image(img)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, c)
