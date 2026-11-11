extends RefCounted
## --wisp-follow-check: a riding Boki wisp (KinWisp, WispFollow) keeps up with its Hunter and out of the level.
## Every Hunter (the 12 and Gil) carries a cindle wisp on the real match step beside a 4 m wall: a dash along
## it, a chained dash (along it, then into it), a glide dive at full dive speed (32.5 m/s) landing at its foot and,
## for Sparkle, a full Wirerun (40 m/s). Each runs at 60 and at 144 frames a second (frame times +-JITTER_S, like
## a real display), drawn by the Hunter's and the Kin's own render as Match does. Then the same path is replayed
## as another player's Hunter over an 80 ms line (40 +-20 ms each way, a snapshot every 0.1 s, 2% lost,
## positions to the cm; NetSmooth draws it) and its wisp is measured the same way. Per run:
##   lag    the largest distance (m) between the wisp and its orbit point (where it sits when all is still: on
##          its orbit round the drawn Hunter at their standing shoulder height, measured as they stand)
##   clip   frames its body is inside the level: "wall" a terrace side or rock above the Hunter's ground,
##          "floor" the ground at the Hunter's level under it
##   jit    the largest wobble (cm) of its own motion: a jump in its drawn path (less the terrace ease it takes
##          from its Hunter, StepSmooth) that the next frame takes back; with the step it came on
##   held   frames its hop stood still though time ran (a pose stepped at 60 Hz)
##   kept   frames the level holds it, left out of lag and jit with the spring's SETTLE_S after them: "phased"
##          (the Hunter's own body in a wall: no spot both near them and outside exists) and "edge" (resting on
##          the top of a wall its Hunter fell past). A teleport of the Hunter is left out of jit
## Targets (DECISIONS 2026-11-09): lag <= LAG_MAX and clip 0 local and remote; on the remote game no visible
## step, jit <= JIT_MAX_CM; held 0 (no 60 Hz judder at 144 frames a second). Local jit is reported.
## Prints "WISPFOLLOW <hunter> <move> <fps> local|remote ..." rows, "WISPFOLLOW ok|FAIL ..." and
## "WISPFOLLOW DONE, failures: N".

const STEPS := 150             # sim steps per move (2.5 s)
const SETTLE := 30             # sim steps to land and settle before a move
const CLEAR := 20              # tiles flattened each way round the start
const WALL_UP := 5             # terraces high (4 m): the wall north of the lane
const WALL_ROWS := 3           # tiles deep
const LANE_X := 15.5           # m east of the start tile the moves begin (they head west)
const HUG := 0.05              # m between the Hunter's body and the wall when it runs along it
const CHAIN_GAP := 1.2         # m from the wall the chained dash starts (its second dash goes into it)
const DIVE_H := 45.0           # m above the ground the dive starts: it reaches full dive speed before landing
const DIVE_VY := 32.5          # m/s the dive must reach (content/rules/hunter_move.json dive_vy)
const WIRE_VMIN := 35.0        # m/s the Wirerun must reach (its speed is 40)
const DASH_AT := 20            # step of the first dash press
const CHAIN_LEFT := 0.08       # s of the first dash left when the second is pressed (inside the dash buffer)
const STOP_AT := 105           # step the keys are let go
const WIRE_HOLD := 36          # steps Sparkle holds the Wirerun: a full charge (0.6 s)
const JITTER_S := 0.0003       # s a frame's time is off its rate either way
const SNAP_EVERY := 6          # steps between snapshots (0.1 s, Net)
const ONE_WAY := 0.04          # s: half the 80 ms ping
const LINE_JITTER := 0.02      # s each way
const LOSS := 0.02             # share of snapshots lost
const TELEPORT_M := 1.5        # m the drawn Hunter moves in one frame that is a teleport (Hunter.render_pos)
const SETTLE_S := 0.2          # s the wisp's spring takes to rejoin its orbit after the level let it go
const BALL := BokiWispLook.BODY_RADIUS + BokiWispLook.DART      # m: the wisp's body and its dart
const LAG_MAX := 1.0           # m from its orbit point at most
const JIT_MAX_CM := 5.0        # cm of wobble at most: 3 px at the match camera (1.5 cm a pixel at 1080p)
const MOVES := ["dash", "chain", "dive"]

var bad := 0
var m: Match
var h: Hunter
var k: Kin
var rng := RandomNumberGenerator.new()
var lane := Vector3.ZERO       # the ground spot by the wall where the moves start (the Hunter's centre)
var stand := 0.0               # m: the Hunter's shoulder above their feet as they stand
var ahead := Vector2(-1, 0)    # the way the moves run (west here; --wisp-follow-shots turns it to its lane)
var side := Vector2(0, -1)     # the way to the wall from the lane (north here)
var truth: Array = []          # [pos, vel] after every step of the last local run, for its remote replay

