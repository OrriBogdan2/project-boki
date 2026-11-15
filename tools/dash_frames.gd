extends Node
## --dash-frames-check: item 181's assert. Sable's dash, Kael's Lunge and Rampage in an Arena the way a player gets them
## (loading screen, warm-up, real Input actions), logged frame by frame, first use and later uses. Each dash must
## show at least MIN_STEPS intermediate positions, on each of them its own kit move, the body shown and the pose away
## from the idle before the press, with no frame over FRAME_MS.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy
##       --fixed-fps 60 -- --dash-frames-check [--dash-out=f.csv] [--dash-shots=dir]
## --dash-only=<archetype> runs that Hunter's dash alone. --fixed-fps sets the delta the game sees, so the positions
## and poses are those of that frame rate on any box (the assert holds at any rate, thanks to DashPace: run it at 15
## too) and the ms columns are what this box really took. Also runs --headless, where nothing is drawn and only travel
## and pose are judged.
##
## The frame budget: a real GPU has FRAME_MS, two 60 fps frames. A software rasterizer (no GPU in the run environment,
## and a box other lanes load to 60) spends 130-300 ms on every frame, so a fixed number means nothing: there a frame
## fails if it costs over SOFT_K x the median of its dash's window, or a compile stops a frame in the dash.
## (Plain noise on that box reached 1.9x; the compile count is the sharp test there, the ratio a backstop.)

const MIN_STEPS := 5
const FRAME_MS := 33.0
const SOFT_K := 2.5
const MIN_POSE := 0.5            # rad: summed over the rig's main joints, away from the idle before the press
const WINDOW_S := 1.1
const STEP_M := 0.02             # m: a drawn position this far from the last counts as a new one
const JOIN_S := 0.1              # s between two rolls that are one dash
const LUNGE_HOLD := 0.45         # s: RMB held, past the tap's Slam
## Archetype -> [slot, s held, moves that count as this dash's pose].
const CARTWHEEL := ["thf_vault_r", "thf_vault_l", "thf_vault_f", "thf_vault_b", "thf_vault_twist"]
const SEQ := {
	"thief": [["dash", 0.0, CARTWHEEL], ["dash", 0.0, CARTWHEEL], ["dash", 0.0, CARTWHEEL]],
	"juggernaut": [["rmb", LUNGE_HOLD, ["jug_lunge"]], ["rmb", LUNGE_HOLD, ["jug_lunge"]], ["rmb", 1.1, ["jug_lunge"]],
			["dash", 0.0, ["jug_dash"]], ["dash", 0.0, ["jug_dash"]]],
}
const POSE_NODES := ["Rig", "Rig/Torso", "Rig/Torso/ArmLPivot", "Rig/Torso/ArmRPivot", "Rig/Legs/LegL", "Rig/Legs/LegR"]
const POSE_BONES := ["root", "hips", "upper_arm.L", "upper_arm.R", "thigh.L", "thigh.R"]
const CSV_HEAD := "arch,use,slot,frame,wall_ms,script_ms,render_ms,compiles,mtime,drawx,drawz,scrx,scry,roll_t,kmove," \
		+ "model_vis,pose_rig,pose_bones,step_m"

class Tail extends Node:
	var d
	func _process(_dt: float) -> void:
		d.tail()

var todo: Array = []
var arch := ""
var out_path := ""
var shots_dir := ""
var m: Match = null
var P: Hunter = null
var home := Vector3.ZERO
var rows: PackedStringArray = [CSV_HEAD]
var uses: Array = []             # this Hunter's dashes: each a list of frames, as dictionaries
var seq: Array = []
var use := -1
var state := "wait"
var t_s := 0.0                   # game seconds in this state
var idle := {}
var sk: Skeleton3D = null
var fr := 0
var last_us := 0
var head_us := 0
var pre_us := 0
var render_us := 0
var compiles_seen := 0
var press_fr := 0
var want_press := false
var want_release := false
var was := Vector3.ZERO
var failures := 0
var headless := false
var software := false

