extends CanvasLayer
## 絵日記帳のUI（第9弾＝予定表／第10弾＝風物詩）。いつでも開ける・行動枠を消費しない常設ビュー。
##
## 二つの見開き（タブ）を切り替える：
##   ・予定表（TAB／B）… 月の一覧（天気・約束の印）＋その日の詳細。
##   ・風物詩（C）    … 集めた夏の情景。かすれ（未収集）→くっきり（収集済）の埋まり具合で進捗を感じる。
## 状態は GameState が持ち、schedule_changed / fubutsushi_discovered を購読して描き直すだけ。
##
## 見た目は UITheme に集約（和紙／すりガラス・夏空の青・暖かいダークグレー）。
## トーン厳守（第10弾）：数字カウンタを前面に出さない・達成音を鳴らさない・見逃しを咎めない。

const TAB_CALENDAR := 0
const TAB_ALMANAC := 1

# --- 予定表（カレンダー）---
const COLS := 7
const START_WEEKDAY := 1  ## 起点（7/23＝1日目）を月曜と仮定（HUD と揃える）
const WEEKDAYS := ["日", "月", "火", "水", "木", "金", "土"]
const CELL_W := 150
const CELL_H := 72
const GRID_TOP := 150

# --- 風物詩（アルマナック）---
const ALM_COLS := 8
const ALM_CELL_W := 132
const ALM_CELL_H := 66
const ALM_TOP := 150

## 状態ごとの差し色。
const COL_FULFILLED := Color("6fae7a")  ## 果たした（葉の緑・清書）
const COL_MISSED_ALPHA := 0.32          ## 未達（かすれ）
const COL_UNCOLLECTED_ALPHA := 0.26     ## 未収集の風物詩（かすれ）

var _open := false
var _tab := TAB_CALENDAR
var _detail_open := false
var _cursor := 0

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _cal_nodes: Array = []   ## 予定表タブの表示ノード（曜日見出し＋日マス）
var _cells := []             ## day_index -> { panel, day, weather, mark }
var _alm_nodes: Array = []   ## 風物詩タブの表示ノード
var _alm_cells := []         ## index -> { panel, label }
var _alm_ids: Array = []     ## 並び順の id（ジャンル順）
var _detail: Panel
var _detail_text: Label


