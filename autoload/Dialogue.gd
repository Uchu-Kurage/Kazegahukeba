extends CanvasLayer
## 会話ウィンドウ（Autoload）。専用の立ち絵は使わず、マップ上のドット絵キャラのまま、
## 画面下のテキストボックスで会話を進める。
##
## 会話は「ノード」の配列で渡す。ノードは2種類:
##   セリフ   : { "speaker": "球磨", "text": "よう。" }（speaker "" は地の文）
##   選択肢   : { "text": 質問文(省略可), "choices": [ 選択肢, ... ] }
##     選択肢 : { "text": "ああ", "affinity": {"kuma": 2}, "set": {"flag": true},
##              "then": [ さらに続くノード ... ] }
##
## E で送り／決定。選択肢を選ぶと option_selected(option) を出し（効果の反映は呼び出し側が担当）、
## その "then" があれば続けて再生する。最後まで行くと finished を出す。

signal finished
signal option_selected(option: Dictionary)

const CHAR_TIME := 0.025  # 1文字あたりの表示秒（タイプライター演出）

var _nodes: Array = []
var _index := -1
var _active := false
var _revealing := false
var _accum := 0.0

var _choosing := false
var _choices: Array = []
var _choice_index := 0
var _choice_labels: Array = []

var _root: Control
var _box: Panel
var _name: Label
var _text: Label
var _hint: Label
var _choice_box: VBoxContainer
var _name_sb: StyleBox
var _choice_sel_sb: StyleBoxFlat
var _choice_unsel_sb: StyleBoxFlat

## 一時停止（入手演出など）の数。0 より大きい間は枠を隠し、次のノードへ進まない。
## 効果ノードで道具や風物詩を手に入れた瞬間に演出を割り込ませ、終わってから続きを流すため。
var _hold := 0
var _resume_pending := false  # 一時停止中に「次のノードへ進む」が来た（解除したら進める）


func _ready() -> void:
	layer = 5  # HUD より手前に出す
	_build_ui()


func is_active() -> bool:
	return _active


## 会話を即座に閉じる（finished は出さない）。オープニングの既読スキップなど、
## 進行中の会話を「なかったこと」にして別シーンへ抜けるときに使う（第13弾）。
func dismiss() -> void:
	_active = false
	_hold = 0
	_resume_pending = false
	_revealing = false
	_choosing = false
	if _root != null:
		_root.visible = false


## 会話を一時停止する（枠を隠す）。入手演出（AcquireFanfare）が効果ノードの直後に呼ぶ。
## 停止中は送りを受け付けず、効果ノードの次へも進まない。release() と対で使う。
func hold() -> void:
	_hold += 1
	if _root != null:
		_root.visible = false


## 一時停止を解く。全部解けたら枠を戻し、止めていた「次のノードへ」を再開する
## （効果ノードが会話の最後なら、ここで finished が出る＝後片付けは演出のあとになる）。
func release() -> void:
	if _hold <= 0:
		return
	_hold -= 1
	if _hold > 0 or not _active:
		return
	_root.visible = true
	if _resume_pending:
		_resume_pending = false
		_next_node()


func is_held() -> bool:
	return _hold > 0


## 会話を開始する。nodes はセリフ／選択肢ノードの配列。
func start(nodes: Array) -> void:
	if nodes.is_empty():
		finished.emit()
		return
	_nodes = nodes.duplicate()  # then の差し込みで書き換えるので複製しておく
	_index = -1
	_active = true
	_resume_pending = false
	_fit_to_touch_ui()
	_root.visible = true
	_next_node()


func _input(event: InputEvent) -> void:
	if not _active or _hold > 0:
		return  # 一時停止中の入力は演出側（スキップ）に渡す
	if _choosing:
		if event.is_action_pressed("walk_up"):
			get_viewport().set_input_as_handled()
			_move_choice(-1)
		elif event.is_action_pressed("walk_down"):
			get_viewport().set_input_as_handled()
			_move_choice(1)
		elif event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_confirm_choice()
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # 背後のシーンに E を渡さない
		_advance_line()


func _process(delta: float) -> void:
	if not _active or _hold > 0:
		return
	if _revealing:
		_accum += delta
		var total := _current_len()
		var shown := int(_accum / CHAR_TIME)
		if shown >= total:
			_text.visible_characters = -1
			_revealing = false
		else:
			_text.visible_characters = shown
	elif not _choosing:
		# 送り待ちのあいだ、続行マークをゆっくり明滅させる（薄くなりすぎて見失わないよう 0.6〜1.0）。
		_hint.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.006))


