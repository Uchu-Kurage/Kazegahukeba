extends CanvasLayer
## スマホ（タッチ端末）向けの画面上コントローラ（Autoload）。
##
## 【なぜ必要か】
## このゲームの操作とデバッグは元々すべて物理キー前提（移動=WASD/矢印、決定=E、戻る=Q、
## デバッグ=F3〜F10）。スマホにはキーボードが無いので、実機ではプレイもデバッグ機能の
## 呼び出しもできなかった。ここで画面上のボタンを載せ、既存の入力アクションへ橋渡しする。
##
## 【設計】各シーンは一切変更しない。
##   - HUD と同じく Autoload の CanvasLayer なので、全シーンの手前に常駐する。
##   - ボタンは「既存の入力アクション」を InputEventAction で合成して Input へ流すだけ。
##     だから Title/Town/Place/Field/Dialogue/Ending/HUD のどれも、キーで来た入力と
##     同じ経路で処理される（追加のフックは不要）。
##
## 【2種類の入力を1つの方式で満たす】
##   - 移動（Player._physics_process の Input.get_vector …）＝ポーリング型。
##       → 押下中は action を pressed のまま保持（離したら release）することで動き続ける。
##   - 決定/戻る/メニュー上下/デバッグ（各 _input・_unhandled_input の is_action_pressed）
##       ＝イベント型。→ タップで pressed→released を1回流せば、押下エッジが1回発火する。
##   InputEventAction を parse_input_event で流すと、上記の両方（ポーリング状態の更新と
##   イベント伝播）が同時に満たせる。

## デスクトップでも強制的に表示したいとき true（タッチUIの見た目・配置確認用）。
const FORCE_SHOW := false

const DPAD := 92          # D-pad ボタンの一辺
const ACT := 128          # 決定ボタンの一辺
const MARGIN := 40        # 画面端からの余白

var _root: Control
var _debug_menu: Panel
var _debug_open := false


func _ready() -> void:
	layer = 128  # HUD より手前に描く（HUD は既定レイヤ）。
	_build_ui()
	# タッチ端末のときだけ表示（それ以外は邪魔にならないよう隠す）。
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_root.visible = touch or FORCE_SHOW


# --- 入力の橋渡し ----------------------------------------------------

## 入力アクションを1つ「押す/離す」。合成イベントを Input に流す。
## pressed=true で押下エッジが発火し、ポーリング状態も pressed になる。
func _emit(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## 押しっぱなし用（D-pad の移動）。button_down/button_up に対応させる。
func _hold(action: String, down: bool) -> void:
	_emit(action, down)


## 単発用（決定・戻る・メニュー上下・デバッグ）。押して即離す＝1回のエッジ。
func _tap(action: String) -> void:
	_emit(action, true)
	_emit(action, false)


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 空きスペースは背後（ゲーム）へ素通し
	add_child(_root)

	_build_dpad()
	_build_action_buttons()
	_build_debug_gear()
	_build_debug_menu()


## 左下：十字キー（移動・カーソル・会話送りの上下）。押下保持で歩ける。
func _build_dpad() -> void:
	var pad := Control.new()
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var span := DPAD * 3 + 24
	pad.offset_left = MARGIN
	pad.offset_top = -(span + MARGIN)
	pad.offset_right = MARGIN + span
	pad.offset_bottom = -MARGIN
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad)

	var mid := DPAD + 12
	_add_hold_button(pad, "▲", "walk_up",    Vector2(mid, 0))
	_add_hold_button(pad, "◀", "walk_left",  Vector2(0, mid))
	_add_hold_button(pad, "▶", "walk_right", Vector2(mid * 2, mid))
	_add_hold_button(pad, "▼", "walk_down",  Vector2(mid, mid * 2))


## 右下：決定（E）と戻る（Q）。会話送り・入る・話す・戻る・スキップに対応。
func _build_action_buttons() -> void:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wrap.offset_left = -(ACT + 130 + MARGIN)
	wrap.offset_top = -(ACT + MARGIN)
	wrap.offset_right = -MARGIN
	wrap.offset_bottom = -MARGIN
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wrap)

	var confirm := _make_button("決定", 34)
	confirm.size = Vector2(ACT, ACT)
	confirm.position = Vector2(130, 0)
	confirm.pressed.connect(func() -> void: _tap("interact"))
	wrap.add_child(confirm)

	var back := _make_button("戻る", 26)
	back.size = Vector2(110, ACT - 30)
	back.position = Vector2(0, 30)
	back.pressed.connect(func() -> void: _tap("skip"))
	wrap.add_child(back)


