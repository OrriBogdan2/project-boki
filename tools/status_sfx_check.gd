extends RefCounted
## --status-sfx-check: the sound of statuses (StatusSfx, content/rules/status_sfx.json).
##   1. every cue and loop sound in the rules exists
##   2. applying each status plays its cue once on the body (Ignite, Slow, Stun, Root, Ground, Daze,
##      Anti-Heal through the real hit and KitStatus paths; Chill and Static through their kits);
##      a refresh of one still running is silent
##   3. Static's cue climbs with the stack; your own statuses play louder (mine_db) than another's
##   4. the loops (Ignite, Static) start with the status and stop when it expires or is cleansed, and
##      none is left when the match ends
##   5. the voice caps: at most cue_cap cues in cue_window_ms, at most loop_cap loops at once
## Prints STATUSSFX ok/FAIL. Runs on tools/support_check.gd's setup.

const DT := 1.0 / 60.0
const GAP_S := 0.3          # s of real time between cues: past the cue window and the stack window

var main: Node
var sc
var bad := 0
var rules: Dictionary

func ok(cond: bool, what: String) -> void:
	print("STATUSSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	sc = load("res://tools/support_check.gd").new()
	sc.main = mn
	rules = Content.rules("status_sfx")
	for kind in rules["cues"]:
		ok(Sfx.ensure(String(rules["cues"][kind]["sound"])), "cue sound for %s exists" % kind)
	for kind in rules["loops"]:
		ok(Sfx.ensure(String(rules["loops"][kind]["sound"])), "loop sound for %s exists" % kind)
	await _body_statuses()
	await _kit_statuses()
	await _caps()
	print("STATUSSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Plays of `sound` that started at or after `t0` (ms).
func plays_since(sound: String, t0: int) -> int:
	var n := 0
	for t in Sfx.recent.get(sound, []):
		if int(t) >= t0:
			n += 1
	return n

func loops_on() -> int:
	var n := 0
	for key in Sfx.loops:
		if String(key).begins_with("st_"):
			n += 1
	return n

## A pool player sounding `sound` now (its pitch and volume), or null; not `but`, the one from before.
func sounding(sound: String, but: AudioStreamPlayer = null) -> AudioStreamPlayer:
	var st = Sfx.streams.get(sound)
	var takes: Array = st if st is Array else [st]
	for p in Sfx.players:
		if p.playing and p != but and p.stream in takes:
			return p
	return null

func settle(m: Match, secs := 0.0) -> void:
	Sfx.listener = m.player.pos         # the camera's job in a game: sounds fade with the distance to it
	sc.step(m, secs)
	await main.get_tree().create_timer(GAP_S).timeout

## Applies once with `apply` and checks the cue played exactly once; a second, running application is silent.
func once(m: Match, label: String, sound: String, apply: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	apply.call()
	ok(plays_since(sound, t0) == 1, "%s: its cue plays once" % label)
	await settle(m)
	var t1 := Time.get_ticks_msec()
	apply.call()
	ok(plays_since(sound, t1) == 0, "%s: a refresh while it runs is silent" % label)
	await settle(m)

func _body_statuses() -> void:
	var r: Array = sc.setup("gunslinger", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	Sfx.listener = P.pos
	await once(m, "Stun", "st_stun", func(): T.hurt(1.0, P, {"stun": 1.0}))
	await once(m, "Root", "st_root", func(): T.hurt(1.0, P, {"root": 1.0}))
	await once(m, "Slow", "st_slow", func(): T.hurt(1.0, P, {"slow": 1.0, "slow_k": 0.3}))
	await once(m, "Anti-Heal", "st_antiheal", func(): T.hurt(1.0, P, {"blight": 2.0}))
	await once(m, "Ground", "st_ground", func(): KitStatus.apply(T, "gnd", 2.0))
	await once(m, "Daze", "st_daze", func(): KitStatus.apply(T, "rat", 2.0))
	await once(m, "Ignite", "as_ignite", func(): T.hurt(1.0, P, {"burn": 5.0, "burn_for": 1.5}))
	await main.get_tree().process_frame
	ok(loops_on() == 1, "Ignite: the crackle loop runs while it burns")
	sc.step(m, 2.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(T.burn_t <= 0.0 and loops_on() == 0, "Ignite: the crackle stops when it burns out")
	T.hurt(1.0, P, {"burn": 5.0, "burn_for": 30.0})
	await main.get_tree().process_frame
	ok(loops_on() == 1, "Ignite: the crackle starts again on a new fire")
	T.burn_t = 0.0                                             # a cleanse
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(loops_on() == 0, "Ignite: the crackle stops when it is cleansed")
	# yours play louder than another's: the same cue on the same body, once by you and once by an ally of theirs
	T.slow_t = 0.0
	sc.step(m, 3.0)
	await settle(m)
	T.hurt(1.0, P, {"stun": 0.5})
	var mine := sounding("st_stun")
	var mine_db := mine.volume_db if mine else -99.0
	sc.step(m, 3.0)
	await settle(m)
	T.hurt(1.0, A, {"stun": 0.5})
	var other := sounding("st_stun", mine)
	var other_db := other.volume_db if other else 99.0
	var gain := mine_db - other_db
	ok(absf(gain - float(rules["mine_db"])) < 0.5, "yours is %.1f dB louder (rules %.1f)" % [gain, float(rules["mine_db"])])
	await _free(m)

func _kit_statuses() -> void:
	var r: Array = sc.setup("rimewright", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	var RK: RimewrightKit = P.ak
	Sfx.listener = P.pos
	await once(m, "Chill", "st_chill", func(): RK.add_chill(T))
	await _free(m)
	r = sc.setup("mage", 6.0)
	m = r[0]
	P = r[1]
	T = r[3]
	var K: MageKit = P.ak
	Sfx.listener = P.pos
	var t0 := Time.get_ticks_msec()
	K.add_spark(T, 1)
	ok(plays_since("mage_zap", t0) == 1, "Static: the first stack plays its cue once")
	var low := sounding("mage_zap")
	var low_pitch := low.pitch_scale if low else 0.0
	await main.get_tree().process_frame
	ok(loops_on() == 1, "Static: the buzz loop runs while it is on the body")
	await settle(m)
	t0 = Time.get_ticks_msec()
	K.add_spark(T, 2)
	ok(plays_since("mage_zap", t0) == 1, "Static: another stack plays the cue again")
	var high := sounding("mage_zap", low)
	var high_pitch := high.pitch_scale if high else 0.0
	ok(high_pitch > low_pitch + 0.1, "Static: the cue climbs with the stacks (%.2f -> %.2f)" % [low_pitch, high_pitch])
	K.clear_sparks(T)                                          # spent or cleansed
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(loops_on() == 0, "Static: the buzz stops when the stacks are spent")
	K.add_spark(T, 1)
	await main.get_tree().process_frame
	ok(loops_on() == 1, "Static: the buzz starts again on a new stack")
	sc.step(m, float(K.res_def()["dur"]) + 1.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	ok(loops_on() == 0, "Static: the buzz stops when the stacks run out")
	K.add_spark(T, 1)
	await main.get_tree().process_frame
	await _free(m)
	ok(loops_on() == 0, "no status loop outlives the match")

func _caps() -> void:
	var r: Array = sc.setup("gunslinger", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[3]
	Sfx.listener = P.pos
	await settle(m)
	var t0 := Time.get_ticks_msec()
	for kind in rules["cues"]:
		StatusSfx.cue(T, kind, P)
	var n := 0
	for kind in rules["cues"]:
		n += plays_since(String(rules["cues"][kind]["sound"]), t0)
	var cap := int(rules["cue_cap"])
	ok(n == cap, "%d cues at once play %d (cue_cap %d)" % [rules["cues"].size(), n, cap])
	var foes: Array = [T]
	for i in 4:
		var at := T.pos + Vector3(1.5 * (i + 1), 0, 0)
		foes.append(m.make_hunter("F%d" % i, P.team + 5, "medium", "Foe", "idle", {}, at, {"arch": "none"}))
	for f in foes:
		f.hurt(1.0, P, {"burn": 5.0, "burn_for": 30.0})
	await main.get_tree().process_frame
	var loop_cap := int(rules["loop_cap"])
	ok(loops_on() == loop_cap, "%d burning bodies run %d loops (loop_cap %d)" % [foes.size(), loops_on(), loop_cap])
	await _free(m)

func _free(m: Match) -> void:
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame
