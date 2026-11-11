extends RefCounted
## --wisp-rules-check: one wisp rule set in PvE and PvP (DECISIONS 2026-11-09 "Soul-linked Boki", WISP_DESIGN_OPEN.md
## Q9, decision 0045). The same summon, kill and steal script runs in three matches (an expedition, the Meadow tier,
## the training area) once with a rival Hunter as the killer and once with a monster. Everything the script records
## must be identical, except the two Q9 exceptions: a monster's kill costs the plain cooldown with no reveal or
## ping and sends the wisp home whatever the owner's state, and a monster never grabs a wisp. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const SETUPS := {
	"expedition": {"tier": 1},
	"meadow": {"tier": 0},
	"training": {"tier": 0, "training": true},
}

var bad := 0
var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	for id in SETUPS:
		_setup(id)
		var rival := _script(true)
		var mons := _script(false)
		_compare(id, rival, mons)
		m.queue_free()
		m = null
	print("WISPRULES %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WRULES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _setup(id: String) -> void:
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 2, "length": 1e9, "seed": 80, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true}
	o.merge(SETUPS[id])
	m.start(o)
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	_frames(0.3)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func _summoned(f: Hunter) -> Kin:
	var k: Kin = f.kin
	k.summon.cd = 0.0
	k.summon.burst(k.summon.dur)
	_frames(0.05)
	return k

## The killer: the player (a rival of f) or a monster (a Mob, kept apart so it cannot interfere).
func _killer(rival: bool) -> Ent:
	if rival:
		return m.player
	var mob := Mob.new()
	m.add_child(mob)
	return mob

## The script. Fields tagged x_ are the Q9 exceptions; every other field must match between killer kinds.
func _script(rival: bool) -> Dictionary:
	var p: Hunter = m.player
	var f: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	var by := _killer(rival)
	var base := KinSummon.times(f.kin.ks).y
	var r := {}
	var k := _summoned(f)
	r["summoned"] = k.summon.out() and not k.wisp
	k.hurt(k.max_hp * 0.6, by)
	r["survives_damage"] = k.summon.out() and not k.wisp
	k.teleport(f.pos + Vector3(12, 0, 0))
	f.reveal_t = 0.0
	k.hurt(k.max_hp * 5.0, by)
	r["back_to_wisp"] = k.wisp and k.state == "shoulder" and k.owner_h == f and not KinSteal.loose(k)
	r["window_over"] = k.summon.left == 0.0 and not k.summon.out()
	r["flies_home"] = k.summon.fly > 0.0
	r["x_cd_mult"] = snappedf(k.summon.cd / base, 0.01)
	r["x_revealed"] = f.reveal_t > 0.0
	_frames(k.summon.fly_len + 0.1)
	k = _summoned(f)
	f.downed = true
	k.hurt(k.max_hp * 5.0, by)
	r["x_loose_when_owner_down"] = KinSteal.loose(k)
	r["owner_down_wisp"] = k.wisp
	KinSteal.go_home(k)
	f.downed = false
	# stealing: a downed owner's wisp breaks loose; only hunters grab it, the same way everywhere
	f.downed = true
	KinSteal.break_loose(f.kin, f.pos)
	var near: Hunter = m.hunters.filter(func(h: Hunter): return h != f and h.team != f.team and h.kin != null)[0]
	r["loose"] = KinSteal.loose(f.kin)
	r["grab_works"] = KinSteal.grab(f.kin, near) if near.team != f.team else false
	r["stolen"] = KinSteal.stolen(f.kin) and f.kin.owner_h == near
	r["carry_count"] = KinSteal.count(near)
	KinSteal.go_home(f.kin)
	f.downed = false
	if by is Mob:
		by.queue_free()
	return r

func _compare(id: String, rival: Dictionary, mons: Dictionary) -> void:
	for key in rival:
		if key.begins_with("x_"):
			continue
		ok(rival[key] == mons[key], "%s: %s identical (rival %s, monster %s)" % [id, key, rival[key], mons[key]])
	var mult := float(KinSummon.rules()["killed_cd_mult"])
	ok(is_equal_approx(float(rival["x_cd_mult"]), mult), "%s: rival kill = x%.2f cooldown" % [id, mult])
	ok(is_equal_approx(float(mons["x_cd_mult"]), 1.0), "%s: monster kill = plain cooldown (exception 2)" % id)
	ok(rival["x_revealed"] and not mons["x_revealed"], "%s: only a rival's kill reveals the owner (exception 2)" % id)
	ok(rival["x_loose_when_owner_down"] and not mons["x_loose_when_owner_down"],
		"%s: owner down: rival leaves a loose wisp, a monster sends it home (exception 2)" % id)
