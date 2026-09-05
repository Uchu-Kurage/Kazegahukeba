class_name Routes
extends RefCounted
## 三ルート（球磨・由布・葵）を「同じデータ構造」で扱うための定義層（実装指示 §1）。
##
## ルートごとにコードで分岐させない。ルートの追加＝ここにデータを1本足すだけ。
## 各ルートは共通して次を持つ（データ駆動）：
##   id        … route_id（"kuma" / "yufu" / "aoi"）。関係値 affinity{} のキーも兼ねる。
##   character … その相手の character_id（＝route_id と一致させる）。
##   location  … その相手と深く過ごせる場所 id（枠を消費して関係が進む場所）。
##   stance    … 中盤の選択 A/B/C（GameState.stance{route_id} に enum で入る）。
##   milestones… 節目イベントの並び（前提フラグ・時期・台本を持つデータ。下記）。
##
## 進行フラグの命名規則は統一：{route_id}_{milestone.key}（例 "kuma_dream"）。
## → flag_of() で機械的に導出。requires も milestone.key で書き、内部でフラグ名へ変換する。
##
## 節目イベントのデータ（milestone）：
##   key               … 節目名（フラグ名の後半になる。ルート内で一意）。
##   requires          … 前提となる“同ルートの節目 key”の配列（順序の強制。連鎖）。
##   aff_min           … 必要な関係値の下限（affinity{route_id} がこの値以上）。
##   since / until     … 出現できる時期範囲（day_index。Timeline のフェーズ定数を使う）。
##   script            … 引く台本キー（本文は Dialogues.route_script、テキストは仮置き可）。
##   requires_choosing … その相手／場所を選んだ枠でのみ発生するか（既定 true）。
##                       節目は基本 true。将来 false（枠外で進む節目）にも対応できるよう持つ。

const KUMA := "kuma"
const YUFU := "yufu"
const AOI := "aoi"

## --- 関係値ゲート（＝そのルートに注いだ枠数の下限。全ルート共通のスケジュール）---
## 「時間の奪い合い（一周一人）」を成立させる主レバー。関係値は1枠につき+1なので、
## 各ゲート値 ≒ そこまでに必要な累積枠数。段階的に上げることで、深い節目ほど枠を要求する。
##
## 肝は中盤最後の AFF_STANCE。stance は中盤(〜30日)で時間窓が閉じるため、
## 「窓が閉じる前に関係値がゲートに届くか」で分岐する：
##   集中(そのルートに1日2枠)   → 早々に到達 → 完結
##   2掛け持ち(1日1枠)          → 中盤内に到達 → 1〜2本 完結
##   3分割(1日0.67枠)           → 到達が中盤の窓を過ぎる → stance未達 → 記録者フォールバック
## 値はすべてここで調整可能（実装指示 §7：しきい値は定数化）。
const AFF_EARLY_1 := 0    # 序盤1つ目（出会い直し等）：無条件
const AFF_EARLY_2 := 0    # 序盤2つ目
const AFF_EARLY_3 := 3    # 序盤3つ目（あがき開始等）
const AFF_MID_1 := 8      # 中盤1つ目
const AFF_MID_2 := 16     # 中盤2つ目
const AFF_STANCE := 25    # 中盤の選択(A/B/C)。ここに届くかがエンディング分岐の要
const AFF_LATE_1 := 30    # 終盤1つ目（折れる／決壊／転換点）
const AFF_LATE_2 := 34    # 終盤2つ目（気づき／最後の日々）＝全節目到達


