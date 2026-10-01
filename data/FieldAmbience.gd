class_name FieldAmbience
extends RefCounted
## 散策画面の「背景の上の動き」（環境演出）の配置データ。AmbientFX が読んで描く。
##
## 背景は一枚絵（静止画）なので、その上に小さな動き＝水面のきらめき・流れる雲の影・トンボ・チョウ・
## 舞う葉・木漏れ日の光の筋・夜の蛍を重ね、画面が「その場で息をしている」ように見せる。
## 絵（assets/field/<id>.png）を差し替えたら、ここの範囲（Rect2。1152×648 の画面座標）も合わせて直す。
## 当たり判定・進行には一切関与しない純粋な演出（コードで描くので素材のライセンスも不要）。
##
## 種類（kind）と、使う項目：
##   "glint"        … 水面のきらめき。rects＝水面の範囲。density＝1万px²あたりの粒数（目安 1.5〜2.5）
##   "cloud_shadow" … 地面を横切る雲の影。rect＝影を落とす地面の範囲（はみ出しは切り取る）
##   "dragonfly"    … トンボ。rect＝飛ぶ範囲、count＝匹数
##   "butterfly"    … チョウ（白・黄）。rect＝舞う範囲、count＝匹数
##   "leaves"       … 舞い落ちる葉。rect＝葉が生まれる範囲（木の茂み）、floor＝消える高さ（地面の Y）、count＝枚数
##   "light"        … 木漏れ日の光の筋（斜めの帯）と、その中を漂う塵。rect＝光が差す範囲
##   "fireflies"    … 夜の蛍（夜だけ出る）。rect＝漂う範囲、count＝匹数
##
## 出し分け（AmbientFX 側で判定）：
##   ・雨・夕立・台風の日 … 何も出さない（雨脚の演出に任せる）
##   ・曇り・霧・台風前・夕焼け … 日差しが要る演出（glint / cloud_shadow / light）は出さない
##   ・夜 … fireflies だけ出す（昼の演出は出さない）

## 演出の層。地面の層はキャラの後ろ（背景の直上）、空の層はキャラの手前に描く。
const GROUND_KINDS := ["glint", "cloud_shadow"]

## 晴れ以外で「日差しが要る演出」を消す天気。
const NO_SUN_WEATHERS := [Weather.CLOUDY, Weather.FOG, Weather.TYPHOON_PRE, Weather.SUNSET]
## 演出を何も出さない天気（雨脚の演出に任せる）。
const WET_WEATHERS := [Weather.RAIN, Weather.SHOWER, Weather.TYPHOON]


## 画面ID → 演出の一覧（無ければ空配列）。
static func of(field_id: String) -> Array:
	match field_id:
		"riverbank":
			return [
				{ "kind": "glint", "rects": [Rect2(620, 338, 532, 82), Rect2(950, 420, 202, 70)], "density": 2.2 },
				{ "kind": "cloud_shadow", "rect": Rect2(0, 318, 1152, 330) },
				{ "kind": "dragonfly", "rect": Rect2(120, 260, 760, 260), "count": 3 },
				{ "kind": "fireflies", "rect": Rect2(60, 300, 1000, 300), "count": 22 },
			]
		"estuary":
			return [
				{ "kind": "glint", "rects": [Rect2(0, 330, 520, 60), Rect2(0, 400, 400, 230), Rect2(720, 300, 432, 50)], "density": 1.4 },
				{ "kind": "dragonfly", "rect": Rect2(200, 240, 700, 220), "count": 2 },
			]
		"fields":
			return [
				{ "kind": "glint", "rects": [Rect2(0, 425, 470, 80), Rect2(650, 445, 502, 200), Rect2(690, 378, 310, 26)], "density": 2.0 },
				{ "kind": "cloud_shadow", "rect": Rect2(0, 340, 1152, 308) },
				{ "kind": "dragonfly", "rect": Rect2(60, 230, 1020, 300), "count": 4 },
				{ "kind": "fireflies", "rect": Rect2(0, 330, 1152, 300), "count": 26 },
			]
		"sunflower":
			return [
				{ "kind": "cloud_shadow", "rect": Rect2(0, 180, 1152, 468) },
				{ "kind": "butterfly", "rect": Rect2(40, 160, 1060, 300), "count": 3 },
				{ "kind": "dragonfly", "rect": Rect2(100, 120, 900, 200), "count": 1 },
			]
		"hill":
			return [
				{ "kind": "glint", "rects": [Rect2(860, 410, 260, 70)], "density": 1.5 },
				{ "kind": "cloud_shadow", "rect": Rect2(0, 300, 1152, 348) },
				{ "kind": "leaves", "rect": Rect2(150, 90, 340, 230), "floor": 600.0, "count": 6 },
				{ "kind": "butterfly", "rect": Rect2(60, 420, 600, 180), "count": 1 },
				{ "kind": "dragonfly", "rect": Rect2(520, 160, 560, 260), "count": 2 },
			]
		"shrine":
			return [
				{ "kind": "light", "rect": Rect2(140, 0, 700, 600) },
				{ "kind": "leaves", "rect": Rect2(0, 0, 1152, 160), "floor": 640.0, "count": 8 },
			]
		# 家＝自室：窓から差しこむ光の筋と、その中を漂う塵（晴れの日だけ）。
		"home":
			return [
				{ "kind": "light", "rect": Rect2(500, 168, 240, 300) },
			]
		"school":
			return [
				{ "kind": "cloud_shadow", "rect": Rect2(0, 420, 1152, 228) },
				{ "kind": "dragonfly", "rect": Rect2(80, 380, 1000, 200), "count": 2 },
			]
		"shops":
			return [
				{ "kind": "cloud_shadow", "rect": Rect2(0, 190, 1152, 458) },  # 空は避け、家並みと通りに
			]
		# 道（road_*）：タイルで組んだ見下ろしの絵（tools/gen_road_tiles.py）に合わせた範囲。
		"road_a":
			return [
				{ "kind": "cloud_shadow", "rect": Rect2(0, 0, 1152, 648) },
				{ "kind": "dragonfly", "rect": Rect2(100, 120, 950, 360), "count": 2 },
				{ "kind": "butterfly", "rect": Rect2(440, 440, 680, 180), "count": 2 },
			]
		"road_b":
			return [
				{ "kind": "leaves", "rect": Rect2(0, 0, 1152, 200), "floor": 640.0, "count": 8 },
				{ "kind": "dragonfly", "rect": Rect2(380, 100, 400, 420), "count": 1 },
			]
		"road_c":
			return [
				{ "kind": "cloud_shadow", "rect": Rect2(0, 0, 1152, 648) },
				{ "kind": "leaves", "rect": Rect2(30, 0, 420, 300), "floor": 640.0, "count": 5 },
				{ "kind": "butterfly", "rect": Rect2(700, 60, 420, 520), "count": 2 },
				{ "kind": "dragonfly", "rect": Rect2(420, 80, 600, 400), "count": 2 },
			]
		"road_d":
			return [
				{ "kind": "glint", "rects": [Rect2(0, 530, 1152, 118)], "density": 2.0 },
				{ "kind": "cloud_shadow", "rect": Rect2(0, 0, 1152, 648) },
				{ "kind": "dragonfly", "rect": Rect2(60, 260, 1020, 280), "count": 3 },
				{ "kind": "fireflies", "rect": Rect2(0, 420, 1152, 200), "count": 20 },
			]
	return []
