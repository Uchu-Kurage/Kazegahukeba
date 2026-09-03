extends Area2D
## 場所の中(Place)に置く対象。中の人(NPC) または 出口。
##
## プレイヤーが近づくと明るくなり、E で反応する（NPCなら会話、出口なら街へ戻る）。
## NPC は専用の立ち絵を使わず、ドット絵風の簡易キャラとして _draw() で描く。
## あとで AnimatedSprite2D（本物のドット絵）に差し替えても、当たり判定や信号はそのまま。

## プレイヤーが範囲に出入りしたことを Place へ知らせる。
signal player_entered(spot: Area2D)
signal player_exited(spot: Area2D)

var location_id := ""
var display_name := ""
var character_id := ""

var _selected := false
var _label: Label


## マップ生成時に呼ばれ、この対象の中身を設定する。
func setup(id: String, disp_name: String, who: String, pos: Vector2) -> void:
	location_id = id
	display_name = disp_name
	character_id = who
	position = pos


func _ready() -> void:
	add_to_group("location_spots")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_label = Label.new()
	_label.text = display_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(160, 0)
	_label.position = Vector2(-80, 34)
	add_child(_label)

	queue_redraw()


## 近づいたとき明るくする（＝反応できる合図）。
func set_highlight(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 24), 15.0, Color(0, 0, 0, 0.25))  # 影
	if character_id != "":
		_draw_person(_char_color())
	else:
		_draw_marker()
	if _selected:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.25), 3.0, true)


## ドット絵風の人物（頭＋体）。色はキャラごと。
func _draw_person(c: Color) -> void:
	draw_rect(Rect2(-12, -6, 24, 30), c)                        # 体
	draw_circle(Vector2(0, -16), 11.0, Color(0.98, 0.90, 0.80)) # 頭
	draw_rect(Rect2(-11, -27, 22, 9), c.darkened(0.35))         # 髪


## 出口／無人の場所は看板風のマーカー。
func _draw_marker() -> void:
	draw_rect(Rect2(-16, -18, 32, 38), Color(0.55, 0.50, 0.42))
	draw_rect(Rect2(-16, -18, 32, 38), Color(0.30, 0.26, 0.20), false, 2.0)


func _char_color() -> Color:
	match character_id:
		"kuma":
			return Color(0.90, 0.55, 0.25)
		"yuu":
			return Color(0.35, 0.55, 0.80)
		"natsu":
			return Color(0.85, 0.40, 0.55)
	return Color(0.60, 0.60, 0.65)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		player_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		player_exited.emit(self)
