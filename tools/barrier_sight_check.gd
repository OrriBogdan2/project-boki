extends RefCounted
## --barrier-sight-check: a barrier never makes the Hunter behind it vanish. Two rivals
## 7 m apart; the far one raises each barrier between them: a Boki's Prism Wall (Frigatee), a Boki's Mass
## Guard (Peb), the Barrier Glove, Neve's Rink Wall. The near side (the player, and the bot team the other way
## round) still sees the far Hunter, and a placed barrier still blocks the shot line. Tenzo's rock still hides
## them, like terrain. With --shots-dir=<dir> (under a renderer) it writes the player's view of a rival bot
## behind its Boki's Prism Wall. Never touches the save.

const DT := 1.0 / 60.0
const GAP := 7.0  # m between the two Hunters: past Match.NEAR_SENSE, well inside VIEW_RANGE
const SETTLE_S := 0.6  # s a barrier gets to go up before it is measured
const EYE := 0.95  # m, the shot line's height (Bot.can_hit)

var bad := 0
var _dir := ""


func ok(cond: bool, what: String) -> void:
	print("BARRIERSIGHT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Settings.v["boki_wisps"] = false
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			_dir = String(a).substr(12)
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	await m.start(
		{
			"teams": 2,
			"squad": 1,
			"tier": 0,
			"length": 1e9,
			"seed": 4242,
			"no_drop": true,
			"arch": "rimewright",
			"cls": Arch.weight("rimewright"),
			"weapon": Arch.signature("rimewright")
		}
	)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var pl: Hunter = m.player
	pl.ctrl = "idle"
	pl.unlock_all()
	var bot: Hunter = null
	for o in m.hunters:
		if o != pl:
			o.ctrl = "idle"
			bot = o
	ok(_place(m, pl, bot), "found open flat ground where the two see each other")
	var glove: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/gear/barrier.json"))["effects"]
	var sources := {
		"Boki Prism Wall": func(by: Hunter, mid: Vector3, _d: Vector2): _boki(m, by, "floenatee", "k1", mid),
		"Boki Mass Guard": func(by: Hunter, mid: Vector3, _d: Vector2): _boki(m, by, "pebbit", "k2", mid),
		"Barrier Glove": func(by: Hunter, mid: Vector3, _d: Vector2): Effects.run(glove, by, {"aim": mid}),
		"Neve's Rink Wall": func(by: Hunter, _mid: Vector3, d: Vector2): (by.ak as RimewrightKit)._raise_wall(d, 0.0),
		"Tenzo's rock":
		func(by: Hunter, mid: Vector3, d: Vector2): HeroZones.rock(m, by, mid, d, "bsc", 3.0, 5.0, 300.0, false),
	}
	for src in sources:
		for side in [[bot, pl, "the player"], [pl, bot, "the bot team"]]:
			var far: Hunter = side[0]
			var near: Hunter = side[1]
			if src == "Neve's Rink Wall" and not far.ak is RimewrightKit:
				continue
			var mid := (far.pos + near.pos) * 0.5
			(sources[src] as Callable).call(
				far, mid, Vector2(near.pos.x - far.pos.x, near.pos.z - far.pos.z).normalized()
			)
			await _settle(main, m, pl, SETTLE_S)
			var wall := _between(m, far, near)
			var tag := "%s raised by %s's rival" % [src, side[2]]
			ok(not wall.is_empty(), "%s: it stands between them" % tag)
			var seen := m.can_see(near.team, far)
			if src == "Tenzo's rock":
				ok(not seen, "%s: a rock still hides like terrain" % tag)
			else:
				ok(seen, "%s: %s still sees the Hunter behind it" % [tag, side[2]])
				if not wall.is_empty() and not wall["follow"]:
					ok(not m.world.los(near.pos, far.pos, near.pos.y + EYE), "%s: it still blocks the shot line" % tag)
			if src == "Boki Prism Wall" and far == bot:
				await _shot(main, m, pl, bot, "prism_wall")
			_clear(m)
			await _settle(main, m, pl, 0.2)
			ok(m.verbs.walls.is_empty(), "%s: gone before the next one" % tag)
	print("BARRIERSIGHT done, %d failures" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Stands the bot GAP m from the player on open, flat ground (both ways clear, no grass), facing each other.
func _place(m: Match, pl: Hunter, bot: Hunter) -> bool:
	for i in 16:
		var d := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var at := pl.pos + Vector3(d.x, 0, d.y) * GAP
		var g: float = m.world.ground_at(at.x, at.z)
		if absf(g - pl.pos.y) > 0.1 or m.world.in_bush(at.x, at.z) or m.world.in_bush(pl.pos.x, pl.pos.z):
			continue
		bot.teleport(Vector3(at.x, g, at.z))
		_face(pl, bot)
		_face(bot, pl)
		if m.can_see(pl.team, bot) and m.can_see(bot.team, pl) and m.world.los(pl.pos, bot.pos, pl.pos.y + EYE):
			return true
	return false


func _face(h: Hunter, at: Hunter) -> void:
	h.inp["aim"] = at.pos + Vector3(0, 0.9, 0)
	h.face = atan2(h.pos.x - at.pos.x, h.pos.z - at.pos.z)  # (Hunter.aim_dir: -(sin, cos) of face)


## The barrier crossing the line between the two, or {}.
func _between(m: Match, a: Hunter, b: Hunter) -> Dictionary:
	for w in m.verbs.walls:
		var cut = Geometry2D.segment_intersects_segment(
			Vector2(a.pos.x, a.pos.z), Vector2(b.pos.x, b.pos.z), w["a"], w["b"]
		)
		if cut != null:
			return w
	return {}


func _boki(m: Match, by: Hunter, species: String, slot: String, at: Vector3) -> void:
	if by.kin:
		var o: Kin = by.kin
		o.dead = true
		o.visible = false
		by.kin = null
	var rec := Save.new_kin(species)
	rec["trust"] = 95.0
	var k := m.give_kin(by, rec)
	k.brain.think_t = 1e9
	k.runner.reset()
	k.teleport(by.pos + Vector3(0.6, 0, 0))
	k.state = "active"
	k.fly = {}
	k.settle = 0.0
	k.grounded = true
	k.use_ability(slot, at)


func _clear(m: Match) -> void:
	for w in m.verbs.walls:
		w["t"] = 0.0


func _settle(main: Node, m: Match, pl: Hunter, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		m.verbs.render(1.0)
		m.cam.snap(pl.pos)
		await main.get_tree().process_frame
		t += DT


## The player's whole view with the fog's verdict applied (Match._update_vision's own line).
func _shot(main: Node, m: Match, pl: Hunter, far: Hunter, label: String) -> void:
	if _dir == "":
		return
	far.unseen = not m.can_see(pl.team, far)
	far.render(DT, 1.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("barrier_sight_%s.png" % label))
	print("BARRIERSIGHT shot %s: rival %s" % [label, "HIDDEN" if far.unseen else "shown"])
	far.unseen = false
