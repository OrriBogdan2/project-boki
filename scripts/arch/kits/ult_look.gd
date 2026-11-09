class_name UltLook
extends CareLook
## Pooled looks of the support pair's ultimates on X, on top of CareLook's (same pool, burst and keep):
##   Pip, Hearth Call: the lantern tether, a braid of warm lantern-gold light with two twisting strands.
##   Claire, Rimelock: the rink (a ragged sheet of ice whose cracks glow as it builds, a fringe of
##   crystals on its edge), her frost bud (six curved ice petals closing over her, not a star), the
##   light pillar of the crash and the ice block on each stunned foe.
## keep(key, "tether", from, {b, k}), keep(key, "rink", at, {r, crack, a}), keep(key, "frostbud", at, {k}),
## burst("pillar", at, {r, dur}), burst("block", at, {ent, dur}).

const FRINGE := 18            # crystals round the rink's edge
const PETALS := 6             # ice petals of the frost bud
const TETHER_SEGS := 10       # straight pieces the tether arc is bent from
const TETHER_BOW := 0.14      # the arc's sideways and upward bow, as a share of the hand-to-ally gap


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


## The tether: TETHER_SEGS short segments, each two strands of lantern light twisting round a 0.16 m core with a
## 0.5 m halo, 1 m long along -Z; _place_tether bends them into an arc between the hand and the ally.
func _build_tether(n: Node3D) -> void:
	for i in TETHER_SEGS:
		var seg := Node3D.new()
		seg.name = "Seg%d" % i
		n.add_child(seg)
		_off(Models.part(seg, Models.box(0.16, 0.16, 1.0), glow_mat(Color("ffe2b0", 0.95)), Vector3(0, 0, -0.5)))
		_off(Models.part(seg, Models.box(0.5, 0.5, 1.0), glow_mat(Color("ffc46a", 0.3)), Vector3(0, 0, -0.5)))
		var twist := Node3D.new()
		twist.name = "Twist"
		seg.add_child(twist)
		var strand_mat := glow_mat(Color("ffe6a8", 0.85))
		for side in [-1.0, 1.0]:
			_off(Models.part(twist, Models.box(0.07, 0.07, 1.0), strand_mat, Vector3(0.2 * side, 0, -0.5)))


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


## Six long curved ice petals leaning in over her and meeting above the head, round a cold core glow.
func _build_bud(n: Node3D) -> void:
	for i in PETALS:
		var a := TAU * i / PETALS
		var p := Node3D.new()
		p.name = "Petal%d" % i
		p.rotation = Vector3(0, a, 0)
		n.add_child(p)
		var blade := _off(Models.part(
				p, Models.crystal(0.24, 2.5, 5), ice_mat(Color("aee8ff"), 0.55, 0.3), Vector3(0, 1.15, 0.62)))
		blade.rotation = Vector3(-0.42, 0, 0)
		var tip := _off(Models.part(
				p, Models.crystal(0.1, 0.7, 4), ice_mat(Color("e8ffff"), 0.8, 0.6), Vector3(0, 0.25, 0.75)))
		tip.rotation = Vector3(0.9, 0, 0)
	var glow := _off(Models.part(n, Models.capsule(0.5, 1.9), glow_mat(Color("9fe0ff", 0.28)), Vector3(0, 1.0, 0)))
	glow.name = "Core"


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
			var grow := _out_back(clampf(float(p.get("k", 1.0)), 0.0, 1.0))
			n.scale = Vector3(grow, maxf(0.05, grow), grow)
			n.rotation.y = m.time * 0.3


## The arc from `from` to p.b: it bows out to her right and up by TETHER_BOW of the gap, so the line reads as
## a throw to the ally at the match camera, not a stick between two bodies.
func _place_tether(n: Node3D, from: Vector3, p: Dictionary) -> void:
	var to: Vector3 = p.get("b", from + Vector3.FORWARD)
	var gap := maxf(0.1, from.distance_to(to))
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var side := flat.cross(Vector3.UP).normalized() if flat.length() > 0.1 else Vector3.RIGHT
	var bow := (side + Vector3.UP) * gap * TETHER_BOW
	var pulse := 0.8 + 0.2 * sin(m.time * 9.0)
	var prev := from
	for i in TETHER_SEGS:
		var u := float(i + 1) / TETHER_SEGS
		var next := from.lerp(to, u) + bow * 4.0 * u * (1.0 - u)
		var seg := n.get_node("Seg%d" % i) as Node3D
		if prev.distance_to(next) > 0.01:
			seg.global_transform = Transform3D(Basis.looking_at(next - prev, Vector3.UP), prev)
			seg.scale = Vector3(1.0, 1.0, prev.distance_to(next))
		(seg.get_node("Twist") as Node3D).rotation.z = m.time * 7.0 + float(i)
		prev = next
	_tint(n, Color.WHITE, pulse * float(p.get("a", 1.0)))


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
		sm.set_shader_parameter("fill", 0.7 + 0.5 * crack)
	var fringe := n.get_node_or_null("Fringe") as Node3D
	if fringe == null:
		return
	for c in fringe.get_children():
		var mi := c as MeshInstance3D
		var a := float(mi.get_meta("a", 0.0))
		mi.position = Vector3(cos(a) * r * 0.96, 0.1, sin(a) * r * 0.96)
		(mi.material_override as ShaderMaterial).set_shader_parameter("glow", 0.2 + 0.9 * crack)
