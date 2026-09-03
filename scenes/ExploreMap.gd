extends Node2D
class_name ExploreMap
## 「2Dで歩き回れるマップ」の共通土台。
## Town（街全体）と Place（各場所の中）が、これを継承して中身だけ差し替える。
##
## 共通でやること:
##  - プレイヤーを1体置く
##  - 対象(LocationSpot)への出入りを追い、今どの対象の上にいるかを持つ
##  - E(interact) / Q(skip) を受けて、サブクラスの処理を呼ぶ

const PlayerScene := preload("res://scenes/Player.tscn")
const LocationSpotScene := preload("res://scenes/LocationSpot.tscn")

var _player: CharacterBody2D
var _current_spot = null  ## プレイヤーが今いる対象（無ければ null）


func _ready() -> void:
	_build_map()                    # サブクラス: 地面・場所・NPC などを作る
	_spawn_player(_player_start())
	_ready_done()                   # サブクラス: プレイヤー生成後の初期化
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_on_interact(_current_spot)
	elif event.is_action_pressed("skip"):
		_on_skip()


# --- サブクラスが上書きするフック（初期は何もしない）------------------
func _build_map() -> void:
	pass

func _ready_done() -> void:
	pass

func _player_start() -> Vector2:
	return Vector2(576, 360)

func _on_interact(_spot) -> void:
	pass

func _on_skip() -> void:
	pass

func _refresh_prompt() -> void:
	pass


# --- 共通のヘルパー --------------------------------------------------
func add_ground(color: Color) -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648)
	])
	ground.color = color
	ground.z_index = -10
	add_child(ground)


## 対象（場所ゲート／NPC／出口）を1つ置き、プレイヤーの出入りを購読する。
func add_spot(id: String, disp_name: String, who: String, pos: Vector2) -> Node:
	var spot = LocationSpotScene.instantiate()
	spot.setup(id, disp_name, who, pos)
	add_child(spot)
	spot.player_entered.connect(_on_spot_entered)
	spot.player_exited.connect(_on_spot_exited)
	return spot


func _spawn_player(pos: Vector2) -> void:
	_player = PlayerScene.instantiate() as CharacterBody2D
	_player.position = pos
	add_child(_player)


func set_player_can_move(v: bool) -> void:
	if _player:
		_player.can_move = v


func _on_spot_entered(spot) -> void:
	_current_spot = spot
	spot.set_highlight(true)
	_refresh_prompt()


func _on_spot_exited(spot) -> void:
	if _current_spot == spot:
		_current_spot = null
	spot.set_highlight(false)
	_refresh_prompt()
