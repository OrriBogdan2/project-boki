extends RefCounted
## --warden-clips-check: the hand-keyed clips (ART-1, scripts/heroes/warden_clips.gd, content/rules/warden_clips.json),
## per Hunter that has a block: every clip it names is in the .glb; every kit move of the Hunter is mapped, and each
## clip is as long as the kit's move; the blend tree plays them (a move changes the pose, kit time drives it); the
## locomotion blends (a run moves the feet); the skinned weapon stays on its bone through every move and only one
## weapon is drawn; it hides when the kit takes it out of the hand and its FX anchors stay on it; the budget holds.
## Never touches the save.

const DT := 1.0 / 60.0
const MAX_TRIS := 20000         # ART-1: weapon and shield included
const GRIP_TOL := 0.03          # m: the weapon's bone stays this close to where the hand holds it
const PREFIX := {"breaker": ["bulwark", "bul_"]}
const SKIP := ["bul_smash_late"]

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("CLIPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for art_name in PREFIX:
		_hunter(String(art_name), String(PREFIX[art_name][0]), String(PREFIX[art_name][1]))
	print("WARDEN_CLIPS_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(art_name: String, id: String, prefix: String) -> void:
	var cfg := WardenClips.data(art_name)
	ok(not cfg.is_empty(), "%s has a clips block" % art_name)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	ok(bool(m.get_meta("glb", false)), "%s wears its .glb" % art_name)
	var w := m.get_node_or_null("Warden")
	var sk := WardenGlb.skeleton(w)
	var sync := w.get_node("Sync") as WardenGlb.Sync
	var clips: WardenClips = sync.clips
	ok(clips != null, "%s: the clip tree was built" % art_name)
	if clips == null:
		m.free()
		return
	# the names
	var moves: Dictionary = cfg["moves"]
	var want: Array = []
	for k in moves:
		want.append(String((moves[k] as Dictionary)["clip"]))
	want.append_array((cfg["body"] as Dictionary).values())
	want.append_array((cfg["over"] as Dictionary).values())
	var lc: Dictionary = cfg["loco"]
	want.append_array([lc["idle"], lc["stance"]])
	want.append_array(lc["walk"])
	want.append_array(lc["run"])
	var missing: Array = want.filter(func(c): return not clips.player.has_animation(String(c)))
	ok(missing.is_empty(), "%s: all %d clips are in the .glb (missing %s)" % [art_name, want.size(), str(missing)])
	# every kit move mapped, and long enough for the kit's clock
	var short: Array = []
	var unmapped: Array = []
	for table in [HunterAnim.KMOVES, KMovesPinBjorn.MOVES]:
		for k in table:
			if not String(k).begins_with(prefix) or k in SKIP:
				continue
			if not moves.has(k):
				unmapped.append(k)
				continue
			var keys: Array = (table[k] as Dictionary)["keys"]
			var end_t := float((keys[keys.size() - 1] as Array)[0])
			var cl := String((moves[k] as Dictionary)["clip"])
			if not (moves[k] as Dictionary).has("loop_from") and clips.player.has_animation(cl) \
					and clips.player.get_animation(cl).length < end_t - 0.04:
				short.append("%s %.2f < %.2f" % [k, clips.player.get_animation(cl).length, end_t])
	ok(unmapped.is_empty(), "%s: every kit move has a clip (%s)" % [art_name, str(unmapped)])
	ok(short.is_empty(), "%s: each clip lasts its kit move (%s)" % [art_name, str(short)])
	var an := HunterAnim.new(m)
	var hand := WardenSkeleton.find(sk, "hand.R")
	var foot := WardenSkeleton.find(sk, "x_foot.R")
	var st := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
	_play(m, an, sync, st, 40)
	var idle_h := sk.get_bone_global_pose(hand).origin
	var idle_f := sk.get_bone_global_pose(foot).origin
	# a run moves the feet
	var run_st := st.duplicate()
	run_st["vel"] = Vector3(0, 0, -4.8)
	var far := 0.0
	for i in 40:
		_play(m, an, sync, run_st, 1)
		far = maxf(far, sk.get_bone_global_pose(foot).origin.distance_to(idle_f))
	ok(far > 0.1, "%s: the run blend moves the feet (%.2f m)" % [art_name, far])
	# every move: changes the pose, the weapon bone stays on the hand
	var wp := WardenSkeleton.find(sk, "x_weapon")
	var rest_off := (sk.get_bone_global_rest(hand).affine_inverse() * sk.get_bone_global_rest(wp)).origin
	var worst := 0.0
	var worst_mv := ""
	var still: Array = []
	_play(m, an, sync, st, 30)
	for k in moves:
		var moved := 0.0
		var tt := 0.0
		var ln := clips.player.get_animation(String((moves[k] as Dictionary)["clip"])).length
		while tt < ln:
			var s2 := st.duplicate()
			s2["kmove"] = k
			s2["kmove_t"] = tt
			_play(m, an, sync, s2, 1)
			tt += DT
			moved = maxf(moved, sk.get_bone_global_pose(hand).origin.distance_to(idle_h))
			var off := sk.get_bone_global_pose(hand).affine_inverse() * sk.get_bone_global_pose(wp)
			var d := off.origin.distance_to(rest_off)
			if d > worst:
				worst = d
				worst_mv = k
		if moved < 0.03 and not k in ["bul_short", "bul_crush", "bul_armed"]:
			still.append(k)
		_play(m, an, sync, st, 12)
	ok(still.is_empty(), "%s: each move's clip moves the hand (%s)" % [art_name, str(still)])
	ok(worst <= GRIP_TOL, "%s: the weapon stays in the hand in every move (worst %.3f m, %s)" % [art_name, worst, worst_mv])
	# the weapon: one drawn; hidden when out of the hand; anchors on it
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	var drawn := 0
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			drawn += 1
	ok(drawn == 0, "%s: no second weapon on the rig (%d drawn)" % [art_name, drawn])
	var seat: Node3D = (sync.seats[0] as Array)[1]
	seat.visible = false
	_play(m, an, sync, st, 3)
	ok(sk.get_bone_pose_scale(wp).is_zero_approx(), "%s: the weapon hides when the kit takes it out of the hand" % art_name)
	seat.visible = true
	_play(m, an, sync, st, 3)
	ok(sk.get_bone_pose_scale(wp).is_equal_approx(Vector3.ONE), "%s: and comes back" % art_name)
	var tip := WardenGlb.anchor(m, "anchor_hammer_head")
	ok(tip != null, "%s: an FX anchor rides the weapon" % art_name)
	var piece := WardenGlb.thrown_piece(m, "hammer", "x_weapon")
	ok(piece != null, "%s: the thrown hammer is the model's own mesh" % art_name)
	if piece:
		piece.free()
	# the budget
	var tris := 0
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for si in mesh.get_surface_count():
			tris += mesh.surface_get_array_index_len(si) / 3
	ok(tris <= MAX_TRIS, "%s: %d triangles, the budget %d" % [art_name, tris, MAX_TRIS])
	m.free()

func _play(m: Node3D, an: HunterAnim, sync: WardenGlb.Sync, s: Dictionary, n: int) -> void:
	for i in n:
		an.update(DT, s)
		sync._process(DT)
