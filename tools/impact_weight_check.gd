extends RefCounted
## --impact-weight-check: every damaging Hunter ability has a hit weight (content/rules/impact_weight.json),
## and the weights hold, shake and stack as the rules say.
##   1. the rules: exactly light, solid and heavy, each heavier than the last, heavy under the cap and the
##      footage bound (one 10 fps frame);
##   2. every Hunter names a tier for its LMB and its ult, and every name is one of the three;
##   3. every hit tag ("ab") a Hunter's kit files deal damage with resolves to an ability that has a tier;
##   4. all 13 Hunters press LMB / RMB / E / X / dash at a dummy: every slot that lands damage has a tier;
##   5. a light, solid and heavy hit hold the struck body for their fixed time, a ranged one never the attacker;
##   6. the team-fight cap: six heavy hits on one body at once hold it no longer than the cap, and five heavy
##      hits on you inside the shake gap start one shake.
## Reuses the dash-flow check's training match and slot presses. Never touches the save.

const SLOTS := ["lmb", "rmb", "e", "x", "dash"]
const FOOTAGE_BOUND_MS := 100      # one 10 fps frame: the reference footage never holds longer
## Steps with no hit from the hunter before the next slot, so a zone left behind has run out.
const QUIET_STEPS := 90
const DRAIN_MAX := 900             # steps at most spent waiting for it
## Kit file name prefix -> the Hunter whose code it is (a Hunter's ult or dash can live in its own file).
const FILE_HERO := {
	"archer": "archer", "pin": "archer", "ashwick": "ashwick", "bjorn": "bulwark", "breah": "dolm",
	"bulwark": "bulwark", "dolm": "dolm", "dredge": "dredge", "gil": "gil", "gunslinger": "gunslinger",
	"juggernaut": "juggernaut",
	"mage": "mage", "ostra": "ostra", "rimewright": "rimewright", "tender": "tender", "thief": "thief",
}

var bad := 0
var dealt := {}                    # slot -> true: the slot being pressed landed damage
var slot_now := ""
var hits_n := 0                    # every damaging hit from the hunter, for the drain between slots
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("IMPACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_rules()
	_named()
	_kit_tags()
	CombatBus.hit_landed.connect(_on_hit)
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		_presses(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	var m2: Match = flow._match(main, Arch.ORDER[0])
	_holds(m2)
	_stacking(m2)
	m2.queue_free()
	print("IMPACT DONE, failures: %d" % bad)
	main.get_tree().quit()

func _on_hit(by: Node, _t: Node, amount: float, _tags: Array) -> void:
	if by != flow.hunter or amount <= 0.0:
		return
	hits_n += 1
	if slot_now != "":
		dealt[slot_now] = true

func _rules() -> void:
	var tiers: Dictionary = ImpactWeight.rules["tiers"]
	ok(tiers.keys() == ImpactWeight.TIERS, "three tiers: %s" % ", ".join(tiers.keys()))
	var ms := ImpactWeight.TIERS.map(func(w): return int(tiers[w]["hitstop_ms"]))
	var sh := ImpactWeight.TIERS.map(func(w): return float(tiers[w]["shake"]))
	ok(ms[0] < ms[1] and ms[1] < ms[2] and sh[0] <= sh[1] and sh[1] < sh[2],
		"each tier holds and shakes more than the last: %s ms, shake %s" % [ms, sh])
	ok(ms[2] < FOOTAGE_BOUND_MS and ms[2] <= ImpactWeight.cap("hitstop_ms"),
		"heavy %d ms is under the footage bound and the cap" % ms[2])
	ok(not bool(tiers["light"]["attacker"]), "a light poke never holds the one who threw it")

func _named() -> void:
	var hunters: Dictionary = ImpactWeight.rules["hunters"]
	for hero in Arch.ORDER:
		var row: Dictionary = hunters.get(hero, {})
		var odd: Array = row.keys().filter(func(a): return not ImpactWeight.TIERS.has(String(row[a])))
		ok(row.has("lmb") and row.has("x") and odd.is_empty(),
			"%s: LMB %s, ult %s, not a tier: %s" % [hero, row.get("lmb", "-"), row.get("x", "-"), odd])
	var n := Arch.ORDER.size()
	ok(hunters.size() == n, "the rules name %d Hunters (there are %d)" % [hunters.size(), n])

## Every "ab" literal in a Hunter's kit files: the ability it resolves to has a tier.
func _kit_tags() -> void:
	var dir := DirAccess.open("res://scripts/arch/kits")
	var rx := RegEx.create_from_string("\"ab\": \"(\\w+)\"")
	var missing := []
	var seen := 0
	for f in dir.get_files():
		var hero := String(FILE_HERO.get(f.get_slice("_", 0), ""))
		if hero == "" or not f.ends_with(".gd"):
			continue
		for hit in rx.search_all(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)):
			seen += 1
			var ab := ImpactWeight.ability_of({"ab": hit.get_string(1)})
			if ImpactWeight.of_ability(hero, ab) == "":
				missing.append("%s %s (%s)" % [hero, ab, f])
	ok(seen > 40 and missing.is_empty(), "%d kit hit tags all have a tier, missing: %s" % [seen, missing])

func _presses(m: Match, hero: String) -> void:
	var h: Hunter = flow.hunter
	dealt = {}
	for slot in SLOTS:
		flow._ready_up(m)
		var dummy := _dummy(m)
		slot_now = slot
		if slot == "dash":
			h.inp["move"] = Vector2(0, -1)
			h.inp["dash"] = true
		else:
			flow._press(slot)
		for i in 150:
			m.step(Match.DT)
			h.inp["dash"] = false
			h.inp["fire"] = slot == "lmb" and i < 20
			dummy.hp = dummy.max_hp
		slot_now = ""
		_drain(m, dummy)
	var untiered: Array = dealt.keys().filter(func(s): return ImpactWeight.of_ability(hero, s) == "")
	ok(dealt.has("lmb") and untiered.is_empty(),
		"%s: damaging slots %s all have a tier, missing: %s" % [hero, dealt.keys(), untiered])

## Steps until nothing the slot left behind hits any more, so its hits never count for the next slot.
func _drain(m: Match, dummy: Hunter) -> void:
	var quiet := 0
	var seen := hits_n
	for i in DRAIN_MAX:
		m.step(Match.DT)
		dummy.hp = dummy.max_hp
		quiet = quiet + 1 if hits_n == seen else 0
		seen = hits_n
		if quiet >= QUIET_STEPS:
			return

## A bot standing still 3 m north of the hunter, where the presses aim (in reach of a melee LMB).
func _dummy(m: Match) -> Hunter:
	var h: Hunter = flow.hunter
	for o in m.hunters:
		if o != h:
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(0, 0, -3))
			o.hp = o.max_hp
			return o
	return null

