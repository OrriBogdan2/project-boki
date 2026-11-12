extends RefCounted
## --drop-rocket-check: the squad mini rocket drop (DropRocket, owner 2026-11-11).
##  1. Doing nothing, the whole squad lands together where the rocket hits (within TOGETHER_M of each other).
##  2. Someone who jumps out free-falls slower than the rocket, but still fast (over FAST_FALL m/s).
##  3. Jumping out and opening the glider at once goes further than jumping out and free-falling.
##  4. Nobody lands in a wall, under the ground or on top of a squadmate (several launches, steered ones too).
##  5. A bot leader flies the rocket to its landing spot (within BOT_SPOT_M).
##  6. Every one of the 12 Hunters rides it standing on a peg with both hands on the bar: no T-pose (the hands within
##     RideProbe.GRIP_M of the bar, hands close together), the feet on the peg and never inside the hull,
##     and no pop (a pose step over RIDE_POP_M, or over BLEND_POP_M while it eases in). Measured in the rocket's frame.

const TOGETHER_M := 4.0          # m: the widest gap between two squadmates who rode it down
const FAST_FALL := 8.0           # m/s: a free fall is still at least this fast
const BOT_SPOT_M := 8.0          # m from a bot leader's landing spot
const LAUNCHES := [2.0, 6.0, 10.0, 14.0]      # s into the ship's run, for check 4
const STEER_S := 1.5             # s the leader holds the keys in check 4
const STEERS := [Vector2.ZERO, Vector2(1, 0), Vector2(0, -1), Vector2(-0.7, 0.7)]
const RIDE_POP_M := 0.03         # m: the most a hand or foot moves between two frames once the pose has settled
const BLEND_POP_M := 0.3         # m: the same while the pose eases in on the launch or out on the jump
const JUMP_S := 0.6              # s after the jump out measured (the ride pose eases out, the skydive in)
const RIDE_S := 1.2              # s measured once the pose has settled (it eases in over about 0.5 s)

var bad := 0
var main: Node
var m: Match

func ok(cond: bool, what: String) -> void:
	print("ROCKET %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A three-a-side squad match, the planning phase skipped, everyone aboard, `ride` seconds into the run.
func _start(ride: float) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1500.0, "seed": 4242})
	m.set_process(false)
	m.skydrop.planning = false
	for i in int(ride / Match.DT):
		m.step(Match.DT)

func _squad() -> Array:
	return m.hunters.filter(func(h): return h.team == m.player.team)

## Steps until nobody of the squad is in the air (or `cap` seconds).
func _land(cap := 40.0, steer := Vector2.ZERO) -> float:
	var t := 0.0
	while t < cap and _squad().any(func(h): return h.riding or h.dropping):
		m.player.inp["move"] = steer
		m.step(Match.DT)
		t += Match.DT
	return t

func _spread(hs: Array) -> float:
	var worst := 0.0
	for a in hs:
		for b in hs:
			worst = maxf(worst, (a as Hunter).flat_dist((b as Hunter).pos))
	return worst

func _together() -> void:
	await _start(6.0)
	m.ship_jump(m.player)
	var r: DropRocket = m.player.rocket
	var n := r.riders.size() if r else 0
	ok(n == 3, "the leader's launch puts the whole squad in one rocket (%d aboard)" % n)
	var y0 := m.player.pos.y
	var t := _land()
	var sq := _squad()
	var down := sq.all(func(h): return h.grounded and not h.riding and not h.dropping)
	ok(down, "everyone is down %.1f s after a %.0f m launch" % [t, y0])
	ok(_spread(sq) <= TOGETHER_M, "the squad lands together (widest gap %.1f m)" % _spread(sq))

