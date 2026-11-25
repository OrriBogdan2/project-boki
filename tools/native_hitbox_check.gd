extends RefCounted
## --native-hitbox-check (docs/art/wardens/MESHY_NATIVE.md "Size"): each Hunter on Meshy's own skeleton is drawn at the
## size that puts Meshy's head bone on the rig's head pivot, while the hit ring and hurtbox are the archetype's
## (body.hit_r, body.hit_h). This measures the visible body at idle, as a match draws it (Hunter.VIS_SCALE, Ostra's
## hover), against them: height vs hit_h (plus the headwear the owner's height chart allows over the head), shoulder
## width and reach vs the hit ring, where the feet plant. Fails when a Hunter's height is off by more than TOL or its
## feet are off the ground (but Ostra's hover); the other columns are printed for the report (NATIVE_HITBOX rows).

const TOL := 0.10  # share: the body's height may differ from the chart's height (hit_h, headwear allowed) by this much
const CHART := "res://tools/warden_model_check.gd"  # the owner's height chart: WARDENS[arch] height, height_3d
const FEET_TOL := 0.06  # m: the lowest vertex stands this close to the ground
const SHOULDER_BAND := 0.06  # share of the body height either side of the shoulders where the width is read

# Parts hung on the body that are no part of it (WardenProps' weapon, orbits, Meeko's companions): left out.
const PROP_PARTS := ["bone_prop", "bone_orbit", "companion_"]

var bad := 0
var n := 0
var holder: Node3D


func ok(cond: bool, what: String) -> void:
	n += 1
	print("NATIVEHITBOX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	for a in Arch.ids():
		if not WardenNative.on(a):
			continue
		var m := await stand(main, a)
		var r := measure(m, a)
		print(row(a, r))
		ok(absf(r.height / r.want - 1.0) <= TOL, "%s: body %.2f m vs chart height %.2f m" % [a, r.height, r.want])
		ok(absf(r.feet) <= FEET_TOL, "%s: feet at %+.3f m" % [a, r.feet])
		m.queue_free()
	print("NATIVEHITBOX DONE %d checks, %d failed" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## The Hunter's model as the game builds it, idle.
func stand(main: Node, a: String) -> Node3D:
	var m := Models.hunter(Arch.weight(a), Data.TEAM_COLORS[0], Arch.signature(a), "", PlayerLook.neutral(), a)
	holder.add_child(m)
	m.scale *= Hunter.VIS_SCALE  # (as Hunter.fit_scale draws it in a match)
	m.set_meta(WardenClips.STATE, {"grounded": true})
	for k in 3:
		await main.get_tree().process_frame
	return m


## Row, metres as drawn in a match: height (top of the body over the ground), want (hit_h, plus the headwear the chart
## allows over the head), feet (lowest vertex), hover (Ostra's float), shoulder (width at the shoulders), reach (the
## farthest any body vertex is from the Hunter's axis), ring (hit_r + Match.HIT_SLACK, the hurtbox circle's radius).
func measure(m: Node3D, a: String) -> Dictionary:
	var hover := KMovesStone.hover(a, 0.0)
	var pts := _points(m)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var reach := 0.0
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
		reach = maxf(reach, Vector2(p.x, p.z).length())
	var h := hi.y + hover
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var sh_y := 0.5 * (_bone_y(m, sk, "upper_arm.L") + _bone_y(m, sk, "upper_arm.R"))
	var sx0 := INF
	var sx1 := -INF
	for p in pts:
		if absf(p.y - sh_y) <= SHOULDER_BAND * h:
			sx0 = minf(sx0, p.x)
			sx1 = maxf(sx1, p.x)
	var chart: Dictionary = (load(CHART) as GDScript).get_script_constant_map()["WARDENS"][a]
	var cls: Dictionary = Data.CLASSES[Arch.weight(a)]
	var hit_h := Arch.hit_h(a)
	return {
		"height": h,
		"feet": lo.y,
		"head": _bone_y(m, sk, "head"),
		"shoulder": sx1 - sx0,
		"reach": reach,
		"width": hi.x - lo.x,
		"depth": hi.z - lo.z,
		"hit_h": hit_h,
		"want": hit_h * float(chart.get("height_3d", chart["height"])) / float(chart["height"]),
		"ring": Arch.hit_r(a, cls) + Match.HIT_SLACK,
	}


func row(a: String, r: Dictionary) -> String:
	var body := (
		"height %.2f | hit_h %.2f | want %.2f | %+.0f%% | head bone %.2f | feet %+.2f"
		% [r.height, r.hit_h, r.want, 100.0 * (r.height / r.want - 1.0), r.head, r.feet]
	)
	var ring := (
		"shoulder %.2f | ring %.2f | reach %.2f | %+.0f%% | width %.2f | depth %.2f"
		% [r.shoulder, 2.0 * r.ring, r.reach, 100.0 * (r.reach / r.ring - 1.0), r.width, r.depth]
	)
	return "NATIVE_HITBOX %s | %s | %s" % [a, body, ring]


func _bone_y(m: Node3D, sk: Skeleton3D, bone: String) -> float:
	return (sk.global_transform * sk.get_bone_global_pose(WardenSkeleton.find(sk, bone))).origin.y - m.global_position.y


## Every vertex of the body's visible meshes (the Hunter's model, no ring, weapon, orbits or companions), skinned by
## the skeleton's pose, in metres from the model's origin (the ground under the Hunter).
func _points(m: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		var path := String(m.get_path_to(mesh)).to_lower()
		# (a QuadMesh is a glow billboard: halo, bloom)
		if not mesh.is_visible_in_tree() or mesh.mesh == null or mesh.mesh is QuadMesh or path.contains("ring"):
			continue
		if PROP_PARTS.any(func(w): return path.contains(w)):
			continue
		var skel := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if mesh.skin != null else null
		var xf: Array = []
		if skel:
			for b in mesh.skin.get_bind_count():
				var bone := mesh.skin.get_bind_bone(b)
				if bone < 0:
					bone = skel.find_bone(mesh.skin.get_bind_name(b))
				xf.append(skel.global_transform * skel.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(b))
		for s in mesh.mesh.get_surface_count():
			var arr := mesh.mesh.surface_get_arrays(s)
			if arr[Mesh.ARRAY_VERTEX] == null:
				continue
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var wts := PackedFloat32Array()
			if arr[Mesh.ARRAY_WEIGHTS] != null:
				wts = arr[Mesh.ARRAY_WEIGHTS]
			var per := int(bones.size() / float(maxi(verts.size(), 1)))
			for v in verts.size():
				var pos := mesh.global_transform * verts[v]
				if skel and per > 0 and wts.size() >= bones.size():
					pos = Vector3.ZERO
					for k in per:
						var w := wts[v * per + k]
						if w > 0.0:
							pos += (xf[bones[v * per + k]] as Transform3D) * verts[v] * w
				out.append(pos - m.global_position)
	return out
