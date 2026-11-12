extends RefCounted
## The camera's cursor lead against the source footage (docs/MOVEMENT_FEEL.md "Camera lead"):
##   --cam-lead-check (headless): with the Supervive follow the view stays on you with the cursor at the
##     screen's edge, a cursor flick moves it by nothing within a frame, and a dash eases the view after
##     you with no jump cut. The same in an expedition and in the Training Grounds.
##   --cam-lead-shots: a frame with the cursor held at the right edge, into --shots-dir=<dir> (xvfb, GPU).
## Never touches the save.

const DT := 1.0 / 60.0
const LEAD_EDGE_MAX_M := 0.35     # m: the footage's noise floor, 1.5% of the ~23.5 m across the view
const FLICK_MOVE_MAX_M := 0.05    # m the view may drift off you in the second after a cursor flick (footage: 0)
const DASH_BACK_S := 0.5          # s after a dash starts by which the view is back on you (footage: ~0.5 s)
const DASH_BACK_SLACK_M := 0.1    # m over the usual running lag allowed at that moment
const DASH_JUMP_MAX_M := 0.5      # m the view may move in one frame during a dash (no jump cut)
const EDGE := Vector2(0.99, 0.5)  # where the shot holds the cursor, as a share of the window

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
	print("CAMLEAD %s %s" % ["ok  " if cond else "FAIL", what])

func run(main_node: Node, what: String) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["cls"] = "medium"
	Save.d["arch"] = "gunslinger"
	Save.d["classes"] = ClassUnlock.legacy()
	if what == "shots":
		await _shots()
	else:
		await _area("expedition", {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
		await _area("training", {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"training": true, "practice": true})
		print("CAMLEAD %s (%d fail)" % ["PASS" if fails == 0 else "FAIL", fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## The three measurements in one area: the edge lean, a flick, a dash.
func _area(label: String, opts: Dictionary) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start(opts)
	m.set_process(false)
	var P: Hunter = m.player
	var cam: CamRig = m.cam
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	cam.follow_mode = "supervive"
	cam.lead = 1.0
	cam.snap(P.pos)
	for i in 30:
		_step(m, cam, P)
	var sz := cam.get_viewport().get_visible_rect().size
	var edge := maxf(cam.cursor_pan(Vector2(sz.x - 1.0, sz.y * 0.5), P.pos).length(),
		cam.cursor_pan(Vector2(sz.x * 0.5, 1.0), P.pos).length())
	ok(edge <= LEAD_EDGE_MAX_M, "%s: the view leans %.2f m with the cursor at the screen's edge (at most %.2f)"
		% [label, edge, LEAD_EDGE_MAX_M])
	var moved := 0.0
	for i in 60:
		_step(m, cam, P)
		moved = maxf(moved, _off(cam, P))
	ok(moved <= FLICK_MOVE_MAX_M, "%s: in the second after a cursor flick the view drifts %.3f m off you"
		% [label, moved])
	_dash(label, m, cam, P)
	m.queue_free()
	await main.get_tree().process_frame

## A dash while running: the view trails you, eases back within DASH_BACK_S and never jumps.
func _dash(label: String, m: Match, cam: CamRig, P: Hunter) -> void:
	P.inp["move"] = Vector2(1, 0)
	for i in 30:
		_step(m, cam, P)
	P.slot_lv["dash"] = maxi(1, int(P.slot_lv["dash"]))      # (an expedition starts with the dash slot locked)
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.dash_buf = 0.0
	var run_lag := _off(cam, P)
	var before := cam.focus
	P.inp["dash"] = true
	var jump := 0.0
	var trail := 0.0
	var back := 0.0
	var t := 0.0
	for i in 60:
		_step(m, cam, P)
		P.inp["dash"] = false
		t += DT
		jump = maxf(jump, _flat(cam.focus - before).length())
		before = cam.focus
		trail = maxf(trail, _off(cam, P))
		if absf(t - DASH_BACK_S) < DT * 0.5:
			back = _off(cam, P)
	P.inp["move"] = Vector2.ZERO
	ok(jump <= DASH_JUMP_MAX_M, "%s: the view moves at most %.2f m in one frame of a dash (at most %.2f, no jump cut)"
		% [label, jump, DASH_JUMP_MAX_M])
	ok(trail > run_lag + 0.05, "%s: the view trails the dash (%.2f m behind you, %.2f m at a run)"
		% [label, trail, run_lag])
	ok(back <= run_lag + DASH_BACK_SLACK_M, "%s: %.1f s into the dash the view is %.2f m behind you (a run: %.2f m)"
		% [label, DASH_BACK_S, back, run_lag])

func _step(m: Match, cam: CamRig, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 0.0)
	cam.follow(P.position, DT, true)

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## How far the view's focus sits from you, across the ground.
static func _off(cam: CamRig, P: Hunter) -> float:
	return _flat(cam.focus - P.position).length()

## One review frame with the cursor held at the right edge of the window.
func _shots() -> void:
	var dir := "user://shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1500.0, "seed": 4242, "no_drop": true})
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	var vp := main.get_viewport()
	for i in 90:
		vp.warp_mouse(vp.get_visible_rect().size * EDGE)
		await main.get_tree().process_frame
	vp.get_texture().get_image().save_png(dir.path_join("cam_lead_edge.png"))
	print("CAMLEAD shot cam_lead_edge.png")
