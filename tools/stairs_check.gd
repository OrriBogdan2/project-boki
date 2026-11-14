extends RefCounted
## --stairs-check: walking up and down a flight of stairs is one smooth walk, never a string of hops. On every map
## with stairs (the generated training islands, the Hollow Crown, Skyreach, the practice arena; the tutorial has
## none) the player's Hunter, then a heavy one that isn't local (moved the way bots are, drawn interpolated), runs
## across real flights both ways and must: stay on the ground the whole way (no hop or fall animation), never
## pop up or down in one step by more than the slope gives, keep an even pace (no doubled steps), and reach the
## far end. Prints STAIRS lines and "STAIRS DONE, N checks, failures: M".

const DT := 1.0 / 60.0
const FLIGHTS := 3          # flights walked per map
const RUN_IN := 1           # flat tiles walked before and after the flight
const TIME_S := 4.0         # s allowed for one crossing (a run crosses ~6 tiles in ~1.1 s)
const POP_SLACK := 0.03     # m a drawn step may rise or fall beyond the slope's own rise over that step
const PACE_SLACK := 1.35    # a step may cover at most this much more ground than a run step
const MAPS := [
	{"name": "generated", "opts": {"training": true}},
	{"name": "hollowcrown", "opts": {}},
	{"name": "skyreach", "opts": {"map": "skyreach"}},
	{"name": "arena", "opts": {"training": true, "arena": true}},
]

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info: String) -> void:
	n += 1
	if not cond:
		fails += 1
	print("STAIRS %s: %s (%s)" % ["ok" if cond else "FAIL", label, info])

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for mp in MAPS:
		await _map(mp)
	print("STAIRS DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _map(mp: Dictionary) -> void:
	var m := Match.new()
	main.add_child(m)
	var o := {"teams": 1, "squad": 1, "tier": 0, "seed": 4242, "no_drop": true, "length": 1e9}
	o.merge(mp["opts"], true)
	await m.start(o)
	m.set_process(false)
	var runs := flights(m.world)
	ok("%s: has flights to walk" % mp["name"], runs.size() > 0, "%d stair tiles" % m.world.stairs.size())
	var spawn := m.player.pos
	var B: Hunter = m.make_hunter("B", 3, "heavy", "Walker", "idle", {}, spawn + Vector3(0, 0, 1), {"arch": "none"})
	for P in [m.player, B]:
		for fl in runs:
			await _cross(m, P, "%s %s %s" % [mp["name"], P.cls, fl["at"]], fl["a"], fl["b"])
			await _cross(m, P, "%s %s %s down" % [mp["name"], P.cls, fl["at"]], fl["b"], fl["a"])
		P.teleport(spawn)       # (out of the next walker's way)
	m.queue_free()
	await main.get_tree().process_frame

## Up to FLIGHTS walks [a, b] (tile centres, a at the foot) straight up a flight's middle, with RUN_IN clear flat
## tiles at each end, so the walk meets nothing but the stairs.
func flights(W: World) -> Array:
	var out: Array = []
	var seen := {}
	for i in W.stairs:
		var d: Vector2i = W.stairs[i]
		var c := Vector2i(i % W.w, i / W.w)
		var side := Vector2i(d.y, d.x)
		if seen.has(i):
			continue
		var lo := c
		while W.stairs.get(W.idx(lo.x - d.x, lo.y - d.y)) == d: lo -= d
		var hi := c
		while W.stairs.get(W.idx(hi.x + d.x, hi.y + d.y)) == d: hi += d
		var a := lo - d * (RUN_IN + 1)
		var b := hi + d * (RUN_IN + 1)
		var clear := true
		for q in _line(a, lo - d) + _line(hi + d, b):
			var j := W.idx(q.x, q.y)
			var flat := W.inb(q.x, q.y) and W.kind[j] == World.T_GROUND and not W.stairs.has(j)
			clear = clear and flat and not W.props.has(j)
		for k in range(-World.STAIR_MAX_W, World.STAIR_MAX_W + 1):      # the whole flight: one walk per flight
			for q in _line(lo + side * k, hi + side * k):
				seen[W.idx(q.x, q.y)] = true
		var foot := Vector3(a.x + 0.5, W.ground_at(a.x + 0.5, a.y + 0.5), a.y + 0.5)
		var head := Vector3(b.x + 0.5, W.ground_at(b.x + 0.5, b.y + 0.5), b.y + 0.5)
		if clear and absf(head.y - foot.y) > World.STEP:
			out.append({"at": "(%d,%d)" % [c.x, c.y], "a": foot, "b": head})
			if out.size() >= FLIGHTS:
				break
	return out

func _line(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = [a]
	var d := (b - a).sign()
	while a != b:
		a += d
		out.append(a)
	return out

func _cross(m: Match, P: Hunter, what: String, a: Vector3, b: Vector3) -> void:
	P.teleport(a)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.drawn_y = INF      # (StepSmooth: a teleport is drawn at once)
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	var t := 0.0
	var air := 0
	var pop := 0.0
	var pace := 0.0
	var run_step := 0.0
	P.render(DT, 1.0)
	var drawn := P.position.y
	var was := 0.0      # m the drawn body moved on the step before
	while t < TIME_S and Vector2(b.x - P.pos.x, b.z - P.pos.z).dot(dir) > 0.3:
		P.inp["move"] = dir
		P.inp["aim"] = P.pos + Vector3(dir.x, 0, dir.y) * 6.0
		var p0 := P.pos
		var g0: float = m.world.ground_at(p0.x, p0.z)
		for mb in m.mobs: mb.queue_free()      # (only the stairs in the way)
		m.mobs.clear()
		m.step(DT)
		P.render(DT, 1.0)
		t += DT
		if not P.grounded:
			air += 1
		var flat := Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length()
		run_step = maxf(run_step, flat) if t < 0.5 else run_step
		if t >= 0.5:
			pace = maxf(pace, flat / maxf(run_step, 0.001))
		var slope := absf(m.world.ground_at(P.pos.x, P.pos.z) - g0)
		# the drawn height (StepSmooth): a pop is a step beyond both the ground's rise and the drawn body's
		# last step, so its ease still finishing on the flat at the top or bottom is not one
		var moved := absf(P.position.y - drawn)
		pop = maxf(pop, moved - maxf(slope, was))
		was = moved
		drawn = P.position.y
	P.inp["move"] = Vector2.ZERO
	var info := "%.2fs, %d airborne steps, pop %.3fm, pace x%.2f, end y %.2f of %.2f" % [
		t, air, pop, pace, P.pos.y, b.y]
	ok("%s: on the ground the whole way" % what, air == 0, info)
	ok("%s: no vertical pop" % what, pop <= POP_SLACK, info)
	ok("%s: an even pace" % what, pace <= PACE_SLACK, info)
	ok("%s: gets there" % what, t < TIME_S and absf(P.pos.y - b.y) < 0.1, info)
