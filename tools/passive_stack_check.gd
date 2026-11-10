extends RefCounted
## --passive-stack-check: how carry passives stack on one Hunter (WISP_DESIGN_OPEN.md Q8, KinSteal, decision 0041).
## Own Boki at 100 %, each stolen wisp at passive_k (content/rules/boki_summon.json), same-stat sums clamped at the
## carry cap (KinParts.OWNER_STATS), at most carry_max stolen wisps; the passives leave when a stolen wisp goes home
## or the match ends. Passives are set by hand (one stat) so the sums are exact. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const STAT := "damage_reduction"       # carry cap 0.15 (x, a fraction of damage taken)
const OWN := 0.06                      # x, the thief's own Boki
const THEIRS := 0.12                   # x, each stolen Boki before its share

var bad := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)
	_stack()
	m.queue_free()
	print("PASSIVESTACK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("PSTACK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func _set_passive(k: Kin, amount: float) -> void:
	k.ks.carry_passives = [{"stat": STAT, "amount": amount, "category": "defence"}]

## A rival goes down and the thief takes its wisp.
func _steal_from(thief: Hunter, foe: Hunter) -> Kin:
	m.knock(foe, thief, {})
	_frames(0.1)
	var k: Kin = foe.kin
	thief.teleport(Vector3(k.pos.x + 0.5, thief.pos.y, k.pos.z))
	thief.inp["interact"] = true
	_frames(0.7)
	thief.inp["interact"] = false
	return k

func _want(stolen: int) -> float:
	var cap := float(KinParts.OWNER_STATS[STAT][2])
	return minf(cap, OWN + float(stolen) * THEIRS * float(KinSteal.rules()["passive_k"]))

func _stat(what: String, stolen: int) -> void:
	_frames(0.1)
	var got := m.player.owner_stat(STAT)
	ok(absf(got - _want(stolen)) < 0.0005, "%s: %s %.3f (want %.3f)" % [what, STAT, got, _want(stolen)])

func _stack() -> void:
	var p: Hunter = m.player
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)
	var f1: Hunter = foes[0]
	var f2: Hunter = foes[1]
	var cap := float(KinParts.OWNER_STATS[STAT][2])
	ok(int(KinSteal.rules()["carry_max"]) == 2 and is_equal_approx(float(KinSteal.rules()["passive_k"]), 0.5),
		"rules: a thief holds 2 stolen wisps, each at half strength")
	var half := THEIRS * float(KinSteal.rules()["passive_k"])
	ok(OWN + half < cap and OWN + 2.0 * half > cap, "setup: one stolen fits under the cap, two do not")
	_set_passive(p.kin, OWN)
	_set_passive(f1.kin, THEIRS)
	_set_passive(f2.kin, THEIRS)
	_stat("own only", 0)
	var k1 := _steal_from(p, f1)
	ok(KinSteal.stolen(k1) and KinSteal.count(p) == 1, "one stolen wisp is carried")
	_stat("own + one stolen", 1)
	var k2 := _steal_from(p, f2)
	ok(KinSteal.stolen(k2) and KinSteal.count(p) == 2, "two stolen wisps are carried")
	_stat("own + two stolen (clamped at the carry cap)", 2)
	ok(p.owner_stat(STAT) == cap, "...the sum sits exactly at the cap")
	KinSteal.go_home(k2)
	_stat("a stolen wisp escapes (goes home)", 1)
	ok(k2.owner_h == f2, "...and rides with its owner again")
	KinSteal.match_end(m)
	_stat("match end", 0)
	ok(not KinSteal.taken(k1) and KinSteal.count(p) == 0, "...no stolen wisp left with the thief")
