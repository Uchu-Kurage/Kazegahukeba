class_name UITheme
extends RefCounted
## UIの見た目を一箇所に集約するテーマ（実装指示 第7弾／見た目の改善で調整）。
##
## 目指すのは「夏に溶けるUI」＝和紙／すりガラスの半透明・角丸・やわらかい縁、
## 文字は暖かいダークグレー（白抜きにしない）、差し色は夏空の青。
## 色・不透明度・角丸・フォント・差し色はすべてここに置き、各所で直書きしない（§7）。
##
## 使い分け：
##   ・washi()  … 世界の上に浮く小さな和紙（会話枠・話者名・日めくり・操作プロンプト）。少し透ける。
##   ・page()   … 一覧を読ませる帳面（予定表・風物詩・かばん）。ほぼ不透明にして中身を読ませる。
##   ・ruled()  … 帳面の罫線マス（カードを並べず、紙に引いた罫で区切る）。

# --- 和紙（メッセージ枠・話者名タグ・選択肢・日めくり 共通の下地）---
const WASHI := Color("f5f0e6")        # 生成り〜クリーム白（純白は避ける）
const WASHI_ALPHA := 0.92             # 半透明（背景がほんのり透ける）
const PAGE_ALPHA := 0.97              # 帳面（一覧を読ませる面）はほぼ不透明
const CORNER := 16                    # 角丸（やわらかめ）
const BORDER := Color("cbbfa6")       # ごく薄い和紙の縁（くっきりした境界にしない）
const BORDER_ALPHA := 0.6
const SHADOW := Color(0.16, 0.13, 0.08, 0.20)  # 影でふわっと浮かせる（黒ではなく土の色）
const RULE := Color("dcd2bd")         # 帳面の罫線（鉛筆で引いたくらいの薄さ）

# --- 文字（本文・話者名・選択肢・日めくり 共通）---
const TEXT := Color("33302b")             # 暖かいダークグレー（墨。純黒は避ける）
const TEXT_SOFT := Color("6b6357")        # 補足（操作説明・過ぎた日・注記）。和紙の上で 5.2:1
const TEXT_OUTLINE := Color(1, 1, 1, 0.6) # 世界の上に直接置く文字だけの、明るい薄い縁取り
const OUTLINE_SIZE := 4

# --- 差し色（夏空の青。選択中・強調に絞って使う）---
const ACCENT := Color("5ba3d0")
const ACCENT_ALPHA := 0.80
const ACCENT_LINE := Color("3a82b3")      # 選択の縁・送りの▼など「線や記号」の青。和紙の上で 3.7:1（非テキストの基準 3:1）
const ACCENT_INK := Color("2a6d99")       # 紙の上に「文字」として置く青。和紙の上で 4.9:1（本文の基準 4.5:1）
const SUNDAY := Color("b23a31")           # 日めくり・暦の日曜（朱）。和紙の上で 5.2:1

# --- 文字サイズ（サイズで階層をつける。フォントは統一）---
const SIZE_DATE := 52   # 日めくりの日付数字（画面でいちばん大きい文字）
const SIZE_BODY := 28
const SIZE_NAME := 24
const SIZE_CHOICE := 24
const SIZE_HINT := 22
const SIZE_DAY := 24
const SIZE_SMALL := 18

## 丸ゴシックのフォント。project.godot の既定フォント（ui_font.tres）と同じもの＝
## M PLUS Rounded 1c（assets/fonts/rounded.ttf）を主に、収録外の字は Noto Sans JP で補う。
const ROUNDED_FONT_PATH := "res://assets/fonts/ui_font.tres"


## 和紙の下地スタイル（枠・タグ・ボタン共通）。角丸・半透明・薄い縁・やわらかい影。
static func washi(corner: int = CORNER, alpha: float = WASHI_ALPHA) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := WASHI
	c.a = alpha
	sb.bg_color = c
	sb.set_corner_radius_all(corner)
	var b := BORDER
	b.a = BORDER_ALPHA
	sb.border_color = b
	sb.set_border_width_all(1)
	sb.shadow_color = SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 3)
	return sb


## 帳面の下地（予定表・風物詩・かばん）。中身を読ませるため、ほぼ不透明。
static func page(corner: int = 20) -> StyleBoxFlat:
	var sb := washi(corner, PAGE_ALPHA)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 6)
	return sb


## 帳面の罫線マス。地は塗らず、右と下にだけ薄い罫を引く（カードを並べない）。
static func ruled() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = RULE
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	return sb


## 罫線マスのうち「いま選んでいる」もの。夏空の青で囲む（塗りはごく薄く）。
static func ruled_cursor() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := ACCENT
	c.a = 0.14
	sb.bg_color = c
	sb.border_color = ACCENT_LINE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	return sb


## 選択中の下地（夏空の青の和紙）。差し色は「今選んでいる項目」に絞る。
static func accent(corner: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c := ACCENT
	c.a = ACCENT_ALPHA
	sb.bg_color = c
	sb.set_corner_radius_all(corner)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## 選択肢の「選んでいる」下地。和紙はそのまま、縁を夏空の青で太く囲む（文字は墨のまま読める）。
static func chip_selected(corner: int = 10) -> StyleBoxFlat:
	var sb := washi(corner, 0.97)
	sb.border_color = ACCENT_LINE
	sb.set_border_width_all(3)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## 未選択の選択肢の下地（和紙。世界の上でも文字が読める濃さ）。
static func chip(corner: int = 10) -> StyleBoxFlat:
	var sb := washi(corner, 0.82)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## 丸ゴシックのフォント（未設置なら null＝プロジェクト既定フォントのまま）。
static func font() -> Font:
	if ResourceLoader.exists(ROUNDED_FONT_PATH):
		return load(ROUNDED_FONT_PATH) as Font
	return null


## ラベルに「文字テーマ」（丸ゴシック・墨色）を適用する。
## 和紙の上の文字は縁取りしない（縁取りは細い線を痩せさせる）。世界の上に直接置く文字だけ
## over_world=true で明るい薄い縁取りをつける。
static func style_label(l: Label, size: int, over_world: bool = false) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	if over_world:
		l.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
		l.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	else:
		l.add_theme_constant_override("outline_size", 0)
	var f := font()
	if f != null:
		l.add_theme_font_override("font", f)
