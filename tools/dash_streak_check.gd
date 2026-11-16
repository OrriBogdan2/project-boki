extends RefCounted
## --dash-streak-check[=<id>,<id>]: every Hunter's ground dash, air dash and a dash chained straight after
## another lays DashStreak pieces in the Hunter's ability colour while it runs, and none is left LIFE + 0.1 s
## after it ends. Also: the pool is not grown by a dash (no node made after the first).

const WATCH_STEPS := 150       # sim steps (1/60 s) a dash may run before the check gives up on it ending
const GAP_S := DashStreak.LIFE + 0.1
const COL_EPS := 0.02

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("DASHSTREAK FAIL %s" % what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		DashStreak.of(m).set_process(false)
		await _case(main, m, hero, "dash", 1)
		await _case(main, m, hero, "air dash", 1)
		await _case(main, m, hero, "chained dash", 2)
		m.queue_free()
		await main.get_tree().process_frame
	print("DASHSTREAK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dash-streak-check=") and arg.length() > 20:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## Steps the match until the dash is over; the most pieces showing while it ran, and whether any had the colour.
func _run_dash(main: Node, m: Match, h: Hunter, want: Color) -> Dictionary:
	var st := DashStreak.of(m)
	var peak := 0
	var tinted := false
	var ran := false
	var idle := 0.0
	for i in WATCH_STEPS:
		m.step(Match.DT)
		h.render(Match.DT, 1.0)         # (the match draws in _process, which a check does not run)
		st.step(Match.DT)
		await main.get_tree().process_frame
		var going := h.roll_t > 0.0 or h.ak.dash_left() > 0.0
		ran = ran or going
		if going:
			peak = maxi(peak, st.live)
			idle = 0.0
			for c in st.get_children():
				var mi := c as MeshInstance3D
				var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
				tinted = tinted or (mi.visible and _same(col, want))
		else:
			idle += Match.DT
		if ran and idle >= GAP_S:
			break
	return {"ran": ran, "peak": peak, "tinted": tinted}

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < COL_EPS and absf(a.g - b.g) < COL_EPS and absf(a.b - b.b) < COL_EPS

func _case(main: Node, m: Match, hero: String, ev: String, n: int) -> void:
	var h: Hunter = flow.hunter
	flow._ready_up(m)
	for mb in m.mobs:
		mb.dead = true
	for o in m.hunters:
		if o != h:
			o.out = true
	if ev == "air dash":
		flow._lift()
	var st := DashStreak.of(m)
	var made := st.get_child_count()
	var want := Arch.color(h.arch).lerp(Color.WHITE, 0.2)
	var all_ran := true
	var all_laid := true
	var peaks: Array = []
	for k in n:
		h.dashes = h.max_dashes()      # (a one-charge kit chains on a refill: the streak is judged, not the charges)
		h.inp["move"] = Vector2(0, -1)
		h.inp["dash"] = true
		h.inp["dash_down"] = true
		m.step(Match.DT)
		h.inp["dash"] = false
		h.inp["dash_down"] = false     # a tap: holding Shift is a charge tell (Sparkle) or a skate (Neve)
		var r: Dictionary = await _run_dash(main, m, h, want)
		all_ran = all_ran and r["ran"]
		all_laid = all_laid and r["peak"] > 0 and r["tinted"]
		peaks.append(r["peak"])
	var tag := "%s/%s" % [hero, ev]
	print("DASHSTREAK %-10s %-12s ran %s, peak pieces %s, left %d" % [hero, ev, all_ran, peaks, st.live])
	ok(all_ran, "%s: the dash never ran" % tag)
	ok(all_laid, "%s: no streak piece in %s while it ran" % [tag, want.to_html(false)])
	ok(st.live == 0, "%s: %d piece(s) still showing %.1f s after the dash" % [tag, st.live, GAP_S])
	ok(st.get_child_count() == made, "%s: the pool grew" % tag)
