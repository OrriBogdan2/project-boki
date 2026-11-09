class_name ExitsLook
extends RefCounted
## Exits, part 1: tuning numbers, the exit list, laying exits out, queries and the HUD lines.

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
