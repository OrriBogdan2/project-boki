class_name DropMerge
extends RefCounted
## Fewer, bigger drops. Gems come out of a monster, chest or prop as ONE pickup holding the total, and a
## new gem or seed drop landing within STACK_R of the same kind on the ground joins it instead of making
## another. A pile is a little bigger the more it holds. The player gets the same gems and seeds; the
## ground (the pickup loop, the nodes and the Net "drop" events) carries a fraction of the objects.
## Gem nodes are pooled: a collected pile is hidden and reused by the next drop.

const SIZE_PER_GEM := 0.06      # extra scale per gem in the pile
const MAX_SIZE := 1.7           # a pile never looks bigger than this
const GEM_UNIT := 3             # value of one ordinary gem, for the pile size
const STACK_R := 3.0            # m: a drop this close (flat) to the same kind on the ground joins it
const STACK_DY := 2.0           # m: and within this height
const POOL_MAX := 24            # hidden gem nodes kept for reuse

## `count` gems worth `each` apiece, as one pickup at `at`. vel0: the launch (null = a random pop).
static func gems(m: Match, at: Vector3, count: int, each: int, vel0 = null) -> void:
	if count > 0:
		m.drop("gem", at, count * each, "", "", vel0)

## A new drop of (kind, v, key) at `at`: true when it was added to a pickup already on the ground (the
## caller makes no new one). Online, the host swaps the old pickup for the bigger one with the existing
## "gone" and "drop" events, so clients need nothing new.
static func stack(m: Match, kind: String, at: Vector3, v: int, key: String) -> bool:
	if kind != "gem" and kind != "seed":
		return false
	for p in m.pickups:
		var pos: Vector3 = p["pos"]
		if p["kind"] != kind or p["key"] != key or absf(pos.y - at.y) > STACK_DY:
			continue
		if Vector2(pos.x - at.x, pos.z - at.z).length() > STACK_R:
			continue
		p["v"] = int(p["v"]) + v
		_size(p)
		if m.net_on and m.is_host:
			m.net_event(["gone", p["id"]])
			m.drop_n += 1
			p["id"] = "d%d" % m.drop_n
			m.net_event(["drop", p["id"], kind, p["v"], key,
				m._r(pos.x), m._r(pos.y), m._r(pos.z), 0.0, 0.0, 0.0])
		return true
	return false

static func _size(p: Dictionary) -> void:
	if p["kind"] == "gem":
		var grown := minf(1.0 + SIZE_PER_GEM * (float(p["v"]) / GEM_UNIT - 1.0), MAX_SIZE)
		(p["node"] as Node3D).scale = Vector3.ONE * grown

## A gem node for a new drop: a pooled one (still in the tree, hidden) or a fresh one.
static func gem_node(m: Match, v: int) -> Node3D:
	var pool: Array = m.get_meta("gem_pool", [])
	var n: Node3D = pool.pop_back() if not pool.is_empty() else Models.gem()
	n.visible = true
	_size({"kind": "gem", "v": v, "node": n})
	return n

## A pickup left the ground: its gem node goes back to the pool, anything else is freed.
static func release(m: Match, p: Dictionary) -> void:
	var n: Node3D = p["node"]
	var pool: Array = m.get_meta("gem_pool", [])
	if p["kind"] == "gem" and pool.size() < POOL_MAX:
		n.visible = false
		pool.append(n)
		m.set_meta("gem_pool", pool)
	else:
		n.queue_free()
