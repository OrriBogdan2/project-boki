extends RefCounted
## --breakables-check: everything smashable (content/rules/breakables.json, scripts/match/breakables.gd).
##   1. no breakable has a health pool; each kind breaks on one hit from a shot, a melee swing, an
##      ability, a Boki strike, an explosion and a dash through it (a powder keg: lit, then blows)
##   2. a break drops loot, and the effect pools do not grow
##   3. a powder keg fuses first, then blows with the configured radius (inside hurt, outside not)
##   4. a chain reaction: a blast lights the kegs in reach, which blow a beat later
##   5. a bot standing by a lit keg is steered away from it
##   6. the sounds: a break plays its material's own sound, a different take each time; a powder keg hisses its own
##      fuse when lit and blows with its own blast (not the shared fuse_hiss or boom), and a chain-lit keg's hiss
##      plays faster so it ends on the shorter fuse

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("BRKCHECK %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "god": true})
	m.set_process(false)
	var spot := _open_spot(m)
	_data()
	_one_hit(m, spot)
	_loot_and_pools(m, spot)
	_fuse_and_radius(m, spot)
	_chain(m, spot)
	_sounds(m, spot)
	_bots(m, spot)
	print("BRKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

## A flat patch near the player with room in every direction.
func _open_spot(m: Match) -> Vector3:
	var p := m.world.free_spot_near(m.player.pos + Vector3(6, 0, 0), [], 3.0, 3.0, 12.0)
	p.y = m.world.ground_at(p.x, p.z)
	return p

func _data() -> void:
	var kinds: Dictionary = Breakables.rules()["kinds"]
	var pooled := true
	for k in kinds:
		pooled = pooled and not kinds[k].has("hp")
	ok("no kind has a health pool, and the roll reaches every kind", pooled and Breakables.kind_for(0.0) == "crate" \
			and Breakables.kind_for(0.999) == "keg")

func _fresh(m: Match, kind_s: String, at: Vector3) -> Dictionary:
	m.player.teleport(at + Vector3(-3.0, 0, 0))
	m._add_break(kind_s, at)
	return m.breaks[-1]

## One hit of this kind of damage on a prop.
func _strike(m: Match, how: String, b: Dictionary) -> void:
	var at: Vector3 = b["pos"]
	var shot_at := at + Vector3(-1.5, 0.4, 0)
	match how:
		"shot":
			m.spawn_shot(m.player, shot_at, Vector2(20, 0), 3.0, 0.5, 0.1, Color.WHITE, {})
		"melee":
			m.spawn_shot(m.player, shot_at, Vector2(20, 0), 3.0, 0.5, 0.1, Color.WHITE, {"melee": true})
		"ability":
			m.spawn_shot(m.player, shot_at, Vector2(20, 0), 0.0, 0.5, 0.1, Color.WHITE, {"src": "abil", "ab": "q"})
		"boki":
			m.spawn_shot(m.player, shot_at, Vector2(20, 0), 0.0, 0.5, 0.1, Color.WHITE, {"kin": true, "kx_dmg": 0.0})
		"blast":
			m.spawn_shot(m.player, at + Vector3(-1.0, 0.4, 0), Vector2.ZERO, 5.0, 0.02, 0.1, Color.WHITE, {"boom": 2.5})
		"dash":
			m.player.teleport(at + Vector3(-0.25, 0, 0))
			m.player.roll_t = 0.3
	step(m, 0.1)

func _one_hit(m: Match, spot: Vector3) -> void:
	var kinds: Dictionary = Breakables.rules()["kinds"]
	for kind_s in kinds:
		for how in ["shot", "melee", "ability", "boki", "blast", "dash"]:
			var b := _fresh(m, kind_s, spot)
			_strike(m, how, b)
			var explosive: bool = kinds[kind_s].has("explosive")
			var hit_ok: bool = bool(b["dead"]) or (explosive and b.has("fuse_t"))
			ok("%s: one %s hit %s" % [kind_s, how, "lights it" if explosive else "breaks it"], hit_ok)
			step(m, float(kinds[kind_s].get("explosive", {}).get("fuse", 0.0)) + 0.2)
			if explosive:
				ok("%s: ...and the %s-lit keg then blows" % [kind_s, how], b["dead"])
			b["dead"] = true
			m.brk.lit.erase(b)

func _loot_and_pools(m: Match, spot: Vector3) -> void:
	var fx_nodes := _fx_children(m)
	for kind_s in ["pot", "crate", "barrel"]:
		var before := m.pickups.size()
		var b := _fresh(m, kind_s, spot)
		m.brk.hit(b, m.player)
		ok("a broken %s drops loot" % kind_s, m.pickups.size() > before, "%d -> %d" % [before, m.pickups.size()])
	for i in 30:
		m.brk.smash(_fresh(m, "crate", spot), m.player)
	step(m, 0.3)
	ok("effects are pooled: breaking 30 crates adds no nodes", _fx_children(m) == fx_nodes, "%d" % fx_nodes)

func _fx_children(m: Match) -> int:
	return m.get_node("BreakFx").get_child_count()

## A rival-free body test: two monsters, one inside the blast and one beyond it.
func _fuse_and_radius(m: Match, spot: Vector3) -> void:
	var ex: Dictionary = Breakables.spec("keg")["explosive"]
	var radius := float(ex["radius"])
	var mobs: Array = m.mobs.filter(func(mb): return not mb.dead and not mb is Boss)
	var inside: Mob = mobs[0]
	var outside: Mob = mobs[1]
	inside.pos = spot + Vector3(radius - 0.6, 0, 0)
	outside.pos = spot + Vector3(-(radius + 1.6 + outside.r), 0, 0)
	inside.hp = 9999.0
	outside.hp = 9999.0
	var b := _fresh(m, "keg", spot)
	m.brk.hit(b, m.player)
	step(m, float(ex["fuse"]) * 0.5)
	ok("a lit keg is fusing, not blown yet", not b["dead"] and m.brk.lit.has(b))
	var hp_in := inside.hp
	step(m, float(ex["fuse"]) * 0.5 + 0.2)
	ok("then it blows after its fuse", b["dead"] and m.brk.lit.is_empty())
	ok("a body inside the configured radius is hurt", inside.hp < hp_in, "%.0f -> %.0f" % [hp_in, inside.hp])
	ok("a body outside it is not", outside.hp == 9999.0)

func _chain(m: Match, spot: Vector3) -> void:
	var ex: Dictionary = Breakables.spec("keg")["explosive"]
	var first := _fresh(m, "keg", spot)
	var second := _fresh(m, "keg", spot + Vector3(0, 0, 1.6))
	var pot := _fresh(m, "pot", spot + Vector3(1.2, 0, 0))
	m.brk.hit(first, m.player)
	step(m, float(ex["fuse"]) + 0.05)
	ok("the first keg blew and lit the next one", first["dead"] and second.has("fuse_t") and not second["dead"])
	ok("a pot in the blast broke at once", pot["dead"])
	step(m, float(ex["chain_fuse"]) + 0.1)
	ok("the chained keg blew a beat later", second["dead"])

## The sounds `act` starts (Sfx's play log, cleared first so no repeat gap or stack limit holds one back).
func _heard(act: Callable) -> Array:
	Sfx.last_played.clear()
	Sfx.recent.clear()
	act.call()
	return Sfx.last_played.keys()

func _sounds(m: Match, spot: Vector3) -> void:
	Sfx.listener = spot
	var rules := Breakables.rules()
	for kind_s in rules["kinds"]:
		var want := String(rules["debris"][rules["kinds"][kind_s]["material"]]["sound"])
		var takes := []
		for i in 4:
			var b := _fresh(m, kind_s, spot)
			if _heard(func(): m.brk.smash(b, m.player)).has(want):
				takes.append(int(Sfx.last_take.get(want, -1)))
		var again := range(1, takes.size()).filter(func(k): return takes[k] == takes[k - 1])
		ok("%s: a break plays %s, a different take each time" % [kind_s, want], takes.size() == 4 and again.is_empty(),
				str(takes))
	var ex: Dictionary = Breakables.spec("keg")["explosive"]
	var keg := _fresh(m, "keg", spot)
	var lit := _heard(func(): m.brk.hit(keg, m.player))
	var own_fuse := lit.has(ex["fuse_sound"]) and not lit.has(ex["blast_sound"]) and not lit.has("fuse_hiss")
	ok("a keg lit by a hit hisses its own fuse", own_fuse, str(lit))
	var blew := _heard(func(): step(m, float(ex["fuse"]) + 0.05))
	ok("...then blows with its own blast", blew.has(ex["blast_sound"]) and not blew.has("boom"), str(blew))
	var chained := _fresh(m, "keg", spot)
	_heard(func(): m.brk.hit(chained, m.player, true))
	var voice: AudioStreamPlayer = Sfx.players[(Sfx.next - 1 + Sfx.players.size()) % Sfx.players.size()]
	var faster := float(ex["fuse"]) / float(ex["chain_fuse"])
	ok("a chain-lit keg's hiss plays faster to end on its fuse", absf(voice.pitch_scale / faster - 1.0) < 0.08,
			"pitch %.2f for %.2f" % [voice.pitch_scale, faster])
	step(m, float(ex["chain_fuse"]) + 0.1)

func _bots(m: Match, spot: Vector3) -> void:
	var b := _fresh(m, "keg", spot)
	m.brk.hit(b, m.player)
	var h: Hunter = m.player
	h.pos = spot + Vector3(0.8, 0, 0)
	var steer := Breakables.bot_steer(m, h, Vector2.ZERO)
	ok("a bot beside a lit keg is steered away from it", steer.x > 0.9)
	h.pos = spot + Vector3(40, 0, 0)
	ok("a bot far away is left alone", Breakables.bot_steer(m, h, Vector2(0, 1)) == Vector2(0, 1))
