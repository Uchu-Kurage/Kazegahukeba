extends Node
## ゲーム全体の状態を持つシングルトン（Autoload）。
##
## シーンを切り替えても生き続ける「モデル」。日付・時間帯・好感度・フラグを
## ここで一元管理する。UI 側はここが出すシグナルを受け取って表示を更新するだけ。
## ＝「状態」と「表示」を分けておくと、後で物語やエンディングを足すのが楽になる。

## 一日の時間帯。午前・午後が「行動枠」、夜は基本は振り返り。
enum Phase { MORNING, AFTERNOON, NIGHT }

## 中盤の選択ポイント（各ルート共通の A/B/C）。意味はルートごとに異なる（Routes 参照）：
##   球磨 A=一緒にあがく / B=寄り添う / C=諫める
##   由布 A=一線を越える / B=幼なじみのまま守る / C=喪失に寄り添う
##   葵   A=一緒に今を生きる / B=未来を求める / C=知ろうとする
## 生文字列をやめ、この enum を正とする（route_id 別に stance{} へ持つ）。
enum Stance { NONE, A, B, C }

## --- カレンダー設定 ---
## 予定表＝8/31 を終点とする 40 日間。起点はその 40 日前＝7/23（世界の終わりに向かう夏）。
## day_index=39 が 8/31（＝最後に過ごす日／三分岐の着地）、その翌日 9/1 が裏エンド。
const START_MONTH := 7
const START_DAY := 23
## 7/23 を 1 日目として全 40 日（day39＝8/31 で終幕）。日数は TOTAL_DAYS で一括調整。
const TOTAL_DAYS := 40

## --- シグナル（状態が変わったら UI へ知らせる）---
signal day_changed(day_index: int)   ## 新しい日になった
signal phase_changed(phase: Phase)   ## 時間帯が変わった
signal game_ended()                  ## 最終日を越えた（＝世界の終わり）
signal schedule_changed()            ## 予定表（約束・日記）が変わった（予定表UIが購読して再描画）

## --- 実行時の状態 ---
var day_index := 0                   ## 0 = 7/23、1 = 7/24 ...、39 = 8/31
var phase: Phase = Phase.MORNING

## その日どこへ行ったかの記録。 day_index -> { Phase(int): location_id(String) }
var schedule := {}

## キャラごとの関係値。 character_id(String) -> int
var affinity := {}

## 選択で立つフラグ。 flag_name(String) -> bool
var flags := {}

## 場所ごとの訪問回数。 location_id -> int（中盤イベントの出しどころ判定などに使う）
var visits := {}

## 各ルートの中盤の立場（A/B/C）。 route_id(String) -> Stance(int)。エンディング判定の主軸。
## ルートごとに個別の器を持つので、掛け持ちしても立場が混ざらない。
var stance := {}

## 汎用カウンタ。 name(String) -> int（例："aoi_ambient"＝葵の遍在遭遇の回数）。
## 記録者エンドの「関わりの総量」判定などに使う。会話の効果ノード count:{} から増える。
var counters := {}

## 葵ルートの「傾き」カウンタ。 direction(String) -> int（Endings.LEAN_* の三方向）。
## 8/31 の三分岐は、量（スコア高低）ではなく、最も高い“方向”で決める（実装指示 第8弾 §2-2）。
## 選択肢の lean タグごとに +1。方向の対応・優先順位・着地の割り当ては Endings に定数化。
var aoi_lean := {}

## 天気（第9弾）。実際の天気は手組みスケジュール（Weather.SCHEDULE）を day_index で引く。
## 予報の「当たり外れ」の揺らぎだけ、この周回固定のシード weather_seed で決める（山場は必ず当てる）。
var weather_seed := 0
## 朝の予報（世界に溶けた開示）を、その日にもう出したか（一日一回。-1=まだ）。
var last_forecast_day := -1

