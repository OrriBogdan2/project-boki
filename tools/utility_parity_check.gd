extends RefCounted
## --utility-parity-check: the belt items that changed to match the source (docs/SOURCE_UTILITIES.md
## section 4). Tonic, armor kit and slot rules are --equal-check; this one covers the field items:
##  1. Bounty Banner: knocked under it you go straight out (no wisp), and the knocker pockets the gems.
##  2. Skyfall Charge: the blast kills a full-health hunter, then the ground burns for 3 s.
##  3. Blight Flask: the patch lasts 40 s and blights whoever stands in it (healing barely takes).
## Prints UTIL ok/FAIL lines and "UTIL DONE, failures: N". Never touches the save file.

var bad := 0
var hazards := 0         # fields on the list before any item is used (the map's hazards)
var main: Node

func ok(cond: bool, what: String) -> void:
	print("UTIL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Save.d["tutorial"]["hatched"] = true
	Save.d["cls"] = "medium"
	var rec := Save.new_kin("cindle", "Pip", 77)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	var P: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]      # (a squad of two: a downed hunter with a live mate
										# is not a wiped team, so it stays downed under the banner)
	_land(m, P, foe)
	for x in m.hunters:      # (the mates only keep the banner's team from being wiped: they stand still, stunned)
		if x != P and x != foe:
			x.stun_t = 1e6
	hazards = m.fields.list.size()      # the map's own hazard fields, there from the start
	_banner(m, P, foe)
	_skyfall(m, P, foe)
	_blight(m, P, foe)
	print("UTIL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

## The most seconds any field `by` cast has left (a fire patch or a blight patch is the longest one standing; the map's
## hazards and a bot's own long fields are not the item under test).
func _longest(m: Match, by: Hunter) -> float:
	var best := 0.0
	for f in m.fields.list:
		if f.get("caster") == by:
			best = maxf(best, float(f.get("t", 0.0)))
	return best

## A match starts with every hunter dropping in from the sky, and a dropping hunter takes no damage: steps the match until
## both are down (a test that hurts one in the air would hit nothing, depending on how long the drop took).
func _land(m: Match, P: Hunter, foe: Hunter) -> void:
	var guard := int(120.0 / Match.DT)
	while (P.dropping or foe.dropping or not P.grounded or not foe.grounded) and guard > 0:
		m.step(Match.DT)
		guard -= 1
	ok(not P.dropping and not foe.dropping, "both hunters have landed (%.0f s in)" % m.time)
	P.inv_t = 0.0
	foe.inv_t = 0.0

## Stands `h` on the ground, still: a match can start with the hunters in the air (an item's blast or a knock-out
## needs them where the test puts them).
func _ground(h: Hunter) -> void:
	h.teleport(Vector3(h.pos.x, h.ground(), h.pos.z))
	h.vel = Vector3.ZERO

## Steps the match; the rival stays on its spot (a bot walks off a telegraph, and the blast must find it).
func _steps(m: Match, secs: float, stay: Hunter = null) -> void:
	var at := stay.pos if stay else Vector3.ZERO
	for i in int(secs / Match.DT):
		if stay:
			stay.pos = at
			stay.vel = Vector3.ZERO
			stay.inv_t = 0.0      # (a bot dashes out of a patch; its dash frames must not dodge the ticks under test)
		m.step(Match.DT)

func _banner(m: Match, P: Hunter, foe: Hunter) -> void:
	_ground(P)
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "bounty_banner", 1)
	P.lives = 3
	foe.gems = 0
	var gems0 := foe.gems
	ok(UtilityBelt.use_id(P, "bounty_banner"), "a Bounty Banner starts")
	_steps(m, 1.0)
	ok(P.reveal_t > 100.0 and bool(m.get_meta("banner_%d" % P.team, false)), "...and shows you to everyone")
	P.hurt(P.hp + P.armor + 50.0, foe, {"src": "shot"})
	ok(P.downed or P.out, "a rival knocks you under it")
	_steps(m, 1.0)
	ok(P.out and P.lives == 3, "...and you go straight out: no wisp, no spare life spent")
	ok(foe.gems == gems0 + int(UtilityBelt.def("bounty_banner").get("reward", 0)),
			"the knocker pockets the bounty (%d gems)" % (foe.gems - gems0))
	ok(not bool(m.get_meta("banner_%d" % P.team, false)), "the banner is over, the squad may raise another")

func _skyfall(m: Match, P: Hunter, foe: Hunter) -> void:
	P.out = false
	P.downed = false
	P.dead = false
	P.hp = P.max_hp
	P.armor = P.max_armor
	foe.out = false
	foe.downed = false
	foe.dead = false
	foe.hp = foe.max_hp
	foe.armor = foe.max_armor
	foe.inv_t = 0.0
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "skyfall_charge", 1)
	_ground(P)
	foe.teleport(P.pos + Vector3(6.0, 0, 0))
	_ground(foe)
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "skyfall_charge"), "a Skyfall Charge is called")
	_steps(m, 4.5, foe)
	ok(foe.hp >= foe.max_hp - 0.5, "...nothing lands for 5 s")
	_steps(m, 1.0, foe)
	ok(foe.downed or foe.out or foe.dead, "the blast knocks a full-health rival outright (hp %.0f)" % foe.hp)
	ok(m.fields.list.size() > hazards, "then the ground burns (a fire patch)")
	var left := _longest(m, P)
	ok(left > 2.0 and left <= 3.0, "...for 3 s (%.1f s left a beat in)" % left)

func _blight(m: Match, P: Hunter, foe: Hunter) -> void:
	foe.out = false
	foe.downed = false
	foe.dead = false
	foe.hp = foe.max_hp
	foe.armor = foe.max_armor
	foe.blight_t = 0.0
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "blight_flask", 1)
	_ground(P)
	foe.teleport(P.pos + Vector3(4.0, 0, 0))
	_ground(foe)
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "blight_flask"), "a Blight Flask is thrown")
	_steps(m, 2.5, foe)
	ok(foe.blight_t > 0.0 and foe.hp + foe.armor < foe.max_hp + foe.max_armor,
			"a rival in the patch is blighted and hurt")
	var left := _longest(m, P)
	ok(left > 36.0 and left <= 38.0, "the patch lasts 40 s (%.1f s left 2.5 s in)" % left)
