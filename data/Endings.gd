class_name Endings
extends RefCounted
## エンディングの定義と判定（実装指示 §4 / 全体タイムライン設計 §5）。
##
## 8/31 到達時、各ルートが「どこまで到達したか」を見て結末を1つ選ぶ：
##   - 中盤の立場(stance A/B/C) を選んだルート＝そのルートを主軸に進んだ、とみなす。
##   - 複数が深まっていれば、最も深く進んだ（到達節目数が最大、同数なら関係値最大）ルートを採用。
##   - どのルートも深まっていなければ、記録者エンド（見届けた／ひとり）へ。
##
## ★設計思想（最重要）：どのエンドも「正解／失敗」ではない。記録者エンドは、特定の誰かと
##   深く結ばれた夏と“対等な”一つの過ごし方。実装・変数名・テキストで失敗として扱わない。
##
## しきい値・配分はすべて名前付き定数（ハードコード禁止）。判定は Routes（データ）を回す。
## 裏エンド(SECRET)は全ノーマル到達で解放（周回記録は SaveData が持つ）。

const PLAYER := "ぼく"  # 主人公の仮の呼び名（記録者エンドの独白などで使う）

const SECRET := "secret"

## 記録者エンド（フォールバック）二種。
##   witness_summer … 特定の誰かとは深く結ばれなかったが、広く関わり夏の全体を見てきた記録者。
##   solo_summer    … 多くを一人で過ごし、終わりと一人で向き合った夏。どちらも対等な過ごし方。
const WITNESS := "witness_summer"
const SOLO := "solo_summer"

## 葵ルートの三分岐（8/31）。三つは対等＝優劣・正解・失敗はない（実装指示 第8弾 §2-1）。
## 命名に bad/fail/best 等の色をつけない。home を消極的選択として扱わない（最も積極的で切ない願い）。
const AOI_END_HIMAWARI := "aoi_end_himawari"  # 輝きの恋「夏を、夏のまま」（ひまわり畑）
const AOI_END_HILL := "aoi_end_hill"          # 見届ける恋「終わりを、共に」（丘）
const AOI_END_HOME := "aoi_end_home"          # 寄り添う恋「ただ、あなたのそばで」（主人公の家）

## 葵ルートの「傾き」タグ（中立名）。量ではなく方向で着地を決める（§2-2）。
const LEAN_WARMTH := "warmth"        # 明るさ・楽しさを膨らませる方向 → ひまわり畑へ
const LEAN_SHADOW := "shadow"        # 寂しさ・終わりに寄り添う方向 → 丘へ
const LEAN_CLOSENESS := "closeness"  # 距離を縮める・二人だけの親密さ → 家へ

## 同点・僅差のときの優先順位（先頭が優先。理由は後で調整可＝§2-3）。破綻なく必ず1つに決まる。
const LEAN_PRIORITY := [LEAN_SHADOW, LEAN_CLOSENESS, LEAN_WARMTH]

## 傾きの方向 → 着地の対応（直書きしない＝§5）。
const LEAN_TO_END := {
	LEAN_WARMTH: AOI_END_HIMAWARI,
	LEAN_SHADOW: AOI_END_HILL,
	LEAN_CLOSENESS: AOI_END_HOME,
}

## 三分岐の着地 → 8/31 に予定表へ載る「場所」id（第9弾 §5-3）。
## 予定表の無言の一マスが、着地（＝別れの温度）を可視化する。home は Locations にあるが
## himawari/hill は着地専用の場所名（GameState.place_name が補完表示する）。
const END_TO_PLACE := {
	AOI_END_HIMAWARI: "himawari",
	AOI_END_HILL: "hill",
	AOI_END_HOME: "home",
}


## 8/31 の葵の約束が載る場所 id（傾きの着地から導く）。
static func aoi_landing_place(end_id: String) -> String:
	return String(END_TO_PLACE.get(end_id, "home"))

## 全ノーマル・エンディング（球磨×3＋由布×3＋葵の三分岐＋記録者エンド二種）。全到達で裏エンド解放。
## 葵は三分岐のいずれも "aoi_" 始まり＝裏エンド判定では「葵ルート到達」で1つと数える（§3）。
const NORMAL_IDS := [
	"kuma_friendship", "kuma_struggle", "kuma_bitter",
	"yufu_cross", "yufu_childhood", "yufu_beside",
	AOI_END_HIMAWARI, AOI_END_HILL, AOI_END_HOME,
	WITNESS, SOLO,
]

