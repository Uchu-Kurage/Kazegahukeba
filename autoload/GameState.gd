extends Node
## ゲーム全体の状態を持つシングルトン（Autoload）。
##
## シーンを切り替えても生き続ける「モデル」。日付・時間帯・好感度・フラグを
## ここで一元管理する。UI 側はここが出すシグナルを受け取って表示を更新するだけ。
## ＝「状態」と「表示」を分けておくと、後で物語やエンディングを足すのが楽になる。

## 一日の時間帯。午前・午後が「行動枠」、夜は基本は振り返り。
enum Phase { MORNING, AFTERNOON, NIGHT }

## --- カレンダー設定 ---
const START_MONTH := 8
const START_DAY := 1
## 8/1 を 1 日目として全 40 日。世界の終わりまでの日数（＋αは作りながら調整）。
const TOTAL_DAYS := 40

## --- シグナル（状態が変わったら UI へ知らせる）---
signal day_changed(day_index: int)   ## 新しい日になった
signal phase_changed(phase: Phase)   ## 時間帯が変わった
signal game_ended()                  ## 最終日を越えた（＝世界の終わり）

## --- 実行時の状態 ---
var day_index := 0                   ## 0 = 8/1、1 = 8/2 ...
var phase: Phase = Phase.MORNING

## その日どこへ行ったかの記録。 day_index -> { Phase(int): location_id(String) }
var schedule := {}

## キャラごとの関係値。 character_id(String) -> int
var affinity := {}

## 選択で立つフラグ。 flag_name(String) -> bool
var flags := {}


func _ready() -> void:
	start_new_run()


## 周回の最初に呼ぶ。状態をリセットして 1 日目の朝から始める。
func start_new_run() -> void:
	day_index = 0
	phase = Phase.MORNING
	schedule.clear()
	affinity.clear()
	flags.clear()
	day_changed.emit(day_index)
	phase_changed.emit(phase)


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
		var who := Locations.character_of(location_id)
		if who != "":
			affinity[who] = int(affinity.get(who, 0)) + 1


## 時間帯を一つ進める。夜の次は翌日の朝。
func _advance_phase() -> void:
	match phase:
		Phase.MORNING:
			phase = Phase.AFTERNOON
			phase_changed.emit(phase)
		Phase.AFTERNOON:
			phase = Phase.NIGHT
			phase_changed.emit(phase)
		Phase.NIGHT:
			_advance_day()


func _advance_day() -> void:
	day_index += 1
	if day_index >= TOTAL_DAYS:
		game_ended.emit()
		return
	phase = Phase.MORNING
	day_changed.emit(day_index)
	phase_changed.emit(phase)


# --- 表示用ヘルパー -------------------------------------------------

## day_index から実際の月日を求める（8/1 起点で素直に加算していく）。
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
