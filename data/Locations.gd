class_name Locations
extends RefCounted
## 町の「場所」の定義。当面はここに定数で持つ。
##
## class_name を付けているので、Autoload に登録しなくても
## どこからでも Locations.ALL / Locations.name_of(...) で参照できる。
## 物語を入れる段階で、場所ごとの登場キャラやイベントをここに足していく。
## （将来は .tres リソースや専用マップに外出しして、非プログラマでも編集できる形にするのも手）

## 各場所:
##   id        … 内部ID
##   name      … 表示名
##   character … そこで会えるキャラ(character_id、空文字なら誰もいない)
##   pos       … 街マップ上の座標（地図の見た目・カーソル移動に使う）
##   icon      … 地図アイコンの種類（house / torii / shop / river）
const ALL := [
	# character は route_id と一致させる（kuma / yufu / aoi）。関係値 affinity{} のキーも兼ねる。
	{ "id": "riverside", "name": "川原",   "character": "kuma", "pos": Vector2(170, 330), "icon": "river" },
	{ "id": "shop",      "name": "商店街", "character": "aoi",  "pos": Vector2(560, 190), "icon": "shop" },
	{ "id": "shrine",    "name": "神社",   "character": "yufu", "pos": Vector2(940, 200), "icon": "torii" },
	# character が空＝一人で過ごす場所（相手なし・関係値は上がらない・枠は消費する）。
	# 「一人で過ごす」ことも夏の正当な過ごし方（記録者エンドへ自然に向かう）。
	{ "id": "home",      "name": "家",     "character": "",     "pos": Vector2(940, 460), "icon": "house" },
	{ "id": "stroll",    "name": "町をぶらつく", "character": "", "pos": Vector2(430, 430), "icon": "path" },
	{ "id": "meadow",    "name": "畦道を歩く",   "character": "", "pos": Vector2(180, 540), "icon": "path" },
]


static func character_of(location_id: String) -> String:
	for loc in ALL:
		if loc["id"] == location_id:
			return loc["character"]
	return ""


static func name_of(location_id: String) -> String:
	for loc in ALL:
		if loc["id"] == location_id:
			return loc["name"]
	return ""


static func pos_of(location_id: String) -> Vector2:
	for loc in ALL:
		if loc["id"] == location_id:
			return loc["pos"]
	return Vector2.ZERO