# --- 判定のしきい値（値は暫定。ここを変えれば着地の出やすさを調整できる）------
## 王道の着地（球磨=友情／由布=一線を越える）に届く関係値の下限（この値“以上”）。
## 関係値スケール（1枠+1）に合わせ、終盤まで見届けた＝ほぼ完走(Routes.AFF_LATE_2 相当)を基準にする。
## これ未満で立場だけ選んだ浅い完結は、より苦い着地（着地2）へ寄せる。
const AFF_DEEP := 34
## 「そのルートを主軸に進んだ」とみなすのに必要な到達節目数の下限（立場に加えての目安）。
const DEEP_MILESTONES := 4

# --- 記録者エンドの分岐：「関わりの総量スコア」の配分としきい値（すべて仮＝調整可能）------
## スコアは「他者とどれだけ関わったか」を測る。低い＝劣る ではなく「一人で過ごすことを選んだ」。
## ⚠️ 一人で過ごす活動は総量に加えない（solo_summer へ自然に向かうべき、という設計意図）。
const SCORE_PER_AFFINITY := 1       # 関係値1につき（＝相手と過ごした枠の量）
const SCORE_PER_ROUTE_VISITED := 3  # 関わった相手（＝ルートの場所）の種類ごと
const SCORE_PER_AMBIENT := 1        # 葵の遍在遭遇1回につき
const SCORE_PER_NIGHT := 4          # 特別な夜への参加1回につき
## この値以上なら witness_summer（広く見届けた）、未満なら solo_summer（一人で過ごした）。
const WITNESS_MIN := 40


## 記録者エンド（フォールバック）の id 群。裏エンド解放条件の判定に使う。
const RECORDER_IDS := [WITNESS, SOLO]


## 裏エンド（9月1日）の解放条件（実装指示 第5弾 §1）。
## 全エンディング到達＝三ルートそれぞれ“いずれかの着地”＋記録者エンド二種、が周回記録に揃うこと。
## （着地違いを個別カウントしているので、ルートは「いずれか1つでも見た」で満たすと解釈する）
static func ura_unlocked() -> bool:
	for route_id in Routes.ids():
		var seen_any := false
		for eid in NORMAL_IDS:
			if String(eid).begins_with(route_id + "_") and SaveData.has_seen(eid):
				seen_any = true
				break
		if not seen_any:
			return false
	for eid in RECORDER_IDS:
		if not SaveData.has_seen(eid):
			return false
	return true


## 裏エンドを再生済みか（周回記録の SECRET を「見た」印として流用）。
static func ura_seen() -> bool:
	return SaveData.has_seen(SECRET)


## この周回の結末を1つ選ぶ。
## 深く完結したルートがあればそのエンディング、無ければ「関わりの総量」で記録者エンド二種に分岐。
## 葵ルートだけは着地を「傾き（方向）」で決めるので aoi_lean を受け取る（§2-2）。
static func pick(affinity: Dictionary, flags: Dictionary, stance: Dictionary, visits: Dictionary, counters: Dictionary, aoi_lean: Dictionary = {}) -> String:
	var best_route := ""
	var best_depth := -1
	var best_aff := -1

	# 「十分に深く進んだ（主軸として進めた）」ルートの中から、最も深いものを採る。
	for route_id in Routes.ids():
		var depth := _route_depth(route_id, flags)
		if depth < DEEP_MILESTONES:
			continue  # 節目が浅い＝主軸とは見なさない
		# 球磨・由布は中盤の立場(stance)を選んで初めて主軸とみなす（従来どおり）。
		# 葵は着地を“方向”で決めるルート＝深さのみで主軸判定し、立場は問わない（§2-2）。
		if route_id != Routes.AOI and int(stance.get(route_id, GameState.Stance.NONE)) == GameState.Stance.NONE:
			continue
		var aff := int(affinity.get(route_id, 0))
		if depth > best_depth or (depth == best_depth and aff > best_aff):
			best_route = route_id
			best_depth = depth
			best_aff = aff

	# どのルートも深く完結していない → 記録者エンド。関わりの総量で二種に分岐（優劣ではない）。
	if best_route == "":
		var score := engagement_score(affinity, flags, visits, counters)
		return WITNESS if score >= WITNESS_MIN else SOLO

	# 葵ルートが主軸 → 傾きの方向で三分岐（量ではなく方向。三つは対等）。
	if best_route == Routes.AOI:
		return _aoi_ending(aoi_lean)

	var st_best := int(stance.get(best_route, GameState.Stance.NONE))
	return _route_ending(best_route, st_best, int(affinity.get(best_route, 0)))


