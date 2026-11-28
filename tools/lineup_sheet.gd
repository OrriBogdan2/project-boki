extends "res://tools/facing_check.gd"
## --lineup-sheet --shots-dir=<dir> [--cell=880x960] [--span=4.8] [--idle-t=1.0] [--hunters=Vex,Kael]: one shot per
## Hunter for the owner's lineup and size sheets (the python side: boki-tools `hunter-lineup`). Every Hunter is built
## the way the match builds it (Models.hunter, the facing table of --facing-check: HUNTERS and the match's face rule),
## drawn at the match's size (Hunter.VIS_SCALE: 1.12 x camera.json match_hunter_scale), the same held idle frame
## (not the bind pose), turned to face the camera, in the same orthographic camera: every shot has the same px per
## metre and the feet on the same row, so heights read straight across. Writes <dir>/cell_<Name>.png and
## <dir>/lineup.json (camera, and per Hunter: facing error at the camera aim and at the four --facing-check aims,
## body height without props, with props, head anchor, width, glb path, triangles). Exits 1 when a Hunter does not face
## the camera (the --facing-check limit). Needs a renderer.

const Measure := preload("res://tools/lineup_shot.gd")
const CAM_DIST := 23.0  # m from the Hunters: the match camera's distance, so far-distance ink and rim read as in game
const BG := Color("dcdde3")  # plain backdrop (the python side draws the ground line and the metre rules)
const SYNC_STEPS := 12  # frames the idle is stepped at the held time (the clip's blend settles)

var span := 4.8  # m of height the ortho camera covers; the feet sit 0.2 m above the bottom edge
var cell := Vector2i(880, 960)
var idle_t := 1.0  # s into the idle clip, the same for every Hunter


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var only := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		elif a.begins_with("--cell="):
			var wh := a.substr(7).split("x")
			cell = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--span="):
			span = float(a.substr(7))
		elif a.begins_with("--idle-t="):
			idle_t = float(a.substr(9))
		elif a.begins_with("--hunters="):
			only = a.substr(10).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = cell
	main.get_viewport().size = cell
	_stage(main)
	_backdrop()
	var rows := []
	var bad := 0
	for h in HUNTERS:
		if not only.is_empty() and not only.has(h[0]):
			continue
		var row := await _one(h[0], h[1], out)
		bad += 0 if row["ok"] else 1
		rows.append(row)
		var verdict := "ok" if row["ok"] else "BACKWARDS"
		print(
			"LINEUP_SHEET %s %s head %.2f body %.2f all %.2f facing %.1f %s"
			% [row["name"], row["id"], row["head_m"], row["body_m"], row["all_m"], row["facing_deg"], verdict]
		)
	var cam_info := {
		"cell": [cell.x, cell.y],
		"span_m": span,
		"feet_m_from_bottom": 0.2,
		"scale": Hunter.VIS_SCALE,
		"match_hunter_scale": CamRig.match_hunter_scale,
		"idle_t": idle_t,
	}
	var f := FileAccess.open(out.path_join("lineup.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"cam": cam_info, "rows": rows}, "\t"))
	print("LINEUP_SHEET_DONE %d hunters, %d not facing the camera" % [rows.size(), bad])
	tree.quit(1 if bad > 0 else 0)


## One Hunter: measures its facing, holds the idle frame, shoots it, returns its row.
func _one(nm: String, id: String, out: String) -> Dictionary:
	var model := await _spawn(id, FRONT_FACE)
	var errs := []
	for deg: float in AIMS_DEG:
		var aim := Vector2(sin(deg_to_rad(deg)), cos(deg_to_rad(deg)))
		model.rotation.y = atan2(-aim.x, -aim.y)  # (the match's face rule)
		errs.append(_error_deg(model, aim))
	model.rotation.y = FRONT_FACE
	var cam_err := _error_deg(model, Vector2(0.0, 1.0))  # the camera is at +Z
	var worst := absf(cam_err)
	for e: float in errs:
		worst = maxf(worst, absf(e))
	model.scale *= Hunter.VIS_SCALE
	var sync := model.get_node_or_null("Warden/Sync")
	if sync:
		sync.set_process(false)
		var clips: WardenClips = sync.get("clips")
		for k in SYNC_STEPS:
			clips.force = {"clip": "idle", "t": idle_t}
			sync.call("_process", 1.0 / 30.0)
			await tree.process_frame
	var meter := Measure.new()
	var body: Vector3 = meter.skinned_top(model, true, false, id)
	var all: Vector3 = meter.skinned_top(model, false, false, id)
	var anchor := WardenGlb.anchor(model, "anchor_head_top")
	_cam_ortho()
	await _grab(out.path_join("cell_%s.png" % nm))
	var row := {
		"name": nm,
		"id": id,
		"facing_deg": absf(cam_err),
		"facing_worst_deg": worst,
		"ok": worst <= MAX_ERR_DEG,
		"body_m": body.y,
		"all_m": all.y,
		"head_m": anchor.global_position.y - model.global_position.y if anchor else -1.0,
		"width_m": all.x,
		"scale_y": model.scale.y,
		"glb": WardenGlb.path(id),
		"tris": _tris(model),
	}
	model.queue_free()
	await tree.process_frame
	return row


## The shared camera: orthographic, level, `span` m tall with the feet 0.2 m above the bottom edge.
func _cam_ortho() -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = span
	cam.near = 1.0
	cam.far = 60.0
	cam.position = Vector3(0.0, span * 0.5 - 0.2, CAM_DIST)
	cam.rotation = Vector3.ZERO


## Plain backdrop, no ground (the sheet draws the ground line).
func _backdrop() -> void:
	for n in holder.get_children():
		if n is WorldEnvironment:
			n.environment.background_mode = Environment.BG_COLOR
			n.environment.background_color = BG
		elif n is MeshInstance3D:
			n.visible = false


## Triangles of the visible meshes (the ring excluded).
func _tris(model: Node3D) -> int:
	var n := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var ring := String(model.get_path_to(m)).begins_with("TeamRing")
		if not m.is_visible_in_tree() or not m.mesh is ArrayMesh or ring:
			continue
		for s in m.mesh.get_surface_count():
			n += int((m.mesh as ArrayMesh).surface_get_array_index_len(s) / 3.0)
	return n
