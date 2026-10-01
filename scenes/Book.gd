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
const GRID_TOP := 164

# --- 風物詩（アルマナック）---
const ALM_COLS := 8
const ALM_CELL_W := 132
const ALM_CELL_H := 66
const ALM_TOP := 150

## 状態ごとの差し色。
const COL_FULFILLED := Color("6fae7a")  ## 果たした（葉の緑・清書）
const COL_MISSED_ALPHA := 0.45          ## 未達（かすれ）
const COL_UNCOLLECTED_ALPHA := 0.45     ## 未収集の風物詩（かすれ）

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
var _tab_btns: Array = []   ## [予定表, 風物詩] のタブ（タップ／クリックで切替）


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
	# キー入力（PC）：該当アクションを act() に委譲。消費したら伝播を止める。
	for a in ["book", "almanac", "interact", "skip", "walk_left", "walk_right", "walk_up", "walk_down"]:
		if event.is_action_pressed(a):
			if act(a):
				get_viewport().set_input_as_handled()
			return


## 予定帳への1操作を実行する（キーからも、スマホの画面ボタンからも同じ入口を使う）。
## 予定帳を開くとツリーを一時停止するため、スマホの合成入力（parse_input_event）は届きにくい。
## そこで TouchControls はこの act() を直接呼ぶ（＝停止中でも確実に開閉・カーソル移動・詳細ができる）。
## 戻り値：この操作を予定帳が受け取ったら true（＝開いている間はゲーム側へ渡さない）。
func act(action: String) -> bool:
	if action == "book":
		_toggle_tab(TAB_CALENDAR)
		return true
	if action == "almanac":
		_toggle_tab(TAB_ALMANAC)
		return true
	if not _open:
		return false
	# 開いている間はゲーム側へ入力を渡さない（枠は消費しない・裏で歩かない）。
	if _detail_open:
		if action == "interact" or action == "skip":
			_close_detail()
		return true
	match action:
		"skip": close()
		"interact": _open_detail()
		"walk_left": _move_cursor(-1)
		"walk_right": _move_cursor(1)
		"walk_up": _move_cursor(-_cols())
		"walk_down": _move_cursor(_cols())
	return true


## 予定帳がいま開いているか（TouchControls が入力の振り分けに使う）。
func is_open() -> bool:
	return _open


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
	for i in _tab_btns.size():
		var on := i == _tab
		var b: Button = _tab_btns[i]
		b.add_theme_stylebox_override("normal", UITheme.ruled_cursor() if on else _tab_sb())
		b.add_theme_color_override("font_color", UITheme.TEXT if on else UITheme.TEXT_SOFT)
	if _tab == TAB_CALENDAR:
		_title.text = "予定表（%sまで）" % GameState.date_text(GameState.TOTAL_DAYS - 1)
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

	# 罫線の帳面：マスは塗らず罫で区切る。今日だけごく薄く青を敷き、選んでいるマスは青で囲む。
	var sb: StyleBoxFlat
	if is_cursor:
		sb = UITheme.ruled_cursor()
	else:
		sb = UITheme.ruled()
		if is_today:
			var tint := UITheme.ACCENT
			tint.a = 0.10
			sb.bg_color = tint
	panel.add_theme_stylebox_override("panel", sb)

	# 日付は数字だけ（月の変わり目と最初の日だけ「月/日」）。日曜は朱・土曜は青（暦の習わし）。
	var d := GameState.date_of(idx)
	var day_label: Label = cell["day"]
	if idx == 0 or int(d["day"]) == 1:
		day_label.text = "%d/%d" % [d["month"], d["day"]]
	else:
		day_label.text = str(int(d["day"]))
	var wd := (idx + START_WEEKDAY) % 7
	var day_col := UITheme.TEXT
	if wd == 0:
		day_col = UITheme.SUNDAY
	elif wd == 6:
		day_col = UITheme.ACCENT_INK
	day_label.add_theme_color_override("font_color", day_col)
	day_label.modulate.a = 0.45 if is_past else 1.0

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
				mark.add_theme_color_override("font_color", UITheme.ACCENT_INK)
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

	panel.add_theme_stylebox_override("panel", UITheme.ruled_cursor() if is_cursor else UITheme.ruled())

	# 収集済＝くっきり名前／未収集＝かすれた「？」（名前は伏せる）。数字は出さない。
	if got:
		label.text = Fubutsushi.name_of(id)
		label.add_theme_color_override("font_color", UITheme.TEXT)
		label.modulate.a = 1.0
	else:
		label.text = "？"
		label.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
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
	UITheme.style_label(_title, UITheme.SIZE_DAY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	var help := Label.new()
	help.position = Vector2(60, 76)
	help.size = Vector2(1000, 26)
	help.text = "矢印／WASD で選ぶ　　［E］で開く"
	UITheme.style_label(help, UITheme.SIZE_SMALL)
	help.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(help)

	_build_tabs()
	_build_calendar()
	_build_almanac()

	# その日の詳細（めくった一枚）。両タブ共用。既定は隠す。
	_detail = Panel.new()
	_detail.size = Vector2(560, 300)
	_detail.position = Vector2((1152 - 560) / 2, (648 - 300) / 2)
	_detail.add_theme_stylebox_override("panel", UITheme.page(18))
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail.gui_input.connect(_on_detail_input)  # めくった一枚はタップで閉じる
	_detail.visible = false
	add_child(_detail)

	_detail_text = Label.new()
	_detail_text.position = Vector2(36, 32)
	_detail_text.size = Vector2(560 - 72, 300 - 64)
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_detail_text, UITheme.SIZE_BODY)
	_detail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.add_child(_detail_text)


