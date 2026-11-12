class_name UltLook
extends CareLook
## Pooled looks of the support pair's ultimates on X, on top of CareLook's (same pool, burst and keep):
##   Pip, Hearth Call: the lantern tether, a braid of warm lantern-gold light with two twisting strands.
##   Claire, Rimelock: the rink (a faint sheet of ice whose cracks glow as it builds, a fringe of
##   crystals on its edge; the lit ring at the hit radius is the kit's AimKit circle), the frost bud
##   at her feet, the light pillar of the crash and the ice block on each stunned foe. Her body is
##   IceBody's while sealed.
## keep(key, "tether", from, {b, a, col}) (also the Burrseed's vine, tinted), keep(key, "rink", at, {r, crack, a}),
## keep(key, "frostbud", at, {grow, crack}),
## burst("pillar", at, {r, dur}), burst("block", at, {ent, dur}).

const FRINGE := 18            # crystals round the rink's edge
const RINK_FILL := 0.35       # rink body strength (doubles by the crash): alpha 0.1-0.2 at the centre, the zone rule
const BUD_SPIKES := 6         # low ice spikes the frost bud throws out from her feet
const BUD_REACH := 0.95       # m: how far those spikes reach, about half her height (not the rink's size)


func _build(kind: String) -> Node3D:
	if not kind in ["tether", "rink", "frostbud", "pillar", "block"]:
		return super._build(kind)
	made += 1
	var n := Node3D.new()
	n.name = kind
	match kind:
		"tether":
			_build_tether(n)
		"rink":
			_build_rink(n)
		"frostbud":
			_build_bud(n)
		"pillar":
			var col := Models.cyl(1.0, 1.0, 1.0, 16)
			_off(Models.part(n, col, glow_mat(Color("bfeaff", 0.75), 1.0), Vector3(0, 0.5, 0)))
			_off(Models.part(n, col, glow_mat(Color("dff6ff", 0.9), 1.0), Vector3(0, 0.5, 0), Vector3(0.35, 1, 0.35)))
		"block":
			_off(Models.part(n, Models.box(1.0, 2.0, 1.0), ice_mat(Color("bfeeff"), 0.55, 0.35), Vector3(0, 1.0, 0)))
			var cap := _off(Models.part(
					n, Models.crystal(0.3, 0.6, 4), ice_mat(Color("e8ffff"), 0.8, 0.5), Vector3(0, 2.1, 0)))
			cap.rotation = Vector3(0, 0.6, 0)
	root.add_child(n)
	return n


## Two strands of lantern light twisting round a soft core, 1 m long along -Z (scaled to the gap).
func _build_tether(n: Node3D) -> void:
	var core := _off(Models.part(n, Models.box(0.09, 0.09, 1.0), glow_mat(Color("ffe2b0", 0.95)), Vector3(0, 0, -0.5)))
	core.name = "Core"
	var halo := _off(Models.part(n, Models.box(0.32, 0.32, 1.0), glow_mat(Color("ffc46a", 0.22)), Vector3(0, 0, -0.5)))
	halo.name = "Halo"
	var twist := Node3D.new()
	twist.name = "Twist"
	n.add_child(twist)
	for side in [-1.0, 1.0]:
		var strand := Models.box(0.04, 0.04, 1.0)
		_off(Models.part(twist, strand, glow_mat(Color("ffe6a8", 0.85)), Vector3(0.11 * side, 0, -0.5)))


## A flat disc (care_disc pattern 4: ragged edge, cracks) and a fringe of short crystals on its rim.
func _build_rink(n: Node3D) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	var disc := _off(Models.part(n, pm, disc_mat(Color("7fd8ff"), Color("e8ffff"), 4.0), Vector3(0, 0.05, 0)))
	disc.name = "Disc"
	var fringe := Node3D.new()
	fringe.name = "Fringe"
	n.add_child(fringe)
	for i in FRINGE:
		var a := TAU * i / FRINGE
		var tall := 0.35 + 0.3 * absf(sin(float(i) * 2.7))
		var c := _off(Models.part(
				fringe, Models.crystal(0.08, tall, 4), ice_mat(Color("bff7ef"), 0.75, 0.3), Vector3.ZERO))
		c.set_meta("a", a)
		c.rotation = Vector3(0.35 * cos(float(i) * 1.9), a, 0.45 * sin(a))


## The frost bud on her ice body: six low spikes splayed out from her feet in a star and six short
## crystals standing close round her shins, so the centre of the rink is a crystal, not a filled disc.
func _build_bud(n: Node3D) -> void:
	for i in BUD_SPIKES:
		var a := TAU * (float(i) + 0.5) / BUD_SPIKES
		var out := Vector3(cos(a), 0.35, sin(a)).normalized()
		_bud_crystal(n, Vector3(cos(a), 0.0, sin(a)) * 0.25, out, Models.crystal(0.11, BUD_REACH, 4), Color("aee8ff"))
		var b := TAU * float(i) / BUD_SPIKES
		var up := Vector3(cos(b) * 0.35, 1.0, sin(b) * 0.35).normalized()
		_bud_crystal(n, Vector3(cos(b), 0.0, sin(b)) * 0.3, up, Models.crystal(0.08, 0.6, 4), Color("e8ffff"))


