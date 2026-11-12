extends "res://tools/hero_pair_check.gd"
## --telegraph-sync-check: a delayed ground hit is only fair if the telegraph everyone sees (an AimKit entry
## with `all`) finishes filling on the frame the damage lands. Each of the delayed hits in the 12 kits is
## cast on a flat strip at 30, 60 and 144 fps; the frame the fill reaches 1 (read off the entry, or
## extrapolated from the last two frames when the kit hides it on the hit frame) must be within one frame
## of the first damage on the dummy. A telegraph with no fill (the source draws cracks or a lane) must be
## refreshed to within one frame of the hit. Online, the cue other players get (the Net fx ring a kit sends) must
## go out on the frame the telegraph first shows (a Net fx ring, or a HeroVfx play such as Skycall's e_count).
## The delays are in each kit's JSON (docs/TELEGRAPH_LEAD.md).

const FPS := [30, 60, 144]
const FULL := 0.999         # a fill at or above this is full
const MAX_T := 4.0          # s a cast gets to land
const EPS := 0.002          # s of float slack on top of the one frame

## One entry per delayed hit: {arch, name, start: Callable(P, T, m)} and optional dist (m to the dummy),
## min (damage that counts as the hit), id (only AimKit entries with this id count), each: Callable(P, T, t),
## prep: Callable(P, T), plain (the telegraph has no fill: it must end with the hit), ring (the kit sends other
## players a ring when the telegraph starts).
func _cases() -> Array:
	var rmb := func(secs: float) -> Callable:
		return func(P: Hunter, _T: Hunter, _m: Match):
			P.inp["sec_hold"] = true
			P.ak.press_rmb()
			P.set_meta("rmb_until", secs)
	var ult := func(P: Hunter, _T: Hunter, _m: Match): HunterKeys.ult_pressed(P)
	var e := func(P: Hunter, _T: Hunter, _m: Match): P.ak.use_e()
	var air_rmb := func(P: Hunter, _T: Hunter, _m: Match):
		P.teleport(P.pos + Vector3(0, 3.0, 0))
		P.grounded = false
		P.ak.press_rmb()
	var beside := func(P: Hunter, T: Hunter):
		T.teleport(T.pos + Vector3(-1.0, 0, 1.5))
		aim_at(P, P.pos + Vector3(9.0, 0, 0))
	var second_x := func(P: Hunter, _T: Hunter, t: float):
		if t >= 0.9 and t < 0.95: HunterKeys.ult_pressed(P)
	var by_burr := func(P: Hunter, T: Hunter, _t: float):     # the dummy goes to the stuck burr's cone
		for b in P.ak.get("burrs"):
			if float(b["fuse"]) >= 0.0 and not T.has_meta("moved"):
				T.set_meta("moved", true)
				T.teleport(b["pos"] + Vector3(b["out"].x, 0, b["out"].y) * 2.0)
	return [
		# Basalt Spine left: its cracks are HeroVfx "spine"/"spine_lane" plays now (no AimKit entry the AimDraw
		# probe can read), same call as --telegraph-lead-check (docs/TELEGRAPH_LEAD.md)
		{"arch": "bulwark", "name": "Faultline", "ring": true, "min": 10.0, "dist": 13.5, "id": "x", "start": ult},
		{"arch": "mage", "name": "Skycall", "ring": true, "start": e},
		{"arch": "mage", "name": "Eye of the Storm", "ring": true, "id": "x_land", "start": ult, "each": second_x},
		{"arch": "rimewright", "name": "Ice Spear", "min": 40.0, "dist": 8.0, "start": rmb.call(0.2)},
		{"arch": "tender", "name": "Burrseed", "min": 30.0, "start": rmb.call(0.0)},
		{"arch": "ostra", "name": "Nightwell", "ring": true, "start": ult},
		{"arch": "juggernaut", "name": "Finishing Slam", "dist": 3.0, "start": rmb.call(0.0)},
		# Meteor Drop is straight down now (jugg-downslam): a 2.4 m circle 0.8 m ahead, so the dummy stands at 2 m
		{"arch": "juggernaut", "name": "Meteor Drop", "dist": 2.0, "start": air_rmb},
		{"arch": "gunslinger", "name": "Burr Charge", "prep": beside, "each": by_burr, "start": rmb.call(0.0)},
		{"arch": "gunslinger", "name": "Nuke", "ring": true, "start": ult},
		{"arch": "dredge", "name": "Anchor slam", "dist": 2.5, "start": e},
		{"arch": "archer", "name": "Hail Wall", "plain": true, "id": "e", "start": e},
	]

