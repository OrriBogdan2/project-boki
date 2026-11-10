extends RefCounted
## --mob-cap-check: the monster activity cap per graphics preset (MobCap). For every preset: 40 idle
## monsters around the local player, so the nearest `mob_cap` of them stay awake and the rest sleep (they
## don't move, don't despawn and keep their hp); one with a target is never put to sleep; a far one is
## never counted; hurting a sleeper wakes it; online play and bot runs use the High cap; and a preset
## with a higher cap wakes them again. The caps must also grow with the preset.

var bad := 0
const DT := 1.0 / 60.0
const CROWD := 40            # monsters placed around the player
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}

func ok(cond: bool, what: String) -> void:
	print("MOBCAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var tree := main.get_tree()
	var last := 0
	for preset in Settings.QUALITY_ORDER:
		var cap := int(Settings.QUALITY[preset]["mob_cap"])
		ok(cap > last, "%s caps at %d, more than the preset below" % [preset, cap])
		last = cap
		Settings.v["quality"] = preset
		var m := Match.new()
		main.add_child(m)
		await m.start(OPTS.duplicate())
		m.set_process(false)
		for i in 5: await tree.process_frame
		_preset(m, String(preset), cap)
		m.queue_free()
		await tree.process_frame
	Settings.v["quality"] = "auto"
	print("MOBCAP DONE, failures: %d" % bad)
	tree.quit()

func _crowd(m: Match) -> Array:
	for mb in m.mobs.duplicate():
		m.mobs.erase(mb)
		mb.queue_free()
	var made: Array = []
	for i in CROWD:
		var a := TAU * i / CROWD
		var at := m.player.pos + Vector3(cos(a), 0, sin(a)) * (6.0 + i)
		var mb := m.spawn_mob("skitter", at)
		mb.pos = Vector3(at.x, m.player.pos.y, at.z)
		made.append(mb)
	return made

func _awake_near(m: Match) -> int:
	return m.mobs.filter(func(mb: Mob) -> bool:
		return not mb.dead and not mb.capped and mb.flat_dist(m.player) <= MobCap.RADIUS).size()

func _preset(m: Match, preset: String, cap: int) -> void:
	var made := _crowd(m)
	var hp0: Array = made.map(func(mb: Mob) -> float: return mb.hp)
	m.mob_cap.tick(1.0)
	var inside := made.filter(func(mb: Mob) -> bool: return mb.flat_dist(m.player) <= MobCap.RADIUS)
	ok(m.mob_cap.limit() == cap, "%s: the limit is its own cap (%d)" % [preset, cap])
	ok(_awake_near(m) == cap and m.mob_cap.sleeping() == inside.size() - cap,
		"%s: %d awake of %d near, the rest asleep" % [preset, cap, inside.size()])
	var nearest := made.filter(func(mb: Mob) -> bool: return mb.flat_dist(m.player) <= MobCap.RADIUS)
	nearest.sort_custom(func(a: Mob, b: Mob) -> bool: return a.flat_dist(m.player) < b.flat_dist(m.player))
	ok(not nearest[0].capped and nearest[cap].capped, "%s: the nearest stay awake, the next one sleeps" % preset)
	var far: Mob = m.spawn_mob("skitter", m.player.pos + Vector3(MobCap.RADIUS + 30.0, 0, 0))
	m.mob_cap.tick(1.0)
	ok(not far.capped, "%s: one beyond the radius is not counted or capped" % preset)
	# asleep means still: no wandering while capped
	var sleeper: Mob = nearest[cap]
	var at := sleeper.pos
	for i in 120:
		for mb in m.mobs: mb.sim(DT)
	ok(sleeper.capped and sleeper.pos.is_equal_approx(at), "%s: a capped monster does not move" % preset)
	var held := made.filter(func(mb: Mob) -> bool: return mb.capped)
	ok(held.all(func(mb: Mob) -> bool: return is_instance_valid(mb) and not mb.dead and m.mobs.has(mb)),
		"%s: no sleeping monster despawned or died" % preset)
	ok(held.all(func(mb: Mob) -> bool: return mb.hp == hp0[made.find(mb)]), "%s: sleepers keep their hp" % preset)
	# a target keeps one awake, and hurting a sleeper wakes it
	var angry: Mob = nearest[cap + 1]
	angry.tgt = m.player
	angry.st = "chase"
	m.mob_cap.tick(1.0)
	ok(not angry.capped, "%s: a monster with a target is never put to sleep" % preset)
	m.player.hp = m.player.max_hp
	sleeper.hurt(1.0, m.player)
	m.mob_cap.tick(1.0)
	ok(sleeper.tgt == m.player and not sleeper.capped, "%s: a hit sleeper wakes with a target" % preset)
	# online matches and bot runs hold the High cap
	var high := int(Settings.QUALITY["high"]["mob_cap"])
	m.opts["autoplay"] = true
	ok(m.mob_cap.limit() == high, "%s: a bot run uses the High cap (%d)" % [preset, high])
	m.opts.erase("autoplay")
	Settings.v["quality"] = "ultra"
	m.mob_cap.tick(1.0)
	var ultra := int(Settings.QUALITY["ultra"]["mob_cap"])
	ok(m.mob_cap.sleeping() <= maxi(inside.size() - ultra, 0), "%s: a higher cap wakes them again" % preset)
	Settings.v["quality"] = preset
