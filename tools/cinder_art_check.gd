extends RefCounted
## --cinder-art-check: Cinder's model (ART-1) against her kit, through the real match code and render path.
## The fire leaves her casting palm (no weapon) through the idle hold and the stream, and that palm is really held out;
## her magma cracks brighten while it runs and fall back after; in Flue Flight both heels carry a jet (their flames
## stretched by the clip) and the hand is free; the fire surfaces are on the flame shader. Never touches the save.

const DT := 1.0 / 60.0
const NEAR := 0.04              # m: FX to the palm
const REACH_MIN := 0.3          # m: the braced palm ahead of her feet

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

## The emission of her magma crack layer now.
func _emit(h: Hunter) -> float:
	for x in h.model.get_meta("mats", []):
		if x is ShaderMaterial and (x as ShaderMaterial).get_shader_parameter("use_emit") == true:
			return float((x as ShaderMaterial).get_shader_parameter("emit"))
	return 0.0

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
	ok(mz != null, "the casting hand has its fire point")
	ok(WardenGlb.anchor(P.model, "anchor_tail_tip") != null, "the tail tip has its flame point")
	var fire := 0
	for mat in P.model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mat as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var sm := (mat as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm and sm.shader == WardenGlb.FLAME:
				fire += 1
	ok(fire >= 2, "hair and jets are on the flame shader (%d surfaces)" % fire)
	var gm := P.model.get_node("Rig/Torso/Aim/Gun/Muzzle") as Node3D
	ok(kit.tip().distance_to(gm.global_position) < NEAR, "at rest the fire point sits on her palm")
	T.teleport(P.pos + Vector3(0, 0, 40.0))
	A.aim_at(P, P.pos + Vector3(0, 0, 6.0))
	var worst := 0.0
	var fwd_sum := 0.0
	var up_sum := 0.0
	var right_sum := 0.0
	var n := 0
	var held_w := 0.0
	var emit0 := _emit(P)
	var emit_hot := 0.0
	for f in 60:
		P.inp["fire"] = true
		_frame(m, P)
		held_w = maxf(held_w, _clips(P).up_w + _clips(P).act_w)
		emit_hot = maxf(emit_hot, _emit(P))
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
	ok(nearest < 0.5, "the drawn stream starts at her palm (nearest puff %.2f m)" % nearest)
	P.inp["fire"] = false
	ok(held_w >= 1.0, "held LMB plays the casting clip (%.2f)" % held_w)
	ok(worst < NEAR, "through the stream the FX stay on her palm (worst %.3f m)" % worst)
	ok(emit_hot > emit0 + 1.0, "the magma cracks brighten while she casts (%.1f to %.1f)" % [emit0, emit_hot])
	var reach := fwd_sum / maxf(1.0, float(n))
	print("CINDERART braced palm: fwd %.3f up %.3f right %.3f" % [reach, up_sum / n, right_sum / n])
	ok(reach > REACH_MIN, "the braced palm reaches %.2f m ahead" % reach)
	ok(kit.hose.emitted > 0, "the stream ran (%d puffs)" % kit.hose.emitted)
	for f in 60:
		_frame(m, P)
	await main.get_tree().create_timer(AshwickKit.CRACKS_FADE + 0.2).timeout
	ok(_emit(P) < emit0 + 0.2, "the cracks fall back after (%.1f)" % _emit(P))
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
	ok(spread > 0.06, "two jets, one on each heel (%.2f m apart)" % spread)
	ok(jet_y > 2.0, "the clip stretches the heels' flames in flight (x%.1f)" % jet_y)
	ok(stowed, "the fire is off her hand in flight")
	print("CINDERART_DONE fails=%d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
