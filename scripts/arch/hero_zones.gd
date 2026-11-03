class_name HeroZones
extends RefCounted
## Placement of what Dolm and Ostra leave in the world (rocks, rock bridges, the seed): one legality
## rule for all of it, and the Net side. A rock or seed only goes on solid ground that a body could
## stand on: not in the abyss, not inside rocks, trees, cliffs or other walls, not through a wall from
## where the caster stands. Rock bridges only replace abyss tiles (Verbs.add_bridge).
##
## Net (Net.VERSION 0.14.0): ["zone", kind, ...] events through the existing "ev" topic. The caster's
## game sends them; every other game builds the same thing, so a rock stops a remote body the same way.
##   ["zone", "rock",   nid, rid, x, y, z, dx, dz, len, time, hp]
##   ["zone", "rockgo", rid]                     a rock was launched or crumbled: remove it
##   ["zone", "bridge", nid, x, y, z, dx, dz, len, width, time, color?]   (color: hex, rock-tan when absent)
##   ["zone", "seed",   nid, sid, x, y, z, rmax, grow]
##   ["zone", "pop",    sid]
##   ["zone", "tp",     nid, x, y, z]            a body another game owns was moved (Trade, the rank-3 Brimseed pull): its own game moves it

const ROCK_COL := Color("c98d4a")
const ROCK_R := 0.5                  # a rock's footprint when it asks the world if it fits
const STEP := 0.25                   # the walk along a cast, metres

## Tests read what would go out over the network without a connection (--zone-check).
static var capture := false
static var sent: Array = []

static func tx(m: Node, e: Array) -> void:
	if capture:
		sent.append(e)
	if m.net_on:
		m.net_event(e)

## Can a rock or seed sit at p? Solid ground within a step of `y`, nothing in the way, no body inside.
static func fits(m: Node, p: Vector3, y: float, bodies := true) -> bool:
	var w: World = m.world
	var g: float = w.ground_at(p.x, p.z)
	if g <= World.VOID + 1.0 or absf(g - y) > 0.9:
		return false
	if w.occupy(p.x, p.z, ROCK_R, g, false) != 0.0:
		return false
	if bodies:
		for e in m.hunters:
			if is_instance_valid(e) and not e.dead and Vector2(e.pos.x - p.x, e.pos.z - p.z).length() < ROCK_R + e.r + 0.15 and absf(e.pos.y - g) < 2.0:
				return false
		for mb in m.mobs:
			if is_instance_valid(mb) and not mb.dead and Vector2(mb.pos.x - p.x, mb.pos.z - p.z).length() < ROCK_R + mb.r + 0.15 and absf(mb.pos.y - g) < 2.0:
				return false
	return true

## Walk from `from` toward `aim` up to `reach` and return the last legal spot:
## {ok, pos, stopped: "" | "reach" | "wall" | "abyss", over_abyss: the aim itself is over the abyss}.
static func walk(m: Node, from: Vector3, aim: Vector3, reach: float) -> Dictionary:
	var w: World = m.world
	var dv := Vector2(aim.x - from.x, aim.z - from.z)
	var want := minf(dv.length(), reach)
	var dir := dv.normalized() if dv.length() > 0.01 else Vector2(0, -1)
	var out := {"ok": false, "pos": from, "stopped": "reach" if dv.length() > reach else "", "over_abyss": w.is_void(aim.x, aim.z), "dir": dir}
	var k := STEP
	var last := from
	var y := from.y
	while k <= want + 0.001:
		var q := Vector3(from.x + dir.x * k, y, from.z + dir.y * k)
		var g: float = w.ground_at(q.x, q.z)
		if g <= World.VOID + 1.0:
			out["stopped"] = "abyss"
			break
		if absf(g - y) > 0.9 or w.occupy(q.x, q.z, 0.3, y, false) != 0.0:
			out["stopped"] = "wall"
			break
		q.y = g
		last = q
		k += STEP
	if last.distance_to(from) > 0.1:
		out["ok"] = true
		out["pos"] = last
	return out

# ------------------------------------------------------------------ rocks
static func rock_node() -> Node3D:
	var n := Node3D.new()
	var body := Models.toon(Color("a8794a"), true, 0.5)
	var top := Models.toon(Color("d9b27a"), true, 0.5)
	var dark := Models.toon(Color("6e4f35"), true, 0.5)
	Models.part(n, Models.box(1.15, 0.85, 0.7), body, Vector3(0, 0.42, 0), Vector3.ONE, Vector3(0, 0.05, 0.04))
	Models.part(n, Models.box(0.7, 0.9, 0.55), top, Vector3(-0.2, 0.95, 0.02), Vector3.ONE, Vector3(0.08, -0.3, 0.12))
	Models.part(n, Models.box(0.42, 0.62, 0.4), dark, Vector3(0.32, 0.78, -0.05), Vector3.ONE, Vector3(-0.1, 0.4, -0.18))
	Models.part(n, Models.box(1.05, 0.12, 0.6), dark, Vector3(0, 0.06, 0.02))
	return n

