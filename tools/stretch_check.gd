extends RefCounted
## --stretch-check [--wardens=a,b] [--limit=1.3] [--step=0.125]: skins every visible mesh of each Hero's .glb through
## every one of its clips (the game's own clip tree and Sync) and measures each triangle edge against its rest length.
## No clip may stretch an edge past the limit. Spring chains (spring_*: the game's own physics ropes and cloth)
## are not measured. A bone that grows on all three axes, like Grimble's junk ball, is growth, not stretch:
## the ratio is divided by it. Prints one line per clip and a table per Hero. Never touches the save.

const MIN_EDGE := 0.008          # m: shorter rest edges (seams, welds, chain links) say nothing about stretch
const SETTLE_FRAMES := 12        # frames of DT: the clip fades in (WardenClips.FADE 0.1 s) before it is measured
const DT := 1.0 / 30.0

var tree: SceneTree
var bad := 0
var limit := 1.3
var step := 0.125                # s between samples of a clip
var parts: Array = []            # per skinned mesh: {verts, bones, weights, stride, skin, edges, rest, bind_bones}
var skel: Skeleton3D

func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	var ids: Array = WardenGlb.ART.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(","))
		if a.begins_with("--limit="): limit = float(a.substr(8))
		if a.begins_with("--step="): step = float(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	var holder := Node3D.new()
	main.add_child(holder)
	var table: Array = []
	for id in ids:
		table.append(await _hero(String(id), holder))
	print("STRETCH_TABLE hero | clips | worst ratio | worst clip | clips over %.2f" % limit)
	for r in table:
		print("STRETCH_TABLE %s | %d | %.2f | %s | %d" % r)
	print("STRETCH_DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

func _hero(id: String, holder: Node3D) -> Array:
	WardenGlb.set_model(id, true)
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	for k in 30:
		await tree.process_frame
	var w := m.get_node_or_null("Warden")
	var sync := w.get_node_or_null("Sync") if w else null
	var clips: WardenClips = sync.get("clips") if sync else null
	if clips == null:
		print("STRETCH FAIL %s has no clips" % id)
		bad += 1
		m.queue_free()
		return [id, 0, 0.0, "-", 0]
	sync.set_process(false)         # (stepped by hand, on a fixed dt)
	skel = WardenGlb.skeleton(w)
	_collect(w)
	var worst := 0.0
	var worst_clip := ""
	var over := 0
	var names: Array = Array(clips.lib.get_animation_list())
	for nm in names:
		var r := await _clip(clips, String(nm))
		var ratio := float(r[0])
		var flag := ratio > limit
		print("STRETCH %s %s %s max=%.2f t=%.2f %s" % ["FAIL" if flag else "ok  ", id, nm, ratio, r[1], r[2]])
		over += 1 if flag else 0
		if ratio > worst:
			worst = ratio
			worst_clip = String(nm)
	bad += over
	m.queue_free()
	return [id, names.size(), worst, worst_clip, over]

## Reads each drawn skinned mesh once: its vertices, weights and unique triangle edges longer than MIN_EDGE.
func _collect(glb: Node) -> void:
	parts.clear()
	for mi in glb.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null or inst.skin == null or not inst.is_visible_in_tree():
			continue
		for s in inst.mesh.get_surface_count():
			var arr := inst.mesh.surface_get_arrays(s)
			var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var idx := arr[Mesh.ARRAY_INDEX] as PackedInt32Array
			if arr[Mesh.ARRAY_BONES] == null or idx.is_empty():
				continue
			var binds: Array = []
			for i in inst.skin.get_bind_count():
				var b := inst.skin.get_bind_bone(i)
				binds.append(b if b >= 0 else skel.find_bone(inst.skin.get_bind_name(i)))
			var seen := {}
			var edges := PackedInt32Array()
			var rest := PackedFloat32Array()
			for t in range(0, idx.size(), 3):
				for k in 3:
					var a := idx[t + k]
					var b := idx[t + (k + 1) % 3]
					var key := mini(a, b) * verts.size() + maxi(a, b)
					var d := verts[a].distance_to(verts[b])
					if d >= MIN_EDGE and not seen.has(key):
						seen[key] = true
						edges.append_array([a, b])
						rest.append(d)
			var bones := arr[Mesh.ARRAY_BONES] as PackedInt32Array
			parts.append({"verts": verts, "bones": bones, "weights": arr[Mesh.ARRAY_WEIGHTS],
				"stride": bones.size() / verts.size(), "skin": inst.skin, "edges": edges, "rest": rest, "binds": binds})

## Plays one clip from start to end; returns [worst ratio, its time, a note naming the bones on the worst edge].
func _clip(clips: WardenClips, nm: String) -> Array:
	var sync := skel.get_parent().get_parent().get_node("Sync")
	var length := clips.lib.get_animation(nm).length
	var worst := [0.0, 0.0, ""]
	clips.force = {"clip": nm, "t": 0.0}
	for k in SETTLE_FRAMES:
		sync.call("_process", DT)
		await tree.process_frame
	var t := 0.0
	while t < length + step:
		var tt := minf(t, length - 0.001)
		clips.force = {"clip": nm, "t": tt}
		sync.call("_process", DT)
		for k in 2:
			await tree.process_frame
		var r := _measure()
		if float(r[0]) > float(worst[0]):
			worst = [r[0], tt, r[1]]
		t += step
	clips.force = {}
	return worst

## The largest edge length over its rest length in the pose now: [ratio, "bone>bone"].
func _measure() -> Array:
	var best := 0.0
	var pairs := {}                 # "bone > bone" -> [edges over the limit, their worst ratio]
	for p in parts:
		var skin := p["skin"] as Skin
		var binds: Array = p["binds"]
		var verts := p["verts"] as PackedVector3Array
		var mats: Array = []
		for i in binds.size():
			var bi := int(binds[i])
			mats.append(Transform3D() if bi < 0 else skel.get_bone_global_pose(bi) * skin.get_bind_pose(i))
		var bones := p["bones"] as PackedInt32Array
		var weights := p["weights"] as PackedFloat32Array
		var stride := int(p["stride"])
		var pos := PackedVector3Array()
		var grow := PackedFloat32Array()      # how far all three axes were scaled up at the vertex (1 = not)
		pos.resize(verts.size())
		grow.resize(verts.size())
		for v in verts.size():
			var acc := Vector3.ZERO
			var bas := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
			for k in stride:
				var wt := weights[v * stride + k]
				if wt > 0.0:
					var m := mats[bones[v * stride + k]] as Transform3D
					acc += m * verts[v] * wt
					bas.x += m.basis.x * wt
					bas.y += m.basis.y * wt
					bas.z += m.basis.z * wt
			pos[v] = acc
			grow[v] = maxf(1.0, minf(bas.x.length(), minf(bas.y.length(), bas.z.length())))
		var edges := p["edges"] as PackedInt32Array
		var rest := p["rest"] as PackedFloat32Array
		if not p.has("spring"):
			var flags := PackedByteArray()
			flags.resize(verts.size())
			for v in verts.size():
				flags[v] = 1 if _main_bone(p, v).begins_with("spring_") else 0
			p["spring"] = flags
		var spring := p["spring"] as PackedByteArray
		for e in rest.size():
			if spring[edges[e * 2]] == 1 or spring[edges[e * 2 + 1]] == 1:
				continue
			var ea := edges[e * 2]
			var eb := edges[e * 2 + 1]
			var ratio := pos[ea].distance_to(pos[eb]) / rest[e] / (0.5 * (grow[ea] + grow[eb]))
			best = maxf(best, ratio)
			if ratio > limit:
				var key := "%s>%s" % [_main_bone(p, edges[e * 2]), _main_bone(p, edges[e * 2 + 1])]
				var cur: Array = pairs.get(key, [0, 0.0])
				pairs[key] = [int(cur[0]) + 1, maxf(float(cur[1]), ratio)]
	return [best, _worst_pairs(pairs)]

## The three bone pairs with the most over-limit edges: "a>b x12 (4.2)".
func _worst_pairs(pairs: Dictionary) -> String:
	var keys := pairs.keys()
	keys.sort_custom(func(a, b): return int(pairs[a][0]) > int(pairs[b][0]))
	var out: Array = []
	for k in keys.slice(0, 3):
		out.append("%s x%d (%.1f)" % [k, pairs[k][0], pairs[k][1]])
	return ", ".join(out)

func _main_bone(p: Dictionary, v: int) -> String:
	var stride := int(p["stride"])
	var top := 0
	var top_w := -1.0
	for k in stride:
		var wt := float((p["weights"] as PackedFloat32Array)[v * stride + k])
		if wt > top_w:
			top_w = wt
			top = (p["bones"] as PackedInt32Array)[v * stride + k]
	var bi := int((p["binds"] as Array)[top])
	return skel.get_bone_name(bi) if bi >= 0 else "?"
