class_name SessionRow
extends RefCounted
## The rolling-session readout under the minimap (Rolling): session clock, when you joined, the next drop
## wave and a bounty on you. Drawn by Hud with its own helpers (no state of its own).

## A rolling session (Rolling): the session clock, when you joined, the next drop wave (or the one
## coming in now), and a bounty on you.
static func draw(hud, sr: Rect2) -> void:
	var m: Match = hud.m
	var big: Font = hud.big
	var ro: Rolling = m.rolling
	hud.mm_bottom = sr.end.y
	hud._rounded(sr, Color(0.04, 0.05, 0.08, 0.78), 6)
	var amber := Color("ffb64a")
	var st := m.sess_time()
	hud._text(sr.position + Vector2(10, 17), "SESSION %s / %s" % [Rolling.fmt(st), Rolling.fmt(Rolling.SESSION)], 11, hud.INK, big)
	var jt := "JOINED %s" % Rolling.fmt(ro.t0)
	hud._text(Vector2(sr.end.x - 10 - big.get_string_size(jt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, sr.position.y + 17), jt, 11, hud.MUTED, big)
	var line := ""; var col: Color = hud.MUTED
	var fl: Array = ro.flying_waves()
	var pulse := 0.65 + 0.35 * sin(m.time * 6.0)
	if not fl.is_empty():
		var n := 0
		for w in fl: n += int(w["n"])
		line = "WAVE INCOMING  ·  %d SQUAD%s" % [n, "" if n == 1 else "S"]
		col = Color(amber, pulse)
	else:
		var nw: Dictionary = ro.next_wave()
		if not nw.is_empty():
			line = "NEXT DROP WAVE  %s" % hud._fmt(float(nw["t"]) - st)
			col = amber.lerp(hud.MUTED, 0.45)
		else:
			line = "NO MORE DROPS  ·  GET OUT BY 30:00"
			col = hud.BAD if Rolling.SESSION - st < 120.0 else hud.MUTED
	hud._text(sr.position + Vector2(10, 35), line, 11, col, big)
	if m.player and m.player.has_meta("bounty") and not m.player.out:
		var bt := "BOUNTY ON YOU"
		hud._text(Vector2(sr.end.x - 10 - big.get_string_size(bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, sr.position.y + 35), bt, 11, Color(amber, pulse), big)
	else:
		# the lobby's level, where there's room beside the wave line (WAVE INCOMING fills the row)
		var md := "LOBBY LV %s" % (str(int(ro.median)) if absf(ro.median - round(ro.median)) < 0.01 else "%.1f" % ro.median)
		var mw := big.get_string_size(md, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		if big.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + mw + 28.0 <= sr.size.x:
			hud._text(Vector2(sr.end.x - 10 - mw, sr.position.y + 35), md, 10, Color(hud.MUTED, 0.85), big)
