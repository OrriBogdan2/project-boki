extends RefCounted
## --bench-ab-ground for --bench-fight (tools/perf_fight.gd): the GPU cost of the ground's and the sea's pixels, read
## inside ONE run so pod load and the fight's own variation cancel (separate runs on a shared pod spread 2-9 ms).
## The fight cycles four variants in blocks of BLOCK frames; the GPU time of every frame after SKIP warm-up frames
## of a block (the renderer's stamps arrive a frame or two late) goes to that variant:
##   old    the terrain's full fine detail everywhere (the look before the cut), sea shown
##   cut    the terrain skips its fine detail past 14-36 m (shaders/terrain.gdshader detail_range), sea shown
##   bake   full fine detail (as old) with the big patterns read from the per-map bake (ground_bake.gd, use_bake)
##   flat   the terrain returns its base colour (flat_ground), sea shown
## (the cloud sea hidden measured -0.29 ms on 11-24, docs/PERF_DRAW_1124.md; the sea list stays for shots)
## Prints "BENCH ab ground: <variant> gpu <ms> over <n> frames" and the saving of each against old.

const BLOCK := 45
const SKIP := 8
const NAMES := ["old", "cut", "bake", "flat"]
const SHOT_AT := 1100  # first frame of the pictures: each variant 3 frames apart, saved 2 frames after it is set

var mats: Array[ShaderMaterial] = []
var sea: Array[MeshInstance3D] = []
var mode := -1
var gpu_us := [0, 0, 0, 0]
var n := [0, 0, 0, 0]
var since := 0
var shots_dir := ""  # --shots-dir=<dir>: also one picture per variant on neighbouring frames (frames SHOT_AT..)
var root: Node


func _init(root_node: Node, world: Node) -> void:
	root = root_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots_dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var sm := (node as MeshInstance3D).material_override as ShaderMaterial
		if sm == null or sm.shader == null:
			continue
		if sm.shader.resource_path.ends_with("terrain.gdshader") and not mats.has(sm):
			mats.append(sm)
	for node in world.find_children("*", "MeshInstance3D", false, false):
		var sm := (node as MeshInstance3D).material_override as ShaderMaterial
		if sm and sm.shader and sm.shader.resource_path.ends_with("clouds.gdshader"):
			sea.append(node)
	print("BENCH ab ground: %d terrain materials, %d sea planes" % [mats.size(), sea.size()])


## Called once per frame with the frame number: switches the variant at each block start.
func frame(f: int) -> void:
	since += 1
	if shots_dir != "" and f >= SHOT_AT and f < SHOT_AT + 12:
		_shot(f - SHOT_AT)
		return
	if f % BLOCK != 0 and f != SHOT_AT + 12:
		return
	mode = (f / BLOCK) % NAMES.size()
	since = 0
	_apply(mode)


func _apply(i: int) -> void:
	for m in mats:
		m.set_shader_parameter("detail_range", Vector2(14, 36) if i == 1 else Vector2(1e6, 1e6))
		m.set_shader_parameter("use_bake", i == 2 and m.get_shader_parameter("bake0") != null)
		m.set_shader_parameter("flat_ground", i == 3)


## The pictures: variant k is set at k * 3 and saved at k * 3 + 2 (the frame shown is the one drawn after the set).
func _shot(k: int) -> void:
	since = 0  # (these frames stay out of the GPU averages)
	root.get_tree().paused = k < 11  # (the fight holds still, so the four pictures show the same frame)
	if k % 3 == 0:
		_apply(k / 3)
	elif k % 3 == 2:
		root.get_viewport().get_texture().get_image().save_png("%s/ab_%s.png" % [shots_dir, NAMES[k / 3]])


func add_gpu(us: int) -> void:
	if mode < 0 or since < SKIP:
		return
	gpu_us[mode] += us
	n[mode] += 1


func report() -> void:
	var baked := mats.filter(func(m): return m.get_shader_parameter("bake0") != null).size()
	print("BENCH ab ground: %d of %d terrain materials baked%s" % [baked, mats.size(), "" if baked else " (WARNING: bake = cut)"])
	var base := 0.0
	for i in NAMES.size():
		var ms: float = gpu_us[i] / 1000.0 / maxi(n[i], 1)
		if i == 0:
			base = ms
		print("BENCH ab ground: %s gpu %.3f ms over %d frames (%+.3f vs old)" % [NAMES[i], ms, n[i], ms - base])
