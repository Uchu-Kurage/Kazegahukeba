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

const DPAD := 128         # D-pad ボタンの一辺（指で押しやすいよう大きめに）
const ACT := 150          # 決定ボタンの一辺
const BACK_W := 132       # 戻るボタンの横幅（縦は決定と揃える）
const GAP := 28           # 決定と戻るの間隔
const MARGIN := 48        # 画面左右端からの余白
const BOTTOM_MARGIN := 72 # 画面下端からの余白（端末のジェスチャーバーを避けて上げる）

# --- フィールド移動＝フローティング仮想スティック ------------------------------------
const STICK_RADIUS := 95.0    # 最大傾き（この距離で最高速）
const STICK_KNOB := 46.0      # つまみ（内円）の半径
const STICK_DEADZONE := 0.12  # これ未満の傾きは無視（指のわずかな揺れで動かないように）
const STICK_AREA_RIGHT := 0.6 # 画面左側のこの割合を反応エリアに（右側の決定/戻る等と干渉させない）

var _root: Control
var _debug_menu: Panel
var _debug_open := false

## フィールド移動：仮想スティックの傾き（長さ≤1＝速度の強弱）。Player が毎フレーム読む。
var move_vec := Vector2.ZERO

var _dpad: Control          # メニュー用の方向キー（項目選択。フィールドでは隠す）
var _stick_area: Control    # フィールド用スティックの反応エリア（画面左側）
var _stick_base: Panel      # スティックの外円（触れた位置に出す）
var _stick_knob: Panel      # スティックのつまみ（内円）
var _stick_active := false
var _stick_touch := -1      # 追従中のタッチ指の index（マウスは -1）
var _stick_origin := Vector2.ZERO


func _ready() -> void:
	layer = 128  # HUD より手前に描く（HUD は既定レイヤ）。
	# 予定表（約束帳）は開くとツリーを一時停止する（get_tree().paused）。停止中でも画面ボタンで
	# 操作できるよう、タッチUIは常時処理する（＝予定表の開閉・カーソル移動・詳細をスマホで行える）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	# タッチ端末のときだけ表示（それ以外は邪魔にならないよう隠す）。
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_root.visible = touch or FORCE_SHOW


## フィールド（主人公を歩かせる画面）ではスティック、メニューでは方向キー、と毎フレーム出し分ける。
func _process(_dt: float) -> void:
	if _root == null or not _root.visible:
		return
	var menu := _in_menu_mode()
	if _dpad != null:
		_dpad.visible = menu
	if _stick_area != null:
		_stick_area.visible = not menu
		if menu and _stick_active:
			_reset_stick()


## メニュー操作モードか（＝方向キーを出す）。予定帳を開いている間、会話中（選択肢を上下で選ぶ）、
## または主人公がいない画面（タイトル・見下ろしマップ等）。
func _in_menu_mode() -> bool:
	if Book.is_open():
		return true
	if Dialogue.is_active():  # 会話中は選択肢を方向キーで選ぶ（フィールドでもスティックにしない）
		return true
	return get_tree().get_first_node_in_group("player") == null


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
	# 予定帳が開いている間は、合成入力ではなく Book を直接操作する（停止中でも確実に効く）。
	# D-pad はカーソル移動なので、押した瞬間（down）だけ1回動かす。
	if Book.is_open():
		if down:
			Book.act(action)
		return
	_emit(action, down)


## 単発用（決定・戻る・メニュー上下・デバッグ）。押して即離す＝1回のエッジ。
func _tap(action: String) -> void:
	# 予定帳が開いている間は、合成入力ではなく Book を直接操作する（停止中でも確実に効く）。
	if Book.is_open():
		Book.act(action)
		return
	_emit(action, true)
	_emit(action, false)


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 空きスペースは背後（ゲーム）へ素通し
	add_child(_root)

	_build_joystick()  # フィールド用スティック（左側）。ボタン類より先に置いて背面にする。
	_build_dpad()      # メニュー用の方向キー（フィールドでは隠す）
	_build_action_buttons()
	_build_book_button()
	_build_debug_gear()
	_build_debug_menu()


## 左下：十字キー（移動・カーソル・会話送りの上下）。押下保持で歩ける。
func _build_dpad() -> void:
	var pad := Control.new()
	pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var span := DPAD * 3 + 24
	pad.offset_left = MARGIN
	pad.offset_top = -(span + BOTTOM_MARGIN)
	pad.offset_right = MARGIN + span
	pad.offset_bottom = -BOTTOM_MARGIN
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pad)
	_dpad = pad

	var mid := DPAD + 12
	_add_hold_button(pad, "▲", "walk_up",    Vector2(mid, 0))
	_add_hold_button(pad, "◀", "walk_left",  Vector2(0, mid))
	_add_hold_button(pad, "▶", "walk_right", Vector2(mid * 2, mid))
	_add_hold_button(pad, "▼", "walk_down",  Vector2(mid, mid * 2))


