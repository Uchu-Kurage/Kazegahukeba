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

	# 中の人がいれば、ドット絵キャラ（待機アニメ）を置く。
	if character_id != "":
		var sprite := PixelCharacter.new()
		sprite.setup(CharacterArt.palette_for(character_id))
		add_child(sprite)

	_label = Label.new()
	_label.text = display_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(160, 0)
	_label.position = Vector2(-80, 40)
	add_child(_label)

	queue_redraw()


## 近づいたとき明るくする（＝反応できる合図）。
func set_highlight(on: bool) -> void:
	if _selected == on:
		return
	_selected = on
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 26), 15.0, Color(0, 0, 0, 0.25))  # 影（スプライトの後ろ）
	if character_id == "":
		_draw_marker()  # 中の人がいない場所は看板マーカー
	if _selected:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.25), 3.0, true)


## 出口／無人の場所は看板風のマーカー。
func _draw_marker() -> void:
	draw_rect(Rect2(-16, -18, 32, 38), Color(0.55, 0.50, 0.42))
	draw_rect(Rect2(-16, -18, 32, 38), Color(0.30, 0.26, 0.20), false, 2.0)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		player_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		player_exited.emit(self)