## The struck body's hold per tier, between two bodies away from the player (the player's own hits use the
## global freeze), 10 m apart so every hit is ranged.
func _holds(m: Match) -> void:
	var a := _body("archer", Vector3(40, 0, 40))
	var t := _body("", Vector3(50, 0, 40))
	var row := {
		"light": {"src": "shot"}, "solid": {"src": "abil", "ab": "utility"}, "heavy": {"src": "abil", "ab": "ult"},
	}
	for w in ImpactWeight.TIERS:
		m.time += 1.0                     # (out of the last hit's repeat window and cap)
		a.freeze_t = 0.0
		t.freeze_t = 0.0
		var got := Feel.hitstop(m, a, t, 5.0, row[w])
		ok(got == w and is_equal_approx(t.freeze_t, ImpactWeight.hold_s(w)) and a.freeze_t == 0.0,
			"a ranged %s hit holds the body %.0f ms, the shooter 0 (got %s, %.0f / %.0f ms)"
				% [w, ImpactWeight.hold_s(w) * 1000.0, got, t.freeze_t * 1000.0, a.freeze_t * 1000.0])
	a.free()
	t.free()

func _stacking(m: Match) -> void:
	var cap_s := ImpactWeight.cap("hitstop_ms") / 1000.0
	var t := _body("", Vector3(50, 0, 40))
	var foes: Array = []
	for i in 6:
		foes.append(_body("juggernaut", Vector3(40 + i, 0, 40)))
	m.time += 1.0
	var start := m.time
	var held := 0.0
	for f in foes:
		t.freeze_t = 0.0
		Feel.hitstop(m, f, t, 30.0, {"src": "abil", "ab": "ult"})
		held += t.freeze_t
		m.time += 0.05
	ok(held <= cap_s + 0.0001, "six heavy hits on one body in %.2f s hold it %.0f ms in all (cap %d)"
		% [m.time - start, held * 1000.0, int(cap_s * 1000.0)])
	# five heavy hits on you from enemies inside one gap: one shake starts, and your game holds no longer than the cap
	Settings.v["screen_shake"] = 1.0
	var p: Hunter = m.player
	m.time += 2.0
	m.hitstop = 0.0
	m.cam.shake_left = 0.0
	var starts := 0
	for i in 5:
		var f: Hunter = foes[i]
		f.team = p.team + 1
		f.pos = p.pos + Vector3(4, 0, 0)
		var before: float = m.cam.shake_left
		Feel.hitstop(m, f, p, 30.0, {"src": "abil", "ab": "ult"})
		if m.cam.shake_left > before + 0.0001: starts += 1
		m.time += 0.06
	ok(starts == 1, "five heavy hits on you in 0.3 s start %d shake (want 1)" % starts)
	ok(m.hitstop <= cap_s + 0.0001,
		"and hold your game %.0f ms at most (cap %d)" % [m.hitstop * 1000.0, int(cap_s * 1000.0)])
	Settings.v["screen_shake"] = Settings.DEFAULTS["screen_shake"]
	for f in foes:
		f.free()
	t.free()

## A free-standing body for direct Feel calls (no match tree).
func _body(arch: String, at: Vector3) -> Hunter:
	var b := Hunter.new()
	b.arch = arch
	b.max_hp = 145.0
	b.pos = at
	return b
