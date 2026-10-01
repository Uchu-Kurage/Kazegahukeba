extends CanvasLayer
## 画面手前の常時UI（第7弾で和紙UIに刷新）。
##   右上：日めくり（一枚の和紙カード。左に大きな日付の数字、右に月・曜日／時間帯・天気／何日目）。
##         上端の青い帯は日めくりの綴じ。日曜は数字を朱にする（暦の習わし）。
##   下：操作プロンプト（和紙の小ピル）。
## 見た目は UITheme に集約。日付・時間帯は GameState のシグナルで自動更新。

const WEEKDAYS := ["日", "月", "火", "水", "木", "金", "土"]
## 曜日の基準：起点（7/23＝1日目）を月曜と仮定。表記は仮（暦の厳密さより雰囲気優先）。
const START_WEEKDAY := 1

var _day_card: Panel
var _date_num: Label    ## 大きな日付の数字（23）
var _date_head: Label   ## 七月　月曜日
var _date_now: Label    ## 午前　晴れ
var _date_count: Label  ## 1日目
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
	_refresh_weather()


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
	elif event.is_action_pressed("debug_aoi_warmth"):
		_force_aoi_ending(Endings.LEAN_WARMTH)
	elif event.is_action_pressed("debug_aoi_shadow"):
		_force_aoi_ending(Endings.LEAN_SHADOW)
	elif event.is_action_pressed("debug_aoi_closeness"):
		_force_aoi_ending(Endings.LEAN_CLOSENESS)


## 葵ルートの三分岐を強制して即着地（検証用）。葵を主軸として成立させ（全節目フラグ）、
## 傾きを指定方向へ強く倒してから、通常のエンディング判定（Endings.pick）を通す。
func _force_aoi_ending(direction: String) -> void:
	for m in Routes.by_id(Routes.AOI)["milestones"]:
		GameState.set_flag(Routes.flag_of(Routes.AOI, String(m["key"])), true)
	GameState.aoi_lean = { direction: 99 }
	SaveData.clear_run()
	Nav.go_to_ending()


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
	_refresh_weather()


## 今日の天気だけを出す。明日の予報は「世界に溶けた形」（朝の予報＝ラジオ/朝刊/祖母）で伝える。
func _refresh_weather() -> void:
	_date_now.text = "%s　%s" % [
		GameState.phase_text(GameState.phase), Weather.name_of(GameState.weather_today()),
	]


func _refresh_day() -> void:
	var idx := GameState.day_index
	var d := GameState.date_of(idx)
	var wd := (idx + START_WEEKDAY) % 7
	_date_num.text = str(int(d["day"]))
	_date_num.add_theme_color_override("font_color", UITheme.SUNDAY if wd == 0 else UITheme.TEXT)
	_date_head.text = "%s月　%s曜日" % [_kanji_num(int(d["month"])), WEEKDAYS[wd]]
	_date_count.text = "%d日目" % (idx + 1)


func _kanji_num(n: int) -> String:
	var ones := ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return ones[n]
	if n < 20:
		return "十" + ones[n - 10]
	return ones[n / 10] + "十" + ones[n % 10]


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	# 右上：日めくり（和紙カード一枚）。左に大きな日付、右に三段の小さな情報。
	_day_card = Panel.new()
	_day_card.size = Vector2(264, 96)
	_day_card.position = Vector2(1152 - _day_card.size.x - 16, 16)
	_day_card.add_theme_stylebox_override("panel", UITheme.washi_paper())
	_day_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_day_card)

	# 綴じの帯（日めくりの上端）。夏空の青を細く一本だけ。
	var binding := Panel.new()
	binding.size = Vector2(_day_card.size.x, 8)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = UITheme.ACCENT
	bsb.corner_radius_top_left = UITheme.PAPER_CORNER  # 和紙の角丸に合わせる
	bsb.corner_radius_top_right = UITheme.PAPER_CORNER
	binding.add_theme_stylebox_override("panel", bsb)
	binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_card.add_child(binding)

	_date_num = _card_label(UITheme.SIZE_DATE, Vector2(10, 12), Vector2(84, 80))
	_date_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# 数字と右の情報を分ける縦の罫。
	var rule := ColorRect.new()
	rule.color = UITheme.RULE
	rule.position = Vector2(100, 22)
	rule.size = Vector2(1, 62)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_card.add_child(rule)

	_date_head = _card_label(UITheme.SIZE_SMALL, Vector2(114, 16), Vector2(140, 24))
	_date_now = _card_label(UITheme.SIZE_HINT, Vector2(114, 40), Vector2(140, 30))
	_date_count = _card_label(UITheme.SIZE_SMALL - 2, Vector2(114, 68), Vector2(140, 22))
	_date_head.add_theme_color_override("font_color", UITheme.TEXT_SOFT)
	_date_count.add_theme_color_override("font_color", UITheme.TEXT_SOFT)

	# 下：操作プロンプト（和紙の小ピル。左下）。
	_prompt = Label.new()
	_prompt.position = Vector2(24, 600)
	UITheme.style_label(_prompt, UITheme.SIZE_SMALL)
	var psb := UITheme.washi_paper(true, 0.85)
	psb.content_margin_left = 14
	psb.content_margin_right = 14
	psb.content_margin_top = 4
	psb.content_margin_bottom = 4
	_prompt.add_theme_stylebox_override("normal", psb)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)

	_build_debug_panel()


func _card_label(size: int, pos: Vector2, box: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	UITheme.style_label(l, size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_card.add_child(l)
	return l


## 到達状況オーバーレイ（右側）。既定は非表示、F3 で切替。
func _build_debug_panel() -> void:
	_debug_panel = Panel.new()
	_debug_panel.position = Vector2(772, 124)
	_debug_panel.size = Vector2(372, 440)
	_debug_panel.add_theme_stylebox_override("panel", _flat(Color(0.03, 0.04, 0.07, 0.82), 8))
	_debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_panel.visible = false
	add_child(_debug_panel)

	_debug_text = Label.new()
	_debug_text.position = Vector2(14, 12)
	_debug_text.size = Vector2(344, 416)
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
