class_name Exits
extends RefCounted
## The ways out of an expedition. No more standing in a circle: three kinds of exit, each with its
## own risk (after ARC Raiders' elevators and raider hatches, made for floating islands):
##  - Skiff docks (public, loud). On the outer landings. Hold interact at the horn beacon to call a
##    sky-skiff: the horn and a tall flare tell the whole map, monsters come at the dock in waves,
##    and the skiff arrives after about 45 s. It holds at the pier for a short boarding window and
##    leaves with whoever is standing on its deck: your squad, a rival who fought their way on, or a
##    downed hunter who crawled aboard. Docks close one by one late in the match (one never does).
##  - Rift hatches (keyed). Sealed hatches all over the islands. Walk up with a Rift Key (rare loot,
##    carried, lost to your deathbox if you die) and press interact: the key is spent and the hatch
##    starts grinding open, a 10 s countdown anyone close by can see and hear (a risky wait). Then it's
##    open for anyone (your squad, or a rival) to drop through, three people in all, and it seals.
##  - Outpost uplinks (hold a mini base). A walled outpost with an uplink mast. Starting it brings
##    monsters; it charges while your squad holds the yard (one of you is enough; two charge it half
##    again as fast, three nearly twice as fast: UPLINK_CREW) and stalls while a rival stands in it
##    (hold it alone long enough and it's theirs). Leave the yard empty and the charge drains away
##    (UPLINK_DECAY_T from full); at nothing the uplink flickers and shuts off, and it has to be
##    started again once it has cooled down (FIZZLE_CD). When it's done, a lift of light opens in the
##    middle for a little while, for anyone who gets in.

const CALL_HOLD := 1.5        # seconds holding interact at a dock's beacon to call the skiff
const START_HOLD := 1.5       # ... at an uplink console to start it
const KEY_HOLD := 0.15        # a key turns at once
const CALL_T := 45.0          # from the call to the skiff tying up
const RUSH_CALL_T := 18.0     # once only one squad is left
const BOARD_T := 12.0         # the boarding window at the pier
const DOCK_CD := 20.0         # before a dock can call another skiff
const DECK_R := 2.2           # stand this close to the berth to be aboard
const APPROACH_T := 9.0       # the last seconds of the call: the skiff is in sight, coming in
const HATCH_R := 1.5          # reach to open a hatch
const HATCH_IN := 1.05        # step this close to an open hatch to drop in
const HATCH_UNLOCK_T := 10.0  # from the key turning to the hatch being open
const HATCH_USES := 3         # people who can drop through an opened hatch before it seals
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
var rush := false             # the last squad standing: skiffs come quicker, uplinks charge faster
var _told := {}

func setup(match_node: Match) -> void:
	m = match_node
	if m.opts.get("training", false) or m.opts.get("duel", false):
		return
	var tut: bool = m.opts.get("tutorial", false)
	var defs: Array = m.world.exit_defs if not m.world.exit_defs.is_empty() else _default_defs()
	for d in defs:
		await m._slice()       # under the loading screen: a frame now and then
		match String(d["kind"]):
			"dock": _add_dock(d)
			"hatch": _add_hatch(d)
			"outpost": _add_outpost(d, tut)
	# docks close one by one late in the match: the order goes round the map, and one stays open
	var docks := list.filter(func(x): return x["kind"] == "dock")
	if docks.size() > 1:
		var keep: int = m.rng.randi_range(0, docks.size() - 1)
		var fr := [0.62, 0.74, 0.86, 0.9, 0.93]
		if m.rolling: fr = [0.84, 0.89, 0.93, 0.95]     # a rolling session: the docks close in its last few minutes
		var k := 0
		for i in docks.size():
			if i == keep:
				continue
			docks[i]["close_at"] = m.at_sess(float(fr[mini(k, fr.size() - 1)]))
			k += 1
		docks[keep]["last"] = true
	for i in list.size():
		list[i]["i"] = i

## A map that doesn't place its exits (a generated one, an older layout): its exit spots become one
## outpost and docks, and a few hatches go on islands without an exit.
func _default_defs() -> Array:
	var W := m.world
	var out: Array = []
	var used := {}
	for i in W.portal_spots.size():
		var p: Vector3 = W.portal_spots[i]
		out.append({"kind": "outpost" if i == 0 or m.opts.get("tutorial", false) else "dock", "pos": p, "walled": false})
		used[W.island_of(p.x, p.z)] = true
	var n := 0
	for ii in range(1, W.islands.size()):
		if n >= 3 or used.has(ii):
			continue
		var g := W.random_ground(ii)
		if g != Vector3.INF and W.island_of(g.x, g.z) == ii:
			out.append({"kind": "hatch", "pos": g})
			n += 1
	return out

