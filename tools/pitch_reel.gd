extends "res://tools/gameplay_media.gd"
## --pitch-reel [--shots=2,3,4,6,7,8,9,10] [--takes=N] --shots-dir=<dir> [--hunter=<id>]: raw demo-reel footage
## played by scripts, 1920x1080 at 60 fps (docs/PITCH_REEL.md). Run it on a GPU worker (jobq --needs gpu;
## Vulkan). Each shot and take is a child Godot under the movie writer (fixed 60 fps, so the footage is smooth
## whatever the machine does): <dir>/shot<N>_take<K>.avi, plus .marks (the PITCH_MARK lines: the frame each part
## starts on, so the encoder can trim the loading). tools/pitch-reel (boki-tools) fetches and encodes.
##   2 hatch      the egg is knocked on, cracks, the Boki is revealed and held
##   3 evolve     a Boki one level short takes its next form on the farm
##   4 farm       hungry Boki eat at the trough, a pat, fetch, a brush and a drill on the dummy
##   6 select     the Hunters screen steps through every Hunter and lands on the chosen one
##   7 kit        a Hunter against one bot: attack, right click and utility on a rota (--hunter, else take 1..n in turn)
##   8 drop       the expedition loads and the squad drops in (the loading is before the DROP mark)
##   9 loot       a bot-played small match (three duos) from the landing: loot and the fights it runs into
##  10 escape     the Hunter walks into an uplink yard as it finishes charging and rides out
## Never writes the save. Takes differ by seed (and by egg, Hunter or foe).

const FPS := 60
const WIDTH_PX := 1920
const HEIGHT_PX := 1080
const MJPEG_QUALITY := 0.85  # 1.0 is huge at 1080p60; 0.85 holds up to the H.264 encode
const CHILD_LOG_LINES := 300  # lines of a take's own output (past its PITCH_ lines) the recorder keeps
const STALL_X := 3.0  # a take whose movie has not grown for this x its length is hung and killed ...
const STALL_MIN_S := 600.0  # ... but never sooner than this many s (loading; the shots that run to their end)
const KIT_ROTA_S := 2.1  # s between a Hunter's ability presses in the kit shot
const KIT_FOE_SKILL := 0.5  # the foe bot's skill (0..1): it fights back but does not hunt the Hunter down
## s of each shot that runs for a set time (the others run to the end of their script: 2, 3, 6)
const SECS := {4: 60.0, 7: 24.0, 8: 22.0, 9: 180.0, 10: 34.0}
const RAID_DUOS := 3  # shot 9: teams of two
const ESCAPE_CHARGE_LEFT := 4.0  # s of the uplink's charge left when shot 10 starts
const CLOCK_LEFT_S := 840.0  # s on the match clock when a stepped shot starts (1e9 reads as junk)
const KIT_GAP_M := 4.5  # m between the Hunter and its foe in the kit shot (both well inside the frame)
# half the ground (m) the default camera frames at zoom 1, inside the cut's 1.08 push
const FIT_HALF := Vector2(10.8, 6.4)
const FIT_PAD_X := 1.6  # m kept beside a fighter
const FIT_PAD_Z := 2.4  # m kept above and below (a Hunter stands ~2 m tall up the screen)
const FIT_MAX := 1.0  # (--fit-max=<zoom>)
const FIT_FOLLOW := 9.0  # 1/s the fit focus eases
const FIT_FAR_M := 22.0  # a fighter further off than this is not in the shot (parked for the intro, thrown far)
const KIT_ZOOM := 0.85  # the kit shot's camera zoom (0.55 frames only ~8 m: the pair sat on its edges)
# m: a foe that has walked further than this from the Hunter is put back at the fight (--reach=)
const KIT_FOE_REACH := 7.0
const KIT_ROOM_M := 10  # m of solid ground all round the kit fight (at a cliff edge both fell off)
const KIT_LEASH_M := 3.0  # m the Hunter may stray from the fight's centre before it walks back (dashes)
const KIT_SEARCH_M := 30  # m from the start the kit shot looks for that much room
const PitchClean := preload("res://tools/pitch_clean.gd")
const SHADOW_M := 70.0  # m of sun shadow range in a take (_crisp_shadows)
const DROP_PLAN_MAX_S := 25.0  # s shot 8 waits for the plan-your-drop screen to hand over to the drop
const ESCAPE_TAIL_S := 2.5  # s of the ride out kept after the Hunter is extracted
const KO_TAIL_S := 1.5  # s shot 9 keeps playing after the Hunter dies (the encoder cuts 1 s after the mark)

