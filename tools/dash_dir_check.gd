extends RefCounted
## --dash-dir-check: a plain dash follows the "Dash toward the cursor" setting for every hunter. With it off
## (the default) you dash the way you're moving even while aiming the other way; with it on you dash at the
## cursor. Hunters whose Shift is aimed movement by design (Archer's grapple, Mage's blink, Motley's swap,
## Tarek's Rock Hop to the cursor and Bulwark's shield charge) are left out. Never touches the save.

const AIMED := ["archer", "mage", "ostra", "dolm"]

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

## Moves "back" (+z) while aiming "forward" (-z), dashes, and returns which way the dash set off along z
## (the sign of roll_dir, in metres it would cover: some dashes slide on only while Shift is held).
func _dash_back(m: Match) -> float:
	var hunter: Hunter = m.player
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.inp["move"] = Vector2(0, 1)
	hunter.inp["aim"] = hunter.pos + Vector3(0, 0.9, -8)
	hunter.do_dash()
	if hunter.ak is RimewrightKit:
		return ((hunter.ak as RimewrightKit).rinkrun["dir"] as Vector2).y * 3.0     # (its Rink Run steers along this)
	if hunter.ak is JuggernautKit:
		return (hunter.ak as JuggernautKit).rampage_dir.y * 3.0     # (it drives this way after its crouch)
	return hunter.roll_dir.y * hunter.roll_speed * hunter.roll_t

func run(main: Node) -> void:
	Save.no_write = true
	var was = Settings.get_v("dash_to_cursor")
	for cls in Arch.ORDER:
		if cls in AIMED:
			continue
		Settings.set_v("dash_to_cursor", false, false)
		var m := _match(main, cls)
		var along := _dash_back(m)
		ok(along > 1.0, "%s: setting off, moving back while aiming forward dashes back (%.1fm)" % [cls, along])
		m.queue_free()
		Settings.set_v("dash_to_cursor", true, false)
		m = _match(main, cls)
		along = _dash_back(m)
		ok(along < -1.0, "%s: setting on, the dash goes to the cursor (%.1fm)" % [cls, along])
		m.queue_free()
		await main.get_tree().process_frame
	Settings.set_v("dash_to_cursor", was, false)
	print("DASHDIR DONE, failures: %d" % bad)
	main.get_tree().quit()
