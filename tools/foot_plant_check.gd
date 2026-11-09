extends RefCounted
## --foot-plant-check: feet on the terrain (FootPlant). Every Hunter stands and walks in place on a flight of stairs
## (the slope) and at its foot (the tier step: one foot on the flat, one on the flight), three times over in step:
## on flat ground (the clip as keyed), on the terrain with planting off, and with it on. Per frame the weight-bearing
## ankle's height over the ground under it is held against the flat twin's: on, within TOL; off, the clip floats or
## sinks by more (the case planting fixes), and off leaves the pose exactly the clip's. One Hunter is run on the
## procedural body too (the rig nodes' IK). Works headless. --foot-plant-shots --shots-dir=<dir>: per Hunter
## <id>.png, the four poses side on, planting off (top row) and on (bottom row). Never touches the save.

const DT := 1.0 / 60.0
const SETTLE := 30             # frames before measuring: planting eases in at FootPlant.RATE, a walk gets going
const SAMPLES := 60            # frames measured per pose (a walk: about two strides)
const WALK := 1.5              # m/s: a walk up the flight (the flat twin walks as far on the flat)
const TOL := 0.035             # m: a planted ankle may sit this far off the flat clip's height over the ground
const SHOWS := 0.01            # m: off, the slope stand must miss by more than this (or the setup shows nothing)
const DOWN := 0.02             # m: the flat twin's lower ankle within this of its lowest is a planted foot (scored)
const CELL := 6                # tiles per pose: flat, flat, a two-tile flight (rising +x), the upper tier
const POSES := [["slope stand", 2.5, 0.0], ["slope walk", 2.1, WALK], ["step stand", 1.97, 0.0],
	["step walk", 0.9, WALK]]     # [name, x in its cell where it starts (tiles), speed]
const SHOT_DIST := 6.0         # m: the side-on camera from the figure
const PROCEDURAL := "gunslinger"   # also run on the procedural body (Settings: Warden models off)

var bad := 0
var tree: SceneTree
var holder: Node3D
var world: World
var cam: Camera3D

func ok(cond: bool, what: String) -> void:
	print("FOOT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, mode: String = "check") -> void:
	Save.no_write = true
	tree = main.get_tree()
	holder = Node3D.new()
	main.add_child(holder)
	world = _world()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	if mode == "shots":
		_stage()
		DirAccess.make_dir_recursive_absolute(out)
	for id in Arch.ids():
		await _hero(String(id), out if mode == "shots" else "")
	if mode == "check":
		WardenGlb.set_model(PROCEDURAL, false)
		await _hero(PROCEDURAL, "")
		WardenGlb.set_model(PROCEDURAL, true)
	world.free()
	print("FOOT_PLANT_CHECK_DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

## A strip of cells along x, one per pose (and its flat twin's below at z 3): flat, a flight up +x, the upper tier.
func _world() -> World:
	var w := World.new()
	w.w = CELL * POSES.size()
	w.h = 6
	w.kind.resize(w.w * w.h)
	w.kind.fill(World.T_GROUND)
	w.level.resize(w.w * w.h)
	w.level.fill(0)
	for z in 3:
		for x in w.w:
			w.level[w.idx(x, z)] = [0, 0, 0, 1, 2, 2][x % CELL]
			if x % CELL in [2, 3]:
				w.stairs[w.idx(x, z)] = Vector2i(1, 0)
	return w

func _hero(id: String, out: String) -> void:
	var trio := [_model(id), _model(id), _model(id)]     # flat twin, planting off, planting on
	var glb := bool((trio[0] as Node3D).get_meta("glb", false))
	var tag := id + ("" if glb else " (procedural)")
	var rows: Array = []
	for i in POSES.size():
		var p: Array = POSES[i]
		var x := i * CELL + float(p[1])
		var at := [Vector3(x, 0.0, 4.5), Vector3(x, 0.0, 1.5), Vector3(x, 0.0, 1.5)]
		var anims: Array = []
		for k in 3:
			var m := trio[k] as Node3D
			m.position = at[k]
			m.rotation.y = -PI * 0.5      # facing +x, up the flight
			anims.append(HunterAnim.new(m))
		for f in SETTLE:
			_step(trio, anims, float(p[2]))
		var seen: Array = []          # per frame: [the flat twin's lower ankle's height, off's miss, on's miss]
		var same := true
		for f in SAMPLES:
			_step(trio, anims, float(p[2]))
			var flat: Array = _ankles(trio[0])
			var low := 0 if (flat[0] as Vector3).y < (flat[1] as Vector3).y else 1
			var clip: float = (flat[low] as Vector3).y - (trio[0] as Node3D).position.y
			var row := [clip]
			for k in 2:
				var body := (trio[k + 1] as Node3D).position
				var ank: Vector3 = _ankles(trio[k + 1])[low]
				var g := world.ground_at(ank.x, ank.z)
				var reach := g - body.y > -FootPlant.REACH_DOWN and g - body.y < FootPlant.REACH_UP
				row.append(absf(ank.y - g - clip) if reach else 0.0)
			seen.append(row)
			var off: Array = _ankles(trio[1])
			for sd in 2:
				var mine := (off[sd] as Vector3) - (trio[1] as Node3D).position
				same = same and mine.distance_to((flat[sd] as Vector3) - (trio[0] as Node3D).position) < 0.001
		var lowest := INF
		for r in seen:
			lowest = minf(lowest, float(r[0]))
		var worst := [0.0, 0.0]
		for r in seen:
			if float(r[0]) < lowest + DOWN:
				worst = [maxf(worst[0], float(r[1])), maxf(worst[1], float(r[2]))]
		ok(worst[1] < TOL, "%s %s: planted ankle %.3f m off the clip's height over the ground (off: %.3f)"
				% [tag, p[0], worst[1], worst[0]])
		ok(same, "%s %s: planting off leaves the clip's pose" % [tag, p[0]])
		var sync := (trio[0] as Node3D).get_node_or_null("Warden/Sync")
		if sync and (sync.get("leg_bones") as PackedInt32Array).is_empty():
			ok(worst[1] == worst[0], "%s %s: a hover, its feet left alone" % [tag, p[0]])
		elif p[0] == "slope stand":
			ok(worst[0] > SHOWS, "%s: unplanted, the clip floats or sinks on the flight (%.3f m)" % [tag, worst[0]])
		if out != "":
			rows.append([await _grab(trio, 1), await _grab(trio, 2)])
	for m in trio:
		(m as Node3D).free()
	if out != "":
		_sheet(rows).save_png(out.path_join(id + ".png"))

func _model(id: String) -> Node3D:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 7)
	holder.add_child(m)
	var sync := m.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)      # stepped by hand below, at DT
	return m

