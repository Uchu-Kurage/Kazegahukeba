extends CharacterBody2D
## 2Dドットの操作キャラ（プレイヤー）。場所の中（Place）で歩き回るのに使う。
##
## 見た目とアタリ判定はコードで用意している（アート未使用でも動くように）。
## あとで Sprite2D / AnimatedSprite2D に差し替えれば、そのままドット絵キャラになる。
## 操作キーの登録は Controls（Autoload）に集約してある。

@export var speed := 230.0
## 加減速（操作感）。押した瞬間に最高速だと硬いので、ごく短く加速・減速させて滑らかにする。
##   accel が大きいほどキビキビ。約0.1秒で最高速／離すと約0.09秒で停止する既定値。
@export var accel := 2300.0
@export var decel := 2600.0

## 道判定のあそび（px）。中心1点＋矩形の和集合だとつなぎ目で引っかかるので、少し広げて滑らかに。
const WALK_MARGIN := 5.0

## Place 側から動きを止めるためのフラグ（今は常に歩ける）。
var can_move := true

## マップ内に収める範囲（左上座標と大きさ）。画面外へ出ないようにする。
var bounds := Rect2(24, 80, 1104, 520)

## 歩ける帯（道）。空なら bounds 全体を歩ける（従来どおり）。
## 非空なら、この Rect2 群の和集合の上だけ歩ける（散策画面 FieldScene で「道の上だけ」を実現）。
## 絵の全面を床にしない＝『ぼくのなつやすみ』方式（実装指示 第6弾 §2-1）。
var walkable_rects: Array[Rect2] = []

## 奥行きのスケール変化（散策画面で使う。無効なら等倍のまま）。
## 実効スケール = _depth_base × lerp(_depth_far, _depth_near, t)。
##   t は Y が _depth_y_near（手前）で1・_depth_y_far（奥）で0。near/far は倍率、base は絶対倍率。
## ⚠️ 以前は _sprite.scale を lerp 値で「上書き」していたため、PixelCharacter の基準倍率(2.2)が
##    消えてキャラが小さくなっていた。base を掛ける方式にして、画面ごとに背丈を調整できるようにする。
var _depth_on := false
var _depth_y_near := 600.0
var _depth_y_far := 150.0
var _depth_near := 1.15
var _depth_far := 0.72
var _depth_base := 1.0

var _sprite: PixelCharacter


func _ready() -> void:
	# タッチUI（TouchControls）が「フィールド＝仮想スティック／メニュー＝方向キー」を出し分けるための目印。
	add_to_group("player")

	# アタリ判定。
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 22)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# 見た目：主人公のスプライトシート（assets/characters/player.png）があればそれを使い、
	# 無ければ従来のコード生成のドット絵キャラにフォールバックする。
	_sprite = PixelCharacter.new()
	if not _sprite.setup_from_sheet(CharacterArt.PLAYER_SHEET_PATH):
		_sprite.setup(CharacterArt.palette_for("player"))
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	# 入力方向：キーボード（get_vector）を優先し、無ければスマホの仮想スティック（アナログ）。
	var dir := Vector2.ZERO
	if can_move:
		dir = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
		if dir == Vector2.ZERO:
			dir = TouchControls.move_vec  # 仮想スティックの傾き（長さ≤1＝速度の強弱）
		dir = dir.limit_length(1.0)
	# 目標速度へ滑らかに寄せる（加速／減速）。硬さを取りつつキビキビ感は残す。
	var target := dir * speed
	var rate := accel if dir != Vector2.ZERO else decel
	velocity = velocity.move_toward(target, rate * delta)
	if velocity != Vector2.ZERO:
		var before := position
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
	if _sprite:
		_sprite.set_moving(velocity)
		_apply_depth_scale()


## 奥行きスケールを有効化する（FieldScene から呼ぶ）。base は手前に立ったときの絶対倍率。
func set_depth_scale(y_near: float, y_far: float, near: float, far: float, base: float = 1.0) -> void:
	_depth_on = true
	_depth_y_near = y_near
	_depth_y_far = y_far
	_depth_near = near
	_depth_far = far
	_depth_base = base
	_apply_depth_scale()


## Y 座標に応じて見た目（スプライト）だけ拡縮する。当たり判定は変えない。
## 実効スケール = base × lerp(far, near, t)。手前ほど大きく、奥ほど小さい。
func _apply_depth_scale() -> void:
	if not _depth_on or _sprite == null:
		return
	var t := clampf((position.y - _depth_y_far) / (_depth_y_near - _depth_y_far), 0.0, 1.0)
	# unit_scale を掛けて、画像シート（別解像度）でも各画面の背丈設定をそのまま活かす。
	var s := _depth_base * lerpf(_depth_far, _depth_near, t) * _sprite.unit_scale
	_sprite.scale = Vector2(s, s)


## いまの位置が「道」の上か（walkable_rects のどれかに入っているか）。
## WALK_MARGIN だけ矩形を広げて判定し、矩形のつなぎ目・縁でのひっかかりを減らす。
func _in_walkable(p: Vector2) -> bool:
	for r in walkable_rects:
		if r.grow(WALK_MARGIN).has_point(p):
			return true
	return false


## 足元の影（スプライトの後ろに描かれる）。
func _draw() -> void:
	draw_circle(Vector2(0, 26), 13.0, Color(0, 0, 0, 0.22))