# --- ノード送り ------------------------------------------------------

func _next_node() -> void:
	_index += 1
	if _index >= _nodes.size():
		_end()
		return
	var node: Dictionary = _nodes[_index]
	if node.has("effect"):
		# 表示しない効果ノード：フラグ/好感度などを反映して、そのまま次へ。
		option_selected.emit(node["effect"])
		_continue()
	elif node.has("choices"):
		_show_choices(node)
	else:
		_show_line(node)


func _advance_line() -> void:
	if _revealing:
		_text.visible_characters = -1  # 表示途中なら、まず全文を出す
		_revealing = false
		return
	AudioManager.play_sfx("talk")
	_next_node()


func _show_line(node: Dictionary) -> void:
	_choosing = false
	_choice_box.visible = false
	_hint.text = "▼"
	_hint.visible = true
	_hint.modulate.a = 1.0
	_set_speaker(String(node.get("speaker", "")))
	_text.text = String(node.get("text", ""))
	_text.visible_characters = 0
	_accum = 0.0
	_revealing = true


## 話者名タグを設定（和紙質感で統一。地の文は隠す）。
func _set_speaker(speaker: String) -> void:
	_name.text = " " + speaker + " "
	_name.visible = speaker != ""


# --- 選択肢 ----------------------------------------------------------

func _show_choices(node: Dictionary) -> void:
	_revealing = false
	# 質問文があれば出す。無ければ直前のセリフをそのまま残す。
	if node.has("text"):
		_set_speaker(String(node.get("speaker", "")))
		_text.text = String(node["text"])
		_text.visible_characters = -1
	_choices = node["choices"]
	_choice_index = 0
	_choosing = true
	_hint.visible = false  # 選択中は文字送り▼を隠す
	_build_choice_labels()
	_choice_box.visible = true


func _build_choice_labels() -> void:
	for l in _choice_labels:
		l.free()
	_choice_labels.clear()
	for i in _choices.size():
		var lbl := Label.new()
		UITheme.style_label(lbl, UITheme.SIZE_CHOICE)  # 丸ゴシック・ダークグレー・薄い縁取り
		lbl.custom_minimum_size = Vector2(236, 64)  # 幅をそろえ、高さは指で押せる大きさに（スマホで約 40pt）
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 選択肢は直接タップ／クリックでも選べる（方向キー＋決定と同じ結果）。
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.gui_input.connect(_on_choice_input.bind(i))
		lbl.mouse_entered.connect(_on_choice_hover.bind(i))
		_choice_box.add_child(lbl)
		_choice_labels.append(lbl)
	_update_choice_highlight()


func _update_choice_highlight() -> void:
	for i in _choice_labels.size():
		var lbl: Label = _choice_labels[i]
		var opt: Dictionary = _choices[i]
		var selected := i == _choice_index
		# 番号付き（イメージボード準拠）。選択は矢印ではなく夏空の青の縁で示す。
		lbl.text = "%d. %s" % [i + 1, String(opt.get("text", ""))]
		# 文字は常に暖かいダークグレー（白抜きにしない）。選択中だけ青の縁が乗る差で見せる。
		lbl.add_theme_color_override("font_color", UITheme.TEXT)
		lbl.add_theme_stylebox_override("normal", _choice_sel_sb if selected else _choice_unsel_sb)


## 選択肢を直接タップ／クリック：その項目を選んで決定する。
func _on_choice_input(event: InputEvent, i: int) -> void:
	if not _choosing:
		return
	# タッチは Godot がマウスのクリックに変換して届ける（emulate_mouse_from_touch）。
	# ScreenTouch も拾うと1回のタップが2回に数えられるので、マウスのクリックだけを見る。
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if tapped:
		get_viewport().set_input_as_handled()
		_choice_index = i
		_update_choice_highlight()
		_choosing = false  # 決定までの間に重ねてタップされても二重に決定しない
		# 続く選択肢でラベルを作り直す（free）ことがあるので、このラベルの入力処理を抜けてから決定する。
		_confirm_choice.call_deferred()


## マウスを重ねた選択肢を選択状態にする（PC。決定はクリックか E）。
func _on_choice_hover(i: int) -> void:
	if _choosing and i != _choice_index:
		_choice_index = i
		AudioManager.play_sfx("blip")
		_update_choice_highlight()


