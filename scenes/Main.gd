extends Control
## 一日を回すループの司令塔（ビュー）。
##
## GameState（状態）を見て画面を組み立て、ボタンが押されたら GameState に
## 「進めて」と頼むだけ。ここ自体はゲームのロジックを持たない（表示と入力に徹する）。
## 状態が変わると GameState がシグナルを出し、それを受けて画面を作り直す。

@onready var date_label: Label = %DateLabel
@onready var phase_label: Label = %PhaseLabel
@onready var prompt_label: Label = %PromptLabel
@onready var button_list: VBoxContainer = %ButtonList
@onready var hint_label: Label = %HintLabel


func _ready() -> void:
	# day_changed(int) / phase_changed(Phase) は引数付きだが、
	# 描画は「現在の状態を全部作り直す」だけなので引数は使わない → unbind(1) で捨てる。
	GameState.day_changed.connect(_refresh.unbind(1))
	GameState.phase_changed.connect(_refresh.unbind(1))
	GameState.game_ended.connect(_on_game_ended)
	_refresh()


## 現在の状態に合わせて画面を作り直す。
func _refresh() -> void:
	date_label.text = "%s（%d日目 / 全%d日）" % [
		GameState.date_text(GameState.day_index),
		GameState.day_index + 1,
		GameState.TOTAL_DAYS,
	]
	phase_label.text = GameState.phase_text(GameState.phase)
	_clear_buttons()

	match GameState.phase:
		GameState.Phase.MORNING, GameState.Phase.AFTERNOON:
			_build_action_slot()
		GameState.Phase.NIGHT:
			_build_night()


## 午前・午後：場所を一つ選ぶ（選ぶと枠を消費して次の時間帯へ）。
func _build_action_slot() -> void:
	prompt_label.text = "どこへ行く？（誰か一人と過ごす）"
	for loc in Locations.ALL:
		var who := String(loc["character"])
		var label := String(loc["name"])
		if who != "":
			label += "  ＜%s＞" % who
		# ラムダで location id を束ねてボタンに接続する。
		var id := String(loc["id"])
		_add_button(label, func() -> void: GameState.choose_location(id))
	_add_button("予定なし（スキップ）", func() -> void: GameState.skip_slot())
	hint_label.text = "一箇所を選ぶと、その枠では他へは行けない。"


## 夜：基本は振り返り。カレンダーを一枚めくって翌日へ。
func _build_night() -> void:
	prompt_label.text = "今日の振り返り\n　午前：%s\n　午後：%s" % [
		_choice_text(GameState.Phase.MORNING),
		_choice_text(GameState.Phase.AFTERNOON),
	]
	_add_button("カレンダーをめくる（翌日へ）", func() -> void: GameState.flip_calendar())
	hint_label.text = "特別な夜だけ、ここで行動できるようにしていく予定。"


## その日の指定時間帯に何を選んだかを、表示用の文字列で返す。
func _choice_text(p: int) -> String:
	var today: Dictionary = GameState.schedule.get(GameState.day_index, {})
	if not today.has(p):
		return "―"
	var id := String(today[p])
	if id == "":
		return "何もしなかった"
	return Locations.name_of(id)


func _on_game_ended() -> void:
	_clear_buttons()
	date_label.text = "――― 世界の終わり ―――"
	phase_label.text = ""
	prompt_label.text = "40日が過ぎた。\n（ここにエンディング分岐が入る）"
	_add_button("もう一度、夏を始める（周回）", func() -> void: GameState.start_new_run())
	hint_label.text = "周回でセーブ記録を貯め、全エンド到達で裏エンドへ。"


# --- ボタン生成のヘルパー -------------------------------------------
func _add_button(text: String, on_pressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 44)
	b.pressed.connect(on_pressed)
	button_list.add_child(b)


func _clear_buttons() -> void:
	for c in button_list.get_children():
		c.queue_free()
