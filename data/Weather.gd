class_name Weather
extends RefCounted
## 天気システム（天気スケジュール設計 ＝ 第9弾）。
##
## 設計思想（設計書より）：
##   - 予報は「明日ぶんだけ」開示（攻略ではなく心の準備）。
##   - 手組みスケジュール（完全ランダムにしない）。物語の山に天気を合わせる。
##   - 予報の当たり外れ（揺らぎ）は入れる。ただし山場は必ず当てる。
##
## データ駆動：40日ぶんの天気を SCHEDULE に手組みで持ち、day_index で引く。
## しきい値・配分・山場は定数。描画（空色・環境音・限定風景）は各シーンが weather を見て切替。
##
## ⚠️ 内部IDは中立名（天気の種類のみ）。葵の二層構造には触れない。

# --- 天気の種類（中立名）---
const CLEAR_MAX := "clear_max"      # 快晴：夏の絶頂
const CLEAR := "clear"              # 晴れ：標準（基調）
const CLOUDY := "cloudy"            # 曇り：迷い・停滞・内省
const RAIN := "rain"                # 雨：静けさ・室内・二人きり
const SHOWER := "shower"            # 夕立：劇的な転換（暗転→土砂降り→晴れ間）
const SUNSET := "sunset"            # 夕焼け（演出）：一日の終わり・郷愁
const FOG := "fog"                  # 霧の朝：世界が知らない場所に見える
const TYPHOON_PRE := "typhoon_pre"  # 台風前：不穏・終わりの予兆（蝉が鳴きやむ）
const TYPHOON := "typhoon"          # 台風：荒天・世界が閉じる

## 40日ぶんの手組みスケジュール（day_index=0 が 8/1）。設計書の代表案に準拠。
## マイルストーンの日付は仮。配置ルール（夕立=葵の初影／台風前=喪失の予兆 等）を保つ範囲で前後可。
## 31日目以降（9/1〜）は追加日：9/1 は「何事もなかったように晴れる残酷さ」で快晴。
const SCHEDULE := [
	CLEAR,       # 8/1  目覚め・夏の始まり
	CLEAR_MAX,   # 8/2  夏の絶頂を早めに一度（後の喪失との落差用）
	CLEAR,       # 8/3
	CLOUDY,      # 8/4  天気が動くことを学習させる
	SHOWER,      # 8/5  ★葵・初対面/初の影（軒下の出会い、晴れ間の翳り）
	CLEAR,       # 8/6  出会いの余韻
	CLEAR_MAX,   # 8/7  夏らしい一日（＝序盤の花火の頃）
	RAIN,        # 8/8  静かな日・二人きりの芽
	CLEAR,       # 8/9
	CLEAR,       # 8/10
	CLOUDY,      # 8/11 迷いの日
	CLEAR,       # 8/12
	CLEAR_MAX,   # 8/13
	CLEAR,       # 8/14
	CLEAR_MAX,   # 8/15
	CLOUDY,      # 8/16
	RAIN,        # 8/17 内省
	CLEAR,       # 8/18
	CLEAR,       # 8/19
	CLEAR_MAX,   # 8/20 ★後半の絶頂（＝祭りの夜の頃）。終わりが近づく前の最後の輝き
	CLEAR,       # 8/21
	CLOUDY,      # 8/22 不穏の兆し
	TYPHOON_PRE, # 8/23 ★喪失・叶わぬ約束の予兆（蝉が鳴きやむ）
	TYPHOON,     # 8/24 荒天・葵の不在/喪失の実感
	FOG,         # 8/25 台風一過。世界が「知らない場所」に見える
	CLEAR,       # 8/26 静かな回復。しかし何かが欠けている
	CLEAR,       # 8/27
	CLEAR_MAX,   # 8/28 最後の夏らしい快晴・惜別の眩しさ
	SUNSET,      # 8/29 終わりが目前・蜩の声・郷愁
	CLOUDY,      # 8/30 最後の夜の前の静けさ・心の準備
	CLEAR,       # 8/31 ★着地（三分岐）。実際の天気はエンドが分岐ごとに決める
	CLEAR_MAX,   # 9/1  ura-end：何事もなかったように晴れる残酷さ
	CLEAR,       # 9/2
	CLEAR,       # 9/3
	CLEAR,       # 9/4
	CLEAR,       # 9/5
	CLEAR,       # 9/6
	CLEAR,       # 9/7
	CLEAR,       # 9/8
	CLEAR,       # 9/9
]

