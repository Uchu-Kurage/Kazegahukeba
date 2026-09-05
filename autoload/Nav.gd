extends Node
## シーン遷移（街 ⇄ 場所 ⇄ エンディング ⇄ タイトル）の入口。Autoload。
##
## 実際の切り替えは Fader.change_scene に任せる（暗転→切替→明転）。
## GameState / HUD などの Autoload は遷移しても生き残るので、状態は保たれる。
## ここは「どのマップを開くか」と「入る場所は何か」を受け渡すだけ。

var current_location_id := ""  ## これから入る場所。Place シーンが読む。

## 散策画面（FieldScene）用：これから開く画面IDと、どの向きから入ってきたか。
var current_field_id := "riverbank"
var field_enter_dir := ""       ## "" なら新規入場（start 位置）。出口遷移では entry を渡す。


func go_to_place(id: String) -> void:
	current_location_id = id
	Fader.change_scene("res://scenes/Place.tscn")


func go_to_town() -> void:
	current_location_id = ""
	Fader.change_scene("res://scenes/Town.tscn")


func go_to_ending() -> void:
	Fader.change_scene("res://scenes/Ending.tscn")


## 裏エンド（9月1日）＝独立した一本道シーンへ。タイトルの導線（解放済み）やデバッグから呼ぶ。
func go_to_ura_ending() -> void:
	Fader.change_scene("res://scenes/UraEnding.tscn")


## 散策画面へ。field_id の画面を開き、enter_dir（来た向き）に対応する入口へ立たせる。
## 移動・遷移では枠を消費しない（GameState を触らない）。
func go_to_field(field_id: String, enter_dir: String = "") -> void:
	current_field_id = field_id
	field_enter_dir = enter_dir
	Fader.change_scene("res://scenes/FieldScene.tscn")


func go_to_title() -> void:
	Fader.change_scene("res://scenes/Title.tscn")
