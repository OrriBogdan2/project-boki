extends RefCounted
## --aim-lead-check [--shots-dir=<dir>]: the aim lead on the v2 clips (WardenAimLead). The cursor sweeps 180 degrees
## through a real match at 30 fps while the Hero idles, walks and holds LMB: the head turns off the leg line by up to
## HEAD_MAX, the chest by up to CHEST_MAX (never more), the head leads the chest, nothing jitters, and everything
## settles square once the cursor stops. A full-body clip turns the layer off, and so do a mantle, death and downed.
## With --shots-dir (needs a renderer): one strip per Hero (aim_lead_<art>.png): the sweep seen from above.
## Prints the measured yaw splits (the numbers are the parity measurement). Never touches the save.

const DT := 1.0 / 30.0
const HEROES := ["gunslinger", "bulwark", "archer"]      # Vex, Albert, Lace
const SWEEP := 0.6              # s: the cursor goes through 180 degrees
const TILE := 300               # px: one frame of a strip
const SETTLE := 1.0             # s after the cursor stops
const RING := 8.0               # m: the cursor's distance from the Hero
const LEAD_MIN := 0.3           # rad: the head turns at least this far ahead of the legs in the sweep
const CHEST_MIN := 0.18         # rad: and the chest this far
const OVER := 0.01              # rad: slack over the clamps
const STEP_MAX := 0.3           # rad: the most a split may change in one frame at 30 fps (a pop)
const WIGGLE := 0.01            # rad: a frame-to-frame change this small is not a direction (rounding)
const REVERSALS := 2            # the lead rises, peaks and falls: one turn round; a jitter turns round again and again
const SETTLED := 0.04           # rad: the splits a second after the cursor stops
const OFF_MAX := 0.02           # layer weight under a full-body clip

var bad := 0
var A
var main: Node
var peaks := {}

