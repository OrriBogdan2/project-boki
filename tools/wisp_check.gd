extends RefCounted
## --wisp-check: a downed Hunter turns into a Wisp (docs/decisions/0019-downed-wisp.md). For all 12 heroes,
## a bot teammate and the tutorial: down a hero, the Wisp spawns and the hero model hides, it hums, it
## hangs back heavily when the hunter moves and settles once they stop, a revive brings the hero back
## (scaled up from the pop), frees the Wisp and stops the hum, and a bleed-out breaks it. The downed
## gameplay (downed flag, speed, hittable) is read untouched. Also the look data and the outline rule
## (round body with a head, team rim, white core, low hover, no flicker, one mesh in one material): every
## look has all its keys and real sounds, an unknown id gives the default Wisp, a look that lists only a
## few keys builds, and the saved id round-trips. Then the Boki wisp prototype (KinWisp):
## off by default (the Boki walks); on, every Boki rides as a critter-outline wisp orbiting its hunter at
## shoulder height, carry passives on, no orders or hits, the AI not ticking, and the snapshot flag turns a
## remote Boki into a wisp and back. The summon (KinSummon): every species has a window and cooldown in the
## uptime band; Summon bursts the wisp into the full Boki on its AI with a short leash, damage never ends
## it, a knock-down turns it back into a wisp with the longer cooldown, the window ends in a shrink back to
## a dim wisp, a resting summon refuses, the snapshot carries it. The stolen-wisp looks (StolenWisp): loose
## wisps bob and pulse, a grab puts a thin side-colour ring and a tether on it, a scatter sends each wisp its own
## way, the flight home trails and arrives, all within the particle budget. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var bad := 0
var m: Match
var main: Node
var _spot: Vector3       # each hero cycle starts here: the drift rows walk the Wisp 1.4 m a cycle, toward the abyss

