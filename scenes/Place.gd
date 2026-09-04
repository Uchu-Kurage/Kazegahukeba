extends ExploreMap
## 各場所の「中」のマップ。街から入ってきた1箇所を、2Dで歩き回れる。
##
## 中の人（NPC）に近づいて E を押すと「その枠でここで過ごす」＝時間帯を消費して街へ戻る。
## 出口に近づいて E（または Q）を押すと、過ごさずに街へ戻る（別の場所を選び直せる）。
## どの場所を開くかは Nav.current_location_id で受け取る。

const EXIT_ID := "__exit__"

var _place_id := ""
var _place_name := ""
var _character := ""


func _build_map() -> void:
	_place_id = Nav.current_location_id
	_place_name = Locations.name_of(_place_id)
	_character = Locations.character_of(_place_id)

	var bg := PlaceBackground.new()  # 場所ごとの内装（河川敷・境内・通り・座敷）
	bg.place_id = _place_id
	add_child(bg)

	# 場所ごとの環境音（BGMは街から継続させる）。
	AudioManager.play_ambient(AudioManager.ambient_for_place(_place_id))

	# 過ごす対象（中の人。いなければ「ここで過ごす」）。id は場所ID にしておく。
	var spend_name := _place_name if _character != "" else "%s（ここで過ごす）" % _place_name
	add_spot(_place_id, spend_name, _character, Vector2(576, 280))

	# 出口。
	add_spot(EXIT_ID, "← 町へ戻る", "", Vector2(200, 540))


func _player_start() -> Vector2:
	return Vector2(576, 500)


func _on_interact(spot) -> void:
	if Dialogue.is_active():
		return  # 会話中は E を会話送りに使う（Place 側は反応しない）
	if spot == null:
		return
	if spot.location_id == EXIT_ID:
		AudioManager.play_sfx("cancel")
		Nav.go_to_town()  # 過ごさずに戻る
		return
	AudioManager.play_sfx("confirm")
	_talk()  # 中の人と会話 → 終わったら枠を消費して街へ


## 会話を始める。専用の立ち絵は使わず、マップ上のキャラのまま会話ボックスで進める。
func _talk() -> void:
	set_player_can_move(false)  # 会話中は歩けない
	# 選択肢が選ばれるたびに効果（好感度・フラグ）を GameState に反映する。
	Dialogue.option_selected.connect(_on_option_selected)
	Dialogue.finished.connect(_on_talk_finished, CONNECT_ONE_SHOT)
	# 三ルート共通の解決器が「その日・その枠で何を流すか」を決める（§4 の優先順位）。
	Dialogue.start(Story.script_for_location(_place_id, GameState))


## 選んだ選択肢の効果を状態に反映する。Dialogue は「何が選ばれたか」を伝えるだけで、
## それが何を意味するか（好感度・フラグ）はここ（ゲーム側）が決める。
func _on_option_selected(option: Dictionary) -> void:
	for who in option.get("affinity", {}):
		GameState.add_affinity(who, int(option["affinity"][who]))
	for flag_name in option.get("set", {}):
		GameState.set_flag(flag_name, option["set"][flag_name])
	# 立場（中盤の A/B/C）は route_id 別の辞書で受け取り、そのルートに立てる。
	for route_id in option.get("stance", {}):
		GameState.set_stance(route_id, option["stance"][route_id])


func _on_talk_finished() -> void:
	if Dialogue.option_selected.is_connected(_on_option_selected):
		Dialogue.option_selected.disconnect(_on_option_selected)
	GameState.choose_location(_place_id)  # この枠を消費
	Nav.go_to_town()


func _on_skip() -> void:
	if Dialogue.is_active():
		return
	# 場所の中では Q も「戻る」に割り当てる（過ごさずに街へ）。
	Nav.go_to_town()


func _refresh_prompt() -> void:
	if _current_spot == null:
		HUD.set_prompt("%s。WASD／矢印で歩く。人に近づいて［E］ ／［Q］で戻る" % _place_name)
	elif _current_spot.location_id == EXIT_ID:
		HUD.set_prompt("［E］で町へ戻る（まだ過ごしていない）")
	elif _current_spot.character_id != "":
		HUD.set_prompt("「%s」に話しかける：［E］（この枠を使う）" % _current_spot.display_name)
	else:
		HUD.set_prompt("「%s」で過ごす：［E］（この枠を使う）" % _current_spot.display_name)
