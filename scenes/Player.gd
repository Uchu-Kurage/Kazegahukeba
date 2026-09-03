extends CharacterBody2D
## 2Dドットの操作キャラ（プレイヤー）。場所の中（Place）で歩き回るのに使う。
##
## 見た目とアタリ判定はコードで用意している（アート未使用でも動くように）。
## あとで Sprite2D / AnimatedSprite2D に差し替えれば、そのままドット絵キャラになる。
## 操作キーの登録は Controls（Autoload）に集約してある。

@export var speed := 150.0

## Place 側から動きを止めるためのフラグ（今は常に歩ける）。
var can_move := true

## マップ内に収める範囲（左上座標と大きさ）。画面外へ出ないようにする。
var bounds := Rect2(24, 80, 1104, 520)

var _sprite: PixelCharacter


func _ready() -> void:
	# アタリ判定。
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 22)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 見た目：コード生成のドット絵キャラ（歩き／待機アニメ入り）。
	_sprite = PixelCharacter.new()
	_sprite.setup(CharacterArt.palette_for("player"))
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if can_move:
		var dir := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
		velocity = dir * speed
		move_and_slide()
		# 画面外へ出ないように位置をクランプ。
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
	else:
		velocity = Vector2.ZERO
	if _sprite:
		_sprite.set_moving(velocity)


## 足元の影（スプライトの後ろに描かれる）。
func _draw() -> void:
	draw_circle(Vector2(0, 26), 13.0, Color(0, 0, 0, 0.22))
