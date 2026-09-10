class_name Areas
extends RefCounted
## 見下ろしマップの「エリア」定義（第10弾＝一日の流れの作り直し）。
##
## 移動を二層に分ける：エリア間＝見下ろしマップから選んで飛ぶ（省く）／エリア内＝歩く（濃く）。
## 枠は「そのエリアを午前／午後の行き先に選んだ」時点で半日ぶん確定する（エリア選択＝枠のトリガー）。
## エリア内の歩行・道マップ・風物詩・軽い遭遇は枠非消費。本イベント（人と過ごす）は半日1回だけ関係値。
##
## 家（home）はエリアではない＝起点／戻る先。見下ろしマップには載せない。
##
## 各エリア：id / name / entry（飛んだとき最初に入る画面）/ fields（エリア内の画面 id）/ enabled（選べるか）。
## enabled=false は「準備中」（今後の弾で開放）。段階導入のため、まずは川エリアだけ開く。

const HOME := "home"


static func all() -> Array:
	return [
		{ "id": "town", "name": "町", "entry": "shops",
			"fields": ["shops", "school"], "enabled": true,
			"hint": "商店街・学校" },
		# 田園：入口＝road_A（畦道の導入を歩いてから田んぼ画面へ。第9弾§3）。
		{ "id": "farm", "name": "田園", "entry": "road_a",
			"fields": ["road_a", "fields", "sunflower"], "enabled": true,
			"hint": "田んぼと畦道・ひまわり畑" },
		# 社：入口＝road_B（参道の導入を歩いてから神社へ）。エリア内に road_C（神社→丘）。
		{ "id": "shrine_area", "name": "社", "entry": "road_b",
			"fields": ["road_b", "shrine", "road_c", "hill"], "enabled": true,
			"hint": "神社・丘" },
		{ "id": "river", "name": "川", "entry": "riverbank",
			"fields": ["riverbank", "estuary", "road_d"], "enabled": true,
			"hint": "河原と土手・河口" },
	]


static func by_id(area_id: String) -> Dictionary:
	for a in all():
		if a["id"] == area_id:
			return a
	return {}


## その画面がどのエリアに属するか（entry も含む）。home は "home"、未所属は ""。
static func area_of(field_id: String) -> String:
	if field_id == HOME:
		return HOME
	for a in all():
		if field_id == a["entry"] or field_id in a["fields"]:
			return a["id"]
	return ""


## 同じエリア内の画面同士か（エリア内の歩行だけ許す＝エリア間は歩かせない）。
static func same_area(field_a: String, field_b: String) -> bool:
	var x := area_of(field_a)
	return x != "" and x == area_of(field_b)