func ok(cond: bool, what: String) -> void:
	print("WISPFOLLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var worst := {}            # move -> [lag, clip frames, jit, held frames] over every Hunter, fps and side
	for arch in Arch.ORDER:
		_start(main, arch)
		ok(k != null and k.wisp, "%s carries its Boki as a wisp" % arch)
		if k == null:
			continue
		var moves: Array = MOVES + (["wirerun"] if arch == "mage" else [])
		for move_id in moves:
			for fps in [60.0, 144.0]:
				var local_run := _measure(move_id, fps, false)
				var remote_run := _measure(move_id, fps, true)
				for got in [local_run, remote_run]:
					var was: Array = worst.get(move_id, [0.0, 0, 0.0, 0])
					worst[move_id] = [maxf(was[0], got["lag"]), was[1] + got["wall"] + got["floor"],
						maxf(was[2], got["jit"]), was[3] + got["held"]]
				_assert(arch, move_id, fps, local_run, remote_run)
		m.queue_free()
		await main.get_tree().process_frame
	for move_id in worst:
		var top: Array = worst[move_id]
		print("WISPFOLLOW worst %-7s lag %.2f m  clip %d  jit %.2f cm  held %d" % [
			move_id, top[0], top[1], top[2], top[3]])
	print("WISPFOLLOW DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _assert(arch: String, move_id: String, fps: float, local_run: Dictionary, remote_run: Dictionary) -> void:
	var run_name := "%s %s %d fps" % [arch, move_id, fps]
	if move_id == "dive":
		var vy: float = local_run["top_vy"]
		ok(vy >= DIVE_VY - 0.1, "%s: the dive reaches full speed (%.1f m/s)" % [run_name, vy])
	if move_id == "wirerun":
		ok(local_run["top"] >= WIRE_VMIN, "%s: the Wirerun streaks (%.1f m/s)" % [run_name, local_run["top"]])
	for pair in [["local", local_run], ["remote", remote_run]]:
		var got: Dictionary = pair[1]
		var what := "%s %s" % [run_name, pair[0]]
		ok(got["lag"] <= LAG_MAX, "%s: within %.1f m of its orbit point (%.2f m)" % [what, LAG_MAX, got["lag"]])
		ok(got["wall"] + got["floor"] == 0,
			"%s: never inside the level (%d wall, %d floor frames)" % [what, got["wall"], got["floor"]])
		ok(got["held"] == 0, "%s: its hop moves every frame (%d held)" % [what, got["held"]])
	var jit: float = remote_run["jit"]
	ok(jit <= JIT_MAX_CM, "%s remote (80 ms): no visible step (%.2f cm wobble)" % [run_name, jit])

## A training match for one Hunter carrying a cindle wisp, on a flat square with a tall wall along its north.
func _start(main: Node, arch: String) -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 1109, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch), "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	h = m.player
	h.set_arch(arch)
	h.unlock_all()
	k = h.kin
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(80, 0, 80))
	var world: World = m.world
	var tile_x := int(floor(h.pos.x))
	var tile_z := int(floor(h.pos.z))
	var home: int = world.idx(tile_x, tile_z)
	var level: int = int(world.level[home])
	for dz in range(-CLEAR, CLEAR + 1):
		for dx in range(-CLEAR, CLEAR + 1):
			if not world.inb(tile_x + dx, tile_z + dz):
				continue
			var i: int = world.idx(tile_x + dx, tile_z + dz)
			world.kind[i] = World.T_GROUND
			world.level[i] = level + (WALL_UP if dz < 0 and dz >= -WALL_ROWS else 0)
			world.island[i] = world.island[home]
			for tiles in [world.stairs, world.walls, world.props, world.bush]:
				tiles.erase(i)
	lane = Vector3(tile_x + LANE_X, level * World.LEVEL, tile_z + h.r + HUG)       # the wall's face is at z = tile_z
	reset(lane, true)
	h.render(0.0, 1.0)
	k.render(0.0, 1.0)            # (its follow takes the shoulder of the Hunter standing)
	stand = _shoulder_y() - h.position.y

func _steps(n: int) -> void:
	for i in n:
		m.step(Match.DT)

## Back to a clean standing (or airborne) start at `at`, every dash ready, then settled.
func reset(at: Vector3, grounded: bool) -> void:
	h.remote = false
	h.net_buf = null
	k.remote = false
	h.hp = h.max_hp
	h.teleport(at)
	h.vel = Vector3.ZERO
	h.grounded = grounded
	h.roll_t = 0.0
	h.gliding = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.knock_t = 0.0
	h.dropping = false
	h.last_gy = at.y
	h.air_t = 0.0 if grounded else 0.5
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	for key in h.ak.cd:
		h.ak.cd[key] = 0.0
	for key in h.inp:
		if h.inp[key] is bool:
			h.inp[key] = false
	h.inp["move"] = Vector2.ZERO
	_steps(SETTLE if grounded else 1)

