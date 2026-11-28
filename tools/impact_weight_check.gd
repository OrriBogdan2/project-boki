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
##      hits on you inside the shake gap start one shake;
##   7. the hit-feel table (DASHES_AND_ABILITY_FEEL.md §5.4): in 4, the lightest hit an LMB / RMB / X lands on
##      the dummy is its rules tier (TIER_OK lists the explained exceptions), the dummy never flashes longer than
##      a tier's flash and your own camera never shakes; one HITFEEL row per Hunter (LMB light, RMB heavy, X ult);
##   8. every freeze of your game, whoever asks (Match.freeze_frame: an armor break, a parry, a Boki's strike),
##      shares that cap, and one asked while another runs costs only the time it adds.
##   9. no kit file sets its own hit-stop, body flash or shake number: they come from the tiers.
##  10. a summoned Boki hits and is hit on the same tiers: its basic bite is light, its ability (a tagged hit, the
##      throw, the recall) solid, each holds the struck body and flashes it by the tier's numbers, and no Boki
##      file (scripts/kin, scripts/match/kin*.gd) sets its own freeze or flash number. One HITFEEL boki row.
##  11. the hit-stop tier table (docs/MOVEMENT_FEEL.d/1128-hitstop-tiers.md, tools/hitstop_tier_table.gd): every
##      Hunter's LMB / RMB / E / R row matches what 4 measured, and a hit the source makes heavy lands heavy.
## Reuses the dash-flow check's training match and slot presses. Never touches the save.

const SLOTS := ["lmb", "rmb", "e", "x", "dash"]
const TierTable := preload("res://tools/hitstop_tier_table.gd")
const FOOTAGE_BOUND_MS := 100  # one 10 fps frame: the reference footage never holds longer

## Steps with no hit from the hunter before the next slot, so a zone left behind has run out.
const QUIET_STEPS := 90

## Steps LMB is held: a spooling stream (Ashwick: 0.2 s spool, then 3 m at 16 m/s) needs ~0.4 s to reach the dummy.
const LMB_HOLD := 45
const DRAIN_MAX := 900  # steps at most spent waiting for it

## Kit file name prefix -> the Hunter whose code it is (a Hunter's ult or dash can live in its own file).
const FILE_HERO := {
	"archer": "archer",
	"pin": "archer",
	"ashwick": "ashwick",
	"bjorn": "bulwark",
	"breah": "dolm",
	"bulwark": "bulwark",
	"dolm": "dolm",
	"dredge": "dredge",
	"gil": "gil",
	"gunslinger": "gunslinger",
	"juggernaut": "juggernaut",
	"mage": "mage",
	"ostra": "ostra",
	"rimewright": "rimewright",
	"tender": "tender",
	"thief": "thief",
}
const TABLE_SLOTS := {"lmb": "light", "rmb": "heavy", "x": "ult"}

## 7: one slot's measured hit feel matches the tiers.
## Table slots whose hits are not their rules tier, and why (docs/DASHES_AND_ABILITY_FEEL.md §5.4).
const TIER_OK := {
	"rimewright rmb": "heavy",  # the lance's detonation is a payoff (one weight heavier); its landing only slows
	"ashwick x": "",  # the lava carpet burns and slows in ticks: no hit-stop (T0)
	"dolm lmb": "solid",  # the punch is an empowered hit (o.heavy: never a poke); the boulder splash is light
}

## 8: kit files take hit-stop, body flash and shake from the tiers (shake: a class in content/rules/shake.json,
## --shake-check's table). A foe's flash_t, a freeze_frame / freeze_t or a Shake.incoming_big set to a number
## or a CONSTANT is a stray (a Hunter's own flash, h.flash_t, is no hit).

var bad := 0
var dealt := {}  # slot -> true: the slot being pressed landed damage
var slot_now := ""
var hits_n := 0  # every damaging hit from the hunter, for the drain between slots
var flow := preload("res://tools/dash_flow_check.gd").new()

## The hit-feel table (7): hero -> slot -> {hold, flash, freeze, shake} peaks (s; hold and flash read after a
## step, so the value set lies within one DT above them).
var feel := {}
var dummy_now: Ent = null
var hit_tags := {}  # the tags of the slot's hits on the dummy (what a stray row names)
var self_hits := {}  # the tags of hits on the hunter itself during the slot