var shot := 2
var take := 1
var fit_zoom := 0.0  # the eased zoom `--fit` holds so both fighters stay in frame (0: not started)
var fit_at := Vector3.INF  # the eased focus `--fit` follows
var spot_at := Vector3.INF  # the spot _roomy_ground picked (`--leash` keeps the fight on it)
var hold_zoom := 0.0  # > 0: _step_frame holds the camera at this zoom (the kit shot)
var hunter := Demo.DEFAULT_HUNTER
var failed := false  # a shot that cannot be filmed on this build says so (fail()), and the take is dropped
var marks := {}  # part -> the frame it started on (mark())


func run(main_node: Node) -> void:
	main = main_node
	var args := OS.get_cmdline_user_args()
	var child := false
	var shots := PackedStringArray(["2", "3", "4", "6", "8"])
	var takes := 1
	for a in args:
		var arg := String(a)
		child = child or arg == "--pitch-child"
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--shots="):
			shots = arg.substr(8).split(",")
		if arg.begins_with("--takes="):
			takes = int(arg.substr(8))
		if arg.begins_with("--pitch-shot="):
			shot = int(arg.substr(13))
		if arg.begins_with("--pitch-take="):
			take = int(arg.substr(13))
	if dir.is_relative_path():
		dir = ProjectSettings.globalize_path("res://").path_join(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	if not child:
		_film_all(shots, takes)
		return
	hunter = _hunter_for(args)
	set_up_take()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	await play()
	print("PITCH_DONE shot=%d take=%d frames=%d" % [shot, take, Engine.get_frames_drawn()])
	BackgroundWork.drain()  # while the tree is up: drained at quit instead, a running load once crashed the exit
	main.get_tree().quit(1 if failed else 0)


## --hunter=<id>, else the take's own Hunter (so five kit takes show five Hunters).
func _hunter_for(args: PackedStringArray) -> String:
	for a in args:
		if String(a).begins_with("--hunter="):
			return Demo.hunter_in(args)
	var ids := Arch.ids()
	return String(ids[(take - 1) % ids.size()]) if shot == 7 else Demo.DEFAULT_HUNTER


## A take never writes the save and shows the clean HUD with no tips.
func set_up_take() -> void:
	failed = false
	marks.clear()
	Save.no_write = true
	Record.set_level(1)
	Settings.v["tips"] = false


func play() -> void:
	var farm = load("res://tools/pitch_reel_farm.gd").new(self)
	match shot:
		2:
			await farm.hatch(take)
		3:
			await farm.evolve()
		4:
			await farm.farm_loop(SECS[4])
		6:
			await farm.hunter_select(hunter)
		7:
			await _kit()
		8:
			await _drop()
		9:
			await _loot()
		10:
			await _escape()


# ------------------------------------------------------------------ the recorder
## Every shot and take as a child Godot under the movie writer. The movie is as big as the project's viewport setting,
## so the children get 1920x1080 (and the MJPEG quality) from a temporary override.cfg.
func _film_all(shots: PackedStringArray, takes: int) -> void:
	var cfg := ProjectSettings.globalize_path("res://override.cfg")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=%d\n" % WIDTH_PX)
	f.store_string("window/size/viewport_height=%d\n\n" % HEIGHT_PX)
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=%s\n" % MJPEG_QUALITY)
	f.close()
	var bad := 0
	for s in shots:
		for k in range(1, takes + 1):
			bad += _film_one(int(s), k)
	DirAccess.remove_absolute(cfg)
	print("PITCH_ALL failed=%d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## One take, its child behind tools/pitch_take_filter.sh (OS.execute keeps all of a child's output in one String and a
## movie child once printed over 2 GB, so the filter trims it; it also kills a take whose movie stops growing for
## max(STALL_X x the shot's length, STALL_MIN_S) s, rc 124). Returns 1 when the child failed or wrote no movie,
## and the next take goes on (keeps_movie: a child that crashed only after PITCH_DONE keeps its movie). (A script
## file: OS.execute runs through a shell that would expand `$` in an argument.)
func _film_one(s: int, k: int) -> int:
	var stem := "shot%d_take%d" % [s, k]
	var movie := dir.path_join(stem + ".avi")
	var args := [
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--rendering-driver",
		"vulkan",
		"--audio-driver",
		"Dummy",
		"--resolution",
		"%dx%d" % [WIDTH_PX, HEIGHT_PX],
		"--fixed-fps",
		str(FPS),
		"--write-movie",
		movie,
		"--"
	]
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(["--pitch-child", "--pitch-shot=%d" % s, "--pitch-take=%d" % k])
	var out: Array = []
	var stall := maxf(STALL_X * float(SECS.get(s, 0.0)), STALL_MIN_S)
	var watch := [
		ProjectSettings.globalize_path("res://tools/pitch_take_filter.sh"),
		movie,
		str(int(stall)),
		str(CHILD_LOG_LINES),
		OS.get_executable_path()
	]
	var rc := OS.execute("bash", watch + args, out)  # stderr stays the job's log: the filter's PITCH_BEAT lines
	var marks := FileAccess.open(dir.path_join(stem + ".marks"), FileAccess.WRITE)
	var marks_text := String(out[0]) if out.size() > 0 else ""
	for line in marks_text.split("\n"):
		marks.store_line(line)
		if line.begins_with("PITCH_") or line.contains("ERROR"):
			print(stem, " ", line)
	marks.close()
	var ok := keeps_movie(rc, marks_text) and FileAccess.file_exists(movie)
	if not ok:
		DirAccess.remove_absolute(movie)
	print("PITCH_TAKE %s rc=%d ok=%s" % [stem, rc, ok])
	return 0 if ok else 1


## A take is kept when its child exited cleanly, or played the whole shot (PITCH_DONE, no PITCH_FAIL) and only crashed
## on its way out; a take the watchdog killed (rc 124) never is.
static func keeps_movie(rc: int, child_out: String) -> bool:
	var done := child_out.contains("PITCH_DONE") and not child_out.contains("PITCH_FAIL")
	return rc == 0 or (done and rc != 124)


## `secs` of game time (one process frame is 1/60 s under the movie writer).
func wait(secs: float) -> void:
	for _i in roundi(secs * FPS):
		await main.get_tree().process_frame


## The shot cannot be filmed on this build (for instance a form without art yet).
func fail(why: String) -> void:
	failed = true
	print("PITCH_FAIL shot %d: %s" % [shot, why])


## The frame a part starts on, for the encoder.
func mark(what: String) -> void:
	marks[what] = Engine.get_frames_drawn()
	print("PITCH_MARK %s movie_frame=%d" % [what, Engine.get_frames_drawn()])


# ------------------------------------------------------------------ the raid shots
## A Match on the demo save with the Hunter picked; `opts` as Demo and Match.demo_opts build them. The match plays at
## its own pace (the movie writer feeds it 1/60 s a frame); shaders are compiled before the shot starts.
func _raid(opts: Dictionary) -> void:
	Demo.setup("match")
	opts["seed"] = int(opts.get("seed", SEED)) + take
	opts.merge({"arch": hunter, "cls": Arch.weight(hunter), "weapon": Arch.signature(hunter)}, true)
	await main.show_screen("match", opts)  # (returns once the loading screen is done)
	m = main.current
	if opts.get("autoplay", false):
		await m.warm_up()  # (an autoplay match skips the loading screen, which is what compiles the shaders)


## Shot 8: the real loading screen, the plan-your-drop screen and the drop; the drop mark is where the drop starts.
func _drop() -> void:
	await _raid(Match.demo_opts())
	var waited := 0.0
	while is_instance_valid(m.player) and not m.player.dropping and waited < DROP_PLAN_MAX_S:
		await wait(0.25)  # (the plan-your-drop screen comes first, then the drop)
		waited += 0.25
	mark("drop")
	await wait(SECS[8])


## Shot 9: the player is a bot (autoplay) in a small match, no drop: it loots and takes the fights it meets.
func _loot() -> void:
	var o := Match.demo_opts()
	o.merge({"teams": RAID_DUOS, "squad": 2, "total": RAID_DUOS * 2, "autoplay": true, "no_drop": true}, true)
	o.erase("blight")
	await _raid(o)
	mark("loot")
	var me := m.player
	for _i in roundi(SECS[9] * FPS):
		await main.get_tree().process_frame
		if not is_instance_valid(me) or me.dead:
			mark("knocked_out")  # the encoder cuts there and flags the take, so a run that dies is not picked
			await wait(KO_TAIL_S)
			return


## Shot 10: alone at an uplink yard as it finishes charging; walks in when it opens and rides out.
func _escape() -> void:
	var o := Match.demo_opts()
	o.merge({"teams": 2, "squad": 1, "total": 2, "no_drop": true, "length": 1e9}, true)
	await _raid(o)
	var me := m.player
	var x: Dictionary = m.exits.of_kind("outpost")[0]
	var mast: Vector3 = x["pos"]
	m.time = float(x["open_at"]) + 1.0
	m.length = m.time + CLOCK_LEFT_S
	m.exits.act(x, "start", me)
	x["prog"] = 1.0 - ESCAPE_CHARGE_LEFT * Exits.crew_rate(1) / m.exits.uplink_time(x)
	x["wave_t"] = 1e9
	me.ctrl = "idle"
	me.teleport(_ground(mast + Vector3(Exits.OUTPOST_R - 1.0, 0, 0)))  # (it charges only with a crew in the yard)
	m.set_process(false)  # stepped by hand below: the match loop ignores an idle Hunter's input
	_zoom(0.55)
	mark("escape")
	var t := 0.0
	var tail := 0.0
	while t < SECS[10] and tail < ESCAPE_TAIL_S:
		if not is_instance_valid(me):
			break  # (the match has sent the extracted Hunter on to the results)
		var to: Vector3 = mast - me.pos
		var go := String(x["state"]) == "open" and to.length() > 0.4
		me.inp["move"] = Vector2(to.x, to.z).normalized() if go else Vector2.ZERO
		_step_frame(mast)
		await main.get_tree().process_frame
		t += 1.0 / FPS
		if is_instance_valid(me) and me.extracted:
			tail += 1.0 / FPS
	if is_instance_valid(me) and not me.extracted:
		fail("the Hunter did not get out within %d s" % int(SECS[10]))


## One 1/60 s step of a match that is stepped by hand, with the camera on `at`.
func _step_frame(at: Vector3) -> void:
	_purge()
	m.step(1.0 / FPS)
	_leash()
	if hold_zoom > 0.0 and "--fit" in OS.get_cmdline_user_args():
		at = _fit(at) + Vector3(0, 0, float(_arg("--lift=", "0")))  # (+z: up the screen, clear of the HUD bar)
	if hold_zoom > 0.0:
		var z := maxf(hold_zoom, fit_zoom)
		m.cam.user_zoom = z  # (the match camera re-reads the wheel's zoom each frame)
		m.cam.zoom = z
		m.cam.zoom_to = z
	m.cam.snap(at)
	for h in m.hunters:
		h.render(1.0 / FPS, 1.0)
	if "--clean-look" in OS.get_cmdline_user_args():
		PitchClean.frame(m)


## `--leash=<m>`: no fighter leaves the circle that wide round the spot `_roomy_ground` picked (a bot that kites would
## run the fight off the open ground); one further off than FIT_FAR_M is parked, not fighting. `--pair=<m>` then keeps
## every fighter within that many m of the pair's middle (a kiting bot pulled the camera out).
func _leash() -> void:
	var r := float(_arg("--leash=", "0"))
	if r <= 0.0 or spot_at == Vector3.INF:
		return
	var near: Array[Hunter] = []
	for h: Hunter in squad_a + squad_b:
		if is_instance_valid(h) and not h.out and h.flat_dist(m.player) < FIT_FAR_M:
			near.append(h)
	for h in near:
		h.pos = _clamp_to(h.pos, spot_at, r)
	var pair := float(_arg("--pair=", "0"))
	if pair > 0.0 and near.size() > 1:
		var mid := Vector3.ZERO
		for h in near:
			mid += h.pos / near.size()
		for h in near:
			h.pos = _clamp_to(h.pos, mid, pair)


## `p` moved flat onto the circle `r` m round `c` when it is outside it.
func _clamp_to(p: Vector3, c: Vector3, r: float) -> Vector3:
	var d := Vector2(p.x - c.x, p.z - c.z)
	if d.length() <= r:
		return p
	d = d.normalized() * r
	return Vector3(c.x + d.x, p.y, c.z + d.y)


## `--fit`: the eased focus for `at`, and fit_zoom eased so every fighter still up is inside the frame with a margin
## (the cut zooms in to 1.08 more). Pulls out fast, comes back in slowly.
func _fit(at: Vector3) -> Vector3:
	if fit_at == Vector3.INF or fit_at.distance_to(at) > 8.0:
		fit_at = at
	fit_at = fit_at.lerp(at, 1.0 - exp(-FIT_FOLLOW / FPS))
	var want := hold_zoom
	for h: Hunter in squad_a + squad_b:
		if not is_instance_valid(h) or h.out or h.flat_dist(m.player) > FIT_FAR_M:
			continue
		want = maxf(want, (absf(h.pos.x - fit_at.x) + FIT_PAD_X) / FIT_HALF.x)
		want = maxf(want, (absf(h.pos.z - fit_at.z) + FIT_PAD_Z) / FIT_HALF.y)
	want = minf(want, float(_arg("--fit-max=", str(FIT_MAX))))
	var rate := 9.0 if want > fit_zoom else 1.2
	fit_zoom = want if fit_zoom <= 0.0 else lerpf(fit_zoom, want, 1.0 - exp(-rate / FPS))
	m.set_meta("zoom_hold", fit_zoom)
	return fit_at


# ------------------------------------------------------------------ shot 7: the kit
## The Hunter against one bot Hunter from another kit: attack held, then right click, then utility, round again.
## Stepped by hand at 1/60 s a frame (the base clips' way) so the abilities land on the rota exactly.
func _kit() -> void:
	Save.d["first_guide"] = 99
	Settings.v["damage_numbers"] = false
	await _start(hunter, "cindle")
	m.length = m.time + CLOCK_LEFT_S
	var me := m.player
	me.ctrl = "idle"
	var base := _roomy_ground(me.pos)
	me.pos = base
	var foe_arch := String(Arch.ids()[(Arch.ids().find(hunter) + 3) % Arch.ids().size()])
	foe_arch = _arg("--foe=", foe_arch)
	var gap := float(_arg("--gap=", str(KIT_GAP_M)))
	var foe := _hunter("b0", 1, foe_arch, "pebbit", _ground(base + Vector3(gap, 0, 0)))
	foe.ai = m.bot_brain.new_mind(m.rng, KIT_FOE_SKILL, m.bot_cfg)
	squad_a = [me]
	squad_b = [foe]
	for h in squad_a + squad_b:
		h.teleport(h.pos)
	var kz := float(_arg("--zoom=", str(KIT_ZOOM)))
	m.set_meta("zoom_hold", kz)  # the match camera re-reads its zoom every frame; this holds it
	hold_zoom = kz
	_clean_take()
	_zoom(kz)
	if "--no-hud" in OS.get_cmdline_user_args():
		Record.set_level(2)  # (the HUD bar sat over the Hunter in the low half of the frame)
	mark("kit")
	var t := 0.0
	while t < SECS[7]:
		_purge()
		m.hud.msgs.clear()
		_kit_press(t, me, foe, base)
		_step_frame(me.pos.lerp(foe.pos, 0.5))
		await main.get_tree().process_frame
		t += 1.0 / FPS


## No game text a take must not show: the locked chest's "needs a key" prompt (chests freed), tips, the objective card,
## the numeral / BURNING plate over the foe (HudPlate.hidden).
func _clean_take() -> void:
	Settings.v["tips"] = false
	for c in m.chests:
		if is_instance_valid(c.get("node")):
			(c["node"] as Node).queue_free()
	m.chests.clear()
	m.objective = null
	m.set_meta("pitch_no_foe_plates", true)
	m.set_meta("pitch_soft_flash", true)  # (Ent.show_flash: hits tint the body, never turn it white)
	m.set_meta("pitch_no_chill_shell", true)  # (StatusLooks: no pale ice shell over a chilled body)
	if "--clean-look" in OS.get_cmdline_user_args():
		Settings.v["damage_numbers"] = false  # (big hit numbers sat over the fighters; the kit shots never had them)
	_crisp_shadows()


## The recording build's shadows: the Ultra preset, then an 8k sun map with the softest filter over a sun range
## cut to SHADOW_M (the top-down camera sees ~40 m; the preset's long range smeared it into stair-steps).
func _crisp_shadows() -> void:
	Settings.v["quality"] = "ultra"
	Settings.apply("quality")
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	main.get_viewport().positional_shadow_atlas_size = 8192
	for n in main.get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		var dl := n as DirectionalLight3D
		if dl.shadow_enabled:
			dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			dl.directional_shadow_max_distance = minf(dl.directional_shadow_max_distance, SHADOW_M)


## The value of the `--name=` user arg, else `dflt`.
func _arg(name: String, dflt: String) -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with(name):
			return String(a).substr(name.length())
	return dflt


## The ground nearest `p` (+ `--off=x,z` m) with solid ground `--room=` m all round (no map edge in the frame) and no
## hazard area (lava, static flats...) as near; with `--open=<m>` the clearest such spot in reach instead (fewest trees,
## rocks, walls and tall-grass tiles within that many m: no canopy or grass hides the fight), nearest on a tie, only on
## the ground `--biome=` / `--island=` name when given;
## `p` with the old KIT_ROOM_M rule when no spot that clear is within reach.
func _roomy_ground(p: Vector3) -> Vector3:
	var off := _arg("--off=", "0,0").split(",")
	p += Vector3(float(off[0]), 0, float(off[1]))
	var room := int(_arg("--room=", str(KIT_ROOM_M)))
	var reach := int(_arg("--search=", str(KIT_SEARCH_M)))
	var open_m := int(_arg("--open=", "0"))
	var biomes := _arg("--biome=", "").split(",", false)
	var isles := _arg("--island=", "").split(",", false)
	var best := Vector3.INF
	var best_d := INF
	var best_c := INF
	for dz in range(-reach, reach + 1, 2):
		for dx in range(-reach, reach + 1, 2):
			var x := int(p.x) + dx
			var z := int(p.z) + dz
			var d := float(dx * dx + dz * dz)
			if not (m.world.inb(x, z) and m.world.edge_dist(x, z, room) > room):
				continue
			if not _on_ground_of(x, z, biomes, isles):
				continue
			var c := _clutter(x, z, open_m) if open_m > 0 else 0.0
			if (c < best_c or (c == best_c and d < best_d)) and not _hazard_near(x, z, room):
				best = Vector3(x + 0.5, 0.0, z + 0.5)
				best_d = d
				best_c = c
	print(
		(
			"PITCH_SPOT room=%d open=%d clutter=%s found=%s off=%.0f m at=%s biome=%s island=%s"
			% [
				room,
				open_m,
				best_c,
				best != Vector3.INF,
				sqrt(best_d),
				best,
				m.world.biome_at(best.x, best.z) if best != Vector3.INF else "-",
				m.world.island_of(best.x, best.z) if best != Vector3.INF else -1
			]
		)
	)
	if best == Vector3.INF and not (biomes.is_empty() and isles.is_empty()):
		fail("no roomy ground on --biome=%s --island=%s" % [biomes, isles])
	if best != Vector3.INF:
		spot_at = best
		var clear := float(_arg("--clear=", "0"))  # m of map dressing hidden round the fight (PitchClean)
		if clear > 0.0:
			print("PITCH_CLEAR r=%.0f hidden=%d" % [clear, PitchClean.clear_deco(m, best, clear)])
		return _ground(best)
	for dz in range(-KIT_SEARCH_M, KIT_SEARCH_M + 1):
		for dx in range(-KIT_SEARCH_M, KIT_SEARCH_M + 1):
			var x := int(p.x) + dx
			var z := int(p.z) + dz
			var d := float(dx * dx + dz * dz)
			if d < best_d and m.world.inb(x, z) and m.world.edge_dist(x, z, KIT_ROOM_M) > KIT_ROOM_M:
				best = Vector3(x + 0.5, 0.0, z + 0.5)
				best_d = d
	return _ground(best if best != Vector3.INF else p)


## Whether (x, z) is on one of `biomes` (content/biomes ids; `--biome=`) and `isles` (island indexes; `--island=`); an
## empty list allows every one.
func _on_ground_of(x: int, z: int, biomes: PackedStringArray, isles: PackedStringArray) -> bool:
	if not biomes.is_empty() and not m.world.biome_at(x + 0.5, z + 0.5) in biomes:
		return false
	return isles.is_empty() or str(m.world.island_of(x + 0.5, z + 0.5)) in isles


## How cluttered the ground within `r` m of (x, z) is: 3 a tree, rock or wall tile, 2 a void or other-terrace
## tile (a cliff or wall face hides the fight), 1 a tall-grass tile.
func _clutter(x: int, z: int, r: int) -> float:
	var w: World = m.world
	var lv := w.level[w.idx(x, z)]
	var isl := w.island[w.idx(x, z)]
	var c := 0.0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r or not w.inb(x + dx, z + dz):
				continue
			var i := w.idx(x + dx, z + dz)
			if w.kind[i] == World.T_BLOCK:
				c += 3.0
			elif w.kind[i] == World.T_VOID or w.level[i] != lv or w.island[i] != isl:
				c += 2.0
			elif w.bush.has(i) or w.paint.has(i) or w.props.has(i) or w.stairs.has(i):
				c += 1.0
	return c


## A terrain hazard area (TerrainHazards) on any tile within `r` m of (x, z) (sampled every 2 m).
func _hazard_near(x: int, z: int, r: int) -> bool:
	var tz := TerrainHazards.of(m)
	if tz == null or tz.cell.is_empty():
		return false
	for dz in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			if dx * dx + dz * dz <= r * r and m.world.inb(x + dx, z + dz) and tz.cell[m.world.idx(x + dx, z + dz)] > 0:
				return true
	return false


## Aims at the foe, walks back when it strays from `base`, and presses: attack held for the first part of each
## beat, then the right click, then the utility.
func _kit_press(t: float, me: Hunter, foe: Hunter, base: Vector3) -> void:
	me.hp = me.max_hp  # neither of them goes down or walks off: the shot is about the kit
	foe.hp = foe.max_hp
	var reach := float(_arg("--reach=", str(KIT_FOE_REACH)))
	if me.flat_dist(foe) > reach:
		foe.teleport(_ground(me.pos + (foe.pos - me.pos).normalized() * minf(KIT_GAP_M, reach)))
	me.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
	var back := Vector2(base.x - me.pos.x, base.z - me.pos.z)
	me.inp["move"] = back.normalized() if back.length() > KIT_LEASH_M else Vector2.ZERO
	var beat := fmod(t, KIT_ROTA_S * 3.0) / KIT_ROTA_S
	me.inp["fire"] = beat < 1.0
	if me.ak == null or t < 0.3:
		return
	var step := 1.0 / FPS
	var at := fmod(t, KIT_ROTA_S)
	if beat >= 1.0 and beat < 2.0 and at < step:
		me.ak.press_rmb()
	elif beat >= 2.0 and at < step:
		me.ak.use_e()
