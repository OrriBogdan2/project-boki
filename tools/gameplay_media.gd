extends RefCounted
## --gameplay-media --media-clip=<1-4> --shots-dir=<dir> [--media-secs=<s>] [--media-size=1920x1080]: scripted,
## seeded gameplay for the website clips and stills (HUD on, recording mode "clean" so no debug text). It runs the
## scene again as a child Godot under the movie writer at a fixed 30 fps, which writes <dir>/clip<N>.avi and a still
## from the scene's best moment (<dir>/clip<N>.png). Run it on a GPU worker (jobq), then cut and encode the AVI with
## tools/gameplay_media.sh. MEDIA_MARK lines give the frame each phase starts on. (--media-child: the scene alone.)
##   1 squad fight   three Hunters with their Boki against a rival squad, abilities going off
##   2 Boki combat   a Boki fighting beside its Hunter against wild monsters
##   3 extraction    the squad holds an uplink's yard as it finishes charging, then rides the lift out
##   4 hatch         an egg hatching and the Boki finding you (EggHatch, then KinReveal)
##   5 tumble        a Tumble on the Boki base (base_tumble.gd): tells, picks that read them, presses in the gold
##   6 echo steps    Echo Steps (echo_steps.gd): the first round answered on the beat, then every third stone wrong
##   7 show ring     the Show Ring (show_ring.gd) from the end of the Look: three presses in the gold, a call at each
##                   lure (the walk cut between them), the judges' reveal and the crowd, then the result
##   8 relay cup     the Relay Cup (base_relay.gd): a great hand-off, a missed one, both teams home
##   9 base to mate  B (BaseWheel, BaseRecall): hold for the wheel, point, let go, the 5.5 s channel lands beside
##                   the teammate; then a second channel that a rival's hit breaks (INTERRUPTED). Its own length.
## Never writes the save. The names come from the Hunters' own archetype data (Vex, Kael, Cinder ...).

const STEP := 1.0 / 60.0         # s per match step; two steps make one 30 fps video frame
const MATE_GAP := 13.0           # m from the player to each teammate (far enough that the teleport reads)
const FRAME := 2.0 * STEP        # s per rendered frame
const SEED := 5                  # the demo map's roll (Dusk Isles)
const FIGHT_GAP := 7.0           # m between the two squads at the start
const CHARGE_LEFT := 2.5         # s of the uplink's charge left when the clip starts
const ASSIST_EVERY := 2.4        # s between a Hunter's scripted ability presses (the bots use few on their own)
const TUMBLE_STAND := 2.2        # m south of the Tumble ring the player watches from
const TUMBLE_ZOOM := 0.4         # the home camera's zoom for clip 5 (closer than the usual 1.0)
const GAME_ZOOM := 0.55          # the home camera's zoom for clips 6-8
const LURE_LEAD := 1.5           # s of the Show Ring walk kept before each lure (clip 7 cuts the rest)
const JUDGE_HOLD := 4.0          # s of the judges' cards clip 7 keeps before the result

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
		5: await _tumble(secs)
		6: await _echo(secs)
		7: await _show(secs)
		8: await _relay(secs)
		9: await _base_tp()
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

## Frames the shot at once (the camera would otherwise ease in from the default over several seconds).
func _zoom(z: float) -> void:
	m.cam.zoom = z
	m.cam.zoom_to = z

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
	_zoom(0.55)
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
	_zoom(0.4)
	still_at = 3.5
	await _go(secs, func(_t: float): pass, func(_t: float): return (P.pos + P.kin.pos) * 0.5)

# ------------------------------------------------------------------ 3: extraction
func _extraction(secs: float) -> void:
	await _start("ashwick", "cindle")
	var P := m.player
	var o: Dictionary = m.exits.of_kind("outpost")[0]
	var mast: Vector3 = o["pos"]
	m.time = float(o["open_at"]) + 1.0
	m.exits.act(o, "start", P)
	o["prog"] = 1.0 - CHARGE_LEFT * Exits.crew_rate(3) / m.exits.uplink_time(o)
	o["wave_t"] = 1e9       # no monster waves at the yard
	squad_a = [P, _hunter("a1", 0, "juggernaut", "pebbit", mast), _hunter("a2", 0, "gunslinger", "zapple", mast)]
	for i in squad_a.size():
		var h: Hunter = squad_a[i]
		h.ctrl = "idle"
		var ang := TAU * i / squad_a.size()
		h.teleport(_ground(mast + Vector3(cos(ang), 0, sin(ang)) * (Exits.OUTPOST_R - 1.0)))
	_zoom(0.55)
	still_at = secs * 0.6
	await _go(secs, func(_t: float):
		for h in squad_a:
			var to: Vector3 = mast - h.pos
			var go := String(o["state"]) == "open" and to.length() > 0.4
			h.inp["move"] = Vector2(to.x, to.z).normalized() if go else Vector2.ZERO,
		func(_t: float): return mast)

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