func run(main_node: Node) -> void:
	main_node.add_child(self)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dash-only="): todo = [a.substr(12)]
		if a.begins_with("--dash-out="): out_path = a.substr(11)
		if a.begins_with("--dash-shots="): shots_dir = a.substr(13)
	if todo.is_empty():
		todo = SEQ.keys()
	process_priority = -100
	var tl := Tail.new()
	tl.d = self
	tl.process_priority = 100000
	add_child(tl)
	headless = DisplayServer.get_name() == "headless"
	if not headless:
		var adapter := RenderingServer.get_video_adapter_name().to_lower()
		software = adapter.contains("llvmpipe") or adapter.contains("softpipe") or adapter.contains("swiftshader")
		if software:
			get_window().size = Vector2i(640, 360)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			Settings.v["msaa"] = 0
		RenderingServer.frame_pre_draw.connect(func(): pre_us = Time.get_ticks_usec())
		RenderingServer.frame_post_draw.connect(func(): render_us = Time.get_ticks_usec() - pre_us)
	Save.no_write = true
	Save.d["tutorial"]["home"] = true
	if Save.d["roster"].is_empty():
		var tk := Save.new_kin("zapple", "Pip")
		Save.d["roster"].append(tk)
		Save.d["active"] = tk["uid"]
	print("DASHF renderer=%s adapter=%s software=%s" % [RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(), software])
	_open(String(todo.pop_front()))

func _open(a: String) -> void:
	arch = a
	seq = SEQ.get(arch, [["dash", 0.0, []], ["dash", 0.0, []]])
	m = null
	P = null
	sk = null
	use = -1
	uses = []
	state = "wait"
	t_s = 0.0
	var o: Dictionary = Match.arena_opts(arch)
	o["probe"] = true
	Game.main.show_screen("match", o)

## Compiles that stop a frame: Forward+'s pipelines built at draw time (the ones it builds when a surface first shows
## and its specializations go on background threads, nothing waits for them), and shader variants written to the
## Compatibility renderer's cache.
func _compiles() -> int:
	var n: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
	var stack := ["user://shader_cache"]
	while not stack.is_empty():
		var p: String = stack.pop_back()
		var da := DirAccess.open(p)
		if da == null:
			continue
		n += da.get_files().size()
		for s in da.get_directories():
			stack.append(p + "/" + s)
	return n

## Radians the rig and the skeleton have turned away from `idle`, over their main joints.
func _pose() -> Array:
	var cur := {}
	for np: String in POSE_NODES:
		var nd := P.model.get_node_or_null(np) as Node3D
		if nd:
			cur[np] = nd.quaternion
	if sk == null:
		var ss := P.model.find_children("*", "Skeleton3D", true, false)
		if not ss.is_empty():
			sk = ss[0]
	if sk:
		for bn: String in POSE_BONES:
			var i := sk.find_bone(bn)
			if i >= 0:
				cur["b:" + bn] = sk.get_bone_pose_rotation(i)
	if idle.is_empty():
		idle = cur
	var a := 0.0
	var b := 0.0
	for k: String in cur:
		var ang: float = (cur[k] as Quaternion).normalized().angle_to((idle[k] as Quaternion).normalized())
		if k.begins_with("b:"):
			b += ang
		else:
			a += ang
	return [a, b]

func _process(_dt: float) -> void:
	head_us = Time.get_ticks_usec()
	# (before Match's own _process: an action's "just pressed" lasts only for the frame it's pressed on)
	if want_press:
		want_press = false
		_press()
	elif want_release:
		want_release = false
		Input.action_release("secondary")
	if m == null:
		var cur = Game.main.current
		if cur is Match and (cur as Match).is_processing() and (cur as Match).hud != null and cur.player != null:
			m = cur
			P = m.player
			fr = 0

func _log(wall: float) -> void:
	var cam: Camera3D = m.cam
	var scr: Vector2 = cam.unproject_position(P.position + Vector3(0, 1, 0))
	var p: Array = _pose()
	var step := Vector2(P.position.x - was.x, P.position.z - was.z).length()
	var c := _compiles()
	var script_ms := (Time.get_ticks_usec() - head_us) / 1000.0
	var e := {"f": fr - press_fr, "wall": wall, "script": script_ms, "render": render_us / 1000.0,
		"comp": c - compiles_seen, "t": m.time, "x": P.position.x, "z": P.position.z, "scr": scr, "roll": P.roll_t,
		"move": P.ak.anim_id, "vis": P.model.visible and P.visible, "rig": p[0], "bones": p[1], "step": step}
	compiles_seen = c
	was = P.position
	(uses[use] as Array).append(e)
	var row: Array = [arch, use, seq[use][0], e["f"], wall, script_ms, e["render"], e["comp"], e["t"],
		e["x"], e["z"], scr.x, scr.y, e["roll"], e["move"], int(e["vis"]), e["rig"], e["bones"], step]
	rows.append(",".join(row.map(func(v): return str(v))))

