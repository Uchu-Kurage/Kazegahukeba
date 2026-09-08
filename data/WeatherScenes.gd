class_name WeatherScenes
extends RefCounted
## 天気限定風景（天気スケジュール設計 §見逃せる）。
##
## 「その天気 × その場所 × その日」に一度だけ現れる情景。見逃したら二度と見られない（＝切なさが主眼）。
## 進行フラグ（wscene_<id>）で一度きり。フラグは周回で消えるので、次の夏にまた挑戦できる。
##
## データ駆動：ALL に条件（day / location / weather）＋台本を持ち、判定は match() だけ。
##   day を指定すると「その日限り」（虹など）。day を省くと「その天気×その場所」の初回一回。
##   location は spend の location_id（riverside=河原 / shrine=神社 / shop=ひまわり /
##   home / meadow=田んぼ / stroll=商店街 / hill=丘 / school）。weather は Weather.* の種類。
##
## ⚠️ 情景は中立に。葵の二層構造（正体）には触れない。テキストは仮置き。

const PREFIX := "wscene_"


static func all() -> Array:
	return [
		{
			"id": "shimmer_shops", "day": 1, "location": "stroll", "weather": Weather.CLEAR_MAX,
			"script": [
				{ "speaker": "", "text": "商店街のアスファルトが、陽炎でゆらいでいる。" },
				{ "speaker": "", "text": "何もかもが白くまぶしくて、夏のいちばん濃いところに立っている気がした。" },
			],
		},
		{
			"id": "rainbow_hill", "day": 4, "location": "hill", "weather": Weather.SHOWER,
			"script": [
				{ "speaker": "", "text": "通り雨が上がって、雲の切れ間から日が差した。" },
				{ "speaker": "", "text": "町の向こうに、うすい虹がかかっている。ほんの少しの間だけ。" },
				{ "speaker": "", "text": "見とれているうちに、それは溶けるように消えてしまった。" },
			],
		},
		{
			"id": "rain_river", "day": 7, "location": "riverside", "weather": Weather.RAIN,
			"script": [
				{ "speaker": "", "text": "雨の河原。川面に無数の輪ができては、重なって消えていく。" },
				{ "speaker": "", "text": "雨の音のほかは、何も聞こえない。世界が少しだけ、狭くなったみたいだ。" },
			],
		},
		{
			"id": "hush_paddies", "day": 22, "location": "meadow", "weather": Weather.TYPHOON_PRE,
			"script": [
				{ "speaker": "", "text": "田んぼの上の空が、やけに張りつめている。" },
				{ "speaker": "", "text": "いつのまにか、蝉が鳴きやんでいた。稲だけが、風のこない中で静かに揺れている。" },
				{ "speaker": "", "text": "何かが終わろうとしている――そんな気配だけが、そこにあった。" },
			],
		},
		{
			"id": "fog_paddies", "day": 24, "location": "meadow", "weather": Weather.FOG,
			"script": [
				{ "speaker": "", "text": "台風が去った朝。田んぼが、白い霧に沈んでいた。" },
				{ "speaker": "", "text": "見慣れたはずの畦道が、知らない場所みたいに続いている。" },
				{ "speaker": "", "text": "霧の中を歩いていると、自分がどこにいるのか、分からなくなりそうだった。" },
			],
		},
		{
			"id": "dusk_hill", "day": 28, "location": "hill", "weather": Weather.SUNSET,
			"script": [
				{ "speaker": "", "text": "丘の上から、町ぜんぶが夕焼けに染まっていくのを見ていた。" },
				{ "speaker": "", "text": "屋根も、川も、田んぼも、みんなオレンジ色。どこかで、蜩が鳴きはじめる。" },
				{ "speaker": "", "text": "この景色を、いつか、たまらなく思い出すんだろうな、と思った。" },
			],
		},
	]


static func flag_of(id: String) -> String:
	return PREFIX + id


## 条件に合う「未見の」情景を返す（無ければ {}）。day を持つ entry は day 一致が必須。
static func match(day: int, location_id: String, weather: String, flags: Dictionary) -> Dictionary:
	for e in all():
		if String(e["location"]) != location_id:
			continue
		if String(e["weather"]) != weather:
			continue
		if e.has("day") and int(e["day"]) != day:
			continue
		if flags.get(flag_of(String(e["id"])), false):
			continue
		return e
	return {}


## この周回で見た限定風景の数（図鑑・デバッグ用）。
static func seen_count(flags: Dictionary) -> int:
	var n := 0
	for e in all():
		if flags.get(flag_of(String(e["id"])), false):
			n += 1
	return n


static func total() -> int:
	return all().size()
