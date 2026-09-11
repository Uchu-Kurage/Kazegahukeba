class_name Story
extends RefCounted
## 三ルート共通のイベント解決器（実装指示 §1-3 / 全体タイムライン設計 §4）。
##
## ある日・ある枠で「どこへ行く／誰と過ごす」を選んだとき、何を再生するかを決める。
## 解決の優先順位（§4）：
##   1. 固定・強制イベント（その日付の背景。§2 の球磨離脱など）← Timeline がフラグで表現し、
##      各ルートの節目台本が if_flag で描写を出し分ける（下の flatten で展開）。
##   2. 選択中ルートの節目イベント（前提フラグ＋関係値＋時期＋その相手を選んだ枠）。
##   3. 節目が無ければ、関係値に応じた日常会話（filler）。
##   4. 葵の遍在遭遇（枠を消費せず、日替わりの居場所で軽く差し込む。§3）。
##
## ルートごとにハードコードで分岐しない。すべて Routes（データ）を回して解決する。
## → ルート追加＝Routes にデータを足す＋Dialogues に台本を足す、だけで済む。


## その場所の枠で流す会話（フラット化済み）を返す。Place から呼ぶ。
static func script_for_location(location_id: String, state) -> Array:
	var out: Array = []

	# 0. 天気限定風景（第9弾）＝「その天気×その場所×その日」に一度だけ。見逃したら再発生しない。
	#    枠の会話の先頭に差し込む（そのあと遍在・節目・日常が続く）。
	out.append_array(_weather_scene(location_id, state))

	# 1. 8/31 の葵（§5-3）＝予定表に葵が載る唯一の日。葵の場所で葵ルートなら、最後の約束を差し出す。
	#    ここで約束すると schedule[8/31] に葵が初めて書き込まれ、その“場所”が三分岐の着地を可視化する。
	var finalday := _aoi_finalday(location_id, state)
	if not finalday.is_empty():
		out.append_array(finalday)
		return out  # 最後の日の特別会話に専念（節目・日常には譲らない）

	# 4. 葵の遭遇（§5-1）は、ここでは会話の頭に差し込まない。
	#    葵は「別の人物」として FieldScene がマップに立たせ、話しかけたときだけ単体で遭遇が流れる
	#    （＝相手の会話に混ざらない＝一キャラ一人分のセリフになるよう分ける）。判定・台本は
	#    aoi_visits_at() / aoi_visit_script() を FieldScene から呼ぶ（実装はこのファイル下部）。

	# その場所に紐づくルート（＝深く過ごせる相手）を引く。
	var route := Routes.by_location(location_id)
	if route.is_empty():
		# ルートの無い場所（家など）は従来どおりの固定台本。
		out.append_array(flatten(Dialogues.for_location(location_id), state.flags))
		return out

	# 2. 選択中ルートの節目イベント（次の1件）。
	var ev := next_milestone(route, state.day_index, state.flags, state.affinity)
	if ev.is_empty():
		# 3. 節目が無い日は、関係値に応じた日常会話＋（球磨・由布は）約束の誘い。
		var level := _affinity_level(int(state.affinity.get(route["id"], 0)))
		out.append_array(flatten(Dialogues.route_filler(route["id"], level), state.flags))
		out.append_array(flatten(_invite_nodes(route["id"], state), state.flags, state))
		return out

	var key := String(ev["key"])
	var nodes := Dialogues.route_script(route["id"], key)
	out.append_array(flatten(nodes, state.flags))
	# 通過後に進行フラグを立てる効果ノード（表示せず状態だけ反映）。
	var eff := {}
	eff[Routes.flag_of(route["id"], key)] = true
	out.append({ "effect": { "set": eff } })
	return out


## いま解放されている“次の1件”の節目を返す（無ければ空 {}）。
## 前提：同ルートの requires フラグがすべて立ち、関係値 aff_min 以上、時期範囲内、未通過。
static func next_milestone(route: Dictionary, day: int, flags: Dictionary, affinity: Dictionary) -> Dictionary:
	var route_id := String(route["id"])
	var aff := int(affinity.get(route_id, 0))
	for m in route["milestones"]:
		var key := String(m["key"])
		if flags.get(Routes.flag_of(route_id, key), false):
			continue  # 通過済み
		if day < int(m["since"]) or day > int(m["until"]):
			continue  # 時期外
		if aff < int(m["aff_min"]):
			continue  # 関係値が足りない
		var ok := true
		for req in m["requires"]:
			if not flags.get(Routes.flag_of(route_id, String(req)), false):
				ok = false
				break
		if ok:
			return m
	return {}


