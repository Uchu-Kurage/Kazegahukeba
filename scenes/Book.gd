extends CanvasLayer
## 予定表＝約束帳のUI（第9弾 §4）。いつでも開ける・行動枠を消費しない常設ビュー。
##
## 二層構造：
##   ・月の一覧（カレンダー方眼）… 天気・約束の印を俯瞰する。
##   ・その日の詳細（めくった一枚）… 約束の中身／絵日記の一言を読む。
## 状態は GameState が持ち、schedule_changed を購読して描き直すだけ（表示と状態の分離）。
##
## 見た目は UITheme に集約（和紙／すりガラス・夏空の青・暖かいダークグレー）。
## 約束の状態で描き分ける（§4）：
##   planned   … くっきりした付箋（夏空の青）
##   fulfilled … きれいに清書された記録（葉の緑）
##   missed    … かすれた薄い一行（責めない）
##   空白の過去… 自動の一言（詳細で読める）
## 葵は載らない（§5）。約束システムの外側の存在。

const COLS := 7
const START_WEEKDAY := 1  ## 起点（7/23＝1日目）を月曜と仮定（HUD と揃える）
const WEEKDAYS := ["日", "月", "火", "水", "木", "金", "土"]

const CELL_W := 150
const CELL_H := 72
const GRID_TOP := 150

## 状態ごとの差し色。
const COL_FULFILLED := Color("6fae7a")  ## 果たした（葉の緑・清書）
const COL_MISSED_ALPHA := 0.32          ## 未達（かすれ）

var _open := false
var _detail_open := false
var _cursor := 0

var _dim: ColorRect
var _panel: Panel
var _title: Label
var _cells := []          ## day_index -> { panel, day, weather, mark }
var _detail: Panel
var _detail_text: Label