## One frame for the three: HunterAnim, the plant (off for the first two), then the .glb's bones.
func _step(trio: Array, anims: Array, speed: float) -> void:
	for k in 3:
		var m := trio[k] as Node3D
		var a := anims[k] as HunterAnim
		m.position.x += speed * DT
		m.position.y = 0.0 if k == 0 else world.ground_at(m.position.x, m.position.z)
		a.update(DT, {"fired": 99.0, "face": m.rotation.y, "grounded": true, "vel": Vector3(speed, 0.0, 0.0)})
		a.feet.plant(a, world, DT, k == 2)
		var sync := m.get_node_or_null("Warden/Sync")
		if sync:
			sync._process(DT)

## Both ankles in world space: the .glb's shin ends, or the rig nodes' on the procedural body.
func _ankles(m: Node3D) -> Array:
	var sk := WardenGlb.skeleton(m.get_node_or_null("Warden"))
	var out: Array = []
	for sd in ["L", "R"]:
		if sk:
			var ank := FootPlant.ankle(sk, sk.find_bone("thigh." + sd), sk.find_bone("shin." + sd))
			out.append(sk.global_transform * ank)
		else:
			var leg := m.get_node("Rig/Legs/Leg" + sd) as Node3D
			out.append((leg.get_parent() as Node3D).global_transform * FootPlant.foot(leg, leg.get_node("Knee")))
	return out

# ==================================================================== shots
func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"), "horizon": Color("ffd2a8"),
		"stars": 0.0})
	holder.add_child(env)
	Look.lights(holder, Color("fff1dc"), 1.0, Vector3(-40, 150, 0), 40.0)
	var mat := Models.toon(Color("4f7a3e"), false)
	for x in world.w:
		var lo := world.ground_at(x + 0.01, 1.5)
		var hi := world.ground_at(x + 0.99, 1.5)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sqrt(1.0 + (hi - lo) * (hi - lo)), 0.4, 3.0)
		slab.mesh = bm
		slab.material_override = mat
		slab.position = Vector3(x + 0.5, (lo + hi) * 0.5 - 0.2, 1.5)
		slab.rotation.z = atan2(hi - lo, 1.0)
		holder.add_child(slab)
	cam = Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	cam.fov = 30.0

## Figure k of the three alone, side on (the others hidden), the frame half size.
func _grab(trio: Array, k: int) -> Image:
	var x := (trio[k] as Node3D).position.x
	for i in 3:
		(trio[i] as Node3D).visible = i == k
	cam.position = Vector3(x, (trio[k] as Node3D).position.y + 1.0, 1.5 + SHOT_DIST)
	for f in 3:
		await tree.process_frame
	var img := tree.root.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return img

## The poses side by side, planting off (top row) over on (bottom row).
func _sheet(rows: Array) -> Image:
	var a := rows[0][0] as Image
	var out := Image.create(a.get_width() * rows.size(), a.get_height() * 2 + 6, false, Image.FORMAT_RGBA8)
	out.fill(Color("1c1a24"))
	for i in rows.size():
		for k in 2:
			var at := Vector2i(a.get_width() * i, (a.get_height() + 6) * k)
			out.blit_rect(rows[i][k], Rect2i(Vector2i.ZERO, a.get_size()), at)
	return out
