extends RefCounted
## --time-trial-check: the Training Grounds' time trial. Ten gates, a start and a finish arch and the pad are
## built; the course asks for a dash, a wall kick, the pad and a glide (the kick tower can't be climbed with a
## plain jump, the glide tower only by the pad); a scripted run with real inputs goes start -> ten gates ->
## finish and sets this Hunter's best; a dash gate walked through doesn't count; a slower run keeps the best;
## a Hunter swap, a fall or walking off the course (a toast says so) ends the run; the clock, the pedestal
## prompt never overlap the HUD, the FPS counter, toasts or the hunter at three window sizes; each station kind
## has a sign (the bot pen's says how to spawn a bot); a v21 save migrates to an empty best list.
## Prints TIMETRIALCHECK PASS/FAIL.

const DT := 1.0 / 60.0
const RUN_CAP := 120.0  # [s] a scripted run that takes longer has got stuck
const HUNTER_BOX := Vector2(160, 170)  # [px] the hunter and its plate, mid-screen (HunterZone needs a running camera)
const DASH_AT := 3.0  # [m] the scripted run dashes this far before a dash gate

var main: Node
var fails := 0
var n := 0


func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("TIMETRIALCHECK %-46s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d["time_trial"] = {}
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	var t: TimeTrial = m.arena.grounds.trial
	_built(m, t)
	_heights(m, t)
	_full_run(m, t)
	_dash_gate(m, t)
	_slower_and_swap(m, t)
	_leave(m, t)
	await _layout(m, t)
	_signs(m)
	_migrate()
	print("TIMETRIALCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()


func _built(m: Match, t: TimeTrial) -> void:
	var moves := {}
	for g in t.gates:
		moves[g.move] = true
	var placed := t.start != Vector3.INF and t.finish != Vector3.INF and t.pad_at != Vector3.INF
	ok("ten gates, start and finish arch, pad", t.gates.size() == 10 and placed, "%d gates" % t.gates.size())
	var c := t.clock
	var centred := c.anchor_left == 0.0 and c.anchor_right == 1.0 and c.offset_left == 0.0 and c.offset_right == 0.0
	ok("the clock is centred, under the top panel", centred and c.offset_top >= 180.0, "top %.0f" % c.offset_top)
	var gap := Vector2(t.finish.x - t.start.x, t.finish.z - t.start.z).length()
	ok("the finish arch stands apart from the start arch", gap > 7.0, "%.1f m" % gap)
	ok(
		"the gates ask for dash, kick, pad, glide",
		moves.has("dash") and moves.has("kick") and moves.has("pad") and moves.has("glide"),
		str(moves.keys())
	)
	var on_floor := [t.start, t.finish, t.pad_at].all(func(p): return m.world.island_id(p.x, p.z) == "floor")
	ok("the course is on the open floor", on_floor)


## The kick tower is four terraces (over a plain jump and mantle), the glide tower more than a kick reaches.
func _heights(m: Match, t: TimeTrial) -> void:
	var kick := _gate(t, "kick")
	var kick_top := m.world.ground_at(kick.at.x, kick.at.z)
	var glide_top := t.pad_land.y
	var cap := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV) + HunterFeel.mantle_reach
	ok("kick tower is out of a plain jump's reach", kick_top > cap, "%.1f m vs %.1f" % [kick_top, cap])
	ok("glide tower is out of a wall kick's reach", glide_top > WallMoves.HOP_CLIMB_CAP + cap, "%.1f m" % glide_top)


func _gate(t: TimeTrial, move: String) -> TimeTrial.Gate:
	for g in t.gates:
		if g.move == move:
			return g
	return null


## Real inputs from behind the start arch to the finish: steer at the next gate, dash before a dash gate,
## jump and kick at the kick tower, step on the pad, glide once falling toward a glide gate.
func _full_run(m: Match, t_v: TimeTrial) -> void:
	var p: Hunter = m.player
	var t := _drive(m, t_v)
	var info := "gate %d, %.2f s" % [t_v.next_i, t_v.last_time]
	ok("a run with real inputs finishes all ten gates", t > 0.0 and not t_v.running, info)
	ok("the run used a wall kick", int(p.stats.get("wall_kicks", 0)) > 0, str(p.stats.get("wall_kicks", 0)))
	ok(
		"the finish is this Hunter's best",
		is_equal_approx(TimeTrial.best("gunslinger"), snappedf(t_v.last_time, 0.01)),
		"%.2f" % TimeTrial.best("gunslinger")
	)
	ok("another Hunter has no best yet", TimeTrial.best("thief") == 0.0)


## Drives one run; returns its time (0 when it didn't finish inside RUN_CAP).
func _drive(m: Match, t_v: TimeTrial) -> float:
	var p: Hunter = m.player
	var back := t_v.start - t_v.gates[0].at
	back.y = 0.0
	p.teleport(t_v.start + back.normalized() * 3.0)
	p.vel = Vector3.ZERO
	var t := 0.0
	var dashed := -1
	var was_on := false
	while t < RUN_CAP:
		for k in ["jump", "dash", "glide"]:
			p.inp[k] = false
		var g: TimeTrial.Gate = t_v.gates[t_v.next_i] if t_v.running and t_v.next_i < t_v.gates.size() else null
		var tgt := t_v.finish if t_v.running else t_v.start
		if g:
			tgt = t_v.pad_at if g.move == "pad" and p.pad.is_empty() and p.pos.y < g.at.y - 3.0 else g.at
		var to := Vector2(tgt.x - p.pos.x, tgt.z - p.pos.z)
		p.inp["move"] = to.normalized()
		if g and g.move == "dash" and p.grounded and to.length() < DASH_AT and dashed != t_v.next_i:
			p.inp["dash"] = true
			dashed = t_v.next_i
		if g and g.move == "kick" and p.pos.y < g.at.y - 1.5 and to.length() < 3.5:
			var falling := not p.grounded and p.vel.y <= 0.5
			p.inp["jump"] = p.grounded or (falling and p.wall_touch_t > 0.0)
		if g and g.move == "glide" and not p.grounded and p.pad.is_empty():
			p.inp["glide"] = true
		m.step(DT)
		t += DT
		was_on = was_on or t_v.running
		if was_on and not t_v.running:
			return t_v.last_time
	return 0.0


## A dash gate walked through doesn't count.
func _dash_gate(m: Match, t: TimeTrial) -> void:
	var p: Hunter = m.player
	var i := t.gates.find(_gate(t, "dash"))
	t.running = true
	t.run_arch = p.arch
	t.next_i = i
	var g: TimeTrial.Gate = t.gates[i]
	p.teleport(g.at - Vector3(0, TimeTrial.BODY_UP, 0))
	p.roll_t = 0.0
	t.tick(DT)
	ok("a dash gate walked through doesn't count", t.next_i == i)
	p.roll_t = 0.2
	t.tick(DT)
	ok("a dash gate dashed through counts", t.next_i == i + 1)
	t.stop()


## A slower time keeps the best; a Hunter swap and a fall each end a run.
func _slower_and_swap(m: Match, t: TimeTrial) -> void:
	var b := TimeTrial.best("gunslinger")
	ok("a slower run keeps the best", not TimeTrial.record("gunslinger", b + 5.0) and TimeTrial.best("gunslinger") == b)
	ok("a faster run takes it", TimeTrial.record("gunslinger", b - 1.0) and TimeTrial.best("gunslinger") < b)
	var p: Hunter = m.player
	t.running = true
	t.run_arch = p.arch
	m.arena.set_arch("thief")
	t.tick(DT)
	ok("a Hunter swap ends the run", not t.running and m.player.arch == "thief")
	t.running = true
	m.player.teleport(Vector3(60, -20, 25))
	m.arena.grounds.tick(DT)
	ok("a fall ends the run", not t.running)


func _migrate() -> void:
	var old := {"v": 21, "roster": []}
	var good := Save.migrate(old)
	var bests = old.get("time_trial", null)
	var empty: bool = bests is Dictionary and (bests as Dictionary).is_empty()
	ok("a v21 save gets an empty best list", good and int(old["v"]) == Save.VERSION and empty)
	ok("a fresh save has one", Save.fresh().get("time_trial", null) is Dictionary)


## Walking off the course ends the run with a toast; a step past the last gate (inside the margin) doesn't.
func _leave(m: Match, t: TimeTrial) -> void:
	var p: Hunter = m.player
	var g: TimeTrial.Gate = t.gates[0]
	t.running = true
	t.run_arch = p.arch
	t.next_i = 1
	m.hud.msgs.clear()
	p.teleport(Vector3(t.area.position.x + TimeTrial.LEAVE_MARGIN * 0.5, 0.0, g.at.z))
	t.tick(DT)
	ok("a step off the course (inside the margin) keeps the run", t.running)
	p.teleport(Vector3(t.area.position.x - 1.0, 0.0, g.at.z))
	t.tick(DT)
	var said: bool = m.hud.msgs.texts().has("Trial cancelled - left the course")
	ok("leaving the course ends the run with a toast", not t.running and said, str(m.hud.msgs.texts()))
	ok("the area covers start, gates, pad and finish", t.area.has_point(Vector2(t.finish.x, t.finish.z)))


## The clock, the pedestal prompt and the toasts at three window sizes: none overlaps the FPS counter (full
## overlay), the minimap, the arena's banner and meter, the practice bar, each other or the hunter.
func _layout(m: Match, t: TimeTrial) -> void:
	Settings.v["show_fps"] = 2
	var g: Grounds = m.arena.grounds
	t.clock.text = "0:42.31  ·  gate 10 / 10  ·  best 0:40.00"
	t.clock.visible = true
	g.prompt.text = "Bot: Juggernaut   ·   Enter"
	g.prompt.visible = true
	m.hud.msgs.clear()
	m.hud.toast("Time trial  0:42.31  ·  your first best", Color.WHITE)
	m.hud.toast("Trial cancelled - left the course", Color.WHITE)
	for sz in [Vector2i(1280, 720), Vector2i(1706, 775), Vector2i(1920, 1080)]:
		main.get_window().size = sz
		for _i in 40:
			await main.get_tree().process_frame
		var vs := m.get_viewport().get_visible_rect().size
		var others := {
			"fps": Overlay.fps_lbl.get_global_rect(),
			"minimap": Rect2(HudStyle.safe_pad(vs), Vector2(196, 196)),
			"banner": m.arena.hint.get_global_rect(),
			"meter": m.arena.meter.get_global_rect(),
			"practice bar": Practice.of(m).bar.get_global_rect(),
			"kit drill": _kit_panel(m),
			"hunter": Rect2(vs * 0.5 - HUNTER_BOX * 0.5, HUNTER_BOX),  # (the camera keeps the hunter mid-screen)
		}
		for i in m.hud.msgs.rects().size():
			others["toast %d" % i] = m.hud.msgs.rects()[i]
		var mine := {"clock": t.clock.get_global_rect(), "prompt": g.prompt.get_global_rect()}
		var real := others.values().all(func(r: Rect2): return r.has_area())
		ok("every reserved rect is real at %dx%d" % [sz.x, sz.y], real and others.size() == 9, str(others))
		var clash := []
		for a_k in mine:
			for b_k in others:
				if (mine[a_k] as Rect2).intersects(others[b_k]):
					clash.append("%s/%s" % [a_k, b_k])
		if (mine["clock"] as Rect2).intersects(mine["prompt"]):
			clash.append("clock/prompt")
		ok("no overlap at %dx%d (window %s)" % [sz.x, sz.y, vs], clash.is_empty(), "%s %s" % [clash, mine])
	t.stop()
	g.prompt.visible = false


## Each station kind has a sign that names its purpose and the interact key; the bot pen's says how to spawn a bot.
func _signs(m: Match) -> void:
	var texts := []
	for ch in m.get_children():
		if ch is Label3D and (ch as Label3D).text.contains("Stand on a pedestal"):
			texts.append((ch as Label3D).text)
	var key := Settings.key_cap("interact")
	var bot := texts.filter(func(x): return x.contains("Practise your combos"))
	var spawn := " ".join(PackedStringArray(bot)).replace("\n", " ").contains("press %s to spawn a sparring bot" % key)
	ok("one sign per station kind", texts.size() == Grounds.SIGNS.size(), str(texts.size()))
	ok("the bot pen's sign says what it is for and how to spawn a bot", bot.size() == 1 and spawn, str(bot))


## The kit drill's banner (a top-centre panel the Training Grounds always shows), through its `_panel` field.
func _kit_panel(m: Match) -> Rect2:
	for ch in Practice.of(m).get_children():
		if ch is KitDrill:
			return (ch.get("_panel") as Control).get_global_rect()
	return Rect2()
