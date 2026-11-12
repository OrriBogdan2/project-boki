extends RefCounted
## --garden-sfx-check: the garden minigame sounds (scripts/home/garden_sfx.gd, docs/AUDIO.md), each cue once per event.
##   1. the names: three grades, three sizes (small, medium, large from the Boki's size tag), every file exists
##   2. the Stump Shove: a three-beat countdown (tick, tick, go), one crowd cheer for the press (perfect), one
##      thump at most, one win fanfare and one loser huff in the winner's and loser's size
##   3. the Dash: a good, a perfect and a missed press each play their own crowd cheer once; one finish
##      swish per runner and one crowd for the first home; one fanfare and one huff
##   4. Seek: the sniffing loop starts once per hunt and stops with it; one fanfare and one huff
##   5. Spark Volley: one seed bat per hit; the spike call's crowd cheer; one fanfare and one huff
##   6. Tumble: the rival's plans are set so each move decides one exchange; one clash in the deciding move per
##      exchange, one push scuff per exchange won, one ring-out when the loser leaves the ring, fanfare and huff
##   7. Echo Steps: the stone notes stay generated; one hit sparkle per hit, one miss per miss, one streak run at
##      every cheer_every hits in a row (counted from the dance's own events), the start and the finish
##   8. the Show Ring: a crowd cheer for each trick press and lure call, the judges' reveal once on the judging
##      round and the crowd once after it, fanfare and huff
##   9. the Relay Cup: per team, one clean or fumbled hand-off sound per hand-off (by the seconds it lost), one
##      finish per team home, fanfare and huff
##  10. home chimes (home_chimes.gd): a stat, a level and a new form each chime once; a drill that lands a
##      stat and a level together (and one 0.3 s later) is one chime; nothing while the Boki sleeps; a
##      small Boki chimes higher than a large one
## Never touches the real save.

