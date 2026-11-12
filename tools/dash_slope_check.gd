extends RefCounted
## --dash-slope-check: every Hunter dashes (one Shift tap, holding the way it goes) on flat ground and
## over four terrain cases, on the Hollow Crown and the Training Area: up a 15 and a 30 degree ramp, up a
## one-tier step, and off a downhill crest. The ramps are the maps' own terrain (stair tiles between
## flat ones, as HandLayout.stamp_ramp lays them), so their angle is the mean rise over the run.
## [game data] a ground dash hugs the ground on walkable slopes (WalkableFloorAngle 50 deg) and keeps its
## distance; it only leaves the ground off a ledge. So per Hunter and case: horizontal distance within
## 10% of the flat dash over the same steps, and no more pop or airtime than on flat. Controls: a dash
## and a walk off a one-tier ledge still leave the ground, and a walk still goes up the step.
## Prints "DSLOPE <map> <hero> <case> dist pop air" rows and "DASH SLOPE CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const CASES := ["ramp15", "ramp30", "step", "crest"]
const TOL := 0.10          # the distance may differ from flat by this share
const POP_TOL := 0.15      # m: extra height over the ground beyond the flat dash's own
const AIR_TOL := 0.10      # s: extra airtime beyond the flat dash's own
const SETTLE := 12         # steps standing still before each run
const MAX_N := 150         # steps watched after the press (Sable's lantern lands after 1.8 s)
## Each ramp: rises per run of tiles (a stair tile climbs one tier across its metre, a flat tile holds).
const RAMPS := {"ramp15": [true, false, false], "ramp30": [true, true, true, false]}
## Shift moves that are not ground dashes by design: only their distance is held to flat.
## Rock Hop: an aimed arc onto a rock at the cursor, so down a slope it is longer in the air.
const HOPS := ["dolm"]
const HOVERS := ["ostra"]      # Lantern Trade: he hovers where he is while the lantern flies, then trades places
const RAMP_TILES := 8      # tiles of ramp; flat at its top beyond

