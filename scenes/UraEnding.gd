extends Control
## 裏エンド（9月1日）＝独立した一本道シーン（実装指示 第5弾）。
##
## 通常の40日ループ（枠・関係値・ルート判定・Story.gd）は一切通さない。
## UraStory.scenes() を上から順に再生するだけ。各場面で背景トーンを切り替え、
## 会話ノードを Dialogue で流す。全場面が終わったらタイトルへ戻る。
## 葵は登場しない（立ち絵・スプライトも出さない）。存在するのは「いない」という事実だけ。

var _bg: UraBackground
var _done := false
var _hint: Label


func _ready() -> void:
	HUD.set_shown(false)     # 裏エンド中はカレンダー等を隠す
	AudioManager.stop_bgm()   # 蝉が減った静けさ（涼しい秋の空気）
	AudioManager.stop_ambient()
	_bg = UraBackground.new()
	add_child(_bg)
	_build_hint()
	_run()


## 場面を順に再生する（背景トーン → その場面の会話 → 次へ）。
func _run() -> void:
	for scene in UraStory.scenes():
		_bg.set_tone(String(scene["tone"]))
		Dialogue.start(scene["nodes"])
		await Dialogue.finished
	# 到達を記録（周回記録の「裏エンド」に反映）。解放とは別に「見た」印。
	SaveData.mark_ending(Endings.SECRET)
	_show_end()


func _show_end() -> void:
	_hint.text = "［E］でタイトルへ"
	_hint.visible = true
	_done = true


func _unhandled_input(event: InputEvent) -> void:
	if _done and event.is_action_pressed("interact"):
		AudioManager.play_sfx("confirm")
		Nav.go_to_title()


func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = ""
	_hint.visible = false
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-120, -60)
	_hint.custom_minimum_size = Vector2(240, 0)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.10, 0.9))
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)
