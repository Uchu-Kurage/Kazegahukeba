class_name RoomLines
extends RefCounted
## 部屋（家）の朝／昼の独白（第10弾）。「今日はどこへ行こうか」の前に、その日の空気を一言そえる。
##
## 出し分けの優先順位：今日の約束（予定表・第9弾）＞今夜の特別な夜（祭り等）＞天気＋時期の情感。
## 僕視点の短い独白（1〜2行）。数字や攻略めいた情報は出さない（トーンは既存方針に合わせる）。

static func intro(state) -> Array:
	var out: Array = [ { "speaker": "", "text": _opener(state) } ]
	var mood := _mood(state)
	if mood != "":
		out.append({ "speaker": "", "text": mood })
	return out


static func _opener(state) -> String:
	var d := int(state.day_index)
	if state.phase == GameState.Phase.MORNING:
		if d == 0:
			return "――夏休みが、始まった。日記帳のページは、まだ、まっさらだ。"
		if d >= GameState.TOTAL_DAYS - 1:
			return "……八月三十一日。とうとう、最後の朝が来てしまった。"
		return "朝。カーテンのすきまから、もう夏の光が差している。"
	return "昼下がり。まだ半日、残っている。"


static func _mood(state) -> String:
	var d := int(state.day_index)
	# 1) 今日の約束（予定表）に触れる。
	var p: Dictionary = state.promise_of(d)
	if not p.is_empty() and String(p.get("status", "")) == "planned":
		var who: String = state.char_display(String(p.get("character", "")))
		var place: String = state.place_name(String(p.get("place", "")))
		return "そうだ、今日は%sと%sで会う約束だった。忘れないようにしないと。" % [who, place]
	# 2) 今夜の特別な夜（祭り・花火）。
	if Nights.is_special(d):
		return "今夜は、%s。……なんだか、朝からそわそわする。" % Nights.name_of(d)
	# 3) 天気＋時期の情感。
	var wl := _weather_line(state.weather_today())
	var pl := _period_line(d)
	if pl != "" and (d % 2 == 0 or wl == ""):
		return pl if wl == "" else "%s　%s" % [wl, pl]
	return wl


static func _weather_line(w: String) -> String:
	match w:
		Weather.CLEAR_MAX: return "空が、痛いくらいに青い。"
		Weather.CLEAR: return "よく晴れている。"
		Weather.CLOUDY: return "少し、曇っている。"
		Weather.RAIN: return "雨の音がする。今日は、濡れるかもしれない。"
		Weather.SHOWER: return "空模様が、少し怪しい。ひと雨きそうだ。"
		Weather.SUNSET: return "朝から、どこか夕方みたいな色の空だ。"
		Weather.FOG: return "窓の外が、白い。霧が出ているみたいだ。"
		Weather.TYPHOON_PRE: return "風がない。やけに、蒸し暑い。"
		Weather.TYPHOON: return "雨戸が鳴っている。今日は、外は荒れそうだ。"
	return ""


static func _period_line(d: int) -> String:
	match Timeline.phase_of(d):
		"early": return "夏は、まだ始まったばかりだ。"
		"mid": return "夏の、まんなかにいる。"
		"late": return "……夏が、少しずつ終わりに近づいている。"
	return ""
