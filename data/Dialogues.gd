class_name Dialogues
extends RefCounted
## 会話データ（当面はここに直書き）。テキストはすべて仮置き＝本文は別途詰める前提。
##
## ノードは3種類:
##   セリフ : { "speaker": 表示名（""なら地の文）, "text": セリフ }
##   選択肢 : { "text": 質問文(省略可), "choices": [ 選択肢, ... ] }
##     選択肢: { "text": 表示, "affinity": {who: delta}, "set": {flag: true},
##             "stance": { route_id: GameState.Stance の値 }, "then": [ 続くノード... ] }
##   効果   : { "effect": { "set": {...}, "affinity": {...} } }（表示せず状態だけ反映）
##
## さらに Story.flatten が展開する「条件ノード」を書ける（Dialogue 側は関知しない）:
##   { "if_flag": フラグ名, "then": [...], "else": [...] }
##   { "if_not_flag": フラグ名, "then": [...], "else": [...] }
## → §2「共通背景フラグ(world_kuma_drifting)を各ルートの節目が参照して描写を出し分ける」を実現。
##
## 三ルート（球磨=riverside／由布=shrine／葵=shop）はすべて Story 経由で
## route_script / route_filler が引かれる。ルート追加＝ここに台本を足すだけ（コード分岐なし）。

const PLAYER := "ぼく"  # 主人公の仮の呼び名


## ルートの無い場所（家など）の固定台本。route 付きの場所は Story が route_script を引く。
static func for_location(location_id: String) -> Array:
	match location_id:
		_:
			return [
				{ "speaker": "", "text": "家に戻ると、扇風機の音だけが回っている。" },
				{ "speaker": PLAYER, "text": "……少し、休もう。" },
				{ "speaker": "", "text": "何もしない時間も、この夏の一部だ。" },
			]


## 節目イベントの台本。route_id × milestone.key で引く（条件は Routes 側のデータ）。
## テキストは仮置き。中盤の "stance" は A/B/C を選ばせる選択ノード（stance を route 別に立てる）。
static func route_script(route_id: String, key: String) -> Array:
	match route_id:
		Routes.KUMA:
			return _kuma_script(key)
		Routes.YUFU:
			return _yufu_script(key)
		Routes.AOI:
			return _aoi_script(key)
	return []


# --- 球磨ルート（友情・青さ・未来）----------------------------------
static func _kuma_script(key: String) -> Array:
	match key:
		"dream":
			return [
				{ "speaker": "", "text": "いつもの川原。球磨が石に腰かけて、川下のほうを見ている。" },
				{ "speaker": "球磨", "text": "よう。今年もこの夏が来たな。" },
				{ "speaker": PLAYER, "text": "……ああ。" },
				{ "speaker": "球磨", "text": "俺さ、いつか外で、でっかいことをやるんだ。未来なんて、まだいくらでもある。" },
				{ "speaker": "", "text": "その未来が来ないことを、ぼくだけが知っている。" },
			]
		"promise":
			return [
				{ "speaker": "球磨", "text": "覚えてるか。ガキの頃、この川の先の海まで行こうって約束したよな。" },
				{ "speaker": "球磨", "text": "あんときは途中で引き返した。……大人になったら、あの先まで行こうな。" },
				{ "speaker": "", "text": "川は、河口で海へ出る。球磨の名前と、同じように。" },
			]
		"struggle":
			return [
				{ "speaker": "球磨", "text": "未来が来ないなら、今のうちに掴めばいい。やりたいこと、全部やる。" },
				{ "speaker": "", "text": "空回り気味だが、球磨は本気だった。〔仮テキスト〕" },
			]
		"hollow":  # 前借りの空しさ（中盤）＝背景フラグを球磨視点で詳しく
			return [
				{ "if_flag": Timeline.F_KUMA_DRIFTING, "then": [
					{ "speaker": "", "text": "球磨は焦るように動き続ける。三人でいる時間は、いつのまにか減っていた。" },
				]},
				{ "speaker": "球磨", "text": "……なんか、詰め込んでも、これじゃない気がするんだ。" },
				{ "speaker": "", "text": "前借りした未来は、どこか空しい。〔仮テキスト〕" },
			]
		"river":  # 河口志向が強まる（中盤）
			return [
				{ "speaker": "球磨", "text": "河口へ行こう。あの約束の先まで。今しかないだろ。" },
				{ "speaker": "", "text": "下流へ辿るほど、世界が褪せて見える。〔仮テキスト〕" },
			]
		"stance":  # 中盤の選択 A/B/C（球磨への態度）
			return [
				{ "speaker": "球磨", "text": "なあ、お前はどうする。俺のあがき、付き合ってくれるか。" },
				{ "text": "球磨のあがきに、どう向き合う？", "choices": [
					{ "text": "一緒にあがく", "stance": { Routes.KUMA: GameState.Stance.A },
						"affinity": { Routes.KUMA: 1 },
						"then": [ { "speaker": "球磨", "text": "……はは。だよな。行こうぜ。" } ] },
					{ "text": "気持ちに寄り添う", "stance": { Routes.KUMA: GameState.Stance.B },
						"affinity": { Routes.KUMA: 1 },
						"then": [ { "speaker": "球磨", "text": "……お前は、そういうやつだよな。" } ] },
					{ "text": "諫める／残りを一緒に", "stance": { Routes.KUMA: GameState.Stance.C },
						"then": [ { "speaker": "球磨", "text": "……なんだよ、それ。" } ] },
				]},
			]
		"broke":  # 折れる瞬間（終盤・河口）
			return [
				{ "speaker": "", "text": "河口。道の消えた白い霞の前で、球磨が膝をつく。" },
				{ "speaker": "球磨", "text": "……本当は、分かってたんだ。終わるのが怖くて、遠くばっか見てた。" },
				{ "speaker": "", "text": "青さの正体が、ここで剥がれ落ちる。〔仮テキスト〕" },
			]
		"realize":  # 気づき（終盤）
			return [
				{ "speaker": "球磨", "text": "一番惜しいのが、この、なんてことない場所なんだ。笑えるよな。" },
				{ "speaker": "", "text": "本当に大切だったのは、今ここにあった。〔仮テキスト〕" },
			]
	return []