## 葵ルートの三分岐（8/31）。最も高い“方向”の着地へ。同点は LEAN_PRIORITY の先頭が優先。
## どの方向にも傾かなくても必ず三つのいずれかに落ちる（記録者エンドには行かない＝§2-3）。
static func _aoi_ending(aoi_lean: Dictionary) -> String:
	var best_dir := LEAN_PRIORITY[0]
	var best_val := -1
	for dir in LEAN_PRIORITY:  # 優先順位の高い方から見るので、同点は先頭が残る
		var v := int(aoi_lean.get(dir, 0))
		if v > best_val:
			best_val = v
			best_dir = dir
	return String(LEAN_TO_END[best_dir])


## 「関わりの総量スコア」＝他者とどれだけ関わったか。一人で過ごす活動は加えない（設計意図）。
static func engagement_score(affinity: Dictionary, flags: Dictionary, visits: Dictionary, counters: Dictionary) -> int:
	var s := 0
	for route_id in Routes.ids():
		s += SCORE_PER_AFFINITY * int(affinity.get(route_id, 0))
		# 関わった相手の“種類数”＝そのルートの場所を訪れたか（一人で過ごす場所は含めない）。
		if visits.has(Routes.by_id(route_id)["location"]):
			s += SCORE_PER_ROUTE_VISITED
	s += SCORE_PER_AMBIENT * int(counters.get("aoi_ambient", 0))
	s += SCORE_PER_NIGHT * _night_participation(flags)
	return s


## 特別な夜に参加した回数（三人で／誰かと／序盤の花火）。夜フラグから数える。
static func _night_participation(flags: Dictionary) -> int:
	var n := 0
	for k in flags:
		if not flags[k]:
			continue
		var ks := String(k)
		if ks == Nights.F_EARLY_FIREWORKS or ks.ends_with(Nights.SUF_FESTIVAL) or ks.ends_with(Nights.SUF_LAST_FIREWORKS):
			n += 1
	return n


## そのルートで到達済みの節目数（＝どこまで深く進んだか）。
static func _route_depth(route_id: String, flags: Dictionary) -> int:
	var route := Routes.by_id(route_id)
	if route.is_empty():
		return 0
	var n := 0
	for m in route["milestones"]:
		if flags.get(Routes.flag_of(route_id, String(m["key"])), false):
			n += 1
	return n


## ルート×立場×関係値 → 着地。narrative なので各ルートの対応はここに持つ（数値は定数）。
## ※葵ルートは立場ではなく「傾き」で決めるので _aoi_ending を使う（ここには来ない）。
static func _route_ending(route_id: String, st: int, aff: int) -> String:
	match route_id:
		Routes.KUMA:
			match st:
				GameState.Stance.A: return "kuma_struggle"                                   # 一緒にあがいた
				GameState.Stance.B: return "kuma_friendship" if aff >= AFF_DEEP else "kuma_struggle"  # 寄り添い
				GameState.Stance.C: return "kuma_bitter"                                     # 諫めた／すれ違い
		Routes.YUFU:
			match st:
				GameState.Stance.A: return "yufu_cross" if aff >= AFF_DEEP else "yufu_childhood"  # 一線を越える
				GameState.Stance.B: return "yufu_childhood"                                  # 幼なじみのまま
				GameState.Stance.C: return "yufu_beside"                                     # 喪失に寄り添う
	return SOLO  # 安全弁（通常ここには来ない）。記録者エンド側へ寄せる


