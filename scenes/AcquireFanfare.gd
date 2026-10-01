class_name AcquireFanfare
extends Node2D
## 入手演出：道具や風物詩を手に入れた瞬間、主人公が正面を向き、頭上にアイコンが浮かんで
## ファンファーレが鳴る（散策画面 FieldScene が1つ持つ）。
##
## GameState の item_acquired / fubutsushi_discovered を購読するだけで動く＝入手経路
## （会話の効果ノード・探索入手・夜の行事）ごとに演出を書かない。
## 会話の途中で手に入れたら Dialogue.hold() で会話を止め、演出が終わってから続きを流す。
## 同時に複数の風物詩が灯ったとき（夏祭りなど）は、一度の演出にまとめて並べる（何度も鳴らさない）。

signal all_done  ## 待ち行列が空になり、演出がすべて終わった

const RISE_TIME := 0.35   ## アイコンが頭上へせり上がる秒数
const SHOW_TIME := 1.5    ## 掲げて見せる秒数（この間は［E］/タップで先へ送れる）
const FADE_TIME := 0.3    ## 消える秒数
const RISE_PX := 30.0     ## 頭のてっぺんから、さらに上へ浮かせる量（px）
const ICON_GAP := 66.0    ## 複数並べるときの間隔（px）
const ICON_SCALE := 1.3  ## 掲げたときのアイコンの倍率（主人公の頭と釣り合う大きさ）
const MAX_BATCH := 6      ## 一度にまとめて並べる風物詩の上限
const CAPTION_NAMES := 2  ## 告知に名前を出す件数（残りは「ほかNつ」。右上の日めくりに掛からない長さに）
const CAPTION_Y := 128.0  ## 告知の帯の画面上の高さ（px。右上の日めくりより下）

var _player = null            # 散策画面のプレイヤー（Player.gd。face_front / head_height を使う）
var _queue: Array = []        # { kind, id, name, bridge } の待ち行列
var _busy := false
var _scheduled := false
var _holding := false         # Dialogue.hold() を掛けているか
var _could_move := true       # 演出前のプレイヤーの can_move（終わったら戻す）
var _skippable := false
var _skip := false
var _glow := 0.0              # 頭上の光（後光）の強さ 0..1
var _spin := 0.0

var _icons: Node2D
var _ui: CanvasLayer
var _caption: Label


func setup(player) -> void:
	_player = player


func _ready() -> void:
	z_index = 40  # 天気の色(20)・天気FX(25)より手前、歩行デバッグ(50)より奥
	_icons = Node2D.new()
	add_child(_icons)
	_ui = CanvasLayer.new()
	_ui.layer = 6  # 会話(5)より手前
	add_child(_ui)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(_caption, UITheme.SIZE_NAME)
	var sb := UITheme.washi(18, 0.96)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_caption.add_theme_stylebox_override("normal", sb)
	_caption.visible = false
	_ui.add_child(_caption)
	GameState.item_acquired.connect(_on_item_acquired)
	GameState.fubutsushi_discovered.connect(_on_fubutsushi_discovered)


func _exit_tree() -> void:
	# 演出の途中で画面ごと消えても、会話を止めたままにしない。
	_release_dialogue()


## 演出中（または待ちあり）か。散策画面はこの間、調べる・帰るを受け付けない。
func is_busy() -> bool:
	return _busy or _scheduled or not _queue.is_empty()


# --- 入手の受け付け ---------------------------------------------------

func _on_item_acquired(id: String) -> void:
	var m := Items.by_id(id)
	if m.is_empty() or not bool(m.get("fanfare", true)):
		return
	_enqueue({ "kind": "item", "id": id, "name": String(m["name"]),
		"bridge": String(m.get("fubutsushi_id", "")) })


func _on_fubutsushi_discovered(id: String) -> void:
	# 道具と同じモチーフで一緒に灯った風物詩（橋）は、道具の演出にまとめて二度鳴らさない。
	for q in _queue:
		if String(q["kind"]) == "item" and String(q["bridge"]) == id:
			return
	_enqueue({ "kind": "fubutsushi", "id": id, "name": Fubutsushi.name_of(id), "bridge": "" })


## 待ち行列に積む。会話中なら即座に会話を止め（効果ノードの次へ進ませない）、
## 実際の演出は次のフレームで始める（同じ瞬間に灯った分をまとめるため）。
func _enqueue(e: Dictionary) -> void:
	_queue.append(e)
	if Dialogue.is_active() and not _holding:
		Dialogue.hold()
		_holding = true
	if not _busy and not _scheduled:
		_scheduled = true
		_play_next.call_deferred()


# --- 演出 -------------------------------------------------------------

