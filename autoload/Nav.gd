extends Node
## シーン遷移（街 ⇄ 各場所）の入口。Autoload。
##
## GameState / HUD などの Autoload は遷移しても生き残るので、日付や好感度、
## カレンダー表示はシーンをまたいでそのまま保たれる。ここは「どのマップを開くか」
## と「入る場所は何か」を受け渡すだけ。

var current_location_id := ""  ## これから入る場所。Place シーンが読む。


func go_to_place(id: String) -> void:
	current_location_id = id
	get_tree().change_scene_to_file("res://scenes/Place.tscn")


func go_to_town() -> void:
	current_location_id = ""
	get_tree().change_scene_to_file("res://scenes/Town.tscn")


func go_to_ending() -> void:
	get_tree().change_scene_to_file("res://scenes/Ending.tscn")


func go_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