func _ready() -> void:
	layer = 20  # HUD より前面
	process_mode = Node.PROCESS_MODE_ALWAYS  # ツリーを止めても操作を受け付ける
	visible = false
	_alm_ids = Fubutsushi.ordered_ids()
	_build_ui()
	GameState.schedule_changed.connect(_refresh)
	GameState.day_changed.connect(_refresh.unbind(1))
	GameState.fubutsushi_discovered.connect(_refresh.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("book"):
		_toggle_tab(TAB_CALENDAR)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("almanac"):
		_toggle_tab(TAB_ALMANAC)
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	# 開いている間はゲーム側へ入力を渡さない（枠は消費しない・裏で歩かない）。
	if _detail_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("skip"):
			_close_detail()
	else:
		if event.is_action_pressed("skip"):
			close()
		elif event.is_action_pressed("interact"):
			_open_detail()
		elif event.is_action_pressed("walk_left"):
			_move_cursor(-1)
		elif event.is_action_pressed("walk_right"):
			_move_cursor(1)
		elif event.is_action_pressed("walk_up"):
			_move_cursor(-_cols())
		elif event.is_action_pressed("walk_down"):
			_move_cursor(_cols())
	get_viewport().set_input_as_handled()


# --- 開閉・タブ -------------------------------------------------------

## そのタブのキーを押したとき：閉→開／同タブなら閉じる／別タブなら切替。
func _toggle_tab(tab: int) -> void:
	if not _open:
		open(tab)
	elif _tab == tab:
		close()
	else:
		_switch_tab(tab)


func open(tab: int = TAB_CALENDAR) -> void:
	if _open:
		return
	_open = true
	_detail_open = false
	_detail.visible = false
	visible = true
	get_tree().paused = true  # ゲーム進行を止める（時間は消費しない）
	AudioManager.play_sfx("confirm")
	_apply_tab(tab)


func close() -> void:
	if not _open:
		return
	_open = false
	_detail_open = false
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("cancel")


func _switch_tab(tab: int) -> void:
	_detail_open = false
	_detail.visible = false
	AudioManager.play_sfx("move")
	_apply_tab(tab)


## タブを適用：ノードの表示を切り替え、カーソル初期位置を決めて描き直す。
func _apply_tab(tab: int) -> void:
	_tab = tab
	for n in _cal_nodes:
		n.visible = tab == TAB_CALENDAR
	for n in _alm_nodes:
		n.visible = tab == TAB_ALMANAC
	if tab == TAB_CALENDAR:
		_cursor = clampi(GameState.day_index, 0, GameState.TOTAL_DAYS - 1)
	else:
		_cursor = 0
	_refresh()


func _count() -> int:
	return GameState.TOTAL_DAYS if _tab == TAB_CALENDAR else _alm_ids.size()


func _cols() -> int:
	return COLS if _tab == TAB_CALENDAR else ALM_COLS


func _move_cursor(delta: int) -> void:
	var n := clampi(_cursor + delta, 0, _count() - 1)
	if n != _cursor:
		_cursor = n
		AudioManager.play_sfx("move")
		_refresh()


func _open_detail() -> void:
	_detail_open = true
	_detail.visible = true
	AudioManager.play_sfx("confirm")
	_refresh_detail()


func _close_detail() -> void:
	_detail_open = false
	_detail.visible = false
	AudioManager.play_sfx("cancel")


# --- 描画（タブで分岐）------------------------------------------------

func _refresh() -> void:
	if not _open:
		return
	if _tab == TAB_CALENDAR:
		_title.text = "予定表　―　%s まで" % GameState.date_text(GameState.TOTAL_DAYS - 1)
		for idx in _cells.size():
			_refresh_cell(idx)
	else:
		_title.text = "夏の風物詩"
		for idx in _alm_cells.size():
			_refresh_alm_cell(idx)
	if _detail_open:
		_refresh_detail()


func _refresh_detail() -> void:
	if _tab == TAB_CALENDAR:
		_detail_text.text = "\n".join(_calendar_detail_lines(_cursor))
	else:
		_detail_text.text = "\n".join(_almanac_detail_lines(_cursor))


# --- 予定表タブ ------------------------------------------------------

func _refresh_cell(idx: int) -> void:
	var cell: Dictionary = _cells[idx]
	var panel: Panel = cell["panel"]
	var is_today := idx == GameState.day_index
	var is_past := idx < GameState.day_index
	var is_cursor := _tab == TAB_CALENDAR and idx == _cursor

	var sb: StyleBoxFlat
	if is_cursor:
		sb = UITheme.washi(10, 0.95)
		sb.border_color = UITheme.ACCENT
		sb.set_border_width_all(3)
	elif is_today:
		sb = UITheme.washi(10, 0.9)
		var bt := UITheme.ACCENT
		bt.a = 0.7
		sb.border_color = bt
		sb.set_border_width_all(2)
	else:
		sb = UITheme.washi(10, 0.45 if is_past else 0.72)
	panel.add_theme_stylebox_override("panel", sb)

	var d := GameState.date_of(idx)
	cell["day"].text = "%d/%d" % [d["month"], d["day"]]
	cell["day"].modulate.a = 0.55 if is_past else 1.0

	cell["weather"].text = _weather_short(idx)
	cell["weather"].modulate.a = 0.6 if idx == GameState.day_index + 1 else 1.0

	var p: Dictionary = GameState.promise_of(idx)
	var mark: Label = cell["mark"]
	if p.is_empty():
		mark.text = ""
	else:
		var who := GameState.char_display(String(p.get("character", "")))
		var initial := who.substr(0, 1)
		match String(p.get("status", "")):
			"planned":
				mark.text = "・%s" % initial
				mark.add_theme_color_override("font_color", UITheme.ACCENT)
				mark.modulate.a = 1.0
			"fulfilled":
				mark.text = "○%s" % initial
				mark.add_theme_color_override("font_color", COL_FULFILLED)
				mark.modulate.a = 1.0
			"missed":
				mark.text = "×%s" % initial
				mark.add_theme_color_override("font_color", UITheme.TEXT)
				mark.modulate.a = COL_MISSED_ALPHA
			_:
				mark.text = ""


func _calendar_detail_lines(idx: int) -> Array:
	var lines := [GameState.date_text(idx)]
	var w := _weather_name(idx)
	if w != "":
		lines.append("天気：%s" % w)
	lines.append("")
	var p: Dictionary = GameState.promise_of(idx)
	if not p.is_empty():
		var who := GameState.char_display(String(p.get("character", "")))
		var place := GameState.place_name(String(p.get("place", "")))
		var tod := _tod_text(String(p.get("time_of_day", "")))
		var flavor := String(p.get("flavor_text", ""))
		match String(p.get("status", "")):
			"planned":
				lines.append("%sと、%s%sで会う約束。" % [who, tod, place])
				if flavor != "":
					lines.append("")
					lines.append("「%s」" % flavor)
			"fulfilled":
				lines.append("%sと、%sで過ごした。" % [who, place])
				lines.append("　――　きれいな一日だった。")
			"missed":
				lines.append("%sとの約束は、果たせなかった。" % who)
				lines.append("　――　それでも、夏は続いていく。")
	else:
		var entry: Dictionary = GameState.diary.get(idx, {})
		if not entry.is_empty():
			lines.append(String(entry.get("note", "")))
		elif idx < GameState.day_index:
			lines.append(GameState._blank_note(idx))
		else:
			lines.append("まだ、何も決まっていない。")
	return lines


func _weather_short(idx: int) -> String:
	match _weather_id(idx):
		Weather.CLEAR_MAX: return "快"
		Weather.CLEAR: return "晴"
		Weather.CLOUDY: return "曇"
		Weather.RAIN: return "雨"
		Weather.SHOWER: return "立"
		Weather.SUNSET: return "夕"
		Weather.FOG: return "霧"
		Weather.TYPHOON_PRE: return "兆"
		Weather.TYPHOON: return "嵐"
	return ""


func _weather_name(idx: int) -> String:
	var id := _weather_id(idx)
	if id == "":
		return ""
	var suffix := "（予報）" if idx == GameState.day_index + 1 else ""
	return Weather.name_of(id) + suffix


func _weather_id(idx: int) -> String:
	if idx <= GameState.day_index:
		return Weather.of(idx)
	if idx == GameState.day_index + 1:
		return GameState.weather_forecast()
	return ""


func _tod_text(tod: String) -> String:
	match tod:
		"morning": return "午前に"
		"afternoon": return "午後に"
		"evening", "night": return "夕方に"
	return ""


# --- 風物詩タブ ------------------------------------------------------

func _refresh_alm_cell(idx: int) -> void:
	var cell: Dictionary = _alm_cells[idx]
	var panel: Panel = cell["panel"]
	var label: Label = cell["label"]
	var id := String(_alm_ids[idx])
	var got := GameState.is_collected(id)
	var is_cursor := _tab == TAB_ALMANAC and idx == _cursor

	var sb: StyleBoxFlat
	if is_cursor:
		sb = UITheme.washi(8, 0.95)
		sb.border_color = UITheme.ACCENT
		sb.set_border_width_all(3)
	else:
		sb = UITheme.washi(8, 0.7 if got else 0.4)
	panel.add_theme_stylebox_override("panel", sb)

	# 収集済＝くっきり名前／未収集＝かすれた「？」（名前は伏せる）。数字は出さない。
	if got:
		label.text = Fubutsushi.name_of(id)
		label.modulate.a = 1.0
	else:
		label.text = "？"
		label.modulate.a = COL_UNCOLLECTED_ALPHA


func _almanac_detail_lines(idx: int) -> Array:
	var id := String(_alm_ids[idx])
	if not GameState.is_collected(id):
		return ["？", "", "まだ見ていない。"]
	var e := Fubutsushi.entry_of(id)
	return [String(e.get("name", id)), "", String(e.get("record_text", ""))]


# --- UI 構築 ---------------------------------------------------------

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
	UITheme.style_label(_title, UITheme.SIZE_DAY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	var help := Label.new()
	help.position = Vector2(60, 76)
	help.size = Vector2(1000, 26)
	help.text = "矢印／WASD で選ぶ　・　［E］で開く　・　［Q］で閉じる　・　［TAB］予定表／［C］風物詩"
	UITheme.style_label(help, UITheme.SIZE_SMALL)
	help.modulate.a = 0.7
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(help)

	_build_calendar()
	_build_almanac()

	# その日の詳細（めくった一枚）。両タブ共用。既定は隠す。
	_detail = Panel.new()
	_detail.size = Vector2(560, 300)
	_detail.position = Vector2((1152 - 560) / 2, (648 - 300) / 2)
	_detail.add_theme_stylebox_override("panel", UITheme.washi(18, 0.97))
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.visible = false
	add_child(_detail)

	_detail_text = Label.new()
	_detail_text.position = Vector2(36, 32)
	_detail_text.size = Vector2(560 - 72, 300 - 64)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_detail_text, UITheme.SIZE_BODY)
	_detail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_text)