func _play_next() -> void:
	_scheduled = false
	if _queue.is_empty():
		_finish()
		return
	if not _busy:
		_busy = true
		if _player != null:
			_could_move = _player.can_move
			_player.can_move = false
	var head: Dictionary = _queue.pop_front()
	var batch: Array = [head]
	if String(head["kind"]) == "fubutsushi":
		while not _queue.is_empty() and String(_queue[0]["kind"]) == "fubutsushi" and batch.size() < MAX_BATCH:
			batch.append(_queue.pop_front())
	await _present(batch)
	_play_next()


## 1回ぶんの演出：正面を向く → アイコンがせり上がる＋ジングル → 掲げて見せる → 消える。
func _present(batch: Array) -> void:
	var is_item := String(batch[0]["kind"]) == "item"
	if _player != null:
		_player.face_front()
	AudioManager.play_jingle("fanfare_item" if is_item else "fanfare_fubutsushi")

	for c in _icons.get_children():
		c.queue_free()
	var w := ICON_GAP * float(batch.size() - 1)
	for i in batch.size():
		var ic := AcquireIcon.new()
		ic.setup(String(batch[i]["kind"]), String(batch[i]["id"]))
		ic.position = Vector2(-w * 0.5 + ICON_GAP * float(i), 0)
		_icons.add_child(ic)

	_caption.text = _caption_text(batch)
	_caption.reset_size()
	_caption.position = Vector2((FieldMaps.VIEW_W - _caption.size.x) * 0.5, CAPTION_Y)
	_caption.visible = true

	_skip = false
	_skippable = false
	_icons.position = Vector2.ZERO
	_icons.scale = Vector2(0.3, 0.3)
	_icons.modulate.a = 0.0
	_caption.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_icons, "position:y", -RISE_PX, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_icons, "scale", Vector2.ONE * ICON_SCALE, RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_icons, "modulate:a", 1.0, RISE_TIME * 0.6)
	t.tween_property(_caption, "modulate:a", 1.0, RISE_TIME)
	t.tween_property(self, "_glow", 1.0, RISE_TIME)
	await t.finished

	_skippable = true
	var shown := 0.0
	while shown < SHOW_TIME and not _skip:
		await get_tree().process_frame
		shown += get_process_delta_time()
	_skippable = false

	var f := create_tween().set_parallel(true)
	f.tween_property(_icons, "modulate:a", 0.0, FADE_TIME)
	f.tween_property(_icons, "position:y", -RISE_PX - 10.0, FADE_TIME)
	f.tween_property(_caption, "modulate:a", 0.0, FADE_TIME)
	f.tween_property(self, "_glow", 0.0, FADE_TIME)
	await f.finished
	_caption.visible = false


## 告知の文言。道具は「手に入れた」、風物詩は「見つけた」（眺める記録なので）。
func _caption_text(batch: Array) -> String:
	if String(batch[0]["kind"]) == "item":
		return "〈%s〉を手に入れた！" % String(batch[0]["name"])
	var names: Array = []
	for e in batch.slice(0, CAPTION_NAMES):
		names.append("〈%s〉" % String(e["name"]))
	var s := "".join(names)
	if batch.size() > CAPTION_NAMES:
		s += "ほか%dつ" % (batch.size() - CAPTION_NAMES)
	return "風物詩 %s を見つけた" % s


func _finish() -> void:
	_busy = false
	if _player != null:
		_player.can_move = _could_move
	_release_dialogue()
	all_done.emit()


func _release_dialogue() -> void:
	if _holding:
		_holding = false
		Dialogue.release()


# --- 追従・送り・後光 ---------------------------------------------------

func _process(delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		position = _player.position + Vector2(0, -float(_player.head_height()) - AcquireIcon.RADIUS * ICON_SCALE)
	if _glow > 0.0:
		_spin += delta * 0.8
		queue_redraw()
	elif _spin != 0.0:
		_spin = 0.0
		queue_redraw()


## ［E］／タップで見せる時間を切り上げる（せり上がりの途中は受け付けない＝誤送り防止）。
func _input(event: InputEvent) -> void:
	if not _busy:
		return
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed  # スマホのタップもここに来る
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()  # 背後の調べる／会話送りに渡さない
		tapped = true
	if tapped and _skippable:
		_skip = true


## 頭上の後光：アイコンの後ろでゆっくり回る光の筋。
func _draw() -> void:
	if _glow <= 0.0:
		return
	var c := _icons.position
	var k := ICON_SCALE
	var col := Color(1.0, 0.93, 0.6, 0.35 * _glow)
	for i in 12:
		var a := _spin + TAU * float(i) / 12.0
		var tip := c + Vector2.from_angle(a) * 52.0 * k
		var l := c + Vector2.from_angle(a - 0.09) * 18.0 * k
		var r := c + Vector2.from_angle(a + 0.09) * 18.0 * k
		draw_colored_polygon(PackedVector2Array([l, tip, r]), col)
	draw_circle(c, 30.0 * k, Color(1.0, 0.97, 0.82, 0.30 * _glow))
