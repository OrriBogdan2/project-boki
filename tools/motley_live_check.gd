extends RefCounted
## --motley-live-check: Motley's jack-in-the-box through the real match code (Match, Hunter.render, HunterAnim, Sync).
## He wears his clips; he floats a hand's width off the ground; running tilts the box, sways the body and never steps;
## the dash compresses the spring (the hips come down) and arriving starts inside the box; a knock-out plays the death
## clip on screen. Never touches the save.

const DT := 1.0 / 60.0

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	var sync: Node = h.model.get_node("Warden/Sync")
	sync.set_process(false)
	if h.visible or h.out:
		sync.call("_process", DT)

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("ostra", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	for f in 30:
		_frame(m, P)
	var sync: Node = P.model.get_node("Warden/Sync")
	var c: WardenClips = sync.get("clips")
	ok(c != null, "Motley wears his clips in a match")
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	ok(WardenSkeleton.find(sk, "x_weapon") < 0 and P.model.get_node("Warden").find_child("weapon", true, false) == null,
			"item 136: no weapon on his model")
	for an in ["anchor_hand_r", "anchor_hand_l", "anchor_cards"]:
		ok(WardenGlb.anchor(P.model, an) != null, "%s rides his hand" % an)
	ok(VoidCard.make() != null, "the void card builds")
	var maps := 0
	for mi in P.model.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in (mesh.get_surface_count() if mesh else 0):
			var sm := (mi as MeshInstance3D).get_active_material(si) as ShaderMaterial
			if sm and sm.get_shader_parameter("use_nrm") and sm.get_shader_parameter("normal_tex") != null:
				maps += 1
	ok(maps > 0, "his normal map reaches the shader, use_nrm (%d surfaces)" % maps)
	var hips := sk.find_bone("hips")
	var box := WardenSkeleton.find(sk, "x_box")
	var root_y := sk.get_bone_global_pose(sk.find_bone("root")).origin.y
	ok(root_y > 0.08 and root_y < 0.25, "the box floats a hand's width off the ground (%.3f model m)" % root_y)
	var hips_y := sk.get_bone_global_pose(hips).origin.y - root_y
	var idle_box := sk.get_bone_pose_rotation(box)
	# running: the box tilts, the body lags, no foot ever comes down
	var tilt := 0.0
	var lean := 0.0
	var steps := 0
	for f in 90:
		P.inp["move"] = Vector2(0, -1)
		_frame(m, P)
		tilt = maxf(tilt, sk.get_bone_pose_rotation(box).angle_to(idle_box))
		var sw: WardenSway = sync.get("sway")
		lean = maxf(lean, sw.lean.length())
		if P.anim.stepped:
			steps += 1
	ok(tilt > 0.1, "running tilts the box (%.2f rad)" % tilt)
	ok(lean > 0.02, "the body sways on the spring (%.2f rad)" % lean)
	ok(steps == 0, "no footsteps (%d)" % steps)
	P.inp["move"] = Vector2.ZERO
	for f in 40:
		_frame(m, P)
	# the dash: the spring compresses, then he arrives from inside the box
	P.ak.play("ostra_swap_aim")
	var low := 9.0
	for f in 40:
		_frame(m, P)
		low = minf(low, sk.get_bone_global_pose(hips).origin.y - sk.get_bone_global_pose(sk.find_bone("root")).origin.y)
	ok(low < hips_y - 0.1, "aiming the dash compresses the spring (%.3f to %.3f)" % [hips_y, low])
	P.ak.play("ostra_arrive")
	var inside := 9.0
	for f in 9:          # (the clips crossfade in over 0.1 s)
		_frame(m, P)
		inside = minf(inside, sk.get_bone_pose_scale(hips).x)
	ok(inside < 0.2, "arriving starts down in the box (scale %.2f)" % inside)
	for f in 60:
		_frame(m, P)
	ok(sk.get_bone_pose_scale(hips).x > 0.9, "and he is out again (%.2f)" % sk.get_bone_pose_scale(hips).x)
	# the cards tumble round him, and none passes over the face
	var grin := WardenGlb.anchor(P.model, "anchor_grin")
	var pivots: Array = (sync.get("orbits") as WardenGlb.Orbits).pivots
	var nearest := 9.0
	var cam_off := Vector3(0.0, 0.25, -5.0).normalized()      # (the viewer, straight in front and a little above)
	for f in 400:
		_frame(m, P)
		var fwd := -P.model.global_basis.z
		var eye := grin.global_position + (fwd + Vector3.UP * 0.05 + cam_off * 0.0).normalized()
		for pv in pivots:
			for pr in pv[2]:
				var at: Vector3 = (pr[0] as Node3D).global_position
				if (at - grin.global_position).dot(fwd) > 0.0:
					var line := (eye - grin.global_position).normalized()
					var off := (at - grin.global_position) - line * (at - grin.global_position).dot(line)
					nearest = minf(nearest, off.length())
	ok(nearest > 0.2, "no card passes over the face (closest %.2f m off its line of sight)" % nearest)
	# a knock-out
	P.lives = 1
	m.eliminate(P, r[2], "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or c.cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out plays the death clip on screen (clip %s, visible %s)"
			% [dead_seen, was_visible])
	print("MOTLEY_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