func _build_calendar() -> void:
	var grid_left := (1152 - COLS * CELL_W) / 2
	for c in COLS:
		var wl := Label.new()
		wl.position = Vector2(grid_left + c * CELL_W, GRID_TOP - 30)
		wl.size = Vector2(CELL_W, 26)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.text = WEEKDAYS[c % 7]
		UITheme.style_label(wl, UITheme.SIZE_SMALL)
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wl)
		_cal_nodes.append(wl)

	for idx in GameState.TOTAL_DAYS:
		var slot := idx + START_WEEKDAY
		var x := grid_left + (slot % COLS) * CELL_W
		var y := GRID_TOP + (slot / COLS) * CELL_H
		var cp := Panel.new()
		cp.position = Vector2(x + 3, y + 3)
		cp.size = Vector2(CELL_W - 6, CELL_H - 6)
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cp)
		_cal_nodes.append(cp)

		var day_label := Label.new()
		day_label.position = Vector2(8, 4)
		day_label.size = Vector2(CELL_W - 40, 26)
		UITheme.style_label(day_label, UITheme.SIZE_SMALL)
		day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(day_label)

		var weather_label := Label.new()
		weather_label.position = Vector2(CELL_W - 38, 4)
		weather_label.size = Vector2(28, 26)
		weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UITheme.style_label(weather_label, UITheme.SIZE_SMALL)
		weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(weather_label)

		var mark_label := Label.new()
		mark_label.position = Vector2(8, 34)
		mark_label.size = Vector2(CELL_W - 20, 28)
		UITheme.style_label(mark_label, UITheme.SIZE_DAY)
		mark_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(mark_label)

		_cells.append({ "panel": cp, "day": day_label, "weather": weather_label, "mark": mark_label })


func _build_almanac() -> void:
	var grid_left := (1152 - ALM_COLS * ALM_CELL_W) / 2
	for idx in _alm_ids.size():
		var x := grid_left + (idx % ALM_COLS) * ALM_CELL_W
		var y := ALM_TOP + (idx / ALM_COLS) * ALM_CELL_H
		var cp := Panel.new()
		cp.position = Vector2(x + 3, y + 3)
		cp.size = Vector2(ALM_CELL_W - 6, ALM_CELL_H - 6)
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.visible = false
		add_child(cp)
		_alm_nodes.append(cp)

		var label := Label.new()
		label.position = Vector2(6, 0)
		label.size = Vector2(ALM_CELL_W - 18, ALM_CELL_H - 6)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.style_label(label, UITheme.SIZE_SMALL)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(label)

		_alm_cells.append({ "panel": cp, "label": label })
