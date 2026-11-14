extends RefCounted
## --breakables-check: everything smashable (content/rules/breakables.json, scripts/match/breakables.gd).
##   1. no breakable has a health pool; each kind breaks on one hit from a shot, a melee swing, an
##      ability, a Boki strike, an explosion and a dash through it (a powder keg: lit, then blows)
##   2. a break drops loot, and the effect pools do not grow
##   3. a powder keg fuses first, then blows with the configured radius (inside hurt, outside not)
##   4. a chain reaction: a blast lights the kegs in reach, which blow a beat later
##   5. a bot standing by a lit keg is steered away from it
##   6. each material's debris on the low preset: its own look, at most BreakFx.DEBRIS_CAP bits, all gone within
##      1 s, and no ring or burst (only a keg's blast makes those)
## --breakables-shots --shots-dir=<dir> (GPU, through jobq): breakables_debris.jpg, a row per kind in the rules'
## order (crate, pot, barrel, keg), each a crop at the game camera before the break and at SHOT_MARKS s after it.

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const SHOT_MARKS := [0.0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0]   # s after the break
const CROP := Vector2i(300, 220)       # px round the prop for a frame

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

func run(main_node: Node, mode := "check") -> void:
	if mode == "shots":
		await shots(main_node)
		return
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
	_bots(m, spot)
	_debris(m, spot)
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

func _bots(m: Match, spot: Vector3) -> void:
	var b := _fresh(m, "keg", spot)
	m.brk.hit(b, m.player)
	var h: Hunter = m.player
	h.pos = spot + Vector3(0.8, 0, 0)
	var steer := Breakables.bot_steer(m, h, Vector2.ZERO)
	ok("a bot beside a lit keg is steered away from it", steer.x > 0.9)
	h.pos = spot + Vector3(40, 0, 0)
	ok("a bot far away is left alone", Breakables.bot_steer(m, h, Vector2(0, 1)) == Vector2(0, 1))

func _debris(m: Match, spot: Vector3) -> void:
	var keep_q = Settings.v["quality"]
	Settings.v["quality"] = "low"
	step(m, 1.5)      # the keg the bot test lit blows, and its debris lands
	var kinds: Dictionary = Breakables.rules()["kinds"]
	var fx: BreakFx = m.get_node("BreakFx")
	for mat_name: String in Breakables.rules()["debris"]:
		var look: Dictionary = Breakables.rules()["debris"][mat_name]
		var kind_s: String = kinds.keys().filter(func(k): return kinds[k]["material"] == mat_name)[0]
		var radial := m.fx.radial
		m.brk.smash(_fresh(m, kind_s, spot), m.player)
		var n := fx.flying_n
		var blasts: bool = kinds[kind_s].has("explosive")
		ok("%s (%s): %s debris, %d..%d bits on low" % [mat_name, kind_s, look["look"], BreakFx.DEBRIS_MIN,
				BreakFx.DEBRIS_CAP], n >= BreakFx.DEBRIS_MIN and n <= BreakFx.DEBRIS_CAP, "%d bits" % n)
		ok("%s: %s" % [kind_s, "the one blast" if blasts else "no ring or burst"], (m.fx.radial > radial) == blasts,
				"radial %d -> %d" % [radial, m.fx.radial])
		step(m, 1.0)
		ok("%s: debris lives %.2f s, all gone within 1 s" % [mat_name, float(look["life"])], float(look["life"]) < 1.0 \
				and fx.flying_n == 0 and fx.flying.is_empty(), "%d left" % fx.flying_n)
	Settings.v["quality"] = keep_q

func shots(main_node: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Engine.max_fps = 60          # one sim step a drawn frame, so the GPU debris keeps the sim's time
	var m := Match.new()
	main_node.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "god": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main_node.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var spot := _open_spot(m)
	var rows: Array = []
	for kind_s: String in Breakables.rules()["kinds"]:
		rows.append(await _shot_row(main_node, m, kind_s, spot))
	var sheet := Image.create(rows[0].get_width(), rows[0].get_height() * rows.size(), false, rows[0].get_format())
	for i in rows.size():
		sheet.blit_rect(rows[i], Rect2i(Vector2i.ZERO, rows[i].get_size()), Vector2i(0, i * rows[0].get_height()))
	sheet.save_jpg(dir.path_join("breakables_debris.jpg"), 0.9)
	print("BRKSHOTS %d rows in %s" % [rows.size(), dir])
	main_node.get_tree().quit(0)

## One kind broken in view: a crop before the break, then one at each mark after it.
func _shot_row(main_node: Node, m: Match, kind_s: String, spot: Vector3) -> Image:
	var b := _fresh(m, kind_s, spot)
	var frames: Array = []
	var marks := SHOT_MARKS.duplicate()
	var t := -0.5
	while not marks.is_empty():
		if t < 0.0 and t + DT >= 0.0:
			m.brk.smash(b, m.player)
		m.step(DT)
		t += DT
		m.cam.snap(spot)
		for x in m.hunters:
			x.render(DT, 1.0)
		await main_node.get_tree().process_frame
		if t >= float(marks[0]) - DT * 0.5:
			marks.pop_front()
			frames.append(_crop(main_node, spot))
	var out := Image.create(CROP.x * frames.size(), CROP.y, false, (frames[0] as Image).get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(Vector2i.ZERO, (frames[i] as Image).get_size()), Vector2i(i * CROP.x, 0))
	return out

func _crop(main_node: Node, at: Vector3) -> Image:
	var img := main_node.get_viewport().get_texture().get_image()
	var c := main_node.get_viewport().get_camera_3d().unproject_position(at + Vector3(0, 0.6, 0))
	var rg := Rect2i(Vector2i(int(c.x) - CROP.x / 2, int(c.y) - CROP.y / 2), CROP)
	var crop := img.get_region(rg.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img = Image.create(CROP.x, CROP.y, false, crop.get_format())
	img.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i.ZERO)
	return img
