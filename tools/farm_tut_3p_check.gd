extends RefCounted
## --farm-tut-3p-check: the farm tutorial's world pointers in the close third-person view (FarmCam), at 1920x1080 as
## the owner plays. For every step with a place in the world, from 8 bearings and two distances at the default view:
## the beam stands on the target, the prompt is in the frame or the arrow on the safe frame's edge points at it, and
## the prompt never sits on the player's own body. Also --farm-tut-3p-shots=<dir>: a screenshot per step and view
## (run with a real renderer and --resolution 1920x1080). Never touches the real save.

const BEARINGS := 8
const DISTANCES := [5.0, 12.0]  # m from the target to you
const SETTLE_FRAMES := 6  # frames at least, then until the camera has stopped easing (it eases with real time)
const SHOULDER_FRAC := 0.35  # your body taller than this share of the screen: the camera is pulled onto your back, the arrow does it
const SETTLE_MAX := 400  # frames at most
const MIN_VIEWS := 4  # standing spots on the island a step needs to count

var bad := 0
var main: Node
var home = null
var shots_dir := ""


func ok(cond: bool, what: String) -> void:
	print("T3P %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node, _mode := "") -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--farm-tut-3p-shots="):
			shots_dir = String(a).substr(20)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	main.get_window().size = Vector2i(1920, 1080)  # as the owner plays
	main.get_viewport().size = Vector2i(1920, 1080)
	FarmUnlocks.rules()["base_mode"] = false  # the twelve farm steps
	await _farm()
	for id in ["chop", "stone", "house"]:
		await _step(id)
	var e := {"u": HomeLayout._next_uid(HomeLayout.of(Save.d)), "id": "house", "x": 36, "z": 24, "r": 0}
	FarmSites.begin(e, {"labour": 8})
	(HomeLayout.of(Save.d)["deco"] as Array).append(e)
	home._sync_fixtures()
	await _step("hammer")
	e.erase("site")  # the house stands
	home._sync_fixtures()
	for id in ["task", "buy", "hob", "expedition"]:
		await _step(id)
	_unit()
	print("T3P DONE, failures: %d" % bad)
	main.get_tree().quit()


func _farm() -> void:
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["uid"] = "t3p0"
	k["level"] = 5
	k["starter"] = true
	Care.ensure(k)
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "hob_intro": true}
	HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	home = await main._hb_home()
	var t0 := CheckClock.own_msec()
	while home.panel_host == null and CheckClock.own_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	home._sync_fixtures()
	if main.fade:
		main.fade.reveal(0.05)


## Makes `id` the step on (every step before it done) and gives the guide its poll, which starts a spotlight and so
## the top-down view for the steps that ask for it (their "spot"); the camera eases with real time, so it is set here.
func _make_current(id: String) -> bool:
	for s in FarmTutorial.steps():
		if String(s["id"]) == id:
			break
		FarmTutorial.mark(String(s["id"]))
	home.guide.tick(0.6)
	home.farm_cam.k = 0.0 if FarmSpotlight.showing() else 1.0
	return FarmTutorial.current() == id


