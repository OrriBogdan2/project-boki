extends RefCounted
## --crouch-check: the four things the tutorial's crouch line promises (content/rules/tutorial.json, detail
## "crouch"), each measured on the real match step against the same Hunter standing: it walks slower, its
## gun sways less, an idle monster notices it only closer in, and it sees further. These are owner rules
## (the source has no crouch rule to match). Never touches the save.
##
## Prints one "CROUCH ok|FAIL <what>" line per promise and "CROUCH CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var P: Hunter
const STRIP := 12          # tiles of flat open ground along +x for the walk and the monster
const SHOTS := 8           # one full turn of Hunter.SWAY, so both runs meet its widest swing

func ok(cond: bool, what: String) -> void:
	print("CROUCH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.hunters[0]
	for h in m.hunters:
		h.ctrl = "idle"
		for kk in [h.kin, h.kin2]:
			if kk:
				m.kins.erase(kk)
				kk.queue_free()
		h.kin = null
		h.kin2 = null
	var s := _strip()
	ok(s != Vector3.INF, "found a flat open strip")
	if s != Vector3.INF:
		for h in m.hunters:
			while h != P and h.pos.distance_to(s) < 30.0: h.teleport(m.world.random_ground())
		_speed(s)
		_sway(s)
		_notice(s)
	_sight()
	print("CROUCH CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Puts P at `at`, standing or crouched, still, and lets the crouch take (it needs the ground under it).
func _place(at: Vector3, crouched: bool) -> void:
	P.teleport(at)
	P.vel = Vector3.ZERO
	P.inp["move"] = Vector2.ZERO
	P.inp["crouch"] = crouched
	for i in 10: m.step(Match.DT)
	P.reveal_t = 0.0

## A flat, open strip STRIP tiles long along +x (3 wide), no grass: its first tile's centre.
func _strip() -> Vector3:
	var w := m.world
	for k in 6000:
		var g := w.random_ground()
		var good := true
		for dx in STRIP:
			for dz in [-1, 0, 1]:
				var x: float = floorf(g.x) + dx + 0.5
				var z: float = floorf(g.z) + dz + 0.5
				if w.is_void(x, z) or w.is_block(x, z) or w.in_bush(x, z) or absf(w.ground_at(x, z) - g.y) > 0.05:
					good = false
		if good: return Vector3(floorf(g.x) + 0.5, g.y, floorf(g.z) + 0.5)
	return Vector3.INF

## Slower: the run speed half a second into a walk along the strip.
func _speed(s: Vector3) -> void:
	var v := []
	for crouched in [false, true]:
		_place(s, crouched)
		P.inp["move"] = Vector2(1, 0)
		for i in 30: m.step(Match.DT)
		v.append(Vector2(P.vel.x, P.vel.z).length())
		P.inp["move"] = Vector2.ZERO
	ok(v[1] > 0.5 and v[1] < v[0] * 0.75, "slower: walks %.2f m/s crouched, %.2f standing" % [v[1], v[0]])

## Steadier aim: the widest a rifle's shots stray from the aim over one turn of its sway pattern.
func _sway(s: Vector3) -> void:
	P.equip("rifle")
	var worst := []
	for crouched in [false, true]:
		_place(s, crouched)
		var aim := Vector3(s.x + 8.0, s.y + 0.95, s.z)
		P.inp["aim"] = aim
		P.inp["aim_y"] = s.y
		var dev := 0.0
		for i in SHOTS:
			P.ammo = 99
			P.fire_cd = 0.0
			P.warm_t = 0.0
			P.wbloom = 0.0
			m.shots.clear()
			P.fire()
			if m.shots.is_empty(): continue
			var sv: Vector2 = m.shots[-1]["vel"]
			dev = maxf(dev, absf(angle_difference(sv.angle(), P.aim_dir().angle())))
			m.step(Match.DT)
		m.shots.clear()
		worst.append(rad_to_deg(dev))
	var what := "steadier aim: sways %.2f deg crouched, %.2f standing" % [worst[1], worst[0]]
	ok(worst[0] > 0.0 and worst[1] < worst[0] * 0.75, what)

## Noticed less: an idle monster 6 m off picks a standing Hunter as its target and passes a crouched one.
func _notice(s: Vector3) -> void:
	var mb := m.spawn_mob(Data.MOBS.keys()[0], s + Vector3(6.0, 0, 0))
	var picked := []
	for crouched in [false, true]:
		_place(s, crouched)
		mb.st = "idle"
		picked.append(mb._find_target() == P)
	ok(picked[0] and not picked[1], "noticed less: an idle monster 6 m off notices standing %s, crouched %s" % picked)
	m.mobs.erase(mb)
	mb.queue_free()

## Sees further: a spot just past a standing Hunter's sight, with a clear line and no grass, in its view cone.
func _sight() -> void:
	var w := m.world
	var far := m.view_range() * 1.12
	for k in 3000:
		var g := w.random_ground()
		var a := float(k % 24) * TAU / 24.0
		var p := g + Vector3(cos(a), 0, sin(a)) * far
		if w.is_void(p.x, p.z) or w.in_bush(p.x, p.z) or absf(w.ground_at(p.x, p.z) - g.y) > 0.05:
			continue
		p.y = g.y
		if not w.los(g, p, g.y + 1.1):
			continue
		var seen := []
		for crouched in [false, true]:
			_place(g, crouched)
			P.inp["aim"] = p
			seen.append(m.sees(P.team, p))
		var what := "sees further: a spot %.1f m off seen standing %s, crouched %s" % [far, seen[0], seen[1]]
		ok(P.crouch and not seen[0] and seen[1], what)
		return
	ok(false, "sees further: found a clear line %.1f m long" % far)
