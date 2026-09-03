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

	add_ground(Color(0.18, 0.16, 0.20))

	# 過ごす対象（中の人。いなければ「ここで過ごす」）。id は場所ID にしておく。
	var spend_name := _place_name if _character != "" else "%s（ここで過ごす）" % _place_name
	add_spot(_place_id, spend_name, _character, Vector2(576, 280))

	# 出口。
	add_spot(EXIT_ID, "← 町へ戻る", "", Vector2(200, 540))


func _player_start() -> Vector2:
	return Vector2(576, 500)


func _on_interact(spot) -> void:
	if spot == null:
		return
	if spot.location_id == EXIT_ID:
		Nav.go_to_town()  # 過ごさずに戻る
		return
	# 中の人 or 過ごす対象 → その枠を消費して街へ戻る。
	GameState.choose_location(_place_id)
	Nav.go_to_town()


func _on_skip() -> void:
	# 場所の中では Q も「戻る」に割り当てる（過ごさずに街へ）。
	Nav.go_to_town()


func _refresh_prompt() -> void:
	if _current_spot == null:
		HUD.set_prompt("%s。WASD／矢印で歩く。中の人に近づいて［E］で過ごす" % _place_name)
	elif _current_spot.location_id == EXIT_ID:
		HUD.set_prompt("［E］で町へ戻る（まだ過ごしていない）")
	else:
		HUD.set_prompt("「%s」で過ごす：［E］（この枠を使う）" % _current_spot.display_name)
