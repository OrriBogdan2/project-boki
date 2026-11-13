extends RefCounted
## --drop-rocket-check: the squad mini rocket drop (DropRocket, owner 2026-11-11).
##  1. Doing nothing, the whole squad lands together where the rocket hits (within TOGETHER_M of each other).
##  2. Someone who jumps out free-falls slower than the rocket, but still fast (over FAST_FALL m/s).
##  3. Jumping out and opening the glider at once goes further than jumping out and free-falling.
##  4. Nobody lands in a wall, under the ground or on top of a squadmate (several launches, steered ones too).
##  5. A bot leader flies the rocket to its landing spot (within BOT_SPOT_M).
##  6. Aboard, everyone is drawn clinging on outside the hull, each in their own seat; jumping out lets go of it.

const TOGETHER_M := 4.0          # m: the widest gap between two squadmates who rode it down
const FAST_FALL := 8.0           # m/s: a free fall is still at least this fast
const BOT_SPOT_M := 8.0          # m from a bot leader's landing spot
const LAUNCHES := [2.0, 6.0, 10.0, 14.0]      # s into the ship's run, for check 4
const STEER_S := 1.5             # s the leader holds the keys in check 4
const STEERS := [Vector2.ZERO, Vector2(1, 0), Vector2(0, -1), Vector2(-0.7, 0.7)]
const HULL_R := 0.75             # m: the rocket's body radius (DropRocket._model)
const SEAT_GAP_M := 1.0          # m at least between two riders' feet

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
	_seats(r)
	m.skydrop.detach(m.player)
	for i in int(1.0 / Match.DT):
		m.step(Match.DT)
	var P: Hunter = m.player
	P.render(Match.DT, 1.0)
	ok(P.model.position == Vector3.ZERO, "jumping out lets go of the rocket (the body back on the hunter)")
	ok(P.dropping and P.diving and P.rocket == null, "jumping out is a free fall")
	var fall := -P.vel.y
	var what := "the free fall (%.1f m/s) is slower than the rocket (%.1f m/s), still fast" % [fall, -r.vel.y]
	ok(fall < -r.vel.y and fall > FAST_FALL, what)
	ok(P.pos.y > r.pos.y + 5.0, "a second later you're above the rocket (%.1f m vs %.1f m)" % [P.pos.y, r.pos.y])

func _seats(r: DropRocket) -> void:
	var feet: Array = []
	for h in r.riders:
		(h as Hunter).render(Match.DT, 1.0)
		var at: Vector3 = (h as Hunter).model.global_position - r.node.position
		var out := (at - r.node.basis.y * at.dot(r.node.basis.y)).length()
		ok(h.visible and out > HULL_R and out < HULL_R + 1.0,
				"%s rides on show, clinging on %.2f m from the rocket's axis" % [h.pname, out])
		for f in feet:
			var gap := at.distance_to(f)
			ok(gap > SEAT_GAP_M, "%s has a seat of their own (%.2f m to the next)" % [h.pname, gap])
		feet.append(at)

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

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	await _together()
	await _free_fall()
	await _glide_further()
	await _no_clipping()
	await _bot_leader()
	if m:
		m.queue_free()
	print("ROCKET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