func ok(cond: bool, what: String) -> void:
	print("IMPACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	_rules()
	_named()
	_kit_tags()
	_kit_literals()
	_boki_literals()
	CombatBus.hit_landed.connect(_on_hit)
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		_presses(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	var m2: Match = flow._match(main, Arch.ORDER[0])
	_holds(m2)
	_stacking(m2)
	_boki(m2)
	m2.queue_free()
	_table()
	TierTable.check(feel, ok)
	print("IMPACT DONE, failures: %d" % bad)
	main.get_tree().quit()


func _on_hit(by: Node, t: Node, amount: float, tags: Array) -> void:
	if by != flow.hunter or amount <= 0.0:
		return
	hits_n += 1
	if slot_now != "" and t == dummy_now:
		hit_tags[",".join(tags)] = true
	if slot_now != "" and t == flow.hunter:
		self_hits[",".join(tags)] = true
	if slot_now != "":
		dealt[slot_now] = true


func _rules() -> void:
	var tiers: Dictionary = ImpactWeight.rules["tiers"]
	ok(tiers.keys() == ImpactWeight.TIERS, "three tiers: %s" % ", ".join(tiers.keys()))
	var ms := ImpactWeight.TIERS.map(func(w): return int(tiers[w]["hitstop_ms"]))
	var sh := ImpactWeight.TIERS.map(func(w): return ImpactWeight.shake(w))
	ok(
		ms[0] < ms[1] and ms[1] < ms[2] and sh[0] <= sh[1] and sh[1] < sh[2],
		"each tier holds and shakes more than the last: %s ms, shake %s" % [ms, sh]
	)
	ok(
		ms[2] < FOOTAGE_BOUND_MS and ms[2] <= ImpactWeight.cap("hitstop_ms"),
		"heavy %d ms is under the footage bound and the cap" % ms[2]
	)
	ok(not bool(tiers["light"]["attacker"]), "a light poke never holds the one who threw it")


func _named() -> void:
	var hunters: Dictionary = ImpactWeight.rules["hunters"]
	for hero in Arch.ORDER:
		var row: Dictionary = hunters.get(hero, {})
		var odd: Array = row.keys().filter(func(a): return not ImpactWeight.TIERS.has(String(row[a])))
		ok(
			row.has("lmb") and row.has("x") and odd.is_empty(),
			"%s: LMB %s, ult %s, not a tier: %s" % [hero, row.get("lmb", "-"), row.get("x", "-"), odd]
		)
	var n := Arch.ORDER.size()
	ok(hunters.size() == n, "the rules name %d Hunters (there are %d)" % [hunters.size(), n])


## Every "ab" literal in a Hunter's kit files: the ability it resolves to has a tier.
func _kit_tags() -> void:
	var dir := DirAccess.open("res://scripts/arch/kits")
	var rx := RegEx.create_from_string('"ab": "(\\w+)"')
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
	if h.ak is GilKit:  # Gil's bag is seeded by his instance id: a fixed order keeps his RMB row from flaking (11)
		(h.ak as GilKit).rng.seed = hash("gil_bag_impact")
		(h.ak as GilKit)._refill()
	for slot in SLOTS:
		flow._ready_up(m)
		var dummy := _dummy(m)
		if flow.ally and slot != "x":
			h.inp["aim"] = dummy.pos + Vector3(0, 0.9, 0)  # _ready_up aims a NEEDS_ALLY hero at its teammate
		slot_now = slot
		if slot == "dash":
			h.inp["move"] = Vector2(0, -1)
			h.inp["dash"] = true
		else:
			flow._press(slot)
		dummy_now = dummy
		hit_tags = {}
		self_hits = {}
		var pair := "%s|%s" % [h.get_instance_id(), dummy.get_instance_id()]
		var seen_t := float(Feel._pair.get(pair, [-9.0, 0])[0])
		# per step, only on a step the hunter's own hit landed (Feel's pair record moved): the dummy's hold and
		# flash, your freeze; your camera on every step. (The hunter's Boki hits the dummy too: those steps skip.)
		var pk := {"hold": 0.0, "flash": 0.0, "freeze": 0.0, "shake": 0.0, "tiers": {}}
		for i in 150:
			m.hitstop = 0.0
			m.cam.shake_left = 0.0
			var mets: int = m.meteors.size()
			m.step(Match.DT)
			h.inp["dash"] = false
			h.inp["fire"] = slot == "lmb" and i < LMB_HOLD
			dummy.hp = dummy.max_hp
			if m.meteors.size() >= mets:  # (a meteor landing near you is the world's shake, not the kit's)
				pk["shake"] = maxf(pk["shake"], m.cam.shake_left)
			var last: Array = Feel._pair.get(pair, [-9.0, 0])  # [time, tier index] of the last weighted hit
			if float(last[0]) <= seen_t:
				continue
			seen_t = float(last[0])
			var tw: String = ImpactWeight.TIERS[int(last[1])]
			pk["tiers"][tw] = int(pk["tiers"].get(tw, 0)) + 1
			pk["hold"] = maxf(pk["hold"], dummy.freeze_t)
			pk["flash"] = maxf(pk["flash"], dummy.flash_t)
			pk["freeze"] = maxf(pk["freeze"], m.hitstop)
		pk["tags"] = hit_tags.keys()
		pk["self"] = self_hits.keys()
		slot_now = ""
		if dealt.has(slot):
			feel[hero] = feel.get(hero, {})
			feel[hero][slot] = pk
			_feel_ok(hero, slot, pk)
		_drain(m, dummy)
	var untiered: Array = dealt.keys().filter(func(s): return ImpactWeight.of_ability(hero, s) == "")
	ok(
		dealt.has("lmb") and untiered.is_empty(),
		"%s: damaging slots %s all have a tier, missing: %s" % [hero, dealt.keys(), untiered]
	)


## The tier whose hit-stop a peak read after a step came from (it was set at most one DT above it), or "".
func _tier_of(peak: float) -> String:
	for w in ImpactWeight.TIERS:
		var s := ImpactWeight.hold_s(w)
		if s >= peak - 0.0001 and s <= peak + Match.DT + 0.0001:
			return w
	return ""


func _feel_ok(hero: String, slot: String, pk: Dictionary) -> void:
	var own := ImpactWeight.of_ability(hero, slot)
	var seen: Array = (pk["tiers"] as Dictionary).keys()
	var lightest := ""
	for w in ImpactWeight.TIERS:
		if seen.has(w):
			lightest = w
			break
	var want := String(TIER_OK.get("%s %s" % [hero, slot], own))
	print(
		(
			"HITDIAG %s %s own %s tiers %s hold %.0f flash %.0f freeze %.0f shake %.3f tags %s"
			% [
				hero,
				slot,
				own,
				pk["tiers"],
				pk["hold"] * 1000.0,
				pk["flash"] * 1000.0,
				pk["freeze"] * 1000.0,
				pk["shake"],
				pk["tags"]
			]
		)
	)
	if TABLE_SLOTS.has(slot) and not (pk["tags"] as Array).is_empty():
		ok(
			lightest == want,
			(
				"%s %s: its lightest hit on the dummy is '%s' (rules %s, want '%s'), hits %s"
				% [hero, slot, lightest, own, want, pk["tiers"]]
			)
		)
	# a landed combo payoff flashes a little longer (ComboMark.payoff, the owner's combo-clarity rule)
	var fl := maxf(ImpactWeight.flash_s("heavy"), ComboMark.FLASH_BODY)
	ok(
		pk["flash"] <= fl + 0.0001 and pk["shake"] < 0.0001,
		(
			"%s %s: the dummy flashes %.0f ms at most (tiers or a payoff %.0f), your own camera shakes %.3f s (want 0)"
			% [hero, slot, pk["flash"] * 1000.0, fl * 1000.0, pk["shake"]]
		)
	)


func _kit_literals() -> void:
	var num := "([0-9.]+|[A-Z][A-Z_0-9]+)"  # a number or a CONSTANT
	var rx := RegEx.create_from_string(
		(
			"(\\b(?!h\\.)\\w+\\.flash_t = (maxf\\(\\w+\\.flash_t, )?"
			+ num
			+ "|freeze_frame\\("
			+ num
			+ "|freeze_t, "
			+ num
			+ "|Shake\\.incoming_big\\([^)]*, "
			+ num
			+ ", [^)]*\\))"
		)
	)
	var dir := DirAccess.open("res://scripts/arch/kits")
	var strays := []
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		for hit in rx.search_all(FileAccess.get_file_as_string("res://scripts/arch/kits/" + f)):
			strays.append("%s:%s" % [f, hit.get_string(0)])
	ok(strays.is_empty(), "no kit sets its own hit-stop, body flash or shake number, strays: %s" % [strays])


## Prints the hit-feel table (DASHES_AND_ABILITY_FEEL.md §5.4): per Hunter, LMB / RMB / X: the tier the dummy held, its
## hold, your freeze, the body flash, and the struck player's shake (the tier's; your own camera is asserted 0).
func _table() -> void:
	for hero in Arch.ORDER:
		var cells := []
		for slot in TABLE_SLOTS:
			var pk: Dictionary = feel.get(hero, {}).get(slot, {})
			var tiers: Dictionary = pk.get("tiers", {})
			if pk.is_empty() or (pk["tags"] as Array).is_empty():
				var named := ImpactWeight.of_ability(hero, slot)
				cells.append("%s: no hit on the dummy (rules %s)" % [TABLE_SLOTS[slot], named])
				continue
			var rows := []
			for w in tiers:
				var ms := roundi(ImpactWeight.hold_s(w) * 1000.0)
				rows.append(
					(
						"%s x%d (%d ms, flash %d ms, shake %.1f)"
						% [w, tiers[w], ms, roundi(ImpactWeight.flash_s(w) * 1000.0), ImpactWeight.shake(w)]
					)
				)
			cells.append(
				(
					"%s: %s (rules %s)"
					% [
						TABLE_SLOTS[slot],
						", ".join(rows) if rows else "ticks only, no hold",
						ImpactWeight.of_ability(hero, slot)
					]
				)
			)
		print("HITFEEL %s | %s" % [hero, " | ".join(cells)])


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
		if o.team != h.team:  # a NEEDS_ALLY hero's squad mate is no target
			o.ctrl = "idle"
			o.teleport(h.pos + Vector3(0, 0, -3))
			o.hp = o.max_hp
			if o.kin is Kin:
				(o.kin as Kin).state = "bench"  # its Boki sits out: an enemy burst near you shakes you (7)
			return o
	return null


## The struck body's hold per tier, between two bodies away from the player (the player's own hits use the
## global freeze), 10 m apart so every hit is ranged.
func _holds(m: Match) -> void:
	var a := _body("archer", Vector3(40, 0, 40))
	var t := _body("", Vector3(50, 0, 40))
	var row := {
		"light": {"src": "shot"},
		"solid": {"src": "abil", "ab": "utility"},
		"heavy": {"src": "abil", "ab": "ult"},
	}
	for w in ImpactWeight.TIERS:
		m.time += 1.0  # (out of the last hit's repeat window and cap)
		a.freeze_t = 0.0
		t.freeze_t = 0.0
		var got := Feel.hitstop(m, a, t, 5.0, row[w])
		ok(
			got == w and is_equal_approx(t.freeze_t, ImpactWeight.hold_s(w)) and a.freeze_t == 0.0,
			(
				"a ranged %s hit holds the body %.0f ms, the shooter 0 (got %s, %.0f / %.0f ms)"
				% [w, ImpactWeight.hold_s(w) * 1000.0, got, t.freeze_t * 1000.0, a.freeze_t * 1000.0]
			)
		)
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
	ok(
		held <= cap_s + 0.0001,
		(
			"six heavy hits on one body in %.2f s hold it %.0f ms in all (cap %d)"
			% [m.time - start, held * 1000.0, int(cap_s * 1000.0)]
		)
	)
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
		if m.cam.shake_left > before + 0.0001:
			starts += 1
		m.time += 0.06
	ok(starts == 1, "five heavy hits on you in 0.3 s start %d shake (want 1)" % starts)
	ok(
		m.hitstop <= cap_s + 0.0001,
		"and hold your game %.0f ms at most (cap %d)" % [m.hitstop * 1000.0, int(cap_s * 1000.0)]
	)
	Settings.v["screen_shake"] = Settings.DEFAULTS["screen_shake"]
	_freezes(m, cap_s)
	for f in foes:
		f.free()
	t.free()


## Three 0.07 s freezes of your game, each drained before the next as the running game does: the first in full, all
## three within the cap. Then one asked twice on the same step holds it once and costs once: the next gets the rest.
func _freezes(m: Match, cap_s: float) -> void:
	const ASK := 0.07  # s: a parry's freeze (combat/verbs.gd)
	m.time += 2.0
	var got: Array[float] = []
	for i in 3:
		m.hitstop = 0.0
		m.freeze_frame(ASK)
		got.append(m.hitstop)
		m.time += 0.05
	var total := got[0] + got[1] + got[2]
	ok(
		is_equal_approx(got[0], ASK) and total <= cap_s + 0.0001,
		(
			"three %.0f ms freezes inside %.2f s hold your game %.0f ms in all (cap %d): %s"
			% [ASK * 1000.0, ImpactWeight.cap("hitstop_window_s"), total * 1000.0, int(cap_s * 1000.0), str(got)]
		)
	)
	m.time += 2.0
	m.hitstop = 0.0
	m.freeze_frame(ASK)
	m.freeze_frame(ASK)
	var twice := m.hitstop
	m.hitstop = 0.0
	m.freeze_frame(ASK)
	ok(
		is_equal_approx(twice, ASK) and is_equal_approx(m.hitstop, cap_s - ASK),
		(
			(
				"a %.0f ms freeze asked twice on one step holds %.0f ms and costs that once: "
				+ "the next gets %.0f ms (want %.0f)"
			)
			% [ASK * 1000.0, twice * 1000.0, m.hitstop * 1000.0, (cap_s - ASK) * 1000.0]
		)
	)
	m.hitstop = 0.0


## A free-standing body for direct Feel calls (no match tree).
func _body(arch: String, at: Vector3) -> Hunter:
	var b := Hunter.new()
	b.arch = arch
	b.max_hp = 145.0
	b.pos = at
	return b


## 9: no Boki file sets its own freeze_frame or body flash number (the tiers' hold_s / flash_s are the only source).
func _boki_literals() -> void:
	var rx := RegEx.create_from_string("freeze_frame\\([0-9.]+\\)|\\bflash_t = [0-9.]+")
	var files := []
	for dir in ["res://scripts/kin", "res://scripts/match"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd") and (dir.ends_with("kin") or f.begins_with("kin")):
				files.append("%s/%s" % [dir, f])
	var strays := []
	for path in files:
		for hit in rx.search_all(FileAccess.get_file_as_string(path)):
			strays.append("%s:%s" % [path.get_file(), hit.get_string()])
	ok(strays.is_empty(), "no Boki file sets its own freeze or flash number (%d files): %s" % [files.size(), strays])


## 9: a Boki's hit on a foe and a hit it takes, on the tiers (basic light, ability solid), away from the player.
func _boki(m: Match) -> void:
	var k := Kin.new()
	k.max_hp = 60.0
	k.pos = Vector3(40, 0, 40)
	var foe := _body("", Vector3(46, 0, 40))
	var row := {
		"basic": {"src": "kin"},
		"ability": {"src": "kin", "ab": "k1"},
		"throw": {"src": "throw", "ab": "throw"},
	}
	var cells := []
	for kind in row:
		var want := ImpactWeight.of_boki(kind != "basic")
		for dir in ["deals", "takes"]:
			m.time += 1.0
			foe.freeze_t = 0.0
			k.freeze_t = 0.0
			var by: Ent = k if dir == "deals" else foe
			var to: Ent = foe if dir == "deals" else k
			var got := Feel.hitstop(m, by, to, 2.0, row[kind])
			var held: float = to.freeze_t
			var wants := want if dir == "deals" else "light"
			ok(
				got == wants and is_equal_approx(held, ImpactWeight.hold_s(wants)),
				"a Boki %s %s hit is '%s' (want '%s'), holds %.0f ms" % [kind, dir, got, wants, held * 1000.0]
			)
		cells.append("%s %s (%d ms)" % [kind, want, roundi(ImpactWeight.hold_s(want) * 1000.0)])
	ok(
		is_equal_approx(ImpactWeight.flash_s(""), ImpactWeight.flash_s("light")),
		"a Boki hit flashes the body %.0f ms, the light tier's" % (ImpactWeight.flash_s("") * 1000.0)
	)
	print("HITFEEL boki | %s | flash %d ms" % [" | ".join(cells), roundi(ImpactWeight.flash_s("") * 1000.0)])
	k.free()
	foe.free()
