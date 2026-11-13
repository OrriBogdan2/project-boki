extends RefCounted
## --mob-notice-check: the notice cue (MobNotice). A camp of every kind sits idle; a crouched Hunter walks
## past outside its sight and nothing wakes or cues; then the Hunter walks into the camp, every monster
## turns to chase and the camp makes exactly one cue. A second camp far off still cues on its own.
## Never touches the save.

const KINDS := ["skitter", "spitter", "brute", "warden", "bomber", "sentinel", "glimmer"]
const PASS_OFF := 13.0      # m beside the camp: past idle sight (7.5) plus a monster's wander (4.8)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MOBNOTICE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var far := m.world.random_ground()
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(far)
	var c := _flat_spot(m, far)
	ok(_level(m, c), "setup: a level camp spot with ground under the pass")
	var camp: Array = []
	for k in KINDS:
		camp.append(m.spawn_mob(k, c + Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.8, 1.8))))
	ok(KINDS.all(func(k): return MobNotice.CUE.has(k)), "every kind has a cue")
	# a crouched pass beside the camp, out of sight: nobody wakes, nobody cues
	P.dropping = false
	P.gliding = false
	P.crouch = true
	for i in 360:
		_put(m, P, c + Vector3(-12.0 + i * 24.0 / 360.0, 0, PASS_OFF))
		m.step(Match.DT)
	ok(P.targetable(), "the Hunter is still up and in plain view after the pass")
	ok(camp.all(func(mb): return mb.st == "idle"), "a crouched pass out of sight leaves the camp idle")
	ok(_cued(camp) == 0, "...and plays no notice cue (%d)" % _cued(camp))
	# into the camp: all seven wake, one cue
	P.crouch = false
	Sfx.last_played.clear()
	for i in 600:
		_put(m, P, c + Vector3(2.0, 0, 0))
		m.step(Match.DT)
		if camp.all(func(mb): return mb.st != "idle"):
			break
	var states: Array = camp.map(func(mb): return "%s %s" % [mb.mkind, mb.st])
	ok(camp.all(func(mb): return mb.st != "idle"), "walking into the camp wakes all seven (%s)" % [states])
	ok(_cued(camp) == 1, "...and the camp makes one notice cue, not seven (%d)" % _cued(camp))
	var cued: Array = camp.filter(func(mb): return mb.noticed_at > -INF)
	var heard := cued.size() == 1 and Sfx.last_played.has("v_" + cued[0].mkind)
	ok(heard, "the cue is that monster's voice, heard where you stand")
	# another camp far off is its own camp
	var c2 := c + Vector3(40.0, 0, 0)
	var lone: Mob = m.spawn_mob("brute", c2)
	lone.st = "chase"
	ok(MobNotice.woke(lone) and not MobNotice.woke(lone), "a second camp cues once on its own")
	print("MOBNOTICE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _cued(camp: Array) -> int:
	return camp.filter(func(mb): return mb.noticed_at > -INF).size()

func _put(m: Match, P: Hunter, at: Vector3) -> void:
	P.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	Sfx.listener = P.pos       # (the camera that moves it is off with the match's process)

## A ground spot away from the other hunters (who stand at `far`) with solid level ground under the pass.
func _flat_spot(m: Match, far: Vector3) -> Vector3:
	for i in 400:
		var p := m.world.random_ground()
		if p.distance_to(far) > 60.0 and _level(m, p):
			return p
	return m.world.random_ground()

func _level(m: Match, c: Vector3) -> bool:
	for x in range(-14, 15, 2):
		for z in range(-4, 16, 2):
			var q := c + Vector3(x, 0, z)
			if m.world.is_void(q.x, q.z) or m.world.is_block(q.x, q.z) or absf(m.world.ground_at(q.x, q.z) - c.y) > 1.0:
				return false
	return true