## Where a move starts: along the wall, the chained dash a little off it, the dive high above the lane.
func move_start(move_id: String) -> Vector3:
	match move_id:
		"chain":
			return lane - Vector3(side.x, 0, side.y) * (CHAIN_GAP - HUG)
		"dive":
			return lane + Vector3(0, DIVE_H, 0)
	return lane

## The keys held on step `i` of a move; `chained` is the step the chained dash's second press went in (or -1).
func press(move_id: String, i: int, chained: int) -> int:
	var inp: Dictionary = h.inp
	var into := (ahead + side).normalized()      # the chained dash's second way: on and into the wall
	var way := ahead if chained < 0 or i < chained else into
	inp["move"] = way if i < STOP_AT else Vector2.ZERO
	inp["aim"] = h.pos + Vector3(way.x, 0, way.y) * 10.0
	inp["dash"] = i == DASH_AT
	match move_id:
		"chain":
			if chained < 0 and i > DASH_AT and (h.roll_t < CHAIN_LEFT or i >= DASH_AT + 30):
				chained = i
				inp["move"] = into
				inp["aim"] = h.pos + Vector3(into.x, 0, into.y) * 10.0
				inp["dash"] = true
		"dive":
			inp["dash"] = false
			inp["jump"] = true
			inp["glide"] = true
			inp["crouch"] = i >= 20
		"wirerun":
			inp["dash_down"] = i >= DASH_AT and i < DASH_AT + WIRE_HOLD
	return chained

## One run of a move at `fps`: frames come at that rate (+-JITTER_S), the match steps on its fixed DT as they
## do and the Hunter and the Kin are drawn every frame. Local runs record the true path; remote ones replay it
## through NetSmooth over the bad line.
func _measure(move_id: String, fps: float, remote: bool) -> Dictionary:
	reset(move_start(move_id), move_id != "dive")
	rng.seed = 80
	var line: Array = []           # remote: [arrival s, owner s, pos, vel], in arrival order
	if remote:
		line = _line()
		h.remote = true
		h.net_t = 0.0
		h.net_buf = NetSmooth.new()
		k.remote = true
	else:
		truth.clear()
	var t0 := m.time
	var got := {"lag": 0.0, "phased": 0, "edge": 0, "wall": 0, "floor": 0, "jit": 0.0, "held": 0, "top": 0.0,
		"top_vy": 0.0}
	var kept_left := 0             # frames still left out after the level held it
	var path: Array = []           # the wisp's own path each frame (where it is drawn, less the terrace ease)
	var skips: Array = []          # each frame: left out of the wobble (kept by the level, a teleport)?
	var at_step: Array = []        # each frame: the steps taken by then
	var last_body := Vector3.INF
	var last_drawn := h.position
	var acc := 0.0
	var i := 0
	var chained := -1
	while i < STEPS:
		var frame_dt := 1.0 / fps + rng.randf_range(-JITTER_S, JITTER_S)
		acc += frame_dt
		while acc >= Match.DT and i < STEPS:
			acc -= Match.DT
			if remote:
				while not line.is_empty() and float(line[0][0]) <= m.time - t0 + 0.0001:
					var snap: Array = line.pop_front()
					h.net_buf.push(float(snap[1]), m.time, snap[2], snap[3])
			else:
				chained = press(move_id, i, chained)
			var was := h.pos
			m.step(Match.DT)
			i += 1
			if not remote:
				truth.append([h.pos, h.vel])
			got["top"] = maxf(got["top"], (h.pos - was).length() / Match.DT)
			got["top_vy"] = maxf(got["top_vy"], -h.vel.y)
		var alpha := acc / Match.DT
		h.render(frame_dt, alpha)
		k.render(frame_dt, alpha)
		var body := k.model.get_node("Body") as Node3D
		path.append(k.global_position - Vector3(0, h.position.y - h.render_pos(alpha).y, 0))
		var phased := _inside(h.position + Vector3(0, stand, 0), BokiWispLook.BODY_RADIUS)
		var on_edge := _on_wall_top(k.global_position)
		got["phased"] += int(phased)
		got["edge"] += int(on_edge)
		if phased or on_edge:
			kept_left = int(fps * SETTLE_S)
		var kept := kept_left > 0
		kept_left -= 1
		skips.append(kept or h.position.distance_to(last_drawn) > TELEPORT_M)
		at_step.append(i)
		last_drawn = h.position
		if not kept:
			got["lag"] = maxf(got["lag"], k.global_position.distance_to(_orbit_point(alpha)))
		var hit := _hit(body.global_position)
		if hit != "":
			got[hit] += 1
		if body.position == last_body:
			got["held"] += 1
		last_body = body.position
	var wobble := _wobble(path, skips)
	got["jit"] = wobble[0] * 100.0
	print(("WISPFOLLOW %-10s %-7s %3d fps %-6s lag %.2f m  clip %d wall %d floor  jit %.2f cm @s%d  held %d  " +
		"kept: phased %d, edge %d  top %.1f m/s") % [h.arch, move_id, fps, "remote" if remote else "local", got["lag"],
		got["wall"], got["floor"], got["jit"], at_step[wobble[1]], got["held"], got["phased"], got["edge"], got["top"]])
	return got

