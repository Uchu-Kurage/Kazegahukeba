class_name Dialogues
extends RefCounted
## 会話データ（当面はここに直書き）。location_id ごとにセリフ行の配列を返す。
##
## 各行: { "speaker": 表示名（"" なら地の文）, "text": セリフ }
## 物語を作り込む段階で、日付や好感度・フラグで分岐させていく想定（引数を足せばよい）。

const PLAYER := "ぼく"  # 主人公の仮の呼び名


static func for_location(location_id: String) -> Array:
	match location_id:
		"riverside":
			return [
				{ "speaker": "", "text": "川の音がする。球磨がいつもの石に腰かけている。" },
				{ "speaker": "球磨", "text": "よう。今年もこの夏が来たな。" },
				{ "speaker": PLAYER, "text": "……ああ。" },
				{ "speaker": "球磨", "text": "なあ、来年も、再来年も、こうやってここに来ようぜ。" },
				{ "speaker": "", "text": "その“来年”が来ないことを、ぼくだけが知っている。" },
			]
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
				{ "speaker": PLAYER, "text": "……どっちも、かな。" },
				{ "speaker": "由布", "text": "じゃあ、隣、座ってけば。" },
			]
		_:
			return [
				{ "speaker": "", "text": "家に戻ると、扇風機の音だけが回っている。" },
				{ "speaker": PLAYER, "text": "……少し、休もう。" },
				{ "speaker": "", "text": "何もしない時間も、この夏の一部だ。" },
			]
