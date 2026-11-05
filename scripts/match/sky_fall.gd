class_name SkyFall
extends RefCounted
## The opening drop's freefall (docs/decisions/0012), for solo divers and the squad comet alike.
##
## You fall along a heading. The side keys turn it; forward (along your heading) dives: a fast,
## steep fall. Letting go floats: a slower fall that reaches further. Back brakes to a near-vertical
## float. The glider opens by itself DEPLOY_H over the ground below you (or on Space), and from then
## on it's the normal glide until you land (Hunter.deploy). The landing has its own kick (land).

## m: the skyship's height. Leaving it to landing takes ~23 s untouched (--drop-check)
static var SKY_Y: float = DropData.rules["sky_y"]
static var FLOAT_FALL: float = DropData.rules["float_fall"]      # m/s down while floating (no keys)
## m/s across while floating: ~0.72 m of reach per metre of height
static var FLOAT_SPEED: float = DropData.rules["float_speed"]
static var DIVE_FALL: float = DropData.rules["dive_fall"]        # m/s down while diving (forward held)
static var DIVE_SPEED: float = DropData.rules["dive_speed"]      # m/s across while diving: steep, ~0.42 m per metre
const BRAKE_SPEED := 2.0      # m/s across while holding back: nearly straight down
const TURN_RATE := 2.4        # rad/s: how fast the side keys turn your heading
const STEER_RATE := 10.0      # 1/s: the speed across reaches 90% of a new target in ~0.23 s
const VY_RATE := 7.0          # 1/s: the fall reaches 90% of a new speed in ~0.33 s
const FORWARD_DOT := 0.5      # keys at least this far along your heading count as forward (dive)
const BACK_DOT := -0.5        # ... and this far against it as back (a full brake; less brakes less)
## m over the ground below you: the glider opens by itself
static var DEPLOY_H: float = DropData.rules["deploy_h"]
const LOW_DEPLOY_H := 4.0     # m: the same for a short drop (a small map, a respawn): a plunge, over in a few seconds
const VOID_DEPLOY_Y := 16.0   # m (world height): over the abyss it opens here, high enough to glide to land
const DEPLOY_POP := -1.6      # m/s: the canopy catching checks your fall to this
const JUMP_LEAD := 6.0        # s: bots leave the ship this long before it passes nearest their spot
const ASSIST_LOOK_S := 8.0    # s: letting go, the drop looks this far ahead for where you'd come down
const ASSIST_GLIDE_S := 1.5   # s: how far the glide carries on after it opens, in that look ahead
const LAND_SQUASH := 0.45     # model squash on touchdown
const PROJECT_STEP := 0.2     # s: DropReticle's look ahead, a step
const PROJECT_STEPS := 160    # ...at most (32 s)

## Off the skyship (or, `low`, a short drop into the sky over a small map or a respawn): freefall along `dir`.
static func start(h: Hunter, dir: Vector2, low := false) -> void:
	h.set_meta("deploy_h", LOW_DEPLOY_H if low else DEPLOY_H)
	h.dropping = true
	h.diving = false
	h.drop_glide = false
	h.gliding = true
	h.glide_k = 1.0
	h.grounded = false
	h.fall_dir = dir.normalized()       # (none: straight down until the keys pick a heading)
	h.set_meta("drop_t", (h.m as Match).time)      # (the camera's pull-out runs from here: DropCam)
	h.vel = Vector3(h.fall_dir.x, 0.0, h.fall_dir.y) * 3.0
	var k: Kin = h.kin
	if k != null and not k.dead and k.state == "active":
		KinFollow.hop_on(k)         # your Boki comes down on your back

## The freefall's velocity across for this step: the keys turn the heading, then dive, float or brake along it.
static func steer(h: Hunter, mv: Vector2, dt: float) -> Vector2:
	var D: DropSquad = (h.m as Match).skydrop
	if D:
		mv = D.comet.steer_off_abyss(h, mv)
	h.fall_dir = turned(h.fall_dir, Vector2(h.vel.x, h.vel.z), mv, dt)
	h.diving = h.fall_dir != Vector2.ZERO and mv.dot(h.fall_dir) > FORWARD_DOT
	return step_across(Vector2(h.vel.x, h.vel.z), h.fall_dir, mv, dt)

## The heading after the keys `mv` act on it for dt (barely moving across, they set it outright).
static func turned(dir: Vector2, hv: Vector2, mv: Vector2, dt: float) -> Vector2:
	if mv.length() <= 0.1:
		return dir
	if hv.length() < 1.0 or dir == Vector2.ZERO:
		return mv.normalized()
	var ang := dir.angle_to(mv)
	if absf(ang) < deg_to_rad(150.0):
		return dir.rotated(clampf(ang, -TURN_RATE * dt, TURN_RATE * dt))
	return dir

