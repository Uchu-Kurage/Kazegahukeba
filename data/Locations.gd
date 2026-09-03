class_name Locations
extends RefCounted
## 町の「場所」の定義。当面はここに定数で持つ。
##
## class_name を付けているので、Autoload に登録しなくても
## どこからでも Locations.ALL / Locations.name_of(...) で参照できる。
## 物語を入れる段階で、場所ごとの登場キャラやイベントをここに足していく。
## （将来は .tres リソースや JSON に外出しして、非プログラマでも編集できる形にするのも手）

## 各場所: id / 表示名 / そこで会えるキャラ(character_id、空文字なら誰もいない)
const ALL := [
	{ "id": "riverside", "name": "川原",       "character": "kuma" },
	{ "id": "shrine",    "name": "神社",       "character": "yuu" },
	{ "id": "shop",      "name": "商店街",     "character": "natsu" },
	{ "id": "home",      "name": "家でのんびり", "character": "" },
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
