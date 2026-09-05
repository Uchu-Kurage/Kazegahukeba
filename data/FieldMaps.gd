class_name FieldMaps
extends RefCounted
## 散策画面（FieldScene）の定義とマップ接続表（実装指示 第6弾 §3）。
##
## 『ぼくのなつやすみ』方式：1場所＝1画面。道（歩ける帯）の上だけ歩き、画面端の出口で
## 隣の画面へ遷移する。移動では枠を消費しない（GameState の日付/フェーズを進めない）。
##
## 接続は画面ごとにハードコードせず、ここにデータとして持つ（§7：接続はデータ駆動）。
## 各画面：
##   id     … 画面ID（マップ接続設計の9場所に対応：home/shops/school/fields/sunflower/
##            shrine/hill/riverbank/estuary）。※まずは riverbank(河原と土手) 1枚だけ。
##   name   … 表示名
##   bg     … 背景PNGのパス（無ければコード描画のプレースホルダにフォールバック＝差し替え可）
##   roads  … 歩ける帯（Rect2 の配列。和集合の上だけ歩ける）。絵の全面は床にしない。
##   start  … その画面に「新規で」入ったときの初期位置（道の上）
##   exits  … 出口の配列。各出口：
##              id    … 出口ID（入ってきた方向＝入口の対応に使う）
##              label … 表示（→河口 等）
##              pos   … 出口トリガーの位置（道の端に置く）
##              to    … 接続先の画面ID（空文字＝未接続。§1 の段階では全て空でよい）
##              entry … 接続先で出現する入口の向き（"west"/"east"/"north"/"south"）。
##                      遷移先で「入ってきた方向」に対応する位置に立たせるのに使う（§3）。
##
## いまは §1（最小構成）なので riverbank 1枚のみ・出口の to は未接続。
## §3 で商店街などを足し、to を埋めれば河原↔商店街の遷移が通る（コード変更不要）。

const VIEW_W := 1152
const VIEW_H := 648


static func all() -> Array:
	return [
		{
			"id": "riverbank", "name": "河原と土手",
			"bg": "res://assets/field/riverbank.png",
			# 手前(下)から奥(上)へ通る畦道（縦帯）＋土手沿いの横道（横帯）＝十字の道。
			"roads": [
				Rect2(500, 140, 150, 450),   # 縦の畦道（手前↔奥）
				Rect2(140, 300, 880, 120),   # 土手沿いの横道（商店街↔河口）
			],
			"start": Vector2(560, 545),
			"exits": [
				{ "id": "to_estuary", "label": "→ 河口",   "pos": Vector2(1000, 360), "to": "", "entry": "west" },
				{ "id": "to_shops",   "label": "← 商店街", "pos": Vector2(175, 360),  "to": "", "entry": "east" },
				{ "id": "to_fields",  "label": "↑ 田んぼ", "pos": Vector2(575, 155),  "to": "", "entry": "south" },
			],
		},
	]


static func by_id(field_id: String) -> Dictionary:
	for f in all():
		if f["id"] == field_id:
			return f
	return {}


## 遷移先の画面で、来た方向(entry)に対応する出口の位置へプレイヤーを立たせる。
## 例：商店街から河原(east入口)に来たら、河原の「商店街への出口(to_shops)」の位置に出す。
## 対応する出口が無ければ start にフォールバック。
static func entry_position(field: Dictionary, entry_dir: String) -> Vector2:
	if entry_dir != "":
		for ex in field.get("exits", []):
			if String(ex.get("entry", "")) == entry_dir:
				return ex["pos"]
	return field.get("start", Vector2(VIEW_W / 2.0, VIEW_H / 2.0))