func _island_name(p: Vector3) -> String:
	var ii := m.world.island_of(p.x, p.z)
	if ii < 0 or ii >= m.world.islands.size():
		return ""
	return String(m.world.islands[ii].get("name", ""))

func _place(n: Node3D, at: Vector3) -> void:
	n.position = at
	m.add_child(n)

## A dock: the layout gives a spot near a landing's rim. The pier runs out to the rim (the skiff's
## bow points over the abyss), the horn beacon stands behind it to one side.
func _add_dock(d: Dictionary) -> void:
	var W := m.world
	var p: Vector3 = d["pos"]
	var ii := W.island_of(p.x, p.z)
	var out: Vector2 = d.get("out", Vector2.ZERO)
	if out == Vector2.ZERO and ii >= 0:
		var c: Vector2 = W.islands[ii]["c"]
		out = Vector2(p.x - c.x, p.z - c.y)
	out = out.normalized() if out.length() > 0.01 else Vector2(0, -1)
	# walk out to the rim, then back in so the hull sits on the landing with its bow at the edge
	var rim := Vector2(p.x, p.z)
	for k in 80:
		var q := Vector2(p.x, p.z) + out * (k * 0.25)
		if W.is_void(q.x, q.y):
			break
		rim = q
	var b2 := rim - out * 2.7
	if W.is_void(b2.x, b2.y) or W.is_block(b2.x, b2.y):
		b2 = Vector2(p.x, p.z)
	var berth := Vector3(b2.x, W.ground_at(b2.x, b2.y), b2.y)
	var side := Vector2(-out.y, out.x)
	var bq := b2 - out * 3.6 + side * 2.1
	var beacon := W.free_spot_near(Vector3(bq.x, berth.y, bq.y), [berth], 3.0, 0.5, 4.0)
	var yaw := atan2(-out.x, -out.y)
	var off := Basis(Vector3.UP, yaw).inverse() * (beacon - berth)
	var n := ExitModels.dock(off)
	n.rotation.y = yaw
	_place(n, berth)
	var nm := _island_name(berth)
	var sk := ExitModels.skiff()
	sk.visible = false
	sk.rotation.y = yaw
	m.add_child(sk)
	list.append({"kind": "dock", "pos": beacon, "berth": berth, "out": out, "node": n, "skiff": sk, "name": (nm + " Dock") if nm != "" else "Skiff Dock",
		"state": "idle", "t": 0.0, "open_at": m.at_sess(0.18), "close_at": 1e9, "team": -1, "caller": "", "hold": {}, "waves": 0, "wave_t": 0.0, "aboard": []})

func _add_hatch(d: Dictionary) -> void:
	var p: Vector3 = d["pos"]
	var at := m.world.free_spot_near(p, [], 1.0, 1.0, 6.0)
	var n := ExitModels.hatch()
	n.rotation.y = m.rng.randf() * TAU
	_place(n, at)
	list.append({"kind": "hatch", "pos": at, "node": n, "name": "Rift Hatch", "state": "sealed", "t": 0.0, "hold": {}, "uses": 0, "team": -1})

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

## A dock can be called right now.
func callable(x: Dictionary) -> bool:
	return x["kind"] == "dock" and x["state"] == "idle" and m.time >= float(x["open_at"]) and m.time < float(x["close_at"])

func startable(x: Dictionary) -> bool:
	return x["kind"] == "outpost" and x["state"] == "idle" and m.time >= float(x["open_at"])

## How long a skiff takes to come once called (shorter for the last squad, and never past the fall).
func call_time() -> float:
	var t := RUSH_CALL_T if rush else CALL_T
	return clampf(m.length - m.time - 20.0, 8.0, t)

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

func on_deck(x: Dictionary, h: Hunter) -> bool:
	var b: Vector3 = x["berth"]
	return h.flat_dist(b) < DECK_R and absf(h.pos.y - b.y) < 1.3

func in_yard(x: Dictionary, h: Hunter) -> bool:
	var c: Vector3 = x["pos"]
	return h.flat_dist(c) < OUTPOST_R and absf(h.pos.y - c.y) < 1.6

func _live(h: Hunter) -> bool:
	return not h.out and not h.extracted and not h.dropping and not h.riding

## The exit this hunter's squad has going (called skiff, charging uplink, open lift), or {}.
func active_for(team: int) -> Dictionary:
	for x in list:
		if int(x.get("team", -1)) == team and String(x["state"]) in ["called", "boarding", "charging", "open", "unlocking"]:
			return x
	return {}

func _cap(s: float) -> String:
	s = maxf(0.0, s)
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