# --- 天気限定風景（第9弾）------------------------------------------
## 今日の天気×この場所×今日 に、未見の限定風景があれば返す（一度きり）。
## 見たら進行フラグ wscene_<id> を立て、以後は出ない（＝見逃したら再発生しない）。
static func _weather_scene(location_id: String, state) -> Array:
	var e := WeatherScenes.match(state.day_index, location_id, Weather.of(state.day_index), state.flags)
	if e.is_empty():
		return []
	var out := flatten(e["script"], state.flags)
	out.append({ "effect": { "set": { WeatherScenes.flag_of(String(e["id"])): true } } })
	return out


# --- 葵の遭遇（§5-1）------------------------------------------------
## 特定の日・場所（・天気）の、未見の遭遇があれば差し込む（一度きり・見逃したら再発生しない）。
## 枠は消費しない。関わりの総量には数える（counters["aoi_ambient"]）＝記録者エンドの布石。
static func _aoi_encounter(location_id: String, state) -> Array:
	var aoi := Routes.by_id(Timeline.AOI_ROUTE)
	if not aoi.is_empty() and location_id == aoi["location"]:
		return []  # 葵の場所では深く過ごす（遭遇ではない）
	var e := AoiEncounters.match(state.day_index, location_id, Weather.of(state.day_index), state.flags)
	if e.is_empty():
		return []
	var out := flatten(e["script"], state.flags)
	out.append({ "effect": {
		"set": { AoiEncounters.flag_of(String(e["id"])): true },
		"count": { "aoi_ambient": 1 },
	} })
	return out


# --- 葵の遍在遭遇（§3）----------------------------------------------
## 今日の葵の居場所がこの場所なら、軽い遭遇を差し込む（枠は消費しない＝関係値は上げない）。
## ⚠️ 二層構造の鉄則：正体を匂わせない。「明るく親しみやすい普通の夏の娘」として通す。
static func _aoi_ambient(location_id: String, state) -> Array:
	var aoi := Routes.by_id(Timeline.AOI_ROUTE)
	if aoi.is_empty():
		return []
	if location_id == aoi["location"]:
		return []  # 葵の場所では深く過ごす（遍在ではない）
	if Timeline.aoi_spot(state.day_index) != location_id:
		return []  # 今日はここにいない
	return flatten(Dialogues.aoi_ambient(), state.flags)


# --- 葵を「別の人物」としてマップに立たせるための入口（FieldScene が使う）------
## 今日この場所（相手の場所）に葵が来ているか＝未見の特別遭遇 or 遍在遭遇が残っているか。
## 真なら FieldScene が葵を独立した話しかけ相手としてマップに置く（相手の会話には混ぜない）。
static func aoi_visits_at(location_id: String, state) -> bool:
	return not aoi_visit_script(location_id, state).is_empty()


## 葵の遭遇の会話ノード（特別遭遇があればそれ、無ければ遍在遭遇。枠非消費・フラット化済み・効果ノード付き）。
## 話しかけたときに単体で流す（Dialogue にそのまま渡せる）。無ければ空配列。
static func aoi_visit_script(location_id: String, state) -> Array:
	var enc := _aoi_encounter(location_id, state)
	if not enc.is_empty():
		return enc
	return _aoi_ambient(location_id, state)


# --- 8/31 の葵（§5-3）----------------------------------------------
## 最後の日、葵の場所で、葵ルートなら「最後の約束」を差し出す（予定表に載る唯一の例外）。
## 応じると schedule[8/31] に葵が書き込まれ、その“場所”が三分岐の着地を可視化する（自動でなく会話選択）。
## 「葵ルートに入っている」判定は、今この周回が葵の着地に向かっているか（＝Endings.pick が葵）で見る。
static func _aoi_finalday(location_id: String, state) -> Array:
	if int(state.day_index) != GameState.TOTAL_DAYS - 1:
		return []
	var aoi := Routes.by_id(Timeline.AOI_ROUTE)
	if aoi.is_empty() or location_id != aoi["location"]:
		return []
	if not _is_aoi_route(state):
		return []
	if not state.day_free(state.day_index):
		return []  # すでに約束済み（重ねて誘わない）
	return flatten(Dialogues.aoi_finalday(), state.flags)