const SETTLE_FRAMES := 900       # frames to wait at most for the home to build
const SIM_S := 400.0             # s of game time at most for one game
const WAIT_S := 1.4              # real s for the countdown and the loser's huff to land

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("GARDENSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_names()
	await _games()
	print("GARDENSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["needs"]["energy"] = 90.0
	return k

func _names() -> void:
	var sized := {}
	for z in [-2.5, -1.0, 0.0, 1.0, 2.5]:
		var rec := {"dna": {"seed": 1, "size": z}}
		sized[Unique.size_tag(rec)] = GardenSfx.SIZE[Unique.size_tag(rec)]
	var want := ["small", "small", "medium", "large", "large"]
	ok(sized.values() == want, "sizes: XS S M L XL read %s" % [want])
	var silent := []
	for p in ["garden_cheer_", "garden_win_", "garden_sulk_"]:
		for tail in (GardenSfx.GRADE if p == "garden_cheer_" else GardenSfx.SIZE).values():
			if not Sfx.ensure(p + tail):
				silent.append(p + tail)
	ok(silent.is_empty(), "every cheer, fanfare and huff sound exists (missing %s)" % [silent])
	var cues: Array = ["tumble_push", "tumble_ringout", "echo_hit", "echo_miss", "echo_streak", "show_reveal",
			"show_crowd", "relay_handoff", "relay_fumble", "relay_finish"]
	for move in BaseTumble.rules()["moves"]:
		cues.append("tumble_clash_" + move)
	ok(cues.all(func(c): return Sfx.ensure(c)), "every Tumble, Echo Steps, Show Ring and Relay cue exists (%d)"
			% cues.size())

func _count(sname: String) -> int:
	return int(GardenSfx.heard.get(sname, 0))

func _total(prefix: String) -> int:
	var n := 0
	for k in GardenSfx.heard:
		if String(k).begins_with(prefix):
			n += int(GardenSfx.heard[k])
	return n

func _wait() -> void:
	await main.get_tree().create_timer(WAIT_S).timeout

func _press(bar: TimingBar, off: float, game) -> void:
	bar.m = clampf(bar.zone + off, 0.0, 1.0)
	var e := InputEventAction.new()
	e.action = "interact"
	e.pressed = true
	game.input(e)

## Sound after the start: tick, tick, go.
func _countdown(game: String) -> void:
	var beats := [_count("garden_count"), _count("garden_go")]
	ok(beats == [2, 1], "%s: countdown tick, tick, go (%s)" % [game, beats])

func _results(game: String) -> void:
	var got := [_total("garden_win_"), _total("garden_sulk_")]
	ok(got == [1, 1], "%s: one fanfare and one huff (%s)" % [game, got])

func _games() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	for f in ["first_shove", "first_seek", "first_volley"]:      # past the practice rounds (FirstRound)
		d["tutorial"][f] = true
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	for k in home.kins:
		k.erase("indoors")
	GardenSfx.heard.clear()
	await _shove(home)
	GardenSfx.heard.clear()
	await _dash(home)
	GardenSfx.heard.clear()
	await _seek(home)
	GardenSfx.heard.clear()
	await _volley(home)
	for game in [_tumble, _echo, _show, _relay]:
		for k in home.kins:
			k["rec"]["needs"]["energy"] = 90.0
		GardenSfx.heard.clear()
		await game.call(home)
	GardenSfx.heard.clear()
	_chimes(home)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

func _shove(home) -> void:
	var sh: BaseShove = home.hshove
	sh.use()
	_press(sh.bar, 0.0, sh)
	var t := 0.0
	while sh.run != null and t < SIM_S:
		sh.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("shove")
	var cheers := _total("garden_cheer_")
	ok(_count("garden_cheer_perfect") == 1 and cheers == 1, "shove: one perfect crowd cheer for the press")
	ok(_count("garden_thud") <= 1 and _count("garden_creak") <= 1, "shove: at most one thump and one creak")
	_results("shove")

func _dash(home) -> void:
	var race: BaseRace = home.hrace
	race.use()
	var runners: int = race.runners.size()
	var offs := [0.0, (TimingBar.GOOD + TimingBar.GREAT) * 0.5, 0.9]      # a perfect, a good and a missed press
	var t := 0.0
	while race.run != null and t < SIM_S:
		if race.run.can_cheer() and not offs.is_empty():
			_press(race.bar, offs.pop_front(), race)
		race.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("dash")
	var presses := [_count("garden_cheer_perfect"), _count("garden_cheer_good"), _count("garden_cheer_miss")]
	ok(presses == [1, 1, 1], "dash: a perfect, a good and a missed press each cheer once (%s)" % [presses])
	ok(_count("garden_finish") == runners and _count("garden_crowd") == 1,
			"dash: a swish for each of %d runners and one crowd (%d, %d)"
			% [runners, _count("garden_finish"), _count("garden_crowd")])
	_results("dash")

func _seek(home) -> void:
	var sk: BaseSeek = home.hseek
	sk.use()
	home.ppos = home.kins[0]["pos"] + Vector3(7, 0, 0)
	sk.use()
	var t := 0.0
	var looped := false
	while sk.state == BaseSeek.S.HUNT and t < SIM_S:
		sk.tick(0.1)
		looped = looped or Sfx.loop_on("seek_sniff")
		t += 0.1
	await _wait()
	_countdown("seek")
	ok(_count("garden_sniff") == 1 and looped and not Sfx.loop_on("seek_sniff"),
			"seek: the sniffing loop starts once and stops with the hunt (%d)" % _count("garden_sniff"))
	_results("seek")

func _volley(home) -> void:
	var vb: BaseVolley = home.hvolley
	vb.use()
	_press(vb.bar, 0.0, vb)
	var hits := 0
	var t := 0.0
	while vb.run != null and t < SIM_S:
		hits = vb.run.hits
		vb.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("volley")
	ok(_count("garden_cheer_perfect") == 1, "volley: one perfect crowd cheer for the spike call")
	var bats := _count("garden_bat")
	ok(hits > 0 and bats == hits, "volley: one seed bat per hit (%d bats, %d hits)" % [bats, hits])
	_results("volley")

func _tumble(home) -> void:
	var tb: BaseTumble = home.htumble
	var moves: Array = BaseTumble.rules()["moves"].keys()
	tb.use()
	var want := {}                # move -> exchanges it should decide
	var pushes := 0
	var out := false
	var t := 0.0
	while tb.run != null and t < SIM_S:
		var r: BaseTumble.Run = tb.run
		if r.state == "tell" and r.pick == "":
			r.plan = moves[r.played % moves.size()]
			var mine := BaseTumble.counter(r.plan)
			tb._choose(moves.find(mine))
			want[mine] = int(want.get(mine, 0)) + 1
			pushes += 1
		if r.state == "resolve" and r.grade == "":
			_press(tb.bar, 0.0, tb)
		out = r.out()
		tb.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("tumble")
	var got := moves.map(func(m): return _count("tumble_clash_" + m))
	var need := moves.map(func(m): return int(want.get(m, 0)))
	ok(not need.has(0) and got == need, "tumble: one clash in the deciding move per exchange, %s (%s, want %s)"
			% [moves, got, need])
	ok(_count("tumble_push") == pushes, "tumble: one push scuff per exchange won (%d of %d)"
			% [_count("tumble_push"), pushes])
	ok(out and _count("tumble_ringout") == 1, "tumble: one ring-out as the loser leaves the ring")
	_results("tumble")

func _echo(home) -> void:
	var es: EchoSteps = home.hecho
	es.use()
	var r: EchoSteps.Run = es.run
	var every := int(EchoSteps.rules()["cheer_every"])
	var want := {"hit": 0, "miss": 0, "streak": 0}
	var streak := [0, 0]
	var t := 0.0
	while not r.over() and t < SIM_S:
		var nt := t + 0.05
		if r.mine():
			for i in r.pattern.size():
				var pt := r.at(r.first + i)
				if pt > t and pt <= nt:
					var s: int = i % 4 if r.pattern[i] < 0 else r.pattern[i]
					r.press(pt, s if r.round_i == 0 else (s + 1) % 4)        # all right, then all wrong
		r.step(nt)
		for e in r.events:
			var side: int = e[1]
			match String(e[0]):
				"hit", "fixed":
					streak[side] += 1
					if e[0] == "hit":
						want["hit"] += 1
						want["streak"] += 1 if streak[side] % every == 0 else 0
				"miss":
					streak[side] = 0
					want["miss"] += 1
			es._show(e, nt)
		r.events.clear()
		t = nt
	es._end(true)
	var got := {"hit": _count("echo_hit"), "miss": _count("echo_miss"), "streak": _count("echo_streak")}
	ok(want["hit"] > 0 and want["miss"] > 0 and want["streak"] > 0 and got == want,
			"echo: one sparkle per hit, one miss per miss, one streak run every %d in a row (%s, want %s)"
			% [every, got, want])
	ok(_count("garden_go") == 1 and _count("garden_finish") == 1, "echo: the start and the finish once each")
	ok(es.voices.size() == 4 and es.voices[0].stream is AudioStreamWAV, "echo: the four stone notes are generated")

func _show(home) -> void:
	var sr: ShowRing = home.hshow
	sr.use()
	var presses := 0
	var t := 0.0
	while sr.run != null and t < SIM_S:
		var r: ShowRing.Run = sr.run
		var due := false
		for i in r.calls.size():
			due = due or (r.phase == ShowRing.Run.Phase.BOND and r.calls[i] == "" and r.t >= r.lure_t(i))
		if r.can_trick() or due:
			_press(sr.bar, 0.0, sr)
			presses += 1
		sr.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("show")
	ok(presses > 3 and _total("garden_cheer_") == presses, "show: a crowd cheer for each of %d presses (%d)"
			% [presses, _total("garden_cheer_")])
	ok(_count("show_reveal") == 1 and _count("show_crowd") == 1, "show: the judges' reveal and the crowd once each")
	_results("show")

func _relay(home) -> void:
	var rc: BaseRelay = home.hrace.relay
	rc.use()
	var lost := [[], []]
	var t := 0.0
	while rc.run != null and t < SIM_S:
		if rc.run.can_press():
			_press(rc.bar, 0.0 if rc.run.grades.is_empty() else 0.9, rc)      # one great hand-off, one missed
		lost = rc.run.lost.duplicate(true)
		rc.tick(0.1)
		t += 0.1
	await _wait()
	_countdown("relay")
	var clean_s := float(BaseRelay.rules()["handoff"]["good"])
	var want := [0, 0]
	for team in lost:
		for s in team:
			want[0 if float(s) <= clean_s else 1] += 1
	var got := [_count("relay_handoff"), _count("relay_fumble")]
	ok(want[0] > 0 and want[1] > 0 and got == want, "relay: clean and fumbled hand-offs each sound once (%s, want %s)"
			% [got, want])
	ok(_count("relay_finish") == 2, "relay: one finish for each team home (%d)" % _count("relay_finish"))
	_results("relay")
## Driven by hand in one frame, so the home's own tick can't land between the steps.
func _chimes(home) -> void:
	var hc: HomeChimes = home.chimes
	var k: Dictionary = {}
	for kk in home.kins:
		if not HomeChimes._asleep(kk):
			k = kk
	var rec: Dictionary = k["rec"]
	hc.tick(0.0)
	var gap := HomeChimes.MERGE_S + 0.05
	Care.add_stat(rec, "power", 1)
	hc.tick(gap)
	hc.tick(0.1)
	ok(_count("garden_chime_stat") == 1 and _total("garden_chime_") == 1, "chimes: one stat chime for a stat")
	rec["level"] = int(rec["level"]) + 1
	hc.tick(gap)
	ok(_count("garden_chime_level") == 1 and _total("garden_chime_") == 2, "chimes: one level chime for a level")
	rec["forms"].append("fierce")
	hc.tick(gap)
	ok(_count("garden_chime_evolve") == 1 and _total("garden_chime_") == 3, "chimes: one evolve chime for a form")
	rec["xp"] = 100 * int(rec["level"]) - 1
	Care.add_stat(rec, "guard", 2)
	GardenXp.give(rec, "drill", false, 4)
	hc.tick(gap)
	Care.add_stat(rec, "speed", 1)
	hc.tick(0.3)
	ok(_total("garden_chime_") == 4, "chimes: a drill's stat and level and a stat 0.3 s on merge into one (%s)"
			% [GardenSfx.heard])
	k["nap_t"] = 5.0
	Care.add_stat(rec, "focus", 1)
	hc.tick(gap)
	k["nap_t"] = 0.0
	hc.tick(gap)
	ok(_total("garden_chime_") == 4, "chimes: nothing while the Boki sleeps, nor once it wakes")
	var p := HomeChimes.PITCH
	ok(Sfx.ensure("garden_chime_stat") and Sfx.ensure("garden_chime_level") and Sfx.ensure("garden_chime_evolve")
			and p["small"] > p["medium"] and p["medium"] > p["large"], "chimes: all three exist, small sings higher")