## The snapshots of the last local run as they reach the other game: every SNAP_EVERY steps, positions to the
## cm, ONE_WAY +-LINE_JITTER late, LOSS of them lost; sorted by arrival (a late one behind a newer one is then
## dropped by NetSmooth, as ENet's unreliable-ordered line does).
func _line() -> Array:
	var out: Array = [[0.0, 0.0, truth[0][0], truth[0][1]]]
	for i in range(SNAP_EVERY, truth.size(), SNAP_EVERY):
		if rng.randf() < LOSS:
			continue
		var p: Vector3 = truth[i][0]
		var at := Vector3(snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01))
		var sent := (i + 1) * Match.DT
		out.append([sent + ONE_WAY + rng.randf_range(-LINE_JITTER, LINE_JITTER), sent, at, truth[i][1]])
	out.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	return out

## Where the wisp would sit with nothing moving: its orbit point round the drawn Hunter at the moment drawn.
func _orbit_point(alpha: float) -> Vector3:
	var orbit: Dictionary = BokiWispCosmetics.worn(h)["orbit"]
	var t := m.time - (1.0 - alpha) * Match.DT
	var angle := TAU * (t * float(orbit["hz"]) + float(k.model.get_meta("phase", 0.0)))
	return KinWisp.orbit_spot(orbit, angle, h.position, h.position.y + stand)

## The height of the Hunter's drawn shoulder (the rig's, as KinWisp reads it).
func _shoulder_y() -> float:
	var sh := h.model.get_node_or_null("Rig/Torso/Shoulder") as Node3D
	return sh.global_position.y if sh else h.position.y + KinWisp.SHOULDER_Y

## "wall", "floor" or "" for the wisp's body at p (BokiWispLook.BODY_RADIUS) against the level.
func _hit(p: Vector3) -> String:
	var radius := BokiWispLook.BODY_RADIUS
	if not _inside(p, radius):
		return ""
	var world: World = m.world
	var under := world.ground_at(p.x, p.z) + (World.BLOCK_H if world.is_block(p.x, p.z) else 0.0)
	return "floor" if p.y - radius < under and under <= h.pos.y + World.STEP else "wall"

## Is a ball of `radius` at p inside the level? Every tile is a box up to its ground (BLOCK_H more on a rock,
## tree or wall tile, as World.los reads them): the ball against the boxes under it.
func _inside(p: Vector3, radius: float) -> bool:
	var world: World = m.world
	for tile_z in range(floori(p.z - radius), floori(p.z + radius) + 1):
		for tile_x in range(floori(p.x - radius), floori(p.x + radius) + 1):
			var near := Vector2(clampf(p.x, tile_x, tile_x + 0.999), clampf(p.z, tile_z, tile_z + 0.999))
			var top := world.ground_at(near.x, near.y) + (World.BLOCK_H if world.is_block(near.x, near.y) else 0.0)
			var above := maxf(0.0, p.y - top)
			if (p.x - near.x) * (p.x - near.x) + above * above + (p.z - near.y) * (p.z - near.y) < radius * radius:
				return true
	return false

## Is the wisp (its middle at p) resting on the top of a wall, a column standing above its Hunter's ground?
func _on_wall_top(p: Vector3) -> bool:
	var world: World = m.world
	var top := world.ground_at(p.x, p.z) + (World.BLOCK_H if world.is_block(p.x, p.z) else 0.0)
	return top > h.pos.y + World.STEP and absf(p.y - BALL - top) < 0.02

## The largest wobble (m) along a drawn path and the frame it is at: the smaller of two frame-to-frame changes
## of its step that point back against each other (a jump the next frame takes back, a hold then a double step).
## Frames next to a `skips` one are left out.
static func _wobble(path: Array, skips: Array) -> Array:
	var top := [0.0, 0]
	for n in range(2, path.size() - 1):
		if skips[n - 1] or skips[n] or skips[n + 1]:
			continue
		var bend_a: Vector3 = path[n] - 2.0 * path[n - 1] + path[n - 2]
		var bend_b: Vector3 = path[n + 1] - 2.0 * path[n] + path[n - 1]
		var amount := minf(bend_a.length(), bend_b.length())
		if bend_a.dot(bend_b) < 0.0 and amount > top[0]:
			top = [amount, n]
	return top