func _free_fall() -> void:
	await _start(6.0)
	m.ship_jump(m.player)
	var r: DropRocket = m.player.rocket
	for i in int(1.5 / Match.DT):
		m.step(Match.DT)
	m.skydrop.detach(m.player)
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	var P: Hunter = m.player
	ok(P.dropping and P.diving and P.rocket == null, "jumping out is a free fall")
	var fall := -P.vel.y
	var what := "the free fall (%.1f m/s) is slower than the rocket (%.1f m/s), still fast" % [fall, -r.vel.y]
	ok(fall < -r.vel.y and fall > FAST_FALL, what)
	ok(P.pos.y > r.pos.y + 5.0, "a second later you're above the rocket (%.1f m vs %.1f m)" % [P.pos.y, r.pos.y])

## Flat distance from where you jump out to where you come down (or drop below the islands).
func _jump_out_dist(glide: bool) -> float:
	await _start(6.0)
	m.ship_jump(m.player)
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	var P: Hunter = m.player
	var sd: Vector3 = m.ship_of(P)["dir"]
	m.skydrop.detach(P)
	var from := P.pos
	if glide:
		P.do_jump()
	var t := 0.0
	while t < 60.0 and P.dropping and P.pos.y > 0.0:
		P.inp["move"] = Vector2(sd.x, sd.z).normalized()
		m.step(Match.DT)
		t += Match.DT
	return P.flat_dist(from)

func _glide_further() -> void:
	var fall := await _jump_out_dist(false)
	var glide := await _jump_out_dist(true)
	ok(glide > fall * 1.3, "the glider goes further (%.0f m) than the free fall (%.0f m)" % [glide, fall])

## Where everyone stood after landing: on open ground, at ground height, apart.
func _clean_landing(tag: String) -> void:
	var W: World = m.world
	var sq := _squad()
	for h in sq:
		var hh: Hunter = h
		if hh.out or hh.pos.y < -1.0:
			ok(false, "%s: %s fell out" % [tag, hh.pname])
			continue
		var g: float = W.ground_at(hh.pos.x, hh.pos.z)
		var open := not W.is_void(hh.pos.x, hh.pos.z) and not W.is_block(hh.pos.x, hh.pos.z)
		var clean := open and absf(hh.pos.y - g) < 0.05
		ok(clean, "%s: %s landed on open ground (y %.2f, ground %.2f)" % [tag, hh.pname, hh.pos.y, g])
		for o in sq:
			if o != h and hh.flat_dist((o as Hunter).pos) < 0.8:
				ok(false, "%s: %s landed on top of %s" % [tag, hh.pname, (o as Hunter).pname])

func _no_clipping() -> void:
	for i in LAUNCHES.size():
		await _start(LAUNCHES[i])
		m.ship_jump(m.player)
		_land(STEER_S, STEERS[i])      # steer a while, then let go: it lands wherever that leaves it
		_land()
		_clean_landing("launch at %.0f s, steering %s" % [LAUNCHES[i], str(STEERS[i])])

func _bot_leader() -> void:
	await _start(6.0)
	var bot: Hunter = _squad().filter(func(h): return h.ctrl == "bot")[0]
	m.skydrop.pass_lead(m.player, bot)
	var sd: Vector3 = m.ship["dir"]
	var ahead := m.ship_pos() + sd * 40.0 + Vector3(-sd.z, 0, sd.x) * 20.0
	var spot: Vector3 = m.world.free_spot_near(Vector3(ahead.x, 0, ahead.z), [], 1.0, 0.5, 40.0)
	m.skydrop._set_land(bot, spot)
	m.ship_jump(bot, true)
	_land()
	ok(bot.flat_dist(spot) <= BOT_SPOT_M, "a bot leader lands the squad on its spot (%.1f m off)" % bot.flat_dist(spot))
	var gap := _spread(_squad())
	ok(gap <= TOGETHER_M, "with the bot leading, the squad still lands together (%.1f m)" % gap)
	_clean_landing("bot leader")

## One match step and one engine frame, every hunter posed as the game's render does (a .glb Hero's skeleton follows).
func _frame() -> void:
	m.step(Match.DT)
	for h in m.hunters:
		h.render(Match.DT, 1.0)
	await main.get_tree().process_frame