func _step(id: String) -> void:
	if not _make_current(id):
		ok(false, "%s: is the step on" % id)
		return
	var at: Vector3 = home.guide.target(id)
	if at.x == INF:
		return
	var top: bool = home.farm_cam.k < 0.5
	var arrows := 0
	var lost := 0
	var covered := 0
	var wrong := 0
	var beam_off := 0
	var views := 0
	var faced_out := 0
	var shot := {}
	var vp: Vector2 = home.get_viewport().get_visible_rect().size
	for d in DISTANCES:
		for a in BEARINGS * 2:  # the second round walks toward the target (the camera turned to face it)
			var facing := a >= BEARINGS
			var ang := (a % BEARINGS) * TAU / BEARINGS
			home.ppos = at + Vector3(sin(ang), 0, cos(ang)) * d
			if home._ground_h(home.ppos.x, home.ppos.z) <= -50.0:
				continue  # not a place to stand: off the island
			views += 1
			home.player.position = home.ppos
			home.cam.snap(home.ppos)
			home.farm_cam.yaw = atan2(at.x - home.ppos.x, home.ppos.z - at.z) * -1.0 if facing else 0.0
			await _settle()
			home.guide.tree_t = 0.0  # the nearest tree or stone is looked up twice a second: look now
			for f in 3:
				await main.get_tree().process_frame
			var tgt: Vector3 = home.guide.target(id)
			var ptr: FarmTutPointer = home.guide.pointer
			var cam: Camera3D = home.cam
			var prompt: Vector3 = home.guide.marker.position
			var stand := Vector2(ptr._beam.position.x - prompt.x, ptr._beam.position.z - prompt.z)
			if not ptr._beam.visible or stand.length() > 0.01:  # (the target moves: a Boki, the nearest tree)
				beam_off += 1
			var strips := [home.guide.hint_box, home.guide.skip_row]
			var frame := FarmTutPointer.frame(home, strips)
			var in_view := FarmTutPointer.in_frame(cam, prompt, frame)
			var feet := cam.unproject_position(tgt)
			var shoulder := FarmTutPointer.player_box(cam, home.ppos).size.y > SHOULDER_FRAC * vp.y  # (the camera on your back)
			if (
				facing and not in_view and not top and not shoulder
				and not cam.is_position_behind(tgt) and frame.has_point(feet)
				and cam.global_position.distance_to(prompt) >= float(FarmTutPointer.rules()["near_m"])
			):
				faced_out += 1  # walking toward it, its base is in the frame and its prompt is not
			if in_view != home.guide.marker.visible or (in_view and ptr._arrow != null and ptr._arrow.visible):
				wrong += 1  # an arrow although the prompt is in the frame, or the label shown out of it
			if not in_view:
				arrows += 1
				var dir := FarmTutPointer.screen_dir(cam, prompt)
				var tip: Vector2 = ptr._arrow.position - vp * 0.5 if ptr._arrow.visible else Vector2.ZERO
				if (
					not ptr._arrow.visible
					or tip.normalized().dot(dir) < 0.99
					or not frame.grow(1.0).has_point(ptr._arrow.position)
					or strips.any(func(c): return (c.rect() if c is StripView else c.get_global_rect()).has_point(ptr._arrow.position))
				):
					lost += 1
			elif (
				not cam.is_position_behind(prompt)
				and FarmTutPointer.player_box(cam, home.ppos).has_point(cam.unproject_position(prompt))
			):
				covered += 1
			var kind := "prompt" if in_view else "arrow"
			if shots_dir != "" and d == DISTANCES[0] and not shot.has(kind):
				shot[kind] = true
				await _shot("%s_%s" % [id, kind])
	var view := "top-down" if top else "third person"
	ok(
		beam_off == 0 and wrong == 0,
		"%s (%s): the beam stands under the prompt, the label and the arrow never both" % [id, view]
	)
	ok(views >= MIN_VIEWS, "%s: %d standing spots on the island to test from" % [id, views])
	ok(
		lost == 0,
		"%s: out of the frame in %d of %d views, the edge arrow points at it every time" % [id, arrows, views]
	)
	ok(faced_out == 0, "%s: walking toward it, the prompt is in the frame (%d views not)" % [id, faced_out])
	ok(covered == 0, "%s: the prompt never sits on the player (%d views)" % [id, covered])


## Waits for the camera to stop moving after the player was put somewhere (its yaw and pitch ease with real time).
func _settle() -> void:
	var still := 0
	var last := Transform3D()
	for f in SETTLE_MAX:
		await main.get_tree().process_frame
		var now: Transform3D = home.cam.global_transform
		still = still + 1 if f > SETTLE_FRAMES and now.is_equal_approx(last) else 0
		last = now
		if still >= 3:
			return


func _shot(shot_name: String) -> void:
	await main.get_tree().create_timer(1.0).timeout
	home.guide.hint_box.visible = true
	await main.get_tree().process_frame
	if home.hover_box:
		home.hover_box.visible = false
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots_dir, shot_name])


## The arithmetic the arrow stands on.
func _unit() -> void:
	var frame := Rect2(100, 50, 800, 400)
	ok(
		FarmTutPointer.edge_point(frame, Vector2.RIGHT).is_equal_approx(Vector2(900, 250)),
		"an arrow to the right sits on the right edge"
	)
	ok(
		FarmTutPointer.edge_point(frame, Vector2.UP).is_equal_approx(Vector2(500, 50)),
		"an arrow up sits on the top edge"
	)
	var corner := FarmTutPointer.edge_point(frame, Vector2(1, 1).normalized())
	ok(is_equal_approx(corner.y, 450.0) and corner.x < 900.0, "a diagonal ends on the nearer edge: %s" % corner)
