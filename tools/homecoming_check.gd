extends RefCounted
## --homecoming-check (GARDEN.md section 2): with base_mode on, the player comes home from a run (BaseLife.returning).
## Round 1: three awake Boki of different trust and bravery start the same distance from the portal; the one with the
## highest trust gets there first (trust order), each greets by its trait (bound, wave, shy peek), and every one is
## back in the state it was in (Roam) within 15 s. Round 2: two napping Boki, one low trust and one high: the first
## sleeps on, the second is woken, greets and goes back to its nap. No machine refuses a transition. Never touches
## the real save.

const WITHIN := 15.0         # s: everyone is back to what they were doing by then
const DT := 0.25             # s per farm step
const START_R := 12.0        # m from the portal every greeter starts
const ISLAND_SEED := 5       # the farm-start island (a random one each run moved the ring round the portal)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HOMECOMING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _new_save() -> Array:
	var d := Save.fresh()
	var recs: Array = []
	# name, species, trust, bravery: bound (high trust, brave), wave, shy (low trust)
	for spec in [["cindle", "Ash", 90.0, 0.9], ["burrlet", "Moss", 60.0, 0.5], ["basaltoad", "Crag", 20.0, 0.1]]:
		var rec := Save.new_kin(spec[0], spec[1], recs.size() + 1)      # a fixed Unique roll: the same body every run
		rec["uid"] = "homecoming_%s" % spec[1]      # likes are seeded from the uid
		rec["trust"] = spec[2]
		rec["traits"]["bravery"] = spec[3]
		recs.append(rec)
	recs[0]["starter"] = true
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.new_fs(d, ISLAND_SEED)
	HomeLayout.ensure(d)
	return recs

## Everyone on a ring round the portal, the same distance away, and not near the player.
func _ring(home) -> void:
	var portal: Vector3 = home.spots["portal"]
	var i := 0
	for k in home.kins:
		var a: float = float(i) * TAU / float(home.kins.size())
		k["pos"] = home.world.free_spot_near(portal + Vector3(cos(a), 0, sin(a)) * START_R, [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]
		k["vel"] = Vector3.ZERO
		i += 1

func _kin(home, who: String) -> Dictionary:
	for k in home.kins:
		if k["rec"]["name"] == who:
			return k
	return {}

## Runs the farm until every Boki's welcome is over (or WITHIN + 5 s pass). Returns name -> {arrive, back, kind}, with
## the seconds from the start at which it began its greeting and at which its state machine left REACT.
func _welcome(home) -> Dictionary:
	var seen := {}
	var t := 0.0
	while t < WITHIN + 5.0:
		home._move_kin(DT)
		t += DT
		for k in home.kins:
			var who: String = k["rec"]["name"]
			var hm: Dictionary = k.get("life_home", {})
			if not seen.has(who):
				seen[who] = {"arrive": -1.0, "back": -1.0, "kind": ""}
			if hm.get("phase", "") == "greet" and float(seen[who]["arrive"]) < 0.0:
				seen[who]["arrive"] = t
				seen[who]["kind"] = hm["kind"]
			if hm.is_empty() and float(seen[who]["arrive"]) >= 0.0 and float(seen[who]["back"]) < 0.0:
				seen[who]["back"] = t
		if seen.values().all(func(s): return float(s["back"]) >= 0.0):
			break
	return seen

func run(main: Node) -> void:
	Save.no_write = true
	seed(5)
	var rules: Dictionary = Content.rules("farm_build")
	rules["base_mode"] = true
	_new_save()
	var home = await main._hb_home()
	seed(5)      # again: the home used up a different number of rolls in the real frames it took to build
	ok(home.life != null, "base_mode on: the farm runs BaseLife")
	home.day_t = 0.4
	home.ppos = home.spots["portal"] + Vector3(0, 0, -4.5)
	_ring(home)
	for k in home.kins:
		home.life.machine(k)
	BaseLife.returning = true
	home.life.come_home()
	var seen := await _welcome(home)
	var ash: Dictionary = seen["Ash"]
	var moss: Dictionary = seen["Moss"]
	var crag: Dictionary = seen["Crag"]
	print("HOMECOMING arrivals ", seen)
	ok(not BaseLife.returning, "the welcome is used up once the farm has opened")
	var ran: bool = seen.values().all(func(s): return float(s["arrive"]) >= 0.0)
	ok(ran, "all three Boki ran to the portal")
	ok(float(ash["arrive"]) < float(moss["arrive"]) and float(moss["arrive"]) < float(crag["arrive"]),
		"trust order: Ash 90 first, Moss 60 next, Crag 20 last")
	ok(ash["kind"] == "bound" and moss["kind"] == "wave" and crag["kind"] == "shy",
		"each greets by trait: bound, wave, shy peek (%s, %s, %s)" % [ash["kind"], moss["kind"], crag["kind"]])
	var back_all: bool = true
	for who in seen:
		var k := _kin(home, who)
		var done := float(seen[who]["back"]) >= 0.0 and float(seen[who]["back"]) <= WITHIN
		var line := ""
		for l in (k["life"] as Fsm).history:
			if l.contains("React>Roam") and l.contains("greeted"):
				line = l
		back_all = back_all and done and line != ""
	var backs: Array = seen.values().map(func(s): return s["back"])
	ok(back_all, "all three are back in their state (Roam) within %.0f s (%s)" % [WITHIN, backs])
	var m: Fsm = _kin(home, "Moss")["life"]
	var moss_k := _kin(home, "Moss")
	ok(not m.is_in(BaseLife.S.REACT) and not moss_k.has("life_home"), "the greeting leaves no React state behind")
	# round 2: two napping Boki, one with low trust and one with high
	for k in home.kins:
		k["life_run"] = false
		k.erase("life_run")
	for who in ["Ash", "Crag"]:
		var k := _kin(home, who)
		var fsm: Fsm = k["life"]
		fsm.go(BaseLife.S.NAP, "test")
		k["nap_t"] = 60.0
	_kin(home, "Moss")["busy"] = true      # the farm is driving this one: it stays out of it
	_ring(home)
	BaseLife.returning = true
	home.life.come_home()
	var seen2 := await _welcome(home)
	var ash2: Fsm = _kin(home, "Ash")["life"]
	var crag2: Fsm = _kin(home, "Crag")["life"]
	var ash_back := float(seen2["Ash"]["back"])
	ok(ash_back >= 0.0 and ash_back <= WITHIN, "the high-trust napper woke, greeted, was back in %.0f s" % WITHIN)
	ok(ash2.is_in(BaseLife.S.NAP) and float(_kin(home, "Ash").get("nap_t", 0.0)) > 0.0, "and went back to its nap")
	ok(float(seen2["Crag"]["arrive"]) < 0.0 and crag2.is_in(BaseLife.S.NAP), "the low-trust napper slept through it")
	ok(float(seen2["Moss"]["arrive"]) < 0.0, "a Boki the farm is driving is left alone")
	var refused := 0
	for k in home.kins:
		refused += (k["life"] as Fsm).refused
	ok(refused == 0, "no machine refused a transition (%d)" % refused)
	rules["base_mode"] = false
	home.queue_free()
	print("HOMECOMING DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
