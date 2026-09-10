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
var _road_hotspots := {}  # 道マップの基本セット風物詩スポット（"look_<id>" → WeatherScenes entry）
var _walk_overlay: WalkOverlay  # 歩行領域の可視化（F10で切替。調整用）
var _weather_overlay: ColorRect  # 天気の空色オーバーレイ（第9弾）
var _weather_fx: WeatherFX       # 天気の専用ビジュアル（虹・星空・霧・雨）


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

	# 出口（画面端の道の切れ目）。第10弾：エリア内の画面へ続く出口だけを残す（エリア間は歩かせない）。
	for ex in _field.get("exits", []):
		if Areas.same_area(String(_field["id"]), String(ex["to"])):
			add_spot(String(ex["id"]), String(ex["label"]), "", ex["pos"])

	# 人／一人で過ごす場所（過ごす＝半日の本イベント。家は起点なので置かない）。
	if String(_field["id"]) != Areas.HOME:
		for n in FieldMaps.npcs_of(String(_field["id"])):
			add_spot(String(n["spend"]), String(n["name"]), String(n["who"]), n["pos"])

	# 道マップ（第9弾）：基本セットの風物詩を「調べどころ」として置く（枠非消費・常設・再閲覧可）。
	if Roads.is_road(String(_field["id"])):
		for e in WeatherScenes.standing_at(String(_field["id"])):
			var sid := "look_%s" % String(e["id"])
			add_spot(sid, WeatherScenes.title_of(String(e["id"])), "", e["pos"])
			_road_hotspots[sid] = e


## プレイヤー生成後：道の上だけ歩けるよう制限し、来た画面に対応する入口に立たせる。
func _ready_done() -> void:
	var roads: Array[Rect2] = []
	for r in _field.get("roads", []):
		roads.append(r)
	_player.walkable_rects = roads
	_player.position = FieldMaps.entry_position(_field, _from_id)
	# 奥行きスケールは画面ごとの設定（FieldMaps の depth）で。手前で最大・奥で最小、base で背丈調整。
	var d: Dictionary = _field.get("depth", {})
	_player.set_depth_scale(
		float(d.get("y_near", FieldMaps.DEPTH_Y_NEAR)), float(d.get("y_far", FieldMaps.DEPTH_Y_FAR)),
		float(d.get("near", FieldMaps.DEPTH_SCALE_NEAR)), float(d.get("far", FieldMaps.DEPTH_SCALE_FAR)),
		float(d.get("base", FieldMaps.DEPTH_SCALE_BASE)))
	# 歩行領域オーバーレイ（既定は非表示。F10 で切替して範囲・縮尺を目で見て詰める）。
	_walk_overlay = WalkOverlay.new()
	_walk_overlay.rects = _field.get("roads", [])
	_walk_overlay.y_near = float(d.get("y_near", FieldMaps.DEPTH_Y_NEAR))
	_walk_overlay.y_far = float(d.get("y_far", FieldMaps.DEPTH_Y_FAR))
	_walk_overlay.z_index = 50
	_walk_overlay.visible = false
	add_child(_walk_overlay)
	# 天気（第9弾）：空色オーバーレイと環境音を今日の天気で切替。
	_apply_weather(GameState.weather_today())
	HUD.set_shown(true)
	# 枠・日付の進行に追従（プロンプト更新／翌朝は家へ／8/31で終幕）。
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	GameState.day_changed.connect(_on_day_changed)
	GameState.game_ended.connect(_on_game_ended)
	# 第10弾：部屋（家）の午前／午後は「朝の独白＋予報＋部屋の風物詩」を流してから見下ろしマップへ。
	#   夜は就寝（下の _on_interact）。それ以外の画面（エリア内）は道・風物詩の演出だけ。
	if String(_field["id"]) == Areas.HOME:
		if GameState.phase != GameState.Phase.NIGHT:
			_home_intro_and_map()
		else:
			_maybe_ambient_fubutsushi()  # 夜の家：ヤモリ・網戸ごしの風など
	else:
		# 道マップ（第9弾）：入場時に独白・見逃せる一品・遭遇（すべて枠非消費）。
		_maybe_road_intro()
		# 風物詩（第10弾）：入場時に環境発見を1回だけ（天気・時間帯・期間で出し分け・枠非消費）。
		_maybe_ambient_fubutsushi()


