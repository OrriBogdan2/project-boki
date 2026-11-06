extends RefCounted
## --cinder-art-check: Cinder's model (ART-1) against her kit, through the real match code and render path.
## The nozzle FX leave the gun you see, through the idle hold and the hose (item 76b); the stream starts about where
## the procedural one did, so its reach holds; in Flue Flight both stacks carry a jet (their flames stretched by the
## clip) and the nozzle is stowed; the fire surfaces are on the flame shader. Never touches the save.

const DT := 1.0 / 60.0
const NEAR := 0.04              # m: FX to the visible nozzle
const REACH_OFF := 0.14         # m: the braced nozzle's forward reach off the kit's old NOZZLE

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CINDERART %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	if h.model and h.model.has_node("Warden/Sync"):
		var sync: Node = h.model.get_node("Warden/Sync")
		sync.set_process(false)
		sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("ashwick", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var kit: AshwickKit = P.ak
	for f in 12:
		_frame(m, P)
	var mz := WardenGlb.anchor(P.model, "weapon_muzzle")
	ok(mz != null, "the skinned gun has its muzzle")
	var fire := 0
	for mat in P.model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mat as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var sm := (mat as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm and sm.shader == WardenGlb.FLAME:
				fire += 1
	ok(fire >= 3, "hair, jets and fuel are on the flame shader (%d surfaces)" % fire)
	var gm := P.model.get_node("Rig/Torso/Aim/Gun/Muzzle") as Node3D
	ok(kit.tip().distance_to(gm.global_position) < NEAR, "at rest the pilot sits on the gun's tip")
	T.teleport(P.pos + Vector3(0, 0, 40.0))
	A.aim_at(P, P.pos + Vector3(0, 0, 6.0))
	var worst := 0.0
	var fwd_sum := 0.0
	var up_sum := 0.0
	var right_sum := 0.0
	var n := 0
	var held_w := 0.0
	for f in 60:
		P.inp["fire"] = true
		_frame(m, P)
		held_w = maxf(held_w, _clips(P).up_w + _clips(P).act_w)
		worst = maxf(worst, kit.tip().distance_to(gm.global_position))
		if f > 30:
			var loc := P.model.to_local(kit.tip()) * P.model.scale     # (the camera's lean out of it)
			fwd_sum += -loc.z
			up_sum += loc.y
			right_sum += loc.x
			n += 1
	var parts: Array = kit.hose.parts(0.5, 2.2)
	var nearest := 9.0
	for pt in parts:
		nearest = minf(nearest, ((pt["p"] as Vector3) - kit.tip()).length())
	ok(nearest < 0.5, "the drawn stream starts at the gun's tip (nearest puff %.2f m)" % nearest)
	P.inp["fire"] = false
	ok(held_w >= 1.0, "held LMB plays the hose clip (%.2f)" % held_w)
	ok(worst < NEAR, "through the hose the FX stay on the gun's tip (worst %.3f m)" % worst)
	var reach := fwd_sum / maxf(1.0, float(n))
	print("CINDERART braced tip: fwd %.3f up %.3f right %.3f" % [reach, up_sum / n, right_sum / n])
	ok(absf(reach - AshwickKit.NOZZLE.x) < REACH_OFF, "the braced nozzle reaches %.2f m ahead (kit %.2f m)"
			% [reach, AshwickKit.NOZZLE.x])
	ok(kit.hose.emitted > 0, "the stream ran (%d puffs)" % kit.hose.emitted)
	for f in 40:
		_frame(m, P)
	var jet := kit.jet
	ok(jet.start(), "Flue Flight lifts off")
	var spread := 0.0
	var stowed := true
	var jet_y := 0.0
	var fr := 0
	while jet.running() and fr < 200:
		_frame(m, P)
		fr += 1
		if fr < 30:
			continue
		var pts := jet.jet_points(P.aim_dir())
		if pts.size() != 2:
			stowed = false
			continue
		spread = maxf(spread, (pts[0] as Vector3).distance_to(pts[1]))
		var sk := P.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bi := sk.find_bone("jet.0")
		jet_y = maxf(jet_y, sk.get_bone_pose_scale(bi).y)
		if kit.nozzle().distance_to(P.pos + Vector3(P.aim_dir().x, 0, P.aim_dir().y) * 1.0) < 0.2:
			stowed = false
	ok(spread > 0.06, "two jets, one on each stack (%.2f m apart)" % spread)
	ok(jet_y > 2.0, "the clip stretches the stacks' flames in flight (x%.1f)" % jet_y)
	ok(stowed, "the nozzle is stowed, not held out, in flight")
	print("CINDERART_DONE fails=%d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