## One crystal of the bud, its foot at `foot`, pointing along `dir` (Models.crystal is centred on its middle).
func _bud_crystal(n: Node3D, foot: Vector3, dir: Vector3, mesh: ArrayMesh, c: Color) -> void:
	var half := mesh.get_aabb().size.y * 0.5
	var mi := _off(Models.part(n, mesh, ice_mat(c, 0.75, 0.3), foot + dir * half))
	mi.basis = Basis(Quaternion(Vector3.UP, dir))


# ------------------------------------------------------------------ timed one-offs
func _style(e: Dictionary, k: float) -> void:
	var n: Node3D = e["n"]
	var p: Dictionary = e["p"]
	match String(e["fx"]):
		"pillar":
			# drops out of the sky in the first quarter, then thins and fades
			var r := float(p.get("r", 1.0))
			var fall := clampf(k * 4.0, 0.0, 1.0)
			n.scale = Vector3(r * (1.0 - 0.6 * k), 14.0, r * (1.0 - 0.6 * k))
			n.position.y = (e["at"] as Vector3).y + (1.0 - fall) * 10.0
			_tint(n, Color.WHITE, 1.0 - smoothstep(0.4, 1.0, k))
		"block":
			n.scale = Vector3.ONE * lerpf(0.5, 1.0, _out_back(clampf(k * 8.0, 0.0, 1.0)))
			_tint(n, Color.WHITE, 1.0 - smoothstep(0.85, 1.0, k))
		_:
			super._style(e, k)


# ------------------------------------------------------------------ held looks
func keep(key: String, kind: String, at: Vector3, p := {}) -> void:
	if not kind in ["tether", "rink", "frostbud"]:
		super.keep(key, kind, at, p)
		return
	var e: Dictionary = held.get(key, {})
	if e.is_empty() or String(e["kind"]) != kind or not is_instance_valid(e["n"]):
		if not e.is_empty():
			_give(String(e["kind"]), e["n"])
		e = {"n": _take(kind), "kind": kind}
		held[key] = e
	e["last"] = m.time
	e["p"] = p
	var n: Node3D = e["n"]
	n.global_position = at
	match kind:
		"tether":
			_place_tether(n, at, p)
		"rink":
			_place_rink(n, p)
		"frostbud":
			n.scale = Vector3.ONE * maxf(0.05, _out_back(clampf(float(p.get("grow", 1.0)), 0.0, 1.0)))
			var glow := 0.3 + 0.9 * clampf(float(p.get("crack", 0.0)), 0.0, 1.0)
			for c in n.get_children():
				((c as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("glow", glow)


func _place_tether(n: Node3D, from: Vector3, p: Dictionary) -> void:
	var to: Vector3 = p.get("b", from + Vector3.FORWARD)
	var gap := maxf(0.1, from.distance_to(to))
	if gap > 0.15:
		n.look_at(to, Vector3.UP)
	n.scale = Vector3(1.0, 1.0, gap)
	var tw := n.get_node_or_null("Twist") as Node3D
	if tw:
		tw.rotation.z = m.time * 7.0
	var pulse := 0.75 + 0.25 * sin(m.time * 9.0)
	_tint(n, p.get("col", Color.WHITE), pulse * float(p.get("a", 1.0)))


func _place_rink(n: Node3D, p: Dictionary) -> void:
	var r := float(p.get("r", 1.0))
	var crack := clampf(float(p.get("crack", 0.0)), 0.0, 1.0)
	n.scale = Vector3.ONE
	var disc := n.get_node_or_null("Disc") as MeshInstance3D
	if disc:
		disc.scale = Vector3(r, 1.0, r)
		_disc(disc.get_parent() as Node3D, Color("7fd8ff"), Color("e8ffff"), float(p.get("a", 1.0)), 4.0, -1.0, 0.0)
		var sm := disc.material_override as ShaderMaterial
		sm.set_shader_parameter("crack", crack)
		sm.set_shader_parameter("fill", RINK_FILL + RINK_FILL * crack)
	var fringe := n.get_node_or_null("Fringe") as Node3D
	if fringe == null:
		return
	for c in fringe.get_children():
		var mi := c as MeshInstance3D
		var a := float(mi.get_meta("a", 0.0))
		mi.position = Vector3(cos(a) * r * 0.96, 0.1, sin(a) * r * 0.96)
		(mi.material_override as ShaderMaterial).set_shader_parameter("glow", 0.2 + 0.9 * crack)
