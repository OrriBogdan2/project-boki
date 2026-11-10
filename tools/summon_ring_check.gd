extends RefCounted
## --summon-ring-check: the ring under a summoned Boki shows the time left (SummonRing). Three squads, Boki wisps
## on. A summon's ring fills to the window left (full at the start, half at half), is steady until the last
## 2 s and then flickers, sits under the team ring and every ground mark, and is gone when the window ends (the
## shrink), when it is knocked back and when the Boki dies. A stolen summon wears the same ring dimmed, in the
## thief's colour. Prints PASS/FAIL. Never touches the save.

const DT := 1.0 / 60.0
const WINDOW := 10.0

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("SUMRING %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
	_window()
	_ends()
	_stolen()
	m.queue_free()
	print("SUMMONRING %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		for k in m.kins:
			k.render(DT, 1.0)
		t += DT

func _ring(k: Kin) -> MeshInstance3D:
	return k.get_node_or_null(SummonRing.NAME) as MeshInstance3D

func _par(ring: MeshInstance3D, key: String) -> Variant:
	return (ring.material_override as ShaderMaterial).get_shader_parameter(key)

## The alpha range the ring shows over the next `secs`.
func _alphas(k: Kin, secs: float) -> Vector2:
	var span := Vector2(INF, -INF)
	var t := 0.0
	while t < secs and _ring(k):
		_run(DT)
		if _ring(k):
			var a := (_par(_ring(k), "color") as Color).a
			span = Vector2(minf(span.x, a), maxf(span.y, a))
		t += DT
	return span

func _window() -> void:
	var k: Kin = m.player.kin
	ok(_ring(k) == null, "a resting wisp has no ring")
	k.summon.burst(WINDOW)
	_run(0.1)
	var ring := _ring(k)
	ok(ring != null and absf(float(_par(ring, "arc")) - 1.0) < 0.02, "a fresh summon's ring is full")
	ok(ring.material_override.render_priority < 0 and ring.global_position.y < k.ring.global_position.y,
		"it sits under the team ring and the marks")
	ok(ring.scale.x > k.ring.scale.x, "...just outside the team ring")
	_run(4.9)
	ok(absf(float(_par(ring, "arc")) - 0.5) < 0.03, "half the window gone: the ring is half")
	var steady := _alphas(k, 2.0)
	ok(is_equal_approx(steady.x, steady.y) and k.summon.left > SummonRing.WARN_S, "steady while more than 2 s is left")
	var warn := _alphas(k, 1.5)
	ok(k.summon.left < SummonRing.WARN_S and warn.x < warn.y * 0.5, "flickers in the last 2 s")

func _ends() -> void:
	var k: Kin = m.player.kin
	k.summon.end()
	_run(0.1)
	ok(_ring(k) == null, "the shrink removes the ring")
	_run(KinSummon.SHRINK_S + 0.5)
	k.summon.cd = 0.0
	k.summon.burst(WINDOW)
	_run(0.1)
	ok(_ring(k) != null, "summoned again: a ring")
	k.summon.knocked()
	_run(0.1)
	ok(_ring(k) == null, "knocked back into a wisp: no ring")
	k.summon.cd = 0.0
	k.summon.burst(WINDOW)
	_run(0.1)
	k.dead = true
	_run(0.1)
	ok(_ring(k) == null, "a dead Boki has none")
	k.dead = false
	k.summon.end()
	_run(KinSummon.SHRINK_S + 0.5)

func _stolen() -> void:
	var p: Hunter = m.player
	var f: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team)[0]
	var fk: Kin = f.kin
	fk.summon.end()
	_run(KinSummon.SHRINK_S + 0.3)
	m.knock(f, p, {})
	_run(0.1)
	p.teleport(Vector3(fk.pos.x + 0.5, p.pos.y, fk.pos.z))
	KinSteal.grab(fk, p)
	_run(0.3)
	p.kin.summon.cd = 40.0
	ok(KinSummon.press(p) and not fk.wisp, "the thief summons the stolen Boki")
	_run(0.3)
	var ring := _ring(fk)
	ok(ring != null and KinSteal.stolen(fk), "a stolen summon has the ring")
	ok(ring != null and absf((_par(ring, "color") as Color).a - SummonRing.STOLEN_A) < 0.01, "...dimmed")
	ok(ring != null and (_par(ring, "color") as Color).is_equal_approx(Color(SideColor.YOU, SummonRing.STOLEN_A)),
		"...in the thief's colour, not its owner's")
	fk.summon.end()
	_run(0.1)
	ok(_ring(fk) == null, "...and gone when it shrinks")
