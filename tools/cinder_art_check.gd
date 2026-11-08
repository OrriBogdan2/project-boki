extends RefCounted
## --cinder-art-check: Cinder's fire against her kit, through the real match code and render path: the pilot and the stream leave her
## casting hand (palm) through the idle hold and the stream, its rules still start where they did (the kit's NOZZLE);
## in Flue Flight the fire bursts from both heels and the tail and no stream runs; the hair is on the flame shader.
## Never touches the save.

const DT := 1.0 / 60.0
const NEAR := 0.04              # m: FX to her palm

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
	var fire := 0
	for mat in P.model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mat as MeshInstance3D).mesh
		if mesh == null:
			continue
		for si in mesh.get_surface_count():
			var sm := (mat as MeshInstance3D).get_surface_override_material(si) as ShaderMaterial
			if sm and sm.shader == WardenGlb.FLAME:
				fire += 1
	ok(fire >= 3, "hair is on the flame shader (%d surfaces)" % fire)
	ok(kit.tip().distance_to(_palm(P)) < NEAR, "at rest the pilot sits in her casting hand")
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
		worst = maxf(worst, kit.tip().distance_to(_palm(P)))
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
	ok(held_w >= 1.0, "held LMB plays the stream clip (%.2f)" % held_w)
	ok(worst < NEAR, "through the stream the FX stay on her palm (worst %.3f m)" % worst)
	print("CINDERART palm: fwd %.3f up %.3f right %.3f" % [fwd_sum / n, up_sum / n, right_sum / n])
	ok(kit.hose.emitted > 0, "the stream ran (%d puffs)" % kit.hose.emitted)
	for f in 40:
		_frame(m, P)
	var jet := kit.jet
	ok(jet.start(), "Flue Flight lifts off")
	var spread := 0.0
	var heels_low := true
	var tail_behind := true
	var jet_y := 0.0
	var puffs := kit.hose.emitted
	var fr := 0
	while jet.running() and fr < 200:
		_frame(m, P)
		fr += 1
		if fr < 30:
			continue
		var hv := HeroVfx.of(m)
		var heels := [hv.anchor_pos(P, "heel_l"), hv.anchor_pos(P, "heel_r")]
		var fwd := Vector3(P.aim_dir().x, 0, P.aim_dir().y)
		for q in heels:
			heels_low = heels_low and (q as Vector3).y - P.pos.y < 0.3
		spread = maxf(spread, (heels[0] as Vector3).distance_to(heels[1]))
		tail_behind = tail_behind and (hv.anchor_pos(P, "tail") - P.pos).dot(fwd) < -0.2
		var sk := P.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		jet_y = maxf(jet_y, sk.get_bone_pose_scale(sk.find_bone("jet.0")).y)
	ok(spread > 0.06, "two jets, one on each heel (%.2f m apart)" % spread)
	ok(heels_low, "the lift burns from her heels (at her feet)")
	ok(tail_behind, "the tail's fire burns behind her")
	ok(jet_y > 2.0, "the clip stretches the heels' flames in flight (x%.1f)" % jet_y)
	ok(kit.hose.emitted == puffs, "no stream of fire runs in flight")
	print("CINDERART_DONE fails=%d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _palm(P: Hunter) -> Vector3:
	return P.anim.hand_r.global_position + Vector3(P.aim_dir().x, 0, P.aim_dir().y) * AshwickKit.PALM_AHEAD
