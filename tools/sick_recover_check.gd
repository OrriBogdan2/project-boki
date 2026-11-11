extends RefCounted
## --sick-recover-check: neglect never kills (care.json natural_death false, DECISIONS 2026-11-08), and
## care brings a Boki back. 10 days with nothing to eat (one-minute ticks) end sick and alive; then,
## fed, it is well within 2 days, faster with a nap and with a friend close (KinAiling.friend_near),
## and one Puffcorn (the snack crop) cures it at once. Never touches the real save.

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
	ok(not bool(Content.rules("care")["natural_death"]), "care.json natural_death is off")
	var base := _neglected("Pip")
	var line := String(Care.STARVE_INFO["sick"][1])
	ok(["Feed", "nap", "friend", "Puffcorn"].all(func(w): return line.contains(w)), "the card line says what helps")
	var fed_s := _care(base.duplicate(true), false, false)
	var nap_s := _care(base.duplicate(true), true, false)
	var pal_s := _care(base.duplicate(true), false, true)
	var all_s := _care(base.duplicate(true), true, true)
	ok(fed_s > 0.0 and fed_s <= CARE_LIMIT_S, "fed only: well in %.1f h (limit 48 h)" % (fed_s / 3600.0))
	ok(nap_s > 0.0 and nap_s < fed_s, "...a nap speeds it up (%.1f h)" % (nap_s / 3600.0))
	ok(pal_s > 0.0 and pal_s < fed_s, "...a friend close speeds it up (%.1f h)" % (pal_s / 3600.0))
	ok(all_s > 0.0 and all_s < nap_s and all_s < pal_s, "...both together faster still (%.1f h)" % (all_s / 3600.0))
	_friend(base.duplicate(true))
	_medicine(base.duplicate(true))
	print("SICK DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

## A kin left alone for NEGLECT_DAYS, asserting it never dies and does reach sick.
func _neglected(nm: String) -> Dictionary:
	var r := Save.new_kin("cindle", nm)
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
	ok(sick_seen and stage == "sick" and Care.ailing(r), "...it got sick, and stays sick (stage %s)" % stage)
	return r

## Seconds of care until the kin is fully well (0 if never within the limit): one meal, then kept
## half full; rest: asleep the whole time; friend: another Boki close the whole time.
func _care(r: Dictionary, rest: bool, friend: bool) -> float:
	var t := 0.0
	Care.feed(r, "sweetbun")
	while t < CARE_LIMIT_S:
		Care.change(r, "food", maxf(0.0, 50.0 - Care.need(r, "food")))      # stays fed without more meals
		Care.tick(r, STEP_S, rest, false, friend)
		t += STEP_S
		if Care.starve_stage(r) == "" and not r.has("starve"):
			return t
	return 0.0

## The farm's friend test: only a Boki close by, outdoors, counts, and only for an ailing one.
func _friend(r: Dictionary) -> void:
	var k := {"rec": r, "pos": Vector3.ZERO}
	var near := {"rec": Save.new_kin("cindle", "Pal"), "pos": Vector3(1.0, 0.0, 0.0)}
	var far := {"rec": near["rec"], "pos": Vector3(FarmChatter.FRIEND_R + 1.0, 0.0, 0.0)}
	var inside := {"rec": near["rec"], "pos": near["pos"], "indoors": true}
	ok(KinAiling.friend_near([k, near], k) and not KinAiling.friend_near([k, far], k)
			and not KinAiling.friend_near([k, inside], k), "a friend counts only when close and outdoors")
	ok(not KinAiling.friend_near([near, k], near), "...and only for a weak or sick Boki")

func _medicine(r: Dictionary) -> void:
	r["likes"]["hates"] = "kibble"
	Save.d["crops"]["puffcorn"] = 1
	ok(KinWants.best_food(r) == "puffcorn", "a sick Boki is offered the Puffcorn first")
	var res := Care.feed(r, "puffcorn")
	var well_now: bool = Care.starve_stage(r) == "" and not Care.ailing(r)
	ok(res.get("cured", false) and well_now, "one Puffcorn snack cures a sick Boki at once")
	var well := Save.new_kin("cindle", "Well")
	res = Care.feed(well, "puffcorn")
	ok(not res.get("cured", false), "...a well Boki just has a snack")