func _move_choice(delta: int) -> void:
	var prev := _choice_index
	_choice_index = clampi(_choice_index + delta, 0, _choices.size() - 1)
	if _choice_index != prev:
		AudioManager.play_sfx("blip")
	_update_choice_highlight()


func _confirm_choice() -> void:
	var opt: Dictionary = _choices[_choice_index]
	AudioManager.play_sfx("confirm")
	_choosing = false
	_choice_box.visible = false
	option_selected.emit(opt)  # 効果（好感度・フラグ）の反映は呼び出し側にまかせる
	# 選んだ枝(then)を、いまの位置の直後に差し込む。
	var branch: Array = opt.get("then", [])
	for i in branch.size():
		_nodes.insert(_index + 1 + i, branch[i])
	_continue()


## 効果の反映（option_selected）のあとに次へ進む。反映中に入手演出が一時停止を掛けたら、
## 解除（release）まで進めずに待つ。
func _continue() -> void:
	if _hold > 0:
		_resume_pending = true
		return
	_next_node()


func _end() -> void:
	_active = false
	_revealing = false
	_choosing = false
	_root.visible = false
	finished.emit()


## スマホ（タッチUI表示中）は右下の決定／戻るに本文が隠れないよう、会話枠の幅を詰める。
func _fit_to_touch_ui() -> void:
	var w := 744.0 if TouchControls.is_shown() else 886.0
	_box.size.x = w
	_text.size.x = w - 86.0
	_hint.position.x = w - 42.0


## 会話枠そのものをタップ／クリックしても送れる（スマホでは決定ボタンへ指を動かさずに済む）。
func _on_box_input(event: InputEvent) -> void:
	if not _active or _choosing:
		return
	# タッチは Godot がマウスのクリックに変換して届ける（emulate_mouse_from_touch）。
	# ScreenTouch も拾うと1回のタップが2回に数えられるので、マウスのクリックだけを見る。
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if tapped:
		get_viewport().set_input_as_handled()
		_advance_line()


func _current_len() -> int:
	return String(_nodes[_index].get("text", "")).length()


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# メッセージ枠：繊維の入った和紙（半透明・角丸・ちぎった縁・やわらかい影）。硬い黒箱にしない。
	# イメージボードに合わせ、画面下の左〜中央（右側は選択肢の場所を空ける）。本文は三行まで。
	_box = Panel.new()
	_box.position = Vector2(24, 446)
	_box.size = Vector2(886, 178)
	_box.add_theme_stylebox_override("panel", UITheme.washi_paper())
	_box.gui_input.connect(_on_box_input)
	_root.add_child(_box)

	# 話者名タグ：枠と同じ和紙質感の独立したピルで、枠の左上に少し上へ浮かせて重ねる。
	_name = Label.new()
	_name.position = Vector2(40, -22)
	UITheme.style_label(_name, UITheme.SIZE_NAME)
	_name_sb = UITheme.washi_paper(true, 0.97)
	_name_sb.content_margin_left = 18
	_name_sb.content_margin_right = 18
	_name_sb.content_margin_top = 3
	_name_sb.content_margin_bottom = 5
	_name.add_theme_stylebox_override("normal", _name_sb)
	_box.add_child(_name)

	# 本文：暖かいダークグレー（和紙の上なので縁取りなし）。行間を少しあけて読みやすく。
	_text = Label.new()
	_text.position = Vector2(40, 34)
	_text.size = Vector2(800, 124)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_text, UITheme.SIZE_BODY)
	_text.add_theme_constant_override("line_spacing", 4)
	_box.add_child(_text)

	# 文字送りの三角（▼）。枠の右下で「続きがある」ことを示す（夏空の青）。
	_hint = Label.new()
	_hint.text = "▼"
	_hint.position = Vector2(844, 138)
	UITheme.style_label(_hint, UITheme.SIZE_SMALL)
	_hint.add_theme_color_override("font_color", UITheme.ACCENT_LINE)
	_box.add_child(_hint)

	# 選択肢：画面右側に縦積みの和紙ピル。選択中だけ夏空の青が乗る。
	_choice_box = VBoxContainer.new()
	_choice_box.position = Vector2(884, 196)
	_choice_box.add_theme_constant_override("separation", 12)
	_choice_box.visible = false
	_root.add_child(_choice_box)
	_choice_sel_sb = UITheme.chip_selected(14)
	_choice_unsel_sb = UITheme.chip(14)
