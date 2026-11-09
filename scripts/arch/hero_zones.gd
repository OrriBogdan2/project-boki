class_name HeroZones
extends RefCounted
## Placement of what Tarek (dolm) and Ostra leave in the world (rocks, rock bridges, the seed): one legality
## rule for all of it, and the Net side. A rock or seed only goes on solid ground that a body could
## stand on: not in the abyss, not inside rocks, trees, cliffs or other walls, not through a wall from
## where the caster stands. Rock bridges only replace abyss tiles (Verbs.add_bridge).
##
## Net (Net.VERSION 0.14.0): ["zone", kind, ...] events through the existing "ev" topic. The caster's
## game sends them; every other game builds the same thing, so a rock stops a remote body the same way.
##   ["zone", "rock",   nid, rid, x, y, z, dx, dz, len, time, hp, top?]   (top: a low Rock Hop rock's height)
##   ["zone", "rockgo", rid]                     a rock was launched or crumbled: remove it
##   ["zone", "bridge", nid, x, y, z, dx, dz, len, width, time, color?]   (color: hex, rock-tan when absent)
##   ["zone", "seed",   nid, sid, x, y, z, rmax, grow]
##   ["zone", "pop",    sid]

const ROCK_COL := Color("c98d4a")
const ROCK_R := 0.5                  # a rock's footprint when it asks the world if it fits
# m: a rock's top above its base (StoneStand: you stand on it), taller than a hunter's head; dolm.json rock.top
const ROCK_TOP := 2.2
const ROCK_TH := 0.42                # m: half its depth (wider than a barrier so a body fits on top)
const STEP := 0.25                   # the walk along a cast, metres
const ROCK_RISE_T := 0.22            # s: a rock heaving up out of the ground
const ROCK_REACH := 0.75             # m: past a rock's top, how far above its base a punch or slam still takes it

## Tests read what would go out over the network without a connection (--zone-check).
static var capture := false
static var sent: Array = []

static func tx(m: Node, e: Array) -> void:
	if capture:
		sent.append(e)
	if m.net_on:
		m.net_event(e)

## Can a rock or seed sit at p? Solid ground within a step of `y`, nothing in the way, no body inside.
static func fits(m: Node, p: Vector3, y: float, bodies := true, skip: Ent = null) -> bool:
	var w: World = m.world
	var g: float = w.ground_at(p.x, p.z)
	if g <= World.VOID + 1.0 or absf(g - y) > 0.9:
		return false
	if w.occupy(p.x, p.z, ROCK_R, g, false) != 0.0:
		return false
	if bodies:
		for e in m.hunters:
			if is_instance_valid(e) and e != skip and not e.dead and Vector2(
				e.pos.x - p.x, e.pos.z - p.z
			).length() < ROCK_R + e.r + 0.15 and absf(e.pos.y - g) < 2.0:
				return false
		for mb in m.mobs:
			if is_instance_valid(mb) and not mb.dead and Vector2(
				mb.pos.x - p.x, mb.pos.z - p.z
			).length() < ROCK_R + mb.r + 0.15 and absf(mb.pos.y - g) < 2.0:
				return false
	return true

## Where a zone cast measures its ground from: the caster, or the terrain under them in the air or a glide (a
## cast needs ground at the target, not at the caster's height). Over the abyss it stays the caster.
static func footing(m: Node, h: Hunter) -> Vector3:
	var g: float = m.world.ground_at(h.pos.x, h.pos.z)
	if h.grounded or g <= World.VOID + 1.0:
		return h.pos
	return Vector3(h.pos.x, minf(h.pos.y, g), h.pos.z)

