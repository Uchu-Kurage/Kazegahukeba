extends CanvasLayer
## 画面遷移のフェード（Autoload）。全シーンの手前に黒幕を持ち、暗転→シーン切替→明転をつなぐ。
##
## Nav から Fader.change_scene(path) を呼ぶと、フェードアウト→change_scene→フェードイン、を
## 自動で行う。遷移中は入力を飲み込んで二重操作を防ぐ。

const DUR := 0.3  # 片道のフェード秒

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100  # HUD(1)・会話(5)より手前
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 1)  # 起動時は黒から始めて…
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_tween_alpha(0.0)  # …そっと明ける（起動時のフェードイン）


func _input(event: InputEvent) -> void:
	if _busy:
		get_viewport().set_input_as_handled()  # 遷移中は操作を受け付けない


func is_busy() -> bool:
	return _busy


## 暗転 → シーン切替 → 明転。呼び出し側は await しなくてよい（投げっぱなしで進む）。
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _tween_alpha(1.0)             # 暗転
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame      # 新シーンの生成を待つ
	await get_tree().process_frame
	await _tween_alpha(0.0)             # 明転
	_busy = false


func _tween_alpha(a: float) -> void:
	var t := create_tween()
	t.tween_property(_rect, "color:a", a, DUR)
	await t.finished
