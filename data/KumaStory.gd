class_name KumaStory
extends RefCounted
## 球磨ルートのイベント表と解決器（指示書§3）。
##
## 40日タイムライン上に節目イベントを並べ、「球磨の枠を選んだとき」に、
## 日付(min_day)と前提フラグ(requires)を満たした“次の1件”だけを進める。
## ＝球磨に時間を注がないと物語が止まる（他キャラと時間を奪い合う）設計。
##
## ・順序は requires（マイルストーンの連鎖）で強制。min_day は「この日以降に出現」。
##   いまは min_day を小さめの定数にしてあり、後から自由に動かせる（ハードコードしない）。
## ・テキストはプロット草稿の仮置き（本文は別途詰める前提）。

const PLAYER := "ぼく"

# --- マイルストーン・フラグ名（GameState.flags のキー。指示書§1-3）---
const F_INTRO := "kuma_intro_seen"
const F_DREAM := "kuma_dream_told"
const F_PROMISE := "kuma_promise_shown"
const F_STRUGGLE := "kuma_struggle_started"
const F_ATTITUDE := "kuma_attitude_chosen"

# --- イベントの出現時期（day_index。後で調整するための定数。今は連鎖駆動で 0 起点）---
const DAY_INTRO := 0
const DAY_DREAM := 0
const DAY_PROMISE := 0
const DAY_STRUGGLE := 0
const DAY_ATTITUDE := 0  # 中盤の選択。narratively は中盤だが、当面は連鎖到達で出す


## イベント表（上から順に判定）。
static func _events() -> Array:
	return [
		{
			"id": "kuma_intro", "min_day": DAY_INTRO, "requires": [], "sets": F_INTRO,
			"script": [
				{ "speaker": "", "text": "いつもの川原。球磨が石に腰かけて、川下のほうを見ている。" },
				{ "speaker": "球磨", "text": "よう。今年もこの夏が来たな。" },
				{ "speaker": PLAYER, "text": "……ああ。" },
				{ "speaker": "球磨", "text": "なんか、いい夏になりそうな気がするんだ。根拠はねぇけどな。" },
			],
		},
		{
			"id": "kuma_dream", "min_day": DAY_DREAM, "requires": [F_INTRO], "sets": F_DREAM,
			"script": [
				{ "speaker": "球磨", "text": "俺さ、いつか外で、でっかいことをやるんだ。" },
				{ "speaker": "球磨", "text": "何をとは、まだ決めてねぇけど……未来なんて、まだいくらでもあるだろ。" },
				{ "speaker": "", "text": "その未来が来ないことを、ぼくだけが知っている。" },
			],
		},
		{
			"id": "kuma_promise", "min_day": DAY_PROMISE, "requires": [F_DREAM], "sets": F_PROMISE,
			"script": [
				{ "speaker": "球磨", "text": "覚えてるか？　ガキの頃、この川の先の海まで行こうって約束したよな。" },
				{ "speaker": "球磨", "text": "あんときは途中で引き返した。……大人になったら、あの先まで行こうな。" },
				{ "speaker": "", "text": "川は、河口で海へ出る。球磨の名前と、同じように。" },
			],
		},
		{
			"id": "kuma_struggle", "min_day": DAY_STRUGGLE, "requires": [F_PROMISE], "sets": F_STRUGGLE,
			"script": [
				{ "speaker": "球磨", "text": "なあ。未来が来ないなら……今のうちに、未来を掴んじまえばいいんじゃねぇか？" },
				{ "speaker": "球磨", "text": "やりたかったこと、全部、今やる。付き合えよ。" },
				{ "speaker": "", "text": "急流みたいに、球磨は動き出した。止まると、終わりと向き合ってしまうから。" },
			],
		},
		{
			# 中盤の選択ポイント（A/B/C）。マイルストーンは選択肢側の "set" で立てる。
			"id": "kuma_attitude", "min_day": DAY_ATTITUDE, "requires": [F_STRUGGLE], "sets": F_ATTITUDE,
			"script": [
				{ "speaker": "", "text": "下流を目指すほど、世界は褪せていく。球磨のあがきは、報われないと見えてきた。" },
				{ "speaker": "球磨", "text": "まだだ。まだ、間に合うはずなんだ――" },
				{
					"text": "球磨に、どう向き合う？",
					"choices": [
						{
							"text": "一緒にあがく", "stance": "a", "affinity": { "kuma": 2 },
							"set": { "struggle_together": true, "kuma_attitude_chosen": true },
							"then": [ { "speaker": "球磨", "text": "……ああ。お前がいるなら、まだやれる。" } ],
						},
						{
							"text": "そばで寄り添う", "stance": "b", "affinity": { "kuma": 1 },
							"set": { "kuma_attitude_chosen": true },
							"then": [ { "speaker": "球磨", "text": "……そっか。無理にとは、言わないよ。" } ],
						},
						{
							"text": "もう受け入れよう、と諫める", "stance": "c", "affinity": { "kuma": -1 },
							"set": { "dissuaded_kuma": true, "kuma_attitude_chosen": true },
							"then": [ { "speaker": "球磨", "text": "……お前まで、そんなこと言うのかよ。" } ],
						},
					],
				},
			],
		},
	]


## いま解放されている“次の1件”を返す（無ければ空 {}）。
static func current_event(day: int, flags: Dictionary) -> Dictionary:
	for ev in _events():
		if flags.get(ev["sets"], false):
			continue  # 既に見た
		if day < int(ev["min_day"]):
			continue  # まだ時期じゃない
		var ok := true
		for req in ev["requires"]:
			if not flags.get(req, false):
				ok = false
				break
		if ok:
			return ev
	return {}


## 球磨と過ごすときに流す会話を返す。イベントがあればその台本＋末尾に
## マイルストーンを立てる効果ノード。無ければ日常の一言（filler）。
static func script_for(state) -> Array:
	var ev := current_event(state.day_index, state.flags)
	if ev.is_empty():
		return _filler()
	var script: Array = (ev["script"] as Array).duplicate(true)
	# 選択イベント以外は、末尾でマイルストーンを立てる（選択イベントは選択肢側で立てる）。
	if ev["id"] != "kuma_attitude":
		var eff := {}
		eff[ev["sets"]] = true
		script.append({ "effect": { "set": eff } })
	return script


static func _filler() -> Array:
	return [
		{ "speaker": "球磨", "text": "……今日は、ただ川を見てるだけでいいや。" },
		{ "speaker": "", "text": "となりで、同じ流れをぼんやり見ていた。" },
	]