## 山場の日（day_index）。この日の天気は予報を必ず当てる（前日の予報も外さない）。
## ＝設計書「山場の前日は予報を当てる」。特殊天気（夕立/霧/台風/夕焼け）も揺らがせない。
const KEY_DAYS := [4, 20, 22, 23, 24, 28, 30]

## 予報の当たり外れ：日常の予報がこの確率で「1段ズレ」る（山場は対象外）。0-100。
const FORECAST_WOBBLE_PCT := 30
## 揺らぎの対象になる基調天気の並び（明るい→暗いの1軸。±1段でズラす）。
const COMMON_ORDER := [CLEAR_MAX, CLEAR, CLOUDY, RAIN]


## その日の実際の天気（範囲外は末尾でクランプ）。
static func of(day: int) -> String:
	if SCHEDULE.is_empty():
		return CLEAR
	var i := clampi(day, 0, SCHEDULE.size() - 1)
	return String(SCHEDULE[i])


## 「その日の予報」（外れうる）。前日夜/当日朝に“明日ぶん”を見せる用途。
## 山場・特殊天気は必ず当てる。基調天気だけ、seed×day で決まる揺らぎで時々1段ズレる。
static func forecast(day: int, seed: int) -> String:
	var actual := of(day)
	if day in KEY_DAYS or not COMMON_ORDER.has(actual):
		return actual
	var h := absi(hash("%d:%d" % [seed, day]))
	if (h % 100) >= FORECAST_WOBBLE_PCT:
		return actual  # 当たり
	# 外れ：基調の並びで±1段ズラす（端は内側へ折り返す）。
	var idx := COMMON_ORDER.find(actual)
	var dir := 1 if (h / 100) % 2 == 0 else -1
	var j := idx + dir
	if j < 0 or j >= COMMON_ORDER.size():
		j = idx - dir
	return String(COMMON_ORDER[j])


## 予報が当たるか（山場か）。UI で「確度」を出したいとき用。
static func is_key_day(day: int) -> bool:
	return day in KEY_DAYS


## 天気の見た目・音・情緒メタ。
##   name   … 表示名 / icon … 短い記号 / tint … 画面に薄く重ねる色（雰囲気）
##   ambient… 環境音キー（"" = 場所の既定を使う / "silence" = 無音に近づける / それ以外は AudioManager のキー）
static func info(id: String) -> Dictionary:
	match id:
		CLEAR_MAX:
			return { "name": "快晴", "icon": "☀", "tint": Color(1.0, 0.96, 0.80, 0.10), "ambient": "cicada" }
		CLEAR:
			return { "name": "晴れ", "icon": "🌤", "tint": Color(1.0, 1.0, 1.0, 0.0), "ambient": "" }
		CLOUDY:
			return { "name": "曇り", "icon": "☁", "tint": Color(0.74, 0.77, 0.82, 0.24), "ambient": "" }
		RAIN:
			return { "name": "雨", "icon": "☂", "tint": Color(0.42, 0.48, 0.62, 0.34), "ambient": "rain" }
		SHOWER:
			return { "name": "夕立", "icon": "⛈", "tint": Color(0.30, 0.34, 0.46, 0.40), "ambient": "rain" }
		SUNSET:
			return { "name": "夕焼け", "icon": "🌇", "tint": Color(1.0, 0.52, 0.20, 0.32), "ambient": "cicada" }
		FOG:
			return { "name": "霧", "icon": "🌫", "tint": Color(0.90, 0.92, 0.95, 0.40), "ambient": "silence" }
		TYPHOON_PRE:
			return { "name": "台風前", "icon": "🌪", "tint": Color(0.55, 0.58, 0.55, 0.26), "ambient": "silence" }
		TYPHOON:
			return { "name": "台風", "icon": "🌀", "tint": Color(0.34, 0.40, 0.52, 0.46), "ambient": "rain" }
	return { "name": "晴れ", "icon": "🌤", "tint": Color(1, 1, 1, 0.0), "ambient": "" }


static func name_of(id: String) -> String:
	return String(info(id)["name"])


static func icon_of(id: String) -> String:
	return String(info(id)["icon"])