var bad := 0
var m: Match
var w: World
var P: Hunter
var o := Vector2i.ZERO     # the lane's first tile; the lane runs +x
var lv0 := 4               # the lane's ground tier (the crest falls 6 tiers from its top)

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("DSLOPE FAIL %s" % what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var was = Settings.get_v("dash_to_cursor")
	Settings.set_v("dash_to_cursor", false, false)
	for map in ["hollowcrown", "training"]:
		_start(main, map)
		for hero in Arch.ORDER:
			_hero(map, hero)
		_controls(map)
		m.queue_free()
		await main.get_tree().process_frame
	Settings.set_v("dash_to_cursor", was, false)
	print("DASH SLOPE CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _start(main: Node, map: String) -> void:
	m = Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true}
	if map == "training": opts["training"] = true
	m.start(opts)
	m.set_process(false)
	m.biomes = null
	w = m.world
	for mob in m.mobs: mob.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	o = Vector2i(int(floor(P.pos.x)) - 4, int(floor(P.pos.z)))

## Lays the lane: 30 x 9 tiles at lv0, then the case's terrain from x = o.x + 6 on.
func _lay(case: String) -> void:
	for dz in range(-4, 5):
		for dx in range(-2, 30):
			var q := Vector2i(o.x + dx, o.y + dz)
			if not w.inb(q.x, q.y): continue
			var i := w.idx(q.x, q.y)
			w.kind[i] = World.T_GROUND
			w.island[i] = w.island[w.idx(o.x, o.y)] if w.island[i] < 0 else w.island[i]
			w.walls.erase(i)
			w.props.erase(i)
			w.stairs.erase(i)
			w.level[i] = _tier(case, dx)
			var up := _stair(case, dx)
			if up != Vector2i.ZERO: w.stairs[i] = up
	w.dyn_walls.clear()

## The tile's tier along the lane (dx tiles from its start) for a case.
func _tier(case: String, dx: int) -> int:
	var k := dx - 6
	if k < 0:
		var top := {"crest": 4, "ledge": 1}
		return lv0 + int(top.get(case, 0))
	match case:
		"step": return lv0 + 1
		"ledge": return lv0
		"ramp15", "ramp30", "crest":
			var pat: Array = RAMPS["ramp30" if case == "crest" else case]
			var rises := 0
			for j in mini(k, RAMP_TILES):
				if pat[j % pat.size()]: rises += 1
			var here: bool = k < RAMP_TILES and pat[k % pat.size()]
			if case == "crest":
				# downhill: mirror the climb so the lane falls from lv0 + 4 (a stair tile's base is its low side)
				return lv0 + 4 - rises - (1 if here else 0)
			return lv0 + rises
	return lv0

func _stair(case: String, dx: int) -> Vector2i:
	var k := dx - 6
	if k < 0 or k >= RAMP_TILES or not (case in RAMPS or case == "crest"):
		return Vector2i.ZERO
	var pat: Array = RAMPS["ramp30" if case == "crest" else case]
	if not pat[k % pat.size()]:
		return Vector2i.ZERO
	return Vector2i(-1, 0) if case == "crest" else Vector2i(1, 0)

## The cursor: on the ground 10 m down the lane from the start (aimed moves, a hop or a lob, go there).
func _cursor() -> Vector3:
	var x := o.x + 14.5
	return Vector3(x, w.ground_at(x, o.y + 0.5) + 0.9, o.y + 0.5)

func _reset(hero: String) -> void:
	P.reclass(Arch.weight(hero), hero, Arch.signature(hero))
	P.unlock_all()
	P.out = false
	P.downed = false
	var start := Vector3(o.x + 4.5, 0.0, o.y + 0.5)
	start.y = w.ground_at(start.x, start.z)
	P.teleport(start)
	P.vel = Vector3.ZERO
	P.grounded = true
	P.roll_t = 0.0
	P.knock_t = 0.0
	P.fly_t = 0.0
	P.gliding = false
	P.stun_t = 0.0
	P.root_t = 0.0
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.dash_buf = 0.0
	for k in ["fire", "sec", "sig", "ult", "jump", "dash", "glide", "crouch"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = _cursor()
	for i in SETTLE: m.step(DT)
	P.dashes = P.max_dashes()

## One dash (or walk) along +x: per step the horizontal distance covered, the height over the ground
## and whether grounded.
func _track(hero: String, case: String, dash: bool) -> Array:
	_lay(case)
	_reset(hero)
	var x0 := P.pos.x
	var rows := []
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = dash
	for i in MAX_N:
		m.step(DT)
		P.inp["dash"] = false
		var speed := Vector2(P.vel.x, P.vel.z).length()
		rows.append([P.pos.x - x0, P.pos.y - _support(), P.grounded, speed, w.ground_at(P.pos.x, P.pos.z)])
	P.inp["move"] = Vector2.ZERO
	return rows

## Where the burst ends on flat ground: the first step back on the ground at run speed after it got going
## (a wind-up stands still first, a hop leaves the ground).
func _burst_end(rows: Array) -> int:
	var going := false
	for i in rows.size():
		var fast: bool = rows[i][3] > P.base_speed * 1.15 or not rows[i][2]
		if going and not fast:
			return i
		going = going or fast
	return rows.size() - 1

## The highest ground under the body's footprint: standing on a lip you were lifted onto is no pop.
func _support() -> float:
	var top := P.ground()
	for a in 8:
		var q := Vector2(P.pos.x, P.pos.z) + Vector2.from_angle(TAU * a / 8.0) * P.r
		top = maxf(top, w.ground_at(q.x, q.y))
	return top

func _pop(rows: Array, n: int) -> float:
	var top := 0.0
	for i in mini(n, rows.size()): top = maxf(top, rows[i][1])
	return top

func _air(rows: Array, n: int) -> float:
	var a := 0
	for i in mini(n, rows.size()):
		if not rows[i][2]: a += 1
	return a * DT

func _hero(map: String, hero: String) -> void:
	var flat := _track(hero, "flat", true)
	var n := _burst_end(flat)
	var fd: float = flat[n][0]
	var fpop := _pop(flat, MAX_N)
	var fair := _air(flat, MAX_N)
	print("DSLOPE %-11s %-10s flat   dist %5.2f m  pop %4.2f m  air %4.2f s  (%d steps)" % [
		map, hero, fd, fpop, fair, n
	])
	if fd < 1.0:
		ok(false, "%s %s: the flat dash went %.2f m" % [map, hero, fd])
		return
	for case in CASES:
		var rows := _track(hero, case, true)
		var end := rows.size() - 1 if hero in HOVERS else _burst_end(rows)     # (the trade lands at the end)
		var d: float = rows[end][0]
		var pop := _pop(rows, MAX_N)
		var air := _air(rows, MAX_N)
		# an arc to higher ground (a hop up the ramp) may peak that much higher
		var rise := maxf(0.0, rows[end][4] - rows[0][4])
		var fall := maxf(0.0, rows[0][4] - rows[end][4])
		# a hop down a slope falls further
		var air_extra := sqrt(2.0 * fall / Hunter.H_GRAV) if hero in HOPS else 0.0
		var good := absf(d - fd) <= fd * TOL
		if not hero in HOVERS:
			good = good and pop <= fpop + rise + POP_TOL and air <= fair + air_extra + AIR_TOL
		print("DSLOPE %-11s %-10s %-6s dist %5.2f m  pop %4.2f m  air %4.2f s  %+4.0f%%  %s" % [
			map, hero, case, d, pop, air, (d / fd - 1.0) * 100.0, "ok" if good else "FAIL"
		])
		ok(good, "%s %s %s" % [map, hero, case])

## A dash and a walk off a one-tier ledge still leave the ground; a walk still goes up the step.
func _controls(map: String) -> void:
	var hero := "gunslinger"
	var rows := _track(hero, "ledge", true)
	ok(_air(rows, MAX_N) > 0.05, "%s: a dash off a one-tier ledge leaves the ground" % map)
	print("DSLOPE %-11s %-10s ledge  dash air %.2f s, pop %.2f m" % [map, hero, _air(rows, MAX_N), _pop(rows, MAX_N)])
	rows = _track(hero, "ledge", false)
	ok(_air(rows, MAX_N) > 0.05, "%s: a walk off a one-tier ledge falls (air %.2f s)" % [map, _air(rows, MAX_N)])
	print("DSLOPE %-11s %-10s ledge  walk air %.2f s" % [map, hero, _air(rows, MAX_N)])
	rows = _track(hero, "step", false)
	var up := P.pos.y >= (lv0 + 1) * World.LEVEL - 0.01
	ok(up, "%s: a walk goes up the one-tier step (y %.2f)" % [map, P.pos.y])
	print("DSLOPE %-11s %-10s step   walk up %s" % [map, hero, "yes" if up else "no"])
