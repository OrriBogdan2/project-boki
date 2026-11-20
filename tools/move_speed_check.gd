extends RefCounted
## --move-speed-check: every Hunter walks at the same speed in the three places you walk (an expedition, the
## Training Grounds and the farm), and that speed is HunterMove.speed: its content/rules/hunter_move.json row at
## body_scale (decision 0061). Each hunter holds the real move key on flat ground through the real frame
## (Match._process: input, hit-stop and slow motion included; Home._move_player on the farm); the steady walk is
## the median step speed over the last MEASURE_S (a Boki wandering into the farm lane can't skew it). Also prints
## the walk in screen widths per second at each place's camera. Never touches the real save.
## Prints "MSPEED <hero> <mode> = <m/s> (<screens>/s)  target <m/s>  ok|FAIL" and "MOVE SPEED CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const SETTLE_S := 0.5       # s held before timing: well past the ~0.1 s to reach the walk
const MEASURE_S := 1.0      # s timed
const TOL := 0.02           # m/s: how far a walk may sit off its target (rounding over a step)
const FARM_LANE := 10       # m of open farm ground the walk needs (SETTLE_S + MEASURE_S at the fastest walk)

var main: Node
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MSPEED %s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for arch in Arch.ids():
		var want := HunterMove.speed(arch)
		var rows := [["expedition", await _match_walk(arch, false)], ["training", await _match_walk(arch, true)],
				["farm", await _farm_walk(arch)]]
		for row in rows:
			var v: Vector2 = row[1]
			var line := "%-11s %-10s = %.2f m/s (%.3f screens/s)  target %.2f" % [arch, row[0], v.x, v.y, want]
			ok(absf(v.x - want) <= TOL, line)
	print("MOVE SPEED CHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## [m/s, screen widths/s] for `arch` walking on cleared flat ground in an expedition (10 trios) or the Training Grounds.
func _match_walk(arch: String, training: bool) -> Vector2:
	var opts := {"teams": 10, "squad": 3, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
			"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)}
	if training:
		opts.merge({"training": true, "practice": true, "teams": 1, "squad": 1}, true)
	Save.d = Save.fresh()      # no farm buff (a meal, an item) carried in from the walk before
	var mt := Match.new()
	main.add_child(mt)
	mt.start(opts)
	for mb in mt.mobs: mb.queue_free()
	mt.mobs.clear()
	var P: Hunter = mt.player
	for h in mt.hunters:
		if h != P:
			h.teleport(h.pos + Vector3(0, 0, 80))
	P.teleport(flat_lane(mt.world, P.pos, 14))
	P.vel = Vector3.ZERO
	var v := _median_walk(func() -> Vector3: return P.pos, func() -> void: mt._process(DT))
	var across := CamRig.style_across(mt.cam.style_id) * mt.cam.dist_mul * mt.cam.zoom
	mt.queue_free()
	await main.get_tree().process_frame
	return Vector2(v, v / across)

## The same walk on the farm's lawn (Home._move_player, the farm's own frame step).
func _farm_walk(arch: String) -> Vector2:
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true}
	d["arch"] = arch
	Save.d = d
	HomeLayout.ensure(d)
	var home = await main._hb_home()
	home.set_process(false)
	home._close_panel()      # the welcome card
	for e in home.kins:
		e["pos"] = Vector3(5.0, 0.0, 5.0)      # the Boki wander; out of the lane
	home.ppos = Vector3(38.0, 0.0, _open_row(home.world))
	home.pvel = Vector3.ZERO
	var v := _median_walk(func() -> Vector3: return home.ppos, func() -> void: home._move_player(DT))
	if absf(v - HunterMove.speed(arch)) > TOL:
		print("MSPEED   farm %s stopped at %s: panel '%s', climb %s" % [arch, home.ppos, home.panel_open, home.climb])
	var cam: CamRig = home.cam
	var across := CamRig.style_across(cam.style_id) * cam.dist_mul * cam.zoom
	home.queue_free()
	await main.get_tree().process_frame
	return Vector2(v, v / across)

## A row (z) of the farm with open ground for the walk east of x 38 (FARM_LANE m), from z 30 down.
func _open_row(w: World) -> float:
	for z in range(30, 10, -1):
		var open := true
		for x in range(38, 38 + FARM_LANE):
			open = open and w.occupy(float(x), float(z), 0.38, 0.0, true) == 0.0
		if open:
			return float(z)
	return 30.0

## Clears a flat lane `length` m east of `at` (7 tiles wide, at the ground level there) and returns its start, a
## tile centre on the ground. Shared with tools/gameplay_media.gd's walk clip.
static func flat_lane(w: World, at: Vector3, length: int) -> Vector3:
	var hx := int(floor(at.x))
	var hz := int(floor(at.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi]) if w.kind[hi] != World.T_VOID else 0
	for dz in range(-3, 4):
		for dx in range(-2, length + 1):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			for tiles: Dictionary in [w.stairs, w.walls, w.props, w.bush]:
				tiles.erase(i)
	return Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)

## Holds the right key, runs `frame` each DT and returns the median flat speed (m/s) over the last MEASURE_S.
func _median_walk(pos: Callable, frame: Callable) -> float:
	Input.action_press("right")
	for i in int(SETTLE_S / DT):
		frame.call()
	var steps: Array[float] = []
	for i in int(MEASURE_S / DT):
		var p0: Vector3 = pos.call()
		frame.call()
		var p1: Vector3 = pos.call()
		steps.append(Vector2(p1.x - p0.x, p1.z - p0.z).length() / DT)
	Input.action_release("right")
	steps.sort()
	return steps[steps.size() / 2]
