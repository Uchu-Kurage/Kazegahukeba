class_name UITheme
extends RefCounted
## UIの見た目を一箇所に集約するテーマ（実装指示 第7弾）。
##
## 目指すのは「夏に溶けるUI」＝和紙／すりガラスの半透明・角丸・やわらかい縁、
## 文字は暖かいダークグレー（白抜きにしない）、差し色は夏空の青。
## 色・不透明度・角丸・フォント・差し色はすべてここに置き、各所で直書きしない（§7）。
## 数値はイメージボードに寄せる出発点。ここを変えれば全体を一括調整できる。

# --- 和紙（メッセージ枠・話者名タグ・選択肢・日めくり 共通の下地）---
const WASHI := Color("f5f0e6")        # 生成り〜クリーム白（純白は避ける）
const WASHI_ALPHA := 0.88             # 半透明（背景がほんのり透ける）：85〜90% が出発点
const CORNER := 16                    # 角丸（やわらかめ）
const BORDER := Color("cbbfa6")       # ごく薄い和紙の縁（くっきりした境界にしない）
const BORDER_ALPHA := 0.5
const SHADOW := Color(0, 0, 0, 0.18)  # 影でふわっと浮かせる

# --- 文字（本文・話者名・選択肢・日めくり 共通）---
const TEXT := Color("3a3a38")             # 暖かいダークグレー（純黒は避ける）
const TEXT_OUTLINE := Color(1, 1, 1, 0.6) # 明るい薄い縁取り（明るい背景でも読めるように）
const OUTLINE_SIZE := 4

# --- 差し色（夏空の青。選択中・強調に絞って使う）---
const ACCENT := Color("5ba3d0")
const ACCENT_ALPHA := 0.80

# --- 文字サイズ（サイズで階層をつける。フォントは統一）---
const SIZE_BODY := 28
const SIZE_NAME := 24
const SIZE_CHOICE := 24
const SIZE_HINT := 22
const SIZE_DAY := 24
const SIZE_SMALL := 18

## 丸ゴシックのフォント。ここに TTF を置けば全体が丸ゴシックに切り替わる（未設置なら既定＝Noto）。
## ライセンス確認のうえ、源柔ゴシック／M PLUS Rounded 1c 等を assets/fonts/rounded.ttf に置く。
const ROUNDED_FONT_PATH := "res://assets/fonts/rounded.ttf"


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


## 未選択の選択肢の下地（ごく薄い和紙）。
static func chip(corner: int = 10) -> StyleBoxFlat:
	var sb := washi(corner, 0.55)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## 丸ゴシックのフォント（未設置なら null＝プロジェクト既定フォントのまま）。
static func font() -> Font:
	if ResourceLoader.exists(ROUNDED_FONT_PATH):
		return load(ROUNDED_FONT_PATH) as Font
	return null


## ラベルに「文字テーマ」（丸ゴシック・ダークグレー・薄い縁取り）を適用する。
static func style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	l.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	var f := font()
	if f != null:
		l.add_theme_font_override("font", f)
