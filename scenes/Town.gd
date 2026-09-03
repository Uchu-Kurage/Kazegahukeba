extends ExploreMap
## 街全体のマップ（メインシーン）。
##
## ここでは「どの場所に行くか」を選ぶ。場所ゲートに近づいて E を押すと、
## その場所の中（Place シーン）へ移動する。夜は歩けず、振り返って翌日へ。

var _ended := false


func _build_map() -> void:
	add_ground(Color(0.15, 0.18, 0.16))
	for loc in Locations.ALL:
		add_spot(loc["id"], loc["name"], loc["character"], loc["pos"])


func _player_start() -> Vector2:
	return Vector2(576, 360)


func _ready_done() -> void:
	# 夜になった／翌朝になった、を受けて歩ける状態とプロンプトを更新する。
	# Town は遷移のたびに作り直されるので、この接続もそのたびに張り直される。
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	GameState.game_ended.connect(_on_game_ended)
	_apply_phase()


func _on_interact(spot) -> void:
	if _ended:
		_restart()
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			if spot != null:
				Nav.go_to_place(spot.location_id)  # 場所の中へ移動
		GameState.Phase.NIGHT:
			GameState.flip_calendar()              # カレンダーをめくる


func _on_skip() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			GameState.skip_slot()


func _on_phase_changed() -> void:
	_apply_phase()


func _apply_phase() -> void:
	set_player_can_move(GameState.phase != GameState.Phase.NIGHT)
	_refresh_prompt()


func _on_game_ended() -> void:
	_ended = true
	set_player_can_move(false)
	HUD.set_prompt("――― 40日が過ぎた。世界の終わり。［E］でもう一度、夏を始める ―――")


func _restart() -> void:
	_ended = false
	GameState.start_new_run()  # phase_changed が飛び、歩ける状態も戻る


func _refresh_prompt() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			if _current_spot != null:
				HUD.set_prompt("「%s」へ行く：［E］で中へ ／ 予定なしは［Q］" % _current_spot.display_name)
			else:
				HUD.set_prompt("移動：WASD／矢印。行きたい場所のゲートへ。予定なしは［Q］")
		GameState.Phase.NIGHT:
			HUD.set_prompt("夜。今日を振り返る。［E］でカレンダーをめくって翌日へ")
