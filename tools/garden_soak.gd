extends RefCounted
## --garden-soak: the garden pieces run together. A base_mode save with six Boki (two friends, two rivals, a baby
## and a retired elder) plus the three toys and the snack patch lives 30 in-game days on the real farm, stepped at
## DT of farm time per call with no frames in between (the high time scale; a day is home.DAY_LEN s). Each day the
## player feeds everyone and picks the patch, every third day the Dash and the Stump Shove are run on the logic
## classes. Every Boki's state changes are kept (user://garden_soak.json). It fails on: a Boki stuck in one state
## over STUCK_HOURS in-game hours (Nap through the night excepted), a need outside 0..100, a NaN or out-of-range
## trait, a bond outside -1..1, a toy held past TOY_HOLD s, the save over SAVE_GROWTH times its first size, or an
## error in the engine log. Never touches the real save.

const DAYS := 30
const DT := 0.25                # s of farm time per step
const SPAWN_EVERY := 400        # steps between frames, so deferred frees and timers can run
const STUCK_HOURS := 6.0        # in-game hours (DAY_LEN / 24 = 12.5 s each) in one state: the rules cap Roam at 45 s
const TOY_HOLD := 60.0          # s a Boki may keep one toy (go_timeout 20 + play 12 at most, with room)
const SAVE_GROWTH := 2.0        # the save may grow to this many times its first size
const DAY_START := 0.3          # the farm clock at the start (morning)
const MATCH_EVERY := 3          # days between a Dash and a Stump Shove
const RACE_MAX_S := 120.0       # s a headless race may run
const OUT := "user://garden_soak.json"

## Collects engine errors while the soak runs (warnings do not count).
class ErrorLog extends Logger:
	var lines: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _notify: bool,
			error_type: int, _backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		lines.append("%s:%d %s %s" % [file.get_file(), line, function, rationale if rationale != "" else code])

var bad := 0
var main: Node
var home
var errors := ErrorLog.new()
var hist := {}              # name -> Array of [t s, state name]
var longest := {}           # name -> {state name: longest stay in s}
var play_since := {}        # name -> t its current toy began
var t := 0.0
var seen := {"plays": 0, "picks": 0, "races": 0, "bouts": 0}      # what the run actually exercised

