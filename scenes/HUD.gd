extends CanvasLayer
## 画面手前の常時UI。日めくりカレンダー（カード）＋時間帯＋操作プロンプト。
##
## 日付・時間帯は GameState のシグナルで自動更新。日が変わったときはカードが
## パタッとめくれるアニメを再生する。UI は .tscn ではなくコードで組み立てる
## （めくり演出のためにピボットや重なりを細かく制御したいので）。

var _card: Control          # カレンダーのカード（これを畳んで日めくり）
var _card_month: Label
var _card_day: Label
var _phase: Label
var _prompt: Label
var _flip: Tween

# --- 動作確認用（デバッグ）オーバーレイ ---
var _debug_on := false
var _debug_panel: Panel
var _debug_text: Label


func _ready() -> void:
	_build_ui()
	GameState.day_changed.connect(_on_day_changed)
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	_apply_date(GameState.day_index, false)  # 起動時はアニメ無しで表示
	_update_phase()


## HUD 全体の表示・非表示（エンディング中などに隠す）。
func set_shown(v: bool) -> void:
	for c in get_children():
		if c is Control:
			c.visible = v
	# デバッグオーバーレイは、表示中でも「デバッグONのとき」だけ出す。
	_debug_panel.visible = v and _debug_on


## デバッグキー（F3=表示切替／F4=いまの状態で即エンディング）。通常入力は消費しない。
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_debug_on = not _debug_on
		_debug_panel.visible = _debug_on
		if _debug_on:
			_refresh_debug()
	elif event.is_action_pressed("debug_end"):
		SaveData.clear_run()   # デバッグ終了なので途中セーブは破棄
		Nav.go_to_ending()     # いまの affinity / flags / stance でエンディング判定
	elif event.is_action_pressed("debug_ura"):
		Nav.go_to_ura_ending() # 裏エンド（9月1日）を強制再生（解放条件を無視・検証用）


func _process(_delta: float) -> void:
	if _debug_on and _debug_panel.visible:
		_refresh_debug()


func _refresh_debug() -> void:
	_debug_text.text = "\n".join(Story.debug_lines(GameState))


func set_prompt(text: String) -> void:
	_prompt.text = text


# --- 状態変化への反応 ------------------------------------------------

func _on_day_changed(index: int) -> void:
	_apply_date(index, true)   # 日が変わった → めくりアニメ
	_update_phase()


func _on_phase_changed() -> void:
	_update_phase()


func _update_phase() -> void:
	_phase.text = "%s（%d日目 / 全%d日）" % [
		GameState.phase_text(GameState.phase),
		GameState.day_index + 1,
		GameState.TOTAL_DAYS,
	]


## カードの日付を更新する。animate=true なら日めくりアニメで切り替える。
func _apply_date(index: int, animate: bool) -> void:
	var d := GameState.date_of(index)
	var month_text := "%d月" % d["month"]
	var day_text := "%d日" % d["day"]
	if not animate:
		_card_month.text = month_text
		_card_day.text = day_text
		return
	if _flip and _flip.is_valid():
		_flip.kill()
	# 上端を軸に、いったん畳んで（scale.y→0）新しい日付にし、また開く。
	_flip = create_tween()
	_flip.tween_property(_card, "scale:y", 0.0, 0.14).set_ease(Tween.EASE_IN)
	_flip.tween_callback(func() -> void:
		_card_month.text = month_text
		_card_day.text = day_text)
	_flip.tween_property(_card, "scale:y", 1.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	# 上の帯（うっすら暗くして文字を読みやすく）。
	var top := Panel.new()
	top.position = Vector2(0, 0)
	top.size = Vector2(1152, 70)
	top.add_theme_stylebox_override("panel", _flat(Color(0.06, 0.07, 0.10, 0.55), 0))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	_phase = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
	_phase.position = Vector2(168, 20)
	_phase.size = Vector2(700, 32)
	add_child(_phase)

	# カレンダーのカード。
	_card = Control.new()
	_card.position = Vector2(20, 6)
	_card.size = Vector2(128, 96)
	_card.pivot_offset = Vector2(64, 0)  # 上端を軸に畳む
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)

	var body := Panel.new()
	body.position = Vector2.ZERO
	body.size = Vector2(128, 96)
	body.add_theme_stylebox_override("panel", _flat(Color(0.95, 0.93, 0.86, 1.0), 8))
	_card.add_child(body)

	var head := Panel.new()
	head.position = Vector2.ZERO
	head.size = Vector2(128, 30)
	var head_sb := _flat(Color(0.80, 0.26, 0.22, 1.0), 8)
	head_sb.corner_radius_bottom_left = 0
	head_sb.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", head_sb)
	_card.add_child(head)

	_card_month = _label(20, HORIZONTAL_ALIGNMENT_CENTER)
	_card_month.position = Vector2(0, 3)
	_card_month.size = Vector2(128, 24)
	_card_month.add_theme_color_override("font_color", Color(1, 1, 1))
	_card.add_child(_card_month)

	_card_day = _label(38, HORIZONTAL_ALIGNMENT_CENTER)
	_card_day.position = Vector2(0, 34)
	_card_day.size = Vector2(128, 56)
	_card_day.add_theme_color_override("font_color", Color(0.15, 0.14, 0.16))
	_card.add_child(_card_day)

	# 下の操作プロンプト帯。
	var bottom := Panel.new()
	bottom.position = Vector2(0, 596)
	bottom.size = Vector2(1152, 52)
	bottom.add_theme_stylebox_override("panel", _flat(Color(0.06, 0.07, 0.10, 0.55), 0))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	_prompt = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_prompt.position = Vector2(24, 608)
	_prompt.size = Vector2(1104, 30)
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


func _label(size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	return sb
