extends "res://tools/online_displace_check.gd"
## --online-rocket-check[=<delay ms>]: the squad rocket drop (DropRocket) seen from the other game. Three real
## processes (relay server, host, guest; tools/udp_delay.py holds every datagram `delay` ms each way, default
## 100). Host and guest are one squad: the host leads and steers, the guest rides, jumps out, free-falls (steering
## with the keys), pulls the glider with a fresh press and lands; the rocket lands on its own. Every frame each game
## records every remote body it knows (hunters driven by the other game, the rocket's follower copy) and flags any
## step over STEP_MAX. The table goes to <user dir>/online_displace/rocket.md (docs/ONLINE_FEEL.md keeps a copy).
## Lines: ODROCKET ok|FAIL ...

const STEP_MAX := 0.5         # m in one frame on a remote body: more reads as a snap
const OWN_SNAP := 1.0         # m: the guest's own body on the rocket (the 0.8 m seat drop at launch is by design)
const SKEW := 0.2             # s: the guest's ship runs this far ahead of the host's (games never start together)
const RIDE_S := 3.0           # s of the ship's run before the leader launches
const JUMP_AFTER := 1.6       # s of rocket flight before the guest jumps out
const GLIDE_AFTER := 1.4      # s of free fall (steered) before the fresh glide press
const CAP_S := 60.0           # s of match time before the run gives up

var _st := ""                 # the player's last state, for the marks
var _rk_end := false
var _acc := 0.0
var spot_xz := Vector2.ZERO   # the island spot the host steers the rocket to; the guest's glide heads there too
var steer_home := false       # the guest's glide heads for where the squad's rocket lands (not into the abyss)

func _init() -> void:
	flag = "--online-rocket-check"
	tag = "ODROCKET"

func _start_dict() -> Dictionary:
	return {"mid": "or%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 2, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": peer_id, "team": 0, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}

## A real match (the ship, the drop) on both games; the planning phase skipped, no monsters in the way.
func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	await nm.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": SEED, "cls": "medium", "net": d})
	nm.set_process(false)
	nm.skydrop.planning = false
	m = nm

## A match runs on real time, as a real game does (a step per DT of wall clock, caught up after a slow frame):
## one step a frame would let the two games' clocks drift apart on a loaded box, and NetSmooth reads that as lag.
## Sampled once a frame, after its steps: the step a player would see between two frames.
func _run(secs: float) -> void:
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		var us := Time.get_ticks_usec()
		_acc += clampf(float(us - last) * 1e-6, 0.0, 0.1)
		last = us
		var n := int(_acc / DT)
		_acc -= n * DT
		for i in n:
			m.step(DT)
		t += n * DT
		if n > 0:
			_frame(n * DT)
		await main.get_tree().process_frame

## Every frame: where each remote body is on this game, and what this game's own player does (the marks).
func _frame(sim_dt: float) -> void:
	var now := Time.get_unix_time_from_system()
	for h in m.hunters:
		if h.remote:
			lines.append("%.3f,%s,%.3f,%.3f,%.3f,%.4f" % [now, h.nid, h.pos.x, h.pos.y, h.pos.z, sim_dt])
	lines.append("%.3f,ME,%.3f,%.3f,%.3f,%.4f" % [now, m.player.pos.x, m.player.pos.y, m.player.pos.z, sim_dt])
	var r: DropRocket = m.skydrop.rockets.get(m.player.team, null)      # (the squad's own: bot squads fly theirs)
	if r != null:
		if not r.done:
			lines.append("%.3f,RK,%.3f,%.3f,%.3f,%.4f" % [now, r.pos.x, r.pos.y, r.pos.z, sim_dt])
		elif not _rk_end:
			_rk_end = true
			lines.append("%.3f,@rocket_end,0,0,0" % now)
	var P := m.player
	var st := "ship"
	if P.rocket != null: st = "ride"
	elif P.riding: st = "ship"
	elif P.dropping: st = "fall" if P.diving else "glide"
	elif P.grounded: st = "landed"
	if st != _st and st != "ship":
		lines.append("%.3f,@%s,%.3f,%.3f,%.3f" % [now, st, P.pos.x, P.pos.y, P.pos.z])
	_st = st
	if steer_home and P.dropping:
		var to := spot_xz - Vector2(P.pos.x, P.pos.z)
		P.inp["move"] = to.normalized() if to.length() > 1.0 else Vector2.ZERO

func _on_msg(topic: String, data, from: String) -> void:
	if topic == "dn" and typeof(data) == TYPE_DICTIONARY and m != null and m.player != null:
		var P := m.player
		match String(data.get("c", "")):
			"rk_time":
				var off: float = m.time - (float(data["t"]) + delay_ms / 1000.0) + SKEW
				m.ship["t0"] = float(m.ship["t0"]) + off
			"rk_spot": spot_xz = Vector2(data["x"], data["z"])
			"rk_jump": P.inp["jump"] = true
			"rk_move": P.inp["move"] = Vector2(data["x"], data["y"])
			"rk_glide":
				P.inp["glide_press_only"] = true       # real keys: only a fresh press opens it
				P.inp["glide_btn"] = true
				P.inp["glide"] = true
				steer_home = true
	super._on_msg(topic, data, from)

