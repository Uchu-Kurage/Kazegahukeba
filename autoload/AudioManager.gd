extends Node
## BGM・環境音・効果音の管理（Autoload）。音源ファイルが無くてもコード合成で鳴らす。
##
## 場面ごとに BGM を切り替え、場所ごとに環境音（アンビエント）を重ねる。
## 本物の音源は assets/audio/ に置けば優先:
##   BGM : bgm.ogg（あれば title/day 共通で使う）
##   SE  : blip / confirm / cancel / talk / page .wav
## どこからでも AudioManager.play_bgm("day") / play_ambient("water") / play_sfx("confirm")。

const MIX_RATE := 22050
const BGM_DB := -14.0
const AMB_DB := -20.0

var _bgm: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _sfx_players: Array = []
var _sfx := {}
var _bgms := {}
var _ambients := {}
var _cur_bgm := ""
var _cur_amb := ""
var _next := 0


func _ready() -> void:
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = BGM_DB
	add_child(_bgm)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = AMB_DB
	add_child(_amb)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)
	_build_sfx()
	_build_bgms()
	_build_ambients()


# --- 再生 API --------------------------------------------------------

func play_sfx(sfx_name: String) -> void:
	if not _sfx.has(sfx_name):
		return
	var p: AudioStreamPlayer = _sfx_players[_next]
	_next = (_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.play()


func play_bgm(bgm_name: String) -> void:
	if bgm_name == _cur_bgm and _bgm.playing:
		return
	if not _bgms.has(bgm_name):
		return
	_cur_bgm = bgm_name
	_swap(_bgm, _bgms[bgm_name], BGM_DB)


func stop_bgm() -> void:
	_cur_bgm = ""
	_bgm.stop()


func play_ambient(amb_name: String) -> void:
	if amb_name == _cur_amb and _amb.playing:
		return
	if not _ambients.has(amb_name):
		stop_ambient()
		return
	_cur_amb = amb_name
	_swap(_amb, _ambients[amb_name], AMB_DB)


func stop_ambient() -> void:
	_cur_amb = ""
	_amb.stop()


## 場所IDに対応する環境音名。
func ambient_for_place(place_id: String) -> String:
	match place_id:
		"riverside": return "water"
		"shrine": return "cicada"
		"shop": return "murmur"
		"home": return "fan"
		"stroll": return "cicada"
		"meadow": return "cicada"
	return ""


## いま鳴っている音を軽くフェードしてから、別のストリームへ差し替えて再生する。
func _swap(player: AudioStreamPlayer, stream: AudioStream, base_db: float) -> void:
	if player.playing:
		var t := create_tween()
		t.tween_property(player, "volume_db", -40.0, 0.25)
		await t.finished
	player.stream = stream
	player.volume_db = base_db
	player.play()


# --- 効果音（ファイルがあれば優先、無ければ合成）--------------------

func _build_sfx() -> void:
	_sfx["blip"] = _load_or("res://assets/audio/blip.wav", _tone(660.0, 0.05, 0.35))
	_sfx["confirm"] = _load_or("res://assets/audio/confirm.wav", _sweep(520.0, 784.0, 0.12, 0.40))
	_sfx["cancel"] = _load_or("res://assets/audio/cancel.wav", _sweep(440.0, 300.0, 0.12, 0.40))
	_sfx["talk"] = _load_or("res://assets/audio/talk.wav", _tone(720.0, 0.025, 0.20))
	_sfx["page"] = _load_or("res://assets/audio/page.wav", _noise(0.14, 0.30))


func _build_bgms() -> void:
	if ResourceLoader.exists("res://assets/audio/bgm.ogg"):
		var ogg: AudioStream = load("res://assets/audio/bgm.ogg")
		_bgms["title"] = ogg
		_bgms["day"] = ogg
		return
	# タイトル：静かなペンタトニック。本編：少し明るく速め。
	_bgms["title"] = _bgm_arp([261.63, 293.66, 329.63, 392.0, 440.0],
		[0, 2, 4, 2, 1, 3, 4, 3, 0, 2, 4, 2, 1, 3, 2, 0], 8.0)
	_bgms["day"] = _bgm_arp([293.66, 329.63, 392.0, 440.0, 523.25],
		[0, 2, 1, 3, 4, 3, 2, 0, 1, 3, 2, 4], 6.0)


func _build_ambients() -> void:
	_ambients["water"] = _water(2.0)
	_ambients["cicada"] = _cicada(2.0)
	_ambients["murmur"] = _murmur(2.0)
	_ambients["fan"] = _fan(2.0)


func _load_or(path: String, fallback: AudioStream) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	return fallback


# --- 効果音の波形 ----------------------------------------------------

func _tone(freq: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := clampf(t / 0.005, 0.0, 1.0) * (1.0 - t / dur)
		s[i] = sin(TAU * freq * t) * amp * env
	return _wav(s, false)


func _sweep(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(f0, f1, t / dur) / MIX_RATE
		var env := clampf(t / 0.005, 0.0, 1.0) * (1.0 - t / dur)
		s[i] = sin(phase) * amp * env
	return _wav(s, false)


func _noise(dur: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := 1.0 - t / dur
		s[i] = randf_range(-1.0, 1.0) * amp * env * env
	return _wav(s, false)


# --- BGM（ペンタトニックのアルペジオ、ループ）------------------------

func _bgm_arp(scale: Array, pattern: Array, dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var note_dur := dur / float(pattern.size())
	for i in n:
		var t := float(i) / MIX_RATE
		var ni := int(t / note_dur) % pattern.size()
		var nt := t - float(ni) * note_dur
		var f: float = scale[pattern[ni]]
		var env := clampf(nt / 0.02, 0.0, 1.0) * clampf((note_dur - nt) / (note_dur * 0.7), 0.0, 1.0)
		var v := sin(TAU * f * nt) * 0.11 * env
		v += sin(TAU * (f * 0.5) * nt) * 0.05 * env
		s[i] = v
	return _wav(s, true)


# --- 環境音（すべてループ）------------------------------------------

## 川のせせらぎ：ローパスしたノイズをゆっくり波打たせる。
func _water(dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		prev += 0.06 * (randf_range(-1.0, 1.0) - prev)   # 1極ローパス
		var swell := 0.7 + 0.3 * sin(TAU * (2.0 / dur) * t)
		s[i] = prev * 3.2 * swell * 0.5
	return _wav(s, true)


## 蝉の声：高めのトーンをトレモロ（ジー…）で震わせ、ゆっくり強弱をつける。
func _cicada(dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var trem := 0.5 + 0.5 * sin(TAU * 48.0 * t)
		var swell := 0.6 + 0.4 * sin(TAU * (1.0 / dur) * t)
		var tone := sin(TAU * 2600.0 * t) * 0.6 + sin(TAU * 5200.0 * t) * 0.2
		s[i] = tone * trem * swell * 0.16
	return _wav(s, true)


## 遠いざわめき：低めのローパスノイズ。
func _murmur(dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		prev += 0.02 * (randf_range(-1.0, 1.0) - prev)
		s[i] = prev * 4.0 * 0.5
	return _wav(s, true)


## 扇風機：低いハムに、かすかなノイズ。
func _fan(dur: float) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var hum := sin(TAU * 120.0 * t) * 0.5 + sin(TAU * 240.0 * t) * 0.15
		s[i] = (hum + randf_range(-1.0, 1.0) * 0.08) * 0.35
	return _wav(s, true)


# --- 変換 ------------------------------------------------------------

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
