extends Node2D
## 街全体マップ（メインシーン）＝行き先を「選ぶ」層。
##
## ここは歩かない。地図上に並んだ場所アイコンを、矢印/WASD でカーソル選択し、
## ［E］で選んだ場所の中（Place シーン）へ入る。夜は選択せず、振り返って翌日へ。
## 場所アイコンには表示用に LocationSpot を流用している（当たり判定は使わない）。

const LocationSpotScene := preload("res://scenes/LocationSpot.tscn")

var _markers: Array = []  ## 場所アイコン（LocationSpot）の並び。Locations.ALL と同じ順。
var _selected := 0
var _ended := false


func _ready() -> void:
	_build()
	# 夜になった／翌朝になったを受けて、選択の見た目とプロンプトを更新する。
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	GameState.game_ended.connect(_on_game_ended)
	_apply_phase()


func _build() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648)
	])
	ground.color = Color(0.15, 0.18, 0.16)
	ground.z_index = -10
	add_child(ground)

	for loc in Locations.ALL:
		var m = LocationSpotScene.instantiate()
		m.setup(loc["id"], loc["name"], loc["character"], loc["pos"])
		add_child(m)
		_markers.append(m)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_confirm()
	elif event.is_action_pressed("skip"):
		_skip()
	elif not _ended and GameState.phase != GameState.Phase.NIGHT:
		# 方向キーでカーソル移動（押した方向にいちばん近いアイコンへ）。
		if event.is_action_pressed("walk_left"):
			_move(Vector2.LEFT)
		elif event.is_action_pressed("walk_right"):
			_move(Vector2.RIGHT)
		elif event.is_action_pressed("walk_up"):
			_move(Vector2.UP)
		elif event.is_action_pressed("walk_down"):
			_move(Vector2.DOWN)


func _confirm() -> void:
	if _ended:
		_ended = false
		GameState.start_new_run()
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			Nav.go_to_place(_markers[_selected].location_id)  # 選んだ場所の中へ
		GameState.Phase.NIGHT:
			GameState.flip_calendar()


func _skip() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			GameState.skip_slot()


## 押した方向にいちばん近いアイコンへカーソルを移す。
func _move(dir: Vector2) -> void:
	var cur: Vector2 = _markers[_selected].position
	var best := -1
	var best_score := INF
	for i in _markers.size():
		if i == _selected:
			continue
		var to: Vector2 = _markers[i].position - cur
		var proj := to.dot(dir)           # その方向にどれだけ進むか
		if proj <= 0.0:
			continue                       # 逆方向・真横は対象外
		var perp := absf(to.dot(Vector2(dir.y, -dir.x)))  # 方向からのズレ
		var score := proj + perp * 2.0     # 近くて方向が合うものほど小さい
		if score < best_score:
			best_score = score
			best = i
	if best != -1:
		_select(best)


func _select(i: int) -> void:
	_selected = i
	for idx in _markers.size():
		_markers[idx].set_highlight(idx == _selected)
	_refresh_prompt()


func _on_phase_changed() -> void:
	_apply_phase()


func _apply_phase() -> void:
	# 昼は選択中のアイコンを光らせ、夜は消す。
	var is_day := GameState.phase != GameState.Phase.NIGHT
	for idx in _markers.size():
		_markers[idx].set_highlight(is_day and idx == _selected)
	_refresh_prompt()


func _on_game_ended() -> void:
	_ended = true
	for m in _markers:
		m.set_highlight(false)
	HUD.set_prompt("――― 40日が過ぎた。世界の終わり。［E］でもう一度、夏を始める ―――")


func _refresh_prompt() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			var m = _markers[_selected]
			HUD.set_prompt("行き先を選ぶ：矢印/WASD で移動、［E］で「%s」へ ／ 予定なしは［Q］" % m.display_name)
		GameState.Phase.NIGHT:
			HUD.set_prompt("夜。今日を振り返る。［E］でカレンダーをめくって翌日へ")
