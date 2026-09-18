class_name Items
extends RefCounted
## 所持品（夏の道具）のマスタ定義（実装指示：所持品システム §1）。
##
## 風物詩（眺める・記憶する・使わない＝情緒の収集）とは役割が違う「使う道具」の箱。
## 手に入れて・持ち運んで・特定の場面で使うと体験が開く。持っていなければ起きない――
## ただしそれは失敗ではなく「別の夏があった」だけ（天気の一期一会と同じ。§0）。
##
## GameState.inventory は id -> 実体（このマスタのコピー＋count）を持つ。表示順はこのマスタ順。
## 各道具：
##   name  … 表示名
##   desc  … かばんに出す短い説明
##   origin… 由来テキスト（例「球磨にもらった」）。★葵絡みは空文字（§5。UIで強調しない）
##   consumable    … 使うと消費されるか（花火＝消費／網・帽子＝残る）
##   fubutsushi_id … 風物詩と重なるモチーフのとき、対応する風物詩 id（入手で灯す。§4）。無ければ ""
##
## ⚠️ 葵絡みアイテム（aoi_shell）の origin は空。喪失後も GameState.inventory から消さない
##    （start_new_run でのみリセット）。由来が空であることを UI で強調しない（§5-2）。

## 道具マスタ（表示順＝この並び順）。
static func all() -> Array:
	return [
		_item("mushi_ami", "虫取り網", "夏の夜、雑木林でカブトムシが採れそうだ。",
			"球磨にもらった", false, ""),
		_item("mugiwara", "麦わら帽子", "炎天下の遠出も、これがあれば少し楽になる。",
			"商店街で見つけた", false, "mugiwara"),  # 風物詩「麦わら帽子」と重なる＝入手で灯す（§4）
		_item("hanabi", "手持ち花火", "ひとたば。誰かと夜に。",
			"畦道の小屋で見つけた（去年の残り）", true, ""),
		# 葵絡み：手渡されない＝「いつのまにか手元にある」。由来は空（§5-1/§5-2）。
		_item("aoi_shell", "貝殻", "耳にあてると、遠い波の音がする気がする。",
			"", false, ""),
	]


static func _item(id: String, name: String, desc: String, origin: String,
		consumable: bool, fubutsushi_id: String) -> Dictionary:
	return {
		"id": id, "name": name, "desc": desc, "origin": origin,
		"consumable": consumable, "fubutsushi_id": fubutsushi_id,
	}


## マスタから1件引く（未知 id は空）。
static func by_id(id: String) -> Dictionary:
	for it in all():
		if it["id"] == id:
			return it
	return {}


# --- 探索入手（§2-B）＝フィールドを歩いて見つける道具の配置 -----------------
## 画面 id -> その画面に落ちている道具の配置（到達で add_item）。一度きり（flag で管理）。
##   item … 入手する道具 id / spot … スポット id / label … 表示名 / pos … 道の上の立ち位置
##   get_text … 入手時に流す一言（静かに。達成音は鳴らさない＝トーン厳守）
static func pickups_of(field_id: String) -> Array:
	match field_id:
		"shops":
			return [{
				"item": "mugiwara", "spot": "item_get_mugiwara", "label": "麦わら帽子",
				"pos": Vector2(760, 480),
				"get_text": "店先の台に、麦わら帽子がひとつ。日に灼けて、少しくたびれている。……もらっていこう。",
			}]
		"fields":
			return [{
				"item": "hanabi", "spot": "item_get_hanabi", "label": "農具小屋",
				"pos": Vector2(820, 415),
				"get_text": "畦道の小屋をのぞくと、去年の手持ち花火が、ひとたば残っていた。まだ、使えそうだ。",
			}]
	return []


# --- 使用（§3）＝道具を持っていると開く体験（鍵と鍵穴。パズルにはしない）-------
## 画面 id -> その画面で「所持していれば開く」体験。has_item AND 日/場所/天気条件で判定。
## 見逃しても再発生させない（一期一会）が、失敗ではない（§3/§8）。
##   item … 必要な道具 / phase … 必要な時間帯（-1=不問）/ spot・label・pos … 配置
##   fubutsushi … 体験で灯す風物詩 id（橋。§4）/ consume … 使うと道具を消費するか
##   script … 流す会話ノード（テキストは仮置き可）
static func usages_of(field_id: String) -> Array:
	match field_id:
		"hill":
			return [{
				"item": "mushi_ami", "phase": -1, "spot": "item_use_ami",
				"label": "雑木林で虫を探す", "pos": Vector2(300, 470),
				"fubutsushi": "mushitori", "consume": false,
				"script": [
					{ "speaker": "", "text": "丘のふちの雑木林。網を手に、そっと木の幹を見上げる。" },
					{ "speaker": "", "text": "――いた。角をつかむ手が、少しだけ震える。" },
				],
			}]
	return []
