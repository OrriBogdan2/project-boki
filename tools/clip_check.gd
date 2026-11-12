extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in
## the tri budget and matches its data (tools/clip_data.gd: the clips it names, each move's clip and hold window, the
## idle and stance loops, docs/art/IDLE_AUDIT.md); the kit's time seeks the clip; through all clips the skinned weapon
## stays on its bone and the Gun and Muzzle lie on the blade you see (item 76b); only one weapon is drawn; moves hand
## over with no pop. Never touches the save.

const ClipData := preload("res://tools/clip_data.gd")
const TRI_BUDGET := 15000
const DT := 1.0 / 30.0
const FLINCH_LEGS_M := 0.002   # m: a chip hit on the run may move the legs this far off the unhit run
const FLINCH_ARMS_M := 0.01    # m: and must move the hand at least this far (the flinch shows)
const FX_ON_BLADE := 0.05      # m: the Muzzle may sit this far off the visible tip
const POP := 0.16              # of the Hero's height: how much further a frame may move the hand than the clip does
var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("CLIP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if not WardenClips.data(art_name).has("loco"):      # (no clips yet, as Gil: the rig's poses drive it)
			continue
		n += 1
		_own_model(String(id), art_name)
		await _hero(main, String(id), art_name)
	ok(n > 0, "at least one Hero has clips (%d)" % n)
	print("CLIP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A Hero's own .glb, wearing its clips: a bad merge of WardenGlb falls back to the procedural body in silence.
func _own_model(id: String, art_name: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	var own := WardenGlb.art(id) == art_name and WardenGlb.has_model(id) and bool(m.get_meta("glb", false))
	ok(own and sync != null and sync.get("clips") != null,
			"%s: its own %s.glb with clips, not the fallback" % [id, art_name])
	m.free()

func _hero(main: Node, id: String, art_name: String) -> void:
	var dd := WardenClips.data(art_name)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	ok(sync != null and sync.get("clips") != null, "%s: wears clips" % id)
	if sync == null or sync.get("clips") == null:
		m.free()
		return
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var tris := 0
	for mi in m.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null or not mesh is ArrayMesh:
			continue
		for si in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	ok(tris > 0 and tris <= TRI_BUDGET, "%s: %d tris, weapon included (budget %d)" % [id, tris, TRI_BUDGET])
	for r in ClipData.rows(id, dd, clips.lib) + ClipData.act_rows(id, dd, clips):
		ok(r[0], r[1])
	# one weapon: the procedural pieces are hidden
	sync.call("_keep_one_weapon")     # (the first frame takes what the build added last: a Mag)
	var shown := 0
	var which := ""
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		# (an emptied Mag draws nothing: HunterAnim still shows it for the reload's motion)
		if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
			shown += 1
			which += " " + String(gun.get_path_to(mi))
	ok(shown == 0, "%s: one weapon drawn (%d procedural pieces showing:%s)" % [id, shown, which])
	_sliders(id, sync)
	_sway(id, m, sync, dd)
	await _on_blade(id, m, sync, clips)
	# "bone_scale" (item 137): the size holds over every clip that keys the bone
	for nm in dd.get("bone_scale", {}):
		var sk := WardenGlb.skeleton(m.get_node("Warden"))
		var want := float(dd["bone_scale"][nm])
		ok(absf(sk.get_bone_pose_scale(WardenSkeleton.find(sk, String(nm))).y - want) < 0.001,
				"%s: %s holds its size %.2f over the clips" % [id, nm, want])
	await _handover(id, m, sync, clips, dd)
	m.free()
	await _flinch(id)

## A body on a spring (data "sway") lags a change of speed, leans away from it, and settles.
func _sway(id: String, m: Node3D, sync: Node, dd: Dictionary) -> void:
	var sw: WardenSway = sync.get("sway")
	if not dd.has("sway"):
		return
	ok(sw != null, "%s: sways on its spring" % id)
	if sw == null:
		return
	sw.step(DT)
	for i in 6:
		m.position.z -= 0.15 * (i + 1)
		sw.step(DT)
	var peak := sw.lean.y
	for i in 240:
		sw.step(DT)
	ok(peak > 0.03 and sw.lean.length() < 0.01, "%s: accelerating forward leans it back (%.3f rad), then settles (%.4f)"
			% [id, peak, sw.lean.length()])
	m.position = Vector3.ZERO

## Through every clip the Gun and Muzzle follow the blade, and the blade keeps its length on the hand. A blade tip
## that a floating companion carries (Meeko's sun circles her, off its bone) keeps its place on that companion instead.
func _on_blade(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var tip := sync.get("blade_tip") as Node3D
	var muzzle := sync.get("muzzle") as Node3D
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hb := int(sync.get("blade_bone"))
	var rest := tip.position.length()
	var carrier: WardenCompanions.Part = null
	var floating := sync.get("companions") as WardenCompanions
	for part: WardenCompanions.Part in (floating.parts if floating else []):
		for an in part.anchors:
			if an[0] == tip:
				carrier = part
				rest = (an[1] as Vector3).length()
	var far := 0.0
	var drift := 0.0
	var n := 0
	for nm in clips.lib.get_animation_list():
		var length := clips.lib.get_animation(nm).length
		for i in 4:
			clips.force = {"clip": String(nm), "t": length * (i + 0.5) / 4.0}
			for k in 3:
				sync.call("_process", DT)
			await holder.get_tree().process_frame
			var sees: Vector3 = sk.global_transform * (sk.get_bone_global_pose(hb) * tip.position)
			far = maxf(far, muzzle.global_position.distance_to(sees))
			var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
			# (a weapon that grows and shrinks on its bone, Motley's orb, keeps its point)
			var body_k := absf((sk.global_transform.basis * sk.get_bone_global_pose(hb).basis).get_scale().x)
			if carrier:
				hand = carrier.node.global_position
				body_k = absf(sk.global_transform.basis.get_scale().x)
			drift = maxf(drift, absf(hand.distance_to(sees) / body_k - rest))
			n += 1
	clips.force = {}
	ok(far <= FX_ON_BLADE, "%s: the Muzzle stays on the visible tip in %d frames (worst %.3f m)" % [id, n, far])
	ok(drift <= 0.02, "%s: the blade never leaves the hand (worst drift %.3f m)" % [id, drift])

## The clips keep rotations only on the contract bones, so MantleLook's sliders (bone offsets) stay on under them; and
## the death state has its time on screen.
func _sliders(id: String, sync: Node) -> void:
	var clips: WardenClips = sync.get("clips")
	var strays := 0
	var sk := clips.skel
	var offsets: Array = clips.d.get("offset_bones", [])      # (Motley's hips ride the spring: the clips move them)
	var names: Array = []
	for b in WardenGlb.BONES:
		if b != "root" and WardenSkeleton.find(sk, b) >= 0:
			names.append(sk.get_bone_name(WardenSkeleton.find(sk, b)))
	for nm in clips.lib.get_animation_list():
		var a := clips.lib.get_animation(nm)
		for i in a.get_track_count():
			var bn := String(a.track_get_path(i).get_concatenated_subnames())
			if a.track_get_type(i) != Animation.TYPE_ROTATION_3D and bn in names and not bn in offsets:
				strays += 1
	ok(strays == 0, "%s: no clip keys a contract bone's offset (%d tracks), the sliders stay on" % [id, strays])
	ok((sync.get("look_pose") as Array).size() >= 10, "%s: the look's bone offsets are held under the clips" % id)
	var stays := float(sync.get("root").get_meta(WardenClips.DEATH_T, 0.0))
	ok(not (clips.d.get("states", {}) as Dictionary).has("dead") or stays > 0.0,
			"%s: a knocked-out Hero stays on screen for its death clip" % id)

## Moves handed over as the game does, the state fed frame by frame. A strike is meant to snap, so a pop is the hand
## moving further in a frame than the clip alone moves it there: that excess stays small against the Hero's height.
func _handover(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var moves: Dictionary = dd.get("kmoves", {})
	var seq: Array = [["", 0.4]]
	seq.append_array(dd.get("flow", []))
	seq.append(["", 0.4])
	var own := {}
	for st in seq:
		if st[0] == "" or own.has(st[0]):
			continue
		var clip := String(moves[st[0]]["clip"])
		clips.force = {"clip": clip, "t": 0.0}
		for k in 10:
			sync.call("_process", DT)
		await holder.get_tree().process_frame
		var path: Array = []
		var t := 0.0
		var last_p := hand.global_position
		while t < float(st[1]):
			clips.force = {"clip": clip, "t": minf(t, clips.lib.get_animation(clip).length - 0.001)}
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			path.append(hand.global_position.distance_to(last_p))
			last_p = hand.global_position
			t += DT
		own[st[0]] = path
	clips.force = {}
	var s := {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var last := Vector3.INF
	var worst := 0.0
	var where := ""
	for st in seq:
		var t := 0.0
		var i := 0
		while t < float(st[1]):
			s["kmove"] = st[0]
			s["kmove_t"] = t
			# (a move that turns its side to the way he goes is fed that facing)
			s["face"] = float(moves.get(st[0], {}).get("heading_off", 0.0))
			if st[0] == "":
				s.erase("kmove")
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			var p := hand.global_position
			if last != Vector3.INF and clips.proc_w <= 0.0 and own.has(st[0]):
				var path: Array = own[st[0]]
				var clip_step := 0.0
				for j in range(maxi(i - 2, 0), mini(i + 3, path.size())):      # (a frame or two either way: the fade)
					clip_step = maxf(clip_step, float(path[j]))
				var over := p.distance_to(last) - clip_step
				if over > worst:
					worst = over
					where = "%s @%.2f" % [st[0], t]
			last = p
			t += DT
			i += 1
	var height := 1.6 * absf(m.scale.y)
	ok(worst <= POP * height, "%s: moves hand over without a pop (worst %.3f m over the clip's own, %s; limit %.3f)"
			% [id, worst, where, POP * height])
	ok(clips.proc_w <= 0.0, "%s: the clips own the body after the run" % id)
	s["kmove"] = "no_such_move"
	for k in 12:
		sync.call("_process", DT)
	ok(clips.proc_w >= 1.0, "%s: a move with no clip hands back to the rig" % id)

## A hit mid-run (item: additive flinch): the legs run exactly as they would unhit, the spine and arms flinch on top;
## standing still, or a stagger, takes the whole body. Two identical models run the same 1 s, one of them hit.
func _flinch(id: String) -> void:
	var calm := await _run_hit(id, 99.0, 1.0, 4.0)
	var hit := await _run_hit(id, 0.0, 1.0, 4.0)
	ok(calm.size() > 0 and hit.size() == calm.size(), "%s: flinch run recorded (%d frames)" % [id, calm.size()])
	var legs := 0.0
	var arms := 0.0
	for i in mini(calm.size(), hit.size()):
		legs = maxf(legs, absf(float(hit[i]["legs"]) - float(calm[i]["legs"])))
		arms = maxf(arms, float(hit[i]["hand"].distance_to(calm[i]["hand"])))
	ok(legs <= FLINCH_LEGS_M, "%s: a hit mid-run leaves the legs on the run (foot slide off by %.4f m, limit %.3f)"
			% [id, legs, FLINCH_LEGS_M])
	ok(arms >= FLINCH_ARMS_M, "%s: a hit mid-run flinches the arms (hand moves %.3f m, min %.3f)"
			% [id, arms, FLINCH_ARMS_M])
	var still := await _run_hit(id, 0.0, 1.0, 0.0)
	var stagger := await _run_hit(id, 0.0, Oomph.HEAVY_FLINCH, 4.0)
	var mid := hit.size() / 3
	ok(float(still[mid]["act"]) > 0.5, "%s: a hit standing still takes the whole body" % id)
	ok(float(stagger[mid]["act"]) > 0.5, "%s: a stagger on the run takes the whole body" % id)
	ok(float(hit[mid]["act"]) <= 0.0, "%s: a chip hit on the run leaves the body to the legs" % id)

## 1 s of play at `speed` m/s, hit at the start (hit_t 99: none); per frame: leg bone sum, right hand, act_w.
func _run_hit(id: String, hit_t: float, hit_k: float, speed: float) -> Array:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var s := {"vel": Vector3(0, 0, -speed), "face": 0.0, "grounded": true, "hit_t": 99.0, "hit_k": hit_k,
			"hit_dir": Vector2(0, -1)}
	m.set_meta(WardenClips.STATE, s)
	for k in 30:
		sync.call("_process", DT)
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var out: Array = []
	var t := 0.0
	while t < 1.0:
		s["hit_t"] = t if hit_t < 1.0 else 99.0
		sync.call("_process", DT)
		await holder.get_tree().process_frame
		var legs := 0.0
		for b in ["thigh.L", "thigh.R", "shin.L", "shin.R"]:
			var o := sk.get_bone_global_pose(WardenSkeleton.find(sk, b)).origin
			legs += o.x * 1.0 + o.y * 3.0 + o.z * 7.0
		out.append({"legs": legs, "hand": hand.global_position, "act": clips.act_w})
		t += DT
	m.free()
	return out
