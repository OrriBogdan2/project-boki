extends RefCounted
## The held far look (ScoutLook, content/rules/camera.json "scout").
## --scout-cam-check, on a 1920x1080 view:
##   1. distance: held, the view widens and leans the cursor's way on screen, at the edge as far as it has room for
##      (further than the cursor lean wherever there is room), you stay on screen every way, none near the centre
##   2. ease: the view goes 90% of the way out in ease_in_s and back in ease_out_s; it lets go off the mouse
##   3. cone: in a live match, sight reaches sight_mul further inside the cone_deg cone along your aim while
##      held, not outside it, not past it, and not without the hold; the hold rides the hunter flags (Net)
##   4. walk: holding it leaves walking speed unchanged; the key is C, shown by Settings.key_cap
## --scout-cam-shots (GPU, --shots-dir=<dir>): a live match with the cursor up and to the right: the usual
## view, the far look held, and half way back after release, one PNG each.

const VIEW := Vector2i(1920, 1080)
const HEAD := 2.0                    # m: the top of a medium hunter's head above its feet
const STEP := 1.0 / 60.0             # s: one frame of the ease
const CLEAR := 34                    # m: the flattened patch round the player (past the far look's reach)
const SHOT_CURSOR := Vector2(0.8, 0.25)   # share of the screen the cursor sits at in the shots

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SCOUTCAM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node, what: String) -> void:
	if what == "shots":
		await _shots(main)
		return
	var vp := SubViewport.new()
	vp.size = VIEW
	main.add_child(vp)
	var cam := CamRig.new()
	vp.add_child(cam)
	cam.use_style("supervive")
	_distance(cam)
	_ease(cam)
	vp.queue_free()
	var m := await _match(main)
	_cone(m)
	_walk(m)
	_key()
	m.queue_free()
	print("SCOUTCAM CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _distance(cam: CamRig) -> void:
	ok(cam.scout_to(Vector2(CamRig.SCOUT_DEAD * 0.8, 0)) == Vector3.ZERO, "a cursor near the centre leans nowhere")
	var halfway := cam.scout_to(Vector2(0.55, 0)).length()
	ok(absf(halfway / cam.scout_to(Vector2(1, 0)).length() - 0.5) < 0.01, "a cursor halfway out leans half the room")
	cam.scout_k = 1.0      # (the far look's wider view, for the on-screen test)
	for z in [1.0, 1.45]:
		cam.zoom = z
		var worst := 1e9
		var short := 0
		var further := 0
		for i in 16:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
			var p := cam.scout_to(Vector2(dir.x, dir.z))
			var lean := cam.lean_to(dir * 200.0).length()
			if p.length() + 0.001 < lean: short += 1
			if p.length() > lean + 1.0: further += 1
			cam.snap(p)
			for at in [Vector3.ZERO, Vector3(0, HEAD, 0)]:
				var s := cam.unproject_position(at)
				worst = minf(worst, minf(minf(s.x, VIEW.x - s.x), minf(s.y, VIEW.y - s.y)))
		ok(short == 0 and further == 16,
				"zoom %.2f: the far look reaches 1 m+ past the cursor lean %d of 16 ways" % [z, further])
		ok(worst >= 20.0, "zoom %.2f: at the full far look every way you stay on screen (%.0f px to the nearest edge)"
				% [z, worst])
	cam.zoom = 1.0
	cam.scout_k = 0.0
	cam.snap(Vector3.ZERO)
	var side := cam.scout_to(Vector2(1, 0)).length()
	var cap := float(CamRig.FOLLOW["supervive"][2])
	print("SCOUTCAM far look across the screen: %.1f m (cursor lean cap %.1f m)" % [side, cap])

## Frames until scout_k crosses `to` with scout_on `on`, as seconds.
func _ease_secs(cam: CamRig, on: bool, mouse_lead: bool, to: float) -> float:
	cam.scout_on = on
	var t := 0.0
	while t < 3.0 and ((cam.scout_k < to) if on else (cam.scout_k > to)):
		cam._tick_scout(STEP, mouse_lead)
		t += STEP
	return t

func _ease(cam: CamRig) -> void:
	var r: Dictionary = CamRig.SCOUT
	var t_in := _ease_secs(cam, true, true, 0.9)
	var want_in := float(r["ease_in_s"])
	ok(absf(t_in - want_in) <= STEP * 1.5, "held: 90%% out in %.3f s (ease_in_s %.2f)" % [t_in, want_in])
	_ease_secs(cam, true, true, 0.999)
	var t_out := _ease_secs(cam, false, true, 0.1)
	var want_out := float(r["ease_out_s"])
	ok(absf(t_out - want_out) <= STEP * 1.5, "released: 90%% back in %.3f s (ease_out_s %.2f)" % [t_out, want_out])
	_ease_secs(cam, false, true, 0.0)
	ok(cam.scout_k == 0.0, "released: settles exactly back on the usual view")
	_ease_secs(cam, true, true, 0.999)
	var t_ship := _ease_secs(cam, true, false, 0.1)
	ok(t_ship < 1.0, "held off the mouse (the ship, the launch): the view still eases back (%.2f s)" % t_ship)
	cam.scout_on = false
	cam.scout_k = 0.0

func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 162, "no_drop": true})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(120, 0, 120))
	var w: World = m.world
	var hx := int(floor(h.pos.x))
	var hz := int(floor(h.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi])
	for dz in range(-CLEAR, CLEAR + 1):
		for dx in range(-CLEAR, CLEAR + 1):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			for d in [w.stairs, w.walls, w.props, w.bush]:
				d.erase(i)
	h.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	for i in 20:
		m.step(Match.DT)
	return m

