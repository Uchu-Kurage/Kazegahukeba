extends Control
## 見下ろしマップ（第10弾＝一日の流れ）。部屋で「今日はどこへ行こうか」と行き先エリアを選ぶ。
##
## 町を俯瞰した仮イラスト（コード描画）＋エリアのホットスポット。家は載せない（起点／戻る先）。
## エリアを選ぶ＝その半日の枠を確定（GameState.choose_area）。選んだエリアの入口画面へ飛ぶ。
## 「今日はやめておく」＝スキップ（end_halfday で phase を進めて部屋へ戻る）。
##
## 地理はマップ接続に寄せた配置：町＝中央（ハブ）／田園＝西／社＝北／川＝東／家＝南（起点）。
## 実イラストは後日差し替え可。矢印で方向選択（近い方へ）、［E］で決定。

const VIEW_W := 1152
const VIEW_H := 648

# エリアごとの地図上の位置（ホットスポットの中心）。
const AREA_POS := {
	"town": Vector2(576, 320),
	"farm": Vector2(286, 356),
	"shrine_area": Vector2(600, 168),
	"river": Vector2(872, 356),
}
const SKIP_POS := Vector2(576, 560)
const HOME_POS := Vector2(576, 476)

# 俯瞰イラスト（仮）の色。
const C_GRASS := Color(0.55, 0.62, 0.37)
const C_FIELD := Color(0.62, 0.67, 0.40)
const C_FIELD_LINE := Color(0.47, 0.53, 0.32)
const C_HILL := Color(0.45, 0.57, 0.35)
const C_RIVER := Color(0.44, 0.62, 0.80)
const C_ROAD := Color(0.80, 0.74, 0.58)
const C_TOWN := Color(0.74, 0.70, 0.60)
const C_ROOF := Color(0.63, 0.35, 0.30)
const C_TORII := Color(0.78, 0.28, 0.22)

var _spots: Array = []   ## { kind:"area"/"skip", id, center, enabled, panel, label }
var _cursor := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	HUD.set_shown(true)
	_build_spots()
	_build_ui()
	_cursor = _first_selectable()
	_refresh()
	AudioManager.play_ambient("cicada")
	HUD.set_prompt("矢印／WASD で選ぶ　・　［E］で決定")
	queue_redraw()


func _build_spots() -> void:
	for a in Areas.all():
		_spots.append({
			"kind": "area", "id": String(a["id"]),
			"center": AREA_POS.get(a["id"], Vector2(576, 324)),
			"enabled": bool(a.get("enabled", false)),
			"name": String(a["name"]), "hint": String(a.get("hint", "")),
		})
	_spots.append({ "kind": "skip", "id": "", "center": SKIP_POS, "enabled": true,
		"name": "今日はやめておく", "hint": "" })


# --- 入力（方向で選ぶ）-----------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_confirm()
	elif event.is_action_pressed("walk_left"):
		_move(Vector2.LEFT)
	elif event.is_action_pressed("walk_right"):
		_move(Vector2.RIGHT)
	elif event.is_action_pressed("walk_up"):
		_move(Vector2.UP)
	elif event.is_action_pressed("walk_down"):
		_move(Vector2.DOWN)


## 押した方向に最も近いホットスポットへカーソルを移す（地理的なナビ）。
func _move(dir: Vector2) -> void:
	var cur: Vector2 = _spots[_cursor]["center"]
	var best := -1
	var best_score := 1e20
	for i in _spots.size():
		if i == _cursor:
			continue
		var d: Vector2 = _spots[i]["center"] - cur
		var along := d.dot(dir)
		if along <= 1.0:
			continue  # その方向にない
		var perp: float = absf(d.dot(Vector2(dir.y, -dir.x)))
		var score := along + perp * 2.5
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_cursor = best
		AudioManager.play_sfx("move")
		_refresh()


func _confirm() -> void:
	var s: Dictionary = _spots[_cursor]
	if s["kind"] == "skip":
		AudioManager.play_sfx("cancel")
		GameState.end_halfday()
		Nav.go_to_field("home", "")
		return
	if not bool(s["enabled"]):
		AudioManager.play_sfx("cancel")
		HUD.set_prompt("「%s」は、まだ行けない。" % String(s["name"]))
		return
	AudioManager.play_sfx("confirm")
	GameState.choose_area(String(s["id"]))
	var entry := String(Areas.by_id(String(s["id"])).get("entry", ""))
	Nav.go_to_field(entry, "")


func _first_selectable() -> int:
	for i in _spots.size():
		if _spots[i]["kind"] == "area" and bool(_spots[i]["enabled"]):
			return i
	return 0