# ------------------------------------------------------------------ the host
func _scenario(G: Hunter) -> void:
	var P := m.player
	# the two games' ships are where the other game's ship is (a real match starts them together); the match
	# clocks are not touched: a clock jump would throw the other game's NetSmooth offset
	Net.lobby_emit("dn", {"c": "rk_time", "t": m.time})
	var t0 := m.time
	while m.time - t0 < RIDE_S:
		await _run(DT)
	ok(P.riding and G.riding, "both ride the ship (host %s, guest copy %s)" % [P.riding, G.riding])
	m.ship_jump(P)
	var rk: DropRocket = m.skydrop.rockets.get(P.team, null)
	ok(rk != null and rk.riders.has(P), "the leader launches the squad's rocket")
	if rk == null:
		return
	t0 = m.time
	var t := 0.0
	var phase := 0
	var y0 := rk.pos.y
	var spot := DropRocket.island_near(m.world, rk.pos)
	Net.lobby_emit("dn", {"c": "rk_spot", "x": spot.x, "z": spot.z})
	while t < CAP_S and not (rk.done and not G.riding and not G.dropping and t > JUMP_AFTER + 1.0):
		var to := Vector2(spot.x - rk.pos.x, spot.z - rk.pos.z)      # (steers for the nearest island, not the abyss)
		P.inp["move"] = to.normalized() if to.length() > 2.0 else Vector2.ZERO
		if phase == 0 and t >= JUMP_AFTER:
			Net.lobby_emit("dn", {"c": "rk_jump"})
			Net.lobby_emit("dn", {"c": "rk_move", "x": 0.0, "y": -1.0})
			phase = 1
		if phase == 1 and t >= JUMP_AFTER + GLIDE_AFTER:
			Net.lobby_emit("dn", {"c": "rk_glide"})
			phase = 2
		await _run(DT)
		t = m.time - t0
	ok(rk.done, "the rocket lands and the squad is down (%.1f s after the launch, from %.0f m up)" % [t, y0])
	await _run(1.5)
	var ground: float = m.world.ground_at(P.pos.x, P.pos.z)
	var down: bool = not P.riding and not P.dropping and absf(P.pos.y - ground) < 0.5
	ok(down, "the leader stands on the ground (y %.2f, ground %.2f)" % [P.pos.y, ground])
	ok(not G.riding and not G.dropping, "the guest is down on the host's copy (%s)" % G.pos)

# ------------------------------------------------------------------ the numbers
func _has_report() -> bool:
	return true

## {nid: [[t, Vector3, sim seconds since the last sample], ...]} from a log file (the parent's, with the sim seconds).
func _load(who: String) -> Dictionary:
	var out := {}
	var p := dir.path_join(who + ".csv")
	if not FileAccess.file_exists(p):
		return out
	for line in FileAccess.get_file_as_string(p).split("\n", false):
		var f := line.split(",")
		if f.size() < 5: continue
		if not out.has(f[1]): out[f[1]] = []
		var v := Vector3(float(f[2]), float(f[3]), float(f[4]))
		out[f[1]].append([float(f[0]), v, float(f[5]) if f.size() > 5 else DT])
	return out

## [t, label] marks of a log, and the time of each: {"label": t}
static func _marks(log: Dictionary) -> Dictionary:
	var out := {}
	for k in log:
		if String(k).begins_with("@"):
			out[String(k).substr(1)] = log[k][0][0]
	return out

