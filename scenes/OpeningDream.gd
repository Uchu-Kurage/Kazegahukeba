extends Node2D
## オープニング＝歩ける「消失の夢」（実装指示 第13弾）。新規開始で、目覚め→本編の前に一度だけ流す。
##
## 8/31（世界最後の日）の夢を、プレイヤーが主人公を歩かせて体験する。ムービーではなく歩ける体験。
## できるのは歩くことだけ＝「終わりは止められない」無力さと、記録者（見て・覚えることしかできない）を体験させる。
##
## 既存の街マップ（家→街の道→丘）をそのまま使い、夢だけは一本道で通す（夢専用マップは作らない＝§7）。
##   ・背景は本編と同じ FieldBackground（同じ PNG）。歩行は本編と同じ Player（walkable_rects）。
##   ・消失は「音もなく、静かに白へ」。遠くから順に（＝画面の奥＝上から、手前＝下へ、白が下りてくる）。
##     背景そのものを白が飲む＝「そこにあったものが無くなる」。派手なエフェクトにしない（§3/§7）。
##   ・二つの人影（球磨・由布に相当）は名前も顔も明示しない。近づくと、届く前に白へ消える（§4）。
##   ・葵は夢に出さない（段階2の伏線。理由はコメントにも書かない）。
##   ・選択肢・戦闘・アイテムは無い。歩くだけ（§0）。
##
## しきい値・速度はすべて定数（§7：定数化）。まず仮値。見ながら詰める。

# --- チューニング定数（すべて仮。見ながら詰める）------------------------
const REACH_RADIUS := 52.0        # ゴール（出口／見晴らし点）に着いたと見なす距離
const FIGURE_RADIUS := 95.0       # 人影に「近づいた」と見なす距離（歩いて寄ると、届く前に消える）
const HAZE_ALPHA := 0.5           # 夢の白い霞（空が白い・色が抜けた感じ）
const CONSUME_ROAD_RATIO := 0.55  # 街の道を歩ききるまでに、上（遠く）からここまで白が下りる
const CONSUME_ROAD_DUR := 9.0     # 道の消失が進む時間（歩ききる時間に合わせる。仮）
const VEIL_DUR := 3.4             # 丘のクライマックス：残りを白が飲み、足元まで迫る時間
const C_SIL := Color(0.17, 0.18, 0.25)  # 人影の影色（featureless）

var _world: Node2D                # 背景・人影・プレイヤー（セグメントごとに作り直す）
var _fx: CanvasLayer              # 霞・白の消失幕（会話ウィンドウ=layer5 より下）
var _haze: ColorRect
var _consume: ColorRect           # 上（遠く）から下りてくる白。世界を飲んでいく
var _ui: CanvasLayer
var _hint: Label

var _player: CharacterBody2D
var _seg := -1
var _busy := false                # 会話中など、ゴール判定を止める
var _walking := false             # 自由歩行中か（ゴール判定を回す）
var _goal := Vector2.ZERO
var _goal_kind := ""              # "exit"（次の画面へ）／"look"（丘の見晴らし＝クライマックス）
var _figures: Array = []          # 二つの人影
var _figures_done := false
var _done := false

const PlayerScene := preload("res://scenes/Player.tscn")


func _ready() -> void:
	HUD.set_shown(false)
	AudioManager.stop_ambient()  # 夢は無音（蝉も風もない）
	AudioManager.stop_bgm()

	# 白い霞（空が白い・色が抜けた感じ）。全画面・薄く・常時。
	_fx = CanvasLayer.new()
	_fx.layer = 4  # 会話(5)より下・HUD(1)より上
	add_child(_fx)
	_haze = ColorRect.new()
	_haze.color = Color(1, 1, 1, HAZE_ALPHA)
	_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(_haze)
	# 消失の白：画面の上（＝奥・遠く）から、下（＝手前）へ下りてくる。背景そのものを飲む。
	_consume = ColorRect.new()
	_consume.color = Color(1, 1, 1, 1)
	_consume.position = Vector2.ZERO
	_consume.size = Vector2(FieldMaps.VIEW_W, 0)
	_consume.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(_consume)

	# 操作ガイド（ごく最小限。夢の雰囲気を壊さない一言）。
	_ui = CanvasLayer.new()
	_ui.layer = 3
	add_child(_ui)
	_hint = Label.new()
	_hint.position = Vector2(28, 604)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.15, 0.16, 0.2, 0.9))
	_hint.text = ""
	_ui.add_child(_hint)

	_start_segment(0)


# --- セグメント（家 → 街の道 → 丘）------------------------------------

func _start_segment(i: int) -> void:
	_seg = i
	_walking = false
	_figures.clear()
	_figures_done = false
	_hint.text = ""

	if _world != null:
		_world.queue_free()
	_world = Node2D.new()
	add_child(_world)

	match i:
		0: _build_home()
		1: _build_road()
		2: _build_hill()


