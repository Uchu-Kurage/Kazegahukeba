extends CanvasLayer
## 画面手前の常時UI（第7弾で和紙UIに刷新）。
##   右上：日めくり表示（DAY N / 漢数字の月日 曜日 ・ 時間帯）を和紙ピルで。
##   下：操作プロンプト（和紙の小ピル）。
## 見た目は UITheme に集約。日付・時間帯は GameState のシグナルで自動更新。

const WEEKDAYS := ["日", "月", "火", "水", "木", "金", "土"]
## 曜日の基準：8/1 を月曜と仮定（DAY38 が水になる＝イメージボードの例に合わせる）。表記は仮。
const START_WEEKDAY := 1

var _day_pill: Panel
var _day_label: Label
var _prompt: Label

# --- 動作確認用（デバッグ）オーバーレイ ---
var _debug_on := false
var _debug_panel: Panel
var _debug_text: Label


func _ready() -> void:
	_build_ui()
	GameState.day_changed.connect(_on_changed.unbind(1))
	GameState.phase_changed.connect(_on_changed.unbind(1))
	_refresh_day()


## HUD 全体の表示・非表示（エンディング中などに隠す）。
func set_shown(v: bool) -> void:
	for c in get_children():
		if c is Control:
			c.visible = v
	_debug_panel.visible = v and _debug_on


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug_panel.visible = _debug_on
		if _debug_on:
			_refresh_debug()
	elif event.is_action_pressed("debug_end"):
		SaveData.clear_run()
		Nav.go_to_ending()
	elif event.is_action_pressed("debug_ura"):
		Nav.go_to_ura_ending()
	elif event.is_action_pressed("debug_field"):
		Nav.go_to_field("riverbank", "")


func _process(_delta: float) -> void:
	if _debug_on and _debug_panel.visible:
		_refresh_debug()


func _refresh_debug() -> void:
	_debug_text.text = "\n".join(Story.debug_lines(GameState))


func set_prompt(text: String) -> void:
	_prompt.text = text


# --- 状態変化への反応 ------------------------------------------------

func _on_changed() -> void:
	_refresh_day()


func _refresh_day() -> void:
	var idx := GameState.day_index
	var d := GameState.date_of(idx)
	_day_label.text = "DAY %d / %s %s ・ %s" % [
		idx + 1,
		_kanji_date(int(d["month"]), int(d["day"])),
		WEEKDAYS[(idx + START_WEEKDAY) % 7],
		GameState.phase_text(GameState.phase),
	]


# --- 漢数字の日付（例：八月二十二日）--------------------------------
func _kanji_date(month: int, day: int) -> String:
	return "%s月%s日" % [_kanji_num(month), _kanji_num(day)]


func _kanji_num(n: int) -> String:
	var ones := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return ones[n]
	if n < 20:
		return "十" + ones[n - 10]
	return ones[n / 10] + "十" + ones[n % 10]


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	# 右上：日めくり表示（和紙ピル）。
	_day_pill = Panel.new()
	_day_pill.size = Vector2(392, 50)
	_day_pill.position = Vector2(1152 - _day_pill.size.x - 16, 16)
	_day_pill.add_theme_stylebox_override("panel", UITheme.washi(14))
	_day_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_day_pill)

	_day_label = Label.new()
	_day_label.position = Vector2(18, 8)
	_day_label.size = Vector2(_day_pill.size.x - 36, 34)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(_day_label, UITheme.SIZE_DAY)
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_pill.add_child(_day_label)

	# 下：操作プロンプト（和紙の小ピル。左下）。
	_prompt = Label.new()
	_prompt.position = Vector2(24, 600)
	UITheme.style_label(_prompt, UITheme.SIZE_SMALL)
	var psb := UITheme.washi(10, 0.6)
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 4
	psb.content_margin_bottom = 4
	_prompt.add_theme_stylebox_override("normal", psb)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

	_build_debug_panel()


## 到達状況オーバーレイ（右側）。既定は非表示、F3 で切替。
func _build_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.position = Vector2(772, 78)
	_debug_panel.size = Vector2(372, 468)
	_debug_panel.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.04, 0.07, 0.82), 8))
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.visible = false
	add_child(_debug_panel)

	_debug_text = Label.new()
	_debug_text.position = Vector2(14, 12)
	_debug_text.size = Vector2(344, 444)
	_debug_text.add_theme_font_size_override("font_size", 16)
	_debug_text.add_theme_color_override("font_color", Color(0.86, 0.95, 0.80))
	_debug_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.add_child(_debug_text)


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb
