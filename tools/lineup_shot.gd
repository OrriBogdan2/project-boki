extends RefCounted
## --lineup-shot --shots-dir=<dir> [--list-meshes]: all 12 Hunters as the game builds them (Models.hunter, same
## loader and scale), idle playing, in one row at true scale on a 1 m grid. Writes <dir>/lineup_front.png (straight
## on), <dir>/lineup_match.png (the match camera's angle and distance) and lineup_match_close.png (same angle, closer),
## and prints each Hunter's measured standing height:
## the skinned bounds of every visible mesh ("all": weapon and props included) and of the body meshes alone ("body":
## meshes whose names say weapon, prop or similar are left out), plus the head-top anchor when the model has one.
## --list-meshes prints every mesh with its own skinned top. Needs a renderer.

const ORDER := ["gunslinger", "juggernaut", "ashwick", "tender", "dolm", "archer", "dredge", "rimewright", "mage",
	"bulwark", "thief", "ostra"]
const GAP := 2.0              # m between Hunters (centre to centre)
const CAM_PITCH := 66.0       # degrees: the default match camera (CamRig STYLES "supervive")
const CAM_DIST := 23.0
const CAM_FOV := 32.0
const SHOT_W := 2560
const SHOT_H := 720
const PROP_WORDS := ["weapon", "prop", "sword", "hammer", "bow", "staff", "gun", "pistol", "shield", "axe", "blade",
	"orb", "wand", "torch", "lance", "scythe", "dagger", "knife", "cannon", "tool", "lantern", "book", "trowel"]

var holder: Node3D
var cam: Camera3D
var tree: SceneTree
var heroes: Array = []

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var list_meshes := OS.get_cmdline_user_args().has("--list-meshes")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	if out == "":
		out = "user://lineup"
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(SHOT_W, SHOT_H)
	main.get_viewport().size = Vector2i(SHOT_W, SHOT_H)
	_stage(main)
	for i in ORDER.size():
		var id: String = ORDER[i]
		var h := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
		h.set_meta("anim_seed", 1)
		h.rotation.y = PI                    # (the export faces -Z: PI turns each to face the camera)
		h.position = Vector3((i - (ORDER.size() - 1) * 0.5) * GAP, 0, 0)
		holder.add_child(h)
		var ring := h.get_node_or_null("TeamRing") as Node3D
		if ring:
			ring.visible = false
		heroes.append(h)
	for k in 30:
		await tree.process_frame       # (past the title's fade, and the models settle)
	var syncs: Array = []
	for h in heroes:
		var sync := (h as Node).get_node_or_null("Warden/Sync")
		syncs.append(sync)
		if sync:
			sync.set_process(false)
			var clips: WardenClips = sync.get("clips")
			if clips:
				clips.force = {"clip": "idle", "t": 0.0}
	await _play(syncs, 12, 0.0)
	await _play(syncs, 1, 1.1)           # (a held idle frame, a little past the first)
	# the table
	print("LINEUP_TABLE id | all_top_m | body_top_m | head_anchor_m | width_m | scale_y | meshes")
	for i in heroes.size():
		var h := heroes[i] as Node3D
		var all := _skinned_top(h, false, list_meshes, ORDER[i])
		var body := _skinned_top(h, true, false, "")
		var anchor := WardenGlb.anchor(h, "anchor_head_top")
		var head := "%.2f" % (anchor.global_position.y - h.global_position.y) if anchor else "-"
		print("LINEUP_ROW %s | %.2f | %.2f | %s | %.2f | %.3f | %d" % [ORDER[i], all.y, body.y, head, all.x,
			h.scale.y, int(all.z)])
	# 1. front: straight on, the whole row
	var span := (ORDER.size() - 1) * GAP + 3.0
	cam.fov = 30.0
	var half_h := atan(tan(deg_to_rad(cam.fov * 0.5)) * float(SHOT_W) / SHOT_H)
	var dist := maxf(span * 0.5 / tan(half_h), 6.0)
	cam.position = Vector3(0, 1.5, dist)
	cam.rotation = Vector3(0.0, 0, 0)
	await _play(syncs, 2, 0.0)
	await _grab(out.path_join("lineup_front.png"))
	print("LINEUP_SHOT ", out.path_join("lineup_front.png"))
	# 2. the match camera's angle
	var p := deg_to_rad(CAM_PITCH)
	var mid := Vector3(0, 1.0, 0)
	cam.fov = CAM_FOV
	cam.position = mid + Vector3(0, sin(p), cos(p)) * CAM_DIST
	cam.rotation = Vector3(-p, 0, 0)
	await _play(syncs, 2, 0.0)
	await _grab(out.path_join("lineup_match.png"))
	print("LINEUP_SHOT ", out.path_join("lineup_match.png"))
	# 3. the same angle, closer (the row filling the frame; the match camera itself keeps them small)
	var near := (ORDER.size() * GAP * 0.5 + 1.0) / (tan(deg_to_rad(CAM_FOV * 0.5)) * float(SHOT_W) / SHOT_H)
	cam.position = mid + Vector3(0, sin(p), cos(p)) * near
	await _play(syncs, 2, 0.0)
	await _grab(out.path_join("lineup_match_close.png"))
	print("LINEUP_SHOT ", out.path_join("lineup_match_close.png"))
	print("LINEUP_SHOT_DONE")
	tree.quit()