func run(main_node: Node) -> void:
	main = main_node
	_looks()
	_start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true})
	_spot = m.player.pos
	for a in Arch.ids():
		_hero_cycle(a)
	_bleed_out()
	_teammate()
	_boki_wisps()
	_summon_data()
	_summon()
	_stolen()
	m.queue_free()
	_tutorial()
	print("WISPCHECK %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("WISP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(opts: Dictionary) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start(opts)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"      # the player too: a crawling bot would hide the Wisp settling
		h.inp["move"] = Vector2.ZERO

func _frames(secs: float, drift := Vector3.ZERO) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		for h in m.hunters:
			if h == m.player:
				h.pos += drift
				h.prev = h.pos
			h.render(DT, 1.0)

## One hero: up, down (Wisp, hidden hero), moving, revived (hero grows back, Wisp gone).
func _hero_cycle(arch_id: String) -> void:
	var p: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	p.pos = _spot
	p.reclass(Arch.weight(arch_id), arch_id)
	p.hp = p.max_hp
	var tag := "[%s] " % arch_id
	_frames(0.1)
	ok(p.model.visible and HunterWisp.node_of(p) == null, tag + "up: the hero shows, no Wisp")
	var base: Vector3 = p.model.scale
	m.knock(p, foe, {})
	p.down_hp = 1e6
	_frames(0.05)
	var wisp := HunterWisp.node_of(p)
	var spawned: bool = wisp != null and wisp.is_inside_tree() and wisp.get_parent() == p
	ok(p.downed and spawned, tag + "downed: a Wisp spawns on the hunter")
	ok(not p.model.visible, tag + "downed: the hero model is hidden")
	_frames(0.4)
	ok(HunterWisp.mode_of(p) == HunterWisp.ON, tag + "the pop-in ends and the Wisp idles")
	ok(p.downed and not p.out, tag + "downed gameplay untouched: still downed, not out")
	ok(Sfx.loop_on(HunterWisp.hum_key(p)), tag + "a downed Wisp hums")
	_frames(0.3, Vector3(0.08, 0, 0))
	ok(wisp.position.x < -0.1, tag + "a moving Wisp hangs back behind the hunter (%.2f m)" % -wisp.position.x)
	ok((wisp.get_node("Body") as Node3D).basis != Basis.IDENTITY, tag + "...and leans")
	_frames(0.15)
	ok(wisp.position.x < -0.05, tag + "it settles heavily: still behind 0.15 s after the stop")
	_frames(1.5)
	ok(absf(wisp.position.x) < 0.02, tag + "...and has caught up after 1.65 s (%.3f m)" % wisp.position.x)
	m.revive_hunter(p, null)
	_frames(0.04)
	var popping: bool = HunterWisp.mode_of(p) == HunterWisp.OUT
	ok(not p.downed and p.model.visible and popping, tag + "revived: the hero is back, the pop-out plays")
	ok(not Sfx.loop_on(HunterWisp.hum_key(p)), tag + "the revive stops the hum")
	ok(p.model.scale.y < base.y * 0.95, tag + "the hero starts small (%.2f of full)" % (p.model.scale.y / base.y))
	_frames(0.5)
	ok(HunterWisp.mode_of(p) == "" and HunterWisp.node_of(p) == null, tag + "the Wisp is gone after the pop-out")
	ok(p.model.scale.is_equal_approx(base), tag + "the hero is back at full size")

func _bleed_out() -> void:
	var p: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	p.hp = p.max_hp
	_frames(0.1)
	m.knock(p, foe, {})
	_frames(0.4)
	var burst0: int = m.fx.radial
	m.eliminate(p, foe, "finished")
	_frames(0.1)
	var gone: bool = HunterWisp.node_of(p) == null and HunterWisp.mode_of(p) == ""
	ok(gone, "bleed-out or an execute breaks the Wisp (it is freed)")
	ok(not Sfx.loop_on(HunterWisp.hum_key(p)), "...and stops the hum")
	ok(m.fx.radial > burst0, "...with a burst of sparks")
	m.revive_hunter(p, null)
	Life.bring_back(m, p, p.pos, 0.5, false)
	_frames(0.1)
	ok(p.model.visible, "back from the dead: the hero shows")

## A bot or remote teammate has no saved look: it gets the default Wisp, from `downed` alone.
func _teammate() -> void:
	var p: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
	var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	m.knock(mate, foe, {})
	_frames(0.3)
	ok(HunterWisp.node_of(mate) != null and not mate.model.visible, "a teammate's downed state shows their Wisp")
	var teammates_downed: bool = mate.downed
	m.revive_hunter(mate, null)
	_frames(0.6)
	var back: bool = mate.model.visible and HunterWisp.node_of(mate) == null
	ok(teammates_downed and back, "...and their revive brings the hero back")

func _tutorial() -> void:
	_start({"teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "tutorial": true})
	var p: Hunter = m.player
	var base: Vector3 = p.model.scale
	_frames(0.2)
	m.knock(p, null, {})
	_frames(0.3)
	ok(p.downed and HunterWisp.node_of(p) != null and not p.model.visible, "tutorial: downed shows the Wisp")
	var waited := 0.0
	while p.downed and waited < 10.0:       # the tutorial brings you back after about 3 s of its own time
		_frames(0.25)
		waited += 0.25
	_frames(0.5)
	ok(not p.downed and p.model.visible and HunterWisp.node_of(p) == null, "tutorial: the revive brings the hero back")
	ok(p.model.scale.is_equal_approx(base), "tutorial: at full size")
	m.queue_free()

func _looks() -> void:
	var rules := WispLook.rules()
	var default_look := WispLook.get_look("")
	for id in rules["looks"]:
		var look := WispLook.get_look(String(id))
		var same_keys := true
		for key in default_look:
			same_keys = same_keys and look.has(key)
		ok(same_keys, "look '%s' has every key" % id)
		for spec in [look["pop_in"], look["pop_out"], look["snuff"], look["hum"]]:
			ok(String(spec["sfx"]) in Sfx.NAMES, "look '%s': sound '%s' exists" % [id, spec["sfx"]])
		_outline(String(id), look)
	ok(WispLook.get_look("no_such_wisp") == default_look, "an unknown id gives the default Wisp")
	var rules_looks: Dictionary = rules["looks"]
	rules_looks["check_ember"] = {"core": {"rim": "ff6a00"}, "hover": 0.3}      # a new Wisp is data only
	var ember := WispLook.get_look("check_ember")
	var kept: bool = ember["body"]["radius"] == default_look["body"]["radius"]
	ok(ember["core"]["rim"] == "ff6a00" and kept, "a look lists only what it changes")
	var body2 := WispLook.build(ember, Color.RED)
	var mat: ShaderMaterial = body2.get_node("Body").material_override
	ok(mat.get_shader_parameter("rim_col") == Color("ff6a00"), "...and builds with its own rim colour")
	body2.free()
	ok(WispLook.equip("check_ember") and WispLook.equipped() == "check_ember", "the saved Wisp id round-trips")
	rules_looks.erase("check_ember")
	var fell_back: bool = WispLook.equipped() == "default" and not WispLook.equip("check_ember")
	ok(fell_back, "a missing look falls back to the default")

## The Boki wisp prototype: the setting's default leaves the walking Boki; on, the Boki rides as a wisp.
func _boki_wisps() -> void:
	var base := {"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle"}
	ok(Settings.DEFAULTS["boki_wisps"] == false, "Boki wisps: the setting is off by default")
	_start(base.merged({"boki_wisps": false}))
	_frames(0.3)
	var walker: Kin = m.player.kin
	var walks: bool = not walker.wisp and walker.state == "active" and walker.model.name != "BokiWisp"
	ok(walks, "Boki wisps off: the Boki walks")
	_start(base.merged({"boki_wisps": true}))
	_frames(0.3)
	var p: Hunter = m.player
	var k: Kin = p.kin
	var owned: Array = m.kins.filter(func(x: Kin): return x.owner_h != null)
	var all_wisps: bool = owned.all(func(x: Kin): return x.wisp and x.state == "shoulder")
	ok(all_wisps and k.model.name == "BokiWisp", "Boki wisps on: every Boki rides as a critter wisp")
	ok(k.carried() and p.kin_carry_on(), "...carried by order, so its carry passives are on")
	ok(HunterWisp.node_of(p) == null, "...and it is not a Hunter Wisp (round = Hunter, critter = Boki)")
	k.think_t = 5.0
	var searches := k.path_searches
	_frames(0.5, Vector3(0.05, 0, 0))
	ok(k.think_t == 5.0 and k.path_searches == searches, "...its AI does not tick (no thinking, no paths)")
	var lag := k.pos.distance_to(p.pos + Vector3(0, 1.5, 0))
	ok(k.state == "shoulder" and lag < 0.06, "...it rides along as you move (%.2f m behind)" % lag)
	k.throw_to(p.pos + Vector3(5, 0, 0))
	ok(k.state == "shoulder" and not KinFollow.set_cmd(k, "follow"), "...it takes no throw and no order")
	ok(k.hurt(50.0, null) == 0.0 and not k.ready_to_fight(), "...it takes no hits and casts nothing")
	k.render(DT, 1.0)
	var flat := Vector2(k.global_position.x - p.position.x, k.global_position.z - p.position.z).length()
	var high := k.global_position.y - p.position.y
	var orbit: bool = absf(flat - KinWisp.ORBIT_R) < 0.05 and high > 1.0 and high < 2.0
	ok(orbit, "...orbiting at shoulder height (%.2f m out, %.2f m up)" % [flat, high])
	var other: Kin = owned.filter(func(x: Kin): return x != k)[0]
	var snap := KinNet.kin_extra(k)
	var row: Array = []
	row.resize(KinNet.KIN_AT)
	KinWisp.set_wisp(other, false)
	KinNet.apply_kin(other, row + snap)
	ok(other.wisp and other.model.name == "BokiWisp", "online: the snapshot flag shows the wisp on the other game")
	snap[5] = 0
	KinNet.apply_kin(other, row + snap)
	ok(not other.wisp and other.model.name != "BokiWisp", "online: and turns it back into the walking Boki")

## The summon numbers: a table cell for every species' role and size, each inside the uptime band.
func _summon_data() -> void:
	var band: Array = KinSummon.rules()["uptime_band"]
	var bad_ids: Array = []
	for id in KinLib.kin_ids():
		var t := KinSummon.times(KinLib.kin(id))
		var row: Dictionary = KinSummon.rules()["table"].get(String(KinLib.kin(id).ai.get("role", "")), {})
		var up := t.x / (t.x + t.y)
		if not row.has(KinLib.kin(id).size) or up < float(band[0]) or up > float(band[1]):
			bad_ids.append(id)
	ok(bad_ids.is_empty(), "summon: every species has a role x size window in the uptime band %s" % [bad_ids])
	ok(KinSummon.times(KinLib.kin("cindle")) == Vector2(8, 60), "summon: Cindle (small bruiser) is out 8 s, rests 60 s")

## The summon itself, on the player's Cindle with Boki wisps on.
func _summon() -> void:
	_start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	_frames(0.3)
	var p: Hunter = m.player
	var k: Kin = p.kin
	var s := k.summon
	ok(Settings.key_cap("summon") != "?" and Settings.ACTIONS.any(func(a): return a[0] == "summon"),
		"summon: a rebindable Summon action with a key cap (%s)" % Settings.key_cap("summon"))
	ok(KinSummon.press(p) and not k.wisp and k.state == "active" and k.model.name != "BokiWisp",
		"summon: the wisp bursts into the full Boki")
	ok(k.ready_to_fight() and k.hp == k.max_hp and absf(s.left - 8.0) < 0.01, "...whole, on its AI, for its 8 s window")
	var lsh := k.brain.leash()
	ok(lsh >= 8.0 and lsh <= 12.0, "...on a short leash (%.1f m)" % lsh)
	ok(m.kins.filter(func(x: Kin): return x.owner_h == p and not x.wisp).size() == 1, "...one summon at a time")
	k.hurt(k.max_hp * 0.6, null)
	_frames(0.2)
	ok(s.left > 0.0 and not k.wisp, "...damage does not end it")
	p.teleport(_ground_away(p.pos, 30.0))
	_frames(0.1)
	ok(k.flat_dist(p) < 6.0 and s.out(), "...left 30 m behind it re-blooms beside you")
	_frames(8.0 + KinSummon.SHRINK_S)
	ok(k.wisp and k.state == "shoulder" and s.cd > 59.0 and s.cd <= 60.0,
		"summon: the window ends, it shrinks back into a wisp, the cooldown runs (%.1f s)" % s.cd)
	k.render(DT, 1.0)
	var trail := k.model.get_node("Trail") as CPUParticles3D
	ok(not trail.emitting, "...the wisp is dim while it rests")
	ok(not KinSummon.press(p) and k.wisp, "...and Summon is refused until it is rested")
	s.cd = 0.0
	k.render(DT, 1.0)
	ok((k.model.get_node("Trail") as CPUParticles3D).emitting, "...bright again when ready")
	KinSummon.press(p)
	ok(KinSummon.press(p) and s.shrink > 0.0, "summon: Summon again sends it back early")
	_frames(KinSummon.SHRINK_S + 0.05)
	ok(k.wisp and absf(s.cd - 60.0) < 0.2, "...full cooldown (%.1f s)" % s.cd)
	s.cd = 0.0
	KinSummon.press(p)
	k.hurt(k.max_hp * 5.0, null)
	ok(k.wisp and k.state == "shoulder" and absf(s.cd - 75.0) < 0.01,
		"summon: knocked down, it turns back into a wisp, 75 s cooldown")
	s.cd = 0.0
	KinSummon.press(p)
	var other: Kin = m.kins.filter(func(x: Kin): return x.owner_h != null and x != k)[0]
	var row: Array = []
	row.resize(KinNet.KIN_AT)
	KinNet.apply_kin(other, row + KinNet.kin_extra(k))
	ok(not other.wisp and absf(other.summon.left - s.left) < 0.11,
		"online: the snapshot shows the summoned Boki and its seconds")

func _stolen() -> void:
	_start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true})
	var thief: Hunter = m.player
	var foe: Hunter = m.hunters.filter(func(x): return x.team != thief.team)[0]
	var at := thief.position + Vector3(6, 1.3, 0)
	var a := StolenWisp.spawn(m, "cindle", {}, at)
	var b := StolenWisp.spawn(m, "puddlet", {}, at)
	var body := a.model.get_node("Body") as Node3D
	var lo := 9.0
	var hi := -9.0
	for i in 240:
		a.tick(1.0 / 60.0)
		lo = minf(lo, body.position.y)
		hi = maxf(hi, body.position.y)
	ok(a.state == StolenWisp.State.LOOSE and a.position == at and hi - lo > StolenWisp.BOB_M,
			"stolen: a loose wisp bobs in place (%.2f m)" % (hi - lo))
	var dims := []
	for i in 120:
		a.tick(1.0 / 60.0)
		dims.append(float(body.get_instance_shader_parameter("dim")))
	ok(dims.min() < StolenWisp.PULSE_LOW + 0.05 and dims.max() > 0.98 and dims.min() >= StolenWisp.PULSE_LOW - 0.01,
			"...and pulses softly (%.2f to %.2f)" % [dims.min(), dims.max()])
	a.grab(thief, 0)
	b.grab(thief, 1)
	for i in 120:
		a.tick(1.0 / 60.0)
		b.tick(1.0 / 60.0)
	ok(a.col.is_equal_approx(SideColor.of(m, thief)) and not a.col.is_equal_approx(SideColor.FOE),
			"stolen: the ring takes the thief's side colour")
	var torus := a._ring.mesh as TorusMesh
	ok(torus.outer_radius - torus.inner_radius <= 0.03 and (a._tether.mesh as CylinderMesh).top_radius <= 0.02,
			"...thin ring and thin tether")
	var ring_body_y := (a.model.get_node("Body") as Node3D).global_position.y
	ok(a.position.y - thief.position.y > 1.0 and absf(a._ring.global_position.y - ring_body_y) < 0.01,
			"...round the wisp, up at shoulder height, never on the ground")
	ok(a.position.distance_to(b.position) > 0.5, "...two stolen wisps float apart")
	var run := thief.position
	for i in 30:
		thief.position += Vector3(0.3, 0, 0)
		a.tick(1.0 / 60.0)
	var chest := thief.position + Vector3(0, StolenWisp.CHEST_Y, 0)
	var tl := a._tether.global_transform
	var held_body := (a.model.get_node("Body") as Node3D)
	ok(a._ring.position == held_body.position, "...the ring rides the body's bob")
	ok(tl.basis.y.length() > 1.5 and tl.origin.distance_to((chest + held_body.global_position) * 0.5) < 0.05,
			"...a running thief drags the tether out (%.1f m)" % tl.basis.y.length())
	ok(a.get_children().all(func(n): return not n is CPUParticles3D),
			"...no particles of its own beyond the body's sparkles")
	thief.position = run
	var from := a.global_position
	m.fx.radial = 0
	a.scatter(0, 2)
	b.scatter(1, 2)
	ok(a._ring == null or a._ring.is_queued_for_deletion(), "scatter: the ring and tether let go")
	for i in int(StolenWisp.SCATTER_S * 60.0) + 2:
		a.tick(1.0 / 60.0)
		b.tick(1.0 / 60.0)
	var da := a.position - from
	var db := b.position - from
	ok(a.state == StolenWisp.State.LOOSE and b.state == StolenWisp.State.LOOSE, "...each settles loose again")
	ok(da.length() > 3.0 and db.length() > 3.0 and absf(da.angle_to(db)) > 0.6,
			"...and darted its own way (%.0f deg apart)" % rad_to_deg(da.angle_to(db)))
	ok(m.fx.radial >= 2, "...a small burst marks each")
	var sparkles := 0
	for w in [a, b]:
		sparkles += (w.model.get_node("Trail") as CPUParticles3D).amount
	ok(sparkles + 8 * BokiWispLook.TRAIL_AMOUNT < 300,
			"particles: ten wisps stay under the 300 budget (%d now)" % sparkles)
	var homed := [false]
	a.arrived.connect(func(): homed[0] = true)
	a.go_home(foe)
	for i in 5:
		a.tick(1.0 / 60.0)
	ok(a._ribbon != null and (a._ribbon.mesh as ImmediateMesh).get_surface_count() == 1,
			"home: a ribbon trails behind the flight")
	for i in 400:
		if homed[0]:
			break
		a.tick(1.0 / 60.0)
	ok(homed[0] and a.is_queued_for_deletion(),
			"...it arrives at its owner within %.1f s and folds in" % StolenWisp.HOME_S.y)
	b.queue_free()

## The outline rule (briefs/DECISIONS.md 2026-11-09): a round body with a head, team colour rim, white
## core, low to the ground, a steady glow, and one mesh in one material so thirty stay cheap.
func _outline(id: String, look: Dictionary) -> void:
	var tag := "look '%s': " % id
	var body := WispLook.build(look, Color.RED)
	var mesh := body.get_node_or_null("Body") as MeshInstance3D
	ok(mesh != null and body.get_child_count() == 1 and mesh.get_child_count() == 0, tag + "one mesh, nothing else")
	if mesh == null:
		body.free()
		return
	var box := mesh.mesh.get_aabb()
	var round_body: bool = absf(box.size.x - box.size.z) < 0.01 and box.size.x > 0.3
	var shape := "%.2f wide, %.2f tall" % [box.size.x, box.size.y]
	ok(round_body and box.size.y > box.size.x * 1.1, tag + "a round body with a head on top (" + shape + ")")
	var mat := mesh.material_override as ShaderMaterial
	ok(mat != null and body.get_meta("mat") == mat, tag + "one material, the one HunterWisp flashes")
	ok(mat.get_shader_parameter("rim_col") == Color.RED, tag + "the rim is the team colour")
	ok(mat.get_shader_parameter("core_col") == Color.WHITE, tag + "the core is white")
	var steady := true
	for uniform in mat.shader.get_shader_uniform_list():
		steady = steady and not String(uniform["name"]).contains("flicker")
	ok(steady, tag + "the glow is steady: the shader has no flicker")
	var low: bool = float(look["hover"]) <= 0.5 and float(look["hover"]) + box.position.y > 0.05
	ok(low, tag + "it floats low, clear of the ground (centre %.2f m)" % float(look["hover"]))
	var heavy: bool = float(look["settle"]) >= 0.3 and float(look["bob_hz"]) <= 0.7
	ok(heavy, tag + "slow and heavy: settle %.1f s, bob %.2f Hz" % [look["settle"], look["bob_hz"]])
	body.free()


## A spot on solid ground dist m from here (the first of 8 directions that is not over the abyss).
func _ground_away(from: Vector3, dist: float) -> Vector3:
	for i in 8:
		var to := from + Vector3(dist, 0, 0).rotated(Vector3.UP, i * TAU / 8.0)
		if not m.world.is_void(to.x, to.z):
			return Vector3(to.x, m.world.ground_at(to.x, to.z), to.z)
	return from + Vector3(dist, 0, 0)