## フィールド用のフローティング仮想スティック。画面左側の触れた場所に出て、なぞった方向へ移動。
## 傾き（引っ張り具合）で速度も変わる。指を離すと停止。反応エリアは決定/戻ると干渉しない左側だけ。
func _build_joystick() -> void:
	_stick_area = Control.new()
	_stick_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick_area.anchor_right = STICK_AREA_RIGHT  # 左側だけを反応エリアにする
	_stick_area.offset_right = 0
	_stick_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_stick_area.visible = false
	_stick_area.gui_input.connect(_on_stick_input)
	_root.add_child(_stick_area)

	_stick_base = _make_ring(STICK_RADIUS, UITheme.washi(16, 0.32))
	_stick_area.add_child(_stick_base)
	_stick_knob = _make_ring(STICK_KNOB, UITheme.accent(16))
	_stick_area.add_child(_stick_knob)


## 円形のパネル（スティックの外円・つまみ）を作る。角丸を半径いっぱいにして円に見せる。
func _make_ring(radius: float, sb: StyleBoxFlat) -> Panel:
	var p := Panel.new()
	p.size = Vector2(radius * 2.0, radius * 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sb.set_corner_radius_all(int(radius))
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	return p


## スティック反応エリアのタッチ／ドラッグ／（確認用に）マウスを処理する。
func _on_stick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if not _stick_active:
				_stick_active = true
				_stick_touch = t.index
				_begin_stick(t.position)
		elif t.index == _stick_touch:
			_reset_stick()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _stick_active and d.index == _stick_touch:
			_update_stick(d.position)
	elif event is InputEventMouseButton:  # デスクトップ確認用（FORCE_SHOW）
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_stick_active = true
				_stick_touch = -1
				_begin_stick(mb.position)
			else:
				_reset_stick()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _stick_active and _stick_touch == -1:
			_update_stick(mm.position)


## 触れた場所を中心にスティックを表示して追従を開始する（座標はエリア内ローカル）。
func _begin_stick(pos: Vector2) -> void:
	_stick_origin = pos
	_stick_base.position = pos - Vector2(STICK_RADIUS, STICK_RADIUS)
	_stick_base.visible = true
	_stick_knob.visible = true
	_update_stick(pos)


## つまみ位置と move_vec を更新する。中心からの距離を最大半径で正規化し、速度の強弱にする。
func _update_stick(pos: Vector2) -> void:
	var clamped := (pos - _stick_origin).limit_length(STICK_RADIUS)
	_stick_knob.position = _stick_origin + clamped - Vector2(STICK_KNOB, STICK_KNOB)
	var v := clamped / STICK_RADIUS
	move_vec = Vector2.ZERO if v.length() < STICK_DEADZONE else v


## スティックを離した／メニューへ切り替わったとき：移動を止めて隠す。
func _reset_stick() -> void:
	_stick_active = false
	_stick_touch = -1
	move_vec = Vector2.ZERO
	if _stick_base != null:
		_stick_base.visible = false
	if _stick_knob != null:
		_stick_knob.visible = false


## 右下：決定（E）と戻る（Q）。会話送り・入る・話す・戻る・スキップに対応。
func _build_action_buttons() -> void:
	var wrap := Control.new()
	wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	wrap.offset_left = -(BACK_W + GAP + ACT + MARGIN)
	wrap.offset_top = -(ACT + BOTTOM_MARGIN)
	wrap.offset_right = -MARGIN
	wrap.offset_bottom = -BOTTOM_MARGIN
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wrap)

	# 戻る（左）と決定（右）を同じ高さで並べる。決定は右端＝親指が届きやすい位置。
	var back := _make_button("戻る", 32)
	back.size = Vector2(BACK_W, ACT)
	back.position = Vector2(0, 0)
	back.pressed.connect(func() -> void: _tap("skip"))
	wrap.add_child(back)

	var confirm := _make_button("決定", 40)
	confirm.size = Vector2(ACT, ACT)
	confirm.position = Vector2(BACK_W + GAP, 0)
	confirm.pressed.connect(func() -> void: _tap("interact"))
	wrap.add_child(confirm)


## 右上：予定表（約束帳）を開く／閉じる。スマホにはキーボードが無いので画面ボタンで橋渡し。
##   開いている間は、既存の十字キー＝日付選択／決定＝詳細／戻る＝閉じる がそのまま使える。
func _build_book_button() -> void:
	var book := _make_button("予定表", 28)
	book.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	book.offset_left = -(140 + MARGIN)
	book.offset_top = 20
	book.offset_right = -MARGIN
	book.offset_bottom = 20 + 64
	# 開閉とも Book を直接操作する（一時停止中でも確実に開閉できるよう合成入力に頼らない）。
	book.pressed.connect(func() -> void: Book.act("book"))
	_root.add_child(book)


## 左上：デバッグメニューの開閉ボタン（歯車）。スマホから F3〜F10 相当を呼ぶ入口。
func _build_debug_gear() -> void:
	var gear := _make_button("⚙", 34)
	gear.set_anchors_preset(Control.PRESET_TOP_LEFT)
	gear.size = Vector2(72, 72)
	gear.position = Vector2(20, 20)
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
	var b := _make_button(text, 44)
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