func _refresh() -> void:
	for i in _spots.size():
		var s: Dictionary = _spots[i]
		var selected := i == _cursor
		var panel: Panel = s["panel"]
		var sb: StyleBoxFlat
		if selected:
			sb = UITheme.washi(10, 0.98)
			sb.border_color = UITheme.ACCENT
			sb.set_border_width_all(3)
		else:
			sb = UITheme.washi(10, 0.82 if bool(s["enabled"]) else 0.5)
		panel.add_theme_stylebox_override("panel", sb)
		var label: Label = s["label"]
		if s["kind"] == "skip":
			label.text = String(s["name"])
		elif bool(s["enabled"]):
			label.text = String(s["name"])
		else:
			label.text = "%s（準備中）" % String(s["name"])
		label.modulate.a = 1.0 if (selected or bool(s["enabled"])) else 0.55


# --- 俯瞰イラスト（仮・コード描画）------------------------------------

func _draw() -> void:
	# 草地の下地。
	draw_rect(Rect2(0, 0, VIEW_W, VIEW_H), C_GRASS)
	# 川（東側）を上から下へ。
	draw_colored_polygon(PackedVector2Array([
		Vector2(760, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(880, 648),
		Vector2(940, 400), Vector2(820, 200),
	]), C_RIVER)
	# 田園（西側）＝畦のある田んぼ。
	draw_rect(Rect2(60, 220, 420, 320), C_FIELD)
	for r in 6:
		draw_line(Vector2(70, 250 + r * 46), Vector2(470, 250 + r * 46), C_FIELD_LINE, 2.0)
	# 社（北の丘）。
	draw_colored_polygon(PackedVector2Array([
		Vector2(430, 40), Vector2(770, 40), Vector2(720, 210), Vector2(480, 210),
	]), C_HILL)
	draw_rect(Rect2(560, 120, 80, 12), C_TORII)   # 鳥居の笠木
	draw_rect(Rect2(570, 120, 10, 60), C_TORII)   # 左柱
	draw_rect(Rect2(620, 120, 10, 60), C_TORII)   # 右柱
	# 町（中央のハブ）＝道と家並み。
	draw_rect(Rect2(470, 270, 220, 140), C_TOWN)
	for i in 3:
		draw_rect(Rect2(492 + i * 60, 292, 34, 34), C_ROOF)
	# 家（南＝起点）。小さな一軒。
	draw_rect(Rect2(HOME_POS.x - 34, HOME_POS.y - 24, 68, 44), Color(0.70, 0.66, 0.52))
	draw_rect(Rect2(HOME_POS.x - 40, HOME_POS.y - 36, 80, 16), C_ROOF)
	# 道：家 → 町 → 各エリア（細い土色の線）。
	draw_line(HOME_POS, AREA_POS["town"], C_ROAD, 6.0)
	draw_line(AREA_POS["town"], AREA_POS["farm"], C_ROAD, 6.0)
	draw_line(AREA_POS["town"], AREA_POS["shrine_area"], C_ROAD, 6.0)
	draw_line(AREA_POS["town"], AREA_POS["river"], C_ROAD, 6.0)


## 鳥居などの微調整用（社の中心 x をそのまま返すだけ。可読性のため関数化）。
func past_center(x: float) -> float:
	return x


# --- UI 構築 ---------------------------------------------------------

func _build_ui() -> void:
	# 見出し（上部に和紙の小札）。
	var title := Label.new()
	title.position = Vector2(40, 28)
	title.size = Vector2(520, 40)
	title.text = "今日は、どこへ行こうか"
	UITheme.style_label(title, UITheme.SIZE_DAY)
	var tb := UITheme.washi(12, 0.9)
	tb.content_margin_left = 16
	tb.content_margin_right = 16
	tb.content_margin_top = 6
	tb.content_margin_bottom = 6
	title.add_theme_stylebox_override("normal", tb)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# 家のラベル（選べない＝起点の目印）。
	var home_label := Label.new()
	home_label.position = Vector2(HOME_POS.x - 24, HOME_POS.y + 22)
	home_label.text = "家"
	UITheme.style_label(home_label, UITheme.SIZE_SMALL)
	home_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(home_label)

	# ホットスポット（エリア＋スキップ）を地図上に置く。
	for s in _spots:
		var is_skip: bool = s["kind"] == "skip"
		var w: int = 220 if is_skip else 168
		var h: int = 46 if is_skip else 60
		var panel := Panel.new()
		panel.size = Vector2(w, h)
		panel.position = Vector2(s["center"]) - panel.size / 2.0
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		var label := Label.new()
		label.size = panel.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_label(label, UITheme.SIZE_CHOICE if not is_skip else UITheme.SIZE_SMALL)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		s["panel"] = panel
		s["label"] = label