## 家の前：夢の始まり。空は白く、音がない。
func _build_home() -> void:
	_lay_background("home")
	_spawn_player("home", Vector2(480, 585))
	_narrate([
		"——夢を、見ていた。",
		"八月の、最後の日の夢。",
		"僕は、町の真ん中に、立っていた。",
		"見慣れた町。見慣れた、夏の景色。でも、どこか、様子が、おかしかった。",
		"空が、白い。あの、目に痛いくらいの夏の青が、抜けていた。",
		"音が、しない。蝉も、風も。しんと、静まりかえっていた。",
	], func() -> void:
		_hint.text = "WASD・矢印で歩く"
		_begin_walk(Vector2(1060, 500), "exit")
	)


## 街の道：遠くから（上から）順に、白が下りてくる。二つの人影。
func _build_road() -> void:
	_lay_background("shops")
	_spawn_player("shops", Vector2(560, 560))
	# 二つの人影（名前も顔も明示しない）。道の途中に。
	_figures.append(_add_figure(Vector2(500, 415), false))  # まっすぐ前を見て叫ぶ男（球磨性）
	_figures.append(_add_figure(Vector2(700, 420), true))   # 日傘の下で静かに笑う女の子（由布性）
	_narrate([
		"——遠くの家が、消えた。",
		"音もなく。煙も立てず。ただ、そこにあったはずのものが、なくなった。最初から、なかったみたいに。",
		"次は、川ぞいの、道。その次は、橋。",
		"世界が、少しずつ、白に、飲まれていく。",
		"僕は、動けなかった。ただ、それを、見ていた。",
	], func() -> void:
		_hint.text = "歩く"
		# 遠く（上）から白が下りはじめる（時間経過で自動。歩いても止まらない＝焦り・無力感）。
		var tw := create_tween()
		tw.tween_property(_consume, "size:y", FieldMaps.VIEW_H * CONSUME_ROAD_RATIO, CONSUME_ROAD_DUR)
		_begin_walk(Vector2(665, 360), "exit")
	)


## 丘：眼下に街全体。残りを白が飲み、足元まで迫って、すべてが白一色に。
func _build_hill() -> void:
	_lay_background("hill")
	_spawn_player("hill", Vector2(400, 545))
	_narrate([
		"丘に、着いた。眼下に、町の、ぜんぶが、見えた。",
	], func() -> void:
		_hint.text = "歩く"
		_begin_walk(Vector2(400, 470), "look")
	)


# --- 二つの人影（近づくと、届く前に、白に包まれて消える）----------------

func _add_figure(pos: Vector2, parasol: bool) -> Node2D:
	var f := Node2D.new()
	f.position = pos
	f.z_index = -4
	# 体（featureless なシルエット）。台形＋頭。
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(9, -46), Vector2(-9, -46),
	])
	body.color = C_SIL
	f.add_child(body)
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-8, -46), Vector2(8, -46), Vector2(8, -64), Vector2(-8, -64),
	])
	head.color = C_SIL
	f.add_child(head)
	if parasol:
		# 日傘（静かに笑う女の子）。頭の上に、ひらいた傘。
		var umb := Polygon2D.new()
		umb.polygon = PackedVector2Array([
			Vector2(-34, -70), Vector2(34, -70), Vector2(0, -92),
		])
		umb.color = Color(0.32, 0.34, 0.42)
		f.add_child(umb)
	_world.add_child(f)
	return f


## 人影に近づいたら、届く前に、二人とも白へ消える（触れられない。§4）。一度だけ。
func _maybe_trigger_figures() -> void:
	if _figures_done or _figures.is_empty() or _player == null:
		return
	for f in _figures:
		if is_instance_valid(f) and _player.position.distance_to(f.position) <= FIGURE_RADIUS:
			_figures_done = true
			_walking = false
			set_player_move(false)
			_narrate([
				"ふと、視界の隅に、人影が、二つ。",
				"一人は、男。まっすぐ前を見て、何かを、叫んでいるようだった。声は、聞こえない。",
				"一人は、女の子。日傘の下で、こちらを見て、静かに、笑っていた。",
				"誰なのか、わからない。でも、知っている気が、した。とても、大切な、誰かだと。",
				"手を、伸ばそうとした。",
				"——届く前に。",
				"二人も、白に、包まれて、消えた。",
			], func() -> void:
				_walking = true
				set_player_move(true)
			)
			# 会話のあいだに、人影は静かに白へ（届く前に消える）。
			for g in _figures:
				if is_instance_valid(g):
					var tw := create_tween()
					tw.tween_property(g, "modulate", Color(1, 1, 1, 1), 0.6)
					tw.tween_property(g, "modulate:a", 0.0, 0.6)
			return


# --- クライマックス（丘）と目覚め --------------------------------------

