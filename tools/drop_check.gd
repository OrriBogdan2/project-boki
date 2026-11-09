extends RefCounted
## --drop-feel-check: the opening drop (DropFeel). Prints PASS/FAIL lines.
##   1. the player's Boki is never downed or killed in the first 10 s of a normal match or the tutorial
##   2. steering ramps (no snapping), the dive is clearly faster than the glider, the flare slows the last metres
##   3. the reticle: projected landing matches where you land, sits on the ground, hides on landing; red over the void
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
	ok(snap <= DropFeel.DIVE_ACCEL + 1.0, "dive steering ramps (peak %.1f m/s^2)" % snap)
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

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_steering()
	_reticle()
	for steer in [Vector2.ZERO, Vector2(1, 0)]:
		_start({})
		var why := _watch_boki(12.0, steer)
		print("  normal steer=", steer, " ", why)
		ok(why == "", "normal match, steer %s: your Boki rides with you and is untouched for 12 s" % str(steer))
	_start({"tutorial": true, "teams": 1, "length": 1500.0})
	var tw := _watch_boki(12.0)
	print("  tutorial ", tw)
	ok(tw == "", "tutorial: your Boki rides with you and is untouched for 12 s")
	print("DROP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
