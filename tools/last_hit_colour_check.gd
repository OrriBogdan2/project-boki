extends RefCounted
## --last-hit-colour-check: a monster's death flashes in the colour of the side that got the kill.
##   1. a kill by you, your Boki's owner's squad-mate or a rival makes one flash: your squad's colour or the
##      rival colour of the picked Colour vision palette (SideColor), never the monster's own
##   2. a lair boss's death (Juice.boss_dead) flashes the same way, once
##   3. a death with no Hunter behind it (a fall, the Blight) keeps the monster's own colour
## Runs with a temporary XDG_DATA_HOME (it writes user://settings.cfg). Never touches the save.

var bad := 0

func ok(what: String, cond: bool, extra := "") -> void:
	print("LASTHIT %s %s %s" % ["ok  " if cond else "FAIL", what, extra])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var me: Hunter = m.player
	var mate: Hunter = null
	var foe: Hunter = null
	for h in m.hunters:
		if h != me and h.team == me.team: mate = h
		elif h.team != me.team: foe = h
	for id in SideColor.ORDER:
		Settings.v[SideColor.KEY] = id
		var p: Dictionary = SideColor.PALETTES[id]
		for boss in [false, true]:
			var tag := "[%s%s] " % [id, " boss" if boss else ""]
			var by_you := _kill(m, me.pos, me, boss)
			var by_mate := _kill(m, me.pos, mate, boss)
			var by_foe := _kill(m, me.pos, foe, boss)
			ok(tag + "your kill: one flash, squad colour", by_you.size() == 1 and _same(by_you[0], p["ally"]))
			ok(tag + "your mate's kill: one flash, squad colour", by_mate.size() == 1 and _same(by_mate[0], p["ally"]))
			ok(tag + "a rival's kill: one flash, rival colour", by_foe.size() == 1 and _same(by_foe[0], p["foe"]))
			ok(tag + "the two sides differ", by_you.size() == 1 and by_foe.size() == 1 and not _same(by_you[0], by_foe[0]))
	var own := _kill(m, me.pos, null, false)
	ok("no Hunter behind it: one flash in the monster's own colour", own.size() == 1 and not _same(own[0], SideColor.ally()) and not _same(own[0], SideColor.foe()))
	print("LASTHIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _same(a: Color, b: Color) -> bool:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.02

## Kills a fresh monster beside `at` for `by` (through the path that pays the kill) and returns the colours of the flashes it made.
func _kill(m: Match, at: Vector3, by: Hunter, boss: bool) -> Array:
	var mb := m.spawn_mob("skitter", at + Vector3(2, 0, 0))
	m.fx.flashes.clear()
	if boss:
		Juice.boss_dead(m, mb, by)      # (a lair boss's death; Boss needs a lair, so the bare Juice call stands in)
	else:
		mb.hp = 0.0
		mb._on_zero(by, {})
	var cols: Array = []
	for f in m.fx.flashes:
		cols.append(((f["node"] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("color"))
	return cols
