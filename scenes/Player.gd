extends CharacterBody2D
## 2Dドットの操作キャラ（プレイヤー）。上下左右に歩くだけの最小実装。
##
## 見た目とアタリ判定はコードで用意している（アート未使用でも動くように）。
## あとで Sprite2D / AnimatedSprite2D に差し替えれば、そのままドット絵キャラになる。

@export var speed := 150.0

## Town から夜などに動きを止めるためのフラグ。
var can_move := true

## マップ内に収める範囲（左上座標と大きさ）。画面外へ出ないようにする。
var bounds := Rect2(24, 80, 1104, 520)


func _ready() -> void:
	_register_inputs()
	_build_placeholder()


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


## アタリ判定と見た目をコードで作る（.tscn を単純に保つため。後で差し替え前提）。
func _build_placeholder() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 22)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-11, -11), Vector2(11, -11), Vector2(11, 11), Vector2(-11, 11)
	])
	body.color = Color(0.96, 0.86, 0.42)
	add_child(body)


## 移動・操作キーをコードで登録する。
## エディタの「プロジェクト設定 > 入力マップ」で作るのが本来だが、
## ここで登録しておけば設定ファイルをいじらずに確実に動く。あとでエディタ側に移してもよい。
func _register_inputs() -> void:
	_bind("walk_left",  [KEY_A, KEY_LEFT])
	_bind("walk_right", [KEY_D, KEY_RIGHT])
	_bind("walk_up",    [KEY_W, KEY_UP])
	_bind("walk_down",  [KEY_S, KEY_DOWN])
	_bind("interact",   [KEY_E, KEY_SPACE, KEY_ENTER])
	_bind("skip",       [KEY_Q])


func _bind(action: String, keys: Array) -> void:
	# 既に登録済み（前のシーンで登録した／エディタで設定済み）なら触らない。
	# これでシーン遷移のたびにキーが二重登録されるのを防ぐ。
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
