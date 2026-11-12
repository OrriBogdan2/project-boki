extends "res://tools/hero_pair_check.gd"
## --telegraph-lead-check: every delayed ground hit in the 12 kits is cast on a flat strip and timed from
## the first tick a ground telegraph that everyone sees (an AimKit entry with `all`) is up to the first
## damage on the dummy. Each must give at least the source footage's lead (briefs/hero-ref, the figures are
## in docs/TELEGRAPH_LEAD.md), show without a gap until the hit, and read in the rival colour to a rival.

const EPS := 0.05            # s of slack (the 60 Hz step and the press tick)
const MAX_T := 4.0           # s a cast gets to land

## One entry per delayed hit: {arch, name, lead (s, the source footage), start: Callable(P, T, m), and
## optional dist (m to the dummy), min (damage that counts as the hit), kept (s: the lead we ship where an
## owner decision keeps it under the source's), each: Callable(P, t), id (only AimKit entries with this id
## count), prep: Callable(P, T) (stand the dummy somewhere else)}. The figures: docs/TELEGRAPH_LEAD.md.
func _cases() -> Array:
	var rmb := func(hold: float) -> Callable:
		return func(P: Hunter, _T: Hunter, _m: Match):
			P.inp["sec_hold"] = true
			P.ak.press_rmb()
			P.set_meta("rmb_until", hold)
	var ult := func(P: Hunter, _T: Hunter, _m: Match): HunterKeys.ult_pressed(P)
	var e := func(P: Hunter, _T: Hunter, _m: Match): P.ak.use_e()
	var air_rmb := func(P: Hunter, _T: Hunter, _m: Match):
		P.teleport(P.pos + Vector3(0, 3.0, 0))
		P.grounded = false
		P.ak.press_rmb()
	var recast_e := func(P: Hunter, t: float):
		if t >= 0.35 and t < 0.4: P.ak.use_e()
	var beside := func(P: Hunter, T: Hunter):
		T.teleport(T.pos + Vector3(-1.0, 0, 1.5))
		aim_at(P, P.pos + Vector3(9.0, 0, 0))
	var second_x := func(P: Hunter, t: float):
		if t >= 0.9 and t < 0.95: HunterKeys.ult_pressed(P)
	return [
		{"arch": "dolm", "name": "Quakefall", "lead": 1.0, "kept": 0.8, "start": rmb.call(2.0)},
		{"arch": "dolm", "name": "Basalt Spine", "lead": 0.2, "start": ult},
		{"arch": "bulwark", "name": "Faultline", "lead": 0.4, "start": ult},
		{"arch": "mage", "name": "Skycall", "lead": 0.8, "start": e},
		{"arch": "mage", "name": "Eye of the Storm", "lead": 0.15, "id": "x_land", "start": ult, "each": second_x},
		{"arch": "rimewright", "name": "Ice Spear", "lead": 1.8, "min": 40.0, "dist": 8.0, "start": rmb.call(0.2)},
		{"arch": "tender", "name": "Burrseed", "lead": 0.6, "min": 30.0, "start": rmb.call(0.0)},
		{"arch": "ostra", "name": "Brimseed pop", "lead": 0.3, "start": e, "each": recast_e},
		{"arch": "ostra", "name": "Nightwell", "lead": 0.8, "start": ult},
		{"arch": "juggernaut", "name": "Finishing Slam", "lead": 0.6, "dist": 3.0, "start": rmb.call(0.0)},
		{"arch": "juggernaut", "name": "Meteor Drop", "lead": 0.85, "kept": 0.2, "dist": 2.0, "start": air_rmb},
		{"arch": "gunslinger", "name": "Burr Charge", "lead": 0.8, "prep": beside, "start": rmb.call(0.0)},
		{"arch": "gunslinger", "name": "Nuke", "lead": 1.5, "start": ult},
		{"arch": "dredge", "name": "Anchor slam", "lead": 0.4, "dist": 2.5, "start": e},
		{"arch": "thief", "name": "Shiv ult", "lead": 0.4, "dist": 3.0, "start": ult},
		{"arch": "archer", "name": "Hail Wall", "lead": 0.35, "start": e},
	]

