extends RefCounted
## --stolen-extract-check: stolen Boki wisps from grab to the saves (decisions 2026-11-09, 11-11; KinSteal, 0041).
## Bots play both sides of a Boki-wisp match with the save started fresh.
##   Thief (the player): downs a rival, grabs its wisp (soul echo in the Field Book), grabs a second; a third is
##   refused (carry cap) and a hunter holds at most 4 wisps; extracts alive: the wisps go home to their owners,
##   the results pay extract_gems for each and the Field Book keeps both echoes. No bonus without getting out.
##   Owner (the player): downed, a bot thief takes the wisp; at match end it is back with the owner and the
##   owner's roster record and gems are untouched, with no echo for the owner.
## Prints PASS/FAIL.

const DT := 1.0 / 60.0
const HOLD_MAX := 4  # decision 2026-11-11: carry 2 in, 1 extra out; a hunter never holds more than 4 wisps

var bad := 0
var m: Match
var main: Node


func run(main_node: Node) -> void:
	main = main_node
	_thief()
	_owner()
	print("WSEXT %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)


func ok(cond: bool, what: String) -> void:
	print("WSEXT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _start() -> void:
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start(
		{
			"teams": 2,
			"squad": 3,
			"tier": 0,
			"length": 1e9,
			"seed": 78,
			"no_drop": true,
			"demo_kin": "cindle",
			"boki_wisps": true
		}
	)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)


func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT


func _foes() -> Array:
	return m.hunters.filter(func(h: Hunter): return h.team != m.player.team and h.kin != null)


## Down a rival and hold interact beside its loose wisp, on the far side from where it fell.
func _down_and_grab(thief: Hunter, foe: Hunter) -> void:
	m.knock(foe, thief, {})
	_frames(0.1)
	var k := foe.kin
	var away := Vector3(k.pos.x - foe.pos.x, 0.0, k.pos.z - foe.pos.z).normalized()
	thief.teleport(Vector3(k.pos.x, thief.pos.y, k.pos.z) + away * 0.5)
	thief.inp["interact"] = true
	_frames(0.8)
	thief.inp["interact"] = false


## Wisps riding with a hunter right now: their own Boki's and the stolen ones.
func _held(h: Hunter) -> int:
	return m.kins.filter(func(k: Kin): return k.owner_h == h and k.wisp and not k.dead).size()


func _echo(species: String) -> int:
	return int(Care.dex_entry(species).get("echo", 0))


func _thief() -> void:
	_start()
	var p: Hunter = m.player
	var mine := Save.new_kin("cindle", "Pip")
	Save.d["roster"] = [mine]
	Save.d["active"] = mine["uid"]
	var foes := _foes()
	var species: Array = []
	for i in 2:
		_down_and_grab(p, foes[i])
		species.append(foes[i].kin.species)
		ok(
			KinSteal.stolen(foes[i].kin) and foes[i].kin.owner_h == p,
			"grab %d: the rival's wisp rides with the thief" % (i + 1)
		)
		ok(_echo(foes[i].kin.species) >= 1, "...a soul echo for %s in the Field Book" % foes[i].kin.species)
		m.revive_hunter(foes[i], null)  # (a squad with everyone down is out, and its last wisp goes with it)
	_down_and_grab(p, foes[2])
	ok(KinSteal.count(p) == 2 and KinSteal.loose(foes[2].kin), "a third grab is refused: the cap is 2 stolen wisps")
	ok(_held(p) <= HOLD_MAX and _held(p) == 3, "the thief holds %d wisps, never more than %d" % [_held(p), HOLD_MAX])
	var gems0 := int(Save.d["gems"])
	var pay := int(KinSteal.rules()["extract_gems"])
	m._extract(p, "", "")
	var back := foes.slice(0, 2).all(
		func(f: Hunter): return not KinSteal.taken(f.kin) and f.kin.owner_h == f and f.kin.team == f.team
	)
	ok(back, "extract: the stolen wisps go home to their owners at once")
	ok(KinSteal.loose(foes[2].kin) or not KinSteal.stolen(foes[2].kin), "...and the loose one stays the rival's")
	ok(
		m.result.get("extracted", false) and m.result.get("stolen", []) == species,
		"the result lists the stolen species"
	)
	var r := m.result.duplicate()
	r["gems"] = 0
	var out := Game.apply_result(r)
	ok(
		int(Save.d["gems"]) == gems0 + 2 * pay and int(out["stolen_gems"]) == 2 * pay,
		"bonus: %d gems each, in the save (%d)" % [pay, Save.d["gems"]]
	)
	ok(species.all(func(s: String): return _echo(s) >= 1), "the thief's save keeps both echoes")
	var none := {"extracted": false, "stolen": species}
	var o2 := {"gems": 0}
	KinSteal.settle(none, o2)
	ok(o2["gems"] == 0 and int(Save.d["gems"]) == gems0 + 2 * pay, "no bonus when the thief did not get out")
	_end()


func _owner() -> void:
	_start()
	var p: Hunter = m.player
	var rec: Dictionary = p.kin.rec.duplicate(true)
	Save.d["roster"] = [rec.duplicate(true)]
	Save.d["active"] = rec["uid"]
	var thief: Hunter = _foes()[0]
	m.knock(p, thief, {})
	_frames(0.1)
	var k := p.kin
	ok(KinSteal.loose(k) and KinSteal.grab(k, thief) and KinSteal.stolen(k), "owner downed: a rival takes the wisp")
	var gems0 := int(Save.d["gems"])
	KinSteal.match_end(m)
	ok(k.owner_h == p and k.team == p.team and not KinSteal.taken(k), "match end: the wisp is back with its owner")
	Game.apply_result(
		{"extracted": false, "why": "left", "tier": 0, "kin_runs": [], "caught": [], "gems": 0, "seeds": {}}
	)
	var kept := Save.kin(String(rec["uid"]))
	ok(
		not kept.is_empty() and kept["species"] == rec["species"] and kept["name"] == rec["name"],
		"the owner's roster Boki is untouched"
	)
	ok(int(Save.d["gems"]) == gems0 and _echo(String(rec["species"])) == 0, "...no gems and no echo for the owner")
	_end()


func _end() -> void:
	m.queue_free()
	m = null