## Walk from `from` toward `aim` up to `reach` and return the last legal spot:
## {ok, pos, stopped: "" | "reach" | "wall" | "abyss", over_abyss: the aim itself is over the abyss}.
static func walk(m: Node, from: Vector3, aim: Vector3, reach: float) -> Dictionary:
	var w: World = m.world
	var dv := Vector2(aim.x - from.x, aim.z - from.z)
	var want := minf(dv.length(), reach)
	var dir := dv.normalized() if dv.length() > 0.01 else Vector2(0, -1)
	var out := {
		"ok": false, "pos": from, "stopped": "reach" if dv.length() > reach else "",
		"over_abyss": w.is_void(aim.x, aim.z), "dir": dir
	}
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
## Builds a rock (a movement-blocking Verbs wall wearing a rock's look). send: tell the other games.
static func rock(
	m: Node, by: Ent, at: Vector3, dir: Vector2, rid: String, len_: float, time_: float, hp: float, send := true,
	top := ROCK_TOP
) -> Dictionary:
	var w: Dictionary = m.verbs.add_wall(
		by, at, dir, {"length": len_, "hp": hp, "time": time_, "block": "enemy", "move": true, "color": "#c98d4a"}, 1.0
	)
	var old: Node3D = w["node"]
	var n := RockLook.make()
	var tall := top / ROCK_TOP
	if tall < 1.0:
		RockLook.upright(n)
	n.scale = Vector3(len_ / 1.15, tall, 1.0)
	m.add_child(n)
	RockLook.cool(n)
	w["node"] = n
	w["rock"] = true
	w["rid"] = rid
	w["top"] = top
	w["th"] = ROCK_TH
	w["kx_end"] = func(gone: Dictionary): RockLook.crumble(m, gone)      # (broken or timed out, not launched)
	m.verbs._place_wall(w, n)
	n.scale = Vector3(len_ / 1.15, 0.05, 1.0)
	n.create_tween().tween_property(
		n, "scale", Vector3(len_ / 1.15, tall, 1.0), ROCK_RISE_T
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(old):
		old.queue_free()
	RockLook.rise_fx(m, at)
	if send and by != null and (m.net_on or capture) and not by.remote:
		var ev := [
			"zone", "rock", by.nid, rid, m._r(at.x), m._r(at.y), m._r(at.z), snappedf(dir.x, 0.001),
			snappedf(dir.y, 0.001), snappedf(len_, 0.01), snappedf(time_, 0.1), snappedf(hp, 0.1)
		]
		if top != ROCK_TOP:
			ev.append(snappedf(top, 0.01))
		tx(m, ev)
	return w

static func find_rock(m: Node, rid: String) -> Dictionary:
	for w in m.verbs.walls:
		if w.get("rid", "") == rid:
			return w
	return {}

## Can a punch or slam at height `y` take a rock whose base is at `base_y`? From the ground, or from on top
## of the rock itself.
static func rock_in_reach(base_y: float, y: float) -> bool:
	return y - base_y < ROCK_TOP + ROCK_REACH and base_y - y < 2.0

## Takes a rock out of the world without the break effects (it was launched).
static func remove_rock(m: Node, w: Dictionary, send := true) -> void:
	m.verbs.walls.erase(w)
	if is_instance_valid(w.get("node")):
		(w["node"] as Node3D).queue_free()
	if send:
		tx(m, ["zone", "rockgo", String(w.get("rid", ""))])

## A temporary rock bridge over the abyss from `from` along `dir`. Returns the tiles turned to ground.
static func bridge(
	m: Node, by: Ent, from: Vector3, dir: Vector2, len_: float, width: float, time_: float, send := true,
	color := "#d9b27a"
) -> int:
	var n: int = m.verbs.add_bridge(by, from, dir, {"length": len_, "width": width, "time": time_, "color": color})
	if n > 0 and send and by != null and (m.net_on or capture) and not by.remote:
		tx(
			m,
			[
				"zone", "bridge", by.nid, m._r(from.x), m._r(from.y), m._r(from.z), snappedf(dir.x, 0.001),
				snappedf(dir.y, 0.001), snappedf(len_, 0.1), snappedf(width, 0.1), snappedf(time_, 0.1), color
			]
		)
	return n

# ------------------------------------------------------------------ the seed (visual; the caster's game runs the rules)
## The seed: a dark indigo glass drum on the ground with a slow violet swirl (shaders/void_glass),
## growing to its full width, with a teal rim ring. Ostra's own shape; no other zone looks like it.
static func seed_visual(m: Node, sid: String, at: Vector3, rmax: float, grow: float, col: Color) -> Node3D:
	var n := Node3D.new()
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = Models.cyl(1.0, 1.0, 1.0, 28)
	core.material_override = KitLooks.glass_mat(Color("1a0636"), Color("7a5cff"), 0.8, 0.55)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = Vector3(0, 0.5, 0)
	n.add_child(core)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = Models.cyl(1.0, 1.0, 0.04, 28)
	ring.material_override = KitLooks.shade_mat(Color(col, 0.75))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	m.add_child(n)
	n.global_position = at + Vector3(0, 0.02, 0)
	n.scale = Vector3(0.45, 0.9, 0.45)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(rmax, 1.4, rmax), grow).set_trans(Tween.TRANS_SINE)
	var seeds: Dictionary = m.get_meta("zone_seeds", {})
	seeds[sid] = n
	m.set_meta("zone_seeds", seeds)
	return n

static func seed_pop(m: Node, sid: String, col: Color) -> void:
	var seeds: Dictionary = m.get_meta("zone_seeds", {})
	var n: Node3D = seeds.get(sid)
	seeds.erase(sid)
	if n != null and is_instance_valid(n):
		m.fx.ring(n.global_position, n.scale.x, col, 0.3)
		n.queue_free()

# ------------------------------------------------------------------ Net in
static func net_in(m: Node, x: Array) -> void:
	if x.size() < 3:
		return
	match String(x[1]):
		"rock":
			if x.size() < 12: return
			var by: Ent = m.ents_by_id.get(String(x[2]), null)
			if by == null or not find_rock(m, String(x[3])).is_empty(): return
			rock(
				m, by, Vector3(x[4], x[5], x[6]), Vector2(x[7], x[8]), String(x[3]), float(x[9]), float(x[10]),
				float(x[11]), false, float(x[12]) if x.size() > 12 else ROCK_TOP
			)
		"rockgo":
			var w := find_rock(m, String(x[2]))
			if not w.is_empty():
				remove_rock(m, w, false)
		"bridge":
			if x.size() < 11: return
			var by2: Ent = m.ents_by_id.get(String(x[2]), null)
			if by2 != null:
				var tint := String(x[11]) if x.size() > 11 else "#d9b27a"
				bridge(
					m, by2, Vector3(x[3], x[4], x[5]), Vector2(x[6], x[7]), float(x[8]), float(x[9]), float(x[10]),
					false, tint
				)
		"seed":
			if x.size() < 9: return
			var sid := String(x[3])
			if not (m.get_meta("zone_seeds", {}) as Dictionary).has(sid):
				seed_visual(m, sid, Vector3(x[4], x[5], x[6]), float(x[7]), float(x[8]), Color("6fd0c6"))
		"pop":
			seed_pop(m, String(x[2]), Color("6fd0c6"))
