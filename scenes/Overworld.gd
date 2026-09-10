extends Control
## 見下ろしマップ（第10弾＝一日の流れ）。部屋で「今日はどこへ行こうか」と行き先エリアを選ぶ。
##
## 家は載せない（起点／戻る先）。4エリア（町・田園・社・川）から午前／午後の行き先を選ぶ。
## エリアを選ぶ＝その半日の枠を確定（GameState.choose_area）。選んだエリアの入口画面へ飛ぶ。
## 「今日はやめておく」＝スキップ（end_halfday で phase を進めて部屋へ戻る）。
##
## 見た目は仮（和紙のリスト）。将来は町を俯瞰したイラスト＋エリアのホットスポットに寄せられる。
## 段階導入のため、いまは川エリアだけ選べる（他は「準備中」）。

const VIEW_W := 1152
const VIEW_H := 648

var _rows: Array = []       ## { kind:"area"/"skip", area:Dictionary }
var _labels: Array = []     ## 各行の Label
var _cursor := 0
var _panel: Panel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	HUD.set_shown(true)
	_build_rows()
	_build_ui()
	# 最初のカーソルは、選べる最初の行に置く。
	_cursor = _first_selectable()
	_refresh()
	AudioManager.play_ambient("cicada")
	HUD.set_prompt("矢印／WASD で選ぶ　・　［E］で決定")


func _build_rows() -> void:
	for a in Areas.all():
		_rows.append({ "kind": "area", "area": a })
	_rows.append({ "kind": "skip" })


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("walk_up"):
		_move(-1)
	elif event.is_action_pressed("walk_down"):
		_move(1)
	elif event.is_action_pressed("interact"):
		_confirm()


func _move(delta: int) -> void:
	_cursor = clampi(_cursor + delta, 0, _rows.size() - 1)
	AudioManager.play_sfx("move")
	_refresh()


func _confirm() -> void:
	var row: Dictionary = _rows[_cursor]
	if row["kind"] == "skip":
		AudioManager.play_sfx("cancel")
		GameState.end_halfday()   # その半日を使わずに終える（＝スキップ。一日は消費する）
		Nav.go_to_field("home", "")
		return
	var a: Dictionary = row["area"]
	if not bool(a.get("enabled", false)):
		AudioManager.play_sfx("cancel")
		HUD.set_prompt("「%s」は、まだ行けない。" % String(a["name"]))
		return
	AudioManager.play_sfx("confirm")
	GameState.choose_area(String(a["id"]))    # ここで半日の枠が確定する
	Nav.go_to_field(String(a["entry"]), "")   # そのエリアの入口画面へ飛ぶ


func _refresh() -> void:
	for i in _labels.size():
		var row: Dictionary = _rows[i]
		var label: Label = _labels[i]
		var selected := i == _cursor
		var text := ""
		var enabled := true
		if row["kind"] == "skip":
			text = "今日はやめておく"
		else:
			var a: Dictionary = row["area"]
			enabled = bool(a.get("enabled", false))
			if enabled:
				text = "%s　―　%s" % [String(a["name"]), String(a.get("hint", ""))]
			else:
				text = "%s　（準備中）" % String(a["name"])
		label.text = ("▶ " if selected else "　") + text
		if not enabled and row["kind"] == "area":
			label.modulate.a = 0.4
		else:
			label.modulate.a = 1.0 if selected else 0.82


func _first_selectable() -> int:
	for i in _rows.size():
		var row: Dictionary = _rows[i]
		if row["kind"] == "area" and bool(row["area"].get("enabled", false)):
			return i
	return 0


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.12, 0.16, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Panel.new()
	_panel.position = Vector2(276, 120)
	_panel.size = Vector2(600, 408)
	_panel.add_theme_stylebox_override("panel", UITheme.washi(20))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var title := Label.new()
	title.position = Vector2(40, 28)
	title.size = Vector2(520, 40)
	title.text = "今日は、どこへ行こうか"
	UITheme.style_label(title, UITheme.SIZE_DAY)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(title)

	var y := 96
	for i in _rows.size():
		var label := Label.new()
		label.position = Vector2(56, y)
		label.size = Vector2(500, 40)
		UITheme.style_label(label, UITheme.SIZE_CHOICE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(label)
		_labels.append(label)
		y += 56