## 残りを白が飲み、足元まで迫り、すべてが白一色に → 目覚めへ。
func _climax() -> void:
	_busy = true
	_walking = false
	set_player_move(false)
	_hint.text = ""
	# 白が、足元まで、ゆっくりと迫る（すべてが白一色に）。
	var vt := create_tween()
	vt.tween_property(_consume, "size:y", float(FieldMaps.VIEW_H), VEIL_DUR)
	await vt.finished
	_narrate([
		"あとには、何も、残らなかった。",
		"田んぼも、川も、町も。何もかも。",
		"白い、何もない世界に。",
		"僕だけが、ぽつんと、立っていた。",
		"——覚えているのは、僕だけ。",
		"そんな、声が、どこからか、聞こえた気がした。",
	], func() -> void:
		_wake()
	)


## 目覚め＝本編開始（家の中・夏の初日の朝）。白い無音 → 現実の青と蝉、の落差は home 側で。
func _wake() -> void:
	_narrate([
		"　　＊",
		"目が、覚めた。",
		"天井が、見えた。自分の、部屋の。",
		"開けはなした窓から、蝉の声が、なだれこんでくる。",
		"カーテンの隙間から、朝の光。目に痛いくらいの、夏の青が、そこにあった。",
		"——ある。まだ、全部、ある。",
		"町も、川も、田んぼも。あの、大切な、二人も。まだ、消えていない。",
		"夢だった。ただの、夢。",
		"……でも。僕は、知っていた。あの夢が、ただの夢じゃ、ないことを。",
		"この夏の、終わりに。あの光景は、ほんとうに、やってくる。",
		"八月三十一日。この町が、この夏が、終わる日。",
		"それまで——あと、四十日。",
		"この夏を、どう、過ごそう。失われると、わかっている、この夏を。悔いの、ないように。",
	], func() -> void:
		_finish()
	)


# --- 歩行・ゴール判定 --------------------------------------------------

func _lay_background(field_id: String) -> void:
	var field := FieldMaps.by_id(field_id)
	var bg := FieldBackground.new()
	bg.bg_path = String(field.get("bg", ""))
	bg.roads = field.get("roads", [])
	bg.field_id = field_id
	_world.add_child(bg)


func _spawn_player(field_id: String, pos: Vector2) -> void:
	var field := FieldMaps.by_id(field_id)
	_player = PlayerScene.instantiate() as CharacterBody2D
	_player.position = pos
	var roads: Array[Rect2] = []
	for r in field.get("roads", []):
		roads.append(r)
	_player.walkable_rects = roads
	_player.can_move = false
	_world.add_child(_player)
	# 奥行きスケール（本編と同じ見え方）。
	var d: Dictionary = field.get("depth", {})
	_player.set_depth_scale(
		float(d.get("y_near", FieldMaps.DEPTH_Y_NEAR)), float(d.get("y_far", FieldMaps.DEPTH_Y_FAR)),
		float(d.get("near", FieldMaps.DEPTH_SCALE_NEAR)), float(d.get("far", FieldMaps.DEPTH_SCALE_FAR)),
		float(d.get("base", FieldMaps.DEPTH_SCALE_BASE)))


func _begin_walk(goal: Vector2, kind: String) -> void:
	_goal = goal
	_goal_kind = kind
	_busy = false
	_walking = true
	set_player_move(true)


func _process(_delta: float) -> void:
	if _done:
		return
	if _seg == 1 and not _figures_done:
		_maybe_trigger_figures()
	if not _walking or _busy or _player == null:
		return
	if _player.position.distance_to(_goal) <= REACH_RADIUS:
		_reach_goal()


func _reach_goal() -> void:
	_walking = false
	set_player_move(false)
	if _goal_kind == "look":
		_climax()
	else:
		_start_segment(_seg + 1)


# --- 会話（ナレーション）--------------------------------------------------

## ナレーションを流し、終わったら done を呼ぶ。流している間は歩けない。
func _narrate(lines: Array, done: Callable) -> void:
	_busy = true
	set_player_move(false)
	var nodes: Array = []
	for t in lines:
		nodes.append({ "speaker": "", "text": String(t) })
	Dialogue.finished.connect(func() -> void:
		_busy = false
		done.call()
	, CONNECT_ONE_SHOT)
	Dialogue.start(nodes)


func set_player_move(v: bool) -> void:
	if _player != null:
		_player.can_move = v


# --- スキップ・終了 ----------------------------------------------------

## 夢はいつでも［Q］（skip）でスキップできる（初回でも／既読なら Title 側で丸ごと飛ばす）。
func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("skip"):
		Dialogue.dismiss()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	SaveData.mark_opening_seen()
	# タイトルの「オープニングを見る」からの再生なら、本編には入らずタイトルへ戻す。
	if Nav.opening_replay:
		Nav.opening_replay = false
		Nav.go_to_title()
		return
	HUD.set_shown(true)
	Nav.go_to_field("home", "")  # 目覚め → 本編（第10弾の流れ：部屋→見下ろしマップ）へ
