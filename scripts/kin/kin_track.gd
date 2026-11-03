class_name KinTrack
extends RefCounted
## The bond pull (docs/decisions/0008). While an enemy hunter carries your captured Boki in their box:
##   - you and your squad, once up (alive, not downed), see an edge arrow "<Boki> is this way" at the captor (BondHud)
##   - the captor's exact spot pings on your squad's map every bond_ping_s (content/rules/boki_system.json "loss")
##   - the captor sees a "Tracked" chip on their HUD
##   - knocked or killed, the captor drops it: it stands dazed where they fell and its owner can cradle it
##   - the pull ends when the captor extracts
## State: hunter meta "bond" = [{uid, name, owner (nid), team}], on every game. Online the "caught" event starts it
## and the "unbond" kcmd event ends it.

const META := "bond"

static func entries(h: Hunter) -> Array:
	return h.get_meta(META, [])

## Drops the entry on this game only.
static func forget(h: Hunter, uid: String) -> void:
	_remove(h, uid, false)

static func tracked(h: Hunter) -> bool:
	return not entries(h).is_empty()

## A scan just put one of someone's Boki in this hunter's box (the host or an offline game; the other games get
## the same through the "caught" event: on_caught_net).
static func on_caught(m, h: Hunter, k: Kin, rec: Dictionary) -> void:
	var o = k.lost_owner
	if o is Hunter:
		register(h, rec, o)

static func register(h: Hunter, rec: Dictionary, o: Hunter) -> void:
	if o.team == h.team:
		return
	var entry := {"uid": String(rec.get("uid", "")), "name": String(rec.get("name", "Boki")), "owner": o.nid}
	entry["team"] = o.team
	_add(h, entry)
	h.set_meta("bond_t", 0.0)             # (the first ping goes out at once)

## The "caught" event, in every game but the one that ran the scan: the captor's game and the owner's game learn of it.
static func on_caught_net(m, captor: Hunter, rec: Dictionary, o: Hunter) -> void:
	register(captor, rec, o)
	if o.team != captor.team:
		for L in m.player_lost:
			if String(L["uid"]) == String(rec.get("uid", "")):
				L["holder"] = captor
		if o == m.player:
			m.kin_stolen(captor, rec)

static func _add(h: Hunter, e: Dictionary) -> void:
	var es := entries(h).duplicate()
	es = es.filter(func(x): return x["uid"] != e["uid"])
	es.append(e)
	h.set_meta(META, es)

## No longer carried. The game that owns the captor tells the others (they have no way to see a released capsule).
static func _remove(h: Hunter, uid: String, send := true) -> void:
	var es := entries(h).filter(func(x): return x["uid"] != uid)
	if es.is_empty():
		h.remove_meta(META)
	else:
		h.set_meta(META, es)
	if send:
		KinNet.event(h.m, "unbond", h, h.pos, uid)

## An event from another game (KinNet.on_event).
static func on_net(h: Hunter, kind: String, extra: String) -> void:
	if kind == "unbond":
		_remove(h, extra.split("|")[0], false)

## The hunter carrying one of this team's Boki (the nearest first), or null.
static func captor_for(m, team: int) -> Hunter:
	var best: Hunter = null
	for c in m.hunters:
		if c.out or c.extracted or c.team == team:
			continue
		if entries(c).any(func(e): return int(e["team"]) == team):
			if best == null or (m.player != null and c.flat_dist(m.player) < best.flat_dist(m.player)):
				best = c
	return best

## The Boki a captor is carrying for that team (for the arrow's name).
static func name_for(c: Hunter, team: int) -> String:
	for e in entries(c):
		if int(e["team"]) == team:
			return String(e["name"])
	return "Your Boki"

## You can feel the pull: alive and on your feet.
static func pulling(p: Hunter) -> bool:
	return p != null and not p.out and not p.downed and not p.extracted

## Each step: map pings, and the pull ends when the captor extracts or no longer has the Boki.
static func tick(m, dt: float) -> void:
	for c in m.hunters:
		var es := entries(c)
		if es.is_empty():
			continue
		if c.extracted:
			c.remove_meta(META)
			continue
		for e in es.duplicate():
			if not c.remote and not c.caught.any(func(r): return String(r.get("uid", "")) == String(e["uid"])):
				_remove(c, String(e["uid"]))          # let go, or lost another way
		if c.out or c.downed or entries(c).is_empty():
			continue
		var t := float(c.get_meta("bond_t", 0.0)) - dt
		if t <= 0.0:
			t = float(KinLoss.rules()["bond_ping_s"])
			var teams := {}
			for e in entries(c):
				teams[int(e["team"])] = true
			for tm in teams:
				m.pings.append({"pos": c.pos, "col": Color("ffd23f"), "t": 0.0, "team": tm})
				if m.player != null and m.player.team == tm and pulling(m.player):
					m.sfx("ping", null, -10.0)
		c.set_meta("bond_t", t)

## The captor is knocked or killed (in the game that owns them): what they carried drops dazed at `at`, guarding for its
## owner. Every game hears it through the "gdrop" event; the owner's game puts the Boki back (KinLoss.on_gdrop).
static func drop_carried(m, h: Hunter, at: Vector3) -> void:
	if h.remote or at == Vector3.INF or m.opts.get("training", false):
		return
	for e in entries(h).duplicate():
		var uid := String(e["uid"])
		var idx := -1
		for i in h.caught.size():
			if String(h.caught[i].get("uid", "")) == uid:
				idx = i
		var owner_hunter = m.ents_by_id.get(String(e["owner"]), null)
		var spot := at + Vector3(0.9, 0, 0.5)
		var can_drop: bool = idx >= 0 and owner_hunter is Hunter and not (owner_hunter as Hunter).extracted
		if not can_drop or KinLoss.ground(m, spot) == Vector3.INF:
			_remove(h, uid)               # (it stays in their box)
			continue
		var rec: Dictionary = (h.caught[idx] as Dictionary).duplicate(true)
		if rec.has("prev_trust"):
			rec["trust"] = float(rec["prev_trust"])
		rec.erase("prev_trust")
		rec.erase("lost_from")
		if m.net_on:
			m.net_event(["gdrop", String(e["owner"]), spot.x, spot.y, spot.z, rec])
		KinLoss.on_gdrop(m, String(e["owner"]), rec, spot)
		m.add_feed("%s dropped %s" % [h.pname, e["name"]])
	h.remove_meta(META)
