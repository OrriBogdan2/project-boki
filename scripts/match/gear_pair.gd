class_name GearPair
extends RefCounted
## The look of Tarek (dolm) and Ostra (HeroGear.dress asks): original silhouettes, built from the same
## parametric pieces as the first six. Tarek: a stone-plated right shoulder, a rubble collar, a leather
## apron and chisel belt, a bare head under a stone brow band. Ostra: a tall wrapped headcloth with a
## long tail, a pale mantle, a trailing hem and three small lanterns that hang behind her.

const HC := Vector3(0, 0.86, 0)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

## What the headgear hides of the hair ("" none).
static func cover(arch: String, bare: bool) -> String:
	if bare:
		return ""
	return "hood" if arch == "ostra" else ""

static func dolm(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var cw: float = c["cw"]; var bw: float = c["bw"]
	var stone := Models.toon(Color("a8794a"), true, 0.5)
	var pale := Models.toon(Color("e0bd86"), true, 0.5)
	var team := HeroGear._deep_acc(m)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		# a stone brow band with a short crest of chips
		_p(g, HeroKit.band("dolm_brow", 0.215, 0.235, 0.07, 0.02), stone, HC + Vector3(0, 0.12, 0.0))
		for k in 5:
			_p(g, Models.box(0.05, 0.1 + 0.02 * (k % 2), 0.05), pale, HC + Vector3(-0.1 + 0.05 * k, 0.22, -0.08), Vector3.ONE, Vector3(0, 0, 0.12 * (k - 2)))
	# the right shoulder: a heap of stone plates, strapped on
	var pr: Node3D = c["pr"]
	_p(pr, Models.box(0.5, 0.3, 0.46), stone, Vector3(0.1, 0.12, 0), Vector3.ONE, Vector3(0, 0, -0.2))
	_p(pr, Models.box(0.34, 0.28, 0.34), pale, Vector3(0.16, 0.34, -0.02), Vector3.ONE, Vector3(0.15, 0.3, -0.35))
	_p(pr, Models.box(0.24, 0.22, 0.24), stone, Vector3(0.02, 0.46, 0.06), Vector3.ONE, Vector3(-0.2, 0.6, 0.3))
	var pl: Node3D = c["pl"]
	_p(pl, Models.box(0.3, 0.16, 0.3), stone, Vector3(-0.06, 0.08, 0), Vector3.ONE, Vector3(0, 0, 0.2))
	_p(pl, Models.box(0.16, 0.14, 0.16), pale, Vector3(-0.08, 0.2, 0.02), Vector3.ONE, Vector3(0.2, 0.4, 0.3))
	# a slab of stone strapped across the chest
	_p(t, Models.box(0.34 * cw, 0.26, 0.08), stone, Vector3(0, 0.46, -0.235 * bw), Vector3.ONE, Vector3(0.05, 0, 0))
	_p(t, Models.box(0.1, 0.3, 0.09), pale, Vector3(0.0, 0.46, -0.245 * bw), Vector3.ONE, Vector3(0.05, 0, 0.0))
	# a collar of rubble and a leather apron with a team-coloured sash
	_p(t, HeroKit.band("dolm_collar", 0.2 * cw, 0.26 * cw, 0.07, 0.03), stone, Vector3(0, 0.66, 0.0))
	_p(t, Models.box(0.36 * cw, 0.5, 0.05), m["leather"], Vector3(0, 0.2, -0.235 * bw), Vector3.ONE, Vector3(0.03, 0, 0))
	_p(t, Models.box(0.1, 0.52, 0.06), team, Vector3(0.0, 0.2, -0.255 * bw))
	for k in 4:
		_p(t, Models.box(0.025, 0.14, 0.025), m["steel"], Vector3(-0.15 + 0.1 * k, 0.04, -0.24 * bw), Vector3.ONE, Vector3(0, 0, 0.0))
	# stone wrist cuffs on both forearms
	for sd in ["L", "R"]:
		var hand: Node3D = (c["arms"][sd] as Array)[2]
		_p(hand, Models.cyl(0.085, 0.09, 0.12, 8), stone, Vector3(0, 0.12, 0))

static func ostra(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var cw: float = c["cw"]; var bw: float = c["bw"]
	var pearl := Models.toon(Color("efe8d6"), true, 0.3)
	var brass := Models.shiny(Color("c9a35a"), 0.6)
	var team := HeroGear._deep_acc(m)
	var glowm := Models.toon(Color("9bf2e4"), false, 1.8)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		# a wrapped headcloth rising to a soft point, with a long tail down the back
		var wrap := func(u: float, v: float) -> Vector3:
			var th := u * TAU
			var w := 1.0 - v            # v runs down from the peak, as the crown of a hat does
			var r := 0.215 * (1.0 - 0.45 * w * w)
			return Vector3(cos(th) * r, w * 0.34, sin(th) * r * 1.05)
		var wrap_ao := func(u: float, v: float) -> float: return lerpf(1.0, 0.8, v * v)
		_p(g, HeroKit.surf("ostra_wrap", wrap, 28, 10, wrap_ao), pearl, HC + Vector3(0, 0.1, 0.0))
		_p(g, HeroKit.band("ostra_wrapband", 0.215, 0.235, 0.05, 0.015), team, HC + Vector3(0, 0.12, 0.0))
		_p(g, HeroKit.lock_mesh("ostra_tail", [HC + Vector3(0, 0.3, 0.1), HC + Vector3(0, 0.26, 0.3), HC + Vector3(0, 0.0, 0.42), HC + Vector3(0, -0.34, 0.46)], 0.09, 0.24, Vector3.RIGHT, 0.8, 0.3), pearl)
	# the hem: long, open at the front
	var sk: Node3D = c["skirt"]
	var r0 := 0.234 * maxf(bw, cw * 0.95); var r1 := 0.46 * bw
	for side in [[0.75, 1.235], [1.265, 1.75]]:
		var a0: float = side[0]; var a1: float = side[1]
		var key := "ost_hem%.3f|%.3f" % [a0, r0]
		_p(sk, HeroKit.drape(key, r0, r1, 0.62, a0, a1, 6.0, 0.07, 0.02, 0.1), pearl, Vector3(0, -0.02, 0.01))
		_p(sk, HeroKit.drape_hem(key, r0, r1, 0.62, a0, a1, 6.0, 0.07, 0.02, 0.1, 0.07), team, Vector3(0, -0.02, 0.01))
	# a pale mantle over the shoulders, a brass clasp at the throat
	_p(t, HeroKit.drape("ost_mantle|%.3f" % cw, 0.19 * cw, 0.34 * cw, 0.2, 0.0, 1.0, 4.0, 0.03, 0.01, 0.06, 0.016), pearl, Vector3(0, 0.64, 0.01))
	_p(t, Models.sphere(0.03, 8), brass, Vector3(0, 0.62, -0.17 * bw))
	# three little lanterns hang behind her on thin chains, glowing teal
	for k in 3:
		var a := PI * 0.5 + (k - 1) * 0.55
		var base := Vector3(cos(a) * 0.3, 0.5 + 0.12 * (k % 2), 0.2 + sin(a) * 0.1)
		_p(t, Models.cyl(0.006, 0.006, 0.2, 5), brass, base + Vector3(0, 0.1, 0))
		_p(t, Models.cyl(0.04, 0.05, 0.03, 8), brass, base)
		_p(t, Models.sphere(0.045, 8), glowm, base + Vector3(0, -0.05, 0))
