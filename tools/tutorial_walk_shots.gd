extends RefCounted
## --tutorial-walk-shots --shots-dir=<dir>: plays the match tutorial start to finish on a fresh save (the driver
## flies the hunter, never writes the save) and saves a 1920x1080 frame of every step as <dir>/NN_<step>.png.
## Checks as it goes: no step, line or detail mentions Fusion, and at every step the real lane's cards (a long combo
## toast sent at each step) clear the step strip, the check mark and the hunter's own screen box.
## Needs a real renderer (xvfb-run --rendering-driver opengl3, or a GPU worker).

const SIZE := Vector2i(1920, 1080)
const GUARD := 24000  # ticks of 1 sim step: the whole course with the driver
const CARD_WAIT := 600  # ticks of 1 sim step a fresh banner may take to settle
const TOAST := "Combo!  Hit three foes in a row to build the meter up"

var bad := 0
var main: Node
var m: Match
var dir := "/tmp/tutorial_walk"


func ok(cond: bool, what: String) -> void:
	print("TUTWALK %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = SIZE
	m = Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	await _walk()
	main.get_tree().quit(1 if bad > 0 else 0)


func _walk() -> void:
	var tu: Tutorial = m.tut
	tu.ack()
	var last := -1
	var shots := 0
	var guard := 0
	while guard < GUARD and tu.step < Tutorial.steps().size() and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		m.step(Match.DT)
		if tu.step == last or tu.step < 0:
			continue
		last = tu.step
		var wait := 0
		while tu.card_up() and wait < CARD_WAIT:  # (the step's banner is fresh: let it settle, the lane waits)
			wait += 1
			m.step(Match.DT)
		if tu.step != last:
			continue
		await _frame()
		await _toast()
		var sid := tu.id()
		ok(not "usion" in tu.text.to_lower() + tu.detail.to_lower(), "%s: no Fusion in '%s'" % [sid, tu.text])
		ok(not sid in ["pick_ult", "ult"], "%s is not a Fusion step" % sid)
		ok(_clear(), "%s: the lane clears the strip, the check mark and the hunter" % sid)
		shots += 1
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("%02d_%s.png" % [shots, sid]))
	ok(shots >= Tutorial.steps().size() - 2, "the whole course ran (%d steps shot)" % shots)
	print("TUTWALK DONE, failures: ", bad)


## One long combo toast, as a fight would send it, settled on the lane.
func _toast() -> void:
	m.hud.msgs.hold = false
	m.hud.toast(TOAST, Color("ffd23f"))
	await _frame()


func _frame() -> void:
	for i in 6:
		await main.get_tree().process_frame
	m.cam.snap(m.player.pos)
	await RenderingServer.frame_post_draw


## True when no lane card on show touches the strip, the check mark or the hunter (HUD sizes and placement as live).
func _clear() -> bool:
	var lane: MsgLane = m.hud.msgs
	var sz: Vector2 = m.hud.c.size
	var lanes := TutorialHud.lanes(sz)
	var zone := HunterZone.rect(m)
	var clear := true
	for r in lane.rects():
		var hit := ""
		if r.intersects(TutorialStrip.rect(sz)):
			hit = "strip"
		elif r.intersects(lanes["check"]):
			hit = "check mark"
		elif zone.has_area() and r.intersects(zone):
			hit = "hunter"
		if hit != "":
			print("TUTWALK card %s touches the %s (size %s)" % [r, hit, sz])
			clear = false
	return clear
