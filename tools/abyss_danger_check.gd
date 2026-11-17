extends RefCounted
## --abyss-danger-check: the abyss warning builds with depth instead of switching on at the lip
## (content/rules/abyss_danger.json). Over a 17 m drop from the lip to the point of no return: no tint
## and no sound down to start_depth, then the tint and the warning heartbeat (level and rate) rise
## monotonically, the tint to 1 exactly at the kill depth, and both are gone again on the way back up.

const SPAN := 17.5   # m, lip to the point of no return (World.ABYSS_DEPTH + Hunter.ABYSS_EXTRA)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("ADANGER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	var start := float(Content.rules("abyss_danger")["start_depth"])
	var fx = load("res://scripts/match/abyss_fx.gd")
	ok(start >= 2.0 and start < SPAN * 0.5, "start depth is a real margin (%.1f m)" % start)
	var shallow := true
	for i in 41:
		var d := start * float(i) / 40.0
		shallow = shallow and fx.danger_depth(d, SPAN) == 0.0 and AbyssFallSfx.warn_db(fx.danger_depth(d, SPAN)) == -INF
	ok(shallow, "a dip of up to %.1f m under the lip: no tint, no sound" % start)
	ok(fx.danger_depth(start + 0.2, SPAN) > 0.0, "just past the start depth the tint begins")
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
	var db_low := AbyssFallSfx.warn_db(fx.danger_depth(start + 0.5, SPAN))
	ok(db_low < db_mid and db_mid < db_full and db_full <= 0.0, "warning volume follows depth (%.1f < %.1f < %.1f dB)" % [db_low, db_mid, db_full])
	ok(AbyssFallSfx.warn_rate(1.0) > AbyssFallSfx.warn_rate(0.3) * 1.5, "the heartbeat quickens toward the end")
	ok(fx.danger_depth(SPAN * 0.9, SPAN, true) >= fx.danger_depth(SPAN * 0.9, SPAN), "an empty glider reads no better")
	ok(fx.danger_depth(start * 0.9, SPAN, true) == 0.0, "an empty glider still shows nothing above the start")
	print("ABYSS DANGER CHECK DONE, failures: ", bad)
	m.get_tree().quit()