func _player_start() -> Vector2:
	return _field.get("start", Vector2(576, 365))


## 部屋（家）の朝／昼：独白 → 明日の予報（朝・一日一回・山場は的中）→ 部屋の風物詩（環境発見）を
## ひと続きに流し、終わったら見下ろしマップを開く（＝行き先を選ぶ）。すべて枠非消費。
func _home_intro_and_map() -> void:
	var nodes: Array = RoomLines.intro(GameState)  # 朝の独白（天気・時期・約束で出し分け）
	# 明日の予報（世界に溶けた開示）＝朝だけ・一日一回・最終日は出さない。
	if GameState.phase == GameState.Phase.MORNING \
			and GameState.last_forecast_day != GameState.day_index \
			and GameState.day_index + 1 < GameState.TOTAL_DAYS:
		var fc := _forecast_nodes()
		if not fc.is_empty():
			GameState.last_forecast_day = GameState.day_index
			nodes.append_array(fc)
	# 部屋の風物詩（朝顔・扇風機・ヤモリ等）を環境発見（枠非消費・一期一会）。
	var aid := GameState.evaluate_ambient_fubutsushi("home")
	if aid != "":
		nodes.append({ "speaker": "", "text": String(Fubutsushi.entry_of(aid).get("record_text", "")) })
	if nodes.is_empty():
		Nav.go_to_overworld()
		return
	set_player_can_move(false)
	Dialogue.finished.connect(func() -> void: Nav.go_to_overworld(), CONNECT_ONE_SHOT)
	Dialogue.start(nodes)


## 明日の予報セリフ（1行）。予報は weather_forecast（山場は的中／通常は揺らぎ有）。
func _forecast_nodes() -> Array:
	var fc := GameState.weather_forecast()
	var phrase := Weather.forecast_phrase(fc)
	if Weather.is_key_day(GameState.day_index + 1):
		# 山場の前日：心の準備をさせる、はっきりした予報。
		match fc:
			Weather.TYPHOON:
				return [{ "speaker": "ラジオ", "text": "……大型の台風が近づいています。明日は大荒れになるでしょう。外出はお控えください。" }]
			Weather.CLEAR_MAX:
				return [{ "speaker": "祖母", "text": "あしたは雲ひとつない快晴だってさ。いい一日になりそうだねえ。" }]
			Weather.SHOWER:
				return [{ "speaker": "ラジオ", "text": "……明日は所により、にわか雨があるでしょう。急な空模様の変化にご注意を。" }]
			Weather.FOG:
				return [{ "speaker": "祖母", "text": "あしたの朝は、濃い霧が出るらしいよ。足もと、気をつけてね。" }]
			Weather.SUNSET:
				return [{ "speaker": "", "text": "朝刊の予報欄。「あすは日中晴れ、夕方は美しい夕焼けが見られるでしょう」。" }]
		return [{ "speaker": "ラジオ", "text": "……明日は%sになるでしょう。" % phrase }]
	# 通常日：日替わりの情報源で、さらっと。
	match GameState.day_index % 3:
		0:
			return [{ "speaker": "祖母", "text": "あしたは%sになりそうだねえ。" % phrase }]
		1:
			return [{ "speaker": "ラジオ", "text": "……あすの天気は、%sでしょう。" % phrase }]
		_:
			return [{ "speaker": "", "text": "朝刊の予報欄に目をやる。あすは%s、とある。" % phrase }]


# --- 道マップ（第9弾）＝通路シーンの独白・風物詩・遭遇（すべて枠非消費）------------

