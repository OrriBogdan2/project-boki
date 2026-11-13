extends RefCounted
## --water-vfx-check: a Hunter in shallow water (WaterFx). On the farm, a stream two tiles wide (all of it
## shallow) for Vex and then Albert: running, dashing and landing on dry ground spawn nothing; stepping
## in splashes, running along it leaves a wake, a dash sprays and a jump lands in a splash, each a
## restart of a pooled emitter (no node made, no ring or burst decal); the pool stays within its droplet
## budget, Albert's splash is bigger than Vex's, and on Low nothing is made or shown.
## --shots-dir=<dir>: also films each Hunter (in their match look) crossing the stream (frames
## <hero>_NNN.png, real frames with the game running, the camera close in; GPU).

const HEROES := ["gunslinger", "bulwark"]      # Vex, Albert
const STREAM_X := 40         # the stream's west tile column (it is two tiles wide)
const STREAM_Z := Vector2i(29, 41)      # its first and last tile row
const DT := 1.0 / 60.0
const FILM_FPS := 60.0       # frames kept per second of play (a fast GPU renders many more)
const FILM_ZOOM := 0.55      # the home camera as close as the wheel takes it (droplets read at this range)

var bad := 0
var shot := ""

func ok(cond: bool, what: String) -> void:
	print("WATERVFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)

func run(main: Node) -> void:
	var tree := main.get_tree()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shot = a.substr(12)
	if shot != "": DirAccess.make_dir_recursive_absolute(shot)
	Save.no_write = true
	var q0 = Settings.v.get("quality")
	Settings.v["quality"] = "high"      # (the most droplets; a headless run would guess Low, where nothing shows)
	var sizes := {}
	var splash_n := {}
	for hero in HEROES:
		var hm = await _home(main, hero)
		var r: Dictionary = await _events(hm, tree, hero)
		sizes[hero] = r["body_k"]
		splash_n[hero] = r["splash_n"]
		if shot != "":
			hm.queue_free()
			await tree.process_frame
			hm = await _home(main, hero)
			await _film(main, hm, hero)
		hm.queue_free()
		await tree.process_frame
	var al := [sizes["bulwark"], splash_n["bulwark"], sizes["gunslinger"], splash_n["gunslinger"]]
	ok(al[0] > al[2] and al[1] > al[3], "scaled by Hunter size: Albert %.2f (%d droplets) over Vex %.2f (%d)" % al)
	_low(main)
	Settings.v["quality"] = q0
	print("WATERVFX DONE, failures: %d" % bad)
	tree.quit()

## The classic farm with a stream laid north to south east of the landing, this Hunter worn.
func _home(main: Node, hero: String):
	var od := Save.fresh()
	var k := Save.new_kin("puddlet", "Drip")
	od["roster"].append(k)
	od["active"] = k["uid"]
	od["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	od["matches"] = 3
	od["cls"] = Arch.weight(hero)
	od["arch"] = hero
	var lay := HomeLayout.fresh()
	for z in range(STREAM_Z.x, STREAM_Z.y + 1):
		for x in [STREAM_X, STREAM_X + 1]: lay["water"][HomeLayout.key(x, z)] = 1
	od["layout"] = lay
	Save.d = JSON.parse_string(JSON.stringify(od))
	var hm = await main._hb_home()
	for i in 20: await main.get_tree().process_frame
	return hm

func _put(hm, at: Vector3) -> void:
	hm.ppos = at
	hm.py = 0.0
	hm.pvy = 0.0
	hm.pvel = Vector3.ZERO
	hm.dash_t = 0.0
	hm.dash_charges = 2.0
	hm.water.was = hm.water.depth(at.x, at.z)
	hm.water.wade_k = 0.0

## Steps the hunter `n` frames holding `dir`; a dash or a jump pressed on the first. Returns whether
## it dashed and how high it rose.
func _steps(hm, tree: SceneTree, dir: Vector2, n: int, act := "") -> Dictionary:
	_press(dir)
	if act != "": Input.action_press(act)
	hm._move_player(DT)
	var dashed: bool = hm.dash_t > 0.0
	var peak: float = hm.py
	if act != "":
		Input.action_release(act)
		await tree.process_frame      # (a press stays "just pressed" until a frame passes)
	for i in n - 1:
		hm._move_player(DT)
		peak = maxf(peak, hm.py)
	_press(Vector2.ZERO)
	return {"dashed": dashed, "peak": peak}

func _counts(hm) -> Dictionary:
	var w: WaterFx = hm.water.wfx
	return w.counts.duplicate() if w else {"splash": 0, "spray": 0, "wake": 0}

## Did `kind` start exactly from its pool (its last emitter running, no node added under WaterFx)?
func _pooled(w: WaterFx, kind: String, nodes: int) -> bool:
	var pool: Array = w.pools[kind]
	var last: CPUParticles3D = pool[(int(w.next[kind]) - 1 + pool.size()) % pool.size()]
	return last.emitting and last.get_parent() == w and w.get_child_count() == nodes

func _events(hm, tree: SceneTree, hero: String) -> Dictionary:
	hm.set_process(false)
	var wtr = hm.water
	var mid_z := (STREAM_Z.x + STREAM_Z.y) / 2.0
	var in_x := STREAM_X + 1.0      # the seam between the stream's two columns
	var shallow: bool = wtr.depth(in_x, mid_z) == 1 and wtr.depth(in_x - 0.5, STREAM_Z.x + 0.5) == 1
	ok(shallow and wtr.depth(STREAM_X - 2.5, mid_z) == 0,
		"%s: the stream is shallow water all through, dry ground beside it" % hero)
	var w_open: bool = hm.world.occupy(in_x, mid_z, 0.38, 0.0, true) == 0.0
	ok(w_open and hm.world.occupy(STREAM_X - 3.0, mid_z, 0.38, 0.0, true) == 0.0,
		"%s: the stream and its west bank are open ground" % hero)
	# dry ground: run, dash, jump and land beside the stream (west of it, heading away)
	_put(hm, Vector3(STREAM_X - 3.0, 0, mid_z))
	await _steps(hm, tree, Vector2(0, -1), 40)
	var dash: Dictionary = await _steps(hm, tree, Vector2(0, -1), 20, "dash")
	var jump: Dictionary = await _steps(hm, tree, Vector2(0, 1), 60, "jump")
	var c := _counts(hm)
	ok(dash["dashed"] and jump["peak"] > 0.5 and absf(hm.py) < 0.01,
		"%s: the dry run dashed, jumped %.1f m and landed" % [hero, jump["peak"]])
	ok(c["splash"] + c["spray"] + c["wake"] == 0 and hm.water.depth(hm.ppos.x, hm.ppos.z) == 0,
		"%s: on dry ground running, a dash and a landing spawn no water effect (%s)" % [hero, str(c)])
	# walk in from the west bank: a splash
	_put(hm, Vector3(STREAM_X - 0.6, 0, mid_z))
	var radial0: int = hm.fx.radial
	await _steps(hm, tree, Vector2(1, 0), 30)
	var w: WaterFx = wtr.wfx
	ok(w != null and w.counts["splash"] == 1, "%s: stepping in splashes" % hero)
	if w == null:
		return {"body_k": 0.0, "splash_n": 0}
	var nodes: int = w.get_child_count()
	var all := 0
	for kind in WaterFx.POOL: all += int(WaterFx.POOL[kind])
	ok(nodes == all and _pooled(w, "splash", nodes),
		"%s: the splash is a pooled emitter (%d emitters, none made for it)" % [hero, nodes])
	var splash_n: int = w.pools["splash"][0].amount
	var body_k := w.body_k
	# run along the stream: a wake
	_put(hm, Vector3(in_x, 0, STREAM_Z.y - 0.5))
	var c0 := _counts(hm)
	await _steps(hm, tree, Vector2(0, -1), 45)
	c = _counts(hm)
	ok(c["wake"] - c0["wake"] >= 4 and c["spray"] == c0["spray"] and _pooled(w, "wake", nodes),
		"%s: running along it leaves a pooled wake (%d puffs in 0.75 s), no spray" % [hero, c["wake"] - c0["wake"]])
	# dash along it: a spray
	c0 = _counts(hm)
	dash = await _steps(hm, tree, Vector2(0, -1), 14, "dash")
	c = _counts(hm)
	ok(dash["dashed"] and c["spray"] - c0["spray"] >= 3 and _pooled(w, "spray", nodes),
		"%s: a dash along it sprays (%d puffs, pooled)" % [hero, c["spray"] - c0["spray"]])
	ok(hm.fx.radial == radial0, "%s: no ring or burst decal stepping in, running or dashing through it" % hero)
	# jump and land in it: a splash
	_put(hm, Vector3(in_x, 0, mid_z))
	hm.py = 1.4
	c0 = _counts(hm)
	for i in 90:
		hm._move_player(DT)
		if absf(hm.py) < 0.01 and i > 5: break
	c = _counts(hm)
	ok(c["splash"] - c0["splash"] == 1 and _pooled(w, "splash", nodes),
		"%s: landing in it splashes once, from the pool" % hero)
	w.set_body(WaterFx.SIZE_MAX)      # (the biggest any Hunter's splash grows)
	ok(w.capacity() <= WaterFx.BUDGET and w.get_child_count() == all,
		"%s: at most %d droplets on High (budget %d), %d emitters" % [hero, w.capacity(), WaterFx.BUDGET, all])
	return {"body_k": body_k, "splash_n": splash_n}

## On Low no pool is made: nothing spawns from any event.
func _low(main: Node) -> void:
	Settings.v["quality"] = "low"
	var w := WaterFx.new()
	main.add_child(w)
	w.splash(Vector3.ZERO, 1.0)
	w.move(Vector3.ZERO, Vector2(4, 0), true, 0.1)
	w.move(Vector3.ZERO, Vector2(4, 0), false, 0.2)
	var spawned: int = w.counts["splash"] + w.counts["spray"] + w.counts["wake"]
	ok(w.get_child_count() == 0 and w.capacity() == 0 and spawned == 0,
		"Low: culled (no emitter made, nothing spawns)")
	w.queue_free()

## The film: the game running at half speed (so a dash gets frames while each one is read back), the
## Hunter crosses the stream from the west bank into it, runs along it, dashes, jumps and lands in it, and
## climbs out the east bank. FILM_FPS frames a second of play kept at 3/4 size, saved at the end.
func _film(main: Node, hm, hero: String) -> void:
	var tree := main.get_tree()
	if main.fade: main.fade.reveal(0.05)      # (the loading card over a new home)
	await tree.create_timer(0.3).timeout
	_put(hm, Vector3(STREAM_X - 1.2, 0, STREAM_Z.y + 0.5))
	# at home you are the Unmasked: the film wears the Hunter's own look, as in a match, so it shows them
	var cls := Data.class_of_save()
	var body: Node3D = Models.hunter(cls, Data.TEAM_COLORS[0], hm._weapon(), "", Unmasked.mask_look(), hero)
	hm.player.queue_free()
	hm.player = body
	hm.add_child(body)
	hm.cam.zoom_to = FILM_ZOOM
	hm.cam.zoom = FILM_ZOOM
	hm.cam.snap(hm.ppos)
	# [direction, seconds of play, key pressed at its start]
	var plan := [[Vector2(0.8, -0.6), 0.6, ""], [Vector2(0, -1), 0.5, ""], [Vector2(0, -1), 0.35, "dash"],
		[Vector2(0, -1), 0.25, ""], [Vector2(0, -1), 0.8, "jump"], [Vector2(1, 0), 0.8, ""], [Vector2.ZERO, 0.4, ""]]
	var frames: Array[Image] = []
	Engine.time_scale = 0.5
	var played := 0.0
	var kept_t := -1.0
	for step in plan:
		_press(step[0])
		if step[2] != "": Input.action_press(step[2])
		var t := 0.0
		while t < float(step[1]):
			await tree.process_frame
			if t == 0.0 and step[2] != "": Input.action_release(step[2])
			t += hm.get_process_delta_time()
			played += hm.get_process_delta_time()
			if played - kept_t < 1.0 / FILM_FPS: continue
			kept_t = played
			var img := tree.root.get_texture().get_image()
			if img == null or img.is_empty():
				ok(false, "%s film: no frame to read back (not a GPU run?)" % hero)
				Engine.time_scale = 1.0
				return
			img.resize(img.get_width() * 3 / 4, img.get_height() * 3 / 4, Image.INTERPOLATE_BILINEAR)
			frames.append(img)
	Engine.time_scale = 1.0
	_press(Vector2.ZERO)
	for i in frames.size():
		frames[i].save_png("%s/%s_%03d.png" % [shot, hero, i])
	var fps := frames.size() / played
	print("WATERVFX film %s: %d frames over %.2f s of play (%.1f fps), effects %s" % [hero, frames.size(), played, fps,
		str(_counts(hm))])
