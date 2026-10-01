extends CanvasLayer
## かばん＝所持品（夏の道具）の専用UI（所持品システム §6）。いつでも開ける・行動枠を消費しない。
##
## 絵日記帳（予定表／風物詩＝眺める記録）とは別立て。「かばん／ポケット」＝持ち運べて使える道具の実物入れ。
## 役割が違うものは入れ物も分ける。状態は GameState が持ち、inventory_changed を購読して描き直すだけ。
##
## 見た目は UITheme に集約（和紙／すりガラス・夏空の青・暖かいダークグレー）。
## トーン厳守：数字カウンタを前面に出さない・達成音を鳴らさない・見逃しを咎めない。
## ★葵絡みアイテムは由来（origin）が空だが、それを特別扱いする表示はしない（§5-2）。
##   他の道具と同じ体裁で、由来欄だけが静かに何もない。気づく人だけが気づく。

const ROW_H := 72  # 指で押せる行の高さ（スマホでは画面が約 0.6 倍に縮むので約 43pt）
const LIST_TOP := 150

var _open := false
var _cursor := 0

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _empty: Label
var _list_box: VBoxContainer
var _rows: Array = []          ## 行 Label（カーソル対象）
var _ids: Array = []           ## 表示順の道具 id（item_list と同順）
var _detail: Panel
var _detail_name: Label
var _detail_body: Label


func _ready() -> void:
	layer = 21  # HUD・予定帳より前面（同時に開かない前提だが念のため上に）
	process_mode = Node.PROCESS_MODE_ALWAYS  # ツリーを止めても操作を受け付ける
	visible = false
	_build_ui()
	GameState.inventory_changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	for a in ["bag", "interact", "skip", "walk_up", "walk_down"]:
		if event.is_action_pressed(a):
			if act(a):
				get_viewport().set_input_as_handled()
			return


## かばんへの1操作（キーからも、スマホの画面ボタン（TouchControls）からも同じ入口）。
## かばんを開くとツリーを一時停止するため、スマホの合成入力は届きにくい。TouchControls はこれを直接呼ぶ。
## 戻り値：この操作をかばんが受け取ったら true（開いている間はゲーム側へ渡さない）。
func act(action: String) -> bool:
	if action == "bag":
		if _open:
			close()
		else:
			open()
		return true
	if not _open:
		return false
	match action:
		"skip", "interact": close()
		"walk_up": _move_cursor(-1)
		"walk_down": _move_cursor(1)
	return true


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	get_tree().paused = true  # 行動枠は消費しない・裏で歩かない
	AudioManager.play_sfx("confirm")
	_cursor = 0
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("cancel")


## 行をタップ／クリック：その道具を選ぶ（右に説明が出る）。
func _on_row_input(event: InputEvent, i: int) -> void:
	if not _open or not _tapped(event):
		return
	get_viewport().set_input_as_handled()
	if i != _cursor and i < _ids.size():
		_cursor = i
		AudioManager.play_sfx("move")
		_refresh.call_deferred()  # 行を作り直すので、この行の入力処理を抜けてから


func _tapped(event: InputEvent) -> bool:
	# タッチは Godot がマウスのクリックに変換して届ける（emulate_mouse_from_touch）。
	# ScreenTouch も拾うと1回のタップが2回に数えられるので、マウスのクリックだけを見る。
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	return false


func _move_cursor(delta: int) -> void:
	if _ids.is_empty():
		return
	var n := clampi(_cursor + delta, 0, _ids.size() - 1)
	if n != _cursor:
		_cursor = n
		AudioManager.play_sfx("move")
		_refresh()


# --- 描画 -----------------------------------------------------------------

func _refresh() -> void:
	if not _open:
		return
	var items := GameState.item_list()
	_ids.clear()
	for it in items:
		_ids.append(String(it["id"]))
	_cursor = clampi(_cursor, 0, max(0, _ids.size() - 1))

	# 空のときは一言だけ（責めない・カウンタを出さない）。
	_empty.visible = items.is_empty()
	_detail.visible = not items.is_empty()

	# 行を作り直す（数が少ないので毎回作り直しても十分軽い）。
	for r in _rows:
		r.queue_free()
	_rows.clear()
	for i in items.size():
		var it: Dictionary = items[i]
		var row := Label.new()
		row.custom_minimum_size = Vector2(0, ROW_H)
		var mark := "　"
		if bool(it.get("consumable", false)):
			mark = "◇"  # 消費品の目印（消/残の区別が分かる程度・控えめ）
		var name := String(it.get("name", ""))
		if bool(it.get("consumable", false)) and int(it.get("count", 1)) > 1:
			name += "（%d）" % int(it["count"])
		row.text = "%s %s" % [mark, name]
		UITheme.style_label(row, UITheme.SIZE_BODY)
		var selected := i == _cursor
		# 帳面の一覧：行は罫で区切り、選んでいる行だけ夏空の青で囲む。
		var sb: StyleBoxFlat = UITheme.ruled_cursor() if selected else UITheme.ruled()
		sb.border_width_right = 2 if selected else 0
		sb.content_margin_left = 12
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_stylebox_override("normal", sb)
		# 行は直接タップ／クリックで選べる（方向キーと同じ結果。説明が右に出る）。
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_row_input.bind(i))
		_list_box.add_child(row)
		_rows.append(row)

	_refresh_detail()


