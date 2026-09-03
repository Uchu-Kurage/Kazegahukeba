extends Node2D
## 町マップ（メインシーン）。プレイヤー・場所・HUD をまとめ、
## 「近づいて調べる ＝ その時間帯の枠を消費する」を GameState につなぐ司令塔。
##
## ロジック（日付を進める・関係値を足す）は GameState 側にあり、ここは
## 入力を受けて GameState に頼み、状態が変われば表示を整えるだけ。

const PlayerScene := preload("res://scenes/Player.tscn")
const LocationSpotScene := preload("res://scenes/LocationSpot.tscn")

@onready var hud: CanvasLayer = %HUD

var _player: CharacterBody2D
var _current_spot = null  ## プレイヤーが今いる場所（無ければ null）
var _ended := false       ## 40日を越えて終端画面になっているか


func _ready() -> void:
	_spawn_ground()
	_spawn_spots()
	_spawn_player()
	GameState.phase_changed.connect(_on_phase_changed.unbind(1))
	GameState.game_ended.connect(_on_game_ended)
	_on_phase_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("skip"):
		_try_skip()


# --- 生成まわり ------------------------------------------------------

func _spawn_ground() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1152, 0), Vector2(1152, 648), Vector2(0, 648)
	])
	ground.color = Color(0.15, 0.18, 0.16)
	ground.z_index = -10
	add_child(ground)


func _spawn_spots() -> void:
	for loc in Locations.ALL:
		var spot = LocationSpotScene.instantiate()
		spot.setup(loc["id"], loc["name"], loc["character"], loc["pos"])
		add_child(spot)
		spot.player_entered.connect(_on_spot_entered)
		spot.player_exited.connect(_on_spot_exited)


func _spawn_player() -> void:
	_player = PlayerScene.instantiate() as CharacterBody2D
	_player.position = Vector2(576, 360)
	add_child(_player)


# --- 場所への出入り --------------------------------------------------

func _on_spot_entered(spot) -> void:
	_current_spot = spot
	spot.set_highlight(true)
	_update_prompt()


func _on_spot_exited(spot) -> void:
	if _current_spot == spot:
		_current_spot = null
	spot.set_highlight(false)
	_update_prompt()


# --- 入力への反応 ----------------------------------------------------

func _try_interact() -> void:
	if _ended:
		_restart()
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			# 場所の上にいるときだけ、その場所で過ごす（＝枠を消費）。
			if _current_spot != null:
				GameState.choose_location(_current_spot.location_id)
		GameState.Phase.NIGHT:
			GameState.flip_calendar()


func _try_skip() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			GameState.skip_slot()


# --- 状態変化への反応 ------------------------------------------------

func _on_phase_changed() -> void:
	# 夜は動けない（振り返り）。午前・午後は自由に歩ける。
	if _player:
		_player.can_move = GameState.phase != GameState.Phase.NIGHT
	_update_prompt()


func _on_game_ended() -> void:
	_ended = true
	if _player:
		_player.can_move = false
	hud.set_prompt("――― 40日が過ぎた。世界の終わり。［E］でもう一度、夏を始める ―――")


func _restart() -> void:
	_ended = false
	_player.position = Vector2(576, 360)
	GameState.start_new_run()  # ここで phase_changed が飛び、can_move も戻る


func _update_prompt() -> void:
	if _ended:
		return
	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			if _current_spot != null:
				hud.set_prompt("「%s」で過ごす：調べる［E］／予定なしは［Q］" % _current_spot.display_name)
			else:
				hud.set_prompt("移動：WASD ／ 矢印キー。誰かのところへ行こう。予定なしは［Q］でスキップ")
		GameState.Phase.NIGHT:
			hud.set_prompt("夜。今日を振り返る。［E］でカレンダーをめくって翌日へ")