# ------------------------------------------------------------------ interacting
## What interact would do at an exit for this hunter, for Match._update_interact (or {}).
## Holding interact fills x.hold[nid]; letting go resets it.
func interact_for(h: Hunter) -> Dictionary:
	var want: bool = h.inp.get("interact", false)
	var key := Settings.key_cap("interact")
	var best := {}
	for x in list:
		if not want:
			(x["hold"] as Dictionary).erase(h.nid)
		if not best.is_empty():
			continue
		match String(x["kind"]):
			"dock":
				var bp: Vector3 = x["pos"]
				if h.flat_dist(bp) > 1.8 or absf(h.pos.y - bp.y) > 1.5:
					continue
				match String(x["state"]):
					"idle":
						if m.time < float(x["open_at"]):
							best = {"label": "The skiff dock opens in %s" % _cap(float(x["open_at"]) - m.time)}
						elif m.time >= float(x["close_at"]):
							best = {"label": "This dock has closed"}
						else:
							best = {"act": "call", "need": CALL_HOLD, "label": "Hold %s to sound the horn and call a skiff  ·  loud: monsters and rivals will come" % key}
					"called": best = {"label": "Skiff on its way  ·  hold the dock, then board at the pier"}
					"boarding": best = {"label": "The skiff is in! Get on its deck  ·  leaves in %ds" % int(ceil(x["t"]))}
					"gone": best = {"label": "The skiff just left. The dock is ready again in %ds" % int(ceil(x["t"]))}
					"closed": best = {"label": "This dock has closed"}
			"hatch":
				var hp: Vector3 = x["pos"]
				if h.flat_dist(hp) > HATCH_R or absf(h.pos.y - hp.y) > 1.2:
					continue
				match String(x["state"]):
					"sealed":
						if h.rift_keys > 0:
							best = {"act": "open", "need": KEY_HOLD, "label": "%s: Unlock with Rift Key  ·  opens in %ds, 3 can drop through (you have %d key%s)" % [key, int(HATCH_UNLOCK_T), h.rift_keys, "" if h.rift_keys == 1 else "s"]}
						else:
							best = {"label": "Needs a Rift Key  ·  vaults, bosses, elite monsters"}
					"unlocking":
						best = {"label": "The hatch is opening  ·  %ds  ·  hold out" % int(ceil(float(x["t"])))}
					"open":
						best = {"act": "enter", "need": KEY_HOLD, "label": "%s: Drop through  ·  %d of %d left" % [key, int(x["uses"]), HATCH_USES]}
			"outpost":
				var cp: Vector3 = x["pos"]
				if h.flat_dist(cp) > 1.9 or absf(h.pos.y - cp.y) > 1.5:
					continue
				match String(x["state"]):
					"idle":
						if m.time < float(x["open_at"]):
							best = {"label": "The uplink comes online in %s" % _cap(float(x["open_at"]) - m.time)}
						else:
							best = {"act": "start", "need": START_HOLD, "label": "Hold %s to start the uplink  ·  monsters will attack the outpost" % key}
					"charging": best = {"label": "Uplink %d%%  ·  hold the yard (more of you charge it faster)%s" % [int(x["prog"] * 100.0), "  ·  CONTESTED" if x["contested"] else crew_text(int(x.get("crew", 0)))]}
					"fizzling": best = {"label": "The uplink lost its charge and is shutting off"}
					"open": best = {"label": "The lift is open! Step into the light"}
					"spent": best = {"label": "The uplink is cooling down: %ds" % int(ceil(x["t"]))}
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
	# a hit breaks a call or a start (not the instant key)
	if it["act"] != "open" and m.time - h.hurt_at < 0.1:
		hd[h.nid] = 0.0
		return
	hd[h.nid] = float(hd.get(h.nid, 0.0)) + dt
	if float(hd[h.nid]) < float(it["need"]):
		return
	hd.erase(h.nid)
	act(x, String(it["act"]), h)

func act(x: Dictionary, what: String, h: Hunter, from_net := false) -> void:
	match what:
		"call":
			if x["state"] != "idle":
				return
			_call(x, h)
		"open":
			if x["state"] != "sealed" or h == null or h.rift_keys <= 0:
				return
			_open_hatch(x, h)
		"enter":
			if x["state"] != "open" or h == null:
				return
			_enter_hatch(x, h)
		"start":
			if x["state"] != "idle":
				return
			_start(x, h)
	if m.net_on and not from_net:
		m.net_event(["xc", int(x["i"]), what, h.nid if h else ""])

func net_in(e: Array) -> void:
	var i := int(e[1])
	if i < 0 or i >= list.size():
		return
	var h: Hunter = m.ents_by_id.get(String(e[3]), null) as Hunter
	if h == null:
		return
	act(list[i], String(e[2]), h, true)