## The speed across after dt along `dir`: diving, floating or braking by how the keys sit on it.
static func step_across(hv: Vector2, dir: Vector2, mv: Vector2, dt: float) -> Vector2:
	if dir == Vector2.ZERO:
		return hv.lerp(Vector2.ZERO, 1.0 - exp(-STEER_RATE * dt))
	var along := mv.dot(dir)
	var float_at := lerpf(FLOAT_SPEED, BRAKE_SPEED, clampf(along / BACK_DOT, 0.0, 1.0))
	var speed := DIVE_SPEED if along > FORWARD_DOT else float_at
	return hv.lerp(dir * speed, 1.0 - exp(-STEER_RATE * dt))

## The freefall's vertical speed for this step.
static func fall_vy(h: Hunter, dt: float) -> float:
	var plunge := float(h.get_meta("deploy_h", DEPLOY_H)) < DEPLOY_H
	var sink := DIVE_FALL if h.diving or plunge else FLOAT_FALL
	return lerpf(h.vel.y, -sink, 1.0 - exp(-VY_RATE * dt))

## How high you are over what's below: the ground, or (over the abyss) the opening height there.
static func height_over(w: World, at: Vector3) -> float:
	if w.is_void(at.x, at.z):
		return at.y - (VOID_DEPLOY_Y - DEPLOY_H)
	return at.y - w.ground_at(at.x, at.z)

## Every step of a freefall: the glider opens by itself low down (a comet bursts instead).
static func tick(h: Hunter) -> void:
	var m: Match = h.m
	var opens_at := float(h.get_meta("deploy_h", DEPLOY_H))
	if not (m.skydrop and m.skydrop.comet.has(h)) and height_over(m.world, h.pos) < opens_at:
		h.deploy()

## Space in the freefall: a comet's rider breaks away; anyone else opens the glider.
static func space(h: Hunter) -> void:
	var D: DropSquad = (h.m as Match).skydrop
	if D and D.comet.has(h):
		D.separate(h)
	else:
		h.deploy()

## The landing at the end of a drop: a dust ring, a squash and a thud, a moment to get your bearings,
## and your Boki leaps off your back beside you.
static func land(h: Hunter) -> void:
	var m: Match = h.m
	h.dropping = false
	h.diving = false
	h.drop_glide = false
	if h.downed or h.out:
		return
	h.inv_t = maxf(h.inv_t, 2.0)
	h.set_meta("landed_t", m.time)     # bots leave a fresh lander be for a while (Bot.fresh)
	if m.world.is_block(h.pos.x, h.pos.z):
		var spot := m.world.free_spot_near(h.pos, [], 1.0, 0.45, 2.5)
		h.teleport(Vector3(spot.x, m.world.ground_at(spot.x, spot.z), spot.z))
	h.squash = LAND_SQUASH        # (the impact's dust and sound: DropFx, no self-shake: item 50)
	var k: Kin = h.kin
	if k != null and not k.dead and k.state == "shoulder" and k.cmd != "return":
		KinFollow.hop_off(k)
	if m.blight: m.blight.on_landed(h)
	if m.rolling: m.rolling.on_landed(h)

## Where `h` comes down if it keeps its keys `mv`: {at (y = the ground), void}. The freefall, then the glide.
static func project(h: Hunter, mv: Vector2) -> Dictionary:
	var m: Match = h.m
	var w: World = m.world
	var comet: bool = m.skydrop != null and m.skydrop.comet.has(h)
	var opens_at := DropComet.BURST_H if comet else float(h.get_meta("deploy_h", DEPLOY_H))
	var falling := h.dropping
	var p := h.pos
	var hv := Vector2(h.vel.x, h.vel.z)
	var vy := h.vel.y
	var dir := h.fall_dir
	for i in PROJECT_STEPS:
		var off := w.is_void(p.x, p.z)
		var gy: float = World.VOID if off else w.ground_at(p.x, p.z)
		if falling and height_over(w, p) < opens_at:
			if comet:
				return {"at": Vector3(p.x, 0.0 if off else gy, p.z), "void": off}
			falling = false
			vy = maxf(vy, DEPLOY_POP)
		if p.y <= (0.0 if off else gy):
			return {"at": Vector3(p.x, 0.0 if off else gy, p.z), "void": off}
		if falling:
			dir = turned(dir, hv, mv, PROJECT_STEP)
			hv = step_across(hv, dir, mv, PROJECT_STEP)
			var sink := DIVE_FALL if dir != Vector2.ZERO and mv.dot(dir) > FORWARD_DOT else FLOAT_FALL
			vy = lerpf(vy, -sink, 1.0 - exp(-VY_RATE * PROJECT_STEP))
		else:
			hv = Hunter.glide_steer(hv, mv * Hunter.GLIDE_SPEED, Hunter.GLIDE_SPEED, PROJECT_STEP)
			var pull := p.y - (0.0 if off else gy) > HunterMove.glide_height
			var sink_at := maxf(Hunter.GLIDE_SINK, HunterMove.glide_pull_vy) if pull else Hunter.GLIDE_SINK
			vy = move_toward(vy, -sink_at, Hunter.GLIDE_GRAV * PROJECT_STEP)
		p += Vector3(hv.x, vy, hv.y) * PROJECT_STEP
	return {"at": Vector3(p.x, 0.0, p.z), "void": true}

