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

	# 4. 葵の遍在遭遇（枠を消費しない）＝他の場所を選んでいても軽く差し込む。
	#    葵自身の場所（深く過ごす枠）では出さない（そこは 2. の節目に譲る）。
	out.append_array(_aoi_ambient(location_id, state))

	# その場所に紐づくルート（＝深く過ごせる相手）を引く。
	var route := Routes.by_location(location_id)
	if route.is_empty():
		# ルートの無い場所（家など）は従来どおりの固定台本。
		out.append_array(flatten(Dialogues.for_location(location_id), state.flags))
		return out

	# 2. 選択中ルートの節目イベント（次の1件）。
	var ev := next_milestone(route, state.day_index, state.flags, state.affinity)
	if ev.is_empty():
		# 3. 節目が無い日は、関係値に応じた日常会話。
		var level := _affinity_level(int(state.affinity.get(route["id"], 0)))
		out.append_array(flatten(Dialogues.route_filler(route["id"], level), state.flags))
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


# --- フラグ条件つきノードの展開 --------------------------------------
## 台本の中の条件ノードを、いまのフラグで確定させてフラット配列にする。
##   { "if_flag": "world_kuma_drifting", "then": [...], "else": [...] }
##   { "if_not_flag": "...", "then": [...], "else": [...] }
## → §2「背景フラグを参照して描写を出し分ける」を、Dialogue 側を汚さずデータで実現。
static func flatten(nodes: Array, flags: Dictionary) -> Array:
	var out: Array = []
	for n in nodes:
		if typeof(n) == TYPE_DICTIONARY and n.has("if_flag"):
			var take: bool = flags.get(String(n["if_flag"]), false)
			out.append_array(flatten(_branch(n, take), flags))
		elif typeof(n) == TYPE_DICTIONARY and n.has("if_not_flag"):
			var take2: bool = not flags.get(String(n["if_not_flag"]), false)
			out.append_array(flatten(_branch(n, take2), flags))
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
	var d := state.day_index
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
