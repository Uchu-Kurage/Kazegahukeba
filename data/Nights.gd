class_name Nights
extends RefCounted
## 特別な夜イベント（実装指示 第3弾）。
##
## 通常の夜（NIGHT）は「その日の振り返り」で行動しない。特定日付の夜だけ、ここに定義した
## 「特別な夜」で行動できる＝昼の積み重ねの上に乗る、関係が一歩進む決定的なハイライト。
## Routes/Timeline と同じデータ駆動の思想：日付でイベントを引き、本文は台本キーで参照。
##
## 各イベントのデータ：
##   id / day（day_index）/ name（表示名）
##   type … "fixed"（内容固定・三人で／進行中ルートで漏れる台詞を出し分け）
##          "shared"（誰と過ごすかを選ぶ＝その周の関係を象徴する選択）
##   fixed のとき : script（Dialogues.night_script のキー）, sets（通過フラグ）
##   shared のとき: suffix（夜フラグの後半。{route_id}_{suffix} を立てる）
##
## テキストは仮置き。葵が絡む夜も正体を匂わせない（二層構造厳守）。

# --- 配置する日付（day_index。0=7/23。すべて定数＝あとで調整可能）---
const EARLY_FIREWORKS_DAY := 15   # 16日目＝8/7 の夜：序盤の花火（三人で・差分出し分け）
const FESTIVAL_DAY := 28          # 29日目＝8/20 の夜：夏祭り（誰と過ごすか選ぶ・後半の絶頂）
const LAST_FIREWORKS_DAY := 36    # 37日目＝8/28 の夜：最後の花火（誰と過ごすか選ぶ・惜別の快晴）

# --- 夜専用フラグ ---
## shared 系は {route_id}_{suffix}（例 kuma_festival_night）。エンディングテキストの分岐に使える。
const SUF_FESTIVAL := "festival_night"
const SUF_LAST_FIREWORKS := "last_fireworks"
## 序盤の花火（三人で・共通）を見た印。
const F_EARLY_FIREWORKS := "saw_early_fireworks"

# --- 相手を選んだときの関係値ボーナス（決定的な夜なので大きめ・定数）---
const NIGHT_AFFINITY_BONUS := 3


## 全定義（データ）。
static func all() -> Array:
	return [
		{ "id": "early_fireworks", "day": EARLY_FIREWORKS_DAY, "type": "fixed",
			"name": "夏のはじめの花火", "script": "early_fireworks", "sets": F_EARLY_FIREWORKS },
		{ "id": "festival", "day": FESTIVAL_DAY, "type": "shared",
			"name": "夏祭りの夜", "suffix": SUF_FESTIVAL },
		{ "id": "last_fireworks", "day": LAST_FIREWORKS_DAY, "type": "shared",
			"name": "最後の花火", "suffix": SUF_LAST_FIREWORKS },
	]


## その日の特別な夜を返す（無ければ {}）。前提条件があればここで判定（今は日付のみ）。
static func for_day(day: int) -> Dictionary:
	for n in all():
		if int(n["day"]) == day:
			return n
	return {}


static func is_special(day: int) -> bool:
	return not for_day(day).is_empty()


static func name_of(day: int) -> String:
	var n := for_day(day)
	return String(n["name"]) if not n.is_empty() else ""


## その特別な夜で流す会話（フラット化済み）を返す。Town から呼ぶ。
## 先頭に「夜の限定風景」（天気が合えば一度だけ＝天の川 等）を差し込む（第9弾）。
static func script_for(night: Dictionary, state) -> Array:
	var out: Array = _weather_night(night, state)
	if String(night["type"]) == "fixed":
		out.append_array(Story.flatten(Dialogues.night_script(String(night["script"])), state.flags))
		var eff := {}                       # 通過フラグ（三人で見た印）を最後に立てる
		eff[String(night["sets"])] = true
		out.append({ "effect": { "set": eff } })
		return out
	out.append_array(_shared_script(night, state))
	return out


## 夜の限定風景（特別な夜）：event=夜イベントID・今日の天気が合えば、頭に一度だけ差し込む。
static func _weather_night(night: Dictionary, state) -> Array:
	var d := int(state.day_index)
	var e := WeatherScenes.night_match(d, Weather.of(d), String(night["id"]), state.flags)
	if e.is_empty():
		return []
	var out := Story.flatten(e["script"], state.flags)
	out.append({ "effect": { "set": { WeatherScenes.flag_of(String(e["id"])): true } } })
	# 夜の限定風景に紐づく風物詩（例：天の川）があれば同時に収集（第10弾）。
	if e.has("discover"):
		out.append({ "effect": { "discover": e["discover"] } })
	return out


## 「誰と過ごすか」を選ぶ夜。昼の選択機構（Dialogue の選択肢）を流用。
## 選んだ相手：関係値ボーナス＋夜フラグ＋その相手の夜の台本。選ばなかった相手とは過ごせない
## （＝その特別な夜は二度と戻らない。時間制の徹底）。
static func _shared_script(night: Dictionary, state) -> Array:
	var suffix := String(night["suffix"])
	var id := String(night["id"])
	var choices: Array = []
	for rid in Routes.ids():
		if not _is_available(rid, state):
			continue
		var aff_d := {}
		aff_d[rid] = NIGHT_AFFINITY_BONUS
		var set_d := {}
		set_d["%s_%s" % [rid, suffix]] = true
		choices.append({
			"text": "%s と過ごす" % _display_name(rid),
			"affinity": aff_d, "set": set_d,
			"then": Dialogues.night_partner_script(id, rid),
		})
	# 「三人で」は常に選べる（誰か一人に決めない夜）。
	var trio_set := {}
	trio_set["trio_%s" % suffix] = true
	choices.append({
		"text": "三人で過ごす", "set": trio_set,
		"then": Dialogues.night_partner_script(id, "trio"),
	})
	var head := [
		{ "speaker": "", "text": "%s。浴衣、出店、遠くで鳴る太鼓。" % String(night["name"]) },
	]
	# 夏祭りの夜は、縁日の風物詩をまとめて収集（第10弾。誰と過ごすかに関わらず、その場の情景）。
	if id == "festival":
		head.append({ "effect": { "discover": [
			"natsumatsuri", "bonodori", "bonodori_taiko", "ramune", "mukaebi", "hanabi_taikai",
		] } })
	head.append({ "text": "この夜を、誰と過ごす？", "choices": choices })
	return Story.flatten(head, state.flags)


## その夜に参加できる相手か（＝出会っている／一定関係値）。
## 球磨・由布は幼なじみで最初からいる。葵は出会い（shop 訪問＝meet 済み）or 関係値ありのときだけ。
static func _is_available(rid: String, state) -> bool:
	if rid == Routes.KUMA or rid == Routes.YUFU:
		return true
	if rid == Routes.AOI:
		return state.flags.get(Routes.flag_of(Routes.AOI, "meet"), false) \
			or int(state.affinity.get(Routes.AOI, 0)) > 0
	return true


static func _display_name(rid: String) -> String:
	match rid:
		Routes.KUMA: return "球磨"
		Routes.YUFU: return "由布"
		Routes.AOI: return "葵"
	return rid
