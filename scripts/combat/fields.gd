class_name Fields
extends RefCounted
## Patches on the ground made by "zone" effects (Thorn Patch and friends): they keep hurting,
## slowing, rooting or healing whatever stands in them until they run out.

var m: Node = null
var list: Array = []

func _init(match_node: Node) -> void:
	m = match_node

func add(caster: Node, at: Vector3, e: Dictionary, ctx: Dictionary, power: float) -> void:
	var r := float(e.get("radius", 2.5))
	var col := Color(String(e.get("color", "#ffffff")))
	var n := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(r * 2.0)
	ring.material_override = Models.ring_mat(Color(col, 0.85), 0.07)
	ring.position.y = 0.07
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var fill := MeshInstance3D.new()
	fill.mesh = Models.cyl(r, r, 0.02, 32)
	fill.material_override = Models.glow_mat(Color(col, 0.16))
	fill.position.y = 0.04
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(fill)
	m.add_child(n)
	n.global_position = at
	m.fx.burst(at + Vector3(0, 0.3, 0), col, 16, 3.0, 0.5)
	list.append({"caster": caster, "team": caster.team, "at": at, "r": r, "e": e, "ctx": ctx, "pw": power,
		"t": float(e.get("time", 4.0)), "tick": 0.0, "node": n, "col": col})

## A grammar zone, aura, linger patch or summon (KinExec): every `every` seconds it calls
## tick(at, entry); when it runs out, end(at). `follow` keeps it on a body (auras, sprites).
## `model` is a core-made shape standing in it ("totem", "sprite") or "".
func add_kx(caster: Node, at: Vector3, r: float, time: float, every: float, col: Color, tick: Callable, end: Callable, follow: Node = null, model := "") -> Dictionary:
	var n := Node3D.new()
	var ring := MeshInstance3D.new()
	ring.mesh = Models.flat_quad(r * 2.0)
	ring.material_override = Models.ring_mat(Color(col, 0.85), 0.07)
	ring.position.y = 0.07
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var fill := MeshInstance3D.new()
	fill.mesh = Models.cyl(r, r, 0.02, 32)
	fill.material_override = Models.glow_mat(Color(col, 0.14))
	fill.position.y = 0.04
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(fill)
	match model:
		"totem":
			Models.part(n, Models.cyl(0.18, 0.26, 1.1, 8), Models.toon(col.darkened(0.3), true, 0.7), Vector3(0, 0.55, 0))
			Models.part(n, Models.sphere(0.2, 10), Models.glow_mat(Color(col, 0.85)), Vector3(0, 1.25, 0))
		"sprite":
			Models.part(n, Models.sphere(0.22, 10), Models.glow_mat(Color(col, 0.85)), Vector3(0.6, 1.4, 0))
	m.add_child(n)
	n.global_position = at
	m.fx.burst(at + Vector3(0, 0.3, 0), col, 14, 3.0, 0.5)
	var z := {"caster": caster, "team": int(caster.team) if caster else -1, "at": at, "r": r, "e": {"every": every}, "ctx": {}, "pw": 1.0,
		"t": time, "tick": 0.0, "node": n, "col": col, "kx": tick, "kx_end": end, "follow": follow}
	list.append(z)
	return z

func tick(dt: float) -> void:
	for z in list.duplicate():
		z["t"] = float(z["t"]) - dt
		z["tick"] = float(z["tick"]) - dt
		var e: Dictionary = z["e"]
		if z.get("follow") != null:
			var fl = z["follow"]
			if is_instance_valid(fl) and not fl.dead:
				z["at"] = Vector3(fl.pos.x, fl.pos.y, fl.pos.z)
				(z["node"] as Node3D).global_position = z["at"]
			else:
				z["t"] = 0.0
		var at: Vector3 = z["at"]
		if z.has("kx"):
			if float(z["tick"]) <= 0.0 and float(z["t"]) > 0.0:
				z["tick"] = float(e.get("every", 0.5))
				(z["kx"] as Callable).call(at, z)
				m.fx.burst(at + Vector3(randf_range(-0.5, 0.5) * float(z["r"]), 0.2, randf_range(-0.5, 0.5) * float(z["r"])), z["col"], 4, 2.0, 0.4, 3.0)
			var n0: Node3D = z["node"]
			if float(z["t"]) < 0.5:
				n0.scale = Vector3.ONE * maxf(0.05, float(z["t"]) / 0.5)
			if float(z["t"]) <= 0.0:
				n0.queue_free()
				list.erase(z)
				if z.get("kx_end") is Callable and (z["kx_end"] as Callable).is_valid():
					(z["kx_end"] as Callable).call(at)
			continue
		if float(z["tick"]) <= 0.0:
			z["tick"] = float(e.get("every", 0.5))
			var caster = z["caster"]
			var by: Ent = caster if is_instance_valid(caster) and not caster.dead else null
			for f in m.foes_of(int(z["team"])):
				if e.get("own", false) and f.remote:
					continue        # a hazard's patch, on every game: each game hurts only its own bodies
				if Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < float(z["r"]) + f.r and AimMode.in_reach(at.y, f.pos.y):
					var o := {"src": "kin" if by is Kin else "abil", "ab": String(z["ctx"].get("slot", "zone")), "tags": ["zone", String(z["ctx"].get("ability", ""))]}
					for k in ["slow", "root", "stun", "burn"]:
						if e.has(k): o[k] = float(e[k])
					if float(e.get("dmg", 0.0)) > 0.0:
						f.hurt(float(e["dmg"]) * float(z["pw"]), by, o)
					else:
						if o.has("slow"): f.slow_t = maxf(f.slow_t, float(o["slow"]))
						if o.has("root"): f.root_t = maxf(f.root_t, float(o["root"]))
			if float(e.get("heal", 0.0)) > 0.0:
				for h in m.hunters:
					if h.team == int(z["team"]) and not h.out and Vector2(h.pos.x - at.x, h.pos.z - at.z).length() < float(z["r"]):
						h.heal(float(e["heal"]))
			m.fx.burst(at + Vector3(randf_range(-0.5, 0.5) * float(z["r"]), 0.2, randf_range(-0.5, 0.5) * float(z["r"])), z["col"], 5, 2.0, 0.4, 3.0)
		var n: Node3D = z["node"]
		if float(z["t"]) < 0.5:
			n.scale = Vector3.ONE * maxf(0.05, float(z["t"]) / 0.5)
		if float(z["t"]) <= 0.0:
			n.queue_free()
			list.erase(z)

func clear() -> void:
	for z in list:
		(z["node"] as Node3D).queue_free()
	list.clear()