# ------------------------------------------------------------------ the skiff
func _call(x: Dictionary, h: Hunter) -> void:
	x["state"] = "called"
	x["t"] = call_time()
	x["team"] = h.team
	x["caller"] = h.pname
	x["waves"] = 0
	x["wave_t"] = 3.0
	var n: Node3D = x["node"]
	var lamp := n.get_node("Beacon/Lamp") as MeshInstance3D
	lamp.material_override = Models.toon(ExitModels.DOCK, false, 1.6)
	n.get_node("Beacon/Flare").visible = true
	(n.get_node("Sparks") as CPUParticles3D).emitting = true
	(n.get_node("Beacon/Lever") as Node3D).rotation.x = 0.5
	# loud: everyone hears the horn and sees the flare and the ping
	Sfx.play("horn", null, -3.0, 0.03, 0.9)
	m.sfx("warn", x["pos"], 0.0, 0.7)
	m.ping(x["pos"], ExitModels.DOCK)
	m.fx.ring(x["berth"], 4.0, ExitModels.DOCK, 0.6)
	var mine: bool = m.player != null and h.team == m.player.team
	if mine:
		UiSfx.extract_start()
	m.add_feed(("%s called a skiff at %s" % [h.pname, x["name"]]) if mine else ("Someone called a skiff at %s" % x["name"]))
	if m.hud and m.player and not m.player.out:
		if mine:
			m.hud.toast("Skiff called! Hold the dock for %ds, then get on board" % int(x["t"]), ExitModels.DOCK)
		else:
			m.hud.toast("A horn sounds: a skiff was called %s at %s" % [m.direction_word(m.player.pos, x["pos"]), x["name"]], ExitModels.DOCK)

func _tick_dock(x: Dictionary, dt: float) -> void:
	var sk: Node3D = x["skiff"]
	var berth: Vector3 = x["berth"]
	var out3 := Vector3(x["out"].x, 0, x["out"].y)
	match String(x["state"]):
		"idle":
			if m.time >= float(x["close_at"]):
				_close_dock(x)
			elif float(x["close_at"]) < 1e8 and float(x["close_at"]) - m.time < 30.0 and not _told.has("cl%d" % int(x["i"])):
				_told["cl%d" % int(x["i"])] = true
				m.add_feed("%s closes in 30 seconds" % x["name"])
		"called":
			x["t"] = float(x["t"]) - dt
			_waves(x, dt)
			var t := float(x["t"])
			if t < APPROACH_T:
				# in sight: flying in from out over the abyss, settling onto the pier
				var k := 1.0 - t / APPROACH_T
				var e := 1.0 - pow(1.0 - k, 3.0)
				var far := berth + out3 * 46.0 + Vector3(0, 16.0, 0)
				sk.visible = true
				sk.position = far.lerp(berth, e) + Vector3(0, 0.6 * (1.0 - e), 0)
				_spin(sk, dt, 14.0)
				if not x.get("seen", false):
					x["seen"] = true
					m.sfx("horn", berth, -2.0, 1.15)
			if t <= 0.0:
				_arrive(x)
		"boarding":
			x["t"] = float(x["t"]) - dt
			sk.position = berth + Vector3(0, sin(m.time * 2.2) * 0.03, 0)
			_spin(sk, dt, 6.0)
			_waves(x, dt)
			var ab: Array = []
			for h in m.hunters:
				if _live(h) and on_deck(x, h):
					ab.append(h)
			x["aboard"] = ab
			var bt := float(x["t"])
			if bt < 3.0 and bt + dt >= 3.0:
				m.sfx("horn", berth, -4.0, 1.3)
			if bt <= 0.0:
				_depart(x)
		"gone":
			x["t"] = float(x["t"]) - dt
			var lt := DOCK_CD - float(x["t"])
			if lt < 6.0:
				sk.position = berth + out3 * (lt * lt * 1.6) + Vector3(0, lt * lt * 0.7 + lt * 0.4, 0)
				_spin(sk, dt, 18.0)
			else:
				sk.visible = false
			if float(x["t"]) <= 0.0:
				if m.time >= float(x["close_at"]):
					_close_dock(x)
				else:
					x["state"] = "idle"; x["team"] = -1; x["caller"] = ""
					m.ping(x["pos"], Color(ExitModels.DOCK, 0.6))
		"closed":
			pass

func _spin(sk: Node3D, dt: float, rate: float) -> void:
	var pr := sk.get_node_or_null("Hull/Prop") as Node3D
	if pr: pr.rotation.z += dt * rate

