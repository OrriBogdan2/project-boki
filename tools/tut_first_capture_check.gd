extends RefCounted
## --tut-first-capture-check: the first-time capture hint (FirstCapture).
##   1. a live Boki or a tutorial match: no hint; the first capturable Boki: one hint (name, type, the key)
##   2. a second capturable Boki, or going out of range and back: no second hint; the flag is saved in Save.d
##   3. the marker is on that Boki only, and goes when the scan starts or it is out of range
##   4. the key in the text follows a rebind
##   5. the fail line names the cause (too far, interrupted, it fled) once; the second failure is the generic one
##   6. a save that has caught before, or saw the old hint, is not taught (migration); a fresh one is
## Never touches the real save.

var bad := 0
var m: Match
var main: Node
var lines: Array = []

func ok(cond: bool, what: String) -> void:
	print("TUTCAP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh(opts := {}) -> void:
	if m: m.queue_free()
	Save.d = Save.fresh()
	Save.d["tutorial"]["move"] = true      # (the first tip of the match is out of the way)
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true,
			"weapon": "rifle", "cls": "medium", "demo_kin": "cindle"}
	o.merge(opts, true)
	m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if h.team != m.player.team:
			h.ctrl = "idle"
			h.teleport(m.player.pos + Vector3(60.0, 0, 40.0))
	m.hud.msgs.clear()
	for i in 20: m.step(Match.DT)

func _wild(species: String, dx: float, dazed := true) -> Kin:
	var at: Vector3 = m.player.pos + Vector3(dx, 0, 0)
	var k := m.spawn_wild(Save.new_kin(species, "", 77), Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), dazed)
	for i in 5: m.step(Match.DT)
	return k

func _flag() -> bool:
	return Save.d["tutorial"].get(FirstCapture.KEY, false)

## What the lane shows with the hint's words.
func _shown(word: String) -> bool:
	for l in m.hud.msgs.texts():
		if String(l).contains(word): return true
	return false

## One frame of Match's first-time tips (the hint is wired in there).
func _tips() -> void:
	m._tip_t = 5.0
	m._tips()

func _run_for(secs: float) -> void:
	for i in int(secs / Match.DT): m.step(Match.DT)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_hint()
	_marker_and_rebind()
	_fails()
	_migration()
	print("TUTCAP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hint() -> void:
	_fresh()
	var P := m.player
	var live := _wild("puddlet", 2.0, false)
	_tips()
	ok(not _flag() and not P.has_meta("fc"), "a Boki on its feet gets no hint")
	live.queue_free()
	m.kins.erase(live)
	var k := _wild("cindle", 2.0)
	m.hud.msgs.clear()
	_tips()
	var text := FirstCapture.hint_text(k)
	var named: bool = text.contains(k.sp["name"]) and text.contains(String(k.sp["type"]).capitalize())
	var keyed: bool = text.contains("Hold %s to capture it" % Settings.key_cap("interact"))
	var home: bool = text.contains("comes home with you if you get out")
	ok(named and keyed and home, "the hint names the Boki, its type and the key: \"%s\"" % text)
	ok(_flag() and _shown("capture it"), "the hint is on screen and in the save, once per save")
	var far := _wild("puddlet", 40.0)
	m.player.teleport(far.pos + Vector3(1.5, 0, 0))
	_tips()
	ok(not FirstCapture.marked(P, far), "a second capturable Boki gets no hint and no marker")
	_fresh({"tutorial": true})
	_wild("cindle", 2.0)
	_tips()
	ok(not _flag() and not m.player.has_meta("fc"), "the tutorial match never shows it")

func _marker_and_rebind() -> void:
	_fresh()
	var P := m.player
	var k := _wild("cindle", 2.0)
	_tips()
	ok(FirstCapture.marked(P, k), "the marker is on that Boki")
	P.inp["interact"] = true
	_run_for(0.6)
	_tips()
	P.inp["interact"] = false
	ok(Capture.active(P) and not FirstCapture.marked(P, k), "...and goes once the scan starts")
	_fresh()
	P = m.player
	k = _wild("cindle", 2.0)
	_tips()
	P.teleport(k.pos - Vector3(float(Capture.rules()["range"]) + 1.0, 0, 0))
	_tips()
	P.teleport(k.pos)
	_tips()
	ok(not FirstCapture.marked(P, k), "...and goes for good when you walk out of range")
	var old: String = Settings.key_cap("interact")
	var evs := InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	var j := InputEventKey.new()
	j.physical_keycode = KEY_J
	InputMap.action_add_event("interact", j)
	ok(FirstCapture.hint_text(k).contains("Hold J to") and old != "J", "the key text follows a rebind (%s to J)" % old)
	InputMap.action_erase_events("interact")
	for e in evs: InputMap.action_add_event("interact", e)

func _fails() -> void:
	for why in ["far", "dash", "cc", "gone"]:
		_fresh()
		var P := m.player
		var k := _wild("cindle", 2.0)
		_tips()
		P.inp["interact"] = true
		_run_for(0.6)
		P.inp["interact"] = false
		m.hud.msgs.clear()
		match why:
			"far": k.teleport(P.pos + Vector3(float(Capture.rules()["cancel_range"]) + 3.0, 0, 0))
			"dash": P.inp["dash"] = true
			"cc": P.stun_t = 1.0
			"gone": k.dead = true
		_run_for(0.3)
		P.inp["dash"] = false
		var word: String = {"far": "Too far", "dash": "You dashed", "cc": "knocked you out", "gone": "got away"}[why]
		var generic := _shown("Scan interrupted") or _shown("Scan cancelled")
		ok(_shown(word) and not P.has_meta("fc") and not generic, "failing by '%s' says so once (\"%s\")" % [why, word])
	_fresh()
	var P2 := m.player
	_wild("cindle", 2.0)
	ok(not FirstCapture.fail(m, P2, "dash"), "no hint behind it: the generic line is used")

func _migration() -> void:
	var a := {"tutorial": {}, "stats": {"caught": 2}}
	var b := {"tutorial": {"catch": true}, "stats": {"caught": 0}}
	var c := {"tutorial": {}, "stats": {"caught": 0}}
	for d in [a, b, c]: FirstCapture.migrate(d)
	var key := FirstCapture.KEY
	var taught: bool = a["tutorial"].get(key, false) and b["tutorial"].get(key, false)
	ok(taught and not c["tutorial"].has(key), "a save that caught or saw the old hint is not taught; a new one is")
