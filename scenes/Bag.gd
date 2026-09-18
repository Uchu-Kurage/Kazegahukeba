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

const ROW_H := 46
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


## かばんへの1操作（キーからも、将来のスマホ画面ボタンからも同じ入口）。
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
		var sb: StyleBoxFlat = UITheme.washi(8, 0.95) if selected else UITheme.washi(8, 0.5)
		if selected:
			sb.border_color = UITheme.ACCENT
			sb.set_border_width_all(3)
		row.add_theme_stylebox_override("normal", sb)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_dim.color = Color(0.06, 0.07, 0.10, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_panel = Panel.new()
	_panel.position = Vector2(24, 20)
	_panel.size = Vector2(1104, 608)
	_panel.add_theme_stylebox_override("panel", UITheme.washi(20))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(60, 32)
	_title.size = Vector2(984, 40)
	_title.text = "かばん　―　夏の道具"
	UITheme.style_label(_title, UITheme.SIZE_DAY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	var help := Label.new()
	help.position = Vector2(60, 76)
	help.size = Vector2(1000, 26)
	help.text = "矢印／WASD で選ぶ　・　［I］／［Q］で閉じる"
	UITheme.style_label(help, UITheme.SIZE_SMALL)
	help.modulate.a = 0.7
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(help)

	# かばんが空のときの一言。
	_empty = Label.new()
	_empty.position = Vector2(60, LIST_TOP)
	_empty.size = Vector2(984, 40)
	_empty.text = "かばんは、まだ空っぽだ。"
	UITheme.style_label(_empty, UITheme.SIZE_BODY)
	_empty.modulate.a = 0.7
	_empty.visible = false
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_empty)

	# 左：所持中の道具一覧。
	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(60, LIST_TOP)
	_list_box.size = Vector2(440, 420)
	_list_box.add_theme_constant_override("separation", 6)
	_list_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_list_box)

	# 右：選択中の道具の詳細（説明・由来）。
	_detail = Panel.new()
	_detail.position = Vector2(540, LIST_TOP)
	_detail.size = Vector2(504, 420)
	_detail.add_theme_stylebox_override("panel", UITheme.washi(16, 0.85))
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.visible = false
	_panel.add_child(_detail)

	_detail_name = Label.new()
	_detail_name.position = Vector2(32, 28)
	_detail_name.size = Vector2(504 - 64, 40)
	UITheme.style_label(_detail_name, UITheme.SIZE_DAY)
	_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_name)

	_detail_body = Label.new()
	_detail_body.position = Vector2(32, 84)
	_detail_body.size = Vector2(504 - 64, 420 - 116)
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_detail_body, UITheme.SIZE_BODY)
	_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_body)
