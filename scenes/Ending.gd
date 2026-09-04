extends Control
## エンディング画面。8/31 を越えたときに Nav がここへ遷移する。
##
## 好感度・フラグから結末を選び、会話ボックスで結末を流す。見たエンディングは
## SaveData に記録し、全ノーマル到達なら裏エンドを続けて解放する。最後に成績を出して周回へ。

var _summary_shown := false

var _center: CenterContainer
var _title: Label
var _progress: Label
var _hint: Label


func _ready() -> void:
	_build_ui()
	HUD.set_shown(false)  # 終幕中はカレンダーを隠す
	AudioManager.stop_bgm()      # 終幕は静けさで（タイトルに戻ると再開）
	AudioManager.stop_ambient()
	_run()


## 結末の再生 → 記録 → （裏エンド）→ 成績表示、を順に待ち合わせる。
func _run() -> void:
	var id := Endings.pick(GameState.affinity, GameState.flags, GameState.kuma_stance)
	Dialogue.start(Endings.script_of(id))
	await Dialogue.finished

	SaveData.mark_ending(id)
	SaveData.record_run()

	var final_id := id
	# 全ノーマル到達済みで、まだ裏を見ていなければ、続けて裏エンドを解放。
	if not SaveData.has_seen(Endings.SECRET) and SaveData.all_seen(Endings.NORMAL_IDS):
		Dialogue.start(Endings.script_of(Endings.SECRET))
		await Dialogue.finished
		SaveData.mark_ending(Endings.SECRET)
		final_id = Endings.SECRET

	_show_summary(final_id)


func _unhandled_input(event: InputEvent) -> void:
	if _summary_shown and event.is_action_pressed("interact"):
		AudioManager.play_sfx("confirm")
		Nav.go_to_title()  # タイトルへ（記録が更新された状態で戻る）


func _show_summary(id: String) -> void:
	_title.text = "『%s』" % Endings.title_of(id)
	var seen := SaveData.seen_count(Endings.NORMAL_IDS)
	var secret_txt := "解放済み" if SaveData.has_seen(Endings.SECRET) else "未解放"
	_progress.text = "見たエンディング：%d / %d　　裏エンド：%s（周回 %d 回目）" % [
		seen, Endings.NORMAL_IDS.size(), secret_txt, SaveData.runs,
	]
	_hint.text = "［E］でタイトルへ"
	_center.visible = true
	_summary_shown = true


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.visible = false
	add_child(_center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	_center.add_child(vbox)

	_title = _make_label(40)
	_progress = _make_label(22)
	_hint = _make_label(18)
	_hint.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_title)
	vbox.add_child(_progress)
	vbox.add_child(_hint)


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	return l
