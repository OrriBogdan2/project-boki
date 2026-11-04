class_name CareUtil
extends RefCounted
## Support helpers shared by the two support heroes (Pip the Tender, Claire the Rimewright):
## squadmate lookups, healing that reaches bots, online squadmates and downed teammates, the
## revive hook, and carrying a downed teammate. Net: heals and revives use the existing "heal" and
## "rev" events; carrying adds one "carry" event (Net 0.14.0).

## Where a hunter's hand is now (the animated hand), else a point beside the chest: casts and held props
## start there.
static func hand_at(h: Hunter, right: bool) -> Vector3:
	var a := h.anim
	if a != null:
		var hand: Node3D = a.hand_r if right else a.hand_l
		if hand != null and is_instance_valid(hand):
			return hand.global_position
	var side := Vector2(cos(h.face), -sin(h.face)) * (0.22 if right else -0.22)
	return h.pos + Vector3(side.x, 0.75, side.y)

## Living teammates of `h` (never `h`), standing or downed, optionally within r of `at`.
static func mates(m: Node, h: Hunter, at := Vector3.INF, r := 1e9, include_downed := true) -> Array:
	var out: Array = []
	for o in m.hunters:
		if o == h or o.team != h.team or o.out or o.extracted or o.dropping:
			continue
		if o.downed and not include_downed:
			continue
		if at != Vector3.INF and Vector2(o.pos.x - at.x, o.pos.z - at.z).length() > r + o.r:
			continue
		out.append(o)
	return out

## Heal a teammate. A standing one heals normally (remote ones through the "heal" event); a downed
## one gets its bleed-out bar topped up `wisp_k` times as much, or revive progress if it is online.
static func heal(m: Node, t: Hunter, n: float, wisp_k := 5.0) -> void:
	if t == null or t.out or t.dead:
		return
	if t.downed:
		var cap := float(Data.MATCH["down_hp"])
		if t.remote:
			m.net_event(["rev", t.nid, clampf(n * wisp_k / cap, 0.0, 0.5) * 0.25])
		else:
			t.down_hp = minf(cap, t.down_hp + n * wisp_k)
		return
	t.heal(n)

## Stand a downed teammate back up (the existing revive; online ones are told through "rev").
static func revive(m: Node, t: Hunter, by: Ent) -> bool:
	if t == null or not t.downed or t.out:
		return false
	if t.remote:
		m.net_event(["rev", t.nid, 1.0])
	else:
		m.revive_hunter(t, by)
	return true

# ------------------------------------------------------------------ carrying
static func carried_by(t: Hunter) -> String:
	return String(t.get_meta("carried_by", ""))

static func is_carried(t: Hunter) -> bool:
	return carried_by(t) != ""

static func carried_of(m: Node, h: Hunter) -> Array:
	var out: Array = []
	for o in m.hunters:
		if o != h and o.team == h.team and o.downed and carried_by(o) == h.nid:
			out.append(o)
	return out

static func set_carry(m: Node, t: Hunter, carrier_nid: String) -> void:
	if carrier_nid == "":
		t.remove_meta("carried_by")
	else:
		t.set_meta("carried_by", carrier_nid)
		t.set_meta("stomped", false)
	if t.remote:
		m.net_event(["carry", t.nid, carrier_nid])

## Called from Life.tick_wisps for each downed, non-remote hunter. True while someone carries them:
## they ride on the carrier, don't bleed and can't be stomped or revived the slow way.
static func carried_tick(m: Node, o: Hunter) -> bool:
	var cn := carried_by(o)
	if cn == "":
		return false
	var c: Hunter = m.ents_by_id.get(cn, null) as Hunter
	if c == null or c.out or c.downed or c.extracted or c.dead:
		o.remove_meta("carried_by")
		return false
	var back := Vector2(sin(c.face), cos(c.face)) * 0.35
	o.teleport(Vector3(c.pos.x + back.x, c.pos.y, c.pos.z + back.y))
	o.vel = Vector3.ZERO
	o.set_meta("stomped", false)
	o.set_meta("revivers", [])
	return true

## The support pair's payoff moment: a big word, rings, a flash, hitstop-grade shake and its own sound.
static func payoff(m: Node, h: Hunter, at: Vector3, word: String, col: Color, snd: String) -> void:
	if word != "":
		m.fx.word(at + Vector3(0, 2.7, 0), word, col, true)
	m.fx.ring(at, 2.4, col, 0.38)
	m.fx.ring(at, 1.0, Color(1, 1, 1, 0.9), 0.2)
	m.fx.burst(at + Vector3(0, 1.1, 0), col, 36, 7.5, 0.65, 8.0, 1.3)
	m.fx.flash(at + Vector3(0, 1.0, 0), col.lightened(0.4), 1.3, 0.1)
	if snd != "": m.sfx(snd, at, 0.0, 1.0)
	if h.ak: h.ak.net_ring(at, 2.4, col)
