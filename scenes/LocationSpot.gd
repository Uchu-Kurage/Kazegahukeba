extends Area2D
## 町の「場所」。プレイヤーが近づいて調べると、その時間帯の枠を消費して過ごす。
##
## 見た目・アタリはコードで用意（アート未使用でも動く）。
## あとで、ここを NPC のドット絵（AnimatedSprite2D）に差し替えていく。

## プレイヤーが範囲に出入りしたことを Town へ知らせる。
signal player_entered(spot: Area2D)
signal player_exited(spot: Area2D)

var location_id := ""
var display_name := ""
var character_id := ""

var _marker: Polygon2D
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
	_build_placeholder()


func _build_placeholder() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	_marker = Polygon2D.new()
	_marker.polygon = PackedVector2Array([
		Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)
	])
	_marker.color = _base_color()
	add_child(_marker)

	_label = Label.new()
	if character_id == "":
		_label.text = display_name
	else:
		_label.text = "%s\n＜%s＞" % [display_name, character_id]
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(120, 0)
	_label.position = Vector2(-60, 40)
	add_child(_label)


## 近づいたとき明るくする（＝調べられる合図）。
func set_highlight(on: bool) -> void:
	if _marker:
		_marker.color = _base_color().lightened(0.35) if on else _base_color()


func _base_color() -> Color:
	# キャラがいる場所は緑寄り、いない場所（家など）は青灰。
	return Color(0.30, 0.55, 0.45) if character_id != "" else Color(0.34, 0.38, 0.52)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		player_entered.emit(self)


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody2D:
		player_exited.emit(self)
