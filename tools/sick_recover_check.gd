extends RefCounted
## --sick-recover-check: neglect never kills, and care brings a Boki back. 10 days with nothing to eat
## (one-minute ticks) end sick, alive, with its pace and drooped pose to show it; then fed, resting
## and with a friend close, it is fully well within 2 days, faster with each kind of care, and one
## snack-crop medicine cures it at once. Never touches the real save.

const NEGLECT_DAYS := 10
const CARE_LIMIT_S := 2.0 * 86400.0
const STEP_S := 60.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SICK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var base := _neglected("Pip")
	_looks(base)
	var fed_s := _care(base.duplicate(true), false, false)
	var nap_s := _care(base.duplicate(true), true, false)
	var all_s := _care(base.duplicate(true), true, true)
	ok(fed_s > 0.0 and fed_s <= CARE_LIMIT_S, "fed only: well in %.1f h (limit 48 h)" % (fed_s / 3600.0))
	ok(nap_s > 0.0 and nap_s < fed_s, "...a nap spot speeds it up (%.1f h)" % (nap_s / 3600.0))
	ok(all_s > 0.0 and all_s < nap_s, "...and a friend nearby more (%.1f h)" % (all_s / 3600.0))
	_medicine(base.duplicate(true))
	print("SICK DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

## A kin left alone for NEGLECT_DAYS, asserting it never dies and does reach sick.
func _neglected(nm: String) -> Dictionary:
	var r := Save.new_kin("zapple", nm)
	Care.ensure(r)
	r["likes"]["hates"] = "kibble" if r["likes"]["food"] != "kibble" else "sweetbun"
	Save.d["roster"] = [r]
	Save.d["feeders"] = []
	var sick_seen := false
	var dead_seen := false
	for i in int(NEGLECT_DAYS * 86400.0 / STEP_S):
		Care.tick(r, STEP_S)
		sick_seen = sick_seen or Care.starve_stage(r) == "sick"
		dead_seen = dead_seen or Care.starve_stage(r) == "dead"
	var deaths := Econ.check_starving().filter(func(e): return e["kind"] == "died")
	ok(Save.d["roster"].has(r) and not dead_seen and deaths.is_empty(), "%d days of neglect: no death" % NEGLECT_DAYS)
	var stage := Care.starve_stage(r)
	ok(sick_seen and stage == "sick", "...a sick state reached, and held (stage %s)" % stage)
	return r

## What the sick Boki shows: a slow pace, a card line saying what helps, a drooped body.
func _looks(r: Dictionary) -> void:
	ok(Care.pace(r) == Care.PACE_SICK and Care.ailing(r), "sick: slow walk (pace %.1f)" % Care.pace(r))
	var line := String(Care.STARVE_INFO["sick"][1])
	var helps := ["Feed", "nap", "friend", "Puffcorn"].all(func(w): return line.contains(w))
	ok(helps, "the card line says what helps")
	var n := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	n.add_child(body)
	var k := {"rec": r}
	for i in 60: KinAiling.pose(k, n, 0.1)
	ok(body.rotation.x > KinAiling.DROOP_WEAK, "...head drooped (lean %.2f)" % body.rotation.x)
	r.erase("starve")
	for i in 60: KinAiling.pose(k, n, 0.1)
	var upright: bool = body.rotation.x == 0.0 and not k.has("droop")
	ok(upright and Care.pace(r) == 1.0, "...and upright and at full pace once well")
	r["starve"] = Care.STARVE["sick"] * 3600.0
	n.free()

## Seconds of care until the kin is fully well (0 if never within the limit): one meal, then kept
## half full; resting means asleep the whole time.
func _care(r: Dictionary, rest: bool, friend: bool) -> float:
	var t := 0.0
	Care.feed(r, "sweetbun")
	while t < CARE_LIMIT_S:
		Care.change(r, "food", maxf(0.0, 50.0 - Care.need(r, "food")))      # stays fed without more meals
		Care.tick(r, STEP_S, rest, friend)
		t += STEP_S
		if Care.starve_stage(r) == "" and not r.has("starve"):
			return t
	return 0.0

func _medicine(r: Dictionary) -> void:
	r["likes"]["hates"] = "kibble"
	var res := Care.feed(r, "puffcorn")
	var well_now: bool = Care.starve_stage(r) == "" and Care.pace(r) == 1.0
	ok(res.get("cured", false) and well_now, "one Puffcorn snack cures a sick Boki at once")
	var well := Save.new_kin("zapple", "Well")
	res = Care.feed(well, "puffcorn")
	ok(not res.get("cured", false), "...a well Boki just has a snack")