## 入場時に一度だけ流す：見逃せる一品（一期一会）＋遭遇（1日1回）＋独白（1日1回）。
## 枠は消費しない（choose_location を呼ばない）。約束が絡む遭遇は promise 効果で予定表に記帳される。
func _maybe_road_intro() -> void:
	var rid := String(_field.get("id", ""))
	if not Roads.is_road(rid):
		return
	if GameState.phase == GameState.Phase.NIGHT:
		return
	var day := GameState.day_index
	var seq: Array = []
	# 見逃せる一品（天気/日付限定・一度きり）。図鑑に記録し、以後は出ない。
	var scene := WeatherScenes.match(day, rid, GameState.weather_today(), GameState.flags)
	if not scene.is_empty():
		seq.append_array(Story.flatten(scene["script"], GameState.flags))
		seq.append({ "effect": { "set": { WeatherScenes.flag_of(String(scene["id"])): true } } })
	# 遭遇（1日1回。葵は喪失後に現れない＝Roads 側で空を返す）。
	var enc_key := "road_enc_%s_%d" % [rid, day]
	if not GameState.flags.get(enc_key, false):
		var enc := Story.flatten(Roads.encounter(rid, GameState), GameState.flags, GameState)
		if not enc.is_empty():
			seq.append_array(enc)
			GameState.set_flag(enc_key, true)
	# 独白（1日1回。他に何も無くても、道の性格を一言）。
	var mono_key := "road_mono_%s_%d" % [rid, day]
	if not GameState.flags.get(mono_key, false):
		var mono := Roads.monologue(rid, GameState)
		if not mono.is_empty():
			seq.append_array(mono)
			GameState.set_flag(mono_key, true)
	if seq.is_empty():
		return
	set_player_can_move(false)
	Dialogue.option_selected.connect(_on_option_selected)
	Dialogue.finished.connect(_on_road_seq_finished, CONNECT_ONE_SHOT)
	Dialogue.start(seq)


# --- 夏の風物詩コレクション（第10弾）＝環境発見（枠非消費）------------------

## 入場時に一度だけ、この画面で見つかる風物詩を判定する。既に別の会話中なら見送る（一期一会）。
## 発見時は既存メッセージウィンドウで record_text を静かに出すだけ（達成音・トーストは無し）。
func _maybe_ambient_fubutsushi() -> void:
	if Dialogue.is_active():
		return  # 予報・道の会話などを優先（この入場では見送る＝取りこぼしは咎めない）
	var fid := String(_field.get("id", ""))
	if Roads.is_road(fid):
		return  # 道は道の風物詩（別系統）に任せる
	var id := GameState.evaluate_ambient_fubutsushi(_place_token(fid))
	if id == "":
		return
	var e := Fubutsushi.entry_of(id)
	set_player_can_move(false)
	AudioManager.play_sfx("page")  # 風鈴一つ程度の控えめな合図（達成音は鳴らさない）
	Dialogue.finished.connect(_on_road_seq_finished, CONNECT_ONE_SHOT)  # 後片付け（枠は消費しない）
	Dialogue.start([{ "speaker": "", "text": String(e.get("record_text", "")) }])


## 画面ID → 風物詩マスタの場所トークン（設計書の命名に合わせる）。
func _place_token(field_id: String) -> String:
	match field_id:
		"shops": return "shopping"
		"fields": return "ricefield"
		"estuary": return "rivermouth"
	return field_id


## 道の風物詩（基本セット・常設）を眺める。図鑑に記録するが、道の風景としては残る（再閲覧可）。
func _inspect_hotspot(spot) -> void:
	var e: Dictionary = _road_hotspots.get(spot.location_id, {})
	if e.is_empty():
		return
	AudioManager.play_sfx("confirm")
	GameState.set_flag(WeatherScenes.flag_of(String(e["id"])), true)  # 図鑑へ（常設なので消えない）
	set_player_can_move(false)
	Dialogue.finished.connect(_on_road_seq_finished, CONNECT_ONE_SHOT)
	Dialogue.start(Story.flatten(e["script"], GameState.flags))