# ------------------------------------------------------------------ the Boki base
## A fresh base with `n` rested level-6 Boki out (Ember, Ripple, Moss), `stats` per Boki when given, and the player
## standing south of `at` (a Callable: the game's spot, placed once the home is built) at camera zoom `zoom`.
func _base(n: int, at: Callable, zoom: float, stats: Array = []) -> Node:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in n:
		var k := Save.new_kin(["cindle", "puddlet", "zapple"][i], ["Ember", "Ripple", "Moss"][i], 11 + i)
		k["level"] = 6
		if not stats.is_empty():
			k["stats"] = stats[i]
		k["needs"]["energy"] = 95.0
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	while not is_instance_valid(home.root_ui):
		await main.get_tree().process_frame
	home._close_panel()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	for e in home.kins:
		e.erase("indoors")
	home.ppos = at.call(home) + Vector3(0.0, 0.0, TUMBLE_STAND)
	home.player.position = home.ppos
	home.cam.zoom = zoom
	home.cam.zoom_to = zoom
	home.cam.snap(home.ppos)
	return home

## Films a base minigame (the home ticks it) for `secs` or until `over` is true; `each(t)` scripts the presses.
func _film(secs: float, each: Callable, over: Callable) -> void:
	still_at = secs * 0.55
	_mark("start")
	var t := 0.0
	while t < secs and not over.call():
		await main.get_tree().process_frame
		each.call(t)
		if still_at >= 0.0 and t >= still_at:
			_still()
			still_at = -1.0
		t += FRAME
		frame += 1
	for _i in 30:                     # a second more for the result's fanfare and huff
		await main.get_tree().process_frame

func _press(game, action := "interact") -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	game.input(ev)

## Two rested Boki on a fresh base; the clip opens as the first tell shows. The scripted player picks the move
## that beats the tell a moment after it, and presses as the marker crosses the gold.
func _tumble(secs: float) -> void:
	var home = await _base(2, func(hm): return hm.htumble.ring.position, TUMBLE_ZOOM, [
		{"power": 42, "guard": 20, "speed": 30, "focus": 36}, {"power": 18, "guard": 38, "speed": 34, "focus": 22}])
	var tb: BaseTumble = home.htumble
	tb.use()
	tb.run.left = FRAME
	still_at = secs * 0.55
	_mark("start")
	var t := 0.0
	var picked_at := -1.0
	while t < secs and tb.run != null:
		await main.get_tree().process_frame
		var r := tb.run
		if r != null and r.state == "pick" and r.pick == "":
			picked_at = t if picked_at < 0.0 else picked_at
			if t - picked_at > 0.7:
				tb._choose(BaseTumble.rules()["moves"].keys().find(BaseTumble.counter(r.tell)))
				picked_at = -1.0
		elif r != null and r.state == "resolve" and r.grade == "" and absf(tb.bar.m - tb.bar.zone) < TimingBar.GREAT:
			_press(tb)
		if still_at >= 0.0 and t >= still_at:
			_still()
			still_at = -1.0
		t += FRAME
		frame += 1

## Two dancers: the first round answered on each beat, from the second on every third stone is the wrong one.
func _echo(secs: float) -> void:
	var home = await _base(2, func(hm): return hm.hecho.middle.position, GAME_ZOOM)
	var es: EchoSteps = home.hecho
	es.use()
	var each := func(_t: float) -> void:
		var r := es.run
		if r == null or not r.mine():
			return
		var now := es._clock()
		for i in r.pattern.size():
			var pt := r.at(r.first + i)
			if not r.done[i] and now >= pt and now - pt < r.window * 0.5:
				var s: int = i % 4 if r.pattern[i] < 0 else r.pattern[i]
				_press(es, EchoSteps.KEYS[(s + 1) % 4 if r.round_i > 0 and i % 3 == 2 else s])
	await _film(secs, each, func(): return es.run == null)

