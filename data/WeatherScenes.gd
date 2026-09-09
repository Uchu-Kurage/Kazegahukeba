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

## 風物詩図鑑の表示メタ（id → [題名, 条件のヒント]）。台本データは触らずここに集約。
const META := {
	"shimmer_shops": ["陽炎", "快晴の商店街で"],
	"rainbow_hill": ["虹", "夕立の日、丘で"],
	"rain_river": ["雨の川面", "雨の日、河原で"],
	"hush_paddies": ["凪いだ田んぼ", "台風前の田んぼで"],
	"fog_paddies": ["霧の田んぼ", "霧の朝、田んぼで"],
	"dusk_hill": ["夕焼けの町", "夕焼けの丘で"],
	"milkyway_festival": ["天の川", "祭りの夜（快晴）"],
	"stars_clear_night": ["満天の星", "快晴の夜、就寝前"],
	"typhoon_night": ["台風の夜", "台風の夜、就寝前"],
	# 通路シーン（道マップ）の風物詩（第9弾）。基本セット＝常設・再閲覧可／一品＝一期一会。
	"road_a_higanbana": ["ヒガンバナ", "畦道への道で"],
	"road_a_kakashi": ["案山子", "畦道への道で"],
	"road_a_puddle": ["夕立あとの水たまり", "雨の日、畦道への道で"],
	"road_b_toro": ["参道の灯籠", "祭りへの参道で"],
	"road_b_moss": ["参道の苔", "祭りへの参道で"],
	"road_b_lanterns": ["祭りの提灯", "祭りの日、参道で"],
	"road_c_farview": ["町の遠景", "丘への坂道で"],
	"road_c_thunderhead": ["入道雲", "丘への坂道で"],
	"road_c_afterglow": ["坂の上の夕焼け", "夕焼けの日、丘への坂道で"],
	"road_d_stream": ["流れる水", "川沿いの道で"],
	"road_d_driftwood": ["流木", "川沿いの道で"],
	"road_d_glitter": ["川面のきらめき", "快晴の昼、川沿いの道で"],
}


static func all() -> Array:
	return [
		{
			"id": "shimmer_shops", "day": 10, "location": "stroll", "weather": Weather.CLEAR_MAX,
			"script": [
				{ "speaker": "", "text": "商店街のアスファルトが、陽炎でゆらいでいる。" },
				{ "speaker": "", "text": "何もかもが白くまぶしくて、夏のいちばん濃いところに立っている気がした。" },
			],
		},
		{
			"id": "rainbow_hill", "day": 13, "location": "hill", "weather": Weather.SHOWER,
			"script": [
				{ "speaker": "", "text": "通り雨が上がって、雲の切れ間から日が差した。" },
				{ "speaker": "", "text": "町の向こうに、うすい虹がかかっている。ほんの少しの間だけ。" },
				{ "speaker": "", "text": "見とれているうちに、それは溶けるように消えてしまった。" },
			],
		},
		{
			"id": "rain_river", "day": 16, "location": "riverside", "weather": Weather.RAIN,
			"script": [
				{ "speaker": "", "text": "雨の河原。川面に無数の輪ができては、重なって消えていく。" },
				{ "speaker": "", "text": "雨の音のほかは、何も聞こえない。世界が少しだけ、狭くなったみたいだ。" },
			],
		},
		{
			"id": "hush_paddies", "day": 31, "location": "meadow", "weather": Weather.TYPHOON_PRE,
			"script": [
				{ "speaker": "", "text": "田んぼの上の空が、やけに張りつめている。" },
				{ "speaker": "", "text": "いつのまにか、蝉が鳴きやんでいた。稲だけが、風のこない中で静かに揺れている。" },
				{ "speaker": "", "text": "何かが終わろうとしている――そんな気配だけが、そこにあった。" },
			],
		},
		{
			"id": "fog_paddies", "day": 33, "location": "meadow", "weather": Weather.FOG,
			"script": [
				{ "speaker": "", "text": "台風が去った朝。田んぼが、白い霧に沈んでいた。" },
				{ "speaker": "", "text": "見慣れたはずの畦道が、知らない場所みたいに続いている。" },
				{ "speaker": "", "text": "霧の中を歩いていると、自分がどこにいるのか、分からなくなりそうだった。" },
			],
		},
		{
			"id": "dusk_hill", "day": 37, "location": "hill", "weather": Weather.SUNSET,
			"script": [
				{ "speaker": "", "text": "丘の上から、町ぜんぶが夕焼けに染まっていくのを見ていた。" },
				{ "speaker": "", "text": "屋根も、川も、田んぼも、みんなオレンジ色。どこかで、蜩が鳴きはじめる。" },
				{ "speaker": "", "text": "この景色を、いつか、たまらなく思い出すんだろうな、と思った。" },
			],
		},

		# --- 夜の限定風景（time:"night"）---
		# 特別な夜：event に夜イベントID。天気が合うと、その夜の台本の頭に一度だけ差し込む。
		{
			"id": "milkyway_festival", "time": "night", "event": "festival", "weather": Weather.CLEAR_MAX, "discover": "amanogawa",
			"script": [
				{ "speaker": "", "text": "屋台の灯りを離れて空を見上げると、澄んだ夜空に、天の川がくっきりと流れていた。" },
				{ "speaker": "", "text": "こんなに星が多いなんて、と思う。祭りのざわめきが、急に遠く聞こえた。" },
			],
		},
		# 通常の就寝前：event "sleep"。日付は問わず、その天気で寝た初回に一度だけ。
		{
			"id": "stars_clear_night", "time": "night", "event": "sleep", "weather": Weather.CLEAR_MAX,
			"script": [
				{ "speaker": "", "text": "眠る前に、窓を開けた。快晴の夜空に、数えきれないほどの星が散らばっている。" },
				{ "speaker": "", "text": "こんな夜が、あと何回あるんだろう。そう思いながら、しばらく見上げていた。" },
			],
		},
		{
			"id": "typhoon_night", "time": "night", "event": "sleep", "day": 32, "weather": Weather.TYPHOON,
			"script": [
				{ "speaker": "", "text": "雨戸を、風が叩いている。台風の夜。町ぜんぶが、雨と風の音に沈んでいた。" },
				{ "speaker": "", "text": "布団の中で、その音を聞いていた。明日、世界はどうなっているんだろう。" },
			],
		},
	]


