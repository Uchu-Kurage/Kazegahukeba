extends Control
## タイトル画面（メインシーン）。起動時とエンディング後に表示する。
##
## 「はじめる」で新しい周回を開始。エンディング記録（図鑑）や記録の消去もここから。
## 周回をまたぐ記録は SaveData が持っているので、ここはそれを見せて選ばせるだけ。

enum Screen { MAIN, RECORDS, ALMANAC, CONFIRM }

var _screen := Screen.MAIN
var _items: Array = []   ## いま選べる項目 [{id, label}]
var _index := 0

var _vbox: VBoxContainer
var _footer: Label
var _sel_sb: StyleBoxFlat
var _unsel_sb: StyleBoxFlat


func _ready() -> void:
	HUD.set_shown(false)  # タイトルではカレンダーを出さない
	AudioManager.play_bgm("title")
	AudioManager.stop_ambient()
	_build_ui()
	_go(Screen.MAIN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("walk_up"):
		_move(-1)
	elif event.is_action_pressed("walk_down"):
		_move(1)
	elif event.is_action_pressed("interact"):
		_activate()
	elif event.is_action_pressed("skip"):
		if _screen != Screen.MAIN:
			_go(Screen.MAIN)


## 項目を直接タップ／クリック：その項目を選んで実行する。
func _on_item_input(event: InputEvent, i: int) -> void:
	# タッチは Godot がマウスのクリックに変換して届ける（emulate_mouse_from_touch）。
	# ScreenTouch も拾うと1回のタップが2回に数えられるので、マウスのクリックだけを見る。
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if tapped and i < _items.size():
		get_viewport().set_input_as_handled()
		_index = i
		# 実行すると項目のラベルを作り直す（free）ので、このラベルの入力処理を抜けてから行う。
		_activate.call_deferred()


func _move(d: int) -> void:
	if _items.is_empty():
		return
	_index = wrapi(_index + d, 0, _items.size())
	AudioManager.play_sfx("blip")
	_render()


func _activate() -> void:
	var id := String(_items[_index]["id"])
	AudioManager.play_sfx("cancel" if id in ["back", "clear_no"] else "confirm")
	match id:
		"start":
			SaveData.clear_run()  # 新規開始：以前の途中セーブを破棄
			GameState.start_new_run()
			# 初回はオープニング（歩ける消失の夢・第13弾）→目覚め→本編。既読なら夢を飛ばして家から。
			if SaveData.opening_seen:
				Nav.go_to_field("home", "")
			else:
				Nav.go_to_opening()
		"resume":
			GameState.restore(SaveData.load_run())  # 途中から再開
			Nav.go_to_field("home", "")  # 再開も家から（保存した日付・時間帯のまま散策へ）
		"ura":
			Nav.go_to_ura_ending()  # 裏エンド（9月1日）へ

		"records":
			_go(Screen.RECORDS)
		"almanac":
			_go(Screen.ALMANAC)
		"opening":
			Nav.go_to_opening(true)  # オープニングの夢を再生（見終わったらタイトルへ戻る）
		"clear":
			_go(Screen.CONFIRM)
		"quit":
			get_tree().quit()
		"back":
			_go(Screen.MAIN)
		"clear_yes":
			SaveData.clear()
			_go(Screen.MAIN)
		"clear_no":
			_go(Screen.MAIN)


## 画面（状態）を切り替える。
func _go(screen: Screen) -> void:
	_screen = screen
	_index = 0
	match screen:
		Screen.MAIN:
			_items = []
			if SaveData.has_run():
				_items.append({ "id": "resume", "label": "つづきから" })
			_items.append({ "id": "start", "label": "はじめる" })
			# 全エンド到達で解放される裏エンドへの導線（控えめに一項目だけ増える）。
			if Endings.ura_unlocked():
				_items.append({ "id": "ura", "label": "９月１日" })
			_items.append({ "id": "records", "label": "エンディング記録" })
			_items.append({ "id": "almanac", "label": "風物詩図鑑" })
			_items.append({ "id": "opening", "label": "オープニングを見る" })
			_items.append({ "id": "clear", "label": "記録を消す" })
			_items.append({ "id": "quit", "label": "おわる" })
		Screen.RECORDS:
			_items = [{ "id": "back", "label": "戻る" }]
		Screen.ALMANAC:
			_items = [{ "id": "back", "label": "戻る" }]
		Screen.CONFIRM:
			_items = [
				{ "id": "clear_no", "label": "いいえ" },
				{ "id": "clear_yes", "label": "はい（記録を消す）" },
			]
	_render()


func _render() -> void:
	for c in _vbox.get_children():
		c.free()

	for line in _screen_lines():
		_vbox.add_child(_make_label(line, 20, UITheme.WASHI))
	if not _screen_lines().is_empty():
		_vbox.add_child(_spacer(16))

	# 項目は左揃えの一列。選んでいる項目だけ、左に夏空の青の短い線が立ち、文字が濃くなる。
	for i in _items.size():
		var it: Dictionary = _items[i]
		var selected := i == _index
		var lbl := _make_label(String(it["label"]), 26 if selected else 24,
			UITheme.WASHI if selected else Color(UITheme.WASHI, 0.62))
		lbl.add_theme_stylebox_override("normal", _sel_sb if selected else _unsel_sb)
		lbl.custom_minimum_size = Vector2(0, 60)  # 指で押せる高さ（スマホで約 36pt。行間と合わせて 40pt 超）
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 項目は直接タップ／クリックでも選べる（方向キー＋決定と同じ結果）。
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.gui_input.connect(_on_item_input.bind(i))
		_vbox.add_child(lbl)

	_footer.text = _footer_text()


## いまの画面に出す説明テキスト（選択項目の上に並ぶ）。
func _screen_lines() -> Array:
	match _screen:
		Screen.RECORDS:
			return _records_lines()
		Screen.ALMANAC:
			return _almanac_lines()
		Screen.CONFIRM:
			return ["記録を消しますか？（到達エンドと周回数がすべて消えます）"]
	return []


## 風物詩図鑑：周回をまたいで見た天気限定風景の一覧（未見は？？？）。
func _almanac_lines() -> Array:
	var ids := WeatherScenes.ids()
	var lines := ["【風物詩図鑑】　%d / %d" % [SaveData.scene_seen_count(ids), ids.size()]]
	for id in ids:
		if SaveData.has_scene(id):
			lines.append("　✓ %s（%s）" % [WeatherScenes.title_of(id), WeatherScenes.hint_of(id)])
		else:
			lines.append("　― ？？？")
	return lines


func _records_lines() -> Array:
	var lines := ["【エンディング記録】"]
	for id in Endings.NORMAL_IDS:
		if SaveData.has_seen(id):
			lines.append("　✓ " + Endings.title_of(id))
		else:
			lines.append("　― ？？？")
	var secret := ""
	if Endings.ura_seen():
		secret = "到達済み：" + Endings.title_of(Endings.SECRET)
	elif Endings.ura_unlocked():
		secret = "解放（「９月１日」から）"
	else:
		secret = "未解放（全エンド到達で開く）"
	lines.append("　裏エンド：" + secret)
	return lines


func _footer_text() -> String:
	return "周回 %d 回　　エンディング %d / %d" % [
		SaveData.runs, SaveData.seen_count(Endings.NORMAL_IDS), Endings.NORMAL_IDS.size(),
	]


# --- UI 部品 ---------------------------------------------------------

func _build_ui() -> void:
	add_child(TitleBackground.new())  # 夕暮れの空・山・田んぼ
	add_child(Fireflies.new())        # 漂う蛍

	# 表題は縦書き（夏休みの絵日記の表紙のように）。画面右に大きく一行、その左に副題を細く。
	# 縦書きは「一字ずつ改行」で組む（題も副題も縦中横・小書き仮名を含まない文字列に限る）。
	# スマホ（画面ボタンあり）は右下の決定／戻るに重ならないよう、表題を少し小さく上に詰める。
	var touch := TouchControls.is_shown()
	var title := _make_vertical("風が吹けば", 62 if touch else 76, UITheme.WASHI, -20 if touch else -22)
	title.add_theme_font_override("font", _display_font())
	title.position = Vector2(960 if touch else 952, 40 if touch else 56)
	add_child(title)
	var sub := _make_vertical("終わりゆく世界の最後の夏", 20, Color(UITheme.WASHI, 0.78), -4)
	sub.position = Vector2(910 if touch else 900, 52 if touch else 70)
	add_child(sub)

	# 選択中の項目：左に夏空の青の短い縦線（ボーダーの左辺だけ）。未選択は同じ余白の透明。
	_sel_sb = StyleBoxFlat.new()
	_sel_sb.bg_color = Color(0, 0, 0, 0)
	_sel_sb.border_color = UITheme.ACCENT
	_sel_sb.border_width_left = 4
	_sel_sb.set_content_margin_all(4)
	_sel_sb.content_margin_left = 18
	_unsel_sb = StyleBoxFlat.new()
	_unsel_sb.bg_color = Color(0, 0, 0, 0)
	_unsel_sb.set_content_margin_all(4)
	_unsel_sb.content_margin_left = 22

	# 項目の列：画面左、地平線をまたいで縦に並べる。
	_vbox = VBoxContainer.new()
	_vbox.position = Vector2(96, 0)
	_vbox.size = Vector2(640, 648)
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)

	_footer = _make_label("", 16, Color(UITheme.WASHI, 0.5))
	_footer.position = Vector2(118, 600)
	add_child(_footer)


## 縦書きのラベル（一字ずつ改行）。line_spacing で字間を詰める。
func _make_vertical(text: String, size: int, color: Color, spacing: int) -> Label:
	var l := _make_label("\n".join(text.split("")), size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", spacing)
	return l


## 表題用：丸ゴシックを少し太らせる（同じ書体のまま、表題だけ重さで立たせる）。
func _display_font() -> Font:
	var fv := FontVariation.new()
	fv.base_font = UITheme.font() if UITheme.font() != null else ThemeDB.fallback_font
	fv.variation_embolden = 0.6
	return fv


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# 夕空と田んぼの上に直接置くので、空の色に沈まないよう夜の藍で縁取る。
	l.add_theme_color_override("font_outline_color", Color(0.10, 0.10, 0.20, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