func ok(cond: bool, what: String) -> void:
	print("AIMLEAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	Save.no_write = true
	main = main_node
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	_weights()
	for id in HEROES:
		await _hero(String(id), shots)
	print("AIM_LEAD_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _weights() -> void:
	ok(WardenAimLead.allowed({}, 0.0, 0.0) == 1.0, "a Hero standing or walking has the layer")
	ok(WardenAimLead.allowed({}, 1.0, 0.0) == 0.0, "a full-body clip turns it off")
	var gone := WardenAimLead.allowed({"dead": true}, 0.0, 0.0) + WardenAimLead.allowed({"downed": true}, 0.0, 0.0)
	ok(gone == 0.0, "death and downed turn it off")
	ok(WardenAimLead.allowed({"mantle": 0.5}, 0.0, 1.0) == 0.0, "a mantle (the rig's own pose) turns it off")

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	var sync: Node = P.model.get_node("Warden/Sync")
	sync.set_process(false)
	sync.call("_process", DT)

## A bone's yaw off the model's facing (the lead's own convention: + counter-clockwise).
func _yaw(P: Hunter, sk: Skeleton3D, bone: String) -> float:
	var bi := sk.find_bone(bone)
	var d: Vector3 = P.model.global_basis.inverse() * sk.global_basis * sk.get_bone_global_pose(bi).basis \
			* sk.get_bone_global_rest(bi).basis.inverse() * Vector3.FORWARD
	return atan2(-d.x, -d.z)

func _aim(P: Hunter, face: float) -> void:
	A.aim_at(P, P.pos + Vector3(-sin(face), 0, -cos(face)) * RING)

## Sweeps the cursor 180 degrees and lets it rest; returns each frame's [head, chest] turns the layer added over the
## legs and the [head, chest] yaw splits the pose shows off the leg line (the clips' own twists in it, a gait's hips).
func _sweep(m: Match, P: Hunter, sk: Skeleton3D, move: Vector2, fire: bool, from: float, shot := Callable()) -> Array:
	var lead := P.model.get_node("Warden/Sync").get("lead") as WardenAimLead
	var rows := []
	var frames := int((SWEEP + SETTLE) / DT)
	var sweep_n := int(SWEEP / DT)
	for f in frames:
		_aim(P, from + PI * minf(float(f + 1) / sweep_n, 1.0))
		P.inp["move"] = move
		P.inp["fire"] = fire
		_frame(m, P)
		var legs := _yaw(P, sk, "root")
		rows.append([(lead.head - lead.legs) * lead.weight, (lead.chest - lead.legs) * lead.weight,
				wrapf(_yaw(P, sk, "head") - legs, -PI, PI), wrapf(_yaw(P, sk, "hips") - legs, -PI, PI)])
		if shot.is_valid():
			await shot.call(f)
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	return rows

func _judge(tag: String, rows: Array) -> void:
	var turn := [0.0, 0.0]
	var pose := [0.0, 0.0]
	var jump := 0.0
	var flips := 0
	var dir := 0.0
	for i in rows.size():
		for k in 2:
			turn[k] = maxf(turn[k], absf(rows[i][k]))
			pose[k] = maxf(pose[k], absf(rows[i][k + 2]))
		if i > 0:
			var step: float = absf(rows[i][0]) - absf(rows[i - 1][0])
			if i > 3:
				jump = maxf(jump, absf(step))
			if absf(step) > WIGGLE:
				flips += 1 if dir != 0.0 and signf(step) != dir else 0
				dir = signf(step)
	var last: Array = rows[rows.size() - 1]
	print("AIMLEAD %s: pose splits off the legs head %.1f, chest %.1f deg; layer %.1f, %.1f; frame step %.1f deg"
			% [tag, rad_to_deg(pose[0]), rad_to_deg(pose[1]), rad_to_deg(turn[0]), rad_to_deg(turn[1]),
			rad_to_deg(jump)])
	var leads: bool = pose[0] >= LEAD_MIN and turn[0] >= LEAD_MIN and turn[1] >= CHEST_MIN
	ok(leads, "%s: the head and chest lead the legs" % tag)
	ok(turn[0] > turn[1], "%s: the head leads the chest" % tag)
	ok(turn[0] <= WardenAimLead.HEAD_MAX + OVER and turn[1] <= WardenAimLead.CHEST_MAX + OVER,
			"%s: the lead is clamped (head %.0f, chest %.0f deg)" % [tag, rad_to_deg(turn[0]), rad_to_deg(turn[1])])
	ok(jump <= STEP_MAX and flips <= REVERSALS,
			"%s: no jitter at 30 fps (step %.1f deg, %d reversals)" % [tag, rad_to_deg(jump), flips])
	ok(absf(last[0]) <= SETTLED and absf(last[1]) <= SETTLED, "%s: square again after the cursor stops" % tag)

func _setup(id: String) -> Array:
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup(id, 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	(r[2] as Hunter).teleport(r[4] + Vector3(30.0, 0, 0))
	for f in 20:
		_frame(m, P)
	return r

func _hero(id: String, shots: String) -> void:
	var r := _setup(id)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var sync: Node = P.model.get_node("Warden/Sync")
	var clips := sync.get("clips") as WardenClips
	ok(clips != null, "%s: wears its clips in a match" % id)
	if clips == null:
		return
	_judge(id + " idle", await _sweep(m, P, sk, Vector2.ZERO, false, 0.0))
	if id == "gunslinger":
		_judge(id + " walk", await _sweep(m, P, sk, Vector2(0, -1), false, PI))
		_judge(id + " LMB hold", await _sweep(m, P, sk, Vector2.ZERO, true, 0.0))
		_dash_off(m, P, sync)
	m.queue_free()
	await main.get_tree().process_frame
	if shots != "":
		await _strip(id, shots)

## A full-body clip (the slide) carries its own pose: the layer is off while it owns the body.
func _dash_off(m: Match, P: Hunter, sync: Node) -> void:
	var clips := sync.get("clips") as WardenClips
	var lead := sync.get("lead") as WardenAimLead
	P.inp["move"] = Vector2(0, -1)
	P.inp["dash"] = true
	var seen := 0
	var worst := 0.0
	for f in 40:
		_aim(P, PI * 0.5 + 0.03 * f)
		_frame(m, P)
		if clips.cur == "dash" and clips.act_w >= 0.99:
			seen += 1
			worst = maxf(worst, lead.weight)
	P.inp["move"] = Vector2.ZERO
	ok(seen > 3 and worst <= OFF_MAX,
			"gunslinger dash: the layer is off under the full-body clip (%d frames, weight %.2f)" % [seen, worst])

## The sweep from above, six frames side by side: a bare model on a stage, its state fed the cursor's facing.
func _strip(id: String, dir: String) -> void:
	var stage = load("res://tools/clip_shots.gd").new()
	stage._stage(main)
	var cam: Camera3D = stage.cam
	cam.fov = 30.0
	cam.position = Vector3(0, 4.6, 1.3)
	cam.look_at(Vector3(0, 0.8, 0))
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	stage.holder.add_child(model)
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	await main.fade.reveal(0.01)
	main.get_window().size = Vector2i(TILE, TILE)
	main.get_viewport().size = Vector2i(TILE, TILE)
	for f in 30:
		await main.get_tree().process_frame       # (past the title's fade)
	var tiles := []
	var sweep_n := int(SWEEP / DT)
	for f in sweep_n:
		var face := PI * float(f + 1) / sweep_n
		model.rotation.y = face
		model.set_meta(WardenClips.STATE, {"face": face, "grounded": true})
		sync.call("_process", DT)
		if f % 3 == 2:
			await RenderingServer.frame_post_draw
			tiles.append(main.get_tree().root.get_texture().get_image())
	var strip := Image.create(TILE * tiles.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in tiles.size():
		strip.blit_rect(tiles[i], Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	DirAccess.make_dir_recursive_absolute(dir)
	strip.save_png("%s/aim_lead_%s.png" % [dir, id])
	stage.holder.queue_free()
