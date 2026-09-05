extends ExploreMap
## 散策画面（実装指示 第6弾）＝『ぼくのなつやすみ』方式の1画面。
##
## 背景・道（歩ける帯）・出口・人 を FieldMaps（データ）から受け取る汎用の器。
## 道の上だけ歩け、画面端の出口に近づいて［E］で隣の画面へ遷移する。
##
## ★移動・遷移では枠を消費しない（GameState の日付/フェーズを触らない）。
##   枠を使うのは「人と過ごす／一人で過ごす」を選んだ瞬間だけ（§4）。過ごすと choose_location で
##   枠が進む（午前→午後→夜）。夜は特別な夜があれば発生／無ければ就寝で翌朝、家スタート（§Q1）。
##
## 内部の枠・関係値・エンディング判定は既存の location_id のまま（Story/Dialogue/Nights/Endings を再利用）。
## FieldScene は「どの画面で誰と会うか」だけを担当し、過ごす時に既存の location_id を choose_location する。

const EXIT_PREFIX := "to_"

var _field := {}
var _from_id := ""      # どの画面から来たか（入口位置の決定に使う）


func _build_map() -> void:
	var fid := Nav.current_field_id if Nav.current_field_id != "" else "riverbank"
	_field = FieldMaps.by_id(fid)
	_from_id = Nav.field_from_id
	if _field.is_empty():
		_field = FieldMaps.by_id("riverbank")

	# 背景（PNG or プレースホルダ）。
	var bg := FieldBackground.new()
	bg.bg_path = String(_field.get("bg", ""))
	bg.roads = _field.get("roads", [])
	bg.field_id = String(_field["id"])
	add_child(bg)

	# 出口（画面端の道の切れ目）。ExploreMap の対象(LocationSpot)を流用して置く。
	for ex in _field.get("exits", []):
		add_spot(String(ex["id"]), String(ex["label"]), "", ex["pos"])

	# 人／一人で過ごす場所（過ごすと枠を消費する）。id は既存の location_id（spend）。
	for n in FieldMaps.npcs_of(String(_field["id"])):
		add_spot(String(n["spend"]), String(n["name"]), String(n["who"]), n["pos"])


## プレイヤー生成後：道の上だけ歩けるよう制限し、来た画面に対応する入口に立たせる。
func _ready_done() -> void:
	var roads: Array[Rect2] = []
	for r in _field.get("roads", []):
		roads.append(r)
	_player.walkable_rects = roads
	_player.position = FieldMaps.entry_position(_field, _from_id)
	_player.set_depth_scale(FieldMaps.DEPTH_Y_NEAR, FieldMaps.DEPTH_Y_FAR,
		FieldMaps.DEPTH_SCALE_NEAR, FieldMaps.DEPTH_SCALE_FAR)
	HUD.set_shown(true)
	AudioManager.stop_ambient()
	# 枠・日付の進行に追従（プロンプト更新／翌朝は家へ／8/31で終幕）。
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	GameState.day_changed.connect(_on_day_changed)
	GameState.game_ended.connect(_on_game_ended)


func _player_start() -> Vector2:
	return _field.get("start", Vector2(576, 365))


func _on_interact(spot) -> void:
	if Dialogue.is_active():
		return
	# 夜：出口・人ではなく「特別な夜 or 就寝」だけができる（§Q1：2枠で夜→翌日）。
	if GameState.phase == GameState.Phase.NIGHT:
		_night_action()
		return
	if spot == null:
		return
	var ex := _exit_by_id(spot.location_id)
	if not ex.is_empty():
		_take_exit(ex)
	else:
		_spend(spot)  # 人／一人で過ごす場所 → 枠を消費して既存の会話・イベントへ


## 出口：接続先があれば遷移（枠は使わない）。無ければ未接続を知らせる。
func _take_exit(ex: Dictionary) -> void:
	var dest := String(ex.get("to", ""))
	if dest == "":
		AudioManager.play_sfx("cancel")
		HUD.set_prompt("「%s」――この先はまだ繋がっていない" % String(ex["label"]))
		return
	AudioManager.play_sfx("confirm")
	Nav.go_to_field(dest, String(_field["id"]))


