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
const MJPEG_QUALITY := 0.85      # 1.0 is huge at 1080p60; 0.85 holds up to the H.264 encode
const KIT_ROTA_S := 2.1          # s between a Hunter's ability presses in the kit shot
const KIT_FOE_SKILL := 0.5       # the foe bot's skill (0..1): it fights back but does not hunt the Hunter down
## s of each shot that runs for a set time (the others run to the end of their script: 2, 3, 6)
const SECS := {4: 60.0, 7: 24.0, 8: 22.0, 9: 180.0, 10: 34.0}
const RAID_DUOS := 3             # shot 9: teams of two
const ESCAPE_CHARGE_LEFT := 4.0  # s of the uplink's charge left when shot 10 starts
const CLOCK_LEFT_S := 840.0      # s on the match clock when a stepped shot starts (1e9 reads as junk)
const KIT_GAP_M := 4.5          # m between the Hunter and its foe in the kit shot (both well inside the frame)
const KIT_ZOOM := 0.85           # the kit shot's camera zoom (0.55 frames only ~8 m: the pair sat on the frame's edges)
const KIT_FOE_REACH := 7.0       # m: a foe that has walked further than this from the Hunter is put back at the fight
const DROP_PLAN_MAX_S := 25.0    # s shot 8 waits for the plan-your-drop screen to hand over to the drop
const ESCAPE_TAIL_S := 2.5       # s of the ride out kept after the Hunter is extracted

var shot := 2
var take := 1
var hunter := Demo.DEFAULT_HUNTER
var failed := false             # a shot that cannot be filmed on this build says so (fail()), and the take is dropped
var marks := {}                 # part -> the frame it started on (mark())

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
		2: await farm.hatch(take)
		3: await farm.evolve()
		4: await farm.farm_loop(SECS[4])
		6: await farm.hunter_select(hunter)
		7: await _kit()
		8: await _drop()
		9: await _loot()
		10: await _escape()

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

## One take; returns 1 when the child failed or wrote no movie.
func _film_one(s: int, k: int) -> int:
	var stem := "shot%d_take%d" % [s, k]
	var movie := dir.path_join(stem + ".avi")
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-driver", "vulkan",
		"--audio-driver", "Dummy", "--resolution", "%dx%d" % [WIDTH_PX, HEIGHT_PX], "--fixed-fps", str(FPS),
		"--write-movie", movie, "--"]
	args.append_array(OS.get_cmdline_user_args())
	args.append_array(["--pitch-child", "--pitch-shot=%d" % s, "--pitch-take=%d" % k])
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	var marks := FileAccess.open(dir.path_join(stem + ".marks"), FileAccess.WRITE)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("PITCH_") or line.contains("ERROR"):
			print(stem, " ", line)
			marks.store_line(line)
	marks.close()
	var ok := rc == 0 and FileAccess.file_exists(movie)
	if rc != 0:
		DirAccess.remove_absolute(movie)
	print("PITCH_TAKE %s rc=%d ok=%s" % [stem, rc, ok])
	return 0 if ok else 1

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
	await main.show_screen("match", opts)      # (returns once the loading screen is done)
	m = main.current
	if opts.get("autoplay", false):
		await m.warm_up()      # (an autoplay match skips the loading screen, which is what compiles the shaders)

## Shot 8: the real loading screen, the plan-your-drop screen and the drop; the drop mark is where the drop starts.
func _drop() -> void:
	await _raid(Match.demo_opts())
	var waited := 0.0
	while is_instance_valid(m.player) and not m.player.dropping and waited < DROP_PLAN_MAX_S:
		await wait(0.25)      # (the plan-your-drop screen comes first, then the drop)
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
	await wait(SECS[9])