# --- 由布ルート（過去・思い出・一線）--------------------------------
static func _yufu_script(key: String) -> Array:
	match key:
		"daily":
			return [
				{ "speaker": "", "text": "石段をのぼると、蝉の声が近い。由布が涼んでいる。" },
				{ "speaker": "由布", "text": "お参り？　それとも、涼みに来ただけ？" },
				{ "speaker": PLAYER, "text": "……なんとなく。" },
				{ "speaker": "由布", "text": "ふふ。じゃあ、隣、座ってけば。" },
			]
		"likes":
			return [
				{ "speaker": "由布", "text": "わたし、この景色が好き。夕暮れの田んぼも、雨上がりの匂いも。" },
				{ "speaker": "", "text": "由布にとって風景は、思い出そのものだ。〔仮テキスト〕" },
			]
		"stay":
			return [
				{ "speaker": "由布", "text": "球磨は外へ、って言うけど。……わたしは、ずっとここにいたい。" },
				{ "speaker": "", "text": "留まりたい子だと、静かに知る。〔仮テキスト〕" },
			]
		"lost":  # 思い出の場所が消える（中盤）＋背景フラグを寂しさの文脈で
			return [
				{ "speaker": "由布", "text": "……ここ、無くなっちゃったね。" },
				{ "speaker": "", "text": "消えた場所の前で、由布は静かに立ち尽くしていた。" },
				{ "if_flag": Timeline.F_KUMA_DRIFTING, "then": [
					{ "speaker": "由布", "text": "球磨、最近付き合い悪いね。……三人でいられる時間も、もう。" },
				]},
			]
		"approach":  # 一線の接近（中盤）
			return [
				{ "speaker": "", "text": "二人きりになる場面が増えた。由布の距離が、幼なじみのそれではなくなっていく。" },
				{ "speaker": "由布", "text": "……なんでもない。ごめん。" },
			]
		"stance":  # 中盤の選択 A/B/C（一線への向き合い方）
			return [
				{ "text": "由布との「一線」に、どう向き合う？", "choices": [
					{ "text": "一線を越えようとする", "stance": { Routes.YUFU: GameState.Stance.A },
						"affinity": { Routes.YUFU: 1 },
						"then": [ { "speaker": "由布", "text": "……ばか。急に、そういうこと言う。" } ] },
					{ "text": "幼なじみのまま守る", "stance": { Routes.YUFU: GameState.Stance.B },
						"then": [ { "speaker": "由布", "text": "……うん。このままが、いいよね。" } ] },
					{ "text": "由布の痛みに寄り添う", "stance": { Routes.YUFU: GameState.Stance.C },
						"affinity": { Routes.YUFU: 1 },
						"then": [ { "speaker": "由布", "text": "……そばに、いてくれるんだ。" } ] },
				]},
			]
		"collapse":  # 静かな決壊（終盤頭）＝このルートの核
			return [
				{ "speaker": "由布", "text": "……ごめんね。わたし、本当は……ずっと、失いたくなかった。" },
				{ "speaker": "由布", "text": "この町も、球磨も、あなたも。三人でいられた、この夏も。全部……" },
				{ "speaker": "", "text": "取り乱さない。ただ、静かに涙がこぼれた。〔仮テキスト〕" },
			]
		"farewell":  # 最後の日々（終盤）
			return [
				{ "speaker": "由布", "text": "ぜんぶ、無くなっちゃうね。わたしが好きだったもの、ぜんぶ。……でもね、" },
				{ "speaker": "", "text": "留まれない現実の中で、由布が何を見出すか。〔仮テキスト〕" },
			]
	return []


