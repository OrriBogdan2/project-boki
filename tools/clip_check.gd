extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in
## the tri budget and carries every clip its file names; each keyed move of its kit has a clip as long as the move (the
## timings are the kit's); the kit's time seeks the clip; through all clips the skinned weapon stays on its bone and the
## Gun and Muzzle lie on the blade you see (item 76b); only one weapon is drawn; moves hand over with no pop. Never
## touches the save.

const GLB_CHECK := preload("res://tools/warden_glb_check.gd")     # (its tri budget and the Heroes over it)
const OWN_MODELS := {"archer": "hem", "thief": "sable", "tender": "pip", "gunslinger": "vex", "ashwick": "cinder",
	"mage": "ryzz", "dolm": "tarek", "rimewright": "claire", "dredge": "dredge", "bulwark": "breaker",
	"ostra": "ostra", "juggernaut": "kael"}
const DT := 1.0 / 30.0
## The source footage's beats (docs/hero-ref, 5 fps: a frame is 0.2 s): the clip's strike, the frame the sword hand
## moves fastest, lands in [from, to] s. Kael (juggernaut.md): the slam winds up three frames (0155-0157) and strikes
## at 0158, 0.6 s in (a frame either way); a slash is a frame of wind-up and one of swing, all in 0.4 s; the riposte
## strikes in the frame the guard ends.
const FOOTAGE := {"juggernaut": {"slam": [0.4, 0.8], "slash_r": [0.0, 0.4], "slash_l": [0.0, 0.4],
	"riposte": [0.0, 0.2]}}
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
	for id in OWN_MODELS:
		_own_model(String(id), String(OWN_MODELS[id]))
	var n := 0
	for id in Arch.ids():
		var art_name := WardenGlb.art(String(id))
		if WardenClips.data(art_name).is_empty():
			continue
		n += 1
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
	var cap: int = GLB_CHECK.TRIS_OVER.get(id, GLB_CHECK.TRIS_MAX)
	ok(tris > 0 and tris <= cap, "%s: %d tris, weapon included (budget %d)" % [id, tris, cap])
	var missing: Array = []
	var named: Array = _named(dd)
	for c in named:
		if not clips.lib.has_animation(String(c)):
			missing.append(c)
	ok(missing.is_empty(), "%s: the file's %d clips are in the .glb (missing %s)" % [id, named.size(), str(missing)])
	_timings(id, dd, clips)
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
	await _footage(id, m, sync, clips)
	m.free()

func _named(dd: Dictionary) -> Array:
	var out: Array = []
	for mv in (dd.get("kmoves", {}) as Dictionary).values():
		out.append(mv["clip"])
	var lc: Dictionary = dd.get("loco", {})
	out.append(lc.get("idle"))
	out.append(lc.get("stance"))
	out.append_array((lc.get("walk", {}) as Dictionary).values())
	out.append_array((lc.get("run", {}) as Dictionary).values())
	var cr: Dictionary = dd.get("crouch", {})
	if not cr.is_empty():
		out.append_array([cr["idle"], cr["in"], cr["out"]])
		out.append_array((cr["walk"] as Dictionary).values())
	out.append_array((dd.get("air", {}) as Dictionary).values())
	for k in dd.get("states", {}):
		var v = dd["states"][k]
		if v is String:
			out.append(v)
	return out

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

## Each mapped kit move: its clip lasts as long as the move's keys (a held move: at least to its last key).
func _timings(id: String, dd: Dictionary, clips: WardenClips) -> void:
	var worst := 0.0
	var where := ""
	var moves: Dictionary = dd.get("kmoves", {})
	for km in moves:
		var def := HunterAnim.km_def(String(km))
		if def.is_empty():
			continue
		var end_t := float(def["keys"][-1][0])
		var length := clips.lib.get_animation(String(moves[km]["clip"])).length
		var off := maxf(end_t - length, 0.0) if moves[km].has("hold_from") else absf(length - end_t)
		if off > worst:
			worst = off
			where = "%s, clip %.3f s, keys %.3f s" % [km, length, end_t]
	ok(worst <= 0.034, "%s: every clip lasts as long as its kit move (worst %.3f s, %s)" % [id, worst, where])
	var unmapped: Array = []
	var pre: String = {"juggernaut": "jug_"}.get(id, "")
	for km in KMovesDJ.MOVES:
		if pre != "" and String(km).begins_with(pre) and not moves.has(km):
			unmapped.append(km)
	ok(unmapped.is_empty(), "%s: all its kit moves have a clip (missing %s)" % [id, str(unmapped)])

## Through every clip the Gun and Muzzle follow the blade, and the blade keeps its length on the hand.
func _on_blade(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var tip := sync.get("blade_tip") as Node3D
	var muzzle := sync.get("muzzle") as Node3D
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var hb := int(sync.get("blade_bone"))
	var rest := tip.position.length()
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

## Each footage-timed clip strikes on the source's frame (FOOTAGE).
func _footage(id: String, m: Node3D, sync: Node, clips: WardenClips) -> void:
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var beats: Dictionary = FOOTAGE.get(id, {})
	for clip in beats:
		var length := clips.lib.get_animation(String(clip)).length
		clips.force = {"clip": String(clip), "t": 0.0}
		for k in 10:      # (settled on its first pose: not the jump from the clip before)
			sync.call("_process", DT)
		await holder.get_tree().process_frame
		var last := Vector3.INF
		var peak := [0.0, -1.0]
		var t := 0.0
		while t < length:
			clips.force = {"clip": String(clip), "t": t}
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			if last != Vector3.INF and hand.global_position.distance_to(last) > peak[0]:
				peak = [hand.global_position.distance_to(last), t - DT * 0.5]
			last = hand.global_position
			t += DT
		var win: Array = beats[clip]
		ok(peak[1] >= float(win[0]) and peak[1] <= float(win[1]), "%s: %s strikes at %.2f s (the footage: %.1f-%.1f s)"
				% [id, clip, peak[1], float(win[0]), float(win[1])])
	clips.force = {}

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
