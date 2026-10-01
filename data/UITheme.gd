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


# --- 和紙テクスチャ（会話枠・話者名・日めくり・操作プロンプトの紙）---
## 繊維の入った和紙の 9-slice 画像（tools/gen_washi.py で生成）。無ければ washi() の単色にフォールバック。
## 画像には紙の外側に落ち影の余白（*_PAD）を含むので、その分だけ外へ広げて描き、紙の縁を Control の縁に合わせる。
const PAPER_PANEL_PATH := "res://assets/ui/washi_panel.png"  # 大きい枠用（角丸 16）
const PAPER_PANEL_PAD := 12
const PAPER_PANEL_MARGIN := 28  # 9-slice の余白（影の余白＋角丸）
const PAPER_TAG_PATH := "res://assets/ui/washi_tag.png"      # 小さい札用（角丸 10）
const PAPER_TAG_PAD := 6
const PAPER_TAG_MARGIN := 16
const PAPER_TAG_SELECTED_PATH := "res://assets/ui/washi_tag_selected.png"  # 小さい札＋夏空の青の縁（選択中）
## 帳面の詳細に貼る紙片の色の掛け具合（帳面よりわずかに濃く＝紙の上の紙に見せる）。
const SLIP_TINT := Color(0.96, 0.96, 0.95)
## 和紙テクスチャの角丸（大きい枠）。上に重ねる帯などはこの丸みに合わせる。
const PAPER_CORNER := 16


## 和紙テクスチャの下地。small=true で小さい札用。alpha で透け具合（和紙 0.92・帳面 0.97 など）。
## 画像が無い環境では、同じ角丸・不透明度の washi()（単色）を返す。
static func washi_paper(small: bool = false, alpha: float = WASHI_ALPHA) -> StyleBox:
	var path := PAPER_TAG_PATH if small else PAPER_PANEL_PATH
	if not ResourceLoader.exists(path):
		return washi(10 if small else PAPER_CORNER, alpha)
	return _paper_texture(path, small, Color(1, 1, 1, alpha))


## 9-slice の和紙テクスチャ下地を組む（washi_paper / chip / chip_selected / page / slip の共通部）。
static func _paper_texture(path: String, small: bool, modulate: Color) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin_all(PAPER_TAG_MARGIN if small else PAPER_PANEL_MARGIN)
	sb.set_expand_margin_all(PAPER_TAG_PAD if small else PAPER_PANEL_PAD)
	# 中央と辺は伸ばさずにタイル張り（繊維が引き伸ばされないように。画像は継ぎ目なしで作ってある）。
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.modulate_color = modulate
	return sb


## 帳面の詳細に貼る紙片（かばんの説明など）。帳面より少しだけ濃い和紙。画像が無ければ単色で同じ見た目。
static func slip(corner: int = 14) -> StyleBox:
	if ResourceLoader.exists(PAPER_PANEL_PATH):
		return _paper_texture(PAPER_PANEL_PATH, false, SLIP_TINT)
	var sb := washi(corner, 1.0)
	sb.bg_color = WASHI.darkened(0.04)
	sb.shadow_size = 0
	return sb


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
## 和紙テクスチャがあればそれを（角丸は画像側の PAPER_CORNER）、無ければ単色の帳面。
static func page(corner: int = 20) -> StyleBox:
	if ResourceLoader.exists(PAPER_PANEL_PATH):
		return _paper_texture(PAPER_PANEL_PATH, false, Color(1, 1, 1, PAGE_ALPHA))
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
## 和紙テクスチャ版は、縁に青の線を焼き込んだ小さい札（washi_tag_selected.png）を使う。
static func chip_selected(corner: int = 10) -> StyleBox:
	var sb: StyleBox
	if ResourceLoader.exists(PAPER_TAG_SELECTED_PATH):
		sb = _paper_texture(PAPER_TAG_SELECTED_PATH, true, Color(1, 1, 1, 0.97))
	else:
		var flat := washi(corner, 0.97)
		flat.border_color = ACCENT_LINE
		flat.set_border_width_all(3)
		sb = flat
	_chip_margins(sb)
	return sb


## 未選択の選択肢の下地（和紙。世界の上でも文字が読める濃さ）。
static func chip(corner: int = 10) -> StyleBox:
	var sb: StyleBox
	if ResourceLoader.exists(PAPER_TAG_PATH):
		sb = _paper_texture(PAPER_TAG_PATH, true, Color(1, 1, 1, 0.82))
	else:
		sb = washi(corner, 0.82)
	_chip_margins(sb)
	return sb


## 選択肢の札の内側余白（選択中・未選択で同じにして、選んでも文字が動かないように）。
static func _chip_margins(sb: StyleBox) -> void:
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14


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
