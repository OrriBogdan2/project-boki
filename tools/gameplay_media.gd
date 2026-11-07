extends RefCounted
## --gameplay-media --media-clip=<1-4> --shots-dir=<dir> [--media-secs=<s>] [--media-size=1920x1080]: scripted,
## seeded gameplay for the website clips and stills (HUD on, recording mode "clean" so no debug text). It runs the
## scene again as a child Godot under the movie writer at a fixed 30 fps, which writes <dir>/clip<N>.avi and a still
## from the scene's best moment (<dir>/clip<N>.png). Run it on a GPU worker (jobq), then cut and encode the AVI with
## tools/gameplay_media.sh. MEDIA_MARK lines give the frame each phase starts on. (--media-child: the scene alone.)
##   1 squad fight   three Hunters with their Boki against a rival squad, abilities going off
##   2 Boki combat   a Boki fighting beside its Hunter against wild monsters
##   3 extraction    the squad boards the skiff and leaves as the boarding timer ends
##   4 hatch         an egg hatching and the Boki finding you (EggHatch, then KinReveal)
## Never writes the save. The names come from the Hunters' own archetype data (Vex, Kael, Cinder ...).

const STEP := 1.0 / 60.0         # s per match step; two steps make one 30 fps video frame
const FRAME := 2.0 * STEP        # s per rendered frame
const SEED := 5                  # the demo map's roll (Dusk Isles)
const FIGHT_GAP := 7.0           # m between the two squads at the start
const BOARD_LEFT := 6.5          # s of the skiff's boarding window left when the clip starts
const ASSIST_EVERY := 2.4        # s between a Hunter's scripted ability presses (the bots use few on their own)

var main: Node
var m: Match
var dir := "/tmp/media"
var clip := 1
var frame := 0
var still_at := -1.0             # s into the scene the still is saved (negative: not yet)
var squad_a: Array = []
var squad_b: Array = []
var mobs_on := false             # wild monsters stay (clip 2 spawns its own); otherwise any that appear are removed

func run(main_node: Node) -> void:
	main = main_node
	var secs := 12.0
	var res := "1920x1080"
	var child := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		child = child or arg == "--media-child"
		if arg.begins_with("--media-size="):
			res = arg.substr(13)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--media-clip="):
			clip = int(arg.substr(13))
		if arg.begins_with("--media-secs="):
			secs = float(arg.substr(13))
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if not child:
		_record(res)
		return
	Save.no_write = true
	Record.set_level(1)
	Settings.v["tips"] = false
	match clip:
		1: await _fight(secs)
		2: await _boki_combat(secs)
		3: await _extraction(secs)
		4: await _hatch(secs)
	print("MEDIA_DONE clip=%d frames=%d movie_frame=%d" % [clip, frame, Engine.get_frames_drawn()])
	main.get_tree().quit(0)

