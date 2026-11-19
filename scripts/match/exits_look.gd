class_name ExitsLook
extends RefCounted
## How exits look and read on screen (nodes, HUD status, demo scenes) for Exits.

var ex: Exits
var m: Match

func _init(l: Exits) -> void:
	ex = l
	m = l.m

## The outpost's look for its state (OutpostLook): lit with the charge, the banner in the holder's colour,
## the yard's edge only while you stand in it or it is contested.
func _show_outpost(x: Dictionary, n: Node3D) -> void:
	var lit := OutpostLook.lit_of(x)
	if x["state"] == "fizzling":
		lit = 1.0 if fmod(Exits.FIZZLE_T - float(x["t"]), 0.45) < 0.2 else 0.0
	elif x.get("draining", false) and x["state"] == "charging":
		lit *= 0.45 + 0.35 * sin(m.time * 7.0)
	var raised := OutpostLook.held(x)
	var col := OutpostLook.NEUTRAL
	if raised:
		col = SideColor.of_team(m.player.team if m.player else -1, int(x["team"]))
	var key := [snappedf(lit, 0.01), raised, col]
	if key != x.get("look"):
		x["look"] = key
		OutpostLook.apply(n, lit, col, 1.0 if raised else 0.0)
	if raised:
		OutpostLook.sway(n, m.time)
	var near: bool = m.player != null and ex.in_yard(x, m.player)
	var charging: bool = x["state"] == "charging"
	OutpostLook.rings(n, near or x["contested"], charging, float(x["prog"]))

## The big status line in the middle of the screen while you're in the middle of an exit, or {}.
func status_for(p: Hunter) -> Dictionary:
	if p == null or p.out or p.extracted:
		return {}
	for x in ex.list:
		if x["state"] == "charging" and ex.in_yard(x, p):
			var mine: bool = int(x["team"]) == p.team
			var t := "Uplink %d%%" % int(x["prog"] * 100.0)
			if x["contested"]: t += "  ·  CONTESTED: clear the outpost"
			elif not mine: t += "  ·  a rival's uplink: hold the outpost to take it"
			elif int(x.get("crew", 0)) > 1: t += Exits.crew_text(int(x["crew"]))
			var st := {"text": t, "prog": float(x["prog"]), "col": Color("ff8a6a") if x["contested"] or not mine else ExitModels.UPLINK}
			if mine and not x["contested"] and int(x.get("crew", 0)) <= 1:
				var a := ex.hints.alpha("outpost", m.time)
				if a > 0.0:
					st["hint"] = "More teammates in the %s fuel it faster!" % x["name"]
					st["hint_a"] = a
			return st
		if x["state"] == "charging" and int(x["team"]) == p.team and x.get("draining", false) and p.flat_dist(x["pos"]) < 80.0:
			# our uplink with nobody in its yard: the charge running out, and how long it has
			return {"text": "Uplink draining  ·  %d%%  ·  back to the outpost: %s" % [int(x["prog"] * 100.0), ex._cap(ex.drain_left(x))], "prog": float(x["prog"]),
				"col": ExitModels.UPLINK.lerp(Color.WHITE, 0.2 + 0.2 * sin(m.time * 7.0))}
	return {}

## Test hook (--exit-demo=<mode>): sets up an uplink in action next to the player for a screenshot.
## Modes: uplink (charging, contested by a rival in the yard), lift (the uplink completes and the lift
## opens), drain (your uplink charging with nobody in its yard).
func demo(mode: String) -> void:
	var p := m.player
	if p == null or ex.list.is_empty():
		return
	if m.has_meta("xdemo"):
		var R0 = m.get_meta("xdemo_r", null)
		for h in [p, R0]:
			if h != null and h.has_meta("pin") and not h.extracted:
				h.teleport(h.get_meta("pin")); h.vel = Vector3.ZERO
		# hold the moment: screenshots take a varying amount of game time to render
		var hold: Array = m.get_meta("xdemo_hold", [])
		if not hold.is_empty():
			var hx: Dictionary = hold[0]
			if String(hx["state"]) == String(hold[1]):
				hx[String(hold[2])] = hold[3]
		return
	m.set_meta("xdemo", true)
	var R: Hunter = null
	for h in m.hunters:
		if h == p: continue
		h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO
		if R == null and h.team != p.team: R = h
		h.teleport(m.world.random_ground())
	m.set_meta("xdemo_r", R)
	p.max_hp = 5000.0; p.hp = 5000.0
	match mode:
		"uplink", "lift":
			var o: Dictionary = ex.uplink_x()
			m.time = float(o["open_at"]) + 1.0
			ex.act(o, "start", p)
			o["wave_t"] = 0.0
			o["prog"] = 0.55 if mode == "uplink" else 0.93
			m.set_meta("xdemo_hold", [o, "charging", "prog", 0.55] if mode == "uplink" else [o, "open", "t", 12.0])
			p.teleport(o["pos"] + Vector3(1.5, 0, 2.2))
			if R and mode == "uplink":
				R.teleport(o["pos"] + Vector3(-2.0, 0, -1.4))
			elif R:
				R.teleport(m.world.random_ground())
			m.cam.zoom_to = 0.85
		"drain":
			# your uplink charging with nobody in its yard: the charge draining (HUD, mast, clock)
			var o: Dictionary = ex.uplink_x()
			m.time = float(o["open_at"]) + 1.0
			ex.act(o, "start", p)
			o["wave_t"] = 99.0
			o["prog"] = 0.6
			m.set_meta("xdemo_hold", [o, "charging", "prog", 0.6])
			var off := Vector3(Exits.OUTPOST_R + 1.6, 0, 1.0)
			p.teleport(m.world.free_spot_near(o["pos"] + off, [], 0.6, 0.5, 3.0))
			if R: R.teleport(m.world.random_ground())
			m.cam.zoom_to = 0.85
	p.set_meta("pin", p.pos)
	if R: R.set_meta("pin", R.pos)
	m.cam.snap(p.pos)
