extends RefCounted
## --drop-feel-check: the opening drop (DropFeel). Prints PASS/FAIL lines.
##   1. the player's Boki is never downed or killed in the first 10 s of a normal match or the tutorial
##   2. steering ramps (no snapping), the dive is clearly faster than the glider, the flare slows the last metres
##   3. the reticle: projected landing matches where you land, sits on the ground, hides on landing; red over the void
##   4. no chests before the match proper: all hidden on the ship and the drop, all shown once you land
##   5. the rocket jump-out (DECISIONS 2026-11-11 drop): the free fall is slower than the rocket but still fast,
##      steers with the one air-control model (Loco.air_step), a fresh Space or glide-key press pulls the glider at
##      any height while Space held from the jump-out never does, and both ways land you unhurt and slowed
const FAST_FALL := 8.0          # m/s: the free fall is still at least this fast
const PULL_HEIGHTS := [90.0, 50.0, 20.0, 9.0]     # m above the ground the glider is pulled at in part 5
const SOFT_LAND := 3.0          # m/s: the most you hit the ground at, free fall or glider

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DROP %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _start(extra: Dictionary) -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	var o := {"teams": 2, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242, "demo_kin": "cindle"}
	o.merge(extra, true)
	m.start(o)
	m.set_process(false)

## Steps `secs` and returns the first sign that the player's Boki was hurt, downed or lost ("" if none).
func _watch_boki(secs: float, steer := Vector2.ZERO) -> String:
	var t := 0.0
	var k: Kin = m.player.kin
	var hp0 := k.hp
	while t < secs:
		# the ship waits during planning, and the match clock with it: not part of the window
		var planning: bool = m.skydrop != null and m.skydrop.planning
		m.player.inp["move"] = steer
		if m.opts.get("tutorial", false):
			m.tut.ack()      # (the intro card waits for a key)
		if t > 1.0 and m.player.riding:
			m.ship_jump(m.player, true)      # off the ship early, so the drop and landing fall inside the window
		m.step(Match.DT)
		if planning:
			continue
		t += Match.DT
		if (m.player.riding or m.player.dropping) and k.flat_dist(m.player) > 6.0:
			var gap := k.flat_dist(m.player)
			return "t=%.2fs left behind (%s, kin y %.1f), %.0f m from you" % [t, k.state, k.pos.y, gap]
		if k.dead or k.state == "downed" or k.hp < hp0 - 0.01:
			return "t=%.2fs state=%s hp=%.1f/%.1f at %s" % [t, k.state, k.hp, hp0, str(k.pos)]
	return ""

## A flat training arena with the player `h` metres up, dropping (diving) with the glider open.
func _arena(h: float) -> Hunter:
	_start({"training": true, "teams": 2, "no_drop": true, "length": 1e9, "weapon": "rifle", "cls": "medium"})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var W = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-40, 41):
		for dx in range(-40, 41):
			if not W.inb(hx + dx, hz + dz):
				continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for d in [W.stairs, W.walls, W.props, W.bush]:
				d.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL + h, hz + 0.5))
	P.vel = Vector3.ZERO
	P.dropping = true
	P.diving = true
	P.gliding = true
	P.grounded = false
	P.glide_k = 1.0
	return P

func _steering() -> void:
	var P := _arena(60.0)
	var prev := Vector2.ZERO
	var snap := 0.0
	var tmax := 0.0
	for i in 40:
		P.inp["move"] = Vector2(1, 0)
		m.step(Match.DT)
		var hv := Vector2(P.vel.x, P.vel.z)
		snap = maxf(snap, hv.distance_to(prev) / Match.DT)
		prev = hv
		tmax = maxf(tmax, hv.length())
	ok(snap <= Loco.air_accel + 1.0, "dive steering ramps (peak %.1f m/s^2)" % snap)
	ok(tmax > Hunter.DROP_SPEED * 1.4 and tmax <= Hunter.DIVE_SPEED + 0.1, "the dive tops out at %.1f m/s" % tmax)
	P.inp["move"] = Vector2.ZERO
	m.step(Match.DT)
	var left := Vector2(P.vel.x, P.vel.z).length()
	ok(left > tmax - DropFeel.BRAKE * Match.DT * 1.5, "letting go decelerates, it does not stop dead")

	var high := DropFeel.fall_vy(-13.0, 13.0, 7.0, 30.0, 0.1)
	var low := DropFeel.fall_vy(-13.0, 13.0, 7.0, 1.0, 0.1)
	ok(low > high + 1.0, "the flare slows the fall near the ground")