## Steps every Hunter's clip sync n times (dt seconds, 1/30 when 0), holding idle.
func _play(syncs: Array, n: int, t: float) -> void:
	for k in n:
		for s in syncs:
			if s:
				var clips: WardenClips = (s as Node).get("clips")
				if clips:
					clips.force = {"clip": "idle", "t": t if t > 0.0 else k / 30.0}
				(s as Node).call("_process", 1.0 / 30.0)
		await tree.process_frame

func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	img.save_png(path)

func _stage(main: Node) -> void:
	holder = Node3D.new()
	main.add_child(holder)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-50, 145, 0), 40.0)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 60)
	ground.mesh = pm
	ground.material_override = Models.toon(Color("4f7a3e"), false)
	holder.add_child(ground)
	_grid()
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()

## A 1 m grid on the ground (thin lines, every 5th darker), 40 m x 8 m around the row.
func _grid() -> void:
	var im := ImmediateMesh.new()
	var thin := StandardMaterial3D.new()
	thin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thin.albedo_color = Color(1, 1, 1, 0.35)
	thin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.surface_begin(Mesh.PRIMITIVE_LINES, thin)
	for x in range(-20, 21):
		im.surface_add_vertex(Vector3(x, 0.01, -4))
		im.surface_add_vertex(Vector3(x, 0.01, 4))
	for z in range(-4, 5):
		im.surface_add_vertex(Vector3(-20, 0.01, z))
		im.surface_add_vertex(Vector3(20, 0.01, z))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	holder.add_child(mi)
	# (a 1 m ruler behind the row: a pole every metre up to 3 m, at the far left, so heights read off the shot)
	var rim := ImmediateMesh.new()
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color("ffffff")
	rim.surface_begin(Mesh.PRIMITIVE_LINES, rm)
	var x0 := -(ORDER.size() * GAP * 0.5) - 0.2
	for z in [-1.2]:
		for hgt in range(0, 4):
			rim.surface_add_vertex(Vector3(x0, hgt, z))
			rim.surface_add_vertex(Vector3(x0 + 0.6, hgt, z))
		rim.surface_add_vertex(Vector3(x0, 0, z))
		rim.surface_add_vertex(Vector3(x0, 3, z))
	rim.surface_end()
	var rmi := MeshInstance3D.new()
	rmi.mesh = rim
	holder.add_child(rmi)

## [width (m), top y above the Hunter's feet (m), mesh count] of the visible meshes' skinned bounds; body_only leaves
## out meshes whose node name says weapon or prop.
func _skinned_top(h: Node3D, body_only: bool, list: bool, id: String) -> Vector3:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var n := 0
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var path := String(h.get_path_to(m))
		if path.begins_with("TeamRing") or path.to_lower().contains("shadow") or path.to_lower().contains("ring"):
			continue
		var low := path.to_lower()
		var prop := false
		for w in PROP_WORDS:
			if low.contains(w):
				prop = true
		if body_only and prop:
			continue
		var bb := _mesh_bounds(m)
		if bb.size == Vector3.ZERO and bb.position == Vector3.ZERO:
			continue
		if list:
			var top := bb.end.y - h.global_position.y
			print("LINEUP_MESH %s %s top=%.2f%s" % [id, path, top, " (prop)" if prop else ""])
		lo = lo.min(bb.position)
		hi = hi.max(bb.end)
		n += 1
	if n == 0:
		return Vector3.ZERO
	return Vector3(hi.x - lo.x, hi.y - h.global_position.y, n)

## A mesh's world bounds as drawn: skinned meshes through their skeleton's current pose (a skinned AABB read off the
## mesh would be the rest pose), others through their transform.
func _mesh_bounds(m: MeshInstance3D) -> AABB:
	var skel := m.get_node_or_null(m.skeleton) as Skeleton3D if m.skin != null else null
	if skel == null:
		return m.global_transform * m.get_aabb()
	var xf: Array = []
	for b in m.skin.get_bind_count():
		var bone := m.skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(m.skin.get_bind_name(b))
		xf.append(skel.global_transform * skel.get_bone_global_pose(bone) * m.skin.get_bind_pose(b))
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for s in m.mesh.get_surface_count():
		var arr := m.mesh.surface_get_arrays(s)
		if arr.size() <= Mesh.ARRAY_WEIGHTS or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights := PackedFloat32Array()
		if arr[Mesh.ARRAY_WEIGHTS] != null:
			weights = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(verts.size(), 1)
		for v in verts.size():
			var pos := Vector3.ZERO
			if per > 0 and weights.size() >= bones.size():
				for k in per:
					var w := weights[v * per + k]
					if w > 0.0:
						pos += (xf[bones[v * per + k]] as Transform3D) * verts[v] * w
			else:
				pos = m.global_transform * verts[v]
			lo = lo.min(pos)
			hi = hi.max(pos)
	if lo.x == INF:
		return AABB()
	return AABB(lo, hi - lo)