## 道の会話（独白・遭遇・風物詩）が終わったとき。枠は消費しない（choose_location を呼ばない）。
func _on_road_seq_finished() -> void:
	if Dialogue.option_selected.is_connected(_on_option_selected):
		Dialogue.option_selected.disconnect(_on_option_selected)
	set_player_can_move(true)
	_refresh_prompt()


## 今日の天気を反映：画面全体に薄い色を重ね（雰囲気）、環境音を切り替える。
## 空色シェーダの本格版は後日。まずは色オーバーレイ＋音で「その天気の日の一枚」を出す。
func _apply_weather(weather_id: String) -> void:
	var info := Weather.info(weather_id)
	# 空色オーバーレイ（背景の上・キャラの上に薄く。歩行デバッグ表示より下）。
	if _weather_overlay == null:
		_weather_overlay = ColorRect.new()
		_weather_overlay.size = Vector2(FieldMaps.VIEW_W, FieldMaps.VIEW_H)
		_weather_overlay.z_index = 20
		_weather_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_weather_overlay)
	_weather_overlay.color = info["tint"]
	# 天気の専用ビジュアル（霧の帯・雨脚・雨上がりの虹）を色の上に重ねる。
	_ensure_weather_fx()
	_weather_fx.setup(_fx_mode_for(weather_id))
	# 環境音："silence"=無音に近づける／""=屋外の既定（蝉）／それ以外はそのキー。
	var amb := String(info["ambient"])
	if amb == "silence":
		AudioManager.stop_ambient()
	elif amb != "":
		AudioManager.play_ambient(amb)
	else:
		AudioManager.play_ambient("cicada")


func _ensure_weather_fx() -> void:
	if _weather_fx == null:
		_weather_fx = WeatherFX.new()
		_weather_fx.z_index = 25  # 色オーバーレイ(20)の上・歩行デバッグ(50)の下
		add_child(_weather_fx)


## 昼の天気 → 専用ビジュアルのモード。
func _fx_mode_for(weather_id: String) -> String:
	match weather_id:
		Weather.FOG: return "fog"
		Weather.RAIN, Weather.TYPHOON: return "rain"
		Weather.SHOWER: return "rainbow"  # 夕立の晴れ間の虹＋弱い雨
	return "none"


## 夜の情景用ビジュアル（特別な夜・就寝前の限定風景で使う）。
## 暗幕をかけ、快晴なら星空／天の川、荒天なら雨。
func _apply_night_fx() -> void:
	_ensure_weather_fx()
	if _weather_overlay != null:
		_weather_overlay.color = Color(0.05, 0.07, 0.16, 0.35)  # 夜の暗幕
	var w := GameState.weather_today()
	if w == Weather.CLEAR_MAX or w == Weather.CLEAR:
		_weather_fx.setup("stars")
	elif w == Weather.RAIN or w == Weather.SHOWER or w == Weather.TYPHOON:
		_weather_fx.setup("rain")
	else:
		_weather_fx.setup("none")


## デバッグ：F10 で歩行領域オーバーレイを切替（interact/skip は親 ExploreMap に委譲）。
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_walk"):
		if _walk_overlay != null:
			_walk_overlay.visible = not _walk_overlay.visible
			_walk_overlay.queue_redraw()
			HUD.set_prompt("歩行領域オーバーレイ: %s（F10）" % ("ON" if _walk_overlay.visible else "OFF"))
		return
	# 第10弾：エリア内のどこからでも［Q］一発で家に帰る（道の逆走はさせない）。
	# 家・夜・会話中は無効（誤操作で帰らない）。
	if event.is_action_pressed("skip"):
		if String(_field.get("id", "")) != Areas.HOME and GameState.phase != GameState.Phase.NIGHT and not Dialogue.is_active():
			_go_home()
		return
	super(event)


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
	elif _road_hotspots.has(spot.location_id):
		_inspect_hotspot(spot)  # 道の風物詩を眺める（枠非消費・常設）
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
	# 第10弾：枠はエリア選択で確定済み。ここでは半日1回だけ関係値を入れ、phase は進めない
	#   （進むのは「家に帰る」で）。エリア内は続けて歩ける（別の相手・道・風物詩へ）。
	GameState.spend_in_area(location_id)
	set_player_can_move(true)
	_refresh_prompt()