func tail() -> void:
	var now := Time.get_ticks_usec()
	var wall := (now - last_us) / 1000.0
	last_us = now
	fr += 1
	if m == null:
		return
	t_s += get_process_delta_time()
	match state:
		"wait":
			if t_s >= 2.0 and P.grounded:
				home = P.pos
				_next()
		"gap":
			if t_s >= 1.0:
				want_press = true
				state = "pressing"
		"held":
			if t_s >= float(seq[use][1]):
				want_release = true
				state = "run"
				t_s = 0.0
				press_fr = fr
		"run":
			_log(wall)
			if shots_dir != "":
				var img := get_viewport().get_texture().get_image()
				if img:
					img.save_png("%s/%s_%d_%03d.png" % [shots_dir, arch, use, fr - press_fr])
			if t_s >= 0.08:
				Input.action_release("dash")
			if t_s >= WINDOW_S:
				_next()

func _next() -> void:
	for a in ["dash", "secondary", "right"]:
		Input.action_release(a)
	use += 1
	if use >= seq.size():
		_judge()
		_end_hunter()
		return
	uses.append([])
	P.teleport(home)
	P.dashes = P.max_dashes()
	for k in P.ak.cd:
		P.ak.cd[k] = 0.0
	state = "gap"
	t_s = 0.0

func _press() -> void:
	idle = {}
	_pose()
	was = P.position
	compiles_seen = _compiles()
	Input.action_press("right")
	t_s = 0.0
	press_fr = fr
	if String(seq[use][0]) == "dash":
		Input.action_press("dash")
		state = "run"
	else:
		Input.action_press("secondary")
		state = "held"

func _ok(what: String, good: bool, detail: String) -> void:
	print("DASHFRAMES %s %s  %s" % ["ok" if good else "FAIL", what, detail])
	if not good:
		failures += 1

## The frames of the dash itself, and whether they read: see the header.
func _judge() -> void:
	for i in uses.size():
		var fs: Array = uses[i]
		var run: Array = _dash_of(fs)
		var moves: Array = seq[i][2]
		var shown := 0
		var at := Vector2.INF
		for e: Dictionary in run:
			var here := Vector2(e["x"], e["z"])
			var posed: bool = float(e["bones"] if sk else e["rig"]) >= MIN_POSE
			var moved: bool = at == Vector2.INF or here.distance_to(at) >= STEP_M
			if moved and posed and bool(e["vis"]) and (moves.is_empty() or String(e["move"]) in moves):
				shown += 1
			at = here
		var name_i := "%s %s #%d" % [arch, seq[i][0], i + 1]
		_ok(name_i + ": at least %d intermediate positions with the dash pose" % MIN_STEPS, shown >= MIN_STEPS + 1,
				"%d frames posed and moving of %d in the dash" % [shown, run.size()])
		if headless or run.is_empty():
			continue
		var walls: Array = fs.map(func(e): return float(e["wall"]))
		walls.sort()
		var med: float = walls[walls.size() / 2]
		var worst := 0.0
		var comp := 0
		# (a stall shows on the frame after the one it was drawn for: the dash's own frames and one more)
		for e: Dictionary in fs.filter(func(q): return int(q["f"]) <= int(run[-1]["f"]) + 1):
			worst = maxf(worst, float(e["wall"]))
			comp += int(e["comp"])
		var limit := med * SOFT_K if software else FRAME_MS
		_ok(name_i + ": no hitch", worst <= limit and (comp == 0 or not software),
				"worst %.0f ms, limit %.0f ms (window median %.0f), %d compiles" % [worst, limit, med, comp])

## The frames of the first dash in a window. Rampage's crouch and drive, under JOIN_S apart, are one; a later roll
## is the terrain's (running on into the rocks after the dash).
func _dash_of(fs: Array) -> Array:
	var out: Array = []
	for e: Dictionary in fs:
		if float(e["roll"]) <= 0.0:
			continue
		if not out.is_empty() and float(e["t"]) - float(out[-1]["t"]) > JOIN_S:
			break
		out.append(e)
	return out

func _end_hunter() -> void:
	if not todo.is_empty():
		_open(String(todo.pop_front()))
		return
	state = "done"
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string("\n".join(rows) + "\n")
		f.close()
	print("DASH FRAMES CHECK DONE, failures: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)

