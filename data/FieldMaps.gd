class_name FieldMaps
extends RefCounted
## 散策画面（FieldScene）の定義とマップ接続表（実装指示 第6弾 §3 / マップ接続設計）。
##
## 『ぼくのなつやすみ』方式：1場所＝1画面。道（歩ける帯）の上だけ歩き、画面端の出口で
## 隣の画面へ遷移する。移動では枠を消費しない（GameState の日付/フェーズを進めない）。
##
## 接続は画面ごとにハードコードせず、ここにデータとして持つ（§7：接続はデータ駆動）。
## 接続は双方向（A の出口に B があれば、B からも A へ戻れる）。マップ接続設計の表を、
## 辺（エッジ）の集合として実装：
##   home↔shops / shops↔school / shops↔fields / shops↔riverbank /
##   fields↔shrine / fields↔sunflower / shrine↔hill / riverbank↔estuary / riverbank↔fields
##
## 各画面：id / name / bg（背景PNGパス。無ければプレースホルダ描画）/ roads（歩ける帯 Rect2）/
##         start（新規入場時の位置）/ exits（出口：id / label / pos / to（接続先画面ID））。
## 遷移先での出現位置は「to が“来た画面”に一致する出口」に立たせる（entry_position）。双方向なので必ず対応が在る。

const VIEW_W := 1152
const VIEW_H := 648

# --- 歩ける帯（道）の共通形（画面共通で使い回す。PNG差し替え時も道の位置を合わせる）---
const ROAD_H := Rect2(120, 300, 912, 130)   # 横帯（左↔右）
const ROAD_V := Rect2(500, 130, 152, 460)   # 縦帯（奥↔手前）
const CENTER := Vector2(576, 365)

# --- 画面端の出口位置（辺ごと）---
const POS_LEFT := Vector2(160, 365)
const POS_RIGHT := Vector2(992, 365)
const POS_UP := Vector2(576, 168)
const POS_DOWN := Vector2(576, 558)

# --- 奥行きスケール（§2-2。手前ほど大きく、奥ほど小さく）。全散策画面で共通。---
const DEPTH_Y_NEAR := 600.0   # この Y 以下（手前）で最大
const DEPTH_Y_FAR := 150.0    # この Y 以上（奥）で最小
const DEPTH_SCALE_NEAR := 1.15
const DEPTH_SCALE_FAR := 0.72

## 9場所の接続（辺の向こう＝出口。side は画面のどの辺に置くか）。
## side: "left"/"right"/"up"/"down"。双方向なので相手側にも対応する出口がある。
static func _screens_def() -> Array:
	return [
		{ "id": "home",      "name": "家",           "exits": [["shops", "right"]] },
		{ "id": "shops",     "name": "商店街",       "exits": [["home", "down"], ["school", "up"], ["fields", "left"], ["riverbank", "right"]] },
		{ "id": "school",    "name": "学校",         "exits": [["shops", "down"]] },
		{ "id": "fields",    "name": "田んぼと畦道", "exits": [["shops", "right"], ["shrine", "up"], ["sunflower", "left"], ["riverbank", "down"]] },
		{ "id": "sunflower", "name": "ひまわり畑",   "exits": [["fields", "right"]] },
		{ "id": "shrine",    "name": "神社",         "exits": [["fields", "down"], ["hill", "up"]] },
		{ "id": "hill",      "name": "丘",           "exits": [["shrine", "down"]] },
		{ "id": "riverbank", "name": "河原と土手",   "exits": [["shops", "left"], ["estuary", "right"], ["fields", "up"]] },
		{ "id": "estuary",   "name": "河口",         "exits": [["riverbank", "left"]] },
	]


static func all() -> Array:
	var out: Array = []
	for s in _screens_def():
		out.append(_build(s))
	return out


## 定義（id/name/exits[to,side]）から、道・出口位置・背景パスを埋めた画面データを組む。
static func _build(s: Dictionary) -> Dictionary:
	var uses_h := false
	var uses_v := false
	var exits: Array = []
	for e in s["exits"]:
		var to := String(e[0])
		var side := String(e[1])
		if side == "left" or side == "right":
			uses_h = true
		else:
			uses_v = true
		exits.append({
			"id": "to_%s" % to, "label": "%s %s" % [_arrow(side), _name_of_id(to)],
			"pos": _pos_of(side), "to": to,
		})
	var roads: Array = []
	if uses_h:
		roads.append(ROAD_H)
	if uses_v:
		roads.append(ROAD_V)
	return { "id": s["id"], "name": s["name"], "bg": "res://assets/field/%s.png" % s["id"],
		"roads": roads, "start": CENTER, "exits": exits }


static func _arrow(side: String) -> String:
	match side:
		"left": return "←"
		"right": return "→"
		"up": return "↑"
		"down": return "↓"
	return "・"


static func _pos_of(side: String) -> Vector2:
	match side:
		"left": return POS_LEFT
		"right": return POS_RIGHT
		"up": return POS_UP
		"down": return POS_DOWN
	return CENTER


static func _name_of_id(field_id: String) -> String:
	for s in _screens_def():
		if s["id"] == field_id:
			return String(s["name"])
	return field_id


static func by_id(field_id: String) -> Dictionary:
	for f in all():
		if f["id"] == field_id:
			return f
	return {}


## 遷移先の画面で、来た画面(from_id)へ戻る出口の位置にプレイヤーを立たせる。
## 双方向接続なので必ず対応する出口が在る。無ければ（新規入場・from空）start へ。
static func entry_position(field: Dictionary, from_id: String) -> Vector2:
	if from_id != "":
		for ex in field.get("exits", []):
			if String(ex["to"]) == from_id:
				return ex["pos"]
	return field.get("start", CENTER)
