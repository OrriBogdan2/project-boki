extends "res://tools/gameplay_media.gd"
## --wisp-read-shots --shots-dir=<dir> [--size=1920x1080]: can you read the Boki wisps in a fight?
## A 3v3 (clip 1's squads, FIGHT) at the match camera with every Boki riding as a wisp (the boki_wisps setting on).
## Saves <dir>/fight_<n>.png (SHOT_AT seconds in) and prints WISPREAD lines: the share of a Hunter's body (a screen
## rectangle) the wisps hid, its own owner's and everyone else's, and the wisps' size on screen.
## Needs a renderer (jobq --needs gpu). Never touches the save.

const SHOT_AT := [1.5, 3.0, 4.5, 6.0]  # s into the fight
const FIGHT_SECS := 6.5
const HUNTER_H := 1.8  # m: a Hunter's body, for its screen rectangle
const HUNTER_W := 0.9  # m

var hits := {}  # wisp owner -> summed share of other Hunters' bodies its wisp hid
var own := {}  # ... of its own owner's body
var frames := 0
var draws := 0.0  # summed draw calls per frame
var wisps := 0
var sizes: Array = []  # px across of every wisp every frame


func run(main_node: Node) -> void:
	main = main_node
	var res := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--size="):
			var p := arg.substr(7).split("x")
			res = Vector2i(int(p[0]), int(p[1]))
	main.get_window().size = res
	main.get_viewport().size = res
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Settings.v["tips"] = false
	Settings.set_v("boki_wisps", true, false)
	await _fight_shots()
	var avg := func(d: Dictionary) -> float:
		var sum := 0.0
		for v in d.values():
			sum += float(v)
		return sum / maxf(1.0, float(wisps) * float(frames))
	sizes.sort()
	var hid := "body_hidden own=%.1f%% others=%.1f%%" % [100.0 * avg.call(own), 100.0 * avg.call(hits)]
	print(
		(
			"WISPREAD frames=%d wisps=%d wisp_px=%.0f %s (mean per wisp per frame) draw_calls=%.0f"
			% [frames, wisps, float(sizes[int(sizes.size() / 2.0)]), hid, draws / maxf(1.0, float(frames))]
		)
	)
	main.get_tree().quit(0)


func _fight_shots() -> void:
	var a := FIGHT.get_slice("/", 0).split(",")
	var b := FIGHT.get_slice("/", 1).split(",")
	await _start(a[0], FIGHT_KIN[0])
	var p := m.player
	p.ctrl = "bot"
	p.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	var base := _ground(p.pos)
	var foe_at := _ground(base + Vector3(FIGHT_GAP, 0, 0))
	var squad_a_v: Array = [
		p,
		_hunter("a1", 0, a[1], FIGHT_KIN[1], _ground(base + Vector3(-1.4, 0, 1.6))),
		_hunter("a2", 0, a[2], FIGHT_KIN[2], _ground(base + Vector3(-1.4, 0, -1.6)))
	]
	var squad_b_v: Array = [
		_hunter("b0", 1, b[0], FIGHT_KIN[3], foe_at),
		_hunter("b1", 1, b[1], FIGHT_KIN[4], _ground(foe_at + Vector3(1.4, 0, 1.6))),
		_hunter("b2", 1, b[2], FIGHT_KIN[5], _ground(foe_at + Vector3(1.4, 0, -1.6)))
	]
	for h in squad_a_v + squad_b_v:
		h.teleport(h.pos)
	main.get_viewport().warp_mouse(Vector2(4, 4))  # (no hover card in the frames)
	wisps = m.kins.filter(func(k): return k.wisp).size()
	var shots: Array = SHOT_AT.duplicate()
	await _go(
		FIGHT_SECS,
		func(t: float):
			_assist(t, squad_a_v, squad_b_v)
			_assist(t, squad_b_v, squad_a_v)
			for k in m.kins:
				k.render(FRAME, 1.0)
			_measure()
			if not shots.is_empty() and t >= float(shots[0]):
				var n := SHOT_AT.size() - shots.size()
				shots.pop_front()
				var img := main.get_viewport().get_texture().get_image()
				img.save_png(dir.path_join("fight_%d.png" % n))
				print("WISPREAD image %d x %d, x%.2f" % [img.get_width(), img.get_height(), _px_k()])
				print("WISPREAD shot %d at t=%.1f" % [n, t])
				for k in m.kins:
					if k.wisp and k.state == "shoulder":
						var at := m.cam.unproject_position(k.global_position) * _px_k()
						print("WISPAT %d %s team=%d %d %d" % [n, k.species, k.owner_h.team, at.x, at.y]),
		func(_t: float): return _centre(squad_a_v + squad_b_v)
	)


## The screen rectangle of a body `w` x `h` m standing on `feet`.
## Screenshot pixels per unit of the screen coordinates the camera projects to (the window may be stretched).
func _px_k() -> float:
	var vp := main.get_viewport()
	return float(vp.size.x) / vp.get_visible_rect().size.x


func _body_rect(feet: Vector3) -> Rect2:
	var top := m.cam.unproject_position(feet + Vector3(0, HUNTER_H, 0))
	var bot := m.cam.unproject_position(feet)
	var wpx := absf(top.y - bot.y) * HUNTER_W / HUNTER_H
	return Rect2(Vector2(bot.x - wpx * 0.5, top.y), Vector2(wpx, absf(bot.y - top.y)))


## For every wisp this frame: the share of a Hunter's body rectangle it hides, when it is nearer the camera
## than that Hunter. Your own Hunter's wisp always sits on it (shoulder height); a rival's is the real problem.
func _measure() -> void:
	frames += 1
	draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	for k in m.kins:
		if not k.wisp or k.state != "shoulder" or k.owner_h == null:
			continue
		var c := m.cam.unproject_position(k.global_position)
		var edge: Vector3 = k.global_position + Vector3(BokiWispLook.BODY_RADIUS * KinWispForm.SIZE, 0, 0)
		var px := absf(m.cam.unproject_position(edge).x - c.x)
		var box := Rect2(c - Vector2(px, px), Vector2(px, px) * 2.0)
		var depth := m.cam.global_position.distance_to(k.global_position)
		sizes.append(px * 2.0 * _px_k())
		for h in m.hunters:
			if h.out or m.cam.global_position.distance_to(h.pos + Vector3(0, 0.9, 0)) < depth:
				continue
			var body := _body_rect(h.pos)
			var share := box.intersection(body).get_area() / body.get_area()
			if share > 0.0:
				var d: Dictionary = own if h == k.owner_h else hits
				d[k.owner_h.arch] = float(d.get(k.owner_h.arch, 0.0)) + share