func _arrive(x: Dictionary) -> void:
	x["state"] = "boarding"
	x["t"] = BOARD_T
	x["seen"] = false
	var sk: Node3D = x["skiff"]
	sk.position = x["berth"]
	(sk.get_node("Wake") as CPUParticles3D).emitting = true
	m.sfx("horn", x["berth"], 0.0, 1.0)
	m.sfx("land", x["berth"], 0.0, 0.6)
	m.fx.dust(x["berth"], 14)
	m.fx.ring(x["berth"], DECK_R, ExitModels.DOCK, 0.5)
	m.ping(x["pos"], ExitModels.DOCK)
	if m.player and not m.player.out and m.player.flat_dist(x["berth"]) < 60.0:
		m.add_feed("The skiff is in at %s: %ds to board" % [x["name"], int(BOARD_T)])
		if m.hud and int(x["team"]) == m.player.team:
			m.hud.toast("The skiff is in! Get on its deck", ExitModels.DOCK)

func _depart(x: Dictionary) -> void:
	var n := 0
	for h in m.hunters:
		if _live(h) and on_deck(x, h) and not h.remote:
			m._extract(h, "skiff", x["name"])
			n += 1
	x["state"] = "gone"
	x["t"] = DOCK_CD
	x["aboard"] = []
	var nd: Node3D = x["node"]
	(nd.get_node("Beacon/Lamp") as MeshInstance3D).material_override = Models.toon(Color("6a5a40"))
	nd.get_node("Beacon/Flare").visible = false
	(nd.get_node("Sparks") as CPUParticles3D).emitting = false
	(nd.get_node("Beacon/Lever") as Node3D).rotation.x = -0.5
	m.sfx("whoosh", x["berth"], 0.0, 0.6)
	m.fx.burst(x["berth"] + Vector3(0, 0.8, 0), ExitModels.DOCK, 26, 5.0, 0.7, -2.0)
	if n == 0 and m.player and m.player.flat_dist(x["berth"]) < 40.0:
		m.add_feed("The skiff left %s empty" % x["name"])

func _close_dock(x: Dictionary) -> void:
	x["state"] = "closed"
	var nd: Node3D = x["node"]
	for nm in ["LanternL", "LanternR"]:
		var l := nd.get_node_or_null(nm) as MeshInstance3D
		if l: l.material_override = Models.toon(Color("5a5048"))
	(nd.get_node("Berth") as Node3D).visible = false
	(nd.get_node("Beacon/Ring") as Node3D).visible = false
	m.add_feed("%s has closed" % x["name"])
	if m.hud and m.player and not m.player.out and not m.player.extracted:
		var open_n := of_kind("dock").filter(func(d): return d["state"] != "closed").size()
		m.hud.toast_small("%s closed  ·  %d dock%s left" % [x["name"], open_n, "" if open_n == 1 else "s"], Color("ffcf8a"))

# ------------------------------------------------------------------ rift hatches
## The key turns: it's spent, and the hatch grinds open over HATCH_UNLOCK_T. No map ping, but anyone
## near enough sees the countdown over it and hears it working.
func _open_hatch(x: Dictionary, h: Hunter) -> void:
	h.rift_keys = maxi(0, h.rift_keys - 1)
	x["state"] = "unlocking"
	x["t"] = HATCH_UNLOCK_T
	x["team"] = h.team
	x["by"] = h.pname
	x["tick"] = 0
	m.sfx("unlock", x["pos"], -2.0, 0.8)
	if h == m.player:
		UiSfx.extract_start()
	m.fx.ring(x["pos"] + Vector3(0, 0.1, 0), 2.2, ExitModels.HATCH, 0.6)
	m.fx.burst(x["pos"] + Vector3(0, 0.3, 0), ExitModels.HATCH, 12, 2.5, 0.5, -3.0)
	if m.player and not m.player.out and m.hud and m.player.flat_dist(x["pos"]) < 30.0:
		if h == m.player:
			m.hud.toast("HATCH OPENS IN %dS" % int(HATCH_UNLOCK_T), ExitModels.HATCH)
		elif h.team != m.player.team:
			m.hud.toast_small("Rival opening a hatch nearby", ExitModels.HATCH)