## 右上：タブ（予定表／風物詩）と「閉じる」。キーが無いスマホでもタブを切り替え、閉じられるように。
## キーの対応（TAB・C・Q）もラベルに添えて、PC でも何で切り替わるか分かるようにする。
func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(620, 28)
	row.size = Vector2(484, 72)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var defs := [["予定表 TAB", TAB_CALENDAR], ["風物詩 C", TAB_ALMANAC]]
	for d in defs:
		var b := _tab_button(String(d[0]))
		var tab: int = d[1]
		b.pressed.connect(func() -> void:
			if _tab != tab:
				_switch_tab(tab))
		row.add_child(b)
		_tab_btns.append(b)
	var close_btn := _tab_button("閉じる Q")
	close_btn.pressed.connect(close)
	row.add_child(close_btn)


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(148, 72)  # スマホで約 44pt
	var f := UITheme.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL + 2)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_color_override("font_hover_color", UITheme.TEXT)
	b.add_theme_color_override("font_pressed_color", UITheme.TEXT)
	b.add_theme_stylebox_override("normal", _tab_sb())
	var hover := _tab_sb()
	hover.bg_color = UITheme.WASHI.darkened(0.05)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", UITheme.ruled_cursor())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _tab_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UITheme.RULE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb


## 日付（風物詩）をタップ／クリック：そのマスを選んで開く。詳細が開いていれば閉じるだけ。
func _on_cell_input(event: InputEvent, idx: int) -> void:
	if not _open or not _tapped(event):
		return
	get_viewport().set_input_as_handled()
	if _detail_open:
		_close_detail()
		return
	_cursor = idx
	AudioManager.play_sfx("move")
	_refresh()
	_open_detail()


func _on_detail_input(event: InputEvent) -> void:
	if _detail_open and _tapped(event):
		get_viewport().set_input_as_handled()
		_close_detail()


func _tapped(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _build_calendar() -> void:
	var grid_left := (1152 - COLS * CELL_W) / 2
	for c in COLS:
		var wl := Label.new()
		wl.position = Vector2(grid_left + c * CELL_W, GRID_TOP - 30)
		wl.size = Vector2(CELL_W, 26)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.text = WEEKDAYS[c % 7]
		UITheme.style_label(wl, UITheme.SIZE_SMALL)
		if c == 0:
			wl.add_theme_color_override("font_color", UITheme.SUNDAY)
		elif c == 6:
			wl.add_theme_color_override("font_color", UITheme.ACCENT_INK)
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wl)
		_cal_nodes.append(wl)
	# 曜日見出しの下に一本、帳面の罫。
	var head_rule := ColorRect.new()
	head_rule.color = UITheme.RULE
	head_rule.position = Vector2(grid_left, GRID_TOP - 2)
	head_rule.size = Vector2(COLS * CELL_W, 2)
	head_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head_rule)
	_cal_nodes.append(head_rule)

	for idx in GameState.TOTAL_DAYS:
		var slot := idx + START_WEEKDAY
		var x := grid_left + (slot % COLS) * CELL_W
		var y := GRID_TOP + (slot / COLS) * CELL_H
		var cp := Panel.new()
		cp.position = Vector2(x, y)
		cp.size = Vector2(CELL_W, CELL_H)
		cp.mouse_filter = Control.MOUSE_FILTER_STOP
		cp.gui_input.connect(_on_cell_input.bind(idx))  # 日付をタップ＝その日を開く
		add_child(cp)
		_cal_nodes.append(cp)

		var day_label := Label.new()
		day_label.position = Vector2(10, 4)
		day_label.size = Vector2(CELL_W - 44, 28)
		UITheme.style_label(day_label, UITheme.SIZE_HINT)
		day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(day_label)

		var weather_label := Label.new()
		weather_label.position = Vector2(CELL_W - 40, 6)
		weather_label.size = Vector2(30, 26)
		weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UITheme.style_label(weather_label, UITheme.SIZE_SMALL)
		weather_label.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
		weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(weather_label)

		var mark_label := Label.new()
		mark_label.position = Vector2(10, 36)
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
		cp.position = Vector2(x, y)
		cp.size = Vector2(ALM_CELL_W, ALM_CELL_H)
		cp.mouse_filter = Control.MOUSE_FILTER_STOP
		cp.gui_input.connect(_on_cell_input.bind(idx))  # 風物詩をタップ＝その一枚を開く
		cp.visible = false
		add_child(cp)
		_alm_nodes.append(cp)

		var label := Label.new()
		label.position = Vector2(6, 0)
		label.size = Vector2(ALM_CELL_W - 12, ALM_CELL_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.style_label(label, UITheme.SIZE_SMALL)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cp.add_child(label)

		_alm_cells.append({ "panel": cp, "label": label })
