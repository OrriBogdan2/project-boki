extends RefCounted
## --drop-feel-check: the opening drop (DropFeel, docs/MOVEMENT_FEEL.md "The expedition drop against the source").
##   1. the player's Boki is never downed or killed through the drop of a normal match or the tutorial
##   2. parity: the glider steers with the glide's force toward its speed, a quarter of it in the dive [game data];
##      the dive opens 3.5 m up and the canopy sinks at the source's high-glide pull; the landing is a low
##      crouch you walk out of at once [footage]; the drop off the skyship lasts 18-22 s (owner)
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

## One measured value against its target, as --move-feel-check prints them.
func row(key: String, v: float, lo: float, hi: float, unit: String, src: String) -> void:
	var good := v >= lo and v <= hi
	var tag := "PASS" if good else "FAIL"
	print("DROP %s %s = %.2f %s target %.2f-%.2f (%s)" % [tag, key, v, unit, lo, hi, src])
	if not good: bad += 1

## Steps with `mv` held until the flat speed reaches 90% of the glide speed; the time it took, the peak
## acceleration and the top speed seen over `steps`.
func _push(P: Hunter, mv: Vector2, steps: int) -> Dictionary:
	var prev := Vector2(P.vel.x, P.vel.z)
	var out := {"t90": 9.0, "snap": 0.0, "top": 0.0}
	for i in steps:
		P.inp["move"] = mv
		m.step(Match.DT)
		var hv := Vector2(P.vel.x, P.vel.z)
		out["snap"] = maxf(out["snap"], hv.distance_to(prev) / Match.DT)
		out["top"] = maxf(out["top"], hv.length())
		if out["t90"] > 8.0 and hv.length() >= 0.9 * Hunter.GLIDE_SPEED: out["t90"] = (i + 1) * Match.DT
		prev = hv
	return out

func _parity() -> void:
	var quarter: float = Hunter.GLIDE_ACCEL * HunterMove.dive_steer
	# the dive: a quarter of the glide's steering force, falling faster than the canopy
	var P := _arena(60.0)
	var d := _push(P, Vector2(1, 0), 120)
	row("dive_steer_t", d["t90"], 0.9, 1.3, "s",
			"[game data] GlideDiveXYForceMultiplier 0.25 x %.2f m/s^2" % Hunter.GLIDE_ACCEL)
	ok(d["snap"] <= quarter + 1.0 and d["top"] <= Hunter.GLIDE_SPEED + 0.1,
			"dive steering ramps (peak %.1f m/s^2, top %.1f m/s)" % [d["snap"], d["top"]])
	ok(absf(-P.vel.y - Hunter.DIVE_FALL) < 0.1 and Hunter.DIVE_FALL > Hunter.DROP_FALL,
			"the dive falls at %.1f m/s, faster than the canopy's %.1f" % [-P.vel.y, Hunter.DROP_FALL])
	P.inp["move"] = Vector2.ZERO
	m.step(Match.DT)
	var kept: bool = Vector2(P.vel.x, P.vel.z).length() > d["top"] - Hunter.GLIDE_ACCEL * Match.DT * 1.5
	ok(kept, "letting go decelerates, it does not stop dead")
	var open_h := -1.0
	for i in 900:
		m.step(Match.DT)
		if not P.diving:
			open_h = P.pos.y - P.ground()
			break
	row("deploy_h", open_h, 3.0, 3.6, "m", "[game data] GlideDiveCancelDistance 350 uu: the glide catches you")
	# under the canopy: the glide's own force and speed, the high glide's sink
	P = _arena(20.0)
	P.diving = false
	var g := _push(P, Vector2(0, 1), 60)
	row("drop_glide_steer_t", g["t90"], 0.0, 0.35, "s", "[game data] GlideTargetXYForce 162,500 / 100 kg")
	row("drop_glide_speed", g["top"], Hunter.GLIDE_SPEED * 0.9, Hunter.GLIDE_SPEED * 1.1, "m/s",
			"[game data] MaxGlide 500 uu/s")
	row("drop_sink", -P.vel.y, 3.4, 3.6, "m/s", "[game data] GlideDownwardForceMinZVelocity -350 uu/s")
	# the landing: a low crouch, and you walk out of it the same step
	P.inp["move"] = Vector2.ZERO
	for i in 900:
		m.step(Match.DT)
		if P.grounded: break
	ok(P.grounded, "the drop lands")
	row("land_squash", P.squash, 0.3, 1.0, "", "[footage] a low crouch on every landing")
	var moving_t := 9.0
	for i in 12:
		P.inp["move"] = Vector2(1, 0)
		m.step(Match.DT)
		if Vector2(P.vel.x, P.vel.z).length() > 1.0:
			moving_t = (i + 1) * Match.DT
			break
	row("land_recover_t", moving_t, 0.0, 0.2, "s", "[footage] up and moving in ~0.15 s, no lockout")
	var dur := _land_clip_durs()
	row("land_clip_dur", dur["lo"], 0.3, 0.5, "s",
			"[footage] every big move ends in a ~0.4-0.5 s low crouch (shortest clip)")
	row("land_clip_dur", dur["hi"], 0.3, 0.5, "s", "[footage] the same (longest clip)")
	var high := DropFeel.fall_vy(-Hunter.DIVE_FALL, Hunter.DIVE_FALL, Hunter.DIVE_VY_RATE, 30.0, 0.1)
	var low := DropFeel.fall_vy(-Hunter.DIVE_FALL, Hunter.DIVE_FALL, Hunter.DIVE_VY_RATE, 1.0, 0.1)
	ok(low > high + 1.0, "the flare slows the fall near the ground")

