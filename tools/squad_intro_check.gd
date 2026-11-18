extends RefCounted
## --squad-intro-check: the squad intro before the skyship ride (SquadIntro, 0.24.4) and the ship itself.
##  1. The ship model: props, contrail and shadow are there; it is baked into a few meshes (perf pass).
##  2. A real start plays the intro: the HUD is hidden, the map waits, the plan is padded by INTRO_T,
##     the squad stands on the deck (drawn; another squad aboard is not), each strikes a pose in turn,
##     the plates read "<Name> the <Title>", the Boki wisps hover beside them.
##  3. A key before SKIP_AFTER is swallowed and the intro plays on; after it, the intro ends and the
##     plan gives the rest back.
##  4. Played out, it hands off to the drop map, then to the ride: the squad still on deck as the ship
##     sails, then the jump.
##  5. The same lineup again this session (offline) skips it; a check that starts a match by hand
##     (no squad_intro) never sees it.
##  6. Nothing of the ship sticks up through the deck where the squad stands (a ray down each rider's slot
##     meets the deck, not the hull), and the ride has no looping sound.
##  7. A press on a locked ability while aboard (in the plan, and on the ride) spends the skill point,
##     and the Boki ride on the shoulder without hopping off the deck and back (ring + sound each beat).

const MAX_MESHES := 14         # mesh instances in a whole ship (one per material after the bake, plus props)
const MAX_TRIS := 60000        # triangles in a whole ship (low preset: a few % of the 1.5M budget)
const DECK_SLACK := 0.15       # m: a rider's feet this close to the deck height

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("INTRO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _model() -> void:
	var n: Node3D = SkyshipModel.build()
	ok(n.get_node_or_null("PropL") != null and n.get_node_or_null("PropR") != null, "the ship has both props")
	ok(n.get_node_or_null("Trail") is CPUParticles3D, "the ship has its contrail")
	ok(n.get_node_or_null("Shadow") is MeshInstance3D, "the ship has its ground shadow")
	var meshes := 0
	var tris := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is MeshInstance3D and c.name != "Shadow":
			meshes += 1
			var mesh := (c as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				var pts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				tris += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int(pts.size() / 3.0)
	ok(meshes <= MAX_MESHES, "the ship is baked into %d meshes (at most %d)" % [meshes, MAX_MESHES])
	ok(tris <= MAX_TRIS, "the ship is %d triangles (at most %d)" % [tris, MAX_TRIS])
	n.free()

## The highest surface of the ship (its meshes, not the shadow) over a deck spot, in ship space.
func _top_at(n: Node3D, x: float, z: float) -> float:
	var top := -INF
	for c in n.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null or mi.name == "Shadow":
			continue
		var hit: Dictionary = mi.mesh.generate_triangle_mesh().intersect_ray(
				mi.transform.affine_inverse() * Vector3(x, 3.0, z), Vector3.DOWN)
		if not hit.is_empty():
			top = maxf(top, (mi.transform * (hit["position"] as Vector3)).y)
	return top

func _deck_and_sounds(m: Match) -> void:
	var n: Node3D = m.ship["node"]
	for h in m.intro.squad:
		var at: Vector2 = SkyDeck.slot(m, h)
		var top := _top_at(n, at.x, at.y)
		var met := absf(top - SkyshipModel.DECK_Y) < 0.02
		ok(met, "%s's feet meet the deck, not the hull (surface %.2f, deck %.2f)" % [h.pname, top, SkyshipModel.DECK_Y])
	var loops := Sfx.loops.keys().filter(func(k: String) -> bool: return k.begins_with("ship_"))
	ok(loops.is_empty(), "the ride plays no looping engine or wind (%s)" % [loops])

func _ranks_aboard() -> void:
	var m := await _start(false)
	var p: Hunter = m.player
	p.skill_pts = 2
	ok(int(p.slot_lv["sec"]) == 0 and int(p.slot_lv["dash"]) == 0, "every ability starts locked")
	m.pending_input["sec"] = true
	m.step(Match.DT)
	ok(int(p.slot_lv["sec"]) == 1 and p.skill_pts == 1, "a key press in the plan spends a point on it")
	m.skydrop.plan_t = 0.0
	_tick(m, 0.5)
	ok(not m.skydrop.planning and p.riding, "the ship has set off")
	m.pending_input["dash"] = true
	_tick(m, 0.1)
	ok(int(p.slot_lv["dash"]) == 1 and p.skill_pts == 0 and p.riding, "a key press on the ride spends a point on it")
	# the Boki stay on their riders' shoulders: no hop off the deck and back (a ring and a sound every beat)
	Sfx.cue_log = []
	_tick(m, 2.0)
	var hops: Array = Sfx.cue_log.filter(func(e: Array) -> bool: return e[0] == "recall")
	Sfx.cue_log = null
	var kins := m.hunters.filter(func(h: Hunter) -> bool: return h.riding and h.kin is Kin)
	var off := kins.filter(func(h: Hunter) -> bool: return (h.kin as Kin).state != "shoulder")
	var on_txt := "every rider's Boki stays on the shoulder (%d of %d off)" % [off.size(), kins.size()]
	ok(not kins.is_empty() and off.is_empty(), on_txt)
	ok(hops.is_empty(), "no Boki hop sound on the ride (%d in 2 s)" % hops.size())
	m.queue_free()
	await main.get_tree().process_frame

func _start(intro: bool) -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242, "squad_intro": intro})
	m.set_process(false)
	return m

