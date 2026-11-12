class_name Exits
extends RefCounted
## The outpost uplinks, the quest way out beside the Heart's seats (Heart; Limited Way Outs, decision
## 0051: there is no open extraction). A walled outpost with an uplink mast. Starting it brings
## monsters; it charges while your squad holds the yard (one of you is enough; two charge it half again
## as fast, three nearly twice as fast: UPLINK_CREW) and stalls while a rival stands in it (hold it
## alone long enough and it's theirs). Leave the yard empty and the charge drains away (UPLINK_DECAY_T
## from full); at nothing the uplink flickers and shuts off, and it has to be started again once it has
## cooled down (FIZZLE_CD). When it's done, a lift of light opens in the middle for a little while,
## for anyone who gets in.

const START_HOLD := 1.5       # seconds holding interact at an uplink console to start it
const UPLINK_T := 40.0        # holding the yard to charge the uplink (one hunter in it)
const UPLINK_CREW := [0.0, 1.0, 1.5, 1.8, 2.0]   # charge rate by how many of the squad hold the yard
const UPLINK_DECAY_T := 18.0  # an empty yard drains a full charge in this long
const UPLINK_GRACE := 3.0     # a just-started uplink isn't shut off for an empty yard this soon
const FIZZLE_T := 1.8         # the uplink flickering before it shuts off
const FIZZLE_CD := 8.0        # then it can be started again after this
const TUT_UPLINK_T := 14.0
const OUTPOST_R := 3.6        # the yard
const LIFT_R := 1.7
const LIFT_T := 15.0
const UPLINK_CD := 30.0
const STEAL_T := 5.0          # holding someone else's uplink alone this long makes it yours
const WAVE_CAP := 7           # monsters a single exit's waves can have alive at once

var m: Match
var list: Array = []          # every exit, see _add_*
var rush := false             # the last squad standing: uplinks charge faster
var seats: QuestSeats = null  # Limited Ways Out: the Sealed Lair and the Uplink seats (null outside the mode)

func setup(match_node: Match) -> void:
	m = match_node
	if m.opts.get("training", false) or m.opts.get("duel", false):
		return
	var tut: bool = m.opts.get("tutorial", false)
	if Heart.enabled(m.opts): seats = QuestSeats.new(m)      # (the Heart itself is built after the exits)
	var defs: Array = m.world.exit_defs if not m.world.exit_defs.is_empty() else _default_defs()
	for d in defs:
		await m._slice()       # under the loading screen: a frame now and then
		if String(d["kind"]) == "outpost":
			_add_outpost(d, tut)
	for i in list.size():
		list[i]["i"] = i

## A map that doesn't place its exits (a generated one, an older layout): its first exit spot becomes an
## outpost (every spot, in the tutorial).
func _default_defs() -> Array:
	var spots_n := m.world.portal_spots.size() if m.opts.get("tutorial", false) else mini(1, m.world.portal_spots.size())
	return m.world.portal_spots.slice(0, spots_n).map(func(p): return {"kind": "outpost", "pos": p, "walled": false})

func _island_name(p: Vector3) -> String:
	var ii := m.world.island_of(p.x, p.z)
	if ii < 0 or ii >= m.world.islands.size():
		return ""
	return String(m.world.islands[ii].get("name", ""))

func _place(n: Node3D, at: Vector3) -> void:
	n.position = at
	m.add_child(n)

func _add_outpost(d: Dictionary, tut: bool) -> void:
	var p: Vector3 = d["pos"]
	var at := m.world.free_spot_near(p, [], 1.0, 0.9, 3.0)
	var n := ExitModels.uplink()
	_place(n, at)
	if not d.get("walled", false):
		var pal := ExitModels.palisade(OUTPOST_R + 0.4)
		_place(pal, at)
	var nm := _island_name(at)
	list.append({"kind": "outpost", "pos": at, "node": n, "name": (nm + " Outpost") if nm != "" else "Outpost", "state": "idle", "t": 0.0, "prog": 0.0,
		"open_at": 0.0 if tut else m.at_sess(0.22), "team": -1, "hold": {}, "waves": 0, "wave_t": 0.0, "contested": false, "steal": 0.0, "tut": tut})

