extends Node
## 操作キーの登録（Autoload）。ゲーム起動時に一度だけ実行される。
##
## エディタの「プロジェクト設定 > 入力マップ」で設定するのが本来だが、ここで登録して
## おけば設定ファイルに依存せず確実に動く。街(Player不在)でも場所でも同じキーが使える。
## 既に同名アクションがあれば（エディタ側で設定済みなら）尊重してスキップする。

func _ready() -> void:
	_bind("walk_left",  [KEY_A, KEY_LEFT])
	_bind("walk_right", [KEY_D, KEY_RIGHT])
	_bind("walk_up",    [KEY_W, KEY_UP])
	_bind("walk_down",  [KEY_S, KEY_DOWN])
	_bind("interact",   [KEY_E, KEY_SPACE, KEY_ENTER])
	_bind("skip",       [KEY_Q])
	# --- 動作確認用（デバッグ）---
	_bind("debug_toggle", [KEY_F3])  # ルート到達状況オーバーレイの表示切替
	_bind("debug_end",    [KEY_F4])  # いまの状態で即エンディング判定へ（分岐確認用）
	_bind("debug_ura",    [KEY_F5])  # 裏エンド（9月1日）を強制再生（解放条件を無視・検証用）
	_bind("debug_field",  [KEY_F6])  # 散策画面（河原と土手）へ（第6弾 §1 の動作確認用）


func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
