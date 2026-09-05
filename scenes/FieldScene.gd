extends ExploreMap
## 散策画面（実装指示 第6弾）＝『ぼくのなつやすみ』方式の1画面。
##
## 背景・道（歩ける帯）・出口を FieldMaps（データ）から受け取る汎用の器。
## 道の上だけ歩け、画面端の出口に近づいて［E］で隣の画面へ遷移する。
## ★移動・遷移では枠を消費しない（GameState の日付/フェーズを一切触らない）。
##   枠を使うのは「人と過ごす／出来事に関わる」ときだけ（§4。まずは移動の仕組みを優先）。
##
## どの画面を開くかは Nav.current_field_id で受け取る（既定 riverbank）。
## ExploreMap を継承：プレイヤー生成・対象(出口)への出入り検知・E入力の土台をそのまま使う。

var _field := {}
var _from_id := ""      # どの画面から来たか（入口位置の決定に使う）


func _build_map() -> void:
	var fid := Nav.current_field_id if Nav.current_field_id != "" else "riverbank"
	_field = FieldMaps.by_id(fid)
	_from_id = Nav.field_from_id
	if _field.is_empty():
		_field = FieldMaps.by_id("riverbank")

	# 背景（PNG or プレースホルダ）。道も薄く敷いて歩ける帯を見せる。
	var bg := FieldBackground.new()
	bg.bg_path = String(_field.get("bg", ""))
	bg.roads = _field.get("roads", [])
	bg.field_id = String(_field["id"])
	add_child(bg)

	# 出口（画面端の道の切れ目）。ExploreMap の対象(LocationSpot)を流用して置く。
	for ex in _field.get("exits", []):
		add_spot(String(ex["id"]), String(ex["label"]), "", ex["pos"])


## プレイヤー生成後：道の上だけ歩けるよう制限し、入ってきた向きの入口に立たせる。
func _ready_done() -> void:
	var roads: Array[Rect2] = []
	for r in _field.get("roads", []):
		roads.append(r)
	_player.walkable_rects = roads
	_player.position = FieldMaps.entry_position(_field, _from_id)
	# 奥行きのスケール変化（§2-2）：手前ほど大きく、奥ほど小さく。全散策画面で共通。
	_player.set_depth_scale(FieldMaps.DEPTH_Y_NEAR, FieldMaps.DEPTH_Y_FAR,
		FieldMaps.DEPTH_SCALE_NEAR, FieldMaps.DEPTH_SCALE_FAR)
	HUD.set_shown(true)
	AudioManager.stop_ambient()


func _player_start() -> Vector2:
	# 初期位置は _ready_done で入口に合わせて上書きするので、ここは道の上の安全な既定。
	return _field.get("start", Vector2(576, 540))


## 出口に近づいて［E］：接続先があれば遷移（枠は使わない）。無ければ「未接続」を知らせる。
func _on_interact(spot) -> void:
	if Dialogue.is_active():
		return
	if spot == null:
		return
	var ex := _exit_by_id(spot.location_id)
	if ex.is_empty():
		return
	var dest := String(ex.get("to", ""))
	if dest == "":
		# §1：接続先はまだ無い。出口が「反応」したことだけ見せる（黒画面は使わずログ＋表示）。
		AudioManager.play_sfx("cancel")
		HUD.set_prompt("「%s」――この先はまだ繋がっていない（§1: 出口の反応を確認）" % String(ex["label"]))
		print("[field] exit reacted: %s (to=未接続)" % String(ex["id"]))
		return
	# 接続先あり：今いる画面IDを渡して遷移（遷移先は「戻る出口」の位置に出す。枠は消費しない）。
	AudioManager.play_sfx("confirm")
	Nav.go_to_field(dest, String(_field["id"]))


func _exit_by_id(exit_id: String) -> Dictionary:
	for ex in _field.get("exits", []):
		if String(ex["id"]) == exit_id:
			return ex
	return {}


func _refresh_prompt() -> void:
	if _current_spot != null:
		HUD.set_prompt("［E］で「%s」へ　／　WASD・矢印で歩く（移動は枠を使わない）" % _current_spot.display_name)
	else:
		HUD.set_prompt("%s。道の上を歩ける。端の出口へ近づくと隣へ／WASD・矢印で歩く" % String(_field.get("name", "")))