func _tick(m: Match, secs: float) -> void:
	for i in int(secs / Match.DT):
		m.step(Match.DT)
		if m.intro:
			m.intro.frame(Match.DT)

func _on_deck(h: Hunter, n: Node3D) -> bool:
	return absf(h.pos.y - (n.position.y + SkyshipModel.DECK_Y)) < DECK_SLACK

func _key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	return e

func _plays_out() -> void:
	SquadIntro._last_lineup = ""
	var m := await _start(true)
	ok(m.intro != null and m.intro.running(), "a real start plays the squad intro")
	if m.intro == null:
		m.queue_free()
		return
	ok(not m.hud.visible and not m.hud.map_open(), "the HUD and the drop map wait for it")
	ok(is_equal_approx(m.skydrop.plan_len, DropSquad.PLAN_T + SquadIntro.INTRO_T), "the plan is padded by the intro")
	var squad: Array = m.intro.squad
	ok(squad.size() == 3, "the whole squad is in it (%d)" % squad.size())
	_tick(m, 0.2)
	var n: Node3D = m.ship["node"]
	for h in squad:
		ok(_on_deck(h, n) and h.grounded, "%s stands on the deck" % h.pname)
		ok(SkyDeck.shown(h), "%s is drawn on the deck" % h.pname)
		var plate: PackedStringArray = SquadIntro.plate_text(h)
		var want: String = HeroTitle.label(HeroTitle.base_name(h.arch), h.arch)
		ok(plate[0] == want and " the " in plate[0], "plate reads '%s'" % plate[0])
	for h in m.hunters:
		if h.team != m.player.team and h.riding:
			ok(not SkyDeck.shown(h), "another squad aboard is not drawn")
			break
	_deck_and_sounds(m)
	var wisps: Dictionary = m.ship.get("wisps", {})
	var kins := squad.filter(func(h: Hunter) -> bool: return h.kin is Kin).size()
	ok(wisps.size() == kins, "a Boki wisp beside each hunter with one (%d of %d)" % [wisps.size(), kins])
	m.intro.skip(_key())
	ok(m.intro.running(), "a key before %.1f s doesn't skip it" % SquadIntro.SKIP_AFTER)
	_tick(m, SquadIntro.BEAT_AT + SquadIntro.BEAT_GAP * 2.0)
	var posed := 0
	for e in m.truce.shown:
		if squad.has(e["h"]): posed += 1
	ok(posed == squad.size(), "each hunter struck a pose (%d)" % posed)
	_tick(m, SquadIntro.INTRO_T)
	ok(not m.intro.running(), "it ends by itself")
	ok(m.hud.visible and m.hud.map_open() and m.skydrop.planning, "then the HUD and the drop map")
	ok(m.truce.shown.filter(func(e: Dictionary) -> bool: return squad.has(e["h"])).is_empty(), "its poses are cleared")
	_tick(m, m.skydrop.plan_t + 0.5)
	ok(not m.skydrop.planning, "the plan runs out and the ship sets off")
	var y0 := n.position
	_tick(m, 1.0)
	ok(n.position.distance_to(y0) > 5.0, "the ship sails")
	ok(m.player.riding and _on_deck(m.player, n), "the squad rides on deck")
	m.ship_jump(m.skydrop.leader(m.player.team), true)
	ok(m.player.riding and m.player.rocket != null, "the leader's launch hands the squad to the rocket")
	ok(SkyDeck.drawn(m.player), "the rocket's riders are drawn")
	m.queue_free()
	await main.get_tree().process_frame

func _skips() -> void:
	SquadIntro._last_lineup = ""
	var m := await _start(true)
	if m.intro == null:
		ok(false, "the intro plays for the skip case")
		m.queue_free()
		return
	_tick(m, SquadIntro.SKIP_AFTER + 0.1)
	ok(m.intro.skip(_key()) and not m.intro.running(), "a key after %.1f s skips it" % SquadIntro.SKIP_AFTER)
	ok(absf(m.skydrop.plan_t - DropSquad.PLAN_T) < 0.1, "the plan gives the rest back (%.2f s left)" % m.skydrop.plan_t)
	ok(m.hud.visible and m.hud.map_open(), "the skip opens the drop map")
	m.queue_free()
	await main.get_tree().process_frame
	m = await _start(true)
	var again := m.intro == null and is_equal_approx(m.skydrop.plan_len, DropSquad.PLAN_T)
	ok(again, "the same lineup again is not shown twice")
	m.queue_free()
	await main.get_tree().process_frame
	SquadIntro._last_lineup = ""
	m = await _start(false)
	ok(m.intro == null and m.hud.map_open(), "a match started by hand has no intro")
	m.queue_free()
	await main.get_tree().process_frame

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_model()
	await _plays_out()
	await _skips()
	await _ranks_aboard()
	print("INTRO DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