# --- 葵ルート（現在・今）※二層構造：正体を一切匂わせない ------------
static func _aoi_script(key: String) -> Array:
	match key:
		"meet":
			return [
				{ "speaker": "", "text": "まぶしい光の中に、見慣れない女の子がいた。" },
				{ "speaker": "葵", "text": "ねえ、あなた、面白い顔してる。" },
				{ "speaker": PLAYER, "text": "……いきなりだな。" },
				{ "speaker": "葵", "text": "あはは。わたし、葵。よろしくね。" },
			]
		"around":
			return [
				{ "speaker": "葵", "text": "これ何？　行ってみよう！　ねえ、早く早く。" },
				{ "speaker": "", "text": "見慣れた町が、葵の目を通すと少し新しく見えた。〔仮テキスト〕" },
			]
		"dodge":
			return [
				{ "speaker": PLAYER, "text": "……葵は、どこから来たんだ？" },
				{ "speaker": "葵", "text": "んー、遠く。秘密！　さ、次いこ。" },
				{ "speaker": "", "text": "軽くかわされた。〔仮テキスト〕" },
			]
		"closer":  # 急速に近づく恋（中盤）。背景（球磨離脱）はほぼ触れない＝軽く。
			return [
				{ "speaker": "葵", "text": "もっと一緒にいたい。今、あなたといるのが楽しいんだもん。" },
				{ "if_flag": Timeline.F_KUMA_DRIFTING, "then": [
					{ "speaker": "葵", "text": "球磨くん、最近見ないね。……ま、いっか。今はわたしたちの番。" },
				]},
			]
		"shadow":  # 翳り（中盤）※さらっと。意味深にしない。
			return [
				{ "speaker": "", "text": "全力で笑ったあと、葵がふと一瞬、遠い目をした。" },
				{ "speaker": "葵", "text": "……ん？　なんでもないよ。さ、次いこ！" },
			]
		"stance":  # 中盤の選択 A/B/C（葵の「今」への向き合い方）
			return [
				{ "text": "葵の「今を生きる」姿勢に、どう応える？", "choices": [
					{ "text": "一緒に今を生きる", "stance": { Routes.AOI: GameState.Stance.A },
						"affinity": { Routes.AOI: 1 },
						"then": [ { "speaker": "葵", "text": "うん！　それでこそ。今を楽しもう。" } ] },
					{ "text": "未来を求める", "stance": { Routes.AOI: GameState.Stance.B },
						"then": [ { "speaker": "葵", "text": "……夏が終わっても、か。ふふ、欲張りだね。" } ] },
					{ "text": "彼女を知ろうとする", "stance": { Routes.AOI: GameState.Stance.C },
						"then": [ { "speaker": "葵", "text": "そんなに知りたい？　変なの。" } ] },
				]},
			]
		"turning":  # 転換点＝主人公の痛みのピーク（終盤頭）
			return [
				{ "speaker": PLAYER, "text": "君のこと、何も知らない。……夏が終わったら、君はどうなるんだ。" },
				{ "speaker": "葵", "text": "過去も先も、あんまり意味ないと思ってる。今、ここにあなたといる。それが全部でしょ？" },
				{ "speaker": "", "text": "理解はできない。でも、好きだ。〔仮テキスト〕" },
			]
		"lastday":  # 最後の今日（終盤）
			return [
				{ "speaker": "葵", "text": "この夏、すっごく楽しかった。あなたといられて。……これで、じゅうぶん。" },
				{ "speaker": "", "text": "いつも通りの葵のまま。〔仮テキスト〕" },
			]
	return []


## 節目が無い日の、その相手との日常会話（関係値レベル 0/1/2 で段階変化の下地）。
## テキストは仮置き。ルートごとに1系統だけ用意（本文フェーズで増やす）。
static func route_filler(route_id: String, level: int) -> Array:
	match route_id:
		Routes.KUMA:
			if level >= 2:
				return [ { "speaker": "球磨", "text": "お前とこうしてるの、悪くないな。" } ]
			return [ { "speaker": "球磨", "text": "……今日は、ただ川を見てるだけでいいや。" } ]
		Routes.YUFU:
			if level >= 2:
				return [ { "speaker": "由布", "text": "……こういう時間が、好き。" } ]
			return [ { "speaker": "由布", "text": "今日は静かだね。蝉の声だけ。" } ]
		Routes.AOI:
			if level >= 2:
				return [ { "speaker": "葵", "text": "また会えた！　今日は何する？" } ]
			return [ { "speaker": "葵", "text": "あ、来た来た。ひま？　ね、ひまでしょ。" } ]
	return [ { "speaker": "", "text": "何気ない時間が過ぎていく。" } ]


## 葵の遍在遭遇（枠を消費しない軽い遭遇）。§3。
## ⚠️ 二層構造の鉄則：正体を匂わせない。ただの「よく会う、明るい子」として通す。
static func aoi_ambient() -> Array:
	return [
		{ "speaker": "葵", "text": "あ、また会ったね！　ほんと、どこにでもいるでしょ、わたし。" },
		{ "speaker": "", "text": "葵は手を振って、また人混みのほうへ駆けていった。" },
	]