## 左上：デバッグメニューの開閉ボタン（歯車）。スマホから F3〜F10 相当を呼ぶ入口。
func _build_debug_gear() -> void:
	var gear := _make_button("⚙", 30)
	gear.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gear.size = Vector2(64, 64)
	gear.position = Vector2(16, 16)
	gear.pressed.connect(_toggle_debug_menu)
	_root.add_child(gear)


## 中央：デバッグ操作の一覧（既定は非表示）。各ボタンは F3〜F10 と同じアクションを流す。
func _build_debug_menu() -> void:
	_debug_menu = Panel.new()
	_debug_menu.add_theme_stylebox_override("panel", UITheme.washi(16, 0.94))
	_debug_menu.set_anchors_preset(Control.PRESET_CENTER)
	_debug_menu.size = Vector2(420, 560)
	_debug_menu.position = Vector2(-210, -280)
	_debug_menu.visible = false
	_root.add_child(_debug_menu)

	var box := VBoxContainer.new()
	box.position = Vector2(20, 20)
	box.size = Vector2(380, 520)
	box.add_theme_constant_override("separation", 10)
	_debug_menu.add_child(box)

	var title := Label.new()
	title.text = "デバッグメニュー"
	UITheme.style_label(title, UITheme.SIZE_DAY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# ラベル, アクション（HUD/FieldScene がこのアクションを受けて処理する）。
	var items := [
		["到達状況オーバーレイ (F3)", "debug_toggle"],
		["即エンディング判定 (F4)", "debug_end"],
		["裏エンド強制再生 (F5)", "debug_ura"],
		["散策画面へ (F6)", "debug_field"],
		["葵→ひまわり畑エンド (F7)", "debug_aoi_warmth"],
		["葵→丘エンド (F8)", "debug_aoi_shadow"],
		["葵→家エンド (F9)", "debug_aoi_closeness"],
		["歩行領域オーバーレイ (F10)", "debug_walk"],
	]
	for it in items:
		var b := _make_button(String(it[0]), 20)
		b.custom_minimum_size = Vector2(0, 44)
		# 押したら該当アクションを1回流し、メニューは閉じる（画面遷移を伴うものが邪魔にならない）。
		b.pressed.connect(_on_debug_item.bind(String(it[1])))
		box.add_child(b)

	var close := _make_button("閉じる", 22)
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(_close_debug_menu)
	box.add_child(close)


## デバッグ項目タップ：アクションを1回流してメニューを閉じる。
func _on_debug_item(action: String) -> void:
	_tap(action)
	_close_debug_menu()


func _toggle_debug_menu() -> void:
	_debug_open = not _debug_open
	_debug_menu.visible = _debug_open


func _close_debug_menu() -> void:
	_debug_open = false
	_debug_menu.visible = false


# --- ボタン生成の共通処理 -------------------------------------------

## 左下 D-pad 用：押下で action を pressed 保持、離すと release（＝移動が続く）。
func _add_hold_button(parent: Control, text: String, action: String, pos: Vector2) -> void:
	var b := _make_button(text, 36)
	b.size = Vector2(DPAD, DPAD)
	b.position = pos
	b.button_down.connect(func() -> void: _hold(action, true))
	b.button_up.connect(func() -> void: _hold(action, false))
	parent.add_child(b)


## 和紙テーマのボタン。押下中は差し色（夏空の青）。キーボード操作を邪魔しないよう focus は取らない。
func _make_button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UITheme.washi(16, 0.74))
	b.add_theme_stylebox_override("hover", UITheme.washi(16, 0.84))
	b.add_theme_stylebox_override("pressed", UITheme.accent(16))
	b.add_theme_stylebox_override("focus", UITheme.washi(16, 0.74))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_color_override("font_hover_color", UITheme.TEXT)
	b.add_theme_color_override("font_pressed_color", UITheme.TEXT)
	var f := UITheme.font()
	if f != null:
		b.add_theme_font_override("font", f)
	return b
