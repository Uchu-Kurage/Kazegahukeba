class_name Dialogues
extends RefCounted
## 会話データ（当面はここに直書き）。location_id ごとに会話ノードの配列を返す。
##
## ノードは3種類:
##   セリフ : { "speaker": 表示名（""なら地の文）, "text": セリフ }
##   選択肢 : { "text": 質問文(省略可), "choices": [ 選択肢, ... ] }
##     選択肢: { "text": 表示, "affinity": {who: delta}, "set": {flag: true},
##             "stance": "a"/"b"/"c", "then": [ 選んだときに続くノード... ] }
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
