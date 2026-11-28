extends RefCounted
## --stairs-check: walking up and down a flight of stairs is one smooth walk, never a string of hops. On every map
## with stairs (the generated training islands, the Hollow Crown, Skyreach, the practice arena; the tutorial has
## none) the player's Hunter, then a heavy one that isn't local (moved the way bots are, drawn interpolated), runs
## across real flights both ways and must: stay on the ground the whole way (no hop or fall animation), never
## pop up or down in one step by more than the slope gives, keep an even pace (no doubled steps), and reach the
## far end. Prints STAIRS lines and "STAIRS DONE, N checks, failures: M".

const DT := 1.0 / 60.0
const FLIGHTS := 3  # flights walked per map
const RUN_IN := 1  # flat tiles walked before and after the flight
const TIME_S := 4.0  # s allowed for one crossing (a run crosses ~6 tiles in ~1.1 s)
const POP_SLACK := 0.03  # m a drawn step may rise or fall beyond the slope's own rise over that step
const PACE_SLACK := 1.35  # a step may cover at most this much more ground than a run step
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
	m.start(o)
	m.set_process(false)
	var runs := flights(m.world)
	ok("%s: has flights to walk" % mp["name"], runs.size() > 0, "%d stair tiles" % m.world.stairs.size())
	var spawn := m.player.pos
	var b_v: Hunter = m.make_hunter("B", 3, "heavy", "Walker", "idle", {}, spawn + Vector3(0, 0, 1), {"arch": "none"})
	for p in [m.player, b_v]:
		for fl in runs:
			_cross(m, p, "%s %s %s" % [mp["name"], p.cls, fl["at"]], fl["a"], fl["b"])
			_cross(m, p, "%s %s %s down" % [mp["name"], p.cls, fl["at"]], fl["b"], fl["a"])
		p.teleport(spawn)  # (out of the next walker's way)
	m.queue_free()
	await main.get_tree().process_frame


## Up to FLIGHTS walks [a, b] (tile centres, a at the foot) straight up a flight's middle, with RUN_IN clear flat
## tiles at each end, so the walk meets nothing but the stairs.
func flights(w_v: World) -> Array:
	var out: Array = []
	var seen := {}
	for i in w_v.stairs:
		var d: Vector2i = w_v.stairs[i]
		var c := Vector2i(i % w_v.w, i / w_v.w)
		var side := Vector2i(d.y, d.x)
		if seen.has(i):
			continue
		var lo := c
		while w_v.stairs.get(w_v.idx(lo.x - d.x, lo.y - d.y)) == d:
			lo -= d
		var hi := c
		while w_v.stairs.get(w_v.idx(hi.x + d.x, hi.y + d.y)) == d:
			hi += d
		var a := lo - d * (RUN_IN + 1)
		var b := hi + d * (RUN_IN + 1)
		var clear := true
		for q in _line(a, lo - d) + _line(hi + d, b):
			var j := w_v.idx(q.x, q.y)
			var flat := w_v.inb(q.x, q.y) and w_v.kind[j] == World.T_GROUND and not w_v.stairs.has(j)
			clear = clear and flat and not w_v.props.has(j)
		for k in range(-World.STAIR_MAX_W, World.STAIR_MAX_W + 1):  # the whole flight: one walk per flight
			for q in _line(lo + side * k, hi + side * k):
				seen[w_v.idx(q.x, q.y)] = true
		var foot := Vector3(a.x + 0.5, w_v.ground_at(a.x + 0.5, a.y + 0.5), a.y + 0.5)
		var head := Vector3(b.x + 0.5, w_v.ground_at(b.x + 0.5, b.y + 0.5), b.y + 0.5)
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


func _cross(m: Match, p: Hunter, what: String, a: Vector3, b: Vector3) -> void:
	p.teleport(a)
	p.vel = Vector3.ZERO
	p.grounded = true
	p.drawn_y = INF  # (drawn at once from the first render)
	var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
	var t := 0.0
	var air := 0
	var pop := 0.0
	var pace := 0.0
	var run_step := 0.0
	p.render(DT, 1.0)
	var drawn := p.drawn_y
	while t < TIME_S and Vector2(b.x - p.pos.x, b.z - p.pos.z).dot(dir) > 0.3:
		p.inp["move"] = dir
		p.inp["aim"] = p.pos + Vector3(dir.x, 0, dir.y) * 6.0
		var p0 := p.pos
		var g0: float = m.world.ground_at(p0.x, p0.z)
		for mb in m.mobs:
			mb.queue_free()  # (only the stairs in the way)
		m.mobs.clear()
		m.step(DT)
		p.render(DT, 1.0)
		t += DT
		if not p.grounded:
			air += 1
		var flat := Vector2(p.pos.x - p0.x, p.pos.z - p0.z).length()
		run_step = maxf(run_step, flat) if t < 0.5 else run_step
		if t >= 0.5:
			pace = maxf(pace, flat / maxf(run_step, 0.001))
		var rise := absf(m.world.ground_at(p.pos.x, p.pos.z) - g0)
		var slope := maxf(rise, StepSmooth.cfg.step_max_speed * DT)  # (or the ease's own cap)
		pop = maxf(pop, absf(p.drawn_y - drawn) - slope)  # (drawn_y: where StepSmooth draws the model)
		drawn = p.drawn_y
	p.inp["move"] = Vector2.ZERO
	var info := (
		"%.2fs, %d airborne steps, pop %.3fm, pace x%.2f, end y %.2f of %.2f" % [t, air, pop, pace, p.pos.y, b.y]
	)
	ok("%s: on the ground the whole way" % what, air == 0, info)
	ok("%s: no vertical pop" % what, pop <= POP_SLACK, info)
	ok("%s: an even pace" % what, pace <= PACE_SLACK, info)
	ok("%s: gets there" % what, t < TIME_S and absf(p.pos.y - b.y) < 0.1, info)
