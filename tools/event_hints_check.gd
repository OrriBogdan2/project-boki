extends RefCounted
## --event-hints-check: the one-time hints for match events (MatchHints, content/rules/hints.json
## "event"). A fresh save sees the drop map before the ship sets off (the hot zone on it), then on
## the ground the first Heartspark charges and the clock passes the tide's start (the Blight closes in).
## Each moment must show exactly one hint line, its own. A second expedition on the same save
## (after a save round-trip) forces the same moments and must show none. A v11 save that finished the
## old match tutorial still has every event hint ahead of it (a missing key means unseen).

const MOMENT_S := 3.0         # s of play a moment gets to show its hint (the poll and the lane)
const CALM_T := 5.0           # s on the match clock before the tide starts (heart.json tide_start_s)

var bad := 0
var main: Node
var m: Match
var p: Hunter
var _on: Array = []           # event hint ids on screen last step
var _shown: Array = []        # event hint ids as they appeared

func ok(cond: bool, what: String) -> void:
	print("EVH %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_migration()
	Save.d = Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	for id in FirstTimeHint.ids("match"):
		FirstTimeHint.mark(String(id))      # only the event hints are under test
	_expedition(true)
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	_expedition(false)
	if m:
		m.queue_free()
	print("EVH DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _migration() -> void:
	var old := {"tutorial": {"hatched": true, "match": true, "ft": {"done": true}}}
	FirstTimeHint.migrate(old)
	var seen: Dictionary = old["tutorial"]["hints"]
	ok(FirstTimeHint.ids("event").size() == 3, "three event hints: %s" % str(FirstTimeHint.ids("event")))
	ok(FirstTimeHint.ids("match").all(func(id): return seen.get(id, false)),
			"migration: the old tutorial's hints are marked seen")
	ok(not FirstTimeHint.ids("event").any(func(id): return seen.has(id)),
			"migration: no event hint is pre-marked (missing key = unseen)")

func _expedition(first: bool) -> void:
	var want := 1 if first else 0
	var tag := "first" if first else "second"
	# the drop map, before the ship sets off: the hot zone is on it
	_start({"plan_t": 6.0})
	ok(m.biomes != null and m.biomes.hot.hot >= 0 and m.skydrop != null and m.skydrop.planning, "%s: the drop map is up with a hot zone" % tag)
	_moment("hotzone", want, tag, func(): return m.skydrop.planning)
	# on the ground (no ship this time): the first Heartspark charging, then the tide closing
	_start({"no_drop": true})
	ok(m.heart != null and m.heart.state == "charging", "%s: a Heartspark is charging" % tag)
	_moment("heartspark", want, tag, func(): return m.heart.state == "charging")
	var tide_t: float = Heart.r("tide_start_s") + 1.0
	_moment("tide", want, tag, func(): return Heart.tide_stage(m) >= 0, tide_t)
	if first:
		ok(FirstTimeHint.ids("event").all(func(id): return FirstTimeHint.seen(String(id))),
				"every event hint is marked seen in the save")

func _start(extra: Dictionary) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 3, "squad": 1, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)
	p = m.player
	for mb in m.mobs:
		mb.queue_free()      # no fight to hold the hints back
	m.mobs.clear()

## Clears the lane, then plays MOMENT_S with the clock at `t` while `during` holds; asserts the
## moment showed `want` hint lines and, if one, the event's own.
func _moment(id: String, want: int, tag: String, during: Callable, t := CALM_T) -> void:
	m.hud.msgs.clear()
	_on.clear()
	var n0 := _shown.size()
	var held := true
	for i in int(MOMENT_S / Match.DT):
		_step(t)
		held = held and bool(during.call())
	var got := _shown.slice(n0)
	ok(held, "%s: the %s moment held for %.1f s" % [tag, id, MOMENT_S])
	var right: bool = got.size() == want and (want == 0 or got[0] == id)
	ok(right, "%s %s: %d hint(s), want %d of '%s' (got %s)" % [tag, id, got.size(), want, id, str(got)])

func _step(t: float) -> void:
	p.hp = p.max_hp
	m.time = t
	m.step(Match.DT)
	var lines: Array[String] = m.hud.msgs.texts() if m.hud else []
	var on: Array = []
	for id in FirstTimeHint.ids("match") + FirstTimeHint.ids("event"):
		var line := FirstTimeHint.text(String(id))
		if lines.any(func(l): return l.contains(line)):
			on.append(id)
	for id in on:
		if not id in _on:
			_shown.append(id)
	_on = on