## 通路シーン（道マップ）の風物詩（第9弾）。location に road_* を持ち、図鑑にもそのまま載る。
##   standing:true … 基本セット（常設・再閲覧可）。拾っても道の風景として残る（match では自動発火しない）。
##   weather/day    … 見逃せる一品（一期一会）。その条件の日にだけ道の入場で一度きり差し込む。
## pos は道の上のホットスポット位置（基本セットの調べどころ）。背景差し替え時に微調整可。
static func roads() -> Array:
	return [
		# road_a：商店街⇔田んぼ（畦道への道）。
		{ "id": "road_a_higanbana", "location": "road_a", "standing": true, "pos": Vector2(250, 380),
			"script": [ { "speaker": "", "text": "畦のふちに、ヒガンバナが一列。燃えるような赤が、青い田をいっそう青く見せている。" } ] },
		{ "id": "road_a_kakashi", "location": "road_a", "standing": true, "pos": Vector2(760, 380),
			"script": [ { "speaker": "", "text": "古びた案山子が一本。片腕が下がって、こちらに手を振っているようにも見えた。" } ] },
		{ "id": "road_a_puddle", "location": "road_a", "weather": Weather.RAIN, "pos": Vector2(520, 392),
			"script": [
				{ "speaker": "", "text": "雨あがりの畦道。轍のくぼみに、小さな水たまり。そこにだけ、切り取ったように青空が映っていた。" },
				{ "speaker": "", "text": "覗き込むと、逆さまの雲がゆっくり流れていく。踏むのが惜しくて、そっとよけて通った。" },
			] },
		# road_b：田んぼ⇔神社（祭りへの参道）。
		{ "id": "road_b_toro", "location": "road_b", "standing": true, "pos": Vector2(576, 250),
			"script": [ { "speaker": "", "text": "鳥居の手前に、石の灯籠が二基。苔むした笠に、木漏れ日がちらちらと落ちている。" } ] },
		{ "id": "road_b_moss", "location": "road_b", "standing": true, "pos": Vector2(576, 470),
			"script": [ { "speaker": "", "text": "参道の敷石の目地に、深い緑の苔。ふかふかとして、夏の湿り気をぜんぶ吸っているみたいだ。" } ] },
		{ "id": "road_b_lanterns", "location": "road_b", "day": 28, "pos": Vector2(576, 350),
			"script": [
				{ "speaker": "", "text": "参道の両脇に、提灯がずらりと吊るされていた。まだ日は高いのに、もう祭りの気配で満ちている。" },
				{ "speaker": "", "text": "夜になれば、この道はぜんぶ、あたたかな橙色に灯るのだろう。" },
			] },
		# road_c：神社⇔丘（丘への坂道。葵の道）。
		{ "id": "road_c_farview", "location": "road_c", "standing": true, "pos": Vector2(576, 220),
			"script": [ { "speaker": "", "text": "坂の途中で振り返ると、町がぜんぶ、足の下に開けていた。屋根の海が、白い光の底に沈んでいる。" } ] },
		{ "id": "road_c_thunderhead", "location": "road_c", "standing": true, "pos": Vector2(576, 440),
			"script": [ { "speaker": "", "text": "坂の上の空に、入道雲がひとつ。まぶしいほど白く盛り上がって、まるで夏そのものみたいだった。" } ] },
		{ "id": "road_c_afterglow", "location": "road_c", "weather": Weather.SUNSET, "pos": Vector2(576, 320),
			"script": [
				{ "speaker": "", "text": "坂を登りきるころ、空がゆっくりと燃えはじめた。町も、川も、田んぼも、みんな橙色に。" },
				{ "speaker": "", "text": "この坂の先の丘で、いつか、この夕焼けを誰かと見るのかもしれない。ふと、そんな気がした。" },
			] },
		# road_d：河原⇔河口（川沿いの道。下流へ）。
		{ "id": "road_d_stream", "location": "road_d", "standing": true, "pos": Vector2(300, 380),
			"script": [ { "speaker": "", "text": "川は、ただ静かに下流へ流れていく。戻ることのない水を、しばらく目で追った。" } ] },
		{ "id": "road_d_driftwood", "location": "road_d", "standing": true, "pos": Vector2(820, 380),
			"script": [ { "speaker": "", "text": "白くさらされた流木が、岸に打ち上げられていた。どこから来て、どこへ行くはずだったんだろう。" } ] },
		{ "id": "road_d_glitter", "location": "road_d", "weather": Weather.CLEAR_MAX, "pos": Vector2(560, 392),
			"script": [
				{ "speaker": "", "text": "真昼の川面が、数えきれないほどの光の粒でざわめいている。まぶしくて、目を細めた。" },
				{ "speaker": "", "text": "この一瞬のきらめきは、たぶん、二度と同じ形では見られない。" },
			] },
	]