## Builds a rock (a movement-blocking Verbs wall wearing a rock's look). send: tell the other games.
static func rock(m: Node, by: Ent, at: Vector3, dir: Vector2, rid: String, len_: float, time_: float, hp: float, send := true) -> Dictionary:
	var w: Dictionary = m.verbs.add_wall(by, at, dir, {"length": len_, "hp": hp, "time": time_, "block": "enemy", "move": true, "color": "#c98d4a"}, 1.0)
	var old: Node3D = w["node"]
	var n := rock_node()
	n.scale = Vector3(len_ / 1.15, 1.0, 1.0)
	m.add_child(n)
	w["node"] = n
	w["rock"] = true
	w["rid"] = rid
	m.verbs._place_wall(w, n)
	n.scale = Vector3(len_ / 1.15, 0.05, 1.0)
	n.create_tween().tween_property(n, "scale", Vector3(len_ / 1.15, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(old):
		old.queue_free()
	m.fx.burst(at + Vector3(0, 0.3, 0), Color("d9b27a"), 10, 3.0, 0.4, 8.0, 1.0)
	if send and by != null and (m.net_on or capture) and not by.remote:
		tx(m, ["zone", "rock", by.nid, rid, m._r(at.x), m._r(at.y), m._r(at.z), snappedf(dir.x, 0.001), snappedf(dir.y, 0.001), snappedf(len_, 0.01), snappedf(time_, 0.1), snappedf(hp, 0.1)])
	return w

static func find_rock(m: Node, rid: String) -> Dictionary:
	for w in m.verbs.walls:
		if w.get("rid", "") == rid:
			return w
	return {}

## Takes a rock out of the world without the break effects (it was launched).
static func remove_rock(m: Node, w: Dictionary, send := true) -> void:
	m.verbs.walls.erase(w)
	if is_instance_valid(w.get("node")):
		(w["node"] as Node3D).queue_free()
	if send:
		tx(m, ["zone", "rockgo", String(w.get("rid", ""))])

## A temporary rock bridge over the abyss from `from` along `dir`. Returns the tiles turned to ground.
static func bridge(m: Node, by: Ent, from: Vector3, dir: Vector2, len_: float, width: float, time_: float, send := true, color := "#d9b27a") -> int:
	var n: int = m.verbs.add_bridge(by, from, dir, {"length": len_, "width": width, "time": time_, "color": color})
	if n > 0 and send and by != null and (m.net_on or capture) and not by.remote:
		tx(m, ["zone", "bridge", by.nid, m._r(from.x), m._r(from.y), m._r(from.z), snappedf(dir.x, 0.001), snappedf(dir.y, 0.001), snappedf(len_, 0.1), snappedf(width, 0.1), snappedf(time_, 0.1), color])
	return n

# ------------------------------------------------------------------ the seed (visual; the caster's game runs the rules)
static func seed_visual(m: Node, sid: String, at: Vector3, rmax: float, grow: float, col: Color) -> Node3D:
	var n := Node3D.new()
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = Models.sphere(0.5, 14)
	core.material_override = Models.glow_mat(Color(col, 0.55))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = Models.cyl(1.0, 1.0, 0.04, 28)
	ring.material_override = Models.glow_mat(Color(col.lightened(0.3), 0.35))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	m.add_child(n)
	n.global_position = at + Vector3(0, 0.9, 0)
	ring.global_position = at + Vector3(0, 0.06, 0)
	n.scale = Vector3.ONE * 0.3
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * rmax * 1.6, grow).set_trans(Tween.TRANS_SINE)
	var seeds: Dictionary = m.get_meta("zone_seeds", {})
	seeds[sid] = n
	m.set_meta("zone_seeds", seeds)
	return n

static func seed_pop(m: Node, sid: String, col: Color) -> void:
	var seeds: Dictionary = m.get_meta("zone_seeds", {})
	var n: Node3D = seeds.get(sid)
	seeds.erase(sid)
	if n != null and is_instance_valid(n):
		m.fx.ring(n.global_position - Vector3(0, 0.9, 0), n.scale.x * 0.7, col, 0.3)
		n.queue_free()

# ------------------------------------------------------------------ moving a body
## Moves `e` to `p`. A body this game owns moves now; one another game owns (e.remote) is asked to move through
## Net, and its own game applies it (a remote body's position here is only what its owner last told us).
static func move_body(m: Node, e: Ent, p: Vector3) -> void:
	if not e.remote:
		e.teleport(p)
	elif e.nid != "" and (m.net_on or capture):
		tx(m, ["zone", "tp", e.nid, m._r(p.x), m._r(p.y), m._r(p.z)])

# ------------------------------------------------------------------ Net in
static func net_in(m: Node, x: Array) -> void:
	if x.size() < 3:
		return
	match String(x[1]):
		"rock":
			if x.size() < 12: return
			var by: Ent = m.ents_by_id.get(String(x[2]), null)
			if by == null or not find_rock(m, String(x[3])).is_empty(): return
			rock(m, by, Vector3(x[4], x[5], x[6]), Vector2(x[7], x[8]), String(x[3]), float(x[9]), float(x[10]), float(x[11]), false)
		"rockgo":
			var w := find_rock(m, String(x[2]))
			if not w.is_empty():
				remove_rock(m, w, false)
		"bridge":
			if x.size() < 11: return
			var by2: Ent = m.ents_by_id.get(String(x[2]), null)
			if by2 != null:
				var tint := String(x[11]) if x.size() > 11 else "#d9b27a"
				bridge(m, by2, Vector3(x[3], x[4], x[5]), Vector2(x[6], x[7]), float(x[8]), float(x[9]), float(x[10]), false, tint)
		"seed":
			if x.size() < 9: return
			var sid := String(x[3])
			if not (m.get_meta("zone_seeds", {}) as Dictionary).has(sid):
				seed_visual(m, sid, Vector3(x[4], x[5], x[6]), float(x[7]), float(x[8]), Color("6fd0c6"))
		"pop":
			seed_pop(m, String(x[2]), Color("6fd0c6"))
		"tp":
			if x.size() < 6: return
			var body: Ent = m.ents_by_id.get(String(x[2]), null)
			if body != null and not body.remote and not body.dead:
				body.teleport(Vector3(x[3], x[4], x[5]))