# ------------------------------------------------------------------ queries
func of_kind(k: String) -> Array:
	return list.filter(func(x): return x["kind"] == k)

## Where every exit is (for spacing other things out).
func spots() -> Array:
	return list.map(func(x): return x["pos"])

func startable(x: Dictionary) -> bool:
	return x["kind"] == "outpost" and x["state"] == "idle" and m.time >= float(x["open_at"]) \
		and (seats == null or seats.may_start(x))

## The outpost the uplink runs on: the Uplink seat's in Limited Ways Out, else the first.
func uplink_x() -> Dictionary:
	if seats: return seats.uplink_x()
	var o := of_kind("outpost")
	return o[0] if not o.is_empty() else {}

func uplink_time(x: Dictionary) -> float:
	if x.get("tut", false):
		return TUT_UPLINK_T
	return UPLINK_T * (0.4 if rush else 1.0)

## Seconds until a draining uplink runs dry and shuts off.
func drain_left(x: Dictionary) -> float:
	return float(x["prog"]) * UPLINK_DECAY_T

## How fast an uplink charges with this many of the squad in its yard (1 = the base rate).
static func crew_rate(n: int) -> float:
	return float(UPLINK_CREW[clampi(n, 0, UPLINK_CREW.size() - 1)])

## "x1.5" style text for the yard's crew, or "" for one hunter (the base rate needs no note).
static func crew_text(n: int) -> String:
	return "" if n <= 1 else "  ·  %d holding: x%s" % [n, String.num(crew_rate(n), 1)]

func in_yard(x: Dictionary, h: Hunter) -> bool:
	var c: Vector3 = x["pos"]
	return h.flat_dist(c) < OUTPOST_R and absf(h.pos.y - c.y) < 1.6

func _live(h: Hunter) -> bool:
	return not h.out and not h.extracted and not h.dropping and not h.riding

## The uplink this hunter's squad has going (charging, or its lift open), or {}.
func active_for(team: int) -> Dictionary:
	for x in list:
		if int(x.get("team", -1)) == team and String(x["state"]) in ["charging", "open"]:
			return x
	return {}

func _cap(s: float) -> String:
	s = maxf(0.0, s)
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

# ------------------------------------------------------------------ interacting
## What interact would do at an exit for this hunter, for Match._update_interact (or {}).
## Holding interact fills x.hold[nid]; letting go resets it.
## A hunter not holding interact: whatever exit hold it had going is dropped (as interact_for does).
func let_go(h: Hunter) -> void:
	for x in list:
		(x["hold"] as Dictionary).erase(h.nid)

func interact_for(h: Hunter) -> Dictionary:
	var want: bool = h.inp.get("interact", false)
	var key := Settings.key_cap("interact")
	var best := {}
	for x in list:
		if not want:
			(x["hold"] as Dictionary).erase(h.nid)
		if not best.is_empty():
			continue
		var cp: Vector3 = x["pos"]
		if h.flat_dist(cp) > 1.9 or absf(h.pos.y - cp.y) > 1.5:
			continue
		match String(x["state"]):
			"idle":
				var why := seats.uplink_wait(x) if seats else ""
				if why != "":
					best = {"label": why}
				elif m.time < float(x["open_at"]):
					best = {"label": "The uplink comes online in %s" % _cap(float(x["open_at"]) - m.time)}
				else:
					best = {"act": "start", "need": START_HOLD, "label": "Hold %s to start the uplink  ·  monsters will attack the outpost" % key}
			"charging": best = {"label": "Uplink %d%%  ·  hold the yard (more of you charge it faster)%s" % [int(x["prog"] * 100.0), "  ·  CONTESTED" if x["contested"] else crew_text(int(x.get("crew", 0)))]}
			"fizzling": best = {"label": "The uplink lost its charge and is shutting off"}
			"open": best = {"label": "The lift is open! Step into the light"}
			"spent": best = {"label": "The uplink is cooling down: %ds" % int(ceil(x["t"]))}
			"closed": best = {"label": "The Uplink has shut"}
		if not best.is_empty():
			best["kind"] = "exit"
			best["x"] = x
			best["col"] = color_of(x)
	return best

