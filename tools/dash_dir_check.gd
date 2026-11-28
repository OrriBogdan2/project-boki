extends RefCounted
## --dash-dir-check: a plain dash follows the "Dash toward the cursor" setting for every hunter. With it off
## (the default) holding A with the cursor on the right dashes left, on the ground and in the air; with it on
## you dash at the cursor. Left out: hunters whose Shift is aimed movement in their doc row (Mage's Wirerun
## direction from the cursor, Motley's Lantern Trade, Tarek's Rock Hop). Lace's roll follows WASD
## (docs/heroes/archer.md, owner default), so she is checked. Never touches the save.

const AIMED := ["mage", "ostra", "dolm"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DASHDIR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `cls` on a flat, empty patch of ground.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	var world: World = m.world
	var cx := int(floor(hunter.pos.x))
	var cz := int(floor(hunter.pos.z))
	var home_i: int = world.idx(cx, cz)
	var level: int = int(world.level[home_i]) if world.kind[home_i] != World.T_VOID else 0
	for dz in range(-14, 15):
		for dx in range(-14, 15):
			if not world.inb(cx + dx, cz + dz):
				continue
			var i: int = world.idx(cx + dx, cz + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = level
			world.island[i] = world.island[home_i]
			world.walls.erase(i)
			world.props.erase(i)
			world.stairs.erase(i)
	hunter.teleport(Vector3(cx + 0.5, level * World.LEVEL, cz + 0.5))
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(40, 0, 40))
	for i in 20:
		m.step(Match.DT)
	return m

## Holds `move` while the cursor is at `aim_off`, dashes (on the ground, or `high` metres up and still in the
## air), and returns the way the dash set off in metres it would cover (some dashes slide on only while Shift is
## held, so the kits that steer or drive the dash after a crouch are read from their own state).
func _dash_vec(m: Match, move: Vector2, aim_off: Vector3, high := 0.0) -> Vector2:
	var hunter: Hunter = m.player
	if high > 0.0:
		hunter.teleport(hunter.pos + Vector3(0, high, 0))
		m.step(Match.DT)
		assert(not hunter.grounded, "%s should be in the air" % hunter.arch)
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.inp["move"] = move
	hunter.inp["aim"] = hunter.pos + aim_off
	hunter.do_dash()
	if hunter.ak is RimewrightKit:
		return (hunter.ak as RimewrightKit).rinkrun["dir"] as Vector2 * 3.0     # (its Rink Run steers along this)
	if hunter.ak is JuggernautKit:
		return (hunter.ak as JuggernautKit).rampage_dir * 3.0     # (it drives this way after its crouch)
	return hunter.roll_dir * hunter.roll_speed * hunter.roll_t

func run(main: Node) -> void:
	Save.no_write = true
	var was = Settings.get_v("dash_to_cursor")
	for cls in Arch.ORDER:
		if cls in AIMED:
			continue
		for high in [0.0, 3.0]:
			var where := "in the air" if high > 0.0 else "on the ground"
			Settings.set_v("dash_to_cursor", false, false)
			var m := _match(main, cls)
			var along := _dash_vec(m, Vector2.LEFT, Vector3(8, 0.9, 0), high).x
			ok(along < -1.0, "%s: setting off, A with the cursor right dashes left %s (%.1fm)" % [cls, where, along])
			m.queue_free()
			Settings.set_v("dash_to_cursor", true, false)
			m = _match(main, cls)
			along = _dash_vec(m, Vector2.LEFT, Vector3(8, 0.9, 0), high).x
			ok(along > 1.0, "%s: setting on, the dash goes to the cursor %s (%.1fm)" % [cls, where, along])
			m.queue_free()
			await main.get_tree().process_frame
	Settings.set_v("dash_to_cursor", was, false)
	print("DASHDIR DONE, failures: %d" % bad)
	main.get_tree().quit()
