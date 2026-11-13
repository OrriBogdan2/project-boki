extends RefCounted
## --kin-target-check: KinTactics.pick_target (the foe an active Boki goes for) against the rule spelled
## out here: of the foes within chase range that are hittable, not downed or cloaked Hunters, not disguised,
## not given up on and that it can walk to, the one with the best score (nearer, whoever hit you, what it
## already chases, your focus, Hunters, stunned or rooted foes). LAYOUTS random layouts in a 2v2 with a
## monster pack: foes scattered round the Boki, some up a ledge it cannot reach, some out of range, some ignored,
## and one layout in five with nothing in range at all.

const LAYOUTS := 60
const DT := 1.0 / 60.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINTARGET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
	for h in m.hunters:
		h.ctrl = "idle"
	var k: Kin = null
	for kk in m.kins:
		if kk.owner_h != null and kk.brain != null: k = kk
	ok(k != null, "a Hunter's Boki with a brain to ask")
	if k == null:
		main.get_tree().quit(1)
		return
	var P: Hunter = k.owner_h
	k.state = "active"
	for i in 4:
		m.spawn_mob(["skitter", "brute", "spitter", "skitter"][i], P.pos)
	var foes: Array = m.foes_of(k.team, false)
	ok(foes.size() >= 6, "2 rivals, their Boki and 4 monsters to pick from (%d)" % foes.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1111
	var reach: float = k.brain.chase_range()
	var picked := 0
	var same := 0
	for i in LAYOUTS:
		k.pos = P.pos + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		k.ignore_until.clear()
		var empty := i % 5 == 0      # nothing in range: it picks no one
		for f in foes:
			var a := rng.randf() * TAU
			var d := rng.randf_range(reach * 1.1, reach * 1.6) if empty else rng.randf_range(0.5, reach * 1.6)
			var at := k.pos + Vector3(cos(a), 0.0, sin(a)) * d
			var up := 3.0 if rng.randf() < 0.15 else 0.0      # up a ledge: in range but not walkable to
			f.pos = Vector3(at.x, m.world.ground_at(at.x, at.z) + up, at.z)
			f.prev = f.pos
			f.stun_t = 1.0 if rng.randf() < 0.2 else 0.0
			if rng.randf() < 0.15:
				k.ignore_until[f] = m.time + 5.0
			if f is Hunter:
				(f as Hunter).downed = rng.randf() < 0.15
		k.target = foes[rng.randi() % foes.size()] if rng.randf() < 0.5 else null
		P.last_hit_by = foes[rng.randi() % foes.size()] if rng.randf() < 0.5 else null
		P.inp["aim"] = (foes[rng.randi() % foes.size()] as Ent).pos if rng.randf() < 0.5 else P.pos + Vector3(30, 0, 0)
		var want := _reference(m, k, foes, reach)
		var got: Ent = k.brain.pick_target()
		picked += 1 if got != null else 0
		same += 1 if got == want else 0
		if got != want:
			print("KINTARGET layout %d: picked %s, the rule says %s" % [i, _name(got), _name(want)])
	ok(same == LAYOUTS, "%d of %d layouts pick the foe the rule says" % [same, LAYOUTS])
	var mixed := picked > LAYOUTS / 4 and picked <= LAYOUTS - LAYOUTS / 5
	ok(mixed, "the layouts cover picks and no-picks (%d picked)" % picked)
	print("KINTARGET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The rule in full: every filter on every foe, then the best score (ties to the earlier foe).
func _reference(m: Match, k: Kin, foes: Array, reach: float) -> Ent:
	var own: Hunter = k.owner_h
	var focus: Ent = KinFollow.owner_focus(k)
	var best: Ent = null
	var bs := -1e9
	for f in foes:
		if f is Hunter and ((f as Hunter).downed or (f as Hunter).cloak_t > 0.0):
			continue
		if not f.hittable() or Shrubling.hidden(f) or float(k.ignore_until.get(f, -1.0)) > m.time:
			continue
		var d: float = k.flat_dist(f)
		if d > reach or not k.walkable_to(f.pos):
			continue
		var s := -d
		if f == own.last_hit_by: s += 2.0 + k.brain.loyalty * k.brain._r("guard_owner_per_loyalty", 4.0)
		if f == k.target: s += 1.5
		if f == focus: s += 3.0
		if f is Hunter: s += k.brain.aggression * 1.5
		s -= own.flat_dist(f) * k.brain.loyalty * 0.25
		if f.stun_t > 0.0 or f.root_t > 0.0: s += 1.0
		if s > bs:
			bs = s
			best = f
	return best

func _name(e: Ent) -> String:
	if e == null:
		return "none"
	var who := (e as Hunter).pname if e is Hunter else e.get_class()
	return "%s@%.1f" % [who, e.pos.length()]
