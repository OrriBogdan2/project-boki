extends RefCounted
## --tutorial-walk-shots --shots-dir=<dir> [--size=WxH]: plays the match tutorial, then the garden tutorial, start to
## finish on a fresh save (the driver flies the hunter, never writes the save) and saves a frame of every step as
## <dir>/<WxH>_<match|garden>_NN_<step>.png (default size 1920x1080).
## Checks as it goes: no step, line or detail mentions Fusion; at every match step the real lane's cards (a long combo
## toast sent at each step) clear the step strip, the check mark and the hunter's own screen box, and the strip and
## check mark sit inside the safe frame; at every garden step the objective strip, the goals tracker and the skip row
## sit inside the safe frame.
## Needs a real renderer (xvfb-run --rendering-driver opengl3, or a GPU worker).

const GUARD := 24000  # ticks of 1 sim step: the whole course with the driver
const CARD_WAIT := 600  # ticks of 1 sim step a fresh banner may take to settle
const TOAST := "Combo!  Hit three foes in a row to build the meter up"
const BEAT_WAIT_S := 0.6  # s of real time on a garden step: its strip has dropped in, the spotlight beat is still up
const GARDEN_TURNS := 40  # a garden course never takes more steps than this

var bad := 0
var main: Node
var m: Match
var dir := "/tmp/tutorial_walk"
var win := Vector2i(1920, 1080)


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
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_tree().root.size = win
	m = Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	await _walk()
	m.queue_free()
	await main.get_tree().process_frame
	await _garden()
	print("TUTWALK DONE, failures: ", bad)
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
		var hud_sz := SafeArea.frame(m.get_viewport().get_visible_rect().size).size  # (the HUD frame)
		var lanes := TutorialHud.lanes(hud_sz)
		var safe := HudStyle.safe_rect(hud_sz)
		ok(
			safe.grow(1.0).encloses(lanes["banner"]) and safe.grow(1.0).encloses(lanes["check"]),
			"%s: the strip and check mark are in the safe frame" % sid
		)
		_sign(sid, safe, lanes["banner"])
		shots += 1
		_save("match_%02d_%s" % [shots, sid])
	ok(shots >= Tutorial.steps().size() - 2, "the whole course ran (%d steps shot)" % shots)


## The garden tutorial as the playthrough check plays it (a hatched starter, every Hob step shown and done), a frame
## of each step once its spotlight beat has run, with the strip, the tracker and the skip row held to the safe frame.
func _garden() -> void:
	var da = load("res://tools/tutorial_dead_air_check.gd").new()
	da.main = main
	da._reset()
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["arch"] = "archer"
	d["cls"] = Arch.weight("archer")
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	var home = await main._hb_home()
	while home.panel_host == null:
		await main.get_tree().process_frame
	home._close_panel()
	var g: FarmGuide = home.guide
	ok(FarmTutorial.active() and g != null, "the farm tutorial runs on the fresh save")
	var turns := 0
	var shots := 0
	while FarmTutorial.current() != "" and turns < GARDEN_TURNS:
		turns += 1
		var id := FarmTutorial.current()
		g.refresh()
		for i in 12:
			g.tick(0.1)
		await main.get_tree().create_timer(BEAT_WAIT_S).timeout
		await RenderingServer.frame_post_draw
		shots += 1
		_save("garden_%02d_%s" % [shots, id])
		_audit_garden(home, id)
		da._farm_step(g, id)
		if id == "house":
			g.place_house()
			home._sync_fixtures()
		elif id == "hammer":
			da._hammer(g)
		elif id == "crop":
			da._crop_course(home, g)
		FarmTutorial.mark(id)
	ok(FarmTutorial.state()["done"], "the garden course ran to its end (%d steps shot)" % shots)
	home.queue_free()
	await main.get_tree().process_frame


## A gap step's sign, as drawn (nudged by its offset): inside the safe frame, clear of the HUD blocks and the strip.
func _sign(sid: String, safe: Rect2, strip: Rect2) -> void:
	var lab := m.tut.pad_sign(sid)
	if lab == null or not lab.visible or m.cam.is_position_behind(lab.global_position):
		return
	var cam := m.cam
	var w := (cam.global_basis.x * lab.offset.x + cam.global_basis.y * lab.offset.y) * lab.pixel_size
	var shift := cam.unproject_position(lab.global_position + w) - cam.unproject_position(lab.global_position)
	var raw := MsgLane.label_rect(lab, cam)
	var off := SafeArea.frame(cam.get_viewport().get_visible_rect().size).position  # (screen px to HUD frame)
	var box := Rect2(raw.position + shift - off, raw.size)
	var hit := ""
	for k in cam.hud_keep:
		if box.intersects(cam.hud_keep[k]):
			hit = "%s %s" % [k, cam.hud_keep[k]]
	if box.intersects(strip):
		hit = "strip"
	var fits := safe.grow(1.0).encloses(box) and hit == ""
	ok(fits, "%s: the sign %s is in the safe frame %s, clear of the HUD (%s)" % [sid, box, safe, hit])


## The strip, the goals tracker and the skip row, whichever show, inside the safe frame (window pixels).
func _audit_garden(home, id: String) -> void:
	var g: FarmGuide = home.guide
	var k: float = main.get_tree().root.content_scale_factor
	var boxes := {}
	if g.hint_box.is_visible_in_tree():
		var xf := g.hint_box.get_global_transform_with_canvas()
		boxes["strip"] = Rect2(xf * g.hint_box.rect().position, g.hint_box.rect().size * xf.get_scale())
	for c: Control in [g.tracker, g.skip_row]:
		if c != null and c.is_visible_in_tree():
			boxes[c.name] = c.get_global_rect()
	if FarmSpotlight.showing():
		boxes["spotlight card"] = FarmSpotlight._node._card.get_global_rect()
	for what in boxes:
		var r := Rect2(boxes[what].position * k, boxes[what].size * k)
		ok(_inside(r), "garden %s: the %s %s is in the safe frame" % [id, what, r])


func _save(what: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("%dx%d_%s.png" % [win.x, win.y, what]))


## One long combo toast, as a fight would send it, settled on the lane.
func _toast() -> void:
	m.hud.msgs.hold = false
	m.hud.toast(TOAST, Color("ffd23f"))
	await _frame()


func _frame() -> void:
	for i in 6:
		await main.get_tree().process_frame
	m.cam.snap(m.player.pos)
	m.cam.hud_keep = HudScale.drawn  # (Match's own frame is off here: the HUD blocks the camera keeps clear of)
	for i in 2:  # (the HUD draws with the snapped camera: what it fits to it is what the frame shows)
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw


## True when a rect (window pixels) sits inside the safe frame, give or take a pixel of rounding.
func _inside(r: Rect2) -> bool:
	return HudStyle.safe_rect(Vector2(win)).grow(1.0).encloses(r)


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
