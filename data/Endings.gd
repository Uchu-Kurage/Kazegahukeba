class_name Endings
extends RefCounted
## エンディングの定義と、どれになるかの判定（当面はここに直書き）。
##
## 判定は GameState の好感度・フラグを見て決める。しきい値や条件は仮なので、
## 台本を作り込みながら調整していく前提。裏エンド(SECRET)は全ノーマル到達で解放。

const SECRET := "secret"
const NORMAL_IDS := ["kuma_friendship", "kuma_struggle", "kuma_bitter", "quiet_summer"]


## この周回の結末を1つ選ぶ。中盤の立場(A/B/C)を主軸に、好感度・フラグで補正する。
static func pick(affinity: Dictionary, flags: Dictionary, stance: String) -> String:
	var kuma := int(affinity.get("kuma", 0))

	# 球磨とほとんど関わらず、立場も選ばなかった → 静かな夏。
	if kuma <= 1 and stance == "":
		return "quiet_summer"

	# 中盤の立場が主軸（プロットの着地1〜3に対応）。
	match stance:
		"a":
			return "kuma_struggle"                                   # 一緒にあがいた
		"b":
			return "kuma_friendship" if kuma >= 5 else "kuma_struggle"  # 寄り添い、深く見届けた
		"c":
			return "kuma_bitter"                                     # 諫めた／すれ違い

	# 立場イベントに至らなかった場合は、序盤の選択で寄せる。
	if flags.get("told_truth_kuma", false) and not flags.get("promised_kuma", false):
		return "kuma_bitter"
	if kuma >= 6 and flags.get("promised_kuma", false):
		return "kuma_friendship"
	return "kuma_struggle"


static func title_of(id: String) -> String:
	match id:
		"kuma_friendship": return "友を見送る夏"
		"kuma_struggle": return "あがきの果てに"
		"kuma_bitter": return "すれ違いの夏"
		"quiet_summer": return "静かな夏"
		SECRET: return "そして、覚えている"
	return "夏の終わり"


## エンディングで流す会話ノード（Dialogue にそのまま渡せる）。
static func script_of(id: String) -> Array:
	match id:
		"kuma_friendship":
			return [
				{ "speaker": "", "text": "八月の終わり。空はほとんど白く褪せている。" },
				{ "speaker": "球磨", "text": "……お前がいてくれて、よかったよ。" },
				{ "speaker": "ぼく", "text": "……ああ。" },
				{ "speaker": "球磨", "text": "外になんか、出られなかったけどさ。……悪くない夏だった。" },
				{ "speaker": "", "text": "叶わなかった夢も、覚えている限り、消えはしない。" },
			]
		"kuma_struggle":
			return [
				{ "speaker": "", "text": "最後まで、二人はあがいた。当然のように、報われなかった。" },
				{ "speaker": "球磨", "text": "なあ。俺たち、最後までかっこ悪かったな。" },
				{ "speaker": "ぼく", "text": "……ああ。" },
				{ "speaker": "球磨", "text": "でも……悪くなかった。" },
				{ "speaker": "", "text": "青さを、青さのまま終わらせる。それも一つの夏だ。" },
			]
		"kuma_bitter":
			return [
				{ "speaker": "", "text": "言葉は、最後まで足りなかった。" },
				{ "speaker": "球磨", "text": "……お前は、俺のこと、分かってくれると思ってた。" },
				{ "speaker": "", "text": "わだかまりは解けないまま、八月が終わる。" },
				{ "speaker": "", "text": "選ばなかったことの帰結。この苦さも、夏の一つだ。" },
			]
		"quiet_summer":
			return [
				{ "speaker": "", "text": "誰と深く過ごすでもなく、八月は静かに過ぎた。" },
				{ "speaker": "", "text": "世界は終わる。ただ、それだけが起きた。" },
			]
		SECRET:
			return [
				{ "speaker": "", "text": "すべての夏を、あなたは見届けた。" },
				{ "speaker": "", "text": "何度も繰り返したこの町の、いくつもの終わり方。" },
				{ "speaker": "", "text": "忘れないでいることだけが、この夏にできる弔いだった。" },
			]
	return [ { "speaker": "", "text": "夏が終わった。" } ]
