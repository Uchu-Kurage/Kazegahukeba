class_name Fubutsushi
extends RefCounted
## 夏の風物詩コレクションのマスタ（第10弾）。res://data/fubutsushi.json を1回だけ読み込み、
## id -> エントリ辞書としてキャッシュする（新規の帳面は作らず、既存の絵日記帳へ統合する）。
##
## 1件のスキーマ（設計書準拠）：
##   id / name / genre(sound/sky/taste/play/creature/scene/special) / cycle(A=めぐる/B=今年かぎり/special)
##   places[] / time[] / weather[] / period / character / trigger(ambient/event) / record_text
## 空配列は any（＝条件を問わない）。判定は GameState 側（天気・時間帯・期間と突き合わせ）。

const PATH := "res://data/fubutsushi.json"
const GENRE_ORDER := ["sound", "sky", "taste", "play", "creature", "scene", "special"]
const GENRE_LABEL := {
	"sound": "音", "sky": "空と光", "taste": "味", "play": "遊びと行事",
	"creature": "生きもの", "scene": "情景", "special": "特別",
}

static var _cache := {}     # id(String) -> entry(Dictionary)
static var _order: Array = []  # ジャンル順に並べた id（絵日記帳の並び＝かすれ→くっきりの器）


static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	if not FileAccess.file_exists(PATH):
		push_warning("fubutsushi.json が見つかりません: %s" % PATH)
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("fubutsushi.json の形式が不正です")
		return
	var by_genre := {}
	for e in parsed:
		if typeof(e) != TYPE_DICTIONARY or not e.has("id"):
			continue
		var id := String(e["id"])
		_cache[id] = e
		var g := String(e.get("genre", ""))
		if not by_genre.has(g):
			by_genre[g] = []
		by_genre[g].append(id)
	# 並びはジャンル順（未知ジャンルは末尾）。同ジャンル内はファイル順。
	for g in GENRE_ORDER:
		if by_genre.has(g):
			_order.append_array(by_genre[g])
	for g in by_genre:
		if not (g in GENRE_ORDER):
			_order.append_array(by_genre[g])


static func db() -> Dictionary:
	_ensure_loaded()
	return _cache


static func ordered_ids() -> Array:
	_ensure_loaded()
	return _order


static func entry_of(id: String) -> Dictionary:
	_ensure_loaded()
	return _cache.get(id, {})


static func name_of(id: String) -> String:
	return String(entry_of(id).get("name", id))


static func record_text_of(id: String) -> String:
	return String(entry_of(id).get("record_text", ""))


static func total() -> int:
	_ensure_loaded()
	return _order.size()
