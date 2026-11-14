extends RefCounted
## --spectate-check: out with your team still in it, you watch a teammate and can switch.
##   1. nobody is watched while you live, or in the first moments after you die
##   2. fire / secondary (Spectate.input) step through living teammates, skip the out and the extracted, and wrap
##   3. the camera, minimap and Boki card follow the watched teammate (Spectate.viewed)
##   4. paused, the keys do nothing; the strip's Give up button ends the match as before
## --spectate-shots --shots-dir=<dir> [--shot-size=2560x1440]: the strip in the renderer.
## Never touches the save.

var bad := 0
var main: Node
var m: Match
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("SPECTATE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func press(action: String) -> bool:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return m.spectate.input(ev)

func setup() -> Array:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 4, "tier": 0, "length": 1e9, "seed": 12, "no_drop": true, "sim_keep": true})
	m.set_process(false)
	P = m.player
	return m.hunters.filter(func(x): return x.team == P.team and x != P)

func settle(frames: int) -> void:
	for i in frames:
		m.step(1.0 / 60.0)
		await main.get_tree().process_frame

func run(main_node: Node, mode: String = "check") -> void:
	main = main_node
	var mates: Array = await setup()
	var A: Hunter = mates[0]
	var B: Hunter = mates[1]
	var C: Hunter = mates[2]
	ok(m.spectate.current() == null and m.spectating() == null, "alive: nobody is watched")
	P.out = true
	P.set_meta("died_at", m.time)
	ok(m.spectate.current() == null, "just died: the camera waits a moment")
	P.set_meta("died_at", m.time - 3.0)
	ok(m.spectate.current() == A and m.spectating() == A, "after the pause you watch the first teammate")
	if mode == "shots":
		await shots(A, B, C)
		return
	ok(press("fire") and m.spectate.current() == B, "fire: the next teammate")
	ok(press("secondary") and m.spectate.current() == A, "secondary: the previous one")
	ok(press("secondary") and m.spectate.current() == C, "secondary from the first wraps to the last")
	ok(press("fire") and m.spectate.current() == A, "fire from the last wraps to the first")
	B.out = true
	m.spectate.cycle(1)
	ok(m.spectate.current() == C, "an out teammate is skipped")
	C.extracted = true
	ok(m.spectate.current() == A and m.spectate.mates() == [A], "an extracted one is skipped too")
	m.spectate.cycle(1)
	ok(m.spectate.current() == A, "one teammate left: cycling stays on them")
	C.extracted = false
	m.spectate.watched = C
	m.set_process(true)      # (the camera follows in the match's own frame)
	for h in m.hunters:
		h.ctrl = "idle"
	for i in 240:
		await main.get_tree().process_frame
	m.set_process(false)
	ok(m.spectate.viewed() == C, "the HUD's minimap and Boki card follow %s" % C.pname)
	ok(m.cam.focus.distance_to(C.pos) < 3.0, "the camera follows them (%.1f m off)" % m.cam.focus.distance_to(C.pos))
	m.paused = true
	var before := m.spectate.current()
	ok(not press("fire") and m.spectate.current() == before, "paused: the keys do nothing")
	m.paused = false
	A.out = true
	C.out = true
	ok(m.spectate.current() == null and m.spectate.viewed() == P, "nobody left: the view is yours again")
	A.out = false
	C.out = false
	m.spectate.give_rect = Rect2(10, 10, 90, 28)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(20, 20)
	var used := m.spectate.input(click)
	ok(used and m.flow.ending() and not m.result.get("extracted", true), "Give up ends the match")
	ok(P.gone, "and your Boki is left behind (Life.make_gone)")
	print("SPECTATE %s" % ("PASS" if bad == 0 else "FAILED %d" % bad))
	main.get_tree().quit(0 if bad == 0 else 1)

## The strip, a teammate switch and a cooldown showing, as screenshots.
func shots(A: Hunter, B: Hunter, C: Hunter) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shot-size="):
			var wh := String(a).substr(12).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
			await settle(10)
	var view := main.get_viewport().get_visible_rect().size
	for h in m.hunters:
		h.ctrl = "idle"
	for i in 3:
		(mates_at(i) as Hunter).teleport(m.world.free_spot_near(P.pos + Vector3(6 + 4 * i, 0, 4), [], 1.0, 0.4, 8.0))
	B.hp = B.max_hp * 0.55
	B.armor = B.max_armor * 0.6
	for who in [A, B]:
		m.spectate.watched = who
		await settle(90)
		m.cam.snap(who.pos)
		await settle(30)
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("spectate_%s_%dp.png" % [who.pname.to_lower(), img.get_height()]))
	print("SPECTATE shots in %s (%dx%d)" % [dir, view.x, view.y])
	main.get_tree().quit(0)

func mates_at(i: int) -> Hunter:
	return m.hunters.filter(func(x): return x.team == P.team and x != P)[i]