func _set_hatch_open(x: Dictionary, open: bool) -> void:
	var n: Node3D = x["node"]
	var lid := n.get_node("Lid") as Node3D
	var tw := m.create_tween()
	if open:
		tw.tween_property(lid, "position", Vector3(1.25, -0.05, 0.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(lid, "position", Vector3.ZERO, 0.3)
	n.get_node("Rift").visible = open
	(n.get_node("Sparks") as CPUParticles3D).emitting = open

## Someone drops through an open hatch: one of its uses. The last one seals it.
func _enter_hatch(x: Dictionary, h: Hunter) -> void:
	if x["state"] != "open" or int(x["uses"]) <= 0 or not _live(h):
		return
	x["uses"] = int(x["uses"]) - 1
	m.fx.burst(x["pos"] + Vector3(0, 0.3, 0), ExitModels.HATCH, 14, 3.0, 0.5, -3.0)
	if not h.remote:
		m._extract(h, "hatch", x["name"])
	if int(x["uses"]) <= 0:
		x["state"] = "sealed"
		x["team"] = -1
		_set_hatch_open(x, false)
		m.sfx("thump", x["pos"], -6.0, 1.2)

func _tick_hatch(x: Dictionary, dt: float) -> void:
	var p: Vector3 = x["pos"]
	if x["state"] == "unlocking":
		x["t"] = float(x["t"]) - dt
		# a tick a second and a ring on the ground: loud enough for anyone close
		var sec := int(ceil(float(x["t"])))
		if sec != int(x.get("tick", 0)):
			x["tick"] = sec
			m.sfx("click", p, -2.0, 0.7 + 0.03 * (HATCH_UNLOCK_T - sec))
			m.fx.ring(p + Vector3(0, 0.1, 0), 1.2 + 0.12 * (HATCH_UNLOCK_T - sec), ExitModels.HATCH, 0.5)
		if float(x["t"]) <= 0.0:
			x["state"] = "open"
			x["uses"] = HATCH_USES
			x["t"] = 0.0
			_set_hatch_open(x, true)
			m.sfx("portal", p, 0.0, 0.7)
			m.fx.burst(p + Vector3(0, 0.3, 0), ExitModels.HATCH, 24, 3.5, 0.6, -3.0)
		return
	if x["state"] != "open":
		return
	# walking into it drops you through too
	for h in m.hunters:
		if x["state"] != "open":
			break
		if _live(h) and not h.remote and h.flat_dist(p) < HATCH_IN and absf(h.pos.y - p.y) < 1.2:
			_enter_hatch(x, h)

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
		if mine:
			UiSfx.extract_start()
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
			for h in m.hunters:
				if _live(h) and not h.remote and h.flat_dist(p) < LIFT_R and absf(h.pos.y - p.y) < 1.5:
					m._extract(h, "uplink", x["name"])
			if float(x["t"]) <= 0.0:
				x["state"] = "spent"
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
			UiSfx.extract_fail()
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
	var col: Color = Data.TEAM_COLORS[int(x["team"]) % Data.TEAM_COLORS.size()] if raised else OutpostLook.NEUTRAL
	var key := [snappedf(lit, 0.01), raised, col]
	if key != x.get("look"):
		x["look"] = key
		OutpostLook.apply(n, lit, col, 1.0 if raised else 0.0)
	if raised:
		OutpostLook.sway(n, m.time)
	var near: bool = m.player != null and in_yard(x, m.player)
	var charging: bool = x["state"] == "charging"
	OutpostLook.rings(n, near or x["contested"], x["contested"], charging, float(x["prog"]))

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
## While a skiff is coming or an uplink is charging, the local monsters keep coming at it.
func _waves(x: Dictionary, dt: float) -> void:
	if x.get("tut", false) and int(x["waves"]) >= 1:
		return
	x["wave_t"] = float(x["wave_t"]) - dt
	if float(x["wave_t"]) > 0.0:
		return
	x["wave_t"] = 11.0 if x["kind"] == "dock" else 12.0
	if m.net_on and not m.is_host:
		return
	var focus: Vector3 = x.get("berth", x["pos"])
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
		mb.camp = focus          # they press in on the dock / outpost
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
	for x in list:
		match String(x["kind"]):
			"dock": _tick_dock(x, dt)
			"hatch": _tick_hatch(x, dt)
			"outpost": _tick_outpost(x, dt)

## Only one squad is left: their way out comes faster.
func on_last_team() -> void:
	if rush or m.opts.get("tutorial", false) or list.is_empty():
		return
	rush = true
	for x in list:
		if x["kind"] == "dock" and x["state"] == "called" and float(x["t"]) > RUSH_CALL_T:
			x["t"] = RUSH_CALL_T
	if m.player and not m.player.out and not m.player.extracted and m.hud:
		m.hud.toast_small("Last squad: exits speed up", Color("8fe3c8"))

## The admin menu's "exits ready now".
func admin_ready() -> void:
	for x in list:
		if x.has("open_at"): x["open_at"] = minf(float(x["open_at"]), m.time)
		if x["kind"] == "dock" and x["state"] == "called": x["t"] = minf(float(x["t"]), 2.0)
		if x["kind"] == "outpost" and x["state"] == "charging": x["prog"] = maxf(float(x["prog"]), 0.95)

# ------------------------------------------------------------------ for the HUD
static func color_of(x: Dictionary) -> Color:
	match String(x["kind"]):
		"dock": return ExitModels.DOCK
		"hatch": return ExitModels.HATCH
	return ExitModels.UPLINK

## Is this exit something you could use (or that's going) right now, for the map and markers.
func live(x: Dictionary) -> bool:
	match String(x["kind"]):
		"dock": return x["state"] in ["called", "boarding"] or callable(x)
		"hatch": return true
		"outpost": return x["state"] in ["charging", "open"] or startable(x)
	return false

## The line under the minimap: what the exits are doing, from your point of view.
func clock_line() -> Array:
	var p := m.player
	if p == null or list.is_empty():
		return ["", Color.WHITE]
	var mine := active_for(p.team)
	if not mine.is_empty():
		match String(mine["state"]):
			"called": return ["SKIFF CALLED %s" % _cap(mine["t"]), ExitModels.DOCK]
			"boarding": return ["SKIFF BOARDING %s" % _cap(mine["t"]), ExitModels.DOCK]
			"charging":
				if mine.get("draining", false):
					# (short: it sits between the clock and your level under the minimap)
					return ["DRAINING %s" % _cap(drain_left(mine)), ExitModels.UPLINK.lerp(Color.WHITE, 0.25 + 0.25 * sin(m.time * 7.0))]
				if mine["contested"]:
					return ["CONTESTED %d%%" % int(mine["prog"] * 100.0), Color("ff8a6a")]
				return [("UPLINK %d%%%s" % [int(mine["prog"] * 100.0), (" x%s" % String.num(crew_rate(int(mine.get("crew", 0))), 1)) if int(mine.get("crew", 0)) > 1 else ""]), ExitModels.UPLINK]
			"open": return ["LIFT OPEN %s" % _cap(mine["t"]), ExitModels.UPLINK]
	var docks := of_kind("dock")
	var first := 1e9
	for d in docks: first = minf(first, float(d["open_at"]))
	if not docks.is_empty() and m.time < first:
		return ["DOCKS IN %s" % _cap(first - m.time), Color(0.75, 0.75, 0.8)]
	var open_docks := docks.filter(func(d): return d["state"] != "closed")
	var next_close := 1e9
	for d in open_docks:
		if float(d["close_at"]) < 1e8: next_close = minf(next_close, float(d["close_at"]))
	if next_close - m.time < 45.0:
		return ["DOCK CLOSES %s" % _cap(next_close - m.time), Color("ffcf8a")]
	if not docks.is_empty():
		return ["%d DOCK%s OPEN" % [open_docks.size(), "" if open_docks.size() == 1 else "S"], ExitModels.DOCK]
	return ["EXITS OPEN", Color("8fe3c8")]

## The big status line in the middle of the screen while you're in the middle of an exit, or {}.
func status_for(p: Hunter) -> Dictionary:
	if p == null or p.out or p.extracted:
		return {}
	for x in list:
		match String(x["kind"]):
			"dock":
				if x["state"] == "boarding" and on_deck(x, p):
					return {"text": "Aboard  ·  casting off in %ds" % int(ceil(x["t"])), "prog": 1.0 - float(x["t"]) / BOARD_T, "col": ExitModels.DOCK}
				if x["state"] == "called" and int(x["team"]) == p.team and p.flat_dist(x["berth"]) < 16.0:
					return {"text": "Skiff inbound  ·  %s" % _cap(x["t"]), "prog": 1.0 - float(x["t"]) / CALL_T, "col": ExitModels.DOCK}
			"hatch":
				if x["state"] == "unlocking" and p.flat_dist(x["pos"]) < 16.0:
					var mine_h := int(x.get("team", -1)) == p.team
					return {"text": ("Rift hatch opening  ·  %ds" if mine_h else "A rival's rift hatch opening  ·  %ds") % int(ceil(float(x["t"]))), "prog": 1.0 - float(x["t"]) / HATCH_UNLOCK_T, "col": ExitModels.HATCH}
				if x["state"] == "open" and p.flat_dist(x["pos"]) < 12.0:
					return {"text": "Rift hatch open  ·  drop through  ·  %d of %d left" % [int(x["uses"]), HATCH_USES], "prog": float(x["uses"]) / HATCH_USES, "col": ExitModels.HATCH}
			"outpost":
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
## Kinds: "hatch" (press interact on arrival), "dock" / "uplink" (hold interact on arrival),
## "board" (stand on the deck), "yard" (hold the outpost), "lift" (step into it).
func bot_goal(h: Hunter, leaving: bool) -> Array:
	var team := h.team
	var mine := active_for(team)
	# in a truce, a partner squad's way out is ours too: escort them there and leave together
	if mine.is_empty() and m.truce:
		for pt in m.truce.partners(team):
			var px := active_for(pt)
			if not px.is_empty() and (leaving or h.flat_dist(px.get("berth", px["pos"])) < 60.0):
				mine = px; break
	if not mine.is_empty():
		match String(mine["state"]):
			"called", "boarding": return [mine["berth"], "board"]
			"charging": return [yard_spot(mine, h), "yard"]
			"unlocking": return [mine["pos"] + Vector3(1.6, 0, 0.0), "yard"]      # wait by the hatch, guarding it
			"open": return [mine["pos"], "lift"]
	var best := []; var bs := 1e9
	for x in list:
		var d := h.flat_dist(x["pos"])
		var s := 1e9
		match String(x["kind"]):
			"dock":
				if x["state"] == "boarding" and d < float(x["t"]) * 5.0 and leaving:
					s = d * 0.5; if s < bs: bs = s; best = [x["berth"], "board"]
					continue
				if x["state"] == "called" and leaving and d < 70.0:
					s = d * 0.7; if s < bs: bs = s; best = [x["berth"], "board"]
					continue
				# don't head for a dock that'll close before we get there and call it
				if callable(x) and leaving and float(x["close_at"]) - m.time > d / 4.5 + CALL_T * 0.5:
					s = d; if s < bs: bs = s; best = [x["pos"], "dock"]
			"hatch":
				if x["state"] == "sealed" and h.rift_keys > 0 and leaving:
					s = d * 0.6; if s < bs: bs = s; best = [x["pos"], "hatch"]
				elif x["state"] == "open" and int(x["uses"]) > 0 and d < 40.0 and leaving:
					s = d * 0.3; if s < bs: bs = s; best = [x["pos"], "lift"]
			"outpost":
				if x["state"] == "open" and d < float(x["t"]) * 5.0:
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

## A rival's loud exit close by, worth crashing (bots that like a fight go and contest it).
func bot_contest(h: Hunter, reach: float) -> Array:
	for x in list:
		if int(x.get("team", -1)) == h.team or int(x.get("team", -1)) < 0:
			continue
		var at: Vector3 = x.get("berth", x["pos"])
		if x["state"] in ["called", "boarding", "charging"] and h.flat_dist(at) < reach:
			return [at, "board" if x["kind"] == "dock" else "yard"]
	return []

# ------------------------------------------------------------------ keys
## A Rift Key dropped as loot (vaults, bosses, elite monsters).
func drop_key(at: Vector3) -> void:
	m.drop("key", at + Vector3(0, 0.6, 0), 1)

# ------------------------------------------------------------------ screenshots
## Test hook (--exit-demo=<mode>): sets up one exit in action next to the player for a screenshot.
## Modes: call (horn just sounded, waves coming), approach (the skiff flying in), board (tied up,
## you and a rival on deck), hatch (a rival drops through a hatch you're next to), uplink (charging,
## contested by a rival in the yard), lift (the uplink completes and the lift opens).
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
		"call", "approach", "board":
			var d: Dictionary = of_kind("dock")[0]
			m.time = float(d["open_at"]) + 1.0
			var b: Vector3 = d["berth"]; var o3 := Vector3(d["out"].x, 0, d["out"].y)
			act(d, "call", p)
			d["wave_t"] = 0.0
			if mode == "call":
				d["t"] = 30.0
				m.set_meta("xdemo_hold", [d, "called", "t", 30.0])
				p.teleport(d["pos"] + Vector3(0.6, 0, 0.6))
			elif mode == "approach":
				d["t"] = APPROACH_T * 0.45
				m.set_meta("xdemo_hold", [d, "called", "t", APPROACH_T * 0.45])
				p.teleport(b - o3 * 4.5)
			else:
				d["t"] = 0.3
				m.set_meta("xdemo_hold", [d, "boarding", "t", 7.0])
				p.teleport(b - o3 * 0.9 + Vector3(-o3.z, 0, o3.x) * 0.5)
				if R: R.teleport(b + o3 * 1.0 + Vector3(o3.z, 0, -o3.x) * 0.6)
			m.cam.zoom_to = 0.85
		"hatch":
			var hx: Dictionary = of_kind("hatch")[0]
			p.rift_keys = 1
			p.teleport(m.world.free_spot_near(hx["pos"] + Vector3(2.2, 0, 1.2), [hx["pos"]], 1.8, 0.5, 4.0))
			if R:
				R.rift_keys = 1
				R.teleport(hx["pos"] + Vector3(-0.8, 0, -0.6))
				m.get_tree().create_timer(1.6).timeout.connect(func(): act(hx, "open", R))
				m.set_meta("xdemo_hold", [hx, "open", "t", 4.0])
			m.cam.zoom_to = 0.6
		"uplink", "lift":
			var o: Dictionary = of_kind("outpost")[0]
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
			var o: Dictionary = of_kind("outpost")[0]
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