func _refresh_detail() -> void:
	if _ids.is_empty():
		return
	var it: Dictionary = GameState.inventory.get(_ids[_cursor], {})
	_detail_name.text = String(it.get("name", ""))
	var lines: Array = [String(it.get("desc", ""))]
	# 由来欄は全アイテム同じ体裁。葵アイテムだけ由来が空 ―― それを強調しない（§5-2）。
	# 「由来:不明」等のラベルは付けない。ただ、他は「― ○○にもらった」と出て、空のものは静かに何もない。
	var origin := String(it.get("origin", ""))
	lines.append("")
	if origin != "":
		lines.append("― %s" % origin)
	_detail_body.text = "\n".join(lines)


# --- UI 構築 --------------------------------------------------------------

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.07, 0.10, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_panel = Panel.new()
	_panel.position = Vector2(24, 20)
	_panel.size = Vector2(1104, 608)
	_panel.add_theme_stylebox_override("panel", UITheme.page())
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(60, 32)
	_title.size = Vector2(984, 40)
	_title.text = "かばん（夏の道具）"
	UITheme.style_label(_title, UITheme.SIZE_DAY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	var help := Label.new()
	help.position = Vector2(60, 76)
	help.size = Vector2(1000, 26)
	help.text = "矢印／WASD で選ぶ"
	UITheme.style_label(help, UITheme.SIZE_SMALL)
	help.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(help)

	# 右上：閉じる（キーが無いスマホでも閉じられるように。キーの対応も添える）。
	var close_btn := Button.new()
	close_btn.text = "閉じる Q"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.position = Vector2(1104 - 148 - 24, 8)
	close_btn.size = Vector2(148, 72)  # スマホで約 44pt
	var f := UITheme.font()
	if f != null:
		close_btn.add_theme_font_override("font", f)
	close_btn.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL + 2)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		close_btn.add_theme_color_override(c, UITheme.TEXT)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0)
	csb.border_color = UITheme.RULE
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("normal", csb)
	var chover := csb.duplicate() as StyleBoxFlat
	chover.bg_color = UITheme.WASHI.darkened(0.05)
	close_btn.add_theme_stylebox_override("hover", chover)
	close_btn.add_theme_stylebox_override("pressed", UITheme.ruled_cursor())
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_btn.pressed.connect(close)
	_panel.add_child(close_btn)

	# かばんが空のときの一言。
	_empty = Label.new()
	_empty.position = Vector2(60, LIST_TOP)
	_empty.size = Vector2(984, 40)
	_empty.text = "かばんは、まだ空っぽだ。"
	UITheme.style_label(_empty, UITheme.SIZE_BODY)
	_empty.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
	_empty.visible = false
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_empty)

	# 左：所持中の道具一覧。
	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(60, LIST_TOP)
	_list_box.size = Vector2(440, 420)
	_list_box.add_theme_constant_override("separation", 0)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_list_box)

	# 右：選択中の道具の詳細（説明・由来）。
	_detail = Panel.new()
	_detail.position = Vector2(540, LIST_TOP)
	_detail.size = Vector2(504, 420)
	# 詳細は帳面に貼った一枚の紙片：地を少しだけ濃くした和紙（帳面の上の紙）。
	_detail.add_theme_stylebox_override("panel", UITheme.slip())
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.visible = false
	_panel.add_child(_detail)

	_detail_name = Label.new()
	_detail_name.position = Vector2(32, 28)
	_detail_name.size = Vector2(504 - 64, 40)
	UITheme.style_label(_detail_name, UITheme.SIZE_BODY)
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_name)

	_detail_body = Label.new()
	_detail_body.position = Vector2(32, 84)
	_detail_body.size = Vector2(504 - 64, 420 - 116)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_detail_body, UITheme.SIZE_CHOICE)
	_detail_body.add_theme_constant_override("line_spacing", 6)
	_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_body)