## Check 6: each Hunter's ride, from the launch, through the settled pose, to the jump-out.
func _ride_pose(arch: String) -> void:
	await _start(6.0)
	var P := m.player
	P.reclass(Arch.weight(arch), arch)
	for i in 3:
		await _frame()      # (the new model is dressed and posed first)
	m.ship_jump(P)
	var r: DropRocket = P.rocket
	var worst := {"grip": 0.0, "hull": 9.0, "peg": 0.0, "pop": 0.0, "blend": 0.0, "len": 0.0, "up": 1.0}
	var prev: Array = []
	var t := 0.0
	var bar_hit := false
	while t < 0.6 + RIDE_S and P.rocket == r:
		await _frame()
		t += Match.DT
		var now := RideProbe.limbs(P, r)
		var settled := t > 0.6
		if not prev.is_empty() and t > 2.5 * Match.DT:      # (the first frame is the rider's first on show)
			for i in 4:
				var step: float = (now[i] as Vector3).distance_to(prev[i])
				var kind := "pop" if settled else "blend"
				worst[kind] = maxf(worst[kind], step)

		prev = now
		if not settled:
			continue
		var fit := RideProbe.fit(P, r)
		worst["grip"] = maxf(worst["grip"], fit["grip"])
		worst["hull"] = minf(worst["hull"], fit["hull"])
		worst["peg"] = maxf(worst["peg"], fit["peg"])
		worst["len"] = maxf(worst["len"], fit["len"])
		worst["up"] = fit["up"]
		bar_hit = true
	var shown: bool = bar_hit and P.visible and P.anim.ride_k > 0.99
	worst["leap"] = await _jump_off(P, r)
	var w: Dictionary = worst
	var fmt := " (%s: grip %.2f m, bar %.2f body sizes long, %.2f m up, hull gap %.2f m, peg %.2f m,"
	var out := (fmt + " pop %.3f / blend %.3f / jump out %.3f m)") % [
		arch, w["grip"], w["len"], w["up"], w["hull"], w["peg"], w["pop"], w["blend"], w["leap"]]
	ok(shown, "%s rides the rocket on show, the pose fully in%s" % [arch, out])
	var bar_ok: bool = w["grip"] <= RideProbe.GRIP_M and w["len"] <= RideProbe.BAR_LEN_MAX
	bar_ok = bar_ok and w["up"] >= RideProbe.BAR_UP.x and w["up"] <= RideProbe.BAR_UP.y
	ok(bar_ok, "%s holds the bar with both hands, no T-pose%s" % [arch, out])
	var feet_ok: bool = w["hull"] >= -RideProbe.HULL_SLACK_M and w["peg"] <= RideProbe.PEG_M
	ok(feet_ok, "%s's feet stand on the peg, none through the hull%s" % [arch, out])
	var smooth: bool = w["pop"] <= RIDE_POP_M and w["blend"] <= BLEND_POP_M and w["leap"] <= BLEND_POP_M
	ok(smooth, "%s's ride pose has no pop in it, on the way in or on the jump out%s" % [arch, out])

## The jump out: how far the body starts from where it stood on its peg (not the rocket's middle), then the most a
## hand or foot moves in a frame round the body as the ride eases out into the skydive (no snap of the body's turn).
func _jump_off(P: Hunter, r: DropRocket) -> float:
	if P.rocket != r:
		return 9.0
	var stood := P.global_position
	r.detach(P)
	var worst := P.pos.distance_to(stood)
	var was: Array = []
	for i in int(JUMP_S / Match.DT):
		await _frame()
		var now := RideProbe.world(P).map(func(p: Vector3) -> Vector3: return p - P.global_position)
		for k in 4 if not was.is_empty() else 0:
			worst = maxf(worst, (now[k] as Vector3).distance_to(was[k]))
		was = now
	return worst

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	await _together()
	await _free_fall()
	await _glide_further()
	await _no_clipping()
	await _bot_leader()
	for arch in Arch.ORDER:
		await _ride_pose(arch)
	if m:
		m.queue_free()
	print("ROCKET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
