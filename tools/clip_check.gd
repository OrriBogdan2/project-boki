extends RefCounted
## --clip-check: every Hero with hand-keyed clips (content/rules/warden_anim/<art>.json). Per Hero: the .glb stays in the tri
## budget and carries every clip its file names; each keyed move of its kit has a clip as long as the move (the timings are
## the kit's); the kit's time seeks the clip; through all clips the skinned weapon stays on its bone and the Gun and Muzzle
## lie on the blade you see (item 76b); only one weapon is drawn; moves hand over with no pop. Never touches the save.

const TRI_BUDGET := 20000
const DT := 1.0 / 30.0
const FX_ON_BLADE := 0.05      # m: the Muzzle may sit this far off the visible tip
const POP := 1.0               # m a frame: no teleport across a hand-over (the fastest strikes move 0.5 m a frame on their own)

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
		if WardenClips.data(art_name).is_empty():
			continue
		n += 1
		await _hero(main, String(id), art_name)
	ok(n > 0, "at least one Hero has clips (%d)" % n)
	print("CLIP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

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
	var missing: Array = []
	var named: Array = _named(dd)
	for c in named:
		if not clips.lib.has_animation(String(c)):
			missing.append(c)
	ok(missing.is_empty(), "%s: the file's %d clips are all in the .glb (missing %s)" % [id, named.size(), str(missing)])
	_timings(id, dd, clips)
	# one weapon: the procedural pieces are hidden
	var shown := 0
	var gun := m.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree():
			shown += 1
	ok(shown == 0, "%s: one weapon drawn (%d procedural pieces showing)" % [id, shown])
	await _on_blade(id, m, sync, clips)
	await _handover(id, m, sync, clips, dd)
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
	out.append_array((dd.get("air", {}) as Dictionary).values())
	for k in dd.get("states", {}):
		var v = dd["states"][k]
		if v is String:
			out.append(v)
	return out

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
	ok(worst <= 0.034, "%s: every clip lasts as long as its kit move, to a frame (worst %.3f s, %s)" % [id, worst, where])
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
	var hb := WardenSkeleton.find(sk, "hand.R")
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
			var size := absf(sk.global_transform.basis.get_scale().x)
			drift = maxf(drift, absf(hand.distance_to(sees) / size - rest))
			n += 1
	clips.force = {}
	ok(far <= FX_ON_BLADE, "%s: the Muzzle stays on the visible tip in %d frames (worst %.3f m)" % [id, n, far])
	ok(drift <= 0.02, "%s: the blade never leaves the hand (worst drift %.3f m)" % [id, drift])

## A dash into an ability into the run: states fed as the game does, the hand never jumps.
func _handover(id: String, m: Node3D, sync: Node, clips: WardenClips, dd: Dictionary) -> void:
	var moves: Array = (dd.get("kmoves", {}) as Dictionary).keys()
	var s := {"vel": Vector3(0, 0, -4.0), "face": 0.0, "grounded": true}
	m.set_meta(WardenClips.STATE, s)
	var hand := m.get_node(String(WardenGlb.BONES["hand.R"])) as Node3D
	var last := Vector3.INF
	var worst := 0.0
	var where := ""
	var seq: Array = [["", 0.4]]
	for i in mini(moves.size(), 8):
		seq.append([moves[i], 0.22])
	seq.append(["", 0.4])
	for st in seq:
		var t := 0.0
		while t < float(st[1]):
			s["kmove"] = st[0]
			s["kmove_t"] = t
			if st[0] == "":
				s.erase("kmove")
			sync.call("_process", DT)
			await holder.get_tree().process_frame
			var p := hand.global_position
			if last != Vector3.INF and clips.proc_w <= 0.0 and p.distance_to(last) > worst:
				worst = p.distance_to(last)
				where = "%s @%.2f" % [st[0], t]
			last = p
			t += DT
	ok(worst <= POP, "%s: moves hand over without a pop (worst hand step %.3f m a frame, %s)" % [id, worst, where])
	ok(clips.proc_w <= 0.0, "%s: the clips own the body after the run" % id)
	s["kmove"] = "no_such_move"
	for k in 12:
		sync.call("_process", DT)
	ok(clips.proc_w >= 1.0, "%s: a move with no clip hands back to the rig" % id)