## 全ルート定義（データ）。時期は Timeline のフェーズ定数を参照。
## いまは各ルート「序盤の節目」を主に、中盤の選択(A/B/C)と終盤の到達点までを仮置きで用意。
## テキストは Dialogues 側で仮置き。中身の作り込みは本文フェーズで行う。
static func all() -> Array:
	return [
		{
			"id": KUMA, "character": KUMA, "location": "riverside",
			"milestones": [
				# --- 序盤（出会い直し＋夢 → 河口の約束 → あがき開始）---
				_m("dream",   [],          AFF_EARLY_1, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("promise", ["dream"],   AFF_EARLY_2, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("struggle",["promise"], AFF_EARLY_3, Timeline.EARLY_START, Timeline.EARLY_END),
				# --- 中盤（前借りの空しさ → 河口志向 → 選択A/B/C）---
				_m("hollow",  ["struggle"],AFF_MID_1,   Timeline.MID_START,   Timeline.MID_END),
				_m("river",   ["hollow"],  AFF_MID_2,   Timeline.MID_START,   Timeline.MID_END),
				_m("stance",  ["river"],   AFF_STANCE,  Timeline.MID_START,   Timeline.MID_END),
				# --- 終盤（折れる瞬間 → 気づき）---
				_m("broke",   ["stance"],  AFF_LATE_1,  Timeline.LATE_START,  Timeline.LATE_END),
				_m("realize", ["broke"],   AFF_LATE_2,  Timeline.LATE_START,  Timeline.LATE_END),
			],
		},
		{
			"id": YUFU, "character": YUFU, "location": "shrine",
			"milestones": [
				# --- 序盤（いつもの三人 → 由布の「好き」→ 留まりたい提示）---
				_m("daily",   [],          AFF_EARLY_1, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("likes",   ["daily"],   AFF_EARLY_2, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("stay",    ["likes"],   AFF_EARLY_3, Timeline.EARLY_START, Timeline.EARLY_END),
				# --- 中盤（思い出の場所が消える → 一線の接近 → 選択A/B/C）---
				_m("lost",    ["stay"],    AFF_MID_1,   Timeline.MID_START,   Timeline.MID_END),
				_m("approach",["lost"],    AFF_MID_2,   Timeline.MID_START,   Timeline.MID_END),
				_m("stance",  ["approach"],AFF_STANCE,  Timeline.MID_START,   Timeline.MID_END),
				# --- 終盤（静かな決壊 → 最後の日々）---
				_m("collapse",["stance"],  AFF_LATE_1,  Timeline.LATE_START,  Timeline.LATE_END),
				_m("farewell",["collapse"],AFF_LATE_2,  Timeline.LATE_START,  Timeline.LATE_END),
			],
		},
		{
			"id": AOI, "character": AOI, "location": "shop",
			"milestones": [
				# --- 序盤（出会い → 連れ回し → はぐらかし）---
				_m("meet",    [],          AFF_EARLY_1, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("around",  ["meet"],    AFF_EARLY_2, Timeline.EARLY_START, Timeline.EARLY_END),
				_m("dodge",   ["around"],  AFF_EARLY_3, Timeline.EARLY_START, Timeline.EARLY_END),
				# --- 中盤（急速に深まる恋 → 翳り → 選択A/B/C）---
				_m("closer",  ["dodge"],   AFF_MID_1,   Timeline.MID_START,   Timeline.MID_END),
				_m("shadow",  ["closer"],  AFF_MID_2,   Timeline.MID_START,   Timeline.MID_END),
				_m("stance",  ["shadow"],  AFF_STANCE,  Timeline.MID_START,   Timeline.MID_END),
				# --- 終盤（転換点＝主人公の痛み → 最後の今日）---
				_m("turning", ["stance"],  AFF_LATE_1,  Timeline.LATE_START,  Timeline.LATE_END),
				_m("lastday", ["turning"], AFF_LATE_2,  Timeline.LATE_START,  Timeline.LATE_END),
			],
		},
	]


## 節目データを1件作る（script はキー = "{route}_{key}" の後半、台本参照も同キーを使う）。
static func _m(key: String, requires: Array, aff_min: int, since: int, until: int) -> Dictionary:
	return {
		"key": key, "requires": requires, "aff_min": aff_min,
		"since": since, "until": until, "requires_choosing": true,
	}


# --- 参照ヘルパー ----------------------------------------------------

static func by_id(route_id: String) -> Dictionary:
	for r in all():
		if r["id"] == route_id:
			return r
	return {}


static func by_location(location_id: String) -> Dictionary:
	for r in all():
		if r["location"] == location_id:
			return r
	return {}


static func by_character(character_id: String) -> Dictionary:
	for r in all():
		if r["character"] == character_id:
			return r
	return {}


static func ids() -> Array:
	var out := []
	for r in all():
		out.append(r["id"])
	return out


## 節目の進行フラグ名を導出する（命名規則：{route_id}_{key}）。
static func flag_of(route_id: String, milestone_key: String) -> String:
	return "%s_%s" % [route_id, milestone_key]
