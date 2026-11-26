extends RefCounted
## --bot-path-check: the bots' tile path search (Bot._grid_path_in) finds the same path as the plain
## breadth-first search it replaced (a Dictionary of tiles and an Array queue), on a real map: PAIRS pairs of
## spawn spots, each in a tight and a wide window, and no hunter (the hazard test is the terrain-hazard check's).
## Never touches the save.

const PAIRS := 40  # spawn pairs searched on the 3x3 seeded map
const REACH_M := 40.0  # m: how far the second spot lies from the first, each way
const SLACK := 8  # tiles of window round the trip (Bot.PATH_SLACK)
const STEPS := 4000  # tiles one search may open (Bot.PATH_STEPS)

var bad := 0


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 3, "tier": 0, "seed": 3})
	m.set_process(false)
	await main.get_tree().process_frame
	var spots: Array = m.world.spawns
	_ok(spots.size() > 4, "the map has spawn spots to search between (%d)" % spots.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var found := 0
	for i in PAIRS:
		var a: Vector3 = spots[rng.randi() % spots.size()]
		var off := Vector3(rng.randf_range(-REACH_M, REACH_M), 0.0, rng.randf_range(-REACH_M, REACH_M))
		var b: Vector3 = m.world.free_spot_near(a + off, [], 1.0, 0.4, 10.0)      # a walkable spot on its island
		var at := Vector2i(int(floor(a.x)), int(floor(a.z)))
		var to := Vector2i(int(floor(b.x)), int(floor(b.z)))
		var slack := SLACK if i % 2 == 0 else Bot.PATH_SLACK_RING
		var steps := STEPS if i % 2 == 0 else Bot.PATH_STEPS_RING
		var got: Array = m.bot_brain._grid_path_in(m, at, to, null, slack, INF, steps)
		var want := _reference(m.world, at, to, slack, steps)
		found += int(not want.is_empty())
		var what := "pair %d (%s to %s, slack %d): %d tiles, as the plain search" % [i, at, to, slack, want.size()]
		_ok(got == want, what)
	_ok(found > PAIRS / 4, "a good share of the pairs have a path (%d of %d)" % [found, PAIRS])
	print("BOTPATH DONE, failures: %d" % bad)
	main.get_tree().quit()


## The search as it was: first in first out over walkable tiles whose step is under 1.7 m, east west south north.
func _reference(w: World, a: Vector2i, b: Vector2i, slack: int, max_steps: int) -> Array:
	var lo := Vector2i(mini(a.x, b.x) - slack, mini(a.y, b.y) - slack)
	var hi := Vector2i(maxi(a.x, b.x) + slack, maxi(a.y, b.y) + slack)
	var prev := {a: a}
	var q: Array = [a]
	var steps := 0
	var hit := false
	while q.size() > 0 and steps < max_steps:
		steps += 1
		var cur: Vector2i = q.pop_front()
		if cur == b or (absi(cur.x - b.x) <= 1 and absi(cur.y - b.y) <= 1 and w.is_block(b.x + 0.5, b.y + 0.5)):
			b = cur
			hit = true
			break
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + dv
			if prev.has(nx) or nx.x < lo.x or nx.y < lo.y or nx.x > hi.x or nx.y > hi.y or not w.inb(nx.x, nx.y):
				continue
			if w.kind[w.idx(nx.x, nx.y)] != World.T_GROUND:
				continue
			if absf(w.ground_at(nx.x + 0.5, nx.y + 0.5) - w.ground_at(cur.x + 0.5, cur.y + 0.5)) > 1.7:
				continue
			prev[nx] = cur
			q.append(nx)
	if not hit:
		return []
	var out: Array = []
	var c := b
	while c != a:
		out.push_front(Vector2(c.x + 0.5, c.y + 0.5))
		c = prev[c]
	return out


func _ok(cond: bool, what: String) -> void:
	print("%s  %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1