## Seen by the player's team at `dist` m, `deg` degrees off the aim (+x), holding the far look or not.
func _seen(m: Match, dist: float, deg: float, held: bool) -> bool:
	var h := m.player
	h.inp["aim"] = h.pos + Vector3(20, 0, 0)
	h.scout = held
	var at := h.pos + Vector3(cos(deg_to_rad(deg)), 0, sin(deg_to_rad(deg))) * dist
	return m.sees(h.team, at)

func _cone(m: Match) -> void:
	var rng := m.view_range()
	var mul := float(CamRig.SCOUT["sight_mul"])
	var half := float(CamRig.SCOUT["cone_deg"]) * 0.5
	var mid := rng * (1.0 + mul) * 0.5
	ok(not _seen(m, mid, 0.0, false), "not held: %.1f m along the aim is past sight (%.1f m)" % [mid, rng])
	ok(_seen(m, mid, 0.0, true), "held: %.1f m along the aim is seen (sight x%.2f)" % [mid, mul])
	ok(_seen(m, mid, half - 3.0, true),
			"held: seen %.0f deg off the aim, inside the %.0f deg cone" % [half - 3.0, half * 2.0])
	ok(not _seen(m, mid, half + 3.0, true), "held: not seen %.0f deg off the aim, outside the cone" % [half + 3.0])
	ok(not _seen(m, rng * mul + 1.0, 0.0, true), "held: not seen past %.1f m along the aim" % (rng * mul))
	ok(_seen(m, rng * 0.8, 40.0, true) and _seen(m, rng * 0.8, 40.0, false),
			"the usual wider cone is the same held or not")
	m.player.scout = true
	var f_on := m._flags(m.player)
	m.player.scout = false
	ok(f_on & ScoutLook.BIT != 0 and m._flags(m.player) & ScoutLook.BIT == 0,
			"the hold rides the hunter flags (teammates share it online)")

## Flat speed after `secs` walking +x, holding the far look or not.
func _speed(m: Match, held: bool) -> float:
	var h := m.player
	h.teleport(h.pos)
	h.vel = Vector3.ZERO
	h.inp["move"] = Vector2(1, 0)
	h.inp["scout"] = held
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	h.inp["move"] = Vector2.ZERO
	h.inp["scout"] = false
	var v := Vector2(h.vel.x, h.vel.z).length()
	for i in int(0.6 / Match.DT):
		m.step(Match.DT)
	h.teleport(h.pos - Vector3(6, 0, 0))
	return v

func _walk(m: Match) -> void:
	var off := _speed(m, false)
	var on := _speed(m, true)
	ok(m.player.scout == false and off > 1.0 and absf(on - off) < 0.01,
			"walking: %.2f m/s held, %.2f m/s not (unchanged)" % [on, off])
	m.player.inp["scout"] = true
	m.step(Match.DT)
	ok(m.player.scout, "the hunter holds the far look while the key is down")
	m.player.inp["scout"] = false
	m.step(Match.DT)

func _key() -> void:
	var c := InputEventKey.new()
	c.physical_keycode = KEY_C
	ok(Settings.key_cap("scout") == "C" and InputMap.has_action("scout"), "the far look is on C by default (key cap %s)"
			% Settings.key_cap("scout"))
	ok(Settings.conflicts(c, "scout").is_empty(),
			"C clashes with nothing in a match (home's Details shares it on purpose)")

func _shots(main: Node) -> void:
	Save.no_write = true
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
		await fade.reveal(0.01)      # (the screen fade from start-up still covers the view)
	Settings.set_v("tips", false)
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	var vp := main.get_viewport()
	# [name, held, frames]: the usual view, the far look settled, then half way back after release
	for sh in [["scout_off", false, 90], ["scout_held", true, 90], ["scout_released", false, 60]]:
		if sh[1]:
			Input.action_press("scout")
		else:
			Input.action_release("scout")
		for i in int(sh[2]):
			vp.warp_mouse(vp.get_visible_rect().size * SHOT_CURSOR)
			await main.get_tree().process_frame
			if sh[0] == "scout_released" and m.cam.scout_k <= 0.5:
				break
		vp.get_texture().get_image().save_png(dir.path_join(String(sh[0]) + ".png"))
		var s := m.cam.unproject_position(m.player.pos)
		var off := Vector2(m.cam.focus.x - m.player.pos.x, m.cam.focus.z - m.player.pos.z).length()
		print("SCOUTCAM shot %s: scout_k %.2f, view %.1f m off you, feet at %.0f,%.0f px"
				% [sh[0], m.cam.scout_k, off, s.x, s.y])
	main.get_tree().quit(0)