static func title_of(id: String) -> String:
	match id:
		"kuma_friendship": return "友を見送る夏"
		"kuma_struggle": return "あがきの果てに"
		"kuma_bitter": return "すれ違いの夏"
		"yufu_cross": return "幼なじみの、その先へ"
		"yufu_childhood": return "言えなかった夏"
		"yufu_beside": return "そばにいた夏"
		AOI_END_HIMAWARI: return "夏を、夏のまま"
		AOI_END_HILL: return "終わりを、この目で"
		AOI_END_HOME: return "ただ、そばにいて"
		WITNESS: return "夏を、見届けた"
		SOLO: return "ひとりの夏"
		SECRET: return "そして、覚えている"
	return "夏の終わり"


## エンディングで流す会話ノード（Dialogue にそのまま渡せる）。テキストは仮置き。
static func script_of(id: String) -> Array:
	match id:
		"kuma_friendship":
			return [
				{ "speaker": "", "text": "八月の終わり。空はほとんど白く褪せている。" },
				{ "speaker": "球磨", "text": "……お前がいてくれて、よかったよ。" },
				# 特別な夜（最後の花火を球磨と過ごした）を見ていれば、結末に一言そえる（§4）。
				{ "if_flag": "kuma_last_fireworks", "then": [
					{ "speaker": "球磨", "text": "最後の花火、お前と見れてよかった。……あれで、十分だ。" },
				]},
				{ "speaker": "", "text": "叶わなかった夢も、覚えている限り、消えはしない。" },
			]
		"kuma_struggle":
			return [
				{ "speaker": "球磨", "text": "なあ。俺たち、最後までかっこ悪かったな。……でも、悪くなかった。" },
				{ "speaker": "", "text": "青さを、青さのまま終わらせる。それも一つの夏だ。" },
			]
		"kuma_bitter":
			return [
				{ "speaker": "球磨", "text": "……お前は、俺のこと、分かってくれると思ってた。" },
				{ "speaker": "", "text": "わだかまりは解けないまま、八月が終わる。" },
			]
		"yufu_cross":
			return [
				{ "speaker": "由布", "text": "……幼なじみじゃ、なくなっちゃうね。でも、いい。最後に、あなたと。" },
				{ "speaker": "", "text": "喪失の中の、小さな獲得。切ないが、温かい。〔仮テキスト〕" },
			]
		"yufu_childhood":
			return [
				{ "speaker": "由布", "text": "……幼なじみのままで、よかったのかな。" },
				{ "speaker": "", "text": "安全な関係を守った。でも、言えなかった後悔が残る。〔仮テキスト〕" },
			]
		"yufu_beside":
			return [
				{ "speaker": "由布", "text": "……そばにいてくれて、ありがとう。" },
				{ "speaker": "", "text": "恋の形にはならなかったが、一人じゃなかった。〔仮テキスト〕" },
			]
		AOI_END_HIMAWARI, AOI_END_HILL, AOI_END_HOME:
			# 葵ルートの三分岐は本文層（AoiScript）に持つ。場所ごとの骨子＋共通の余韻。
			return AoiScript.ending(id)
		WITNESS:  # 見届けたエンド：広く関わり、夏の全体を記憶した記録者。裏エンドへの静かな種。
			return [
				{ "speaker": "", "text": "特定の誰かと、深く結ばれることはなかった。" },
				{ "speaker": "", "text": "けれど、この町のいろんな人と、いろんな場所と、ひと夏を分け合った。" },
				{ "speaker": PLAYER, "text": "……ぼくは、この夏の全部を覚えている。たぶん、誰よりも。" },
				{ "speaker": "", "text": "その感覚が何を意味するのかは、まだ分からない。ただ静かに、胸の奥に残った。" },
			]
		SOLO:  # ひとりのエンド：多くを一人で過ごし、終わりと一人で向き合った夏。裁かない。
			return [
				{ "speaker": "", "text": "この夏、ぼくは多くの時間を、一人で過ごした。" },
				{ "speaker": "", "text": "褪せていく空を、消えていく町を、ただ一人で見ていた。" },
				{ "speaker": PLAYER, "text": "……寂しくなかった、と言えば嘘になる。でも、これはこれで、ぼくの夏だ。" },
				{ "speaker": "", "text": "誰にも言えない、自分だけの夏があった。それだけのことだ。" },
			]
		SECRET:
			return [
				{ "speaker": "", "text": "すべての夏を、あなたは見届けた。" },
				{ "speaker": "", "text": "忘れないでいることだけが、この夏にできる弔いだった。" },
			]
	return [ { "speaker": "", "text": "夏が終わった。" } ]
