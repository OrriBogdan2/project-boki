extends RefCounted
## --utility-parity-check: the belt items that changed to match the source (docs/SOURCE_UTILITIES.md
## section 4). Tonic, armor kit and slot rules are --equal-check; this one covers the field items:
##  1. Bounty Banner: knocked under it you go straight out (no wisp), and the knocker pockets the gems.
##  2. Skyfall Charge: the blast kills a full-health hunter, then the ground burns for 3 s.
##  3. Blight Flask: the patch lasts 40 s and blights whoever stands in it (healing barely takes).
## Prints UTIL ok/FAIL lines and "UTIL DONE, failures: N". Never touches the save file.

var bad := 0
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
	m.start({"teams": 2, "squad": 1, "tier": 2, "length": 1e9, "seed": 9001, "no_drop": true, "raid": "clear"})
	m.set_process(false)
	var P: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	_banner(m, P, foe)
	_skyfall(m, P, foe)
	_blight(m, P, foe)
	print("UTIL DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _steps(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT): m.step(Match.DT)

func _banner(m: Match, P: Hunter, foe: Hunter) -> void:
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
	foe.teleport(P.pos + Vector3(6.0, 0, 0))
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "skyfall_charge"), "a Skyfall Charge is called")
	_steps(m, 4.5)
	ok(foe.hp >= foe.max_hp - 0.5, "...nothing lands for 5 s")
	_steps(m, 1.0)
	ok(foe.downed or foe.out or foe.dead, "the blast knocks a full-health rival outright (hp %.0f)" % foe.hp)
	ok(m.fields.list.size() >= 1, "then the ground burns (a fire patch)")
	_steps(m, 3.5)
	ok(m.fields.list.is_empty(), "...for 3 s")

func _blight(m: Match, P: Hunter, foe: Hunter) -> void:
	foe.out = false
	foe.downed = false
	foe.dead = false
	foe.hp = foe.max_hp
	foe.armor = foe.max_armor
	foe.blight_t = 0.0
	P.belt = UtilityBelt.empty()
	UtilityBelt.grant(P, "blight_flask", 1)
	foe.teleport(P.pos + Vector3(4.0, 0, 0))
	P.inp["aim"] = foe.pos
	ok(UtilityBelt.use_id(P, "blight_flask"), "a Blight Flask is thrown")
	_steps(m, 2.5)
	ok(foe.blight_t > 0.0 and foe.hp + foe.armor < foe.max_hp + foe.max_armor,
			"a rival in the patch is blighted and hurt")
	_steps(m, 35.0)
	ok(m.fields.list.size() >= 1, "the patch is still there after 37 s")
	_steps(m, 4.0)
	ok(m.fields.list.is_empty(), "...and gone after 40 s")
