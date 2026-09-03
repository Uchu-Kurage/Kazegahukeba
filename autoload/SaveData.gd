extends Node
## 周回をまたいで残るセーブ記録（Autoload）。
##
## 到達したエンディングの一覧と周回数を user:// に保存する。
## これが「全エンド到達で裏エンドが開く」の土台。ゲーム内の一時状態(GameState)とは別に、
## ここだけはディスクに残り、周回リセットでも消えない。

const PATH := "user://save.cfg"

var seen_endings := {}  ## ending_id -> true
var runs := 0           ## クリア（8/31到達）した回数


func _ready() -> void:
	_load()


## エンディングを「見た」として記録する。
func mark_ending(id: String) -> void:
	seen_endings[id] = true
	_save()


func has_seen(id: String) -> bool:
	return seen_endings.get(id, false)


## 渡した全 id を見ていれば true（裏エンド解放の判定に使う）。
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
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return  # まだセーブが無い（初回）
	runs = int(cfg.get_value("progress", "runs", 0))
	for id in cfg.get_value("progress", "seen", []):
		seen_endings[id] = true


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "runs", runs)
	cfg.set_value("progress", "seen", seen_endings.keys())
	cfg.save(PATH)
