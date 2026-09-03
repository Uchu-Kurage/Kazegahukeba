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
##   pos       … 町マップ上の座標（当面はここに直書き。後でマップ上に配置し直せる）
const ALL := [
	{ "id": "riverside", "name": "川原",       "character": "kuma",  "pos": Vector2(240, 200) },
	{ "id": "shrine",    "name": "神社",       "character": "yuu",   "pos": Vector2(912, 200) },
	{ "id": "shop",      "name": "商店街",     "character": "natsu", "pos": Vector2(240, 470) },
	{ "id": "home",      "name": "家",         "character": "",      "pos": Vector2(912, 470) },
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
