extends RefCounted
## --step-smooth-check: Vex (gunslinger), Albert (bulwark) and Sable (thief) walk up and back down three terrace
## steps and a flight of stairs on the Hollow Crown, through the real Match._process (sim, render, camera). Every
## frame logs the collision body's y, the drawn body's y and the camera's y. Stepping onto a terrace snaps the
## body (World.STEP); StepSmooth eases the drawn offset and the camera so neither jolts, with the body untouched.
## Prints "STEPSMOOTH <hero> <run> ..." lines and "STEP SMOOTH CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const HEROES := ["gunslinger", "bulwark", "thief"]
const MAX_BODY_JUMP := 0.08     # m: the most the drawn body's y may change in one frame
const MAX_CAM_JUMP := 0.05      # m: the most the camera's y may change in one frame

var bad := 0
var m: Match
var w: World
var P: Hunter

func run(main: Node, mode := "check") -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true,
		"map": "hollowcrown"})
	m.set_process(false)
	w = m.world
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	ok(m.map_name == "The Hollow Crown", "the run is on the Hollow Crown (%s)" % m.map_name)
	var tiers := _find_tiers()
	var slope := _find_slope()
	if mode == "shots":
		await _shots(main, tiers)
		return
	ok(not tiers.is_empty() and not slope.is_empty(), "found three terrace steps %s and stairs %s" % [tiers, slope])
	if not tiers.is_empty() and not slope.is_empty():
		for hero in HEROES:
			P.set_arch(hero)
			_walk(hero, "tiers", tiers[0], tiers[1])
			_walk(hero, "stairs", slope[0], slope[1])
	print("STEP SMOOTH CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func ok(c: bool, what: String) -> void:
	print("STEPSMOOTH %s  %s" % ["ok  " if c else "FAIL", what])
	if not c: bad += 1

## A tile the walk may cross: ground, no rock or bridge.
func _plain(x: int, z: int) -> bool:
	return w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and not w.stairs.has(w.idx(x, z)) \
		and not w.bridge.has(w.idx(x, z)) and not w.is_block(x + 0.5, z + 0.5)

func _lvl(x: int, z: int) -> int:
	return w.level[w.idx(x, z)]

## The Hollow Crown joins its terraces by flights of stairs, so the one-terrace lips the hunters step up (a snap)
## are laid here: on the first open run of ground, tiles 2, 3 and 4 along +x are raised one, two and three
## terraces, the rows beside them too. Returns [from, to]: the walk's two ends (tile centres).
func _find_tiers() -> Array:
	for z in range(2, w.h - 2):
		for x in range(2, w.w - 8):
			var l0 := _lvl(x, z)
			var open := true
			for k in 7:
				for dz in [-1, 0, 1]:
					if not _plain(x + k, z + dz) or _lvl(x + k, z + dz) != l0: open = false
			if not open:
				continue
			for k in 3:
				for dz in [-1, 0, 1]:
					w.level[w.idx(x + 2 + 2 * k, z + dz)] = l0 + 1 + k
					w.level[w.idx(x + 3 + 2 * k, z + dz)] = l0 + 1 + k
			return [Vector3(x + 0.5, 0, z + 0.5), Vector3(x + 6.5, 0, z + 0.5)]
	return []

## A flight of four stairs along +x (three terraces of rise) with plain ground at both ends, as [from, to].
func _find_slope() -> Array:
	for i in w.stairs.keys():
		var x: int = i % w.w
		var z: int = i / w.w
		var top := _lvl(x, z) + 4
		if w.stairs[i] != Vector2i(1, 0) or not _plain(x - 1, z) or not _plain(x + 4, z) or _lvl(x + 4, z) != top:
			continue
		if _lvl(x - 1, z) == _lvl(x, z) and w.stairs.has(i + 1) and w.stairs.has(i + 2) and w.stairs.has(i + 3):
			return [Vector3(x - 0.5, 0, z + 0.5), Vector3(x + 5.5, 0, z + 0.5)]
	return []

var body_max := 0.0
var cam_max := 0.0
var pos_max := 0.0
var last := []

## One rendered frame; keeps the worst jump of each y since the last.
func _frame(hero: String, label: String) -> void:
	m._process(DT)
	pos_max = maxf(pos_max, absf(P.pos.y - float(last[0])))
	body_max = maxf(body_max, absf(P.position.y - float(last[1])))
	cam_max = maxf(cam_max, absf(m.cam.position.y - float(last[2])))
	last = [P.pos.y, P.position.y, m.cam.position.y]
	if OS.get_cmdline_user_args().has("--log-frames"):
		print("STEPFRAME %s %s collision.y=%.3f body.y=%.3f cam.y=%.3f"
			% [hero, label, P.pos.y, P.position.y, m.cam.position.y])

## --step-smooth-shots --shots-dir=<dir>: one strip per hero (<hero>.png): the frames around the first terrace
## step, 1/60 s apart then wider, each cropped round the hunter, with the body and camera y in <hero>.txt.
const STRIP_AT := [-1, 0, 1, 2, 3, 5, 7, 10]     # frames from the snap
const CROP := Vector2i(220, 260)                  # px round the hunter

func _shots(main: Node, tiers: Array) -> void:
	var dir := "."
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)       # the boot splash stays up when a tool starts the match by hand
	if m.hud:
		m.hud.visible = false
	for hero in HEROES:
		P.set_arch(hero)
		_start_at(tiers[0])
		var frames: Array[Image] = []
		var log := PackedStringArray()
		var snap_at := -99
		Input.action_press("right")
		for i in 160:
			var before := P.pos.y
			m._process(DT)
			await RenderingServer.frame_post_draw
			if snap_at < 0 and P.pos.y > before + 0.3: snap_at = i
			log.append("frame %d  body.y %.3f  drawn.y %.3f  cam.y %.3f" % [i, P.pos.y, P.position.y, m.cam.position.y])
			if snap_at >= 0 and (i - snap_at) in STRIP_AT or (snap_at < 0 and i == 0):
				frames.append(_crop(main))
			if snap_at >= 0 and i - snap_at > int(STRIP_AT[-1]): break
		Input.action_release("right")
		var strip := Image.create(CROP.x * frames.size(), CROP.y, false, Image.FORMAT_RGBA8)
		for k in frames.size():
			strip.blit_rect(frames[k], Rect2i(Vector2i.ZERO, CROP), Vector2i(CROP.x * k, 0))
		strip.save_png(dir.path_join(hero + ".png"))
		var f := FileAccess.open(dir.path_join(hero + ".txt"), FileAccess.WRITE)
		f.store_string("\n".join(log))
	main.get_tree().quit(0)