## The movie writer's flags are engine arguments, and the GPU workers (jobq) pass their job arguments after "--",
## so this runs the same scene again as a child Godot with --write-movie (the child gets --media-child). The movie
## is as big as the project's viewport setting, so the child gets that (and a better MJPEG quality) from a
## temporary override.cfg.
func _record(res: String) -> void:
	var wh := res.split("x")
	var cfg := ProjectSettings.globalize_path("res://override.cfg")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n\n" % [wh[0], wh[1]])
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=0.95\n")
	f.close()
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "opengl3",
		"--audio-driver", "Dummy", "--position", "30000,30000", "--resolution", res, "--fixed-fps", "30",
		"--write-movie", dir.path_join("clip%d.avi" % clip), "--"]
	args.append_array(OS.get_cmdline_user_args())
	args.append("--media-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	DirAccess.remove_absolute(cfg)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("MEDIA_") or line.contains("ERROR"):
			print(line)
	print("MEDIA_CHILD rc=%d" % rc)
	main.get_tree().quit(rc)

# ------------------------------------------------------------------ the match rig
## A seeded Dusk Isles match with only the player in it (the rest are made by hand), no drop, no mobs.
func _start(arch: String, kin: String, mobs := false) -> void:
	Save.d["name"] = HeroTitle.base_name(arch)
	var o := {"teams": 2, "squad": 3, "total": 1, "tier": 1, "seed": SEED, "length": 1e9, "no_drop": true,
		"raid": "clear", "blight": false, "sim_keep": true, "demo_kin": kin, "demo_kin_lv": "8:95"}
	o.merge({"arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch)}, true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	_purge()
	mobs_on = mobs
	if m.hud:
		m.hud.guide_hidden = true
	m.player.unlock_all()

## A bot Hunter of `arch` with a Boki of species `kin`, on `team`, standing at `at`.
func _hunter(id: String, team: int, arch: String, kin: String, at: Vector3) -> Hunter:
	var rec := Save.new_kin(kin, "", hash(id) & 0x7fffffff)
	rec["trust"] = 90.0
	rec["level"] = 8
	var kit := {"arch": arch, "weapon": Arch.signature(arch), "perk": ""}
	var h := m.make_hunter(id, team, Arch.weight(arch), HeroTitle.base_name(arch), "bot", rec, at, kit)
	h.unlock_all()
	h.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	return h

func _purge() -> void:
	if mobs_on:
		return
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()

func _ground(p: Vector3) -> Vector3:
	return m.world.free_spot_near(Vector3(p.x, m.world.ground_at(p.x, p.z), p.z), [], 1.2, 0.5, 6.0)

## Steps `secs` of the match, one rendered frame per 1/30 s. `each(t)` runs before every frame's steps,
## `cam_to(t)` gives the camera's point.
func _go(secs: float, each: Callable, cam_to: Callable) -> void:
	var t := 0.0
	while t < secs:
		_purge()
		each.call(t)
		for _i in 2:
			m.step(STEP)
		m.cam.snap(cam_to.call(t))
		for h in m.hunters:
			h.render(FRAME, 1.0)
		await main.get_tree().process_frame
		if still_at >= 0.0 and t >= still_at:
			_still()
			still_at = -1.0
		t += FRAME
		frame += 1

func _still() -> void:
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("clip%d.png" % clip))
	_mark("still")

## The movie frame (AVI frame index) a phase starts on.
func _mark(what: String) -> void:
	print("MEDIA_MARK %s movie_frame=%d" % [what, Engine.get_frames_drawn()])

func _centre(hs: Array) -> Vector3:
	var c := Vector3.ZERO
	for h in hs:
		c += (h as Hunter).pos
	return c / maxf(1.0, float(hs.size()))

func _nearest(h: Hunter, foes: Array) -> Hunter:
	var best: Hunter = null
	for f in foes:
		if (f as Hunter).out or (best != null and h.flat_dist(f) >= h.flat_dist(best)):
			continue
		best = f
	return best

## The abilities go off on a fixed rota: E then RMB, each Hunter offset so the squad never all fires at once.
func _assist(t: float, hs: Array, foes: Array) -> void:
	for i in hs.size():
		var h: Hunter = hs[i]
		var f := _nearest(h, foes)
		if h.out or f == null or h.flat_dist(f) > 13.0 or h.ak == null:
			continue
		var phase := fmod(t + 0.7 * i, ASSIST_EVERY)
		if phase < FRAME:
			h.inp["aim"] = f.pos + Vector3(0, 0.9, 0)
			if int((t + 0.7 * i) / ASSIST_EVERY) % 2 == 0:
				h.ak.use_e()
			else:
				h.ak.press_rmb()

# ------------------------------------------------------------------ 1: squad fight
func _fight(secs: float) -> void:
	await _start("ashwick", "cindle")
	var P := m.player
	P.ctrl = "bot"
	P.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	var base := _ground(P.pos)
	var foe_at := _ground(base + Vector3(FIGHT_GAP, 0, 0))
	squad_a = [P, _hunter("a1", 0, "juggernaut", "pebbit", _ground(base + Vector3(-1.4, 0, 1.6))),
			_hunter("a2", 0, "gunslinger", "zapple", _ground(base + Vector3(-1.4, 0, -1.6)))]
	squad_b = [_hunter("b0", 1, "archer", "wisplet", foe_at),
			_hunter("b1", 1, "bulwark", "burrlet", _ground(foe_at + Vector3(1.4, 0, 1.6))),
			_hunter("b2", 1, "mage", "puddlet", _ground(foe_at + Vector3(1.4, 0, -1.6)))]
	for h in squad_a + squad_b:
		h.teleport(h.pos)
	m.cam.zoom_to = 0.6
	still_at = 4.0
	_mark("start")
	await _go(secs, func(t: float):
		_assist(t, squad_a, squad_b)
		_assist(t, squad_b, squad_a),
		func(_t: float): return _centre(squad_a + squad_b))

# ------------------------------------------------------------------ 2: Boki combat
func _boki_combat(secs: float) -> void:
	await _start("gunslinger", "zapple", true)
	var P := m.player
	P.ctrl = "bot"
	P.ai = m.bot_brain.new_mind(m.rng, 0.85, m.bot_cfg)
	var base := _ground(P.pos)
	var foes: Array = []
	for i in 3:
		foes.append(m.spawn_mob("brute" if i == 0 else "skitter", _ground(base + Vector3(7.0 + i, 0, (i - 1) * 2.5))))
	m.cam.zoom_to = 0.5
	still_at = 3.5
	await _go(secs, func(_t: float): pass, func(_t: float): return (P.pos + P.kin.pos) * 0.5)

# ------------------------------------------------------------------ 3: extraction
func _extraction(secs: float) -> void:
	await _start("ashwick", "cindle")
	var P := m.player
	var d: Dictionary = m.exits.of_kind("dock")[0]
	var berth: Vector3 = d["berth"]
	var out3 := Vector3(d["out"].x, 0, d["out"].y)
	m.time = float(d["open_at"]) + 1.0
	m.exits.act(d, "call", P)
	m.exits._arrive(d)
	d["t"] = BOARD_LEFT
	d["wave_t"] = 1e9       # no monster waves at the berth
	var side := Vector3(-out3.z, 0, out3.x)
	squad_a = [P, _hunter("a1", 0, "juggernaut", "pebbit", berth), _hunter("a2", 0, "gunslinger", "zapple", berth)]
	for i in squad_a.size():
		var h: Hunter = squad_a[i]
		h.ctrl = "idle"
		h.teleport(_ground(berth - out3 * (9.0 + 1.5 * i) + side * (i - 1) * 2.0))
	m.cam.zoom_to = 0.6
	still_at = secs * 0.6
	await _go(secs, func(_t: float):
		if String(d["state"]) == "boarding":
			for i in squad_a.size():
				var h: Hunter = squad_a[i]
				var spot := berth + side * (i - 1) * 1.1 - out3 * 0.2
				var to := spot - h.pos
				h.inp["move"] = Vector2(to.x, to.z).normalized() if to.length() > 0.4 else Vector2.ZERO
		else:
			for h in squad_a:
				h.inp["move"] = Vector2.ZERO,
		func(_t: float): return berth + Vector3(0, 0, 0))

# ------------------------------------------------------------------ 4: hatch
## The real hatch screen: the egg is picked, knocked on (auto_warm), cracks, hatches, and KinReveal shows the Boki.
func _hatch(secs: float) -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	await main.show_screen("hatch", {})
	var hx = main.current
	for _i in 3:
		await main.get_tree().process_frame
	await main.fade.reveal(0.01)
	hx._end_intro()
	hx._pick(0)
	hx._pick(0)
	hx.auto_warm = true
	still_at = secs * 0.7
	_mark("start")
	var t := 0.0
	while t < secs:
		await main.get_tree().process_frame
		if still_at >= 0.0 and t >= still_at:
			_still()
			still_at = -1.0
		t += FRAME
		frame += 1