## Holding interact on an exit (Match._update_interact).
func hold(h: Hunter, it: Dictionary, dt: float) -> void:
	if not it.has("act"):
		return
	var x: Dictionary = it["x"]
	var hd: Dictionary = x["hold"]
	# a hit breaks a start
	if m.time - h.hurt_at < 0.1:
		hd[h.nid] = 0.0
		return
	hd[h.nid] = float(hd.get(h.nid, 0.0)) + dt
	if float(hd[h.nid]) < float(it["need"]):
		return
	hd.erase(h.nid)
	act(x, String(it["act"]), h)

func act(x: Dictionary, what: String, h: Hunter, from_net := false) -> void:
	if what != "start" or x["state"] != "idle" or (seats and not from_net and not seats.may_start(x)):
		return
	_start(x, h)
	if m.net_on and not from_net:
		m.net_event(["xc", int(x["i"]), what, h.nid if h else ""])

func net_in(e: Array) -> void:
	if e.size() > 1 and String(e[1]) == "seat":
		if seats: seats.net_in(e)
		return
	var i := int(e[1])
	if i < 0 or i >= list.size():
		return
	var h: Hunter = m.ents_by_id.get(String(e[3]), null) as Hunter
	if h == null:
		return
	act(list[i], String(e[2]), h, true)