## この周回が「葵ルート」か＝現時点の状態で選ばれる結末が葵の三分岐のいずれかか。
static func _is_aoi_route(state) -> bool:
	var end_id := Endings.pick(state.affinity, state.flags, state.stance, state.visits, state.counters, state.aoi_lean)
	return String(end_id).begins_with("aoi_")


# --- 約束の誘い（第9弾 §6・§7）--------------------------------------
## 節目の無い日、その相手が約束を差し出す。球磨=短射程・高頻度／由布=先の日・低頻度。
## §7 連鎖：果たした数（counters[route+"_chain"]）を段階として、次の“種”の誘いへ進める。
## 対象日が埋まっていれば Dialogues 側の if_day_free で「先約セリフ」に分岐する。
## 葵は誘わない（§5：予定表に載らない）。
static func _invite_nodes(route_id: String, state) -> Array:
	var stage := int(state.counters.get(route_id + "_chain", 0))
	match route_id:
		Routes.KUMA:
			return Dialogues.route_invite(Routes.KUMA, stage)  # 毎回（勢い・直近マス）
		Routes.YUFU:
			# 由布は控えめ（先の枠を独占しすぎない）。3日に一度だけ差し出す。
			if int(state.day_index) % 3 == 0:
				return Dialogues.route_invite(Routes.YUFU, stage)
	return []


# --- フラグ条件つきノードの展開 --------------------------------------
## 台本の中の条件ノードを、いまのフラグで確定させてフラット配列にする。
##   { "if_flag": "world_kuma_drifting", "then": [...], "else": [...] }
##   { "if_not_flag": "...", "then": [...], "else": [...] }
##   { "if_day_free": N, "then":[空きの誘い], "else":[先約セリフ] }（第9弾。state 必須）
##     → N 日後(day_index+N)の予定表が空いていれば then、埋まっていれば else。
## → §2「背景フラグを参照して描写を出し分ける」を、Dialogue 側を汚さずデータで実現。
static func flatten(nodes: Array, flags: Dictionary, state = null) -> Array:
	var out: Array = []
	for n in nodes:
		if typeof(n) == TYPE_DICTIONARY and n.has("if_flag"):
			var take: bool = flags.get(String(n["if_flag"]), false)
			out.append_array(flatten(_branch(n, take), flags, state))
		elif typeof(n) == TYPE_DICTIONARY and n.has("if_not_flag"):
			var take2: bool = not flags.get(String(n["if_not_flag"]), false)
			out.append_array(flatten(_branch(n, take2), flags, state))
		elif typeof(n) == TYPE_DICTIONARY and n.has("if_day_free"):
			# 対象日が空いているか（予定表・先埋め優先）。state が無ければ空扱い。
			var free := true if state == null else bool(state.day_free(int(state.day_index) + int(n["if_day_free"])))
			out.append_array(flatten(_branch(n, free), flags, state))
		else:
			out.append(n)
	return out


static func _branch(node: Dictionary, take: bool) -> Array:
	if take:
		return node.get("then", [])
	return node.get("else", [])