## 予定表＝約束帳（第9弾）。 day_index(int) -> Promise 辞書。一日一予定・先埋め優先（§3）。
##   Promise = { character, place, time_of_day, status("planned"/"fulfilled"/"missed"), flavor_text }
##   葵は載らない（§5。8/31 の一度だけ例外）。
var promises := {}
## 過去マス用の絵日記。 day_index(int) -> { weather, note }。日送り時に確定する（§4）。
var diary := {}


func _ready() -> void:
	start_new_run()


## 周回の最初に呼ぶ。状態をリセットして 1 日目の朝から始める。
## （ディスクの進行データ [run] はここでは触らない。新規開始の上書きは Title 側で行う）
func start_new_run() -> void:
	day_index = 0
	phase = Phase.MORNING
	schedule.clear()
	affinity.clear()
	flags.clear()
	visits.clear()
	stance.clear()
	counters.clear()
	aoi_lean.clear()
	weather_seed = randi()  # 予報の揺らぎ用（周回ごとに変わる）
	last_forecast_day = -1
	promises.clear()
	diary.clear()
	Timeline.apply_background(self)  # 1日目の背景状態を反映（この時点では何も立たない）
	day_changed.emit(day_index)
	phase_changed.emit(phase)


## 現在の進行状況をまとめて返す（セーブ用）。
func snapshot() -> Dictionary:
	return {
		"day": day_index,
		"phase": int(phase),
		"schedule": schedule.duplicate(true),
		"affinity": affinity.duplicate(),
		"flags": flags.duplicate(),
		"visits": visits.duplicate(),
		"stance": stance.duplicate(),
		"counters": counters.duplicate(),
		"aoi_lean": aoi_lean.duplicate(),
		"weather_seed": weather_seed,
		"last_forecast_day": last_forecast_day,
		"promises": promises.duplicate(true),
		"diary": diary.duplicate(true),
	}


## セーブした進行状況を復元する（つづきから）。
## 旧フォーマットや壊れたセーブでも落ちないよう、各フィールドは型を確かめてから取り込む
## （型が違えば空で始める）。セーブ互換は保証しない方針だが、クラッシュはさせない。
func restore(data: Dictionary) -> void:
	day_index = int(data.get("day", 0)) if _is_num(data.get("day")) else 0
	phase = int(data.get("phase", Phase.MORNING)) if _is_num(data.get("phase")) else Phase.MORNING
	schedule = _dict_field(data, "schedule", true)
	affinity = _dict_field(data, "affinity")
	flags = _dict_field(data, "flags")
	visits = _dict_field(data, "visits")
	stance = _dict_field(data, "stance")
	counters = _dict_field(data, "counters")
	aoi_lean = _dict_field(data, "aoi_lean")
	weather_seed = int(data.get("weather_seed", 0)) if _is_num(data.get("weather_seed")) else randi()
	last_forecast_day = int(data.get("last_forecast_day", -1)) if _is_num(data.get("last_forecast_day")) else -1
	promises = _dict_field(data, "promises", true)
	diary = _dict_field(data, "diary", true)
	Timeline.apply_background(self)  # 再開時も現在日の背景状態に整える
	day_changed.emit(day_index)
	phase_changed.emit(phase)


## セーブ辞書から Dictionary フィールドを安全に取り出す（型が違えば空を返す）。
## ⚠️ `x as Dictionary` は非Dictionaryに対して null ではなく実行時エラーを投げるため、
##    必ず is で型を確認してからコピーする。
func _dict_field(data: Dictionary, key: String, deep: bool = false) -> Dictionary:
	var v = data.get(key, {})
	if v is Dictionary:
		return (v as Dictionary).duplicate(deep)
	return {}


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


func _autosave() -> void:
	SaveData.save_run(snapshot())


## 行動枠（午前・午後）で場所を選んだときに呼ぶ。枠を消費して次の時間帯へ。
func choose_location(location_id: String) -> void:
	_record_choice(location_id)
	_advance_phase()


