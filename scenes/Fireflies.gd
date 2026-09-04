extends Node2D
class_name Fireflies
## タイトルに漂う蛍。ゆっくり上へ流れ、明滅する。雰囲気づけの軽いアニメ。

const COUNT := 26

var _flies: Array = []


func _ready() -> void:
	z_index = -10
	for i in COUNT:
		_flies.append({
			"pos": Vector2(randf_range(0, 1152), randf_range(120, 648)),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(6.0, 18.0),
			"sway": randf_range(8.0, 22.0),
		})
	set_process(true)


func _process(delta: float) -> void:
	for f in _flies:
		f["phase"] += delta * 2.0
		var p: Vector2 = f["pos"]
		p.y -= f["speed"] * delta                  # ゆっくり上へ
		p.x += sin(f["phase"]) * f["sway"] * delta   # 左右にゆれる
		if p.y < 90.0:                              # 上に抜けたら下から
			p.y = 660.0
			p.x = randf_range(0, 1152)
		f["pos"] = p
	queue_redraw()


func _draw() -> void:
	for f in _flies:
		var a: float = 0.25 + 0.55 * absf(sin(f["phase"]))
		var p: Vector2 = f["pos"]
		draw_circle(p, 5.0, Color(1.0, 0.95, 0.6, a * 0.25))  # ほのかな光輪
		draw_circle(p, 2.0, Color(1.0, 0.97, 0.7, a))         # 芯
