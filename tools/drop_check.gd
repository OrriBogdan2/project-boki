extends RefCounted
## --drop-feel-check: the opening drop (DropFeel). Prints PASS/FAIL lines.
##   1. the player's Boki is never downed or killed in the first 10 s of a normal match or the tutorial
##   2. steering ramps (no snapping), the dive is clearly faster than the glider, the flare slows the last metres
##   3. the reticle: projected landing within RETICLE_M of where you land (canopy and dive), sits on the ground,
##      hides on landing; red over the void
##   4. no chests before the match proper: all hidden on the ship and the drop, all shown once you land
##   5. decision 0049, from the ship's height: a straight dive lands in DIVE_S, the canopy opens by itself at
##      DropFeel.open_h, a canopy open from the top lands in CANOPY_S with CANOPY_REACH_M of flat reach, crouch
##      held dives and letting go opens the canopy, a soft landing draws no ring, and the dive view (wider,
##      tipped down) is back to the usual view within VIEW_BACK_S of landing
const DIVE_S := [6.5, 7.5]
const CANOPY_S := [21.0, 23.0]
const CANOPY_REACH_M := 190.0
const RETICLE_M := 2.0
const VIEW_BACK_S := 1.0
const WRAP_M := 20.0          # the arena is 40 m to a side: a long glide is stepped back this far to stay on it
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
	ok(snap <= DropFeel.dive_accel + 1.0, "dive steering ramps (peak %.1f m/s^2)" % snap)
	ok(tmax > DropFeel.canopy_speed * 1.4 and tmax <= DropFeel.dive_speed + 0.1, "the dive tops out at %.1f m/s" % tmax)
	P.inp["move"] = Vector2.ZERO
	m.step(Match.DT)
	var left := Vector2(P.vel.x, P.vel.z).length()
	ok(left > tmax - DropFeel.brake * Match.DT * 1.5, "letting go decelerates, it does not stop dead")

	var high := DropFeel.fall_vy(-DropFeel.dive_fall, true, 30.0, 0.1)
	var low := DropFeel.fall_vy(-DropFeel.dive_fall, true, 1.0, 0.1)
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
	ok(off < RETICLE_M, "you land where the ring says, under the canopy (off by %.2f m)" % off)
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

## Steps `P` down to the ground with these keys, ticking the drop's view as a frame would. Returns the
## seconds it took, the flat metres covered, the height the canopy opened at (-1: it never changed), the
## widest field of view and steepest tilt on the way, and how far it was stepped back to stay on the arena.
func _fall(P: Hunter, mv: Vector2, crouch_until := -1.0) -> Dictionary:
	var out := {"t": 0.0, "flat": 0.0, "open_h": -1.0, "fov": 0.0, "tilt": 0.0, "wrapped": 0.0}
	var x0 := P.pos.x
	while P.dropping and out["t"] < 60.0:
		P.inp["move"] = mv
		P.inp["crouch"] = P.pos.y - P.ground() > crouch_until and crouch_until >= 0.0
		var was := P.diving
		var before := P.pos
		m.step(Match.DT)
		DropView.tick(m, Match.DT)
		out["t"] += Match.DT
		out["flat"] += Vector2(P.pos.x - before.x, P.pos.z - before.z).length()
		out["fov"] = maxf(out["fov"], m.cam.fov)
		out["tilt"] = maxf(out["tilt"], m.cam.dive_tilt)
		if was and not P.diving:
			out["open_h"] = P.pos.y - P.ground()
		if P.pos.x - x0 > WRAP_M:
			P.pos.x -= WRAP_M
			P.prev.x -= WRAP_M
			out["wrapped"] += WRAP_M
	P.inp["crouch"] = false
	return out

func _height() -> void:
	var top := DropFeel.ship_height
	# a straight dive: no keys (a drop with no ship starts in the dive)
	var P := _arena(top)
	var mv := Vector2(0.3, 0.2)
	var pr: Dictionary = DropReticle.project(P, mv)
	var usual := m.cam.fov
	var d := _fall(P, mv)
	var dived := "a straight dive from %.0f m lands in %.2f s (%.1f to %.1f)" % [top, d["t"], DIVE_S[0], DIVE_S[1]]
	ok(d["t"] >= DIVE_S[0] and d["t"] <= DIVE_S[1], dived)
	var opened := "the canopy opens by itself at %.1f m (%.0f)" % [d["open_h"], DropFeel.open_h]
	ok(d["open_h"] <= DropFeel.open_h and d["open_h"] > DropFeel.open_h - 1.0, opened)
	var at: Vector3 = pr["at"]
	var off := Vector2(at.x - P.pos.x - float(d["wrapped"]), at.z - P.pos.z).length()
	ok(off < RETICLE_M, "you land where the ring said at the top of the dive (off by %.2f m)" % off)
	var ringed := false
	for r: Dictionary in m.fx.rings:
		ringed = ringed or (r["node"] as Node3D).global_position.distance_to(P.pos) < 6.0
	ok(not ringed, "a soft landing draws no ring")
	var view: Dictionary = DropFeel.rules("view")
	var wider: float = d["fov"] - usual
	var tipped := rad_to_deg(d["tilt"])
	ok(absf(wider - float(view["widen_deg"])) < 0.01 and absf(tipped - float(view["tilt_deg"])) < 0.01,
		"the dive view: %.0f degrees wider, tipped %.0f further down" % [wider, tipped])
	for i in int(VIEW_BACK_S / Match.DT):
		m.step(Match.DT)
		DropView.tick(m, Match.DT)
	var dv := m.get_node_or_null("DropView")
	var freed := dv == null or dv.is_queued_for_deletion()
	var back := "the usual view is back within %.0f s of landing, the drop's view freed" % VIEW_BACK_S
	ok(m.cam.fov == usual and m.cam.dive_tilt == 0.0 and freed, back)
	# the canopy open from the top, steering one way all the way down
	P = _arena(top)
	P.diving = false
	var c := _fall(P, Vector2(1, 0))
	var floated := "under the canopy from %.0f m you land in %.2f s" % [top, c["t"]]
	ok(c["t"] >= CANOPY_S[0] and c["t"] <= CANOPY_S[1], floated)
	ok(c["flat"] >= CANOPY_REACH_M, "...with %.0f m of flat reach (at least %.0f)" % [c["flat"], CANOPY_REACH_M])
	ok(c["open_h"] < 0.0, "the canopy stays open with no key held")
	# the dive you hold: crouch folds the canopy, letting go at 50 m opens it there
	P = _arena(top)
	P.diving = false
	var hd := _fall(P, Vector2.ZERO, 50.0)
	var held := "crouch held dives, letting go opens the canopy (at %.1f m, down in %.1f s)" % [hd["open_h"], hd["t"]]
	ok(hd["open_h"] > 48.0 and hd["open_h"] <= 50.0 and hd["t"] < c["t"] * 0.7, held)

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
	_height()
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
