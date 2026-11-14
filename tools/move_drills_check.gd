extends RefCounted
## --move-drills-check: the Training Area's movement drills (MoveDrills). A bot input script passes each
## of the five drills (gates, glide, dive, wall kick, mantle) in the real match step; the wrong play fails
## (a held Space from the take-off, a dive that lands off the mat, no input at all); the best time is kept
## and only improves; the Drills button exists in the Training Area only; a v11 save upgrades. The match
## is stepped by hand (Match.step, then MoveDrills.tick) so the count is in fixed steps. Never writes a save.

var bad := 0
var m: Match
var P: Hunter
var dr: MoveDrills
const DT := Match.DT
const MAX_STEPS := 1200
const DIVE_AT := 5.0  # m from the mat the dive bot crouches: with Loco.glide_step steering (0.24.5) 6-9 m lands short
const OPTS := {
	"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "training": true, "practice": true
}


func ok(cond: bool, what: String) -> void:
	print("MOVEDRILLS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	m = Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var pr := Practice.of(m)
	dr = pr.drills
	dr.set_process(false)
	ok(dr != null and pr.bar_btns.has("drills"), "the Training Area's bar has a Drills button")
	_passes()
	_fails()
	_best()
	await _other_areas(main)
	_save()
	print("MOVEDRILLS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


# ---------------------------------------------------------------- stepping
func _begin(i: int) -> void:
	dr.origin = P.pos if dr.origin == Vector3.INF else dr.origin
	dr._begin(i)
	P.inp["move"] = Vector2.ZERO
	for k in ["jump", "glide", "crouch", "dash"]:
		P.inp[k] = false


## Steps until the drill is decided; `bot` sets the inputs for step f. Returns the steps taken.
func _play(bot: Callable) -> int:
	var f := 0
	while dr.state == MoveDrills.State.RUN and f < MAX_STEPS:
		bot.call(f)
		m.step(DT)
		dr.tick(DT)
		f += 1
	return f


func _passed(id: String, bot: Callable) -> void:
	_begin(MoveDrills.IDS.find(id))
	var f := _play(bot)
	ok(dr.passed.has(id), "%s: the bot passes in %d steps (%.1f s)" % [id, f, dr.t])
	if not dr.passed.has(id):
		print("MOVEDRILLS    banner: ", dr._label.text)


func _failed(id: String, bot: Callable, why: String) -> void:
	dr.passed.erase(id)
	_begin(MoveDrills.IDS.find(id))
	_play(bot)
	var failed := dr.state == MoveDrills.State.RESULT and not dr.passed.has(id) and dr._label.text.contains(why)
	ok(failed, "%s: fails with '%s' (%s)" % [id, why, dr._label.text])


# ---------------------------------------------------------------- the bots
func _gates_bot(f: int) -> void:
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = P.roll_t <= 0.0 and f % 15 == 0


func _glide_bot(f: int) -> void:
	P.inp["move"] = Vector2(1, 0)
	P.inp["jump"] = f == 20 or f == 31  # a tap, let go, then press again and hold
	P.inp["glide"] = f in [20, 21, 22] or f >= 31


func _glide_held_bot(f: int) -> void:
	P.inp["move"] = Vector2(1, 0)
	P.inp["jump"] = f == 20  # Space held from the take-off
	P.inp["glide"] = f >= 20


func _dive_bot(f: int) -> void:
	var to := dr.target - P.pos
	var flat := Vector2(to.x, to.z)
	P.inp["glide"] = true
	P.inp["jump"] = f == 0
	P.inp["move"] = flat.normalized() if flat.length() > 0.5 else Vector2.ZERO
	P.inp["crouch"] = flat.length() < DIVE_AT


func _dive_idle_bot(_f: int) -> void:
	P.inp["glide"] = false


func _climb_bot(f: int) -> void:
	P.inp["move"] = Vector2(1, 0)
	var to_wall := dr.target.x - P.pos.x
	P.inp["jump"] = to_wall > -0.3 and ((to_wall > 0.0 and to_wall < 1.0 and f % 2 == 0) if P.grounded else f % 6 == 0)
	P.inp["glide"] = P.inp["jump"]


func _passes() -> void:
	_passed("gates", _gates_bot)
	_passed("glide", _glide_bot)
	_passed("dive", _dive_bot)
	_passed("wall", _climb_bot)
	_passed("mantle", _climb_bot)


func _fails() -> void:
	_failed("glide", _glide_held_bot, "Space held")
	_failed("dive", _dive_idle_bot, "m off the mat")
	_begin(0)
	dr.passed.erase("gates")
	dr.t = MoveDrills.LIMIT_S
	dr.tick(DT)
	ok(dr._label.text.contains("Out of time") and not dr.passed.has("gates"), "a drill that runs out of time fails")


func _best() -> void:
	var d := {}
	ok(MoveDrills.record(d, "gates", 5.0) and float(d["drills"]["gates"]) == 5.0, "the first pass is the best")
	ok(not MoveDrills.record(d, "gates", 6.0) and float(d["drills"]["gates"]) == 5.0, "a slower pass keeps the best")
	ok(MoveDrills.record(d, "gates", 4.25) and float(d["drills"]["gates"]) == 4.25, "a faster pass replaces it")
	var saved: bool = Save.d["drills"].has("wall") and float(Save.d["drills"]["wall"]) > 0.0
	ok(saved, "the bot's passes were saved in the profile")


func _other_areas(main: Node) -> void:
	var before := m.world.level.duplicate()
	dr._begin(MoveDrills.IDS.size())
	var back := dr.state == MoveDrills.State.OFF and m.world.level == before and P.pos.is_equal_approx(dr.origin)
	ok(back, "the end of the run puts the terraces and you back")
	for o in [Match.arena_opts("gunslinger"), Match.duel_opts(), {"tutorial": true}]:
		var mm := Match.new()
		main.add_child(mm)
		var opts: Dictionary = {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
		opts.merge(o, true)
		await mm.start(opts)
		mm.set_process(false)
		var p := Practice.of(mm)
		ok(p != null and p.drills == null and not p.bar_btns.has("drills"), "no Drills button in %s" % o.keys()[0])
		mm.queue_free()
		await main.get_tree().process_frame


func _save() -> void:
	var old := {"v": 11, "roster": []}
	var up: bool = Save.migrate(old) and int(old["v"]) == Save.VERSION and old["drills"] == {}
	ok(up, "a v11 save upgrades with an empty best-times table")
	ok(Save.fresh()["drills"] == {}, "a new save starts with one")
