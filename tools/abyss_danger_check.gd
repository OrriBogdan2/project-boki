extends RefCounted
## --abyss-danger-check: the abyss warning builds with depth instead of switching on at the lip
## (content/rules/abyss_danger.json). Over a 17 m drop from the lip to the point of no return: the tint
## starts at the reference's 0.25 m and the warning heartbeat at its 3 m (the wind: --abyss-check), no
## tint down to start_depth, then the tint and the warning heartbeat (level and rate) rise
## monotonically, the tint to 1 exactly at the kill depth, and both are gone again on the way back up.

const SPAN := 17.5  # m, lip to the point of no return (World.ABYSS_DEPTH + HunterFeel.abyss_extra)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("ADANGER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	var start := float(Content.rules("abyss_danger")["start_depth"])
	var fx = load("res://scripts/match/abyss_fx.gd")
	var audio := float(Content.rules("abyss_danger")["audio_from"])
	ok(is_equal_approx(start, 0.25), "the tint starts 0.25 m under the lip, as the reference (%.2f m)" % start)
	ok(is_equal_approx(audio, 3.0), "the wind and warning start 3 m under the lip, as the reference (%.2f m)" % audio)
	var shallow := true
	for i in 41:
		var d := start * float(i) / 40.0
		shallow = shallow and fx.danger_depth(d, SPAN) == 0.0
	ok(shallow, "a dip of up to %.2f m under the lip: no tint" % start)
	ok(fx.danger_depth(start + 0.1, SPAN) > 0.0, "just past the start depth the tint begins")
	var quiet := true
	for i in 41:
		quiet = quiet and AbyssFallSfx.warn_db(fx.danger_depth(audio * 0.999 * float(i) / 40.0, SPAN)) == -INF
	ok(quiet, "no heartbeat down to %.1f m" % audio)
	ok(AbyssFallSfx.warn_db(fx.danger_depth(audio + 0.1, SPAN)) > -INF, "the heartbeat starts just past %.1f m" % audio)
	var real_span := World.ABYSS_DEPTH - 0.5 + HunterFeel.abyss_extra
	ok(is_equal_approx(AbyssFallSfx.audio_k(), fx.danger_depth(audio, real_span)), "its start is the tint at 3 m")
	var prev_k := -1.0
	var prev_db := -INF
	var prev_rate := 0.0
	var mono := true
	var steps := 200
	for i in steps + 1:
		var d := start + (SPAN - start) * float(i) / steps
		var k: float = fx.danger_depth(d, SPAN)
		var db := AbyssFallSfx.warn_db(k)
		var rate := AbyssFallSfx.warn_rate(k)
		if k < prev_k or db < prev_db or rate < prev_rate:
			mono = false
		prev_k = k
		prev_db = db
		prev_rate = rate
	ok(mono, "tint, warning level and warning rate never fall as you go deeper")
	ok(is_equal_approx(fx.danger_depth(SPAN, SPAN), 1.0), "full tint exactly at the point of no return")
	ok(fx.danger_depth(SPAN + 3.0, SPAN) == 1.0, "and it stays at 1 below it")
	var mid: float = fx.danger_depth(start + (SPAN - start) * 0.5, SPAN)
	ok(mid > 0.15 and mid < 0.5, "half way down it is a hint, not a wash (%.2f)" % mid)
	var db_full := AbyssFallSfx.warn_db(1.0)
	var db_mid := AbyssFallSfx.warn_db(mid)
	var db_low := AbyssFallSfx.warn_db(fx.danger_depth(start + 3.0, SPAN))
	ok(
		db_low < db_mid and db_mid < db_full and db_full <= 0.0,
		"warning volume follows depth (%.1f < %.1f < %.1f dB)" % [db_low, db_mid, db_full]
	)
	ok(AbyssFallSfx.warn_rate(1.0) > AbyssFallSfx.warn_rate(0.3) * 1.5, "the heartbeat quickens toward the end")
	ok(fx.danger_depth(SPAN * 0.9, SPAN, true) >= fx.danger_depth(SPAN * 0.9, SPAN), "an empty glider reads no better")
	ok(fx.danger_depth(start * 0.9, SPAN, true) == 0.0, "an empty glider still shows nothing above the start")
	print("ABYSS DANGER CHECK DONE, failures: ", bad)
	m.get_tree().quit()
