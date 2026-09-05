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

## 歩ける帯（道）。空なら bounds 全体を歩ける（従来どおり）。
## 非空なら、この Rect2 群の和集合の上だけ歩ける（散策画面 FieldScene で「道の上だけ」を実現）。
## 絵の全面を床にしない＝『ぼくのなつやすみ』方式（実装指示 第6弾 §2-1）。
var walkable_rects: Array[Rect2] = []

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
		var before := position
		velocity = dir * speed
		move_and_slide()
		# 画面外へ出ないように位置をクランプ。
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
		# 道（歩ける帯）が定義されていれば、その上だけに制限する。
		# 軸ごとに判定して、道の縁に沿ってスライド・角を曲がれるようにする。
		if not walkable_rects.is_empty() and not _in_walkable(position):
			var try_x := Vector2(position.x, before.y)
			var try_y := Vector2(before.x, position.y)
			if _in_walkable(try_x):
				position = try_x
			elif _in_walkable(try_y):
				position = try_y
			else:
				position = before
	else:
		velocity = Vector2.ZERO
	if _sprite:
		_sprite.set_moving(velocity)


## いまの位置が「道」の上か（walkable_rects のどれかに入っているか）。
func _in_walkable(p: Vector2) -> bool:
	for r in walkable_rects:
		if r.has_point(p):
			return true
	return false


## 足元の影（スプライトの後ろに描かれる）。
func _draw() -> void:
	draw_circle(Vector2(0, 26), 13.0, Color(0, 0, 0, 0.22))
