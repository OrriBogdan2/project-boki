extends RefCounted
## --tutorial-lane-check: the tutorial's lesson is never covered, and it teaches the mouse buttons in order.
##   1. beat order: the left click (fire) is the first thing taught, the right click (unlock, then cast)
##      second, every other skill after; each beat's key cap is the key it teaches
##   2. a run of the whole course (the driver): at every step a real combo toast (the longest combo line)
##      is fired once the card is down; at 1280x720 and 1920x1080 no toast card on show touches the step
##      strip, the check mark or the hunter's own screen box
## Pass --shots-dir=<dir> (with a real renderer, e.g. xvfb-run --rendering-driver opengl3 --resolution 1280x720)
## to save a frame of the first two beats with the combo toast up: <dir>/<step>.png.

var bad := 0
var main: Node
var m: Match
var shots := ""

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]
const GUARD := 24000      # ticks of 1 sim step: the whole course with the driver

func ok(cond: bool, what: String) -> void:
	print("TUTLANE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots)
	_order()
	await _lane()
	print("TUTLANE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. the order
func _order() -> void:
	var ids: Array = Tutorial.steps().map(func(s): return String(s[0]))
	ok(ids.find("shoot") >= 0 and ids.find("shoot") < ids.find("pick_sec"), "the left click is taught before the right")
	ok(ids.find("pick_sec") < ids.find("sec"), "the right click is unlocked, then cast")
	var first_of := ids.filter(func(x): return Tutorial.KEYS.get(x, "") in ["fire", "secondary"])
	ok(first_of.slice(0, 3) == ["shoot", "pick_sec", "sec"], "beats 1 and 2 are LMB then RMB (%s)" % str(first_of))
	var later := ids.slice(ids.find("sec") + 1).filter(func(x): return Tutorial.KEYS.get(x, "") in ["fire", "secondary"])
	ok(later.is_empty(), "nothing teaches those two keys again later (%s)" % str(later))
	ok(Tutorial.KEYS["shoot"] == "fire" and Tutorial.KEYS["sec"] == "secondary", "each beat's key cap is its own key")
	var duo: Array = Content.rules("duo_tutorial")["beats"].map(func(b): return String(b["id"]))
	var duo_keys: Array = Content.rules("duo_tutorial")["beats"].filter(func(b): return String(b["key"]) != "")
	var duo_first: Array = duo_keys.map(func(b): return String(b["key"])).slice(0, 2)
	ok(duo_first == ["fire", "secondary"], "the 2v2 tutorial also teaches fire then secondary first (%s)" % str(duo))

# ------------------------------------------------------------------ 2. no toast over the lesson
func _combo_line() -> String:
	var best := ""
	for c: Dictionary in Content.combos():
		var line := "%s!  %s" % [String(c.get("name", "Combo")), String(c.get("desc", ""))]
		if line.length() > best.length():
			best = line
	return best

func _lane() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	if shots != "" and main.fade:
		await main.fade.reveal(0.01)
	var tu: Tutorial = m.tut
	tu.ack()
	var line := _combo_line()
	var seen := 0
	var touched := 0
	var worst := ""
	var last := -1
	var guard := 0
	while guard < GUARD and tu.step < Tutorial.steps().size() and not m.player.extracted:
		guard += 1
		TutorialDrive.drive(m)
		m.step(Match.DT)
		if tu.step == last or tu.card_up() or tu.step < 0:
			continue
		last = tu.step
		if shots != "" and tu.id() in ["shoot", "sec"]:
			await _shot(tu.id(), line)
		for sz: Vector2 in SIZES:
			var n := _probe(sz, line)
			seen += 1
			if n != "":
				touched += 1
				worst = "%s at %dx%d" % [n, sz.x, sz.y] if worst == "" else worst
	ok(seen >= Tutorial.steps().size(), "a combo toast was fired at every step (%d probes)" % seen)
	ok(touched == 0, "no combo toast touches the strip, the check mark or the hunter (%d hits; first: %s)" % [touched, worst])

## Fires the combo toast on a lane sized `sz` and returns what its card touches ("" for nothing).
func _probe(sz: Vector2, line: String) -> String:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	lane.size = sz
	TutorialHud.place_msgs(lane, sz)
	lane.hold = false
	m.hud.toast(line, Color("ffd23f"))
	var lanes := TutorialHud.lanes(sz)
	var found := ""
	for r in lane.rects():
		if r.intersects(TutorialStrip.rect(sz)):
			found = "the step strip"
		elif r.intersects(lanes["check"]):
			found = "the check mark"
		elif lane.avoid.has_area() and r.intersects(lane.avoid):
			found = "the hunter"
	lane.clear()
	lane.hold = m.tut.card_up()
	return found

## The live HUD with the combo toast on it, saved as <shots>/<step>.png.
func _shot(sid: String, line: String) -> void:
	m.hud.msgs.clear()
	m.hud.msgs.hold = false
	TutorialHud.place_msgs(m.hud.msgs, main.get_viewport().get_visible_rect().size)      # (the HUD does it every frame)
	m.hud.toast(line, Color("ffd23f"))
	for i in 12:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(shots.path_join(sid + ".png"))
	m.hud.msgs.clear()