## 過ごす：ここで初めて枠を消費する。既存の Story/Dialogue をそのまま流し、
## 終わったら choose_location で枠を1つ進める（午前→午後→夜）。散策に戻る。
func _spend(spot) -> void:
	AudioManager.play_sfx("confirm")
	set_player_can_move(false)
	Dialogue.option_selected.connect(_on_option_selected)
	Dialogue.finished.connect(_on_spend_finished.bind(String(spot.location_id)), CONNECT_ONE_SHOT)
	Dialogue.start(Story.script_for_location(String(spot.location_id), GameState))


func _on_spend_finished(location_id: String) -> void:
	if Dialogue.option_selected.is_connected(_on_option_selected):
		Dialogue.option_selected.disconnect(_on_option_selected)
	GameState.choose_location(location_id)   # 枠を消費（phase を進める）
	set_player_can_move(true)
	_refresh_prompt()


## 会話の選択肢／効果ノードの効果を GameState に反映する（Place/Town と同じ処理）。
func _on_option_selected(option: Dictionary) -> void:
	for who in option.get("affinity", {}):
		GameState.add_affinity(who, int(option["affinity"][who]))
	for flag_name in option.get("set", {}):
		GameState.set_flag(flag_name, option["set"][flag_name])
	for cname in option.get("count", {}):
		GameState.bump(cname, int(option["count"][cname]))
	for route_id in option.get("stance", {}):
		GameState.set_stance(route_id, option["stance"][route_id])


# --- 夜（§Q1：特別な夜があれば発生／無ければ就寝で翌朝）------------------
func _night_action() -> void:
	var night := Nights.for_day(GameState.day_index)
	if night.is_empty():
		AudioManager.play_sfx("page")
		GameState.flip_calendar()   # 就寝 → 翌日へ
	else:
		_start_special_night(night)


func _start_special_night(night: Dictionary) -> void:
	AudioManager.play_sfx("confirm")
	set_player_can_move(false)
	Dialogue.option_selected.connect(_on_option_selected)
	Dialogue.finished.connect(_on_night_finished, CONNECT_ONE_SHOT)
	Dialogue.start(Nights.script_for(night, GameState))


func _on_night_finished() -> void:
	if Dialogue.option_selected.is_connected(_on_option_selected):
		Dialogue.option_selected.disconnect(_on_option_selected)
	AudioManager.play_sfx("page")
	GameState.flip_calendar()


# --- 日付・フェーズの進行に追従 --------------------------------------
func _on_phase_changed() -> void:
	_refresh_prompt()


func _on_day_changed(_index: int) -> void:
	# 翌朝は家からスタート（§Q1）。※初回入場時は go_to_field 経由なのでここは翌日以降のみ発火。
	Nav.go_to_field("home", "")


func _on_game_ended() -> void:
	Nav.go_to_ending()  # 8/31 を越えた → エンディングへ


func _exit_by_id(exit_id: String) -> Dictionary:
	for ex in _field.get("exits", []):
		if String(ex["id"]) == exit_id:
			return ex
	return {}


func _refresh_prompt() -> void:
	if GameState.phase == GameState.Phase.NIGHT:
		var night := Nights.for_day(GameState.day_index)
		if night.is_empty():
			HUD.set_prompt("夜。［E］で今日を終える（眠って翌朝へ）")
		else:
			HUD.set_prompt("特別な夜――「%s」。［E］で始める" % String(night["name"]))
		return
	if _current_spot != null:
		var s = _current_spot
		if _exit_by_id(s.location_id).is_empty():
			HUD.set_prompt("［E］で「%s」（この枠を使う）／ WASD・矢印で歩く（移動は無料）" % s.display_name)
		else:
			HUD.set_prompt("［E］で「%s」へ ／ WASD・矢印で歩く（移動は無料）" % s.display_name)
	else:
		HUD.set_prompt("%s。道を歩ける。人と過ごすと枠を使う／端の出口で隣へ（移動は無料）" % String(_field.get("name", "")))
