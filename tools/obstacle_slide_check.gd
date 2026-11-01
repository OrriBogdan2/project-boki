extends RefCounted
## --obstacle-check: walking past and around trees and rocks slides cleanly, with no sticking and
## no pull. On the training map (the --training match, seed 4242) and on an expedition island it
## finds every tree/rock cluster (connected blocker tiles, World.T_BLOCK) with open level ground
## around it and, for each:
##   1. walks a full lap around it, steering along it and a little into it (hugging it): every step
##      must move (no run of stuck steps longer than STUCK_RUN) and the lap must finish;
##   2. stands touching each side and walks straight away: you leave at once (no magnet);
##   3. walks past it on lines that just clear it: the hunter is never moved toward it more than
##      the keys ask (no pull).
## Also walks away from the training spawn in 8 directions. Counts fixed simulation steps; never
## touches the save. Prints "OBST ..." lines and "OBSTACLE CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const STUCK_RUN := 4          # steps in a row with almost no movement while walking along an obstacle
const PULL_EPS := 0.004       # m per step toward an obstacle that the keys didn't ask for
var bad := 0
var m: Match
var w: World
var P: Hunter
var debug := false

func ok(cond: bool, msg: String) -> void:
	print("OBST %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	debug = OS.has_environment("OBST_DEBUG")
	for setup in [["training", {"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": true}],
			["expedition", {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": true}]]:
		_map(main, String(setup[0]), setup[1])
	print("OBSTACLE CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _map(main: Node, label: String, opts: Dictionary) -> void:
	m = Match.new()
	main.add_child(m)
	m.start(opts)
	m.set_process(false)
	w = m.world
	P = m.player
	var spawn := P.pos
	# the training spawn first, as it is (props, breakables and all)
	if label == "training":
		var worst := 1e9
		var worst_dir := Vector2.ZERO
		for k in 8:
			var d := Vector2.RIGHT.rotated(TAU * k / 8.0)
			_reset(spawn)
			var moved := 0.0
			for i in 30:
				P.inp["move"] = d
				_step()
			moved = Vector2(P.pos.x - spawn.x, P.pos.z - spawn.z).dot(d)
			if moved < worst:
				worst = moved; worst_dir = d
		# (half a second at a run is ~2.4m; a ruin wall 2m south of the spawn stops that one at ~1.2m,
		# but nothing may hold you where you start)
		ok(worst > 0.8, "%s: walking away from the spawn in 8 directions, the shortest half-second walk is %.2fm (toward %s)" % [label, worst, str(worst_dir.snapped(Vector2(0.01, 0.01)))])
	# then a quiet map: no monsters, nobody else, nothing breakable in the way
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if h != P: h.teleport(Vector3(-500, 50, -500)); h.out = true
	for b in m.breaks: b["dead"] = true       # (pots and crates push you about: not what this measures)
	m.biomes = null                            # (nor do the biomes' hazards: gusts, vents, lightning)
	for k in m.kins.duplicate():               # (nor do wild Boki or your own: bodies push each other)
		k.dead = true; m.kins.erase(k); k.queue_free()
	P.kin = null; P.kin2 = null
	P.ctrl = "local"
	var clusters := _clusters(spawn)
	var n_lap := 0; var lap_ok := 0; var worst_run := 0; var worst_lap := ""
	var n_esc := 0; var esc_ok := 0; var worst_esc := 1e9; var worst_esc_at := ""
	var n_pass := 0; var worst_pull := 0.0; var worst_pull_at := ""
	for c in clusters:
		var cen: Vector2 = c["c"]; var rad: float = c["r"]
		# 1. a lap around it, hugging it (when there's open level ground all round)
		var res := _lap(c) if bool(c["ring"]) else {}
		if not res.is_empty(): n_lap += 1
		if res.is_empty(): pass
		elif res["done"] and int(res["run"]) <= STUCK_RUN: lap_ok += 1
		elif debug: print("OBST   lap stuck at %s (cluster %s, %d tiles): run %d, swept %.0f deg" % [str(res["at"]), str(cen), (c["tiles"] as Array).size(), res["run"], res["swept"]])
		if not res.is_empty() and int(res["run"]) > worst_run:
			worst_run = int(res["run"]); worst_lap = "%s near %s" % [label, str(res["at"])]
		# 2. touching each side, walk away
		for t in c["tiles"]:
			var tc := Vector2(t.x + 0.5, t.y + 0.5)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
				var n2 := Vector2i(int(floor(tc.x + float(d.x) * 0.9)), int(floor(tc.y + float(d.y) * 0.9)))
				if not _open(n2, int(c["lv"])): continue
				# as close as a body gets: step in from outside until something stops it
				var at: Vector2 = tc + d * 2.2
				if not _open_ground(at, int(c["lv"])): continue
				_reset(Vector3(at.x, float(c["lv"]) * World.LEVEL, at.y))
				for i in 40:
					P.inp["move"] = -d
					_step()
				var p0 := Vector2(P.pos.x, P.pos.z)
				if p0.distance_to(tc) > 1.4: continue      # didn't reach it (something else in between)
				# away from where you actually touch it (you may have slid round a corner on the way in)
				var away := _away(c, p0)
				if away == Vector2.ZERO: continue
				n_esc += 1
				var trace: Array = []
				for i in 6:
					P.inp["move"] = away
					_step()
					if debug: trace.append("OBST     esc step %d pos %s vel %s gr %s stun %.2f wedged %.2f pad %s lf %s" % [i, str(P.pos.snapped(Vector3(0.001, 0.001, 0.001))), str(P.vel.snapped(Vector3(0.01, 0.01, 0.01))), P.grounded, P.stun_t, P.wedged_t, str(P.pad.keys()), str(P.get("lfloat"))])
				var gone := (Vector2(P.pos.x, P.pos.z) - p0).dot(away)
				# 6 steps at a run from pushing into it: ~0.3m (0.36m from a standstill)
				if gone > 0.2: esc_ok += 1
				elif debug:
					print("OBST   escape failed at %s, going %s: %.2fm, vel %s (tile %s, came in along %s)" % [str(p0), str(away), gone, str(P.vel.snapped(Vector3(0.01, 0.01, 0.01))), str(t), str(-d)])
					for ln in trace: print(ln)
				if gone < worst_esc:
					worst_esc = gone; worst_esc_at = "%s at %s going %s" % [label, str(p0.snapped(Vector2(0.01, 0.01))), str(away.snapped(Vector2(0.01, 0.01)))]
		# 3. walk past on lines that just clear it
		for k in 8:
			var d := Vector2.RIGHT.rotated(TAU * k / 8.0)
			var side := Vector2(-d.y, d.x)
			for off in [rad + P.r + 0.05, rad + P.r + 0.3, -(rad + P.r + 0.05), -(rad + P.r + 0.3)]:
				var start: Vector2 = cen - d * (rad + 3.0) + side * off
				if not _line_clear(start, d, 2.0 * (rad + 3.0), int(c["lv"]), c): continue
				n_pass += 1
				_reset(Vector3(start.x, float(c["lv"]) * World.LEVEL, start.y))
				var steps := int((2.0 * (rad + 3.0)) / (float(P.base_speed) * DT))
				for i in steps:
					P.inp["move"] = d
					var b := Vector2(P.pos.x, P.pos.z)
					_step()
					var a := Vector2(P.pos.x, P.pos.z)
					var to_c := (cen - b).normalized()
					# moved toward the cluster's middle more than the keys asked (they ask d . to_c)
					var pull := (a - b).dot(to_c) - maxf(0.0, d.dot(to_c)) * P.base_speed * 1.3 * DT
					if pull > worst_pull:
						worst_pull = pull; worst_pull_at = "%s at %s" % [label, str(b.snapped(Vector2(0.01, 0.01)))]
					if debug and pull > PULL_EPS:
						print("OBST   pull %.3f at %s -> %s keys %s cluster %s r %.2f vel %s gr %s y %.2f pad %s fly %.2f knock %.2f roll %.2f ground %.2f" % [pull, str(b), str(a), str(d), str(cen), rad, str(P.vel.snapped(Vector3(0.01, 0.01, 0.01))), P.grounded, P.pos.y, str(P.pad.keys()), P.fly_t, P.knock_t, P.roll_t, w.ground_at(a.x, a.y)])
	print("OBST %s: %d tree/rock clusters checked, %d with open ground all round for a lap (%d blocker tiles on the map)" % [label, clusters.size(), n_lap, _count_blocks()])
	ok(clusters.size() > 0, "%s: found clusters to walk around" % label)
	ok(lap_ok == n_lap, "%s: laps around clusters with no stuck run over %d steps: %d of %d (longest run %d steps%s)" % [label, STUCK_RUN, lap_ok, n_lap, worst_run, (", " + worst_lap) if worst_lap != "" else ""])
	ok(esc_ok == n_esc, "%s: walking away from a cluster you're touching: %d of %d leave at once (least %.2fm in 0.1s%s)" % [label, esc_ok, n_esc, worst_esc if n_esc > 0 else 0.0, (", " + worst_esc_at) if worst_esc_at != "" else ""])
	ok(worst_pull <= PULL_EPS, "%s: walking past %d times, never pulled toward a cluster (worst %.4fm in a step%s)" % [label, n_pass, worst_pull, (", " + worst_pull_at) if worst_pull_at != "" else ""])
	m.queue_free()
	m = null

## One step with nothing else acting on you: monsters that spawn in later and the map's own stuns
## (storms, lair alerts) are cleared, so only walking and the rocks are measured.
func _step() -> void:
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P.stun_t = 0.0; P.root_t = 0.0; P.knock_t = 0.0; P.slow_t = 0.0
	m.step(DT)

func _reset(at: Vector3) -> void:
	P.out = false; P.downed = false; P.hp = P.max_hp
	P.teleport(at)
	P.grounded = true; P.vel = Vector3.ZERO; P.pad = {}; P.grap = {}; P.grap_cd = 0.0; P.roll_t = 0.0
	P.gliding = false; P.knock_t = 0.0; P.fly_t = 0.0; P.stun_t = 0.0; P.root_t = 0.0; P.slow_t = 0.0
	P.dropping = false; P.diving = false; P.last_gy = at.y; P.wedged_t = 0.0
	for k in ["glide", "jump", "dash", "fire"]: P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	_step()

func _count_blocks() -> int:
	var n := 0
	for i in w.w * w.h:
		if w.kind[i] == World.T_BLOCK: n += 1
	return n

## Ground tile at this terrace level, not a blocker, not a wall.
func _open(t: Vector2i, lv: int) -> bool:
	if not w.inb(t.x, t.y): return false
	var i := w.idx(t.x, t.y)
	return w.kind[i] == World.T_GROUND and int(w.level[i]) == lv and not w.stairs.has(i)

func _open_ground(p: Vector2, lv: int) -> bool:
	for o in [Vector2.ZERO, Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]:
		if not _open(Vector2i(int(floor(p.x + o.x)), int(floor(p.y + o.y))), lv): return false
	return true

## The walk-past line stays on open level ground, away from every other blocker and jump pad.
func _line_clear(s: Vector2, d: Vector2, len: float, lv: int, c: Dictionary) -> bool:
	var t := 0.0
	while t <= len:
		var p := s + d * t
		for pd in w.pads:
			if Vector2((pd["pos"] as Vector3).x, (pd["pos"] as Vector3).z).distance_to(p) < 1.5: return false
		for o in [Vector2.ZERO, Vector2(-d.y, d.x) * 0.7, Vector2(d.y, -d.x) * 0.7]:
			var q: Vector2 = p + o
			var ti := Vector2i(int(floor(q.x)), int(floor(q.y)))
			if not w.inb(ti.x, ti.y): return false
			var i := w.idx(ti.x, ti.y)
			if w.kind[i] == World.T_BLOCK:
				if not (c["set"] as Dictionary).has(ti): return false
			elif w.kind[i] != World.T_GROUND or int(w.level[i]) != lv or w.stairs.has(i):
				return false
		t += 0.25
	return true

## Connected blocker tiles (trees, rocks; not built walls), nearest the spawn first: up to 40 with
## open level ground all round ("ring", needed for a lap) and the 30 nearest others.
func _clusters(near: Vector3) -> Array:
	var seen := {}
	var out: Array = []
	for z in w.h:
		for x in w.w:
			var i := w.idx(x, z)
			if w.kind[i] != World.T_BLOCK or seen.has(Vector2i(x, z)) or w.walls.has(i): continue
			var tiles: Array = []
			var st := {}
			var q: Array = [Vector2i(x, z)]
			seen[Vector2i(x, z)] = true
			while not q.is_empty():
				var t: Vector2i = q.pop_back()
				tiles.append(t); st[t] = true
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					var n: Vector2i = t + dv
					if w.inb(n.x, n.y) and not seen.has(n) and w.kind[w.idx(n.x, n.y)] == World.T_BLOCK and not w.walls.has(w.idx(n.x, n.y)):
						seen[n] = true; q.append(n)
			if tiles.size() > 12: continue
			var cen := Vector2.ZERO
			for t in tiles: cen += Vector2(t.x + 0.5, t.y + 0.5)
			cen /= tiles.size()
			var rad := 0.0
			for t in tiles:
				for cx in [0.0, 1.0]:
					for cz in [0.0, 1.0]:
						rad = maxf(rad, cen.distance_to(Vector2(t.x + cx, t.y + cz)))
			var lv := int(w.level[w.idx(tiles[0].x, tiles[0].y)])
			# level open ground in a ring round it, wide enough for a lap
			var clear := true
			for k in 32:
				for rr in [rad + 0.3, rad + 0.9, rad + 1.6]:
					var p: Vector2 = cen + Vector2.RIGHT.rotated(TAU * k / 32.0) * rr
					var ti := Vector2i(int(floor(p.x)), int(floor(p.y)))
					if st.has(ti): continue
					if not _open(ti, lv): clear = false
					# (ice in a frost region: you skid by design, slow to start and stop)
					if m.ground_grip(Vector3(p.x, lv * World.LEVEL, p.y)) < 0.9: clear = false
			# (no open ring round it: no lap, but the walk-away and walk-past tests still run where
			# their own paths are clear)
			out.append({"tiles": tiles, "set": st, "c": cen, "r": rad, "lv": lv, "ring": clear})
	out.sort_custom(func(a, b): return (a["c"] as Vector2).distance_to(Vector2(near.x, near.z)) < (b["c"] as Vector2).distance_to(Vector2(near.x, near.z)))
	# every lap-able cluster (up to 40) and the 30 nearest others
	var ring: Array = out.filter(func(c): return bool(c["ring"]))
	var rest: Array = out.filter(func(c): return not bool(c["ring"]))
	return ring.slice(0, 40) + rest.slice(0, 30)

## The way straight out from the cluster's nearest tile at p (unit), or ZERO when p is inside one.
func _away(c: Dictionary, p: Vector2) -> Vector2:
	var best := 1e9; var out := Vector2.ZERO
	for t in c["tiles"]:
		var q := Vector2(clampf(p.x, t.x, t.x + 1.0), clampf(p.y, t.y, t.y + 1.0))
		var l := p.distance_to(q)
		if l < best and l > 0.0001:
			best = l; out = (p - q) / l
	return out

## Walk round the cluster, steering along it and 20 degrees into it. {done, run (longest stuck run), at, swept}
func _lap(c: Dictionary) -> Dictionary:
	var cen: Vector2 = c["c"]; var rad: float = c["r"]
	var a0 := 0.3
	var st := cen + Vector2.RIGHT.rotated(a0) * (rad + P.r + 0.35)
	_reset(Vector3(st.x, float(c["lv"]) * World.LEVEL, st.y))
	var swept := 0.0
	var last_a := a0
	var run := 0; var worst := 0; var worst_at := Vector2.ZERO
	for i in 900:
		# along the surface where it's nearest (as a player hugging it steers), 20 degrees into it
		var nrm := _away(c, Vector2(P.pos.x, P.pos.z))
		if nrm == Vector2.ZERO: nrm = (Vector2(P.pos.x, P.pos.z) - cen).normalized()
		var tang := Vector2(-nrm.y, nrm.x)
		var mv := tang.rotated(deg_to_rad(20.0))     # (rotating the tangent toward the obstacle)
		P.inp["move"] = mv
		var b := Vector2(P.pos.x, P.pos.z)
		_step()
		var a := Vector2(P.pos.x, P.pos.z)
		if a.distance_to(b) < P.base_speed * DT * 0.25:
			if debug and run >= STUCK_RUN and run < STUCK_RUN + 6:
				print("OBST     lap stuck step at %s mv %s nrm %s vel %s gr %s" % [str(b), str(mv), str(nrm), str(P.vel.snapped(Vector3(0.01, 0.01, 0.01))), P.grounded])
			run += 1
			if run > worst: worst = run; worst_at = b
		else:
			run = 0
		var ang := (a - cen).angle()
		swept += wrapf(ang - last_a, -PI, PI)
		last_a = ang
		if swept >= TAU:
			return {"done": true, "run": worst, "at": worst_at.snapped(Vector2(0.01, 0.01)), "swept": rad_to_deg(swept)}
		if (a - cen).length() > rad + P.r + 3.0:
			break      # drifted off (shouldn't: the steering hugs it)
	return {"done": false, "run": maxi(worst, run), "at": Vector2(P.pos.x, P.pos.z).snapped(Vector2(0.01, 0.01)), "swept": rad_to_deg(swept)}