## 道マップの、その場所の「基本セット（常設）」風物詩を返す（FieldScene がホットスポット化する）。
static func standing_at(location_id: String) -> Array:
	var out: Array = []
	for e in roads():
		if String(e.get("location", "")) == location_id and e.get("standing", false):
			out.append(e)
	return out


static func flag_of(id: String) -> String:
	return PREFIX + id


## flag 名（wscene_xxx）から風物詩 id を取り出す（cross-run 記録のフックで使う）。
static func id_from_flag(flag_name: String) -> String:
	return flag_name.trim_prefix(PREFIX) if flag_name.begins_with(PREFIX) else ""


## 全風物詩の id（図鑑の並び順＝既存画面→道マップの順）。道マップの風物詩も同じ図鑑に載る。
static func ids() -> Array:
	var out: Array = []
	for e in all():
		out.append(String(e["id"]))
	for e in roads():
		out.append(String(e["id"]))
	return out


## 図鑑用：題名と条件ヒント。
static func title_of(id: String) -> String:
	return String(META.get(id, [id, ""])[0])


static func hint_of(id: String) -> String:
	return String(META.get(id, [id, ""])[1])


## 昼の枠：条件に合う「未見の」情景を返す（無ければ {}）。既存画面＋道マップの一品を対象にする。
## day を持つ entry は day 一致必須。weather を持つ entry は天気一致必須（道の day 限定は weather 無し可）。
## standing（道の基本セット・常設）は自動発火しないので対象外。
static func match(day: int, location_id: String, weather: String, flags: Dictionary) -> Dictionary:
	var pool: Array = all()
	pool.append_array(roads())
	for e in pool:
		if String(e.get("time", "day")) != "day":
			continue
		if e.get("standing", false):
			continue
		if String(e.get("location", "")) != location_id:
			continue
		if e.has("weather") and String(e["weather"]) != weather:
			continue
		if e.has("day") and int(e["day"]) != day:
			continue
		if flags.get(flag_of(String(e["id"])), false):
			continue
		return e
	return {}


## 夜：条件に合う「未見の」夜の情景を返す（無ければ {}）。
## event は夜イベントID（"festival" 等）／通常の就寝前は "sleep"。day を持つ entry は day 一致必須。
static func night_match(day: int, weather: String, event: String, flags: Dictionary) -> Dictionary:
	for e in all():
		if String(e.get("time", "day")) != "night":
			continue
		if String(e.get("event", "")) != event:
			continue
		if String(e["weather"]) != weather:
			continue
		if e.has("day") and int(e["day"]) != day:
			continue
		if flags.get(flag_of(String(e["id"])), false):
			continue
		return e
	return {}


## この周回で見た限定風景の数（図鑑・デバッグ用）。既存画面＋道マップ。
static func seen_count(flags: Dictionary) -> int:
	var n := 0
	for id in ids():
		if flags.get(flag_of(id), false):
			n += 1
	return n


static func total() -> int:
	return ids().size()
