extends Node
## シーン遷移（街 ⇄ 場所 ⇄ エンディング ⇄ タイトル）の入口。Autoload。
##
## 実際の切り替えは Fader.change_scene に任せる（暗転→切替→明転）。
## GameState / HUD などの Autoload は遷移しても生き残るので、状態は保たれる。
## ここは「どのマップを開くか」と「入る場所は何か」を受け渡すだけ。

var current_location_id := ""  ## これから入る場所。Place シーンが読む。


func go_to_place(id: String) -> void:
	current_location_id = id
	Fader.change_scene("res://scenes/Place.tscn")


func go_to_town() -> void:
	current_location_id = ""
	Fader.change_scene("res://scenes/Town.tscn")


func go_to_ending() -> void:
	Fader.change_scene("res://scenes/Ending.tscn")


func go_to_title() -> void:
	Fader.change_scene("res://scenes/Title.tscn")
