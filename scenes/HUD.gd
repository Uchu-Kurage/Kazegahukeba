extends CanvasLayer
## 画面手前に常時出る UI。カレンダー（日付・時間帯）と、操作プロンプト。
##
## 日付・時間帯は GameState のシグナルを購読して自動更新する。
## 状況に応じたプロンプト文字列は Town から set_prompt() で渡してもらう。

@onready var date_label: Label = %DateLabel
@onready var phase_label: Label = %PhaseLabel
@onready var prompt_label: Label = %PromptLabel


func _ready() -> void:
	GameState.day_changed.connect(_on_changed.unbind(1))
	GameState.phase_changed.connect(_on_changed.unbind(1))
	_on_changed()


func _on_changed() -> void:
	date_label.text = "%s（%d日目 / 全%d日）" % [
		GameState.date_text(GameState.day_index),
		GameState.day_index + 1,
		GameState.TOTAL_DAYS,
	]
	phase_label.text = GameState.phase_text(GameState.phase)


func set_prompt(text: String) -> void:
	prompt_label.text = text


## HUD 全体（カレンダー＋プロンプト）の表示・非表示。エンディング中などに隠す。
func set_shown(v: bool) -> void:
	for c in get_children():
		if c is Control:
			c.visible = v