func run(main_node: Node) -> void:
	main = main_node
	var only := ""      # --only=<arch>: just that hero's casts (they are slow)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	for c in _cases():
		if only.is_empty() or c["arch"] == only:
			await _case(c)
	print("PAIRCHECK telegraph-lead DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The ground telegraphs P is showing to everyone right now.
func _up(m: Match, P: Hunter, id: String) -> Array:
	var out: Array = []
	var d: AimDraw = AimKit.layer(m)
	for k in d.entries:
		var e: Dictionary = d.entries[k]
		if e["h"] == P and bool(e["all"]) and d.live(e) and (id.is_empty() or String(k).ends_with(":" + id)):
			out.append(e)
	return out

func _case(c: Dictionary) -> void:
	var r := setup(String(c["arch"]), float(c.get("dist", 6.0)))
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	fresh(T)
	aim_at(P, T.pos)
	var t := 0.0
	var first := -1.0
	var last := -1.0
	var hit := -1.0
	var gap := 0.0
	var rival := -1.0
	if c.has("prep"):
		c["prep"].call(P, T)
	c["start"].call(P, T, m)
	while t < MAX_T and hit < 0.0:
		if P.has_meta("rmb_until") and t >= float(P.get_meta("rmb_until")):
			P.inp["sec_hold"] = false
		if c.has("each"):
			c["each"].call(P, t)
		var up := _up(m, P, String(c.get("id", "")))
		if not up.is_empty():
			if first < 0.0:
				first = t
			elif rival < 0.0 and t >= first + 0.1:
				rival = _rival_gain(m, P, T)
			elif last >= 0.0 and t - last > 0.05:
				gap = maxf(gap, t - last)
			last = t
		m.step(DT)
		t += DT
		if dmg(T) >= float(c.get("min", 0.001)) or (T.stun_t > 0.0 and not c.has("min")):
			hit = t
	var lead := hit - first if first >= 0.0 and hit >= 0.0 else -1.0
	var tag := "%s %s" % [c["arch"], c["name"]]
	var need := float(c.get("kept", c["lead"]))
	ok(tag + ": telegraph up", first >= 0.0, "first %.2f hit %.2f" % [first, hit])
	ok(tag + ": lead >= %.2f s (source %.2f)" % [need, float(c["lead"])], lead >= need - EPS, "lead %.2f" % lead)
	var held := hit >= 0.0 and hit - last <= EPS + 0.1 and gap <= EPS
	ok(tag + ": up until the hit", held, "gap %.2f, ends %.2f before" % [gap, hit - last])
	ok(tag + ": a rival sees it in the rival colour", rival > 0.0, "gain %.3f" % rival)
	m.queue_free()
	await main.get_tree().process_frame

## How much nearer to the hostile rim colour the ground telegraphs draw for a rival of their owner than
## for an ally of theirs (mean over the vertices of what only `all` entries draw). AimDraw tints an `all`
## entry toward Feel.RIM_ENEMY for the other team.
func _rival_gain(m: Match, P: Hunter, T: Hunter) -> float:
	var d: AimDraw = AimKit.layer(m)
	var team := T.team
	var mean_gap := func() -> float:
		d.rebuild()
		var sum := 0.0
		for c in d.geo.c:
			sum += absf(c.r - Feel.RIM_ENEMY.r) + absf(c.g - Feel.RIM_ENEMY.g) + absf(c.b - Feel.RIM_ENEMY.b)
		return sum / maxf(1.0, d.geo.c.size())
	m.player = T
	T.team = P.team
	var ally: float = mean_gap.call()
	T.team = team
	var rival: float = mean_gap.call()
	m.player = P
	return ally - rival
