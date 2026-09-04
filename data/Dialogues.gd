class_name Dialogues
extends RefCounted
## 会話データ（当面はここに直書き）。location_id ごとに会話ノードの配列を返す。
##
## ノードは3種類:
##   セリフ : { "speaker": 表示名（""なら地の文）, "text": セリフ }
##   選択肢 : { "text": 質問文(省略可), "choices": [ 選択肢, ... ] }
##     選択肢: { "text": 表示, "affinity": {who: delta}, "set": {flag: true},
##             "stance": GameState.KumaStance の値, "then": [ 選んだときに続くノード... ] }
##   効果   : { "effect": { "set": {...}, "affinity": {...} } }（表示せず状態だけ反映）
##
## 球磨（川原）はイベント表 KumaStory に載せ替えた。日付・前提フラグで“次の1件”が進む。
## 他キャラ（夏・由布）は当面その場の固定台本（後で状態分岐に広げる）。

const PLAYER := "ぼく"  # 主人公の仮の呼び名


static func for_location(location_id: String) -> Array:
	match location_id:
		"riverside":
			# 球磨ルートはイベント表が返す（球磨の枠を選んだときだけ物語が進む）。
			return KumaStory.script_for(GameState)
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


## 球磨ルートの節目イベントの台本。KumaStory がイベント id をキーに引く。
## （イベントの「条件」は KumaStory 側のデータ、「台本」はここ、と分離している）
static func kuma_script(key: String) -> Array:
	match key:
		"kuma_dream":  # 出会い直し＋夢を語る
			return [
				{ "speaker": "", "text": "いつもの川原。球磨が石に腰かけて、川下のほうを見ている。" },
				{ "speaker": "球磨", "text": "よう。今年もこの夏が来たな。" },
				{ "speaker": PLAYER, "text": "……ああ。" },
				{ "speaker": "球磨", "text": "俺さ、いつか外で、でっかいことをやるんだ。未来なんて、まだいくらでもあるだろ。" },
				{ "speaker": "", "text": "その未来が来ないことを、ぼくだけが知っている。" },
			]
		"kuma_promise":  # 子供時代の河口の約束（伏線）
			return [
				{ "speaker": "球磨", "text": "覚えてるか？　ガキの頃、この川の先の海まで行こうって約束したよな。" },
				{ "speaker": "球磨", "text": "あんときは途中で引き返した。……大人になったら、あの先まで行こうな。" },
				{ "speaker": "", "text": "川は、河口で海へ出る。球磨の名前と、同じように。" },
			]
		"kuma_filler":  # 節目が無い日の、球磨との何気ない時間
			return [
				{ "speaker": "球磨", "text": "……今日は、ただ川を見てるだけでいいや。" },
				{ "speaker": "", "text": "となりで、同じ流れをぼんやり見ていた。" },
			]
	return []