## Shot 10: alone at an uplink yard as it finishes charging; walks in when it opens and rides out.
func _escape() -> void:
	var o := Match.demo_opts()
	o.merge({"teams": 2, "squad": 1, "total": 2, "no_drop": true, "length": 1e9}, true)
	await _raid(o)
	var P := m.player
	var x: Dictionary = m.exits.of_kind("outpost")[0]
	var mast: Vector3 = x["pos"]
	m.time = float(x["open_at"]) + 1.0
	m.length = m.time + CLOCK_LEFT_S
	m.exits.act(x, "start", P)
	x["prog"] = 1.0 - ESCAPE_CHARGE_LEFT * Exits.crew_rate(1) / m.exits.uplink_time(x)
	x["wave_t"] = 1e9
	P.ctrl = "idle"
	P.teleport(_ground(mast + Vector3(Exits.OUTPOST_R - 1.0, 0, 0)))      # (it charges only with a crew in the yard)
	m.set_process(false)      # stepped by hand below: the match loop ignores an idle Hunter's input
	_zoom(0.55)
	mark("escape")
	var t := 0.0
	var tail := 0.0
	while t < SECS[10] and tail < ESCAPE_TAIL_S:
		if not is_instance_valid(P):
			break      # (the match has sent the extracted Hunter on to the results)
		var to: Vector3 = mast - P.pos
		var go := String(x["state"]) == "open" and to.length() > 0.4
		P.inp["move"] = Vector2(to.x, to.z).normalized() if go else Vector2.ZERO
		_step_frame(mast)
		await main.get_tree().process_frame
		t += 1.0 / FPS
		if is_instance_valid(P) and P.extracted:
			tail += 1.0 / FPS
	if is_instance_valid(P) and not P.extracted:
		fail("the Hunter did not get out within %d s" % int(SECS[10]))

## One 1/60 s step of a match that is stepped by hand, with the camera on `at`.
func _step_frame(at: Vector3) -> void:
	_purge()
	m.step(1.0 / FPS)
	m.cam.snap(at)
	for h in m.hunters:
		h.render(1.0 / FPS, 1.0)

# ------------------------------------------------------------------ shot 7: the kit
## The Hunter against one bot Hunter from another kit: attack held, then right click, then utility, round again.
## Stepped by hand at 1/60 s a frame (the base clips' way) so the abilities land on the rota exactly.
func _kit() -> void:
	Save.d["first_guide"] = 99
	await _start(hunter, "cindle")
	m.length = m.time + CLOCK_LEFT_S
	var P := m.player
	P.ctrl = "idle"
	var base := _ground(P.pos)
	var foe_arch := String(Arch.ids()[(Arch.ids().find(hunter) + 3) % Arch.ids().size()])
	var foe := _hunter("b0", 1, foe_arch, "pebbit", _ground(base + Vector3(KIT_GAP_M, 0, 0)))
	foe.ai = m.bot_brain.new_mind(m.rng, KIT_FOE_SKILL, m.bot_cfg)
	squad_a = [P]
	squad_b = [foe]
	for h in squad_a + squad_b:
		h.teleport(h.pos)
	_zoom(KIT_ZOOM)
	mark("kit")
	var t := 0.0
	while t < SECS[7]:
		_purge()
		_kit_press(t, P, foe)
		_step_frame(P.pos.lerp(foe.pos, 0.5))
		await main.get_tree().process_frame
		t += 1.0 / FPS

## Aims at the foe and presses: attack held for the first part of each beat, then the right click, then the utility.
func _kit_press(t: float, P: Hunter, foe: Hunter) -> void:
	P.hp = P.max_hp      # neither of them goes down or walks off: the shot is about the kit
	foe.hp = foe.max_hp
	if P.flat_dist(foe) > KIT_FOE_REACH:
		foe.teleport(_ground(P.pos + (foe.pos - P.pos).normalized() * KIT_GAP_M))
	P.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
	var beat := fmod(t, KIT_ROTA_S * 3.0) / KIT_ROTA_S
	P.inp["fire"] = beat < 1.0
	if P.ak == null or t < 0.3:
		return
	var step := 1.0 / FPS
	var at := fmod(t, KIT_ROTA_S)
	if beat >= 1.0 and beat < 2.0 and at < step:
		P.ak.press_rmb()
	elif beat >= 2.0 and at < step:
		P.ak.use_e()