## The local player's keys on the way down when they let go: if the drop would come down over the
## abyss, it steers for the nearest island instead (as a bot would), so letting go never drops you
## into the void. Over solid ground it leaves you be: the float carries on.
static func assist(m: Match, h: Hunter) -> void:
	if (h.inp["move"] as Vector2).length() > 0.1:
		return
	var land := land_if_void(m, h, DEPLOY_H)
	if land != Vector3.INF:
		h.inp["move"] = keys_toward(h, land) if h.dropping else Vector2(land.x - h.pos.x, land.z - h.pos.z).normalized()

## If h's drop, carrying on as it is, would come down `low` m over the abyss: the nearest island spot
## to steer for. INF when it comes down on solid ground, or is more than ASSIST_LOOK_S off.
static func land_if_void(m: Match, h: Hunter, low: float) -> Vector3:
	var at := h.pos
	if h.dropping:
		var secs := maxf(0.0, height_over(m.world, h.pos) - low) / maxf(1.0, -h.vel.y) + ASSIST_GLIDE_S
		if secs > ASSIST_LOOK_S:
			return Vector3.INF
		at += Vector3(h.vel.x, 0.0, h.vel.z) * secs
	if not m.world.is_void(at.x, at.z):
		return Vector3.INF
	return nearest_land(m, at)

## The nearest island spot (the spawn and portal spots at island edges) to `at`, or INF.
static func nearest_land(m: Match, at: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := 1e9
	for sp in m.world.spawns + m.world.portal_spots:
		var d := Vector2(sp.x - at.x, sp.z - at.z).length()
		if d < best_d:
			best_d = d
			best = sp
	return best

## The freefall keys that bring h down on `land`: floating when it's far, diving when it's in reach,
## braking when it's nearly overhead (turning back if it's behind).
static func keys_toward(h: Hunter, land: Vector3) -> Vector2:
	var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
	var reach := to.length() / maxf(1.0, h.pos.y - maxf(land.y, 0.0) - DEPLOY_H)     # m across per m of fall
	var dir := to.normalized()
	var ahead := h.fall_dir.dot(dir)
	if reach < 0.35 or to.length() < 3.0:
		return dir if ahead < 0.0 else -h.fall_dir
	if ahead < 0.7 or reach > 0.85:
		return dir * 0.45          # turn first, or far: float for the reach
	return dir                     # in reach: dive

# ------------------------------------------------------------------ bots
## A bot's keys on the way down: for its spot (somewhere closer if it's out of reach); under the
## glider, straight for it.
static func bot_steer(m: Match, h: Hunter) -> void:
	var land: Vector3 = h.ai.get("land", h.pos)
	var to := Vector2(land.x - h.pos.x, land.z - h.pos.z)
	if not h.dropping:
		h.inp["move"] = to.normalized() if to.length() > 0.6 else Vector2.ZERO
		return
	var drop := maxf(1.0, h.pos.y - maxf(land.y, 0.0) - DEPLOY_H)
	if to.length() / drop > FLOAT_SPEED / FLOAT_FALL and not h.ai.get("retarget", false):
		h.ai["retarget"] = true
		h.ai["land"] = _bot_spot_in_reach(m, h, drop * FLOAT_SPEED / FLOAT_FALL * 0.85)
		return
	h.inp["move"] = keys_toward(h, land)

## The closest landing spot within `reach`, away from squads already heading somewhere close.
static func _bot_spot_in_reach(m: Match, h: Hunter, reach: float) -> Vector3:
	var best: Vector3 = h.ai.get("land", h.pos)
	var best_score := 1e9
	for sp in m.world.spawns + m.world.portal_spots:
		var d := Vector2(sp.x - h.pos.x, sp.z - h.pos.z).length()
		var score := (d if d < reach else d + 1000.0) + Bot.crowd_at(m, h, sp, Bot.LAND_SPREAD) * 30.0
		if score < best_score:
			best_score = score
			best = sp
	return best
