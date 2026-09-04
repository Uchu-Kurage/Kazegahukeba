extends Node
## BGM と効果音の管理（Autoload）。
##
## 音源ファイルが無くても鳴るよう、効果音と BGM をコードで合成している。
## あとで本物の音源を assets/audio/ に置けば、そちらを優先して使う:
##   - BGM : res://assets/audio/bgm.ogg
##   - SE  : res://assets/audio/<名前>.wav / .ogg（blip / confirm / cancel / talk / page）
## どこからでも AudioManager.play_sfx("confirm") のように呼べる。

const MIX_RATE := 22050

var _bgm: AudioStreamPlayer
var _sfx_players: Array = []   # 同時発音のための使い回しプール
var _sfx: Dictionary = {}      # 名前 -> AudioStream
var _next := 0


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -14.0
	add_child(_bgm)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)

	_build_sfx()
	_bgm.stream = _load_or("res://assets/audio/bgm.ogg", _build_bgm())
	start_bgm()


# --- 再生 API --------------------------------------------------------

func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_next]
	_next = (_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.play()


func start_bgm() -> void:
	if _bgm.stream and not _bgm.playing:
		_bgm.play()


func stop_bgm() -> void:
	_bgm.stop()


# --- 効果音の用意（ファイルがあれば優先、無ければ合成）----------------

func _build_sfx() -> void:
	_sfx["blip"] = _load_or("res://assets/audio/blip.wav", _tone(660.0, 0.05, 0.35))
	_sfx["confirm"] = _load_or("res://assets/audio/confirm.wav", _sweep(520.0, 784.0, 0.12, 0.40))
	_sfx["cancel"] = _load_or("res://assets/audio/cancel.wav", _sweep(440.0, 300.0, 0.12, 0.40))
	_sfx["talk"] = _load_or("res://assets/audio/talk.wav", _tone(720.0, 0.025, 0.20))
	_sfx["page"] = _load_or("res://assets/audio/page.wav", _noise(0.14, 0.30))


func _load_or(path: String, fallback: AudioStream) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return fallback


# --- 波形合成 --------------------------------------------------------

## 一定周波数のサイン波（アタック＋減衰つき）。
func _tone(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := clampf(t / 0.005, 0.0, 1.0) * (1.0 - t / dur)
		s[i] = sin(TAU * freq * t) * amp * env
	return _wav(s, false)


## 周波数がすべる（上下する）短い音。決定/キャンセル向け。
func _sweep(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := lerpf(f0, f1, t / dur)
		phase += TAU * f / MIX_RATE
		var env := clampf(t / 0.005, 0.0, 1.0) * (1.0 - t / dur)
		s[i] = sin(phase) * amp * env
	return _wav(s, false)


## ホワイトノイズを急減衰（ページめくり風）。
func _noise(dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := (1.0 - t / dur)
		s[i] = randf_range(-1.0, 1.0) * amp * env * env
	return _wav(s, false)


## やさしいペンタトニックのアルペジオを1ループ分（ループ再生用）。
func _build_bgm() -> AudioStreamWAV:
	var dur := 8.0
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var scale := [261.63, 293.66, 329.63, 392.0, 440.0]  # Cメジャーペンタトニック
	var pattern := [0, 2, 4, 2, 1, 3, 4, 3, 0, 2, 4, 2, 1, 3, 2, 0]
	var note_dur := dur / float(pattern.size())
	for i in n:
		var t := float(i) / MIX_RATE
		var ni := int(t / note_dur) % pattern.size()
		var nt := t - float(ni) * note_dur           # そのノート内の経過時間
		var f: float = scale[pattern[ni]]
		# 音の頭を立ち上げ、末尾で 0 に戻す（ループ継ぎ目のノイズも防ぐ）。
		var env := clampf(nt / 0.02, 0.0, 1.0) * clampf((note_dur - nt) / (note_dur * 0.7), 0.0, 1.0)
		var v := sin(TAU * f * nt) * 0.11 * env
		v += sin(TAU * (f * 0.5) * nt) * 0.05 * env  # 低いオクターブで厚みを足す
		s[i] = v
	return _wav(s, true)


## float サンプル列（-1..1）を 16bit の AudioStreamWAV にする。
func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