func run(main_node: Node) -> void:
	main = main_node
	var only := ""      # --only=<arch>: just that hero's casts
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	for c in _cases():
		if only.is_empty() or c["arch"] == only:
			for fps in FPS:
				await _case(c, 1.0 / fps)
	print("PAIRCHECK telegraph-sync DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The ground telegraphs P shows to everyone right now: {fill: the biggest fill (-1: none), at: when the kit
## last refreshed one, plus its own run-out for a one-off (-1: none up)}.
func _seen(m: Match, P: Hunter, id: String) -> Dictionary:
	var out := {"fill": -1.0, "at": -1.0}
	var d: AimDraw = AimKit.layer(m)
	for k in d.entries:
		var en: Dictionary = d.entries[k]
		if en["h"] == P and bool(en["all"]) and d.live(en) and (id.is_empty() or String(k).ends_with(":" + id)):
			out["fill"] = maxf(out["fill"], float(en["fill"]) if en.has("fill") else -1.0)
			var one_off := 0.0       # a "dur" entry runs itself out
			if float(en["keep"]) > AimDraw.KEEP:
				one_off = float(en["keep"])
			out["at"] = maxf(out["at"], float(en["t"]) + one_off)
	return out

func _case(c: Dictionary, dt: float) -> void:
	var r := setup(String(c["arch"]), float(c.get("dist", 6.0)))
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	fresh(T)
	aim_at(P, T.pos)
	if c.has("prep"):
		c["prep"].call(P, T)
	m.net_on = true
	Net.out_events.clear()
	c["start"].call(P, T, m)
	var t0: float = m.time
	var t := 0.0
	var first := -1.0                # the first frame a telegraph shows
	var ring_at: Array[float] = []   # the frames a Net fx ring went out (0: the press itself)
	var hit := -1.0
	var full := -1.0
	var prev := Vector2(-1, -1)      # the last two (t, fill) frames with a fill showing
	var last := Vector2(-1, -1)
	var refreshed := -1.0            # the last time a telegraph without a fill was refreshed
	while t < MAX_T and hit < 0.0:
		if P.has_meta("rmb_until") and t >= float(P.get_meta("rmb_until")):
			P.inp["sec_hold"] = false
		if c.has("each"):
			c["each"].call(P, T, t)
		m.step(dt)
		t += dt
		var seen := _seen(m, P, String(c.get("id", "")))
		for ev in Net.out_events:
			if ev[0] == "fx" and ev[1] in ["ring", "hvfx"]:    # a Net ring or a HeroVfx play
				ring_at.append(t)
		Net.out_events.clear()
		if first < 0.0 and float(seen["at"]) >= 0.0:
			first = t
		refreshed = maxf(refreshed, float(seen["at"]) - t0)
		var f: float = seen["fill"]
		if f >= 0.0:
			prev = last
			last = Vector2(t, f)
			if f >= FULL and full < 0.0:
				full = t
		if dmg(T) >= float(c.get("min", 0.001)) or (T.stun_t > 0.0 and not c.has("min")):
			hit = t
	if c.has("plain") and refreshed >= 0.0:
		full = refreshed + dt            # drawn until the step before this one, so it ends with it
		last = Vector2(refreshed, 1.0)
	elif full < 0.0 and prev.x >= 0.0 and last.y > prev.y:
		full = last.x + (1.0 - last.y) * (last.x - prev.x) / (last.y - prev.y)
	var tag := "%s %s @%d fps" % [c["arch"], c["name"], roundi(1.0 / dt)]
	ok(tag + ": fill shows", last.x >= 0.0, "hit %.3f" % hit)
	ok(tag + ": fill ends with the hit", hit >= 0.0 and full >= 0.0 and absf(hit - full) <= dt + EPS,
		"fill end %.3f hit %.3f" % [full, hit])
	if c.has("ring"):
		ok(tag + ": other players' ring goes out with it", ring_at.any(func(r): return absf(r - first) <= dt + EPS),
			"telegraph %.3f rings %s" % [first, ring_at])
	m.net_on = false
	m.queue_free()
	await main.get_tree().process_frame