## 予定なしでスキップ（枠は消費する）。
func skip_slot() -> void:
	_record_choice("")
	_advance_phase()


## 夜にカレンダーをめくる（翌日へ）。
func flip_calendar() -> void:
	_advance_phase()


## 今日のこの時間帯の選択を記録し、関係値も更新する。
func _record_choice(location_id: String) -> void:
	if not schedule.has(day_index):
		schedule[day_index] = {}
	schedule[day_index][phase] = location_id
	# 場所にキャラが紐づいていれば関係値を +1（当面の仮ロジック）。
	if location_id != "":
		visits[location_id] = int(visits.get(location_id, 0)) + 1
		var who := Locations.character_of(location_id)
		if who != "":
			affinity[who] = int(affinity.get(who, 0)) + 1
			# 今日その相手と過ごしたら、planned の約束を「果たした」にする（§4）。
			var p: Dictionary = promises.get(day_index, {})
			if not p.is_empty() and String(p.get("status", "")) == "planned" and String(p.get("character", "")) == who:
				p["status"] = "fulfilled"
				schedule_changed.emit()


## 関係値を増減する（会話の選択肢などから呼ぶ）。
func add_affinity(who: String, delta: int) -> void:
	if who == "":
		return
	affinity[who] = int(affinity.get(who, 0)) + delta
	print("[affinity] %s = %d" % [who, affinity[who]])  # 確認用（エンディング実装時に削除可）


## 汎用カウンタを増やす（会話の効果ノード count:{} などから呼ぶ）。
func bump(counter_name: String, delta: int) -> void:
	if counter_name == "":
		return
	counters[counter_name] = int(counters.get(counter_name, 0)) + delta


## 葵ルートの「傾き」を1つ足す（会話の選択肢の lean タグから呼ぶ）。方向のみを記録する。
func bump_lean(direction: String) -> void:
	if direction == "":
		return
	aoi_lean[direction] = int(aoi_lean.get(direction, 0)) + 1
	print("[lean] %s = %d" % [direction, aoi_lean[direction]])  # 確認用


## 今日の天気（実際）。手組みスケジュールを day_index で引く。
func weather_today() -> String:
	return Weather.of(day_index)


## 明日の実際の天気（翌朝そのまま出る天気）。演出・限定風景の判定に使う。
func weather_tomorrow() -> String:
	return Weather.of(day_index + 1)


## 明日の“予報”（外れうる）。前日夜/当日朝に見せるのはこちら。山場は必ず当たる。
func weather_forecast() -> String:
	return Weather.forecast(day_index + 1, weather_seed)


# --- 予定表＝約束帳（第9弾）--------------------------------------------

## その日が空いているか（一日一予定・先埋め優先）。
func day_free(day: int) -> bool:
	return not promises.has(day)


## 約束を記帳する（会話の「応じる」選択などから）。既に埋まっていれば成立しない（先約優先）。
## 葵は原則ここに載せない（§5。8/31 の会話約束のみ例外的に呼ぶ）。
func make_promise(day: int, character: String, place: String, time_of_day: String, flavor: String) -> bool:
	if day < 0 or day >= TOTAL_DAYS or promises.has(day):
		return false
	promises[day] = {
		"character": character, "place": place, "time_of_day": time_of_day,
		"status": "planned", "flavor_text": flavor,
	}
	print("[promise] d%d %s @ %s (%s)" % [day, character, place, time_of_day])
	schedule_changed.emit()
	_autosave()
	return true


func promise_of(day: int) -> Dictionary:
	return promises.get(day, {})


## 一日を締める：未達の planned は missed に、絵日記を確定する（責めない・静かに残す）。
func _close_day(day: int) -> void:
	var p: Dictionary = promises.get(day, {})
	if not p.is_empty() and String(p.get("status", "")) == "planned":
		p["status"] = "missed"
	_write_diary(day)
	schedule_changed.emit()