# ------------------------------------------------------------------ outposts
func _start(x: Dictionary, h: Hunter) -> void:
	x["state"] = "charging"
	x["team"] = h.team
	x["prog"] = 0.0
	x["waves"] = 0
	x["wave_t"] = 1.5
	x["steal"] = 0.0
	x["started_at"] = m.time
	x["draining"] = false
	m.sfx("warn", x["pos"], 0.0, 0.9)
	m.sfx("zap", x["pos"], -2.0, 0.7)
	m.fx.ring(x["pos"], OUTPOST_R, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		var mine: bool = m.player != null and h.team == m.player.team
		m.add_feed(("%s started the uplink at %s" % [h.pname, x["name"]]) if mine else ("An uplink came on at %s" % x["name"]))
		if m.hud and m.player and not m.player.out:
			m.hud.toast("Uplink started: hold the yard until it's charged" if mine else "An uplink is charging %s at %s" % [m.direction_word(m.player.pos, x["pos"]), x["name"]], ExitModels.UPLINK)

func _tick_outpost(x: Dictionary, dt: float) -> void:
	var n: Node3D = x["node"]
	match String(x["state"]):
		"charging":
			var team := int(x["team"])
			var squad := 0
			var foes := {}
			for h in m.hunters:
				if not _live(h) or h.downed or not in_yard(x, h):
					continue
				# truce partners share the yard: they hold it with you rather than contest it
				if h.team == team or (m.truce and m.truce.allied(team, h.team)): squad += 1
				else: foes[h.team] = int(foes.get(h.team, 0)) + 1
			x["contested"] = not foes.is_empty()
			x["crew"] = squad
			# nobody in the yard at all: the charge drains away, and at nothing the uplink shuts off. (A
			# rival standing in it alone is the old contest instead: it stalls, then it's theirs.)
			x["draining"] = squad == 0 and foes.is_empty()
			if x["draining"]:
				x["prog"] = maxf(0.0, float(x["prog"]) - dt / UPLINK_DECAY_T)
				if float(x["prog"]) <= 0.0 and m.time - float(x.get("started_at", -99.0)) > UPLINK_GRACE:
					_fizzle(x)
					return
			if squad > 0 and foes.is_empty():
				x["prog"] = minf(1.0, float(x["prog"]) + dt * crew_rate(squad) / uplink_time(x))
				x["steal"] = 0.0
			elif squad == 0 and foes.size() == 1:
				# a rival squad holding the yard alone takes the uplink over (progress and all)
				x["steal"] = float(x["steal"]) + dt
				if float(x["steal"]) >= STEAL_T:
					x["steal"] = 0.0
					x["team"] = int(foes.keys()[0])
					m.sfx("zap", x["pos"], 0.0, 1.3)
					m.fx.ring(x["pos"], OUTPOST_R, Color("ff8a6a"), 0.5)
					var who := ""
					for h in m.hunters:
						if h.team == int(x["team"]) and in_yard(x, h): who = h.pname; break
					m.add_feed("%s took over the uplink at %s" % [who, x["name"]])
			else:
				x["steal"] = 0.0
			_waves(x, dt)
			if float(x["prog"]) >= 1.0:
				_open_lift(x)
		"open":
			x["t"] = float(x["t"]) - dt
			var p: Vector3 = x["pos"]
			var seat: bool = x.get("seat", false)      # the Uplink seat: its lift is the finishing squad's alone
			var rode := false
			for h in m.hunters:
				var at_lift: bool = _live(h) and not h.remote and h.flat_dist(p) < LIFT_R and absf(h.pos.y - p.y) < 1.5
				if at_lift and (not seat or h.team == int(x["team"])):
					m._extract(h, "uplink", x["name"])
					rode = true
			if seat and rode:
				# ...and it takes their downed in the yard along
				for h in m.hunters:
					if _live(h) and not h.remote and h.downed and h.team == int(x["team"]) and in_yard(x, h):
						m._extract(h, "uplink", x["name"])
			if float(x["t"]) <= 0.0:
				x["state"] = "closed" if seat else "spent"      # (one use: the Uplink seat doesn't come back)
				x["taken"] = true     # the lift opened once: WaysOutLook shows the seat used
				x["t"] = UPLINK_CD
				n.get_node("Lift").visible = false
				m.sfx("thump", p, -6.0, 0.8)
		"fizzling":
			# a few hard flickers, a sputter each, then dark
			x["t"] = float(x["t"]) - dt
			var k := FIZZLE_T - float(x["t"])
			if int(k / 0.45) != int((k - dt) / 0.45):
				m.sfx("zap", x["pos"], -3.0, 0.6 + 0.1 * int(k / 0.45))
				m.fx.ring(x["pos"], OUTPOST_R, ExitModels.UPLINK, 0.3)
			if float(x["t"]) <= 0.0:
				x["state"] = "spent"
				x["t"] = FIZZLE_CD
				x["team"] = -1
				m.sfx("thump", x["pos"], -4.0, 0.6)
		"spent":
			x["t"] = float(x["t"]) - dt
			if float(x["t"]) <= 0.0:
				x["state"] = "idle"; x["team"] = -1; x["prog"] = 0.0
	_show_outpost(x, n)

## The Uplink seat shut (its window ran out): dark for the rest of the match.
func close_outpost(x: Dictionary) -> void:
	var was := String(x["state"])
	x["state"] = "closed"
	x["team"] = -1
	x["prog"] = 0.0
	x["contested"] = false
	x["draining"] = false
	var n: Node3D = x["node"]
	((n.get_node("Charge") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("arc", 0.0)
	if was == "charging": m.sfx("thump", x["pos"], -4.0, 0.6)

## The yard stood empty until the charge ran out: the uplink flickers and shuts off.
func _fizzle(x: Dictionary) -> void:
	var was := int(x["team"])
	x["state"] = "fizzling"
	x["t"] = FIZZLE_T
	x["prog"] = 0.0
	x["contested"] = false
	x["draining"] = false
	var n: Node3D = x["node"]
	((n.get_node("Charge") as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("arc", 0.0)
	m.sfx("warn", x["pos"], -2.0, 0.6)
	if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
		m.add_feed("The uplink at %s lost its charge and shut off" % x["name"])
		if m.hud and was == m.player.team:
			m.hud.toast("The uplink shut off: nobody held the yard. Start it again to charge it", ExitModels.UPLINK)

## The outpost's look for its state (OutpostLook): lit with the charge, the banner in the holder's colour,
## the yard's edge only while you stand in it or it is contested.
func _show_outpost(x: Dictionary, n: Node3D) -> void:
	var lit := OutpostLook.lit_of(x)
	if x["state"] == "fizzling":
		lit = 1.0 if fmod(FIZZLE_T - float(x["t"]), 0.45) < 0.2 else 0.0
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
	var near: bool = m.player != null and in_yard(x, m.player)
	var charging: bool = x["state"] == "charging"
	OutpostLook.rings(n, near or x["contested"], charging, float(x["prog"]))

func _open_lift(x: Dictionary) -> void:
	x["state"] = "open"
	x["t"] = 1e9 if x.get("tut", false) else LIFT_T
	x["contested"] = false
	var n: Node3D = x["node"]
	n.get_node("Lift").visible = true
	m.sfx("unlock", x["pos"], 0.0, 0.9)
	m.sfx("portal", x["pos"], 0.0, 0.8)
	m.fx.burst(x["pos"] + Vector3(0, 1.0, 0), ExitModels.UPLINK, 34, 6.0, 0.8, -3.0)
	m.fx.ring(x["pos"], LIFT_R + 0.4, ExitModels.UPLINK, 0.6)
	if not x.get("tut", false):
		m.ping(x["pos"], ExitModels.UPLINK)
		if m.player and not m.player.out and m.player.flat_dist(x["pos"]) < 70.0:
			m.add_feed("The lift is open at %s for %ds" % [x["name"], int(LIFT_T)])
	if m.hud and m.player and int(x["team"]) == m.player.team and not m.player.out:
		m.hud.toast("Uplink complete! The lift is open: step into the light", ExitModels.UPLINK)

# ------------------------------------------------------------------ monster waves
## While an uplink is charging, the local monsters keep coming at it.
func _waves(x: Dictionary, dt: float) -> void:
	if x.get("tut", false) and int(x["waves"]) >= 1:
		return
	x["wave_t"] = float(x["wave_t"]) - dt
	if float(x["wave_t"]) > 0.0:
		return
	x["wave_t"] = 12.0
	if m.net_on and not m.is_host:
		return
	var focus: Vector3 = x["pos"]
	var alive := 0
	for mb in m.mobs:
		if not mb.dead and int(mb.get_meta("exit", -1)) == int(x["i"]): alive += 1
	var n := 2 if x.get("tut", false) else 2 + m.tier + (1 if int(x["waves"]) >= 2 else 0)
	n = mini(n, WAVE_CAP - alive)
	x["waves"] = int(x["waves"]) + 1
	if n <= 0:
		return
	var ii := m.world.island_of(focus.x, focus.z)
	var spawned := 0
	for k in n:
		var at := _wave_spot(focus, ii)
		if at == Vector3.INF:
			continue
		var kinds: Array = ["skitter"] if x.get("tut", false) else []
		if kinds.is_empty() and m.biomes:
			kinds = m.biomes.camp_comp({"pos": at, "kind": "normal" if int(x["waves"]) >= 3 else "light"})
		if kinds.is_empty():
			kinds = ["skitter", "spitter", "bomber", "skitter"] + (["brute"] if int(x["waves"]) >= 3 else [])
		var mb: Mob = m.spawn_mob(String(kinds[m.rng.randi() % kinds.size()]), at)
		if m.biomes: m.biomes.dress(mb)
		mb.set_meta("exit", int(x["i"]))
		mb.camp = focus          # they press in on the outpost
		mb.st = "chase"
		var best: Hunter = null; var bd := 16.0
		for h in m.hunters:
			if h.targetable() and mb.flat_dist(h) < bd: bd = mb.flat_dist(h); best = h
		mb.tgt = best
		if best == null: mb.st = "idle"
		m.fx.burst(at + Vector3(0, 0.4, 0), Color("ff9a6a"), 12, 3.0, 0.5)
		m.fx.dust(at, 6)
		spawned += 1
	if spawned > 0:
		m.sfx("thump", focus, -4.0, 0.8)
		if m.player and not m.player.out and m.player.flat_dist(focus) < 24.0 and m.hud:
			m.hud.toast_small("Monsters incoming!", Color("ff9a6a"))

func _wave_spot(focus: Vector3, ii: int) -> Vector3:
	var W := m.world
	for k in 40:
		var a := m.rng.randf() * TAU
		var d := m.rng.randf_range(7.0, 13.0) if k < 30 else m.rng.randf_range(4.0, 8.0)
		var x := focus.x + cos(a) * d; var z := focus.z + sin(a) * d
		if W.is_void(x, z) or W.is_block(x, z) or (ii >= 0 and W.island_of(x, z) != ii):
			continue
		if W.edge_dist(int(x), int(z), 2) < 2:
			continue
		var near := false
		for h in m.hunters:
			if _live(h) and Vector2(h.pos.x - x, h.pos.z - z).length() < 4.0: near = true; break
		if near:
			continue
		return Vector3(x, W.ground_at(x, z), z)
	return Vector3.INF

# ------------------------------------------------------------------ the match clock
func tick(dt: float) -> void:
	if seats: seats.tick(dt)
	for x in list:
		_tick_outpost(x, dt)
		var who := occupant(x) if ExitSignal.phase(x, -1) == ExitSignal.ACTIVE else -1
		ExitSignal.show(x, ExitSignal.phase(x, who), who, m.time)

## The team of someone standing in a live outpost's yard, or -1.
func occupant(x: Dictionary) -> int:
	for h in m.hunters:
		if _live(h) and in_yard(x, h): return h.team
	return -1

## Only one squad is left: uplinks charge faster.
func on_last_team() -> void:
	if rush or m.opts.get("tutorial", false) or list.is_empty():
		return
	rush = true
	if m.player and not m.player.out and not m.player.extracted:
		m.music_dir.last_squad()
		if m.hud:
			m.hud.toast_small("Last squad: exits speed up", Color("8fe3c8"))

## The admin menu's "exits ready now".
func admin_ready() -> void:
	for x in list:
		if x.has("open_at"): x["open_at"] = minf(float(x["open_at"]), m.time)
		if x["state"] == "charging": x["prog"] = maxf(float(x["prog"]), 0.95)

# ------------------------------------------------------------------ for the HUD
static func color_of(_x: Dictionary) -> Color:
	return ExitModels.UPLINK

## Is this exit something you could use (or that's going) right now, for the map and markers.
func live(x: Dictionary) -> bool:
	return x["state"] in ["charging", "open"] or startable(x)

## The big status line in the middle of the screen while you're in the middle of an exit, or {}.
func status_for(p: Hunter) -> Dictionary:
	if p == null or p.out or p.extracted:
		return {}
	for x in list:
		if x["state"] == "charging" and in_yard(x, p):
			var mine: bool = int(x["team"]) == p.team
			var t := "Uplink %d%%" % int(x["prog"] * 100.0)
			if x["contested"]: t += "  ·  CONTESTED: clear the yard"
			elif not mine: t += "  ·  a rival's uplink: hold the yard to take it"
			elif int(x.get("crew", 0)) > 1: t += crew_text(int(x["crew"]))
			else: t += "  ·  bring your squad: more of you charge it faster"
			return {"text": t, "prog": float(x["prog"]), "col": Color("ff8a6a") if x["contested"] or not mine else ExitModels.UPLINK}
		if x["state"] == "charging" and int(x["team"]) == p.team and x.get("draining", false) and p.flat_dist(x["pos"]) < 80.0:
			# our uplink with nobody in its yard: the charge running out, and how long it has
			return {"text": "Uplink draining  ·  %d%%  ·  back to the yard: %s" % [int(x["prog"] * 100.0), _cap(drain_left(x))], "prog": float(x["prog"]),
				"col": ExitModels.UPLINK.lerp(Color.WHITE, 0.2 + 0.2 * sin(m.time * 7.0))}
	return {}

# ------------------------------------------------------------------ for bots
## Where a bot heading home should go, and what it's doing there: [pos, goal kind] or [].
## Kinds: "uplink" (hold interact on arrival), "yard" (hold the outpost), "lift" (step into it).
func bot_goal(h: Hunter, leaving: bool) -> Array:
	var team := h.team
	var mine := active_for(team)
	# in a truce, a partner squad's way out is ours too: escort them there and leave together
	if mine.is_empty() and m.truce:
		for pt in m.truce.partners(team):
			var px := active_for(pt)
			if not px.is_empty() and (leaving or h.flat_dist(px["pos"]) < 60.0):
				mine = px; break
	if not mine.is_empty():
		match String(mine["state"]):
			"charging": return [yard_spot(mine, h), "yard"]
			"open": return [mine["pos"], "lift"]
	var best := []; var bs := 1e9
	for x in list:
		var d := h.flat_dist(x["pos"])
		var s := 1e9
		var ours: bool = not x.get("seat", false) or h.team == int(x["team"])
		if x["state"] == "open" and d < float(x["t"]) * 5.0 and ours:
			s = d * 0.4; if s < bs: bs = s; best = [x["pos"], "lift"]
		elif startable(x) and leaving and m.length - m.time > 70.0:
			s = d * 1.1; if s < bs: bs = s; best = [x["pos"], "uplink"]
	return best

## Where a bot holds an uplink's yard: its own spot round the mast (each squadmate in the yard adds
## to the charge rate, so they spread out instead of shoving each other off one spot).
func yard_spot(x: Dictionary, h: Hunter) -> Vector3:
	var a := float(hash(h.nid) % 6) / 6.0 * TAU
	var p: Vector3 = x["pos"] + Vector3(cos(a), 0, sin(a)) * 1.7
	if m.world.is_void(p.x, p.z) or m.world.is_block(p.x, p.z):
		p = x["pos"] + Vector3(0.0, 0, 1.6)
	return p

## A rival's charging uplink close by, worth crashing (bots that like a fight go and contest it).
func bot_contest(h: Hunter, reach: float) -> Array:
	for x in list:
		if int(x.get("team", -1)) == h.team or int(x.get("team", -1)) < 0:
			continue
		if x["state"] == "charging" and h.flat_dist(x["pos"]) < reach:
			return [x["pos"], "yard"]
	return []

# ------------------------------------------------------------------ screenshots
## Test hook (--exit-demo=<mode>): sets up an uplink in action next to the player for a screenshot.
## Modes: uplink (charging, contested by a rival in the yard), lift (the uplink completes and the lift
## opens), drain (your uplink charging with nobody in its yard).
func demo(mode: String) -> void:
	var p := m.player
	if p == null or list.is_empty():
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
			var o: Dictionary = uplink_x()
			m.time = float(o["open_at"]) + 1.0
			act(o, "start", p)
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
			var o: Dictionary = uplink_x()
			m.time = float(o["open_at"]) + 1.0
			act(o, "start", p)
			o["wave_t"] = 99.0
			o["prog"] = 0.6
			m.set_meta("xdemo_hold", [o, "charging", "prog", 0.6])
			var off := Vector3(OUTPOST_R + 1.6, 0, 1.0)
			p.teleport(m.world.free_spot_near(o["pos"] + off, [], 0.6, 0.5, 3.0))
			if R: R.teleport(m.world.random_ground())
			m.cam.zoom_to = 0.85
	p.set_meta("pin", p.pos)
	if R: R.set_meta("pin", R.pos)
	m.cam.snap(p.pos)