func _crop(main: Node) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)   # the viewport gives RGB8; blit_rect needs matching formats
	var at := Vector2i(m.cam.unproject_position(P.position + Vector3(0, 0.9, 0)))
	var r := Rect2i(at - CROP / 2, CROP).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var out := Image.create(CROP.x, CROP.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, r, r.position - (at - CROP / 2))
	return out

func _start_at(a: Vector3) -> void:
	P.out = false
	P.gone = false
	P.downed = false
	a.y = w.ground_at(a.x, a.z)
	P.teleport(a)
	P.vel = Vector3.ZERO
	P.grounded = true
	m.cam.snap(P.pos)
	m.acc = 0.0
	m.paused = false
	for i in 30: m._process(DT)

## Walks from a to b and back, logging each frame; the worst frame-to-frame jumps must stay under the limits.
func _walk(hero: String, label: String, a: Vector3, b: Vector3) -> void:
	_start_at(a)
	body_max = 0.0
	cam_max = 0.0
	pos_max = 0.0
	last = [P.pos.y, P.position.y, m.cam.position.y]
	for leg in [b, a]:
		var key := "right" if leg.x > P.pos.x else "left"
		Input.action_press(key)
		for i in 400:
			_frame(hero, label)
			if absf(P.pos.x - leg.x) < 0.15 or (key == "right") == (P.pos.x > leg.x): break
		Input.action_release(key)
		for i in 90: _frame(hero, label)
	print("STEPSMOOTH %s %s: collision y jump %.3f m (not limited), drawn %.3f, camera %.3f"
		% [hero, label, pos_max, body_max, cam_max])
	ok(body_max <= MAX_BODY_JUMP, "%s %s: drawn body y jump %.3f <= %.2f m" % [hero, label, body_max, MAX_BODY_JUMP])
	ok(cam_max <= MAX_CAM_JUMP, "%s %s: camera y jump %.3f <= %.2f m" % [hero, label, cam_max, MAX_CAM_JUMP])