## 家に帰る＝その半日を終える（phase を進める）→ 部屋へ一発で戻る（道の逆走なし）。
func _go_home() -> void:
	AudioManager.play_sfx("cancel")
	GameState.end_halfday()
	Nav.go_to_field(Areas.HOME, "")


## 約束（promise）を予定表に記帳する。in_days は今日からの相対日。
func _record_promise(pr: Dictionary) -> void:
	var day := GameState.day_index + int(pr.get("in_days", 0))
	GameState.make_promise(day, String(pr.get("character", "")), String(pr.get("place", "")),
		String(pr.get("time_of_day", "")), String(pr.get("flavor", "")))


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
	# 葵ルートの「傾き」（三分岐の布石。方向のみ記録）。
	if option.has("lean"):
		GameState.bump_lean(String(option["lean"]))
	# 約束の記帳（第9弾）：応じた選択肢が持つ promise を予定表に書き込む。
	if option.has("promise"):
		_record_promise(option["promise"])
	# 8/31 の葵の約束（§5-3）：場所は傾きの着地から動的に決まる。
	if option.get("promise_aoi_final", false):
		GameState.make_aoi_final_promise()
	# 風物詩の発見（第10弾）：イベント／会話から明示発火（id 文字列または配列）。
	if option.has("discover"):
		var d = option["discover"]
		if d is Array:
			for x in d:
				GameState.discover_fubutsushi(String(x))
		else:
			GameState.discover_fubutsushi(String(d))


# --- 夜（§Q1：特別な夜があれば発生／無ければ就寝で翌朝）------------------
func _night_action() -> void:
	var night := Nights.for_day(GameState.day_index)
	if not night.is_empty():
		_start_special_night(night)
		return
	# 特別な夜でなければ就寝。ただし「夜の限定風景」（快晴の星空・台風の夜 等）があれば
	# 寝る前に一度だけ流す（見逃したら再発生しない）。
	var scene := WeatherScenes.night_match(GameState.day_index, GameState.weather_today(), "sleep", GameState.flags)
	if scene.is_empty():
		AudioManager.play_sfx("page")
		GameState.flip_calendar()   # 就寝 → 翌日へ
	else:
		_start_sleep_scene(scene)


## 就寝前の夜の限定風景を流し、終わったら翌日へ。
func _start_sleep_scene(scene: Dictionary) -> void:
	_apply_night_fx()  # 夜の暗幕＋星空/雨
	set_player_can_move(false)
	Dialogue.option_selected.connect(_on_option_selected)
	Dialogue.finished.connect(_on_sleep_scene_finished, CONNECT_ONE_SHOT)
	var nodes := Story.flatten(scene["script"], GameState.flags)
	nodes.append({ "effect": { "set": { WeatherScenes.flag_of(String(scene["id"])): true } } })
	Dialogue.start(nodes)


func _on_sleep_scene_finished() -> void:
	if Dialogue.option_selected.is_connected(_on_option_selected):
		Dialogue.option_selected.disconnect(_on_option_selected)
	AudioManager.play_sfx("page")
	GameState.flip_calendar()


func _start_special_night(night: Dictionary) -> void:
	_apply_night_fx()  # 夜の暗幕＋星空/雨（祭りの快晴夜＝天の川）
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
		if not _exit_by_id(s.location_id).is_empty():
			HUD.set_prompt("［E］で「%s」へ ／［Q］家に帰る" % s.display_name)
		elif _road_hotspots.has(s.location_id):
			HUD.set_prompt("［E］で「%s」を眺める ／［Q］家に帰る" % s.display_name)
		else:
			HUD.set_prompt("［E］で「%s」と過ごす ／［Q］家に帰る" % s.display_name)
	else:
		HUD.set_prompt("%s。WASD・矢印で歩く（移動は無料）／［Q］で家に帰る（この半日を終える）" % String(_field.get("name", "")))