# --- 動作確認用（デバッグ）------------------------------------------
## いまの到達状況を1行ずつのテキストにして返す（HUD のオーバーレイが表示する）。
## 各ルートの「到達済み節目」「次の節目と解放条件」「関係値」「立場」が一目で分かる。
static func debug_lines(state) -> PackedStringArray:
	var out := PackedStringArray()
	var d: int = state.day_index
	var drift := "on" if state.flags.get(Timeline.F_KUMA_DRIFTING, false) else "off"
	out.append("=== DEBUG (F3で消す) ===")
	out.append("%d日目 %s / phase=%s  背景:球磨離脱=%s" % [
		d + 1, GameState.date_text(d), _phase_name(state.phase), drift,
	])
	out.append("葵の今日の居場所: %s" % Locations.name_of(Timeline.aoi_spot(d)))
	out.append("")
	for r in Routes.all():
		var rid := String(r["id"])
		var reached: Array = []
		var next_key := ""
		var next_cond := ""
		for m in r["milestones"]:
			var mk := String(m["key"])
			if state.flags.get(Routes.flag_of(rid, mk), false):
				reached.append(mk)
			elif next_key == "":
				next_key = mk
				next_cond = "d%d-%d,aff≥%d" % [int(m["since"]), int(m["until"]), int(m["aff_min"])]
		var total: int = (r["milestones"] as Array).size()
		var stance_txt := _stance_name(int(state.stance.get(rid, GameState.Stance.NONE)))
		out.append("[%s] aff=%d stance=%s  %d/%d" % [
			rid, int(state.affinity.get(rid, 0)), stance_txt, reached.size(), total,
		])
		out.append("   済: %s" % (" > ".join(reached) if not reached.is_empty() else "(なし)"))
		if next_key != "":
			out.append("   次: %s (%s)" % [next_key, next_cond])
		else:
			out.append("   次: (全節目 到達)")
	# 特別な夜の状況（今日は特別な夜か／これまでに立った夜フラグ）。
	out.append("")
	out.append("今日の特別な夜: %s" % (Nights.name_of(d) if Nights.is_special(d) else "-"))
	var night_flags: Array = []
	for k in state.flags:
		var ks := String(k)
		if not state.flags[k]:
			continue
		if ks == Nights.F_EARLY_FIREWORKS or ks.ends_with(Nights.SUF_FESTIVAL) or ks.ends_with(Nights.SUF_LAST_FIREWORKS):
			night_flags.append(ks)
	out.append("夜フラグ: %s" % (", ".join(night_flags) if not night_flags.is_empty() else "(なし)"))
	# 記録者エンドの分岐（どのルートも深く完結していない場合の行き先）。
	var score := Endings.engagement_score(state.affinity, state.flags, state.visits, state.counters)
	var solo_visits := 0
	for loc in Locations.ALL:
		if String(loc["character"]) == "" and state.visits.has(loc["id"]):
			solo_visits += int(state.visits.get(loc["id"], 0))
	out.append("")
	out.append("関わりの総量: %d / %d（閾値以上=見届けた／未満=ひとり）" % [score, Endings.WITNESS_MIN])
	out.append("葵の遍在遭遇: %d回  一人で過ごした回数: %d回" % [int(state.counters.get("aoi_ambient", 0)), solo_visits])
	# 葵ルートの三分岐（8/31）＝量ではなく方向で決まる。今の傾きと、現時点での着地先。
	var lean: Dictionary = state.aoi_lean
	out.append("")
	out.append("葵の傾き: 明%d 翳%d 近%d → 着地 %s" % [
		int(lean.get(Endings.LEAN_WARMTH, 0)),
		int(lean.get(Endings.LEAN_SHADOW, 0)),
		int(lean.get(Endings.LEAN_CLOSENESS, 0)),
		Endings.title_of(Endings._aoi_ending(lean)),
	])
	# 天気（第9弾）：今日の実際／明日の実際／明日の予報（外れうる）。山場は必ず当たる。
	var w_today := Weather.of(d)
	var w_tomo := Weather.of(d + 1)
	var w_fc := Weather.forecast(d + 1, int(state.weather_seed))
	out.append("")
	out.append("天気: 今日=%s / 明日=%s（予報=%s%s）" % [
		Weather.name_of(w_today), Weather.name_of(w_tomo), Weather.name_of(w_fc),
		"" if Weather.is_key_day(d + 1) else "・揺らぎ有",
	])
	# 天気限定風景（見逃したら再発生しない）＝この周回で見た数。
	out.append("天気限定風景: %d / %d 見た" % [WeatherScenes.seen_count(state.flags), WeatherScenes.total()])
	return out


static func _phase_name(phase: int) -> String:
	match phase:
		GameState.Phase.MORNING: return "午前"
		GameState.Phase.AFTERNOON: return "午後"
		GameState.Phase.NIGHT: return "夜"
	return "?"


static func _stance_name(st: int) -> String:
	match st:
		GameState.Stance.A: return "A"
		GameState.Stance.B: return "B"
		GameState.Stance.C: return "C"
	return "-"


# --- 日常会話のレベル分け（関係値でセリフを段階変化させる下地）--------
static func _affinity_level(aff: int) -> int:
	if aff >= 5:
		return 2
	if aff >= 2:
		return 1
	return 0