func _ready() -> void:
	layer = 20  # HUD より前面
	process_mode = Node.PROCESS_MODE_ALWAYS  # ツリーを止めても操作を受け付ける
	visible = false
	_build_ui()
	GameState.schedule_changed.connect(_refresh)
	GameState.day_changed.connect(_refresh.unbind(1))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("book"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return
	# 開いている間はゲーム側へ入力を渡さない（枠は消費しない・裏で歩かない）。
	if _detail_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("skip") or event.is_action_pressed("book"):
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
			_move_cursor(-COLS)
		elif event.is_action_pressed("walk_down"):
			_move_cursor(COLS)
	get_viewport().set_input_as_handled()


# --- 開閉 -------------------------------------------------------------

func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_detail_open = false
	_detail.visible = false
	_cursor = clampi(GameState.day_index, 0, GameState.TOTAL_DAYS - 1)
	visible = true
	get_tree().paused = true  # ゲーム進行を止める（時間は消費しない）
	AudioManager.play_sfx("confirm")
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	_detail_open = false
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("cancel")


func _move_cursor(delta: int) -> void:
	var n := clampi(_cursor + delta, 0, GameState.TOTAL_DAYS - 1)
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


# --- 描画 -------------------------------------------------------------

## 今の状態で一覧を描き直す（schedule_changed / day_changed / カーソル移動で呼ぶ）。
func _refresh() -> void:
	if not _open:
		return
	_title.text = "予定表　―　%s まで" % GameState.date_text(GameState.TOTAL_DAYS - 1)
	for idx in _cells.size():
		_refresh_cell(idx)
	if _detail_open:
		_refresh_detail()


func _refresh_cell(idx: int) -> void:
	var cell: Dictionary = _cells[idx]
	var panel: Panel = cell["panel"]
	var is_today := idx == GameState.day_index
	var is_past := idx < GameState.day_index
	var is_cursor := idx == _cursor

	# 下地：今日＝夏空の青の縁、過去＝うっすら褪せる、それ以外＝和紙。
	var sb: StyleBoxFlat
	if is_cursor:
		sb = UITheme.washi(10, 0.95)
		var b := UITheme.ACCENT
		sb.border_color = b
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

	# 日付。
	var d := GameState.date_of(idx)
	cell["day"].text = "%d/%d" % [d["month"], d["day"]]
	cell["day"].modulate.a = 0.55 if is_past else 1.0

	# 天気（分かる範囲だけ：今日まで＝実績、明日＝予報を薄く。以降は伏せる）。
	cell["weather"].text = _weather_short(idx)
	cell["weather"].modulate.a = 0.6 if idx == GameState.day_index + 1 else 1.0

	# 約束の印（状態で描き分け。葵は載らない）。
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


## 約束の状態を短い言葉に（詳細ビュー用）。
func _refresh_detail() -> void:
	var idx := _cursor
	var lines := []
	lines.append(GameState.date_text(idx))

	# 天気（分かる範囲）。
	var w := _weather_name(idx)
	if w != "":
		lines.append("天気：%s" % w)
	lines.append("")

	var p: Dictionary = GameState.promise_of(idx)
	if not p.is_empty():
		var who := GameState.char_display(String(p.get("character", "")))
		var place := Locations.name_of(String(p.get("place", "")))
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
		# 約束のない日：過去は絵日記の一言、未来はまだ白紙。
		var entry: Dictionary = GameState.diary.get(idx, {})
		if not entry.is_empty():
			lines.append(String(entry.get("note", "")))
		elif idx < GameState.day_index:
			lines.append(GameState._blank_note(idx))
		else:
			lines.append("まだ、何も決まっていない。")

	_detail_text.text = "\n".join(lines)


func _weather_short(idx: int) -> String:
	var id := _weather_id(idx)
	match id:
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


## 分かる範囲の天気ID（今日まで＝実績、明日＝予報、以降＝伏せる＝空文字）。
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


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	# 背景の暗幕（後ろのゲーム画面をやわらかく落とす）。
	_dim = ColorRect.new()
	_dim.color = Color(0.06, 0.07, 0.10, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	# 予定帳の台紙（和紙）。
	_panel = Panel.new()
	_panel.position = Vector2(24, 20)
	_panel.size = Vector2(1104, 608)
	_panel.add_theme_stylebox_override("panel", UITheme.washi(20))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# 見出し。
	_title = Label.new()
	_title.position = Vector2(60, 32)
	_title.size = Vector2(984, 40)
	UITheme.style_label(_title, UITheme.SIZE_DAY)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title)

	# 操作の手引き（右上に小さく）。
	var help := Label.new()
	help.position = Vector2(60, 76)
	help.size = Vector2(984, 26)
	help.text = "矢印／WASD で選ぶ　・　［E］で開く　・　［Q］で閉じる"
	UITheme.style_label(help, UITheme.SIZE_SMALL)
	help.modulate.a = 0.7
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(help)

	var grid_left := (1152 - COLS * CELL_W) / 2

	# 曜日の見出し。
	for c in COLS:
		var wl := Label.new()
		wl.position = Vector2(grid_left + c * CELL_W, GRID_TOP - 30)
		wl.size = Vector2(CELL_W, 26)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wl.text = WEEKDAYS[(c) % 7]
		UITheme.style_label(wl, UITheme.SIZE_SMALL)
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wl)

	# 日ごとのマス（曜日に合わせて配置）。
	for idx in GameState.TOTAL_DAYS:
		var slot := idx + START_WEEKDAY
		var col := slot % COLS
		var row := slot / COLS
		var x := grid_left + col * CELL_W
		var y := GRID_TOP + row * CELL_H

		var cp := Panel.new()
		cp.position = Vector2(x + 3, y + 3)
		cp.size = Vector2(CELL_W - 6, CELL_H - 6)
		cp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cp)

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

		_cells.append({
			"panel": cp, "day": day_label,
			"weather": weather_label, "mark": mark_label,
		})

	# その日の詳細（めくった一枚）。既定は隠す。
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
