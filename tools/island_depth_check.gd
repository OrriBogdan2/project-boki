extends RefCounted
## --island-depth-check (the deep islands of IslandDepth): every sky island (a match map,
## the Training Area, the farm) reaches far down below its top as tall tapered rock, its collision
## follows that rock (open air under it), and a hunter gliding in under an island steers into its
## side and climbs up onto the top, on three different islands; at the farm too.

var bad := 0
var m: Match
var w: World
var h: Hunter
const DT := 1.0 / 60.0

func ok(cond: bool, what: String) -> void:
	print("IDCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var o := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "autoplay": true}
	_match(main, o, "match map", 3)
	_match(main, Match.arena_opts(), "Training Area", 1)
	await _farm(main)
	print("IDCHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

## The depth of every island on world ww: at the middle at least deep_min_m under the top, and
## never less than the tall outer wall at the coast.
func _depths(ww: World, where: String) -> void:
	var ud := ww.under_heights()
	var mid := {}
	var coast := INF
	var wall: float = IslandDepth.RIM + float(IslandDepth.T["cliff_m"]) - 0.4
	for i in ww.w * ww.h:
		if ww.kind[i] == World.T_VOID or ww.bridge.has(i): continue
		var d: float = ww.level[i] * World.LEVEL - ud[i]
		mid[ww.island[i]] = maxf(float(mid.get(ww.island[i], 0.0)), d)
		coast = minf(coast, d)
	var shallow := 0
	for k in mid:
		if float(mid[k]) < float(IslandDepth.T["deep_min_m"]): shallow += 1
	var deep: float = IslandDepth.T["deep_min_m"]
	ok(mid.size() > 0 and shallow == 0 and coast >= wall,
			"%s: %d islands, all at least %.0fm deep under the middle (%d shallow), "
			% [where, mid.size(), deep, shallow] + "the coast wall at least %.1fm (least %.1fm)" % [wall, coast])
	# collision: open air under the rock, a wall beside it
	var tried := 0
	var right := 0
	for i in range(0, ww.w * ww.h, 7):
		if ww.kind[i] != World.T_GROUND or ww.bridge.has(i): continue
		var x := i % ww.w + 0.5
		var z := i / ww.w + 0.5
		tried += 1
		var air := ww.occupy(x, z, 0.3, ud[i] - IslandDepth.HEAD - 0.3, false, true) == 0.0
		if air and ww.occupy(x, z, 0.3, ud[i] + 0.5, false, true) > 0.0:
			right += 1
	ok(tried > 0 and right == tried, "%s: under each tile's rock is open air, beside it a wall (%d of %d)"
			% [where, right, tried])

func _match(main: Node, o: Dictionary, where: String, want: int) -> void:
	m = Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	w = m.world
	h = m.hunters[0]
	h.set_arch("")
	for o2 in m.hunters:
		o2.ctrl = "idle"
	h.ctrl = "local"
	m.opts["god"] = true
	_depths(w, where)
	var done := {}
	var good := 0
	var tried := 0
	for e in _edges(w, 40):
		if done.has(e["isl"]) or done.size() >= want: continue
		done[e["isl"]] = true
		tried += 1
		if _glide_under(e, where): good += 1
	ok(tried == want and good == tried, "%s: glided in under %d islands' rims, steered into the side and climbed "
			% [where, want] + "onto the top %d of %d" % [good, tried])
	m.queue_free()

## Starts under rim e's rock, gliding in toward the island's middle; true when it ends
## up standing on the island's top having climbed (and never inside the rock).
func _glide_under(e: Dictionary, where: String) -> bool:
	var dir: Vector2 = e["dir"]
	var y0: float = e["rock"] - IslandDepth.HEAD - 0.4
	h.out = false
	h.downed = false
	h.hp = h.max_hp
	h.teleport(Vector3(e["ex"] - dir.x * 0.25, y0, e["ez"] - dir.y * 0.25))      # under the rim tile
	h.grounded = false
	h.vel = Vector3(-dir.x * 4.0, 0.0, -dir.y * 4.0)
	h.lfloat = {}
	h.pad = {}
	h.grap = {}
	h.grap_cd = 0.0
	h.mantle_cd = 0.0
	h.gliding = true
	h.glide_fuel = 1.0
	h.last_gy = e["top"]
	h.kb_t = -9.0
	h.inp["glide"] = true
	h.inp["jump"] = false
	h.inp["dash"] = false
	var t := 0.0
	var climbed := false
	var under := false
	var inside := 0.0
	while t < 6.0:
		h.inp["move"] = -dir
		h.inp["glide"] = not h.mantling()
		m.step(DT)
		t += DT
		if h.mantling(): climbed = true
		if IslandDepth.below(w, h.pos): under = true
		var i := w.idx(int(floor(h.pos.x)), int(floor(h.pos.z)))
		var g := w.ground_at(h.pos.x, h.pos.z)
		if not w.is_void(h.pos.x, h.pos.z) and h.pos.y < g - 0.3 and not IslandDepth.below(w, h.pos):
			inside = maxf(inside, minf(h.pos.y + IslandDepth.HEAD - w.under_heights()[i], g - h.pos.y))
		if climbed and h.grounded and not h.mantling(): break
	var on_ground := absf(h.pos.y - w.ground_at(h.pos.x, h.pos.z)) < 0.05
	var topped := h.grounded and on_ground and h.pos.y > float(e["top"]) - 0.9
	print("IDCHECK   %s island %d: start %.1fm under the top, under the rock %s, climbed %s, "
			% [where, e["isl"], float(e["top"]) - y0, under, climbed]
			+ "on top %s in %.2fs, deepest in rock %.2fm" % [topped, t, inside])
	return under and climbed and topped and inside < 0.35

## Rims with open air out past them:
## {ex, ez (the edge), dir (out), top, rock (the rim tiles' lowest underside), isl}.
func _edges(ww: World, n: int) -> Array:
	var out: Array = []
	for k in 4000:
		if out.size() >= n: break
		var g := ww.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var gi := ww.idx(int(floor(g.x)), int(floor(g.z)))
			if ww.sheer.has(gi) or ww.bridge.has(gi) or not ww.is_void(g.x + d.x * 1.1, g.z + d.y * 1.1): continue
			var open := true
			for dd in [1.1, 2.0, 3.0, 4.0, 5.0]:
				for s in [-1.0, 0.0, 1.0]:
					if not ww.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s): open = false
			var top := ww.ground_at(g.x, g.z)
			for s in [-1.0, 1.0]:
				var nb := ww.idx(int(floor(g.x + d.y * s)), int(floor(g.z + d.x * s)))
				if absf(ww.ground_at(g.x + d.y * s, g.z + d.x * s) - top) > 0.05 or ww.sheer.has(nb):
					open = false
			if not open: continue
			var ex := g.x
			var ez := g.z
			while not ww.is_void(ex + d.x * 0.25, ez + d.y * 0.25):
				ex += d.x * 0.25
				ez += d.y * 0.25
			var lo := 0.0
			for s in [-1.0, 0.0, 1.0]:
				lo = minf(lo, ww.under_heights()[ww.idx(int(floor(g.x + d.y * s)), int(floor(g.z + d.x * s)))])
			out.append({"ex": ex, "ez": ez, "dir": d, "top": top, "rock": lo, "isl": ww.island[gi]})
			break
	return out

## The farm: the same glide in under its rim, with the farm's own movement.
func _farm(main: Node) -> void:
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	hm.set_process(false)
	_depths(hm.world, "farm")
	var es := _edges(hm.world, 3)
	var good := 0
	for e in es:
		var dir: Vector2 = e["dir"]
		hm.climb = {}
		hm.lfl = {}
		hm.ppos = Vector3(e["ex"] - dir.x * 0.25, 0, e["ez"] - dir.y * 0.25)
		hm.py = float(e["rock"]) - IslandDepth.HEAD - 0.4
		hm.pvy = 0.0
		hm.pvel = Vector3.ZERO
		hm.gliding = true
		hm.dash_t = 0.0
		var under := false
		var climbed := false
		for i in 360:
			_press(-dir)
			hm._move_player(DT)
			if IslandDepth.below(hm.world, Vector3(hm.ppos.x, hm.py, hm.ppos.z)): under = true
			if not hm.lfl.is_empty() or not hm.climb.is_empty(): climbed = true
			var up: bool = absf(hm.py - float(e["top"])) < 0.05 and hm.pvy == 0.0
			if up and not hm.world.is_void(hm.ppos.x, hm.ppos.z):
				break
		var topped: bool = absf(hm.py - float(e["top"])) < 0.05
		print("IDCHECK   farm rim %s: under the rock %s, climbed %s, on top %s"
				% [str(Vector2(e["ex"], e["ez"])), under, climbed, topped])
		if under and climbed and topped: good += 1
	_press(Vector2.ZERO)
	var n := es.size()
	ok(n > 0 and good == n, "farm: glided in under the rim, climbed onto the top %d of %d" % [good, n])
	hm.queue_free()

func _press(dir: Vector2) -> void:
	for a in ["left", "right", "up", "down"]: Input.action_release(a)
	if dir.x > 0.1: Input.action_press("right", dir.x)
	if dir.x < -0.1: Input.action_press("left", -dir.x)
	if dir.y > 0.1: Input.action_press("down", dir.y)
	if dir.y < -0.1: Input.action_press("up", -dir.y)