## その日の絵日記の一言を確定する（果たした約束の清書／未達／空白日の自動一言）。
func _write_diary(day: int) -> void:
	var entry := { "weather": Weather.of(day) }
	var p: Dictionary = promises.get(day, {})
	if not p.is_empty():
		match String(p.get("status", "")):
			"fulfilled":
				entry["note"] = "%sと%sで過ごした。" % [char_display(String(p["character"])), Locations.name_of(String(p["place"]))]
			"missed":
				entry["note"] = "%sとの約束は、果たせなかった。" % char_display(String(p["character"]))
			_:
				entry["note"] = _blank_note(day)
	else:
		entry["note"] = _blank_note(day)
	diary[day] = entry


## 約束のない日の自動一言（ぼくのなつやすみ的な豊かさ。何もしない夏も肯定する）。
const BLANK_NOTES := [
	"セミの声を、ずっと聞いていた。", "大きな入道雲を、ただ見上げていた。",
	"知らない路地で、近道を見つけた。", "何もしない一日。それも悪くなかった。",
	"風が、少しだけ涼しかった。", "水たまりに、空が映っていた。",
	"どこかで、風鈴が鳴っていた。",
]
func _blank_note(day: int) -> String:
	return BLANK_NOTES[day % BLANK_NOTES.size()]


## キャラID→表示名（予定表・絵日記用）。
func char_display(id: String) -> String:
	match id:
		"kuma": return "球磨"
		"yufu": return "由布"
		"aoi": return "葵"
	return id


## フラグを立てる／下ろす（会話の選択肢などから呼ぶ）。
func set_flag(flag_name: String, value: bool) -> void:
	flags[flag_name] = value
	print("[flag] %s = %s" % [flag_name, str(value)])  # 確認用（エンディング実装時に削除可）
	# 天気限定風景を見たら、周回をまたぐ図鑑（風物詩）にも記録する。
	if value:
		var scene_id := WeatherScenes.id_from_flag(flag_name)
		if scene_id != "":
			SaveData.mark_scene(scene_id)


## あるルートの立場を決める（中盤の A/B/C 選択から呼ぶ）。値は Stance の enum。
func set_stance(route_id: String, value: Stance) -> void:
	if route_id == "":
		return
	stance[route_id] = value
	print("[stance] %s = %d" % [route_id, value])  # 確認用


## 時間帯を一つ進める。夜の次は翌日の朝。
func _advance_phase() -> void:
	match phase:
		Phase.MORNING:
			phase = Phase.AFTERNOON
			phase_changed.emit(phase)
			_autosave()
		Phase.AFTERNOON:
			phase = Phase.NIGHT
			phase_changed.emit(phase)
			_autosave()
		Phase.NIGHT:
			_advance_day()


func _advance_day() -> void:
	_close_day(day_index)  # 今日ぶんを確定（未達の約束→missed／絵日記を書く）
	day_index += 1
	if day_index >= TOTAL_DAYS:
		SaveData.clear_run()  # クリアしたので「つづきから」は消す
		game_ended.emit()
		return
	phase = Phase.MORNING
	Timeline.apply_background(self)  # 新しい日の共通背景を反映（中盤で球磨離脱フラグ等）
	day_changed.emit(day_index)
	phase_changed.emit(phase)
	_autosave()


# --- 表示用ヘルパー -------------------------------------------------

## day_index から実際の月日を求める（7/23 起点で素直に加算していく）。
func date_of(index: int) -> Dictionary:
	var days_in_month := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var month := START_MONTH
	var day := START_DAY + index
	while day > days_in_month[month - 1]:
		day -= days_in_month[month - 1]
		month += 1
	return { "month": month, "day": day }


func date_text(index: int) -> String:
	var d := date_of(index)
	return "%d月%d日" % [d["month"], d["day"]]


func phase_text(p: Phase) -> String:
	match p:
		Phase.MORNING:
			return "午前"
		Phase.AFTERNOON:
			return "午後"
		Phase.NIGHT:
			return "夜"
	return ""
