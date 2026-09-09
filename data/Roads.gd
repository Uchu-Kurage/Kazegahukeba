class_name Roads
extends RefCounted
## 通路シーン（道マップ）の中身（第9弾）。既存10画面の“あいだ”を歩く道の、独白・遭遇を持つ。
##
## 道の役割は「通路・発見・すれ違い」。ここに置くのは「その道でしか会えない/見られない」もの。
## すべて枠非消費（散策の自由を壊さない）。枠を使う本イベントは目的地（既存画面）でのみ。
##   ・独白      … 入場時の一人称。道の性格（町→自然／登り／下流）を、静かに一言。
##   ・遭遇      … キャラの立ち話／すれ違い。1日1回（FieldScene がフラグで制御）。
##   ・風物詩    … WeatherScenes（road_* location）に集約＝既存の図鑑機構へ接続（新規機構は作らない）。
##
## キャラ描き分け（§6）：由布＝計画型（先の約束へ）／球磨＝勢い型（当日〜翌日）／葵＝静かなすれ違い。
## ⚠️ 葵は遭遇型・予定表に載らない・喪失後は現れない・正体を明かさない（§4/§5 厳守）。

const IDS := ["road_a", "road_b", "road_c", "road_d"]

## 葵の喪失フラグ（転換点＝叶わない約束以降、葵は道からも消える）。「誰も覚えていない」を静かに再体現。
const AOI_LOSS_KEY := "turning"


static func is_road(field_id: String) -> bool:
	return field_id in IDS


## 入場時の独白（枠非消費）。天気や喪失で軽く色を変える。無ければ空配列。
static func monologue(road_id: String, state) -> Array:
	match road_id:
		"road_a":
			return [ { "speaker": "", "text": "舗装が途切れて、土の匂いに変わる。町を出て自然へ入るときの、少し心細いような、それでいて開放されるような感じ。" } ]
		"road_b":
			return [ { "speaker": "", "text": "ゆるやかな登りの参道。蝉の声が層になって降ってくる。祭りの舞台へ近づいていく、という気がした。" } ]
		"road_c":
			# 登り・沈黙メイン。喪失後は、そのことにそっと触れる（言葉にしすぎない）。
			if bool(state.flags.get(Routes.flag_of(Routes.AOI, AOI_LOSS_KEY), false)):
				return [ { "speaker": "", "text": "坂をのぼる。以前はこの道で、よく誰かとすれ違った気がする。……気のせいかもしれない。もう、思い出せない。" } ]
			return [ { "speaker": "", "text": "坂をのぼるほど、町が下に開けていく。賑やかさが遠ざかり、自分の足音だけが大きくなる。" } ]
		"road_d":
			return [ { "speaker": "", "text": "川に沿って、下流へ。水は戻らない。この道の先に何があるのか、まだ知らないのに、戻れなさの予感だけがある。" } ]
	return []


## 遭遇（枠非消費・1日1回）。約束が絡む遭遇（由布）は promise 効果を持ち、予定表に記帳される。
## 返り値は Dialogue にそのまま流せるノード列（if_day_free は Story.flatten が state で確定）。
static func encounter(road_id: String, state) -> Array:
	match road_id:
		"road_a":
			# 由布＝計画型。先の日付の約束へつなぐ立ち話（対象日が埋まっていれば自然に引く）。
			return [
				{ "speaker": "由布", "text": "あ……。こんな道で会うなんて、めずらしいね。" },
				{ "if_day_free": 3, "then": [
					{ "speaker": "由布", "text": "ねえ。三日後の夕方、少しだけ時間つくれない？　……見せたい場所が、あるの。" },
					{ "text": "", "choices": [
						{ "text": "「うん、約束する」", "then": [ { "speaker": "由布", "text": "……よかった。じゃあ、ね。指切り、あとでちゃんとしよ。" } ],
							"promise": { "in_days": 3, "character": "yufu", "place": "shrine", "time_of_day": "evening", "flavor": "由布と、見せたい場所へ" } },
						{ "text": "「考えとく」", "then": [ { "speaker": "由布", "text": "……うん。気が向いたら、でいいから。" } ] },
						{ "text": "「その日は、ちょっと」", "then": [ { "speaker": "由布", "text": "ううん、いいの。忘れて。……また、別の日にね。" } ] },
					] },
				], "else": [
					{ "speaker": "由布", "text": "三日後は……もう、予定があるみたいね。ふふ、いいの。また今度、誘わせて。" },
				] },
			]
		"road_b":
			# 球磨＝勢い型。祭りへの誘いの立ち話（約束帳は絡めない＝軽いノリ）。
			return [
				{ "speaker": "球磨", "text": "お、いいとこで会った。なあ、今年の祭り、行くよな？　当たり前だよな？" },
				{ "speaker": "球磨", "text": "屋台まわって、花火見て……夜まで付き合えよ。じゃ、また後でな！" },
			]
		"road_c":
			# 葵＝静かなすれ違い。喪失後は現れない（＝誰も覚えていない）。関わりの総量には数える。
			if bool(state.flags.get(Routes.flag_of(Routes.AOI, AOI_LOSS_KEY), false)):
				return []
			return [
				{ "speaker": "葵", "text": "……あ。" },
				{ "speaker": "葵", "text": "ううん、なんでもない。……この坂の上、いいよね。ぜんぶ見えて。" },
				{ "speaker": "", "text": "葵はそれだけ言って、坂の上のほうへ、先に行ってしまった。追いつこうとして、やめた。" },
				{ "effect": { "count": { "aoi_ambient": 1 } } },
			]
		"road_d":
			# 球磨＝河口（精神的ゴール）へ向かう道。並んで歩く、少し先の自分たちの話。
			return [
				{ "speaker": "球磨", "text": "よお。……河口まで行くのか。おれも、たまに来るんだ、ここ。" },
				{ "speaker": "球磨", "text": "海までは、まだ遠い。……でも、いつか、ほんとに行こうぜ。二人でさ。" },
			]
	return []