## Two Boki from the end of the Look round: three presses in the gold, a call at each lure, the judges' cards.
func _show(secs: float) -> void:
	var home = await _base(2, func(hm): return hm.hshow.stage.position, GAME_ZOOM)
	var sr: ShowRing = home.hshow
	sr.use()
	sr.run.t = float(ShowRing.rules()["look_s"]) - 2.0
	var each := func(_t: float) -> void:
		var r := sr.run
		if r == null:
			return
		if r.can_trick() and r.t > 1.0 and absf(sr.bar.m - sr.bar.zone) < TimingBar.GREAT:
			_press(sr)
		elif r.phase == ShowRing.Run.Phase.BOND:
			var next := r.calls.find("")
			if next < 0:
				r.t = maxf(r.t, float(ShowRing.rules()["walk_s"]) - FRAME)
			elif r.t >= r.lure_t(next):
				_press(sr)
			else:
				r.t = maxf(r.t, r.lure_t(next) - LURE_LEAD)
		elif r.phase == ShowRing.Run.Phase.JUDGE and r.t > JUDGE_HOLD:
			r.t = float(ShowRing.rules()["judge_s"])
	await _film(secs, each, func(): return sr.run == null)

## Three of yours against a visiting team: the first hand-off in the gold, the second pressed far off it.
func _relay(secs: float) -> void:
	var home = await _base(3, func(hm): return hm.hrace.start, GAME_ZOOM * 1.6)
	var rc: BaseRelay = home.hrace.relay
	rc.use()
	var each := func(_t: float) -> void:
		var r := rc.run
		if r == null or not r.can_press():
			return
		var off := absf(rc.bar.m - rc.bar.zone)
		if (r.grades.is_empty() and off < TimingBar.GREAT) or (r.grades.size() == 1 and off > TimingBar.GOOD * 2.0):
			_press(rc)
	await _film(secs, each, func(): return rc.run == null)

# ------------------------------------------------------------------ 9: base to a teammate

func _base_tp() -> void:
	await _start("ashwick", "cindle")
	var me := m.player
	me.ctrl = "local"
	var base := _ground(me.pos)
	var mates := [_hunter("a1", me.team, "juggernaut", "pebbit", _ground(base + Vector3(MATE_GAP, 0, -3.0))),
			_hunter("a2", me.team, "gunslinger", "zapple", _ground(base + Vector3(-3.0, 0, MATE_GAP)))]
	for h in mates:
		h.ctrl = "idle"
		h.teleport(h.pos)
	_zoom(0.75)
	still_at = 4.5
	_mark("take1")
	await _wheel_take(me, mates[0], 1.0, base)
	await _go(1.5, func(_t: float): me.inp["move"] = Vector2.ZERO, func(_t: float): return me.pos)
	# take 2: back where we started, a rival close by, and its hit breaks the channel 2 s in
	me.teleport(base)
	me.base_cd = 0.0
	me.weak_t = 0.0
	var foe := _hunter("b0", 1 - me.team, "archer", "wisplet", _ground(base + Vector3(-4.0, 0, -5.0)))
	foe.ctrl = "idle"
	foe.teleport(foe.pos)
	_mark("take2")
	await _wheel_take(me, mates[1], 2.0, base, foe)
	await _go(2.5, func(_t: float): me.inp["move"] = Vector2.ZERO, func(_t: float): return me.pos)

## Opens the wheel, sweeps to `to`'s slice, lets go, then films the channel; with a `foe`, it shoots the
## player `hit_at` s in (and a hit lands then for sure), else the channel runs to the end.
func _wheel_take(me: Hunter, to: Hunter, hit_at: float, base: Vector3, foe: Hunter = null) -> void:
	var o := main.get_viewport().get_visible_rect().size * 0.5 + Vector2(0, 40)
	var mates := BaseRecall.mates(m, me)
	var slice := BaseWheel.dir(mates.find(to), mates.size()) * 110.0
	var still := func(_t: float): me.inp["move"] = Vector2.ZERO
	await _go(0.6, still, func(_t: float): return base)
	BaseWheel.open(me, o, mates)
	await _go(1.2, func(t: float):
		me.inp["move"] = Vector2.ZERO
		BaseWheel.update(me, o + slice * clampf((t - 0.3) / 0.5, 0.0, 1.0), FRAME),
		func(_t: float): return base)
	me.inp["base_pick"] = BaseWheel.close(me)
	var hit := [false]
	var span := BaseRecall.CHANNEL_S + 0.2 if foe == null else hit_at + 0.1
	await _go(span, func(t: float):
		me.inp["move"] = Vector2.ZERO
		if foe and t >= hit_at - 0.35 and not hit[0]:
			hit[0] = true
			foe.inp["aim"] = me.pos + Vector3(0, 0.9, 0)
			foe.ak.press_rmb()
		if foe and t >= hit_at and me.base_t > 0.0:
			me.hurt(6.0, foe, {"src": "media"}),
		func(_t: float): return (me.pos + to.pos) * 0.5 if me.base_t > 0.0 else me.pos)
