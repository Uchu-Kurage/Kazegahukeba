class_name Endings
extends RefCounted
## エンディングの定義と判定（実装指示 §4 / 全体タイムライン設計 §5）。
##
## 8/31 到達時、各ルートが「どこまで到達したか」を見て結末を1つ選ぶ：
##   - 中盤の立場(stance A/B/C) を選んだルート＝そのルートを主軸に進んだ、とみなす。
##   - 複数が深まっていれば、最も深く進んだ（到達節目数が最大、同数なら関係値最大）ルートを採用。
##   - どのルートも深まっていなければ、記録者エンド系のフォールバック（quiet_summer）。
##
## しきい値・優先順位はすべて名前付き定数（ハードコード禁止）。判定は Routes（データ）を回す。
## 裏エンド(SECRET)は全ノーマル到達で解放（周回記録は SaveData が持つ）。

const SECRET := "secret"

## 全ノーマル・エンディング（三ルート×3着地＋記録者フォールバック）。全到達で裏エンド解放。
const NORMAL_IDS := [
	"kuma_friendship", "kuma_struggle", "kuma_bitter",
	"yufu_cross", "yufu_childhood", "yufu_beside",
	"aoi_now", "aoi_future", "aoi_unknown",
	"quiet_summer",
]

# --- 判定のしきい値（値は暫定。ここを変えれば着地の出やすさを調整できる）------
## 王道の着地（球磨=友情／由布=一線を越える）に届く関係値の下限（この値“以上”）。
## 関係値スケール（1枠+1）に合わせ、終盤まで見届けた＝ほぼ完走(Routes.AFF_LATE_2 相当)を基準にする。
## これ未満で立場だけ選んだ浅い完結は、より苦い着地（着地2）へ寄せる。
const AFF_DEEP := 34
## 「そのルートを主軸に進んだ」とみなすのに必要な到達節目数の下限（立場に加えての目安）。
const DEEP_MILESTONES := 4


## この周回の結末を1つ選ぶ。affinity・flags・stance（route_id→Stance の辞書）から判定。
static func pick(affinity: Dictionary, flags: Dictionary, stance: Dictionary) -> String:
	var best_route := ""
	var best_depth := -1
	var best_aff := -1

	# 「立場を選び（＝中盤に踏み込み）、かつ十分に深く進んだ」ルートの中から、最も深いものを採る。
	for route_id in Routes.ids():
		var st := int(stance.get(route_id, GameState.Stance.NONE))
		if st == GameState.Stance.NONE:
			continue
		var depth := _route_depth(route_id, flags)
		if depth < DEEP_MILESTONES:
			continue  # 立場は選んだが、節目が浅い＝主軸とは見なさない
		var aff := int(affinity.get(route_id, 0))
		if depth > best_depth or (depth == best_depth and aff > best_aff):
			best_route = route_id
			best_depth = depth
			best_aff = aff

	# どのルートも中盤に至らなかった → 記録者エンド系のフォールバック。
	if best_route == "":
		return "quiet_summer"

	var st_best := int(stance.get(best_route, GameState.Stance.NONE))
	return _route_ending(best_route, st_best, int(affinity.get(best_route, 0)))


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


## ルート×立場×関係値 → 着地(1〜3)。narrative なので各ルートの対応はここに持つ（数値は定数）。
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
		Routes.AOI:
			match st:
				GameState.Stance.A: return "aoi_now"                                         # 今を生き切る
				GameState.Stance.B: return "aoi_future"                                      # 続きを願う
				GameState.Stance.C: return "aoi_unknown"                                     # 知ろうとして届かない
	return "quiet_summer"


static func title_of(id: String) -> String:
	match id:
		"kuma_friendship": return "友を見送る夏"
		"kuma_struggle": return "あがきの果てに"
		"kuma_bitter": return "すれ違いの夏"
		"yufu_cross": return "幼なじみの、その先へ"
		"yufu_childhood": return "言えなかった夏"
		"yufu_beside": return "そばにいた夏"
		"aoi_now": return "今を、生き切る"
		"aoi_future": return "続きは、なくて"
		"aoi_unknown": return "知らないまま、好きだった"
		"quiet_summer": return "静かな夏"
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
		"aoi_now":
			return [
				{ "speaker": "", "text": "最後まで先を考えず、二人で今を燃やし尽くした。" },
				{ "speaker": "", "text": "あの夏は、確かにあった。理解はできなくても。〔仮テキスト〕" },
			]
		"aoi_future":
			return [
				{ "speaker": "葵", "text": "ごめんね。……未来は、あげられないや。" },
				{ "speaker": "", "text": "もっと一緒にいたかった、という渇き。〔仮テキスト〕" },
			]
		"aoi_unknown":
			return [
				{ "speaker": "", "text": "これほど好きだったのに、何も分からなかった。" },
				{ "speaker": "", "text": "彼女の核心には、ついに手が届かないまま夏が終わる。〔仮テキスト〕" },
			]
		"quiet_summer":
			return [
				{ "speaker": "", "text": "誰と深く過ごすでもなく、八月は静かに過ぎた。" },
				{ "speaker": "", "text": "世界は終わる。ただ、それだけが起きた。" },
			]
		SECRET:
			return [
				{ "speaker": "", "text": "すべての夏を、あなたは見届けた。" },
				{ "speaker": "", "text": "忘れないでいることだけが、この夏にできる弔いだった。" },
			]
	return [ { "speaker": "", "text": "夏が終わった。" } ]
