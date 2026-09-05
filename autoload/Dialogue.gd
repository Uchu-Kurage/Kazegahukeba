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
var _name_sb: StyleBoxFlat
var _choice_sel_sb: StyleBoxFlat
var _choice_unsel_sb: StyleBoxFlat


func _ready() -> void:
	layer = 5  # HUD より手前に出す
	_build_ui()


func is_active() -> bool:
	return _active


## 会話を開始する。nodes はセリフ／選択肢ノードの配列。
func start(nodes: Array) -> void:
	if nodes.is_empty():
		finished.emit()
		return
	_nodes = nodes.duplicate()  # then の差し込みで書き換えるので複製しておく
	_index = -1
	_active = true
	_root.visible = true
	_next_node()


func _input(event: InputEvent) -> void:
	if not _active:
		return
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
	if not _active:
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
		# 送り待ちのあいだ、続行マークを点滅させる。
		_hint.modulate.a = 0.35 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.006))


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
		_next_node()
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
	_hint.modulate.a = 0.7
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
		_choice_box.add_child(lbl)
		_choice_labels.append(lbl)
	_update_choice_highlight()


func _update_choice_highlight() -> void:
	for i in _choice_labels.size():
		var lbl: Label = _choice_labels[i]
		var opt: Dictionary = _choices[i]
		var selected := i == _choice_index
		var mark := "▶ " if selected else "　 "
		lbl.text = mark + String(opt.get("text", ""))
		# 文字は常に暖かいダークグレー（白抜きにしない）。選択中だけ夏空の青の下地が乗る差で見せる。
		lbl.add_theme_color_override("font_color", UITheme.TEXT)
		lbl.add_theme_stylebox_override("normal", _choice_sel_sb if selected else _choice_unsel_sb)


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
	_next_node()


func _end() -> void:
	_active = false
	_revealing = false
	_choosing = false
	_root.visible = false
	finished.emit()


func _current_len() -> int:
	return String(_nodes[_index].get("text", "")).length()


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	# メッセージ枠：和紙・すりガラス（半透明・角丸・薄い縁・やわらかい影）。硬い黒箱にしない。
	_box = Panel.new()
	_box.position = Vector2(48, 412)
	_box.size = Vector2(1056, 196)
	_box.add_theme_stylebox_override("panel", UITheme.washi())
	_root.add_child(_box)

	# 話者名タグ：枠と同じ和紙質感で、枠の左上に少し上へはみ出して重ねる。
	_name = Label.new()
	_name.position = Vector2(28, -18)
	UITheme.style_label(_name, UITheme.SIZE_NAME)
	_name_sb = UITheme.washi(10)
	_name_sb.content_margin_left = 14
	_name_sb.content_margin_right = 14
	_name_sb.content_margin_top = 3
	_name_sb.content_margin_bottom = 3
	_name.add_theme_stylebox_override("normal", _name_sb)
	_box.add_child(_name)

	# 本文：暖かいダークグレー＋薄い縁取り（どんな背景でも読めるように）。
	_text = Label.new()
	_text.position = Vector2(28, 30)
	_text.size = Vector2(1000, 120)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_text, UITheme.SIZE_BODY)
	_box.add_child(_text)

	_choice_box = VBoxContainer.new()
	_choice_box.position = Vector2(40, 118)
	_choice_box.add_theme_constant_override("separation", 6)
	_choice_box.visible = false
	_box.add_child(_choice_box)

	# 選択肢：選択中は夏空の青の和紙、未選択はごく薄い和紙。
	_choice_sel_sb = UITheme.accent(10)
	_choice_unsel_sb = UITheme.chip(10)

	# 文字送りの三角（▼）。枠の右下で「続きがある」ことを示す。
	_hint = Label.new()
	_hint.text = "▼"
	_hint.position = Vector2(1012, 150)
	UITheme.style_label(_hint, UITheme.SIZE_HINT)
	_hint.modulate = Color(1, 1, 1, 0.7)
	_box.add_child(_hint)
