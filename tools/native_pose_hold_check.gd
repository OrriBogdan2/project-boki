extends RefCounted
## --native-pose-hold-check: a Hunter on Meshy's own skeleton (WardenNative) holds its clips on a frame its Hunter
## skipped the pose (SimLod.pose_every, WardenGlb.POSE_HELD) and catches up the held time on the next posed frame, as
## the contract rig (WardenGlb.Sync) does; its held gun still follows the hand while the body moves. Headless, no
## renderer; never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("NATIVEPOSEHOLD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	WardenNative.contract_only = false
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	var nat: WardenNative = null
	for h in m.hunters:
		var n: Node = h.model.get_node_or_null("Warden/Native") if h.model else null
		if n is WardenNative:
			nat = n
			break
	ok(nat != null, "setup: a Hunter on Meshy's own skeleton")
	if nat == null:
		main.get_tree().quit(1)
		return
	nat.set_process(false)  # (stepped by hand below)
	var now := Engine.get_process_frames()
	nat.root.set_meta(WardenGlb.POSE_HELD, -1)
	nat._process(Match.DT)  # (the first posed frame picks a clip)
	var at0 := nat.player.current_animation_position
	nat.root.set_meta(WardenGlb.POSE_HELD, now)
	nat._process(Match.DT)
	nat.root.global_position += Vector3(1.0, 0.0, 0.0)  # (the body moves on a held frame)
	nat._process(Match.DT)
	ok(is_equal_approx(nat.pose_held_t, 2.0 * Match.DT), "held frames add up the time")
	ok(is_equal_approx(nat.player.current_animation_position, at0), "held frames leave the clip where it was")
	if nat.gun and nat.gun.is_inside_tree() and nat.hand >= 0:
		ok(nat.gun.global_position.is_equal_approx(nat.hand_position()), "the gun follows the hand on a held frame")
	nat.root.set_meta(WardenGlb.POSE_HELD, -1)
	nat._process(Match.DT)
	ok(nat.pose_held_t == 0.0, "the next posed frame spends the held time")
	ok(not is_equal_approx(nat.player.current_animation_position, at0), "and the clip moves on")
	print("NATIVEPOSEHOLD done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
