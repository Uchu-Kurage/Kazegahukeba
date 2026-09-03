class_name PixelCharacter
extends AnimatedSprite2D
## コード生成のドット絵キャラ（AnimatedSprite2D）。プレイヤーと NPC が共用する。
##
## setup(palette) で配色を渡すと、待機／歩きアニメ入りの SpriteFrames を組み立てる。
## set_moving(velocity) を毎フレーム呼べば、進行方向に合わせて向き・歩きを切り替える。

var _dir := "down"


func setup(palette: Dictionary) -> void:
	sprite_frames = CharacterArt.build_frames(palette)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # ドット絵をくっきり
	centered = true
	scale = Vector2(2.2, 2.2)
	play("idle_down")


## 速度から向きと歩き/待機を決める。静止なら待機、動いていれば歩き。
func set_moving(velocity: Vector2) -> void:
	if velocity.length() < 5.0:
		_play("idle_" + _dir)
		return
	if absf(velocity.x) > absf(velocity.y):
		_dir = "side"
		flip_h = velocity.x < 0.0
	else:
		flip_h = false
		_dir = "down" if velocity.y > 0.0 else "up"
	_play("walk_" + _dir)


## 同じアニメを毎フレーム play して先頭に戻さないようにする。
func _play(anim: String) -> void:
	if animation != anim or not is_playing():
		play(anim)
