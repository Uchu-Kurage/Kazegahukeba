extends Control
## タイトル画面（メインシーン）。起動時とエンディング後に表示する。
##
## 「はじめる」で新しい周回を開始。エンディング記録（図鑑）や記録の消去もここから。
## 周回をまたぐ記録は SaveData が持っているので、ここはそれを見せて選ばせるだけ。

enum Screen { MAIN, RECORDS, CONFIRM }

var _screen := Screen.MAIN
var _items: Array = []   ## いま選べる項目 [{id, label}]
var _index := 0

var _center: CenterContainer
var _vbox: VBoxContainer
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
			Nav.go_to_field("home", "")  # 散策（『ぼくのなつやすみ』方式）を本編の入口に。家から朝スタート
		"resume":
			GameState.restore(SaveData.load_run())  # 途中から再開
			Nav.go_to_field("home", "")  # 再開も家から（保存した日付・時間帯のまま散策へ）
		"ura":
			Nav.go_to_ura_ending()  # 裏エンド（9月1日）へ

		"records":
			_go(Screen.RECORDS)
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
			_items.append({ "id": "clear", "label": "記録を消す" })
			_items.append({ "id": "quit", "label": "おわる" })
		Screen.RECORDS:
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

	_vbox.add_child(_make_label("風が吹けば", 56, Color(0.96, 0.92, 0.82)))
	_vbox.add_child(_make_label("― 終わりゆく世界の、最後の夏 ―", 20, Color(0.80, 0.82, 0.88)))
	_vbox.add_child(_spacer(24))

	for line in _screen_lines():
		_vbox.add_child(_make_label(line, 20, Color(0.88, 0.88, 0.90)))
	if not _screen_lines().is_empty():
		_vbox.add_child(_spacer(12))

	for i in _items.size():
		var it: Dictionary = _items[i]
		var selected := i == _index
		var mark := "▶ " if selected else "　 "
		var lbl := _make_label(mark + String(it["label"]), 26,
			Color(1.0, 0.92, 0.6) if selected else Color(1, 1, 1, 0.85))
		lbl.add_theme_stylebox_override("normal", _sel_sb if selected else _unsel_sb)
		_vbox.add_child(lbl)

	_vbox.add_child(_spacer(24))
	_vbox.add_child(_make_label(_footer_text(), 16, Color(1, 1, 1, 0.55)))


## いまの画面に出す説明テキスト（選択項目の上に並ぶ）。
func _screen_lines() -> Array:
	match _screen:
		Screen.RECORDS:
			return _records_lines()
		Screen.CONFIRM:
			return ["記録を消しますか？（到達エンドと周回数がすべて消えます）"]
	return []


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
	return "周回 %d 回　／　エンディング %d / %d" % [
		SaveData.runs, SaveData.seen_count(Endings.NORMAL_IDS), Endings.NORMAL_IDS.size(),
	]


# --- UI 部品 ---------------------------------------------------------

func _build_ui() -> void:
	add_child(TitleBackground.new())  # 夕暮れの空・山・田んぼ
	add_child(Fireflies.new())        # 漂う蛍

	# 選択中の項目に敷くハイライト帯（未選択は同サイズの透明で見た目のガタつきを防ぐ）。
	_sel_sb = StyleBoxFlat.new()
	_sel_sb.bg_color = Color(1.0, 0.85, 0.45, 0.22)
	_sel_sb.set_corner_radius_all(6)
	_sel_sb.set_content_margin_all(8)
	_sel_sb.content_margin_left = 24
	_sel_sb.content_margin_right = 24
	_unsel_sb = StyleBoxFlat.new()
	_unsel_sb.bg_color = Color(0, 0, 0, 0)
	_unsel_sb.set_content_margin_all(8)
	_unsel_sb.content_margin_left = 24
	_unsel_sb.content_margin_right = 24

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

	_vbox = VBoxContainer.new()
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 8)
	_center.add_child(_vbox)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# 明るい空でも読めるよう、濃い縁取りをつける。
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.10, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
