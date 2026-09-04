extends Node
## セーブ記録（Autoload）。user://save.cfg に2種類を保存する。
##   [progress] 周回をまたぐ記録：到達エンド一覧・周回数（図鑑・裏エンド解放用）
##   [run]      進行中の1周のスナップショット（中断／再開用）
##
## ゲーム内の一時状態(GameState)とは別に、ここだけがディスクに残る。

const PATH := "user://save.cfg"

var seen_endings := {}  ## ending_id -> true
var runs := 0           ## クリア（8/31到達）した回数


func _ready() -> void:
	var cfg := _open()
	runs = int(cfg.get_value("progress", "runs", 0))
	for id in cfg.get_value("progress", "seen", []):
		seen_endings[id] = true


# --- 周回記録（図鑑）------------------------------------------------

func mark_ending(id: String) -> void:
	seen_endings[id] = true
	_save_progress()


func has_seen(id: String) -> bool:
	return seen_endings.get(id, false)


func all_seen(ids: Array) -> bool:
	for id in ids:
		if not seen_endings.get(id, false):
			return false
	return true


func seen_count(ids: Array) -> int:
	var n := 0
	for id in ids:
		if seen_endings.get(id, false):
			n += 1
	return n


func record_run() -> void:
	runs += 1
	_save_progress()


## 周回記録だけを消す（進行データ [run] は触らない）。
func clear() -> void:
	seen_endings.clear()
	runs = 0
	_save_progress()


# --- 進行データ（中断／再開）----------------------------------------

func save_run(data: Dictionary) -> void:
	var cfg := _open()
	cfg.set_value("run", "has", true)
	cfg.set_value("run", "data", data)
	cfg.save(PATH)


func has_run() -> bool:
	return bool(_open().get_value("run", "has", false))


func load_run() -> Dictionary:
	return _open().get_value("run", "data", {})


func clear_run() -> void:
	var cfg := _open()
	cfg.set_value("run", "has", false)
	cfg.set_value("run", "data", {})
	cfg.save(PATH)


# --- 内部 ------------------------------------------------------------

## 既存ファイルを読み込んで返す（無ければ空）。両セクションを保つために毎回これを使う。
func _open() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # 失敗（初回）でも空の cfg を使う
	return cfg


func _save_progress() -> void:
	var cfg := _open()  # [run] を消さないよう、既存を読んでから上書き
	cfg.set_value("progress", "runs", runs)
	cfg.set_value("progress", "seen", seen_endings.keys())
	cfg.save(PATH)
