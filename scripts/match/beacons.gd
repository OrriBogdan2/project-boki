class_name Beacons
extends RefCounted
## Revive beacons (docs/decisions/0018). Several stand on every map and show on it. A Hunter standing
## on one while any teammate is dead or a wisp lights it; after beacon_s (content/rules/revive.json)
## every dead teammate comes back at the beacon, from wherever they fell (Life.bring_back: full
## health, nothing carried, resurrection sickness). Single use; two squads on it pause it.
## A lit beacon is loud: a horn every player hears, a hum that carries beacon_hear_m, a toast with
## the direction and a pulsing marker on the world, the minimap and the full map for every player
## (ReviveHud) until it goes off or its squad steps away.
## Online, the game that owns the Hunter on the beacon runs it and tells the others with the "bcn"
## event: [i, team, "lit" | "out" | "used"] or [i, -1, "lamp", x, y, z] for a beacon set down mid-match
## (Hearth Lamp, Revive Ember); each game brings back the dead Hunters it owns.

const RADIUS := 2.2              # metres: stand this close to light it
const COUNT := 6                 # beacons per map (fewer if the islands are small)
const SPACING := 30.0            # metres: at least this far apart
const ALARM_DB := 4.0            # the lit hum's level at the beacon, loud
const HORN_DB := -4.0            # the horn when one is lit (heard by everyone, no falloff)
const COL := Color("8fffc0")

## Seconds standing on a beacon until it goes off.
static func time_s() -> float:
	return float(BoxRevive.rules()["beacon_s"])

## Stands the beacons up on the biggest islands, apart from each other and the exits.
static func place(m: Match) -> void:
	if m.opts.get("training", false) or m.opts.get("tutorial", false):
		return
	var isl: Array = []
	for i in m.world.islands.size():
		isl.append(i)
	isl.sort_custom(func(a, b): return float(m.world.islands[a]["r"]) > float(m.world.islands[b]["r"]))
	var spots: Array = []
	for i in isl:
		if spots.size() >= COUNT:
			break
		for tries in 12:
			var p: Vector3 = m.world.random_ground(i)
			if p == Vector3.INF or m.world.is_void(p.x, p.z):
				continue
			if _clear(m, spots, p):
				spots.append(p)
				break
	for p in spots:
		_add(m, p)

static func _add(m: Match, p: Vector3) -> void:
	var n := Models.revive_beacon()
	n.position = p
	m.add_child(n)
	m.beacons.append({"pos": p, "used": false, "prog": 0.0, "team": -1, "node": n, "contested": false,
		"lit": false, "lit_team": -1, "lit_at": 0.0, "lit_net": false})

## A beacon set down mid-match (Hearth Lamp). Online, the others stand the same one up ("lamp").
static func lamp(m: Match, at: Vector3, net := false) -> void:
	_add(m, at)
	m.fx.ring(at, 3.0, COL, 0.6)
	m.sfx("unlock", at, -4.0, 1.2)
	if not net:
		m.net_event(["bcn", m.beacons.size() - 1, -1, "lamp", at.x, at.y, at.z])

## A beacon that goes off at once for a team (Revive Ember, a Bounty Banner kept).
static func pop(m: Match, at: Vector3, team: int) -> void:
	lamp(m, at)
	var i := m.beacons.size() - 1
	m.net_event(["bcn", i, team, "used"])
	_use(m, m.beacons[i], team)

static func _clear(m: Match, spots: Array, p: Vector3) -> bool:
	for s in spots:
		if Vector2(s.x - p.x, s.z - p.z).length() < SPACING:
			return false
	for ep in (m.exits.spots() if m.exits else []):
		if Vector2(ep.x - p.x, ep.z - p.z).length() < 6.0:
			return false
	return true

## Who a beacon would bring back for this team: every dead or downed teammate still waiting
## (in any game; each game brings back its own).
static func targets(m: Match, team: int) -> Array:
	return m.hunters.filter(func(x): return x.team == team and not x.extracted and ((x.out and not x.gone) or x.downed))