func _report() -> void:
	var hl := _load("host")
	var gl := _load("guest")
	var hm := _marks(hl)
	var gm := _marks(gl)
	var t_launch: float = hm.get("ride", gm.get("ride", 0.0))
	var t_jump: float = gm.get("fall", INF)
	var t_glide: float = gm.get("glide", INF)
	var t_land: float = gm.get("landed", INF)
	var t_rend: float = hm.get("rocket_end", INF)
	var t_hland: float = hm.get("landed", t_rend)
	# the guest's body (seen on the host): its own ride, fall, glide, landing; the rocket's and the leader's
	# (seen on the guest): the same phases, cut where the rocket ends
	var gwins := {"ride": [t_launch, t_jump], "fall": [t_jump, t_glide], "glide": [t_glide, t_land],
		"landing": [t_land - 0.2, t_land + 1.5]}
	var rwins := {"ride": [t_launch, minf(t_jump, t_rend)], "fall": [t_jump, minf(t_glide, t_rend)],
		"glide": [t_glide, t_rend], "landing": [t_rend - 0.2, maxf(t_hland, t_rend) + 1.5]}
	var md := "| Game | Body | Phase | Frames | Largest step per 1/60 s (m) | Frames over %.1f m | " % STEP_MAX
	md += "Catch-up frames | Worst at (s after launch) |\n|---|---|---|---|---|---|---|---|\n"
	var me := "P" + Net.me
	var gu := "P" + peer_id
	var seen_any := false
	for gname in ["host", "guest"]:
		var log: Dictionary = hl if gname == "host" else gl
		var mate := gu if gname == "host" else me
		var skip := ["RK", "ME", mate]
		var others: Array = log.keys().filter(func(k): return not String(k).begins_with("@") and not k in skip)
		var rk_body: Array = ["RK"] if gname == "guest" else []
		var bodies := {"squadmate (the other player)": [mate], "rocket (follower copy)": rk_body,
			"own body (this game)": ["ME"],
			"rival bots": others}
		for what in bodies:
			var wins: Dictionary = gwins if gname == "host" else rwins
			for ph in wins:
				var w: Array = wins[ph]
				var r := {"n": 0, "max": 0.0, "over": 0, "at": 0.0, "hitch": 0, "list": []}
				for body in bodies[what]:
					var q := _steps(log.get(body, []), w[0], w[1])
					r["n"] += q["n"]
					r["over"] += q["over"]
					r["hitch"] += q["hitch"]
					r["list"].append_array(q["list"])
					if q["max"] > r["max"]:
						r["max"] = q["max"]
						r["at"] = q["at"]
				if r["n"] < 2: continue
				seen_any = true
				var worst_at: float = (r["at"] - t_launch) if r["max"] > 0.0 else 0.0
				md += "| %s | %s | %s | %d | %.2f | %d | %d | %.1f |\n" % [
					gname, what, ph, r["n"], r["max"], r["over"], r["hitch"], worst_at]
				if not r["list"].is_empty() and not what.begins_with("rival"):
					print("%s steps %s game, %s, %s (launch = %.2f): %s" % [
						tag, gname, what, ph, fposmod(t_launch, 1000.0), ", ".join(r["list"].slice(0, 8))])
				var info := "%s game, %s, %s: largest step %.2f m per 1/60 s, " % [gname, what, ph, r["max"]]
				info += "%d frames over %.1f m, %d catch-up frames" % [r["over"], STEP_MAX, r["hitch"]]
				if what.begins_with("own"):
					# the guest's own body must not snap when it joins the rocket: the ship's clock differs by SKEW
					if gname == "guest" and ph == "ride":
						ok(r["max"] <= OWN_SNAP, info)
				elif what.begins_with("rival") or ph == "landing":
					print("%s info %s" % [tag, info])      # (bots are the host's; a landing is a teleport)
				elif r["over"] > 0:
					print("%s FLAG %s" % [tag, info])
				else:
					print("%s ok   %s" % [tag, info])
	ok(seen_any, "remote bodies were measured on both games")
	for pair in [["guest", gl, "ME", hl, gu], ["leader", hl, "ME", gl, me]]:
		var own: Array = pair[1].get(pair[2], [])
		var seen: Array = pair[3].get(pair[4], [])
		if not own.is_empty() and not seen.is_empty():
			var e: float = own[-1][1].distance_to(seen[-1][1])
			ok(e < END_TOL, "the %s ends where the other game shows them (%.2f m apart)" % [pair[0], e])
	var gmsg := "the guest jumped out (%.1f s), opened the glider (%.1f s) and landed (%.1f s)" % [
		t_jump - t_launch, t_glide - t_launch, t_land - t_launch]
	ok(t_jump < INF and t_glide < INF and t_land < INF, gmsg)
	print("ODROCKET table\n" + md)
	var f := FileAccess.open(dir.path_join("rocket.md"), FileAccess.WRITE)
	f.store_string(md)
	f.close()

## The steps between samples inside [a, b] on one body, each scaled to a 1/60 s frame (a frame that caught up
## several sim steps after a slow one moves everything further: that is the box, not the network): count, largest,
## frames over STEP_MAX, catch-up frames, and when the largest was.
static func _steps(log: Array, a: float, b: float) -> Dictionary:
	var r := {"n": 0, "max": 0.0, "over": 0, "at": a, "hitch": 0, "list": []}
	var prev := Vector3.INF
	for s in log:
		if s[0] < a or s[0] > b: continue
		r["n"] += 1
		if s[2] > DT * 1.5: r["hitch"] += 1
		if prev != Vector3.INF:
			var d: float = prev.distance_to(s[1]) * DT / maxf(s[2], DT)
			if d > STEP_MAX:
				r["over"] += 1
				r["list"].append("%.2f s +%.2f m" % [fposmod(s[0], 1000.0), d])
			if d > r["max"]:
				r["max"] = d
				r["at"] = s[0]
		prev = s[1]
	return r
