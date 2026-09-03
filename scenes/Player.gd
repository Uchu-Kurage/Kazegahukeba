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


func _ready() -> void:
	# アタリ判定（見た目は _draw で描く）。
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 22)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	velocity = dir * speed
	move_and_slide()
	# 画面外へ出ないように位置をクランプ。
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)


## 見た目：NPC(LocationSpot)と同じドット絵風の人物。色だけ主人公用。
func _draw() -> void:
	var c := Color(0.95, 0.80, 0.35)
	draw_circle(Vector2(0, 24), 15.0, Color(0, 0, 0, 0.25))      # 影
	draw_rect(Rect2(-12, -6, 24, 30), c)                         # 体
	draw_circle(Vector2(0, -16), 11.0, Color(0.98, 0.90, 0.80))  # 頭
	draw_rect(Rect2(-11, -27, 22, 9), c.darkened(0.35))          # 髪
