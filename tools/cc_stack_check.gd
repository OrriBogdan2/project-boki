extends RefCounted
## --cc-stack-check: overlapping crowd control goes through Ent's one rule (docs/decisions/0022).
## Slow + Slow: the strongest running slow sets the speed, each keeps its own clock, overlaps never add.
## Stun during Root: both run side by side, the root holds on after the stun, neither adds.
## Grounded + Slow: independent, both apply. Online: the same hits sent through the Net hit path to the
## body's owner land on exactly the same state as local hits. Never touches the save.

const DT := 1.0 / 60.0
const EPS := 0.03            # s / share of speed: one frame of slack

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CCSTACK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
	var P: Hunter = m.player
	P.ctrl = "idle"
	var T: Hunter = null
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			T = o
	_slow_slow(m, P, T)
	_stun_root(m, P, T)
	_grounded_slow(m, P, T)
	_online(m, P, T)
	print("CCSTACK %s, %d failures" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs - 1e-6:
		m.step(DT)
		t += DT

func _fresh(T: Hunter) -> void:
	T.hp = T.max_hp
	T.slow_t = 0.0
	T.slow_k = 0.0
	T.slows.clear()
	T.stun_t = 0.0
	T.root_t = 0.0
	T.cc_immune_t = 0.0
	T.dr.clear()
	T.set_meta("gnd_until", 0.0)

func _slow(T: Hunter, by: Ent, secs: float, k: float) -> void:
	T.hurt(1.0, by, {"src": "abil", "slow": secs, "slow_k": k})

func _slow_slow(m: Match, P: Hunter, T: Hunter) -> void:
	_fresh(T)
	_slow(T, P, 0.5, 0.6)              # a strong, short slow (a burst's)
	_slow(T, P, 2.0, 0.2)              # a weak, long one (a zone's) on top
	ok(absf(T.slow_mult() - 0.4) < EPS, "slow+slow: the stronger one sets the speed (mult %.2f)" % T.slow_mult())
	_step(m, 0.7)
	var left := "mult %.2f, %.2fs left" % [T.slow_mult(), T.slow_t]
	ok(absf(T.slow_mult() - 0.8) < EPS and absf(T.slow_t - 1.3) < EPS,
			"slow+slow: the strong one ran out, the weak one keeps its own clock (%s)" % left)
	_step(m, 1.4)
	ok(T.slow_mult() == 1.0 and T.slows.is_empty(), "slow+slow: both over, full speed")
	_fresh(T)
	_slow(T, P, 1.0, 0.3)
	_step(m, 0.5)
	_slow(T, P, 1.0, 0.3)              # the same slow again: refreshes, never adds
	var rep := "%.2fs, k %.2f, %d running" % [T.slow_t, T.slow_k, T.slows.size()]
	ok(absf(T.slow_t - 1.0) < EPS and absf(T.slow_k - 0.3) < EPS and T.slows.size() == 1,
			"slow+slow: a repeat refreshes to its own length (%s)" % rep)
	_slow(T, P, 0.4, 0.1)              # weaker and shorter: changes nothing
	ok(absf(T.slow_k - 0.3) < EPS and T.slows.size() == 1, "slow+slow: weaker and shorter changes nothing")
	T.hurt(1.0, P, {"src": "abil", "slow": 0.5})      # a plain slow is the body's usual one, and stronger
	var usual := "usual %.2f, k %.2f" % [T.usual_slow(), T.slow_k]
	ok(absf(T.slow_k - T.usual_slow()) < EPS, "slow+slow: a plain slow counts as the usual one (%s)" % usual)
	T.slow_t = 0.0                     # a cleanse clears every running slow
	_slow(T, P, 0.3, 0.1)
	ok(T.slows.size() == 1 and absf(T.slow_k - 0.1) < EPS, "slow+slow: after a cleanse only the new one runs")
	_fresh(T)

func _stun_root(m: Match, P: Hunter, T: Hunter) -> void:
	_fresh(T)
	T.hurt(1.0, P, {"src": "abil", "root": 2.0})
	_step(m, 0.3)
	T.hurt(1.0, P, {"src": "abil", "stun": 0.5})
	ok(absf(T.stun_t - 0.5) < EPS and absf(T.root_t - 1.7) < EPS,
			"stun during root: both run side by side (stun %.2f, root %.2f)" % [T.stun_t, T.root_t])
	T.hurt(1.0, P, {"src": "abil", "stun": 0.2, "root": 0.5})       # shorter ones: no add, no cut
	ok(absf(T.stun_t - 0.5) < EPS and absf(T.root_t - 1.7) < EPS, "stun during root: shorter repeats change nothing")
	_step(m, 0.6)
	ok(T.stun_t <= 0.0 and T.root_t > 1.0, "stun during root: the root holds on after the stun (root %.2f)" % T.root_t)
	_fresh(T)

func _grounded_slow(m: Match, P: Hunter, T: Hunter) -> void:
	_fresh(T)
	KitStatus.apply(T, "gnd", 1.5)
	_slow(T, P, 1.0, 0.3)
	var both := KitStatus.grounded(T) and absf(T.slow_mult() - 0.7) < EPS
	ok(both, "grounded+slow: both apply (mult %.2f)" % T.slow_mult())
	KitStatus.apply(T, "dsr", 0.5, 0.4)      # Disoriented's slow joins the same rule
	ok(absf(T.slow_mult() - 0.6) < EPS and KitStatus.grounded(T), "grounded+slow: a stronger Disoriented slow wins")
	_step(m, 1.1)
	ok(T.slow_mult() == 1.0 and KitStatus.grounded(T), "grounded+slow: the slows end, Grounded runs on")
	_fresh(T)

## The same sequence, applied locally and sent over the Net hit path to the body's owner, ends the same.
func _online(m: Match, P: Hunter, T: Hunter) -> void:
	var seq := [
		{"src": "abil", "slow": 0.6, "slow_k": 0.55},
		{"src": "abil", "slow": 2.0, "slow_k": 0.25, "root": 1.2},
		{"src": "abil", "stun": 0.4},
		{"src": "abil", "slow": 1.0},
	]
	_fresh(T)
	for o in seq:
		T.hurt(1.0, P, o.duplicate())
	var local := _state(T)
	_fresh(T)
	var net0: bool = m.net_on
	Net.out_hits.clear()
	m.net_on = true
	T.remote = true                    # another game owns it: the hits go out as Net hits
	for o in seq:
		T.hurt(1.0, P, o.duplicate())
	T.remote = false
	m.net_on = net0
	var sent: Array = Net.out_hits.duplicate()
	Net.out_hits.clear()
	var quiet := sent.size() == seq.size() and _state(T) == _state_zero()
	ok(quiet, "online: %d hits sent, none applied on the sender" % sent.size())
	for x in sent:
		m._net_hit_in(x)               # the owner's game runs the same rule
	var remote := _state(T)
	var same := true
	for i in local.size():
		same = same and absf(float(local[i]) - float(remote[i])) < EPS
	ok(same, "online: the owner ends on the local result (local %s, owner %s)" % [local, remote])
	_fresh(T)

func _state(T: Hunter) -> Array:
	var v := [T.slow_k, T.slow_t, T.slow_mult(), T.stun_t, T.root_t]
	return v.map(func(x): return snappedf(x, 0.01))

func _state_zero() -> Array:
	return [0.0, 0.0, 1.0, 0.0, 0.0]