func _reticle() -> void:
	var P := _arena(14.0)
	P.diving = false
	P.inp["move"] = Vector2(0.6, 0.8)
	var pr: Dictionary = DropReticle.project(P, P.inp["move"])
	DropReticle.tick(P, 0.016)
	var r: DropReticle = P.get_node_or_null("DropReticle")
	ok(r != null and r.visible, "the reticle shows while dropping")
	var landed_at := Vector3.ZERO
	for i in 600:
		P.inp["move"] = Vector2(0.6, 0.8)
		m.step(Match.DT)
		if not P.dropping:
			landed_at = P.pos
			break
	var at: Vector3 = pr["at"]
	ok(not pr["void"] and absf(at.y - P.ground()) < 0.5, "the projected spot is on the real ground (y %.2f)" % at.y)
	var off := Vector2(at.x - landed_at.x, at.z - landed_at.z).length()
	ok(off < DropReticle.RADIUS, "you land inside the ring (off by %.2f m)" % off)
	DropReticle.tick(P, 0.016)
	ok(not r.visible, "the reticle hides on landing")
	# over the void: red warning
	P = _arena(14.0)
	P.diving = false
	var W = m.world
	var far := Vector2(1, 0)
	var pv: Dictionary = DropReticle.project(P, far)
	ok(not pv["void"], "steering over solid ground is not flagged")
	for dz in range(-40, 41):
		for dx in range(-40, 41):
			var i: int = W.idx(int(P.pos.x) + dx, int(P.pos.z) + dz)
			if W.inb(int(P.pos.x) + dx, int(P.pos.z) + dz) and dx > 8:
				W.kind[i] = World.T_VOID
	ok(DropReticle.project(P, far)["void"], "a projected spot over the void is flagged")

## One step of the player's keys as Match reads them: Space jumps (a press) and is held, the glide key likewise.
func _keys(P: Hunter, mv: Vector2, space: bool, space_press: bool, glide_key := false) -> void:
	P.inp["move"] = mv
	P.inp["jump"] = space_press
	P.inp["glide_press_only"] = true
	P.inp["glide"] = space or glide_key
	P.inp["glide_btn"] = glide_key

## A squad match with the player aboard its rocket `ride` seconds after the launch.
func _rocket(ride: float) -> DropRocket:
	_start({"teams": 2, "squad": 3, "seed": 4242})
	m.skydrop.planning = false
	for i in int(6.0 / Match.DT):
		m.step(Match.DT)
	m.ship_jump(m.player)
	for i in int(ride / Match.DT):
		m.step(Match.DT)
	return m.player.rocket

## Space pressed aboard: you jump out. Then Space stays held for `hold` s.
func _jump_out(hold: float) -> void:
	_keys(m.player, Vector2.ZERO, true, true)
	m.step(Match.DT)
	for i in int(hold / Match.DT):
		_keys(m.player, Vector2.ZERO, true, false)
		m.step(Match.DT)

func _rocket_fall() -> void:
	var r := _rocket(1.0)
	var P: Hunter = m.player
	_jump_out(1.2)
	var fall := -P.vel.y
	ok(P.dropping and P.rocket == null, "Space aboard the rocket jumps you out")
	ok(fall < DropRocket.FALL and fall > FAST_FALL,
			"the free fall (%.1f m/s) is slower than the rocket (%.1f m/s), still fast" % [fall, DropRocket.FALL])
	var ry := r.pos.y if r else 0.0
	ok(r != null and P.pos.y > ry + 3.0, "the rocket pulls away below you (%.1f m vs %.1f m)" % [P.pos.y, ry])
	ok(P.diving, "Space held from the jump-out never opens the glider (1.2 s held, still free-falling)")

## The free fall steers with Loco.air_step, the air control every jump has: one model, DECISIONS 2026-11-08.
func _rocket_steer() -> void:
	_rocket(1.0)
	var P: Hunter = m.player
	_jump_out(0.2)
	var worst := 0.0
	var turn_t := -1.0
	var t := 0.0
	for mv in [Vector2(1, 0), Vector2(-1, 0), Vector2.ZERO, Vector2(0, 1)]:
		for i in int(0.6 / Match.DT):
			var hv0 := Vector2(P.vel.x, P.vel.z)
			_keys(P, mv, false, false)
			m.step(Match.DT)
			t += Match.DT
			var want := Loco.air_step(hv0, mv, Hunter.DIVE_SPEED, Match.DT)
			worst = maxf(worst, want.distance_to(Vector2(P.vel.x, P.vel.z)))
			if mv.x < 0.0 and turn_t < 0.0 and P.vel.x < 0.0:
				turn_t = t - 0.6
	ok(P.diving and worst < 0.01,
			"free-fall steering is Loco.air_step at %.0f m/s (worst step off by %.3f m/s)" % [Hunter.DIVE_SPEED, worst])
	ok(turn_t > 0.0 and turn_t < 0.5, "counter-steer turns the fall around in %.2f s" % turn_t)

