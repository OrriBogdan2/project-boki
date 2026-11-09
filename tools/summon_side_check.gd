extends RefCounted
## --summon-side-check: a summoned or stolen Boki always reads as someone's, never as a wild one (SideRings,
## SideColor). Three squads, Boki wisps on, a wild Boki beside them. Every summoned Boki has the ring under it
## and its glow shell in the side colour of whoever it rides with (you, your squad, a rival); a wild Boki has
## neither; a stolen wisp in orbit wears a ring in its thief's side colour and its own hunter's wisp wears none;
## a stolen Boki, summoned, takes the thief's colour and not its victim's. Prints PASS/FAIL. Never touches the save.

const DT := 1.0 / 60.0
const SIDES := [SideColor.YOU, SideColor.ALLY, SideColor.FOE]

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("SUMSIDE %s %s" % ["ok  " if cond else "FAIL", what])
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
	var wild := m.spawn_wild(Save.new_kin("cindle", "", 5), m.player.pos + Vector3(4, 0, 0))
	_run(0.3)
	_summoned(wild)
	_stolen()
	m.queue_free()
	print("SUMMONSIDE %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
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

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.01

func _shell(k: Kin) -> Color:
	var s := k.model.get_node_or_null("Body/Shell") as MeshInstance3D
	return (s.material_override as ShaderMaterial).get_shader_parameter("color") if s else Color.BLACK

## The side a colour is, as a word.
func _side(c: Color) -> String:
	for i in SIDES.size():
		if _same(c, SIDES[i]):
			return ["you", "squad", "rival"][i]
	return "none"

func _summoned(wild: Kin) -> void:
	var p: Hunter = m.player
	var seen := {}
	for h in m.hunters:
		if h.kin:
			h.kin.summon.burst(10.0)
	_run(0.3)
	for h in m.hunters:
		var k: Kin = h.kin
		if k == null:
			continue
		var want := SideColor.of(m, h)
		var who := "%s's summoned Boki" % h.pname
		ok(not k.wisp and k.ring.visible and _same(SideRings.shown(k.ring), want), "%s: ring under it is the %s colour" % [who, _side(want)])
		ok(_same(_shell(k), want), "%s: glow shell is the %s colour" % [who, _side(want)])
		seen[_side(want)] = true
	ok(seen.size() == 3, "all three reads on screen at once: you, your squad, a rival")
	var rival: Kin = m.hunters.filter(func(h: Hunter): return h.team != p.team)[0].kin
	var mate: Kin = m.hunters.filter(func(h: Hunter): return h.team == p.team and h != p)[0].kin
	ok(not _same(SideRings.shown(rival.ring), SideRings.shown(mate.ring)) and not _same(SideRings.shown(rival.ring), SideRings.shown(p.kin.ring)),
		"a rival's summon never reads as yours or your squad's")
	ok(wild.owner_h == null and _side(SideRings.shown(wild.ring)) == "none" and _side(_shell(wild)) == "none",
		"a wild Boki has no side ring and no side glow")

func _stolen() -> void:
	var p: Hunter = m.player
	var f: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team)[0]
	var fk: Kin = f.kin
	for h in m.hunters:
		if h.kin:
			h.kin.summon.end()
	_run(KinSummon.SHRINK_S + 0.3)
	m.knock(f, p, {})
	_run(0.1)
	ok(KinSteal.loose(fk) and not fk.ring.visible, "a loose wisp has no thief ring yet")
	p.teleport(Vector3(fk.pos.x + 0.5, p.pos.y, fk.pos.z))
	KinSteal.grab(fk, p)
	_run(0.3)
	ok(KinSteal.stolen(fk) and fk.wisp and fk.ring.visible, "a stolen wisp in orbit wears a ring")
	ok(_same(SideRings.shown(fk.ring), SideColor.YOU), "...in the thief's side colour (you), not its owner's")
	ok(fk.ring.scale.x < 1.0 and absf(fk.ring.global_position.distance_to(fk.global_position)) < 0.01, "...small, round the wisp")
	var own: Kin = p.kin
	ok(not own.ring.visible, "your own wisp wears none")
	own.summon.cd = 40.0
	ok(KinSummon.press(p) and not fk.wisp, "the thief summons the stolen Boki")
	_run(0.3)
	ok(fk.ring.visible and _same(SideRings.shown(fk.ring), SideColor.YOU) and _same(_shell(fk), SideColor.YOU),
		"...its ring and glow are the thief's colour, not the victim's")
	var thief: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h != f and h.kin != null)[0]
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == p.team and h != p)[0]
	var mk: Kin = mate.kin
	m.knock(mate, thief, {})
	_run(0.1)
	thief.teleport(Vector3(mk.pos.x + 0.5, thief.pos.y, mk.pos.z))
	KinSteal.grab(mk, thief)
	_run(0.3)
	ok(KinSteal.stolen(mk) and mk.ring.visible and _same(SideRings.shown(mk.ring), SideColor.FOE),
		"a squad-mate's wisp stolen by a rival wears the rival colour")
	ok(not _same(SideRings.shown(mk.ring), SideColor.ALLY), "...not the squad colour it was born with")
