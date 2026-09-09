class_name AoiEncounters
extends RefCounted
## 葵の遭遇テーブル（第9弾 §5-1）。葵は約束を差し出さない＝予定表に載らない存在。
##
## 球磨・由布は「約束を段取る」遊び、葵は「見つける」遊び。特定の日・場所（・天気）に
## 葵がふらりと現れ、その日その場所へ行けたら一度きりの遭遇が起きる。見逃したら再発生
## しない（天気限定風景と同じ“一期一会”の論理）。枠は消費しない（会話の頭に差し込む）。
##
## データ駆動：ALL に条件（day / location / weather 任意）＋台本を持ち、判定は match() だけ。
##   day      … day_index（起点 7/23＝0）。必須。
##   location … spend の location_id（riverside=川原 / shrine=神社 など。葵自身の shop は載せない）。
##   weather  … 省略可。指定すると「その日その場所がその天気のときだけ」会える（§8）。
##   id       … 一度きり判定のフラグ後半（aoi_enc_<id>）。
##
## ⚠️ 二層構造の鉄則：正体・別れを匂わせない。「よく会う、明るい子」として通す（§5）。
## ⚠️ 一人で過ごす場所（home/stroll/meadow）には基本置かない＝記録者エンドの意図を守る。

const PREFIX := "aoi_enc_"


static func all() -> Array:
	return [
		# 夕立の日、川原で。晴れ間に落ちる最初の翳り（天気＝葵の記憶トリガーと整合）。
		{
			"id": "shower_river", "day": 13, "location": "riverside", "weather": Weather.SHOWER,
			"script": [
				{ "speaker": "", "text": "通り雨。橋の下で雨宿りしていると、先客がいた。膝を抱えて、川面を見ている女の子。" },
				{ "speaker": "葵", "text": "あ。きみも雨宿り? ……いいよね、こういうの。世界に、ふたりだけみたいでさ。" },
				{ "speaker": "", "text": "雨はすぐに上がって、葵は「じゃ、またね」と、濡れた石段を跳ねるように上っていった。" },
			],
		},
		# 真夏の快晴、神社の境内で。まぶしさの中の、屈託のない一瞬。
		{
			"id": "clear_shrine", "day": 24, "location": "shrine", "weather": Weather.CLEAR_MAX,
			"script": [
				{ "speaker": "", "text": "蝉時雨の境内。石段の上から、誰かが手を振っている。葵だ。" },
				{ "speaker": "葵", "text": "こんなとこで会うなんて、奇遇だね! ……なんてね。あたし、ほんとにどこにでもいるでしょ。" },
				{ "speaker": "", "text": "ひとしきり笑って、葵は木漏れ日の中へ、すっと紛れていった。" },
			],
		},
		# 台風前の張りつめた空の下、川原で。理由の分からない胸騒ぎ（喪失の予兆と整合）。
		{
			"id": "pre_typhoon_river", "day": 31, "location": "riverside", "weather": Weather.TYPHOON_PRE,
			"script": [
				{ "speaker": "", "text": "風のない、やけに静かな夕方。川原に葵が立って、色を失いかけた空を見上げていた。" },
				{ "speaker": "葵", "text": "……ね。夏って、どうして終わっちゃうんだろうね。" },
				{ "speaker": "", "text": "答えられずにいると、葵はいつもの調子に戻って、「なんてね!」と笑った。それきり、その話はしなかった。" },
			],
		},
	]


static func flag_of(id: String) -> String:
	return PREFIX + id


## 昼の枠で、条件に合う「未見の」遭遇を返す（無ければ {}）。weather を持つ entry は天気一致必須。
static func match(day: int, location_id: String, weather: String, flags: Dictionary) -> Dictionary:
	for e in all():
		if int(e["day"]) != day:
			continue
		if String(e["location"]) != location_id:
			continue
		if e.has("weather") and String(e["weather"]) != weather:
			continue
		if flags.get(flag_of(String(e["id"])), false):
			continue
		return e
	return {}


## この周回で見た遭遇の数（デバッグ用）。
static func seen_count(flags: Dictionary) -> int:
	var n := 0
	for e in all():
		if flags.get(flag_of(String(e["id"])), false):
			n += 1
	return n


static func total() -> int:
	return all().size()