## Every step: Hunters this game owns light and channel the beacons they stand on.
static func tick(m: Match, dt: float) -> void:
	for bc in m.beacons:
		if bc["used"]:
			continue
		var teams := {}
		var mine := -1             # a team with a Hunter of ours on it and someone to bring back
		for h in m.hunters:
			if h.out or h.extracted or h.downed or h.dropping:
				continue
			if h.flat_dist(bc["pos"]) < RADIUS and absf(h.pos.y - float(bc["pos"].y)) < 1.8:
				teams[h.team] = true
				if not h.remote and not targets(m, h.team).is_empty():
					h.set_hold("beacon")
					mine = h.team
		bc["contested"] = teams.size() > 1
		if not bc["lit_net"] and bool(bc["lit"]) != (mine >= 0):
			var team: int = mine if mine >= 0 else int(bc["lit_team"])
			_light(m, bc, mine >= 0, team)
			m.net_event(["bcn", m.beacons.find(bc), team, "lit" if mine >= 0 else "out"])
		if mine < 0:
			if teams.is_empty():
				bc["prog"] = maxf(0.0, float(bc["prog"]) - dt * 0.25)
			continue
		if bc["contested"]:
			continue
		if int(bc["team"]) != mine:
			# a different team stepping on starts from scratch
			bc["team"] = mine
			bc["prog"] = 0.0
		bc["prog"] = float(bc["prog"]) + dt / time_s()
		if float(bc["prog"]) >= 1.0:
			m.net_event(["bcn", m.beacons.find(bc), mine, "used"])
			_use(m, bc, mine)

## Another game's Hunter lit, left or used a beacon (the "bcn" event).
static func net_in(m: Match, x: Array) -> void:
	if x.size() < 4:
		return
	var i := int(x[1])
	if String(x[3]) == "lamp" and x.size() >= 7:
		if i == m.beacons.size():
			lamp(m, Vector3(float(x[4]), float(x[5]), float(x[6])), true)
		return
	if i < 0 or i >= m.beacons.size() or m.beacons[i]["used"]:
		return
	var bc: Dictionary = m.beacons[i]
	match String(x[3]):
		"lit":
			bc["lit_net"] = true
			_light(m, bc, true, int(x[2]))
		"out":
			bc["lit_net"] = false
			_light(m, bc, false, int(x[2]))
		"used":
			_use(m, bc, int(x[2]))

## The beacons lit right now, for every player's HUD whatever their team.
static func lit(m: Match) -> Array:
	return m.beacons.filter(func(bc): return bc["lit"] and not bc["used"])

## Stops every beacon hum (the match is ending).
static func stop_sounds(m: Match) -> void:
	for i in m.beacons.size():
		Sfx.loop_stop("beacon%d" % i)

## Lit: the horn for everyone, the hum that carries, and the toast. Out: quiet again.
static func _light(m: Match, bc: Dictionary, on: bool, team: int) -> void:
	if bool(bc["lit"]) == on:
		return
	bc["lit"] = on
	bc["lit_team"] = team
	bc["lit_at"] = m.time
	var key := "beacon%d" % m.beacons.find(bc)
	if not on:
		Sfx.loop_stop(key)
		return
	Sfx.loop_start(key, "revive_hum", bc["pos"], ALARM_DB, float(BoxRevive.rules()["beacon_hear_m"]))
	Sfx.loop_set(key, bc["pos"], 0.7)
	m.sfx("horn", null, HORN_DB, 0.75)
	m.ping(bc["pos"], COL)
	if m.player == null or m.hud == null:
		return
	if m.player.flat_dist(bc["pos"]) < RADIUS * 2.0:
		m.hud.toast("Beacon lit: every Hunter can see it", COL)
	else:
		m.hud.toast("Revive beacon lit %s" % m.direction_word(m.player.pos, bc["pos"]), COL)

## The beacon goes off: every dead teammate this game owns comes back round it.
static func _use(m: Match, bc: Dictionary, team: int) -> void:
	_light(m, bc, false, team)
	bc["used"] = true
	var names: Array = []
	var i := 0
	for o in targets(m, team):
		if o.remote:
			continue
		var at: Vector3 = bc["pos"] + Vector3(cos(i * 2.1) * 1.2, 0, sin(i * 2.1) * 1.2)
		Life.bring_back(m, o, at, 1.0, true)
		o.gems = 0          # you come back empty-handed: your box is where you left it
		o.seeds = {}
		o.caught = []
		names.append(o.pname)
		i += 1
	var glow: Node3D = (bc["node"] as Node3D).get_node_or_null("Glow")
	if glow: glow.visible = false
	m.fx.ring(bc["pos"], 4.0, COL, 0.6)
	m.sfx("unlock", bc["pos"], 0.0, 0.8)
	if not names.is_empty():
		m.add_feed("A revive beacon brought back %s" % ", ".join(names))
	Life.trace(m, "beacon team %d brought back %s" % [team, ", ".join(names)])
