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
const TUT_UPLINK_T := 8.0      # s: the tutorial outpost's capture (long enough for its one wave to arrive)
const OUTPOST_R := 3.6        # the yard
const LIFT_R := 1.7
const LIFT_T := 15.0
const UPLINK_CD := 30.0
const STEAL_T := 5.0          # holding someone else's uplink alone this long makes it yours
const WAVE_CAP := 7           # monsters a single exit's waves can have alive at once
const WAVE_EVERY := 12.0      # seconds between an uplink's monster waves
const WAVE_WARN := 2.5        # seconds the wave posts glow on the ground before monsters climb out of them
const WAVE_POSTS := 6         # fixed posts round each outpost that its waves come from (docs/SPAWNS.md)
const WAVE_R := [10.0, 8.0, 12.0, 6.0]   # metres from the outpost a post may sit, tried in this order

var m: Match
var list: Array = []          # every exit, see _add_*
var rush := false             # the last squad standing: uplinks charge faster
var seats: QuestSeats = null  # Limited Ways Out: the Sealed Lair and the Uplink seats (null outside the mode)
var flow: ExitsFlow
var look: ExitsLook
var hints := ZoneHint.new()   # the fading "more teammates fuel it faster" tip

func setup(match_node: Match) -> void:
	m = match_node
	flow = ExitsFlow.new(self)
	look = ExitsLook.new(self)
	if m.opts.get("training", false) or m.opts.get("duel", false) or HeartRaid.on(m.opts):
		return      # (a raid's only way out is the Heart ring once its boss is down)
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
			"charging": best = {"label": "Uplink %d%%  ·  hold the outpost%s" % [int(x["prog"] * 100.0), "  ·  CONTESTED" if x["contested"] else crew_text(int(x.get("crew", 0)))]}
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

func _start(x: Dictionary, h: Hunter) -> void:
	flow._start(x, h)

func _tick_outpost(x: Dictionary, dt: float) -> void:
	flow._tick_outpost(x, dt)

func _open_lift(x: Dictionary) -> void:
	flow._open_lift(x)

func close_outpost(x: Dictionary) -> void:
	flow.close_outpost(x)

func _show_outpost(x: Dictionary, n: Node3D) -> void:
	look._show_outpost(x, n)

func wave_posts(x: Dictionary) -> Array:
	return flow.wave_posts(x)

# ------------------------------------------------------------------ the match clock
func tick(dt: float) -> void:
	if seats: seats.tick(dt)
	var viewer := SideColor.viewer(m)
	for x in list:
		_tick_outpost(x, dt)
		var who := occupant(x) if ExitSignal.phase(x, -1) == ExitSignal.ACTIVE else -1
		ExitSignal.show(x, ExitSignal.phase(x, who), who, m.time, viewer)

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
		if seats: seats.open_now(x)      # (the Uplink seat's own window too, or the prompt offers a start it refuses)
		if x["state"] == "charging": x["prog"] = maxf(float(x["prog"]), 0.95)

# ------------------------------------------------------------------ for the HUD
static func color_of(_x: Dictionary) -> Color:
	return ExitModels.UPLINK

## Is this exit something you could use (or that's going) right now, for the map and markers.
func live(x: Dictionary) -> bool:
	return x["state"] in ["charging", "open"] or startable(x)

func status_for(p: Hunter) -> Dictionary:
	return look.status_for(p)

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

func demo(mode: String) -> void:
	look.demo(mode)
