class_name KumaStory
extends RefCounted
## 球磨ルートのイベント解決層（指示書§3）。
##
## 「日付 × 前提フラグ × 球磨を選んだか」で、次に再生すべき節目イベントを決める。
## 各イベントはデータとして次を持つ：
##   requires : 必要な進行フラグ（連鎖で順序を強制）
##   since / until : 出現できる時期の範囲（day_index。後で動かせる定数）
##   sets     : 通過したら立てる進行フラグ
##   script   : 引く台本のキー（本文は Dialogues.gd に置く＝データとロジックの分離）
##
## 節目の追加は _events() にデータを1行足すだけ（台本は Dialogues.kuma_script に足す）。
## 「球磨の枠を選んだとき」だけ script_for() が呼ばれるので、球磨に時間を注がないと進まない。

# --- 球磨ルートの進行フラグ（正式名6つ。GameState.flags のキー）------
const F_DREAM := "kuma_dream_told"
const F_PROMISE := "kuma_promise_shown"
const F_STRUGGLE := "kuma_struggle_started"
const F_RIVER := "kuma_river_journey_started"
const F_BROKE := "kuma_broke"
const F_REALIZATION := "kuma_realization"

# --- 時期の範囲（day_index。後で調整するための定数）------------------
const DAY_EARLY_START := 0
const DAY_EARLY_END := 14   # 序盤（1〜15日ごろ）


## イベント表（上から順に判定）。ここは純粋なデータ（台本は持たずキーで参照）。
## いまは序盤の2節目だけ（出会い直し＋夢 → 河口の約束）。中盤以降は後で追加する。
static func _events() -> Array:
	return [
		{
			"id": "kuma_dream", "requires": [], "sets": F_DREAM, "script": "kuma_dream",
			"since": DAY_EARLY_START, "until": DAY_EARLY_END,
		},
		{
			"id": "kuma_promise", "requires": [F_DREAM], "sets": F_PROMISE, "script": "kuma_promise",
			"since": DAY_EARLY_START, "until": DAY_EARLY_END,
		},
	]


## いま解放されている“次の1件”を返す（無ければ空 {}）。
static func current_event(day: int, flags: Dictionary) -> Dictionary:
	for ev in _events():
		if flags.get(ev["sets"], false):
			continue  # 通過済み
		if day < int(ev["since"]):
			continue  # まだ早い
		var until := int(ev.get("until", -1))
		if until >= 0 and day > until:
			continue  # 時期を過ぎた
		var ok := true
		for req in ev["requires"]:
			if not flags.get(req, false):
				ok = false
				break
		if ok:
			return ev
	return {}


## 球磨と過ごすときに流す会話を返す。イベントがあれば、その台本（Dialogues から取得）＋
## 末尾に進行フラグを立てる効果ノード。無ければ何気ない一言（filler）。
static func script_for(state) -> Array:
	var ev := current_event(state.day_index, state.flags)
	if ev.is_empty():
		return Dialogues.kuma_script("kuma_filler")
	var script: Array = Dialogues.kuma_script(String(ev["script"])).duplicate(true)
	var eff := {}
	eff[String(ev["sets"])] = true
	script.append({ "effect": { "set": eff } })
	return script
