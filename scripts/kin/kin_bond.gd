class_name KinBond
extends RefCounted
## The bond pull (docs/decisions/0008). While an enemy hunter carries your captured Boki in their box:
##   - you and your squad, once up (alive, not downed), see an edge-of-screen arrow "<Boki> is this way" at the captor (BondHud)
##   - the captor's exact spot pings on your squad's map every bond_ping_s (content/rules/boki_system.json "loss")
##   - the captor sees a "Tracked" chip on their HUD
##   - knocked or killed, the captor drops it: it stands dazed where they fell and its owner can cradle it
##   - the pull ends when the captor extracts
## State: hunter meta "bond" = [{uid, name, owner (nid), team}], on every game (the "bond"/"unbond" kcmd events carry it online).

const META := "bond"

static func entries(h: Hunter) -> Array:
	return h.get_meta(META, [])

static func tracked(h: Hunter) -> bool:
	return not entries(h).is_empty()

## A scan just put one of someone's Boki in this hunter's box.
static func on_caught(m, h: Hunter, k: Kin, rec: Dictionary) -> void:
	var o = k.lost_owner
	if not (o is Hunter) or (o as Hunter).team == h.team:
		return
	_add(h, {"uid": String(rec.get("uid", "")), "name": String(rec.get("name", "Boki")), "owner": (o as Hunter).nid, "team": (o as Hunter).team})
	h.set_meta("bond_t", 0.0)             # (the first ping goes out at once)
	KinNet.event(m, "bond", h, h.pos, "%s|%d|%s|%s" % [(o as Hunter).nid, (o as Hunter).team, rec.get("uid", ""), rec.get("name", "Boki")])

static func _add(h: Hunter, e: Dictionary) -> void:
	var es := entries(h).duplicate()
	es = es.filter(func(x): return x["uid"] != e["uid"])
	es.append(e)
	h.set_meta(META, es)

static func _remove(h: Hunter, uid: String) -> void:
	var es := entries(h).filter(func(x): return x["uid"] != uid)
	if es.is_empty():
		h.remove_meta(META)
	else:
		h.set_meta(META, es)

## An event from another game (KinNet.on_event).
static func on_net(h: Hunter, kind: String, extra: String) -> void:
	var p := extra.split("|")
	if kind == "bond" and p.size() >= 4:
		_add(h, {"uid": p[2], "name": p[3], "owner": p[0], "team": int(p[1])})
	elif kind == "unbond":
		_remove(h, p[0])

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
			if not c.caught.any(func(r): return String(r.get("uid", "")) == String(e["uid"])) and not c.remote:
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

## The captor is knocked or killed: what they carried drops dazed at `at`, guarding for its owner.
static func drop_carried(m, h: Hunter, at: Vector3) -> void:
	if h.remote or at == Vector3.INF or m.opts.get("training", false):
		return
	for e in entries(h).duplicate():
		var idx := -1
		for i in h.caught.size():
			if String(h.caught[i].get("uid", "")) == String(e["uid"]):
				idx = i
		var owner = m.ents_by_id.get(String(e["owner"]), null)
		if idx < 0 or not (owner is Hunter) or (owner as Hunter).extracted:
			continue
		var rec: Dictionary = (h.caught[idx] as Dictionary).duplicate(true)
		if rec.has("prev_trust"):
			rec["trust"] = float(rec["prev_trust"])
		rec.erase("prev_trust")
		rec.erase("lost_from")
		var g := KinLoss.spawn_guard(m, owner, rec, at + Vector3(0.9, 0, 0.5))
		if g == null:
			continue
		h.caught.remove_at(idx)
		for L in m.player_lost:
			if String(L["uid"]) == String(e["uid"]):
				L["kin"] = g
				L["holder"] = null
		KinNet.event(m, "unbond", h, h.pos, String(e["uid"]))
		m.add_feed("%s dropped %s" % [h.pname, e["name"]])
	h.remove_meta(META)