## A fresh press pulls the glider wherever you are; Space or the glide key held from before never does.
func _rocket_pull() -> void:
	_rocket(0.5)
	var P: Hunter = m.player
	_jump_out(0.1)
	_keys(P, Vector2.ZERO, false, false)
	m.step(Match.DT)
	_keys(P, Vector2.ZERO, true, true)
	m.step(Match.DT)
	ok(not P.diving and P.dropping, "a second Space press after the jump-out opens the glider (%.0f m up)" % P.pos.y)
	_rocket(0.5)
	P = m.player
	_keys(P, Vector2.ZERO, false, false, true)      # the glide key held aboard, then Space to jump out
	m.step(Match.DT)
	_keys(P, Vector2.ZERO, true, true, true)
	m.step(Match.DT)
	for i in int(1.0 / Match.DT):
		_keys(P, Vector2.ZERO, false, false, true)
		m.step(Match.DT)
	ok(P.dropping and P.diving, "the glide key held from aboard through the jump-out never opens the glider")
	for h in PULL_HEIGHTS:
		for glide_key in [false, true]:
			P = _arena(h)
			_keys(P, Vector2.ZERO, not glide_key, false)      # Space held from before (or nothing): no press
			m.step(Match.DT)
			var held_shut := P.diving
			_keys(P, Vector2.ZERO, not glide_key, not glide_key, glide_key)
			m.step(Match.DT)
			var how := "the glide key" if glide_key else "Space"
			var what := "a fresh %s press pulls the glider %.0f m up (falling before it: %s)" % [how, h, held_shut]
			ok(held_shut and not P.diving, what)

## Never pulled, the glider opens itself near the ground; either way you touch down slowly and unhurt.
func _rocket_land() -> void:
	for pull in [false, true]:
		var P := _arena(60.0)
		var hurt0 := P.dmg_taken      # (hp only near the ground: the training arena scratches you to 70% at 1 s)
		var hp_low := -1.0
		var vy := 0.0
		var t := 0.0
		while t < 40.0 and P.dropping:
			_keys(P, Vector2.ZERO, false, pull and t < Match.DT * 0.5)      # (keys would leave the 40 m arena)
			vy = P.vel.y
			if hp_low < 0.0 and P.pos.y - P.ground() < 3.0:
				hp_low = P.hp
			m.step(Match.DT)
			t += Match.DT
		var tag := "glider pulled 60 m up" if pull else "never pulled"
		var down := P.grounded and not P.out and absf(P.pos.y - P.ground()) < 0.05
		ok(down, "%s: down on the ground in %.1f s" % [tag, t])
		var hurt := P.dmg_taken - hurt0 + maxf(0.0, hp_low - P.hp)
		ok(-vy <= SOFT_LAND and hurt <= 0.0, "%s: touches down at %.1f m/s, unhurt (%.0f damage)" % [tag, -vy, hurt])

## How many of the match's chests are hidden.
func _hidden_chests() -> int:
	return m.chests.filter(func(c): return not (c["node"] as Node3D).visible).size()

## Every chest was hidden at the start (`hid` of them), and none is once you've landed (steps up to 30 s for that).
func _chests_wait(what: String, hid: int) -> void:
	var t := 0.0
	while t < 30.0 and (m.player.riding or m.player.dropping):
		if m.player.riding:
			m.ship_jump(m.player, true)
		m.step(Match.DT)
		t += Match.DT
	var landed: bool = not (m.player.riding or m.player.dropping)
	var info := "%d of %d hidden at the start, %d now, landed %s" % [hid, m.chests.size(), _hidden_chests(), landed]
	ok(not m.chests.is_empty() and hid == m.chests.size() and landed and _hidden_chests() == 0,
			"%s: no chest shows before you land, all once you have (%s)" % [what, info])

## Tutorial: no chest shows before you land (however many the level has), and every one does once you have.
func _tutorial_chests_wait() -> void:
	var seen := m.chests.size() - _hidden_chests()
	var t := 0.0
	while t < 30.0 and (m.player.riding or m.player.dropping):
		if m.player.riding:
			m.ship_jump(m.player, true)
		m.step(Match.DT)
		t += Match.DT
	var landed: bool = not (m.player.riding or m.player.dropping)
	var n := m.chests.size()
	var info := "%d of %d visible before landing, %d now, landed %s" % [seen, n, n - _hidden_chests(), landed]
	ok(seen == 0 and landed and _hidden_chests() == 0,
			"tutorial: no chest shows before you land, the level's chests do once you have (%s)" % info)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_steering()
	_reticle()
	_rocket_fall()
	_rocket_steer()
	_rocket_pull()
	_rocket_land()
	for steer in [Vector2.ZERO, Vector2(1, 0)]:
		_start({})
		var hid := _hidden_chests()
		var why := _watch_boki(12.0, steer)
		print("  normal steer=", steer, " ", why)
		ok(why == "", "normal match, steer %s: your Boki rides with you and is untouched for 12 s" % str(steer))
		_chests_wait("normal match, steer %s" % str(steer), hid)
	_start({"tutorial": true, "teams": 1, "length": 1500.0})
	var tw := _watch_boki(12.0)
	print("  tutorial ", tw)
	ok(tw == "", "tutorial: your Boki rides with you and is untouched for 12 s")
	_tutorial_chests_wait()
	print("DROP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