func ok(cond: bool, what: String) -> void:
	print("SOAK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _fail(what: String) -> void:
	print("SOAK FAIL %s (t=%.0f s, day %.1f)" % [what, t, t / home.DAY_LEN])
	bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(30)
	OS.add_logger(errors)
	var d := BaseDemo.save()
	_add_young_and_old(d)
	SnackPatch.grant(d)
	home = await main._hb_home()
	_stage()
	var size0 := JSON.stringify(Save.d).length()
	var hour: float = home.DAY_LEN / 24.0
	var steps := int(DAYS * home.DAY_LEN / DT)
	var wall := Time.get_ticks_msec()
	for i in steps:
		_step()
		_watch(hour * STUCK_HOURS)
		if i % SPAWN_EVERY == 0:
			await main.get_tree().process_frame
	var size1 := JSON.stringify(Save.d).length()
	var secs := float(Time.get_ticks_msec() - wall) / 1000.0
	print("SOAK %d days (%d steps) in %.0f s of wall time" % [DAYS, steps, secs])
	_report()
	ok(size1 <= size0 * SAVE_GROWTH, "save size %d -> %d bytes (limit x%.0f)" % [size0, size1, SAVE_GROWTH])
	var drifted: int = home.kins.filter(func(k): return k["rec"].has("drift")).size()
	print("SOAK exercised: ", seen, ", trait drift on %d Boki" % drifted)
	ok(seen.values().all(func(n): return n > 0) and drifted > 0, "toys, patch, Dash, Shove and trait drift all ran")
	var played: bool = hist.values().any(func(h): return h.any(func(e): return e[1] == "Play"))
	ok(played, "the machine shows Play while a Boki is at a toy (home_toys.gd)")
	ok(errors.lines.is_empty(), "no errors in the log (%d)" % errors.lines.size())
	for l in errors.lines.slice(0, 5):
		print("SOAK   ", l)
	_write()
	OS.remove_logger(errors)
	FarmUnlocks.rules()["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame
	print("SOAK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Two more Boki on top of the demo's four: a baby (level 1) and an Elder who has retired as a mentor.
func _add_young_and_old(d: Dictionary) -> void:
	for spec in [["burrlet", "Bean", 1], ["pebbit", "Gran", 16]]:
		var rec := Save.new_kin(spec[0], spec[1])
		rec["level"] = spec[2]
		Care.ensure(rec)
		d["roster"].append(rec)
		if spec[2] == 16:
			Mentor.retire(rec)

## The three toys and the snack patch near the landing; the demo's Nook and egg are left out.
func _stage() -> void:
	var land := HomeLayout.LANDING
	for id in BaseDemo.TOYS:
		home.hg.demo_place(id, land + BaseDemo.TOYS[id])
	home.hg.demo_place(SnackPatch.ID, land + Vector3(5.0, 0, 5.0))
	home._sync_fixtures()
	home.day_t = DAY_START
	ok(home.kins.size() == 6 and home.life != null, "six Boki live on a base_mode farm (%d)" % home.kins.size())
	ok(home.toys.toys().size() == 3 and not SnackPatch.entry(Save.d).is_empty(), "three toys and the snack patch stand")

func _step() -> void:
	var day_before: int = int(t / home.DAY_LEN)
	t += DT
	home.day_t = fmod(home.day_t + DT / home.DAY_LEN, 1.0)
	home._move_kin(DT)
	home._care_tick(DT)
	home.hecon.tick(DT)
	home.hsp.tick(DT)
	home.hrace.tick(DT)
	home.hshove.tick(DT)
	var e := SnackPatch.entry(Save.d)
	if e.has("t"):
		e["t"] = float(e["t"]) - DT          # real unix time cannot be sped up: age the timer instead
	if int(t / home.DAY_LEN) > day_before:
		_player_day(int(t / home.DAY_LEN))

## What the player does once a day: feed everyone, walk over the patch, and now and then run a Dash and a Shove.
func _player_day(day: int) -> void:
	for k in home.kins:
		Care.feed(k["rec"], String(k["rec"]["likes"]["food"]))
	var e := SnackPatch.entry(Save.d)
	if not e.is_empty():
		var was: Vector3 = home.ppos
		home.ppos = HomeLayout.deco_center(e)
		var crops := int(Save.d["crops"].values().reduce(func(a, b): return a + b, 0))
		home.hsp.tick(1.0)
		seen["picks"] += 1 if int(Save.d["crops"].values().reduce(func(a, b): return a + b, 0)) > crops else 0
		home.ppos = was
	if day % MATCH_EVERY == 0:
		_matches()

func _matches() -> void:
	var recs: Array = home.kins.map(func(k): return k["rec"]).filter(func(r): return not Mentor.is_mentor(r))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t)
	var race := BaseRace.Run.new(recs, 0, rng)
	var rt := 0.0
	while not race.over() and rt < RACE_MAX_S:
		race.step(DT)
		rt += DT
	if race.over():
		BaseRace.settle(race)
		seen["races"] += 1
	var bout := BaseShove.Run.new([recs[2], recs[3]], 0, rng)
	rt = 0.0
	while not bout.over() and rt < RACE_MAX_S:
		bout.step(DT)
		rt += DT
	if bout.over():
		BaseShove.settle(bout)
		seen["bouts"] += 1

## One look at every Boki: record a state change, and check the stuck limit and every value's range. A Boki the
## farm itself has (called, indoors, held) keeps its state and does not count; neither does a night Nap or a
## retired mentor's stroll, which have no end by design.
func _watch(limit_s: float) -> void:
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var nm := String(rec["name"])
		var m := k["life"] as Fsm
		var state := String(BaseLife.NAMES[m.state])
		if not hist.has(nm):
			hist[nm] = [[t, state]]
			longest[nm] = {}
		if hist[nm][-1][1] != state:
			hist[nm].append([t, state])
		longest[nm][state] = maxf(float(longest[nm].get(state, 0.0)), m.since)
		var endless: bool = m.is_in(BaseLife.S.MENTOR) or (m.is_in(BaseLife.S.NAP) and home.life.night)
		if m.since > limit_s and m.since <= limit_s + DT and not endless and not BaseLife._taken(k):
			_fail("%s stuck in %s for over %.1f s" % [nm, state, limit_s])      # said once, as it crosses
		_check_values(rec, nm)
		_check_toy(k, nm)

func _check_values(rec: Dictionary, nm: String) -> void:
	for n in Care.NEEDS:
		var v := float(rec["needs"][n])
		if is_nan(v) or v < 0.0 or v > 100.0:
			_fail("%s need %s = %s" % [nm, n, str(v)])
	for tr in rec["traits"]:
		var v := float(rec["traits"][tr])
		if is_nan(v) or v < 0.0 or v > 1.0:
			_fail("%s trait %s = %s" % [nm, tr, str(v)])
	for uid in rec.get("bonds", {}):
		var v := float(rec["bonds"][uid])
		if is_nan(v) or v < -1.0 or v > 1.0:
			_fail("%s bond %s = %s" % [nm, uid, str(v)])

func _check_toy(k: Dictionary, nm: String) -> void:
	if not k.has("play"):
		play_since.erase(nm)
		return
	if not play_since.has(nm):
		play_since[nm] = t
		seen["plays"] += 1
	elif t - float(play_since[nm]) > TOY_HOLD and t - float(play_since[nm]) < TOY_HOLD + DT:
		_fail("%s holds a toy for over %.0f s" % [nm, TOY_HOLD])

func _report() -> void:
	for nm in hist:
		var changes: int = hist[nm].size() - 1
		var parts: PackedStringArray = []
		for s in longest[nm]:
			parts.append("%s %.0f" % [s, longest[nm][s]])
		print("SOAK %-6s %4d changes, longest stay (s): %s" % [nm, changes, ", ".join(parts)])
		ok(changes > 0, "%s changed state during the run" % nm)

func _write() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(hist))
