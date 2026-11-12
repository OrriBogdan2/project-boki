extends RefCounted
## --pad-check: jump pads and updrafts (PadFlight; DECISIONS: pad and updraft auto-glides). For every hunter
## off a map pad aimed at another island: the rise is a ballistic throw to HunterMove.pad_vy's apex in its time,
## the keys barely steer it, the glider is shut on the way up and opens by itself at the apex with no
## glide input, steers from then on, and a hands-off flight is set down near the landing. Once: a pocket
## pad's launch opens the glider the same way, and a hunter falling into an updraft has the glider opened
## for them and climbs at HunterMove.updraft_vy.

const MIN_GAP := 12.0       # m at least to the landing on another island
const MAX_GAP := 46.0       # m at most (the map's pads start at 46 m; the training map's islands are closer)
const APEX_TOL := 0.5       # m off pad_vy^2 / 2g
const APEX_T_TOL := 0.1     # s off pad_vy / g
const RISE_DRIFT := 0.6     # m sideways a held key may move you during the rise (HunterMove.air_control)
const OPEN_WAIT := 0.3      # s after the apex the glider has to open in
const STEER_V := 2.0        # m/s sideways a held key must reach within a second of the glider opening
const LAND_R := 4.0         # m from the landing a hands-off flight must come down within
const FLIGHT_S := 12.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("PAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh training match as `arch`, bots idle and far away.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 51, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

## A landing on another island across the void, as the map's pads have: the farthest clear ground cell well
## inside an island within MAX_GAP m (INF when there is none MIN_GAP m or more out).
func _landing(m: Match, at: Vector3) -> Vector3:
	var w: World = m.world
	var here := w.island_of(at.x, at.z)
	var best := Vector3.INF
	var far := MIN_GAP
	for isl in w.islands.size():
		if isl == here:
			continue
		for cell: Vector2i in w.islands[isl]["cells"]:
			var x := cell.x + 0.5
			var z := cell.y + 0.5
			var d := Vector2(x - at.x, z - at.z).length()
			if d <= far or d > MAX_GAP or w.is_void(x, z) or w.is_block(x, z) or w.edge_dist(cell.x, cell.y, 4) < 4:
				continue
			far = d
			best = Vector3(x, w.ground_at(x, z), z)
	return best

## Stands the hunter on a map pad aimed at `land` and flies it with `move` held and no glide input.
## Returns apex (m over the pad), apex_t (s), rise_drift (m sideways at the apex), glided_in_rise,
## open_after (s from apex to the glider opening, INF if never), steer_v (sideways m/s a second after
## the open), end (flat m from the landing when grounded again, INF if still flying).
func _flight(m: Match, land: Vector3, move: Vector2) -> Dictionary:
	var h: Hunter = m.player
	var start := h.pos
	var side := Vector2(land.x - start.x, land.z - start.z).normalized().orthogonal()
	m.world.pads.append({"pos": start, "land": land, "from": 0, "to": 0, "cd": 0.0})
	var r := {
		"apex": 0.0, "apex_t": -1.0, "rise_drift": 0.0, "glided_in_rise": false,
		"open_after": INF, "steer_v": 0.0, "end": INF,
	}
	var t := 0.0
	var open_t := -1.0
	for i in int(FLIGHT_S / Match.DT):
		h.inp["move"] = move.x * side + move.y * Vector2(side.y, -side.x)
		h.inp["glide"] = false
		h.inp["glide_btn"] = false
		h.inp["jump"] = false
		m.step(Match.DT)
		if h.pad_flight.is_empty() and r["apex_t"] < 0.0 and t > 0.5:
			break                                   # never launched
		t += Match.DT
		r["apex"] = maxf(r["apex"], h.pos.y - start.y)
		if r["apex_t"] < 0.0:
			if h.gliding:
				r["glided_in_rise"] = true
			if h.vel.y <= 0.0 and t > 0.1:
				r["apex_t"] = t
				r["rise_drift"] = absf(Vector2(h.pos.x - start.x, h.pos.z - start.z).dot(side))
			continue
		if open_t < 0.0 and h.gliding:
			open_t = t
			r["open_after"] = t - float(r["apex_t"])
		if open_t > 0.0 and t - open_t >= 1.0 and r["steer_v"] == 0.0:
			r["steer_v"] = absf(Vector2(h.vel.x, h.vel.z).dot(side))
		if h.grounded and h.vel.y <= 0.0 and t > float(r["apex_t"]) + 0.2:
			r["end"] = Vector2(h.pos.x - land.x, h.pos.z - land.z).length()
			break
	m.world.pads.pop_back()
	h.inp["move"] = Vector2.ZERO
	return r

## Back on the ground at `at`, still, glider shut.
func _reset(m: Match, at: Vector3) -> void:
	var h: Hunter = m.player
	h.auto_glide = false
	h.pad_flight = {}
	h.teleport(at)
	h.vel = Vector3.ZERO
	for i in 30:
		h.inp["move"] = Vector2.ZERO
		m.step(Match.DT)

func _pad_flights(m: Match, arch: String, land: Vector3) -> void:
	var h: Hunter = m.player
	var pad := h.pos
	var g := Hunter.H_GRAV
	var want_apex := HunterMove.pad_vy * HunterMove.pad_vy / (2.0 * g)
	var want_t := HunterMove.pad_vy / g
	var r := _flight(m, land, Vector2.ZERO)
	var apex_ok := absf(float(r["apex"]) - want_apex) <= APEX_TOL and absf(float(r["apex_t"]) - want_t) <= APEX_T_TOL
	ok(apex_ok, "%s: pad %.0f m out, apex %.2f m at %.2f s (source gravity: %.2f m at %.2f s)"
		% [arch, Vector2(land.x - pad.x, land.z - pad.z).length(), r["apex"], r["apex_t"], want_apex, want_t])
	ok(not r["glided_in_rise"] and float(r["open_after"]) <= OPEN_WAIT,
		"%s: glider shut in the rise, opens by itself %.2f s after the apex, no glide input" % [arch, r["open_after"]])
	ok(float(r["end"]) <= LAND_R, "%s: hands-off flight set down %.1f m from the landing" % [arch, r["end"]])
	_reset(m, pad)
	r = _flight(m, land, Vector2(1, 0))
	ok(float(r["rise_drift"]) <= RISE_DRIFT and float(r["steer_v"]) >= STEER_V,
		"%s: a held side key moves you %.2f m in the rise, then steers the glide at %.1f m/s"
		% [arch, r["rise_drift"], r["steer_v"]])
	_reset(m, pad)

## A pocket pad throws you up the same way and the glider opens by itself at the apex.
func _pocket(m: Match) -> void:
	var h: Hunter = m.player
	var start := h.pos
	PadFlight.launch_up(h)
	var apex := 0.0
	var opened := -1.0
	var apex_t := -1.0
	var t := 0.0
	for i in int(4.0 / Match.DT):
		h.inp["glide"] = false
		m.step(Match.DT)
		t += Match.DT
		apex = maxf(apex, h.pos.y - start.y)
		if apex_t < 0.0 and h.vel.y <= 0.0 and t > 0.1:
			apex_t = t
		if apex_t > 0.0 and h.gliding:
			opened = t - apex_t
			break
	var want_apex := HunterMove.pad_vy * HunterMove.pad_vy / (2.0 * Hunter.H_GRAV)
	ok(absf(apex - want_apex) <= APEX_TOL and opened >= 0.0 and opened <= OPEN_WAIT,
		"pocket pad: apex %.2f m, glider opens by itself %.2f s after it" % [apex, opened])
	_reset(m, start)

## Falling into rising air with no input: the glider opens for you and you climb at updraft_vy.
func _updraft(m: Match) -> void:
	var h: Hunter = m.player
	var start := h.pos
	m.world.updrafts.append({"pos": start, "r": 1.6, "top": start.y + 30.0})
	h.teleport(start + Vector3(0, 8, 0))
	var opened := -1.0
	var climb := -INF
	var t := 0.0
	for i in int(2.5 / Match.DT):
		h.inp["glide"] = false
		m.step(Match.DT)
		t += Match.DT
		if opened < 0.0 and h.gliding:
			opened = t
		if opened >= 0.0:
			climb = maxf(climb, h.vel.y)
	ok(opened >= 0.0 and opened <= 0.6 and climb >= HunterMove.updraft_vy - 0.5,
		"updraft: glider opens by itself %.2f s into the fall, climbs at %.1f m/s (updraft_vy %.1f)"
		% [opened, climb, HunterMove.updraft_vy])
	m.world.updrafts.pop_back()
	_reset(m, start)

func run(main: Node) -> void:
	Save.no_write = true
	var last: Match = null
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		var land := _landing(m, m.player.pos)
		if not land.is_finite():
			ok(false, "%s: no level ground %.0f m or more from the spawn to land on" % [arch, MIN_GAP])
		else:
			_pad_flights(m, arch, land)
		if last:
			last.queue_free()
		last = m
		await main.get_tree().process_frame
	_pocket(last)
	_updraft(last)
	last.queue_free()
	print("PAD DONE, failures: %d" % bad)
	main.get_tree().quit()
