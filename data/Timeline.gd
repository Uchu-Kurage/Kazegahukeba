class_name Timeline
extends RefCounted
## 共通背景タイムライン（全体タイムライン設計 §3）＝三人が同じ40日を共有する整合の要。
##
## ここは「どのルートを進めていても、世界の側で起きること」を持つ層。
##   - フェーズ境界（序盤／中盤／終盤）の日付定数（各ルートの節目の時期範囲が参照する）。
##   - 中盤の転機フラグ（球磨が河口＝未来へ傾き、三人でいる時間が減る）を、
##     プレイヤーがどのルートを選んでいても中盤の一定日付で必ず立てる（§2 の実装）。
##   - 葵の遍在遭遇の「今日の居場所」（§3。枠を消費しない軽い遭遇のための日替わり位置）。
##
## いずれも数字は仮＝動かして調整する前提。ルートごとにハードコードで分岐させない。

# --- フェーズの日付範囲（day_index。0 = 8/1）------------------------
## 各ルートの節目データ（Routes.gd）が since/until にこれらを使う。
const EARLY_START := 0
const EARLY_END := 14    # 序盤 1〜15日ごろ
const MID_START := 15
const MID_END := 29      # 中盤 16〜30日ごろ
const LATE_START := 30
const LATE_END := 39     # 終盤 31〜40日ごろ

# --- 共通背景フラグ（GameState.flags のキー。全ルート共通で立つ）-----
## 中盤の転機：球磨が自分のあがき（河口・未来）へ傾き始め、三人でいる時間が減る。
## 球磨ルートでは球磨視点で詳しく、由布ルートでは寂しさの文脈で、葵ルートではほぼ背景。
## → 各ルートの節目台本がこのフラグを参照して描写を出し分ける（Dialogues 側の if_flag）。
const F_KUMA_DRIFTING := "world_kuma_drifting"


## その日の背景状態を GameState に反映する（GameState が日付を進めるたびに呼ぶ）。
## 「強制イベント」＝プレイヤーの選択に関わらず、世界の側で進む変化。
static func apply_background(state) -> void:
	if state.day_index >= MID_START:
		# すでに立っていれば print で騒がないよう、変化時だけ set する。
		if not state.flags.get(F_KUMA_DRIFTING, false):
			state.set_flag(F_KUMA_DRIFTING, true)


## day_index がどのフェーズかを返す（"early" / "mid" / "late"）。表示や判定の補助。
static func phase_of(day: int) -> String:
	if day <= EARLY_END:
		return "early"
	if day <= MID_END:
		return "mid"
	return "late"


# --- 葵の遍在遭遇（§3。枠を消費しない層）----------------------------
## 「日替わりで葵の居場所が決まり、そこへ行くと軽い会話」の簡易版（確率方式は後で調整）。
## 葵自身の場所（深く過ごす枠）は遍在遭遇の対象外＝そこは枠を使う恋の進行に譲る。
const AOI_ROUTE := "aoi"

## 今日、葵がふらっと現れている場所 id を返す。日替わりで巡回する（決定的）。
## 巡回先は「他の相手がいる場所」だけ（葵自身の場所と、一人で過ごす場所・家は除く）。
## ＝一人で過ごす選択のときに葵と遭遇しない（記録者エンドの意図を守る）。
static func aoi_spot(day: int) -> String:
	var spots := []
	for loc in Locations.ALL:
		var who := Locations.character_of(loc["id"])
		if who == "" or who == AOI_ROUTE:
			continue  # 一人で過ごす場所・家（相手なし）と、葵自身の場所は除く
		spots.append(loc["id"])
	if spots.is_empty():
		return ""
	return String(spots[day % spots.size()])