## The shortest and longest landing clip in content/rules/warden_anim (the pose you land in, and for how long).
func _land_clip_durs() -> Dictionary:
	var out := {"lo": 9.0, "hi": 0.0}
	for f in DirAccess.get_files_at("res://content/rules/warden_anim"):
		if not f.ends_with(".json"): continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/warden_anim/" + f))
		if d == null or not d.has("land"): continue
		var dur := float(d["land"].get("dur", 0.0))
		out["lo"] = minf(out["lo"], dur)
		out["hi"] = maxf(out["hi"], dur)
	return out

## Off the skyship to the ground in a normal match: how long, and how high the glider opens.
func _timing() -> void:
	_start({})
	var P: Hunter = m.player
	var t := -1.0
	var open_h := -1.0
	for i in 3000:
		if m.skydrop != null and m.skydrop.planning:
			m.step(Match.DT)
			continue
		if P.riding and t < 0.0:
			m.ship_jump(P, true)
			t = 0.0
		m.step(Match.DT)
		if t < 0.0: continue
		t += Match.DT
		if open_h < 0.0 and P.launch_at < 0.0:
			open_h = P.pos.y      # (the islands sit near y 0; the ground under the ship may be void)
		if not P.dropping: break
	row("drop_open_y", open_h, 40.0, 70.0, "m up", "owner: a high start, a long readable glide down")
	row("drop_time_s", t, 18.0, 22.0, "s", "owner: the skyship to the ground in 18-22 s")

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
	_parity()
	_reticle()
	_timing()
	for steer in [Vector2.ZERO, Vector2(1, 0)]:
		_start({})
		var why := _watch_boki(24.0, steer)
		print("  normal steer=", steer, " ", why)
		ok(why == "", "normal match, steer %s: your Boki rides with you and is untouched for 24 s" % str(steer))
	_start({"tutorial": true, "teams": 1, "length": 1500.0})
	var tw := _watch_boki(24.0)
	print("  tutorial ", tw)
	ok(tw == "", "tutorial: your Boki rides with you and is untouched for 24 s")
	print("DROP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
