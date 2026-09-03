extends CanvasLayer
## 会話ウィンドウ（Autoload）。専用の立ち絵は使わず、マップ上のドット絵キャラのまま、
## 画面下のテキストボックスで会話を進める。E で送り、最後の行まで行くと finished を出す。
##
## 使い方:
##   Dialogue.finished.connect(_on_done, CONNECT_ONE_SHOT)
##   Dialogue.start([{ "speaker": "球磨", "text": "よう。" }, ...])

signal finished

const CHAR_TIME := 0.025  # 1文字あたりの表示秒（タイプライター演出）

var _lines: Array = []
var _index := 0
var _active := false
var _revealing := false
var _accum := 0.0

var _root: Control
var _box: Panel
var _name: Label
var _text: Label
var _hint: Label


func _ready() -> void:
	layer = 5  # HUD より手前に出す
	_build_ui()


func is_active() -> bool:
	return _active


## 会話を開始する。lines は { "speaker", "text" } の配列。speaker が "" なら地の文。
func start(lines: Array) -> void:
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_index = 0
	_active = true
	_root.visible = true
	_show_line()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # 背後のシーンに E を渡さない
		_advance()


func _process(delta: float) -> void:
	if not _active or not _revealing:
		return
	_accum += delta
	var total := _current_len()
	var shown := int(_accum / CHAR_TIME)
	if shown >= total:
		_text.visible_characters = -1
		_revealing = false
	else:
		_text.visible_characters = shown


func _advance() -> void:
	if _revealing:
		_text.visible_characters = -1  # 表示途中なら、まず全文を出す
		_revealing = false
		return
	_index += 1
	if _index >= _lines.size():
		_end()
	else:
		_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker := String(line.get("speaker", ""))
	_name.text = speaker
	_name.visible = speaker != ""
	_text.text = String(line.get("text", ""))
	_text.visible_characters = 0
	_accum = 0.0
	_revealing = true


func _end() -> void:
	_active = false
	_revealing = false
	_root.visible = false
	finished.emit()


func _current_len() -> int:
	return String(_lines[_index].get("text", "")).length()


## UI をコードで組み立てる（.tscn を使わずに完結させる）。
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_box = Panel.new()
	_box.position = Vector2(48, 430)
	_box.size = Vector2(1056, 180)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.93)
	sb.border_color = Color(0.90, 0.85, 0.60, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	_box.add_theme_stylebox_override("panel", sb)
	_root.add_child(_box)

	_name = Label.new()
	_name.position = Vector2(24, 16)
	_name.add_theme_font_size_override("font_size", 24)
	_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50))
	_box.add_child(_name)

	_text = Label.new()
	_text.position = Vector2(24, 58)
	_text.size = Vector2(1008, 100)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 22)
	_box.add_child(_text)

	_hint = Label.new()
	_hint.text = "［E］▶"
	_hint.position = Vector2(972, 148)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.modulate = Color(1, 1, 1, 0.6)
	_box.add_child(_hint)
