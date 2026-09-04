class_name Dialogues
extends RefCounted
## 会話データ（当面はここに直書き）。location_id ごとに会話ノードの配列を返す。
##
## ノードは2種類:
##   セリフ : { "speaker": 表示名（""なら地の文）, "text": セリフ }
##   選択肢 : { "text": 質問文(省略可), "choices": [ 選択肢, ... ] }
##     選択肢: { "text": 表示, "affinity": {who: delta}, "set": {flag: true},
##             "then": [ 選んだときに続くノード... ] }
##
## 物語を作り込む段階では、日付や好感度・フラグで台本を分岐させていく想定
## （for_location に引数を足し、GameState を見て返す配列を変えればよい）。

const PLAYER := "ぼく"  # 主人公の仮の呼び名

## 球磨の中盤イベント（A/B/C）を出すまでの川原の訪問回数。小さくすると早く出る。
const KUMA_MID_AFTER := 1


static func for_location(location_id: String) -> Array:
	match location_id:
		"riverside":
			return _riverside()
		"shop":
			return [
				{ "speaker": "", "text": "商店街は、どこか気だるい昼下がり。" },
				{ "speaker": "夏", "text": "あら、来たの。ラムネ、まだ冷えてるよ。" },
				{ "speaker": PLAYER, "text": "……もらおうかな。" },
				{ "speaker": "夏", "text": "ふふ。こういう日が、ずっと続けばいいのにね。" },
			]
		"shrine":
			return [
				{ "speaker": "", "text": "石段をのぼると、蝉の声が近い。" },
				{ "speaker": "由布", "text": "お参り？　それとも、涼みに来ただけ？" },
				{
					"choices": [
						{
							"text": "お参りに",
							"affinity": { "yuu": 1 },
							"then": [ { "speaker": "由布", "text": "ふうん。殊勝だね。" } ],
						},
						{
							"text": "きみに会いに",
							"affinity": { "yuu": 2 },
							"set": { "flirt_yuu": true },
							"then": [ { "speaker": "由布", "text": "……ばか。" } ],
						},
					],
				},
				{ "speaker": "由布", "text": "じゃあ、隣、座ってけば。" },
			]
		_:
			return [
				{ "speaker": "", "text": "家に戻ると、扇風機の音だけが回っている。" },
				{ "speaker": PLAYER, "text": "……少し、休もう。" },
				{ "speaker": "", "text": "何もしない時間も、この夏の一部だ。" },
			]


# --- 川原（球磨）: 状態で会話が変わる -------------------------------

## 立場が決まっていなければ、序盤の顔合わせ → （何度か通うと）中盤の A/B/C。
## 立場が決まったあとは、その立場に応じた短い場面。
static func _riverside() -> Array:
	if GameState.kuma_stance != "":
		return _riverside_after(GameState.kuma_stance)
	if int(GameState.visits.get("riverside", 0)) >= KUMA_MID_AFTER:
		return _riverside_stance()
	return _riverside_intro()


static func _riverside_intro() -> Array:
	return [
		{ "speaker": "", "text": "川の音がする。球磨がいつもの石に腰かけている。" },
		{ "speaker": "球磨", "text": "よう。今年もこの夏が来たな。" },
		{ "speaker": PLAYER, "text": "……ああ。" },
		{ "speaker": "球磨", "text": "なあ、来年も、再来年も、こうやってここに来ようぜ。" },
		{
			"choices": [
				{
					"text": "ああ、来よう",
					"affinity": { "kuma": 2 },
					"set": { "promised_kuma": true },
					"then": [ { "speaker": "球磨", "text": "だろ？　約束な。" } ],
				},
				{
					"text": "……（だまってうなずく）",
					"affinity": { "kuma": 1 },
					"then": [ { "speaker": "", "text": "球磨は少し笑って、それ以上は聞かなかった。" } ],
				},
				{
					"text": "来年なんて、来ないよ",
					"affinity": { "kuma": -1 },
					"set": { "told_truth_kuma": true },
					"then": [
						{ "speaker": "球磨", "text": "……なんだよ、辛気くさいな。" },
						{ "speaker": "", "text": "その横顔が、一瞬だけこわばった気がした。" },
					],
				},
			],
		},
		{ "speaker": "", "text": "その“来年”が来ないことを、ぼくだけが知っている。" },
	]


## 中盤の核。球磨のあがきに、どう向き合うかを選ぶ（A/B/C）。ここで着地が大きく決まる。
static func _riverside_stance() -> Array:
	return [
		{ "speaker": "", "text": "川原の球磨は、前より少し焦って見える。" },
		{ "speaker": "球磨", "text": "なあ、まだ間に合うよな。終わりを止める方法、きっとどこかに――" },
		{ "speaker": "", "text": "そのあがきが報われないことを、二人とも、薄々わかってきている。" },
		{
			"text": "球磨に、どう向き合う？",
			"choices": [
				{
					"text": "一緒にあがく",
					"stance": "a",
					"affinity": { "kuma": 2 },
					"set": { "struggle_together": true },
					"then": [ { "speaker": "球磨", "text": "……ああ。お前がいるなら、まだやれる。" } ],
				},
				{
					"text": "そばで寄り添う",
					"stance": "b",
					"affinity": { "kuma": 1 },
					"then": [ { "speaker": "球磨", "text": "……そっか。無理にとは、言わないよ。" } ],
				},
				{
					"text": "もう受け入れよう、と諫める",
					"stance": "c",
					"affinity": { "kuma": -1 },
					"set": { "dissuaded_kuma": true },
					"then": [ { "speaker": "球磨", "text": "……お前まで、そんなこと言うのかよ。" } ],
				},
			],
		},
	]


## 立場を決めたあとの、川原の短い場面。
static func _riverside_after(stance: String) -> Array:
	match stance:
		"a":
			return [
				{ "speaker": "球磨", "text": "次はあそこを調べよう。まだ、終わらせない。" },
				{ "speaker": "", "text": "二人で、無駄かもしれない道を歩く。それでも、隣にいた。" },
			]
		"b":
			return [
				{ "speaker": "球磨", "text": "……今日は、ただ川を見てるだけでいいや。" },
				{ "speaker": "", "text": "となりで、同じ流れをぼんやり見ていた。" },
			]
		"c":
			return [
				{ "speaker": "球磨", "text": "……もう、いいよ。ほっといてくれ。" },
				{ "speaker": "", "text": "少しだけ、距離ができた気がした。" },
			]
	return [ { "speaker": "", "text": "川は、今日も静かに流れている。" } ]
