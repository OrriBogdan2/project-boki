extends RefCounted
## --drop-feel-check: the opening drop (DropFeel). Prints PASS/FAIL lines.
##   1. the player's Boki is never downed or killed in the first 10 s of a normal match or the tutorial
##   2. steering ramps (no snapping), the dive is clearly faster than the glider, the flare slows the last metres
##   3. the reticle: projected landing within RETICLE_M of where you land (canopy and dive), sits on the ground,
##      hides on landing; red over the void
##   4. decision 0049, from the ship's height: a straight dive lands in DIVE_S, the canopy opens by itself at
##      DropFeel.open_h, a canopy open from the top lands in CANOPY_S with CANOPY_REACH_M of flat reach, crouch
##      held dives and letting go opens the canopy, a soft landing draws no ring, and the dive view (wider,
##      tipped down) is back to the usual view within VIEW_BACK_S of landing
##   5. decision 0050, a Hard Landing (HardLanding): the dive key held to the ground lands at dive speed,
##      staggers and hurts the monsters inside its radius (none past it, no Hunter, no Boki, no lair boss),
##      credits the camp's last kill, locks and slows the lander, draws its ring at exactly that radius, dips
##      the local view with no shake, reaches the other clients and a rival's minimap; letting go at
##      SOFT_RELEASE_M is a soft landing; HARD_SHARE of BOT_DROPS seeded bot drops onto a live camp land hard;
##      BURST landings in a second stay under PARTICLE_CAP particles and, where a quiet second does, FRAME_MS a frame
##   6. no chests before the match proper: all hidden on the ship and the drop, all shown once you land
const DIVE_S := [6.5, 7.5]
const CANOPY_S := [21.0, 23.0]
const CANOPY_REACH_M := 190.0
const RETICLE_M := 2.0
const VIEW_BACK_S := 1.0
const WRAP_M := 20.0          # the arena is 40 m to a side: a long glide is stepped back this far to stay on it
const SOFT_RELEASE_M := 12.0  # the dive key let go this high: the canopy opens, no Hard Landing
const BOT_DROPS := 200
const BOT_SEED := 5150
const HARD_SHARE := [0.4, 0.6]
const BURST := 9              # Hard Landings inside one second
const PARTICLE_CAP := 4000    # particles alive at once during the burst
const FRAME_MS := 50.0        # no frame of the burst may run longer (checked where there is a renderer)
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
func _arena(h: float, teams := 2) -> Hunter:
	_start({"training": true, "teams": teams, "no_drop": true, "length": 1e9, "weapon": "rifle", "cls": "medium"})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.camps.camps.clear()
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

	var high := DropFeel.fall_vy(-DropFeel.canopy_fall, false, 30.0, 0.1)
	var low := DropFeel.fall_vy(-DropFeel.canopy_fall, false, 1.0, 0.1)
	ok(low > high + 1.0, "the canopy's flare slows the fall near the ground")
	var held := DropFeel.fall_vy(-DropFeel.dive_fall, true, 1.0, 0.1)
	ok(is_equal_approx(held, -DropFeel.dive_fall), "the dive has no flare: held to the ground it lands at dive speed")

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
## seconds it took, the flat metres covered, the height the canopy opened at (-1: it never opened), the
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
		if was and not P.diving and P.dropping:
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

## A live camp at `at` holding `mobs`, as Camps keeps them.
func _camp(at: Vector3, mobs: Array) -> Dictionary:
	var c := {"id": m.camps.camps.size(), "pos": at, "island": -1, "size": 0, "state": Camps.State.LIVE,
		"mobs": mobs, "back_t": -1.0, "region": -1, "paid": {}}
	for mb: Mob in mobs:
		mb.set_meta("camp", c["id"])
	m.camps.camps.append(c)
	return c

func _ring_at(at: Vector3) -> Dictionary:
	for r: Dictionary in m.fx.rings:
		if (r["node"] as Node3D).global_position.distance_to(at) < 1.0:
			return r
	return {}

func _hard_landing() -> void:
	var hl: Dictionary = HardLanding.rules
	var P := _arena(40.0)
	var feet := Vector3(P.pos.x, P.ground(), P.pos.z)
	var rival: Hunter = m.hunters.filter(func(o: Hunter) -> bool: return o.team != P.team)[0]
	for o: Hunter in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.kin.state = "bench"      # (nobody else's fight: the numbers below are the landing's alone)
	var near := m.spawn_mob("brute", feet)
	var edge := m.spawn_mob("brute", feet)
	var past := m.spawn_mob("brute", feet)
	var last := m.spawn_mob("skitter", feet)
	last.hp = 20.0
	var camp := _camp(feet, [last])
	# held in place to the step you land: two monsters inside the radius, one past it, a rival beside you
	var spots := {near: Vector3(3, 0, 0), edge: Vector3(0, 0, 5.5), past: Vector3(-7, 0, 0), last: Vector3(0, 0, -3),
		rival: Vector3(-2.5, 0, 2.5)}
	var hp0 := {}
	var vy := 0.0
	var shaken := m.cam.shake_total
	while P.dropping:
		for e: Ent in spots:
			e.teleport(feet + spots[e])
			hp0[e] = e.hp
		hp0[P.kin] = P.kin.hp
		rival.inv_t = 0.0
		P.inp["crouch"] = true
		vy = P.vel.y
		m.step(Match.DT)
	ok(vy < -DropFeel.dive_fall + 0.5, "the dive key held to the ground: no canopy, down at %.1f m/s" % -vy)
	var dmg: float = hl["damage"]
	var stun: float = hl["stun_s"]
	var hit := "monsters at 3 m and 5.5 m take %.0f and %.0f (%.0f) and are staggered %.2f s (%.1f)" % [
		hp0[near] - near.hp, hp0[edge] - edge.hp, dmg, near.stun_t, stun]
	ok(is_equal_approx(hp0[near] - near.hp, dmg) and is_equal_approx(hp0[edge] - edge.hp, dmg)
		and absf(near.stun_t - stun) < 0.05 and absf(edge.stun_t - stun) < 0.05, hit)
	ok(past.hp == hp0[past] and past.stun_t == 0.0, "a monster at 7 m is untouched")
	ok(rival.hp == hp0[rival] and rival.stun_t == 0.0, "a rival Hunter inside the ring is untouched")
	ok(P.kin.hp == hp0[P.kin] and P.kin.stun_t == 0.0, "your Boki is untouched")
	var cleared := "the hit counts as the camp's last kill, credited to the lander's squad"
	ok(last.dead and camp["state"] == Camps.State.CLEARED and (camp["paid"] as Dictionary).has(P.team), cleared)
	var ring := _ring_at(P.pos)
	var team_col: Color = Data.TEAM_COLORS[P.team % Data.TEAM_COLORS.size()]
	var ringed := "the ring is the effect's radius (%.1f m = %.1f m), team colour, %.2f s" % [
		ring.get("r", 0.0), HardLanding.radius, ring.get("dur", 0.0)]
	ok(not ring.is_empty() and ring["r"] == HardLanding.radius and ring["r"] == float(hl["radius"])
		and ring["dur"] == float(hl["ring_s"]) and ring["col"] == team_col, ringed)
	var view := "your view dips %.1f m, back in %.2f s, with a %.0f ms hit-stop and no shake" % [
		m.cam.dip_depth, m.cam.dip_left, m.hitstop * 1000.0]
	ok(m.cam.dip_depth == float(hl["dip_m"]) and m.cam.dip_left == float(hl["dip_s"])
		and m.hitstop == float(hl["hitstop_s"]) and m.cam.shake_total == shaken, view)
	P.kin.state = "bench"
	_lock(P, hl)
	var t: float = hl["lock_s"] + 0.5
	while t < stun - 0.1:
		m.step(Match.DT)
		t += Match.DT
	var still := edge.stun_t > 0.0
	for i in int(0.2 / Match.DT) + 1:
		m.step(Match.DT)
	ok(still and edge.stun_t <= 0.0, "the stagger lasts %.1f s, then they are back" % stun)
	_spared(P)
	_seen_and_heard(P, rival, hl)

## The lander's lock: slowed and no attack while it runs, both back after it.
func _lock(P: Hunter, hl: Dictionary) -> void:
	var lock: float = hl["lock_s"]
	var ammo := P.ammo
	var slow := 0.0
	var t := 0.0
	while t < lock - Match.DT * 1.5:
		P.inp["move"] = Vector2(1, 0)
		P.inp["fire"] = true
		m.step(Match.DT)
		t += Match.DT
		slow = maxf(slow, Vector2(P.vel.x, P.vel.z).length())
	ok(P.ammo == ammo and slow > 0.5, "for %.1f s the lander cannot fire (moving at %.2f m/s)" % [lock, slow])
	var fast := 0.0
	while t < lock + 0.5:
		P.inp["move"] = Vector2(1, 0)
		P.inp["fire"] = true
		m.step(Match.DT)
		t += Match.DT
		fast = maxf(fast, Vector2(P.vel.x, P.vel.z).length())
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	var slowed := slow / maxf(fast, 0.01)
	var freed := "after it they fire, and run at %.2f m/s: the lock slowed them to %.2f of it (%.2f)" % [
		fast, slowed, 1.0 - float(hl["slow_k"])]
	ok(P.ammo < ammo and absf(slowed - (1.0 - float(hl["slow_k"]))) < 0.05, freed)

## A lair boss inside the ring is spared; a Blight monster is hit like a camp's.
func _spared(P: Hunter) -> void:
	var boss := Boss.new()
	boss.init_boss(m, m.next_id("b"), Data.BOSSES[0], P.pos + Vector3(2, 0, 0), 1.0, {})
	var bl := Blight.new()
	bl.init_blight(m, m.next_id("m"), "bl_warden", P.pos + Vector3(0, 0, 2), 1.0, null)
	for mb: Mob in [boss, bl]:
		m.add_child(mb)
		m.mobs.append(mb)
	HardLanding.land(m, P)
	ok(boss.hp == boss.max_hp and boss.stun_t == 0.0, "a lair boss inside the ring is untouched")
	var blighted := "a Blight monster takes %.0f and is staggered" % (bl.max_hp - bl.hp)
	ok(is_equal_approx(bl.max_hp - bl.hp, HardLanding.rules["damage"]) and bl.stun_t > 0.0, blighted)
	for mb: Mob in [boss, bl]:
		m.mobs.erase(mb)
		mb.queue_free()

## What the other clients get: the landing's event draws the ring there, and a rival's landing pings
## your minimap from inside hear_m (past the usual sound-ping range) and not from beyond it.
func _seen_and_heard(P: Hunter, rival: Hunter, hl: Dictionary) -> void:
	var hear: float = hl["hear_m"]
	var out := P.pos + Vector3(hear + 10.0, 0, 0)
	var pings := m.sound_pings.size()
	m._net_ev([HardLanding.NET_EVENT, rival.nid, out.x, out.y, out.z], "peer")
	var ring := _ring_at(out)
	ok(not ring.is_empty() and ring["r"] == HardLanding.radius, "the landing's event draws the ring on another client")
	ok(m.sound_pings.size() == pings, "a rival's Hard Landing %.0f m off is not on your minimap" % (hear + 10.0))
	var inside := P.pos + Vector3(hear - 10.0, 0, 0)
	m.time += 1.0      # (pings from one source inside 0.7 s are one ping)
	HardLanding.show(m, rival, inside)
	ok(m.sound_pings.size() == pings + 1, "one %.0f m off pings your minimap" % (hear - 10.0))

func _soft_landing() -> void:
	var P := _arena(40.0)
	var mb := m.spawn_mob("brute", Vector3(P.pos.x + 3.0, P.ground(), P.pos.z))
	var f := _fall(P, Vector2.ZERO, SOFT_RELEASE_M)
	var opened := "the dive key let go at %.0f m: the canopy opens (at %.1f m)" % [SOFT_RELEASE_M, f["open_h"]]
	ok(f["open_h"] > 0.0 and f["open_h"] <= SOFT_RELEASE_M, opened)
	var soft := "...for a soft landing: no ring, no lock, the monster beside you not staggered"
	ok(_ring_at(P.pos).is_empty() and P.land_t == 0.0 and mb.stun_t == 0.0 and m.cam.dip_left == 0.0, soft)

func _hint() -> void:
	var hint_h := float(HardLanding.rules["hint_h"])
	var P := _arena(hint_h + 10.0)
	DropReticle.tick(P, 0.016)
	var r: DropReticle = P.get_node("DropReticle")
	var high := r.tag.visible
	P.teleport(P.pos - Vector3(0, 12.0, 0))
	DropReticle.tick(P, 0.016)
	var shown := "in the last %.0f m of the dive the reticle reads '%s'" % [hint_h, r.tag.text]
	ok(not high and r.tag.visible and r.tag.text == DropReticle.HARD_TEXT, shown)
	P.diving = false
	DropReticle.tick(P, 0.016)
	ok(not r.tag.visible, "under the canopy it shows no line")
	P.diving = true
	P.inp["crouch"] = true
	var held: Dictionary = DropReticle.project(P, Vector2.ZERO)
	P.inp["crouch"] = false
	var d := _fall(P, Vector2.ZERO, 0.0)
	var at: Vector3 = held["at"]
	ok(Vector2(at.x - P.pos.x, at.z - P.pos.z).length() < RETICLE_M and d["open_h"] < 0.0,
		"the reticle marks where a held dive hits (the canopy never opened)")

## Bots choose: over a live camp half of them hold the dive to the ground, away from one none do.
func _bots() -> void:
	var P := _arena(0.0, 6)
	var feet := Vector3(P.pos.x, P.ground(), P.pos.z)
	P.teleport(feet + Vector3(34, 0, 34))
	var bots: Array = m.hunters.filter(func(o: Hunter) -> bool: return o.ctrl == "bot")
	seed(BOT_SEED)
	var bare := _bot_drops(bots, feet, bots.size())
	ok(bare[0] > 0 and bare[1] == 0, "with no camp below, no bot lands hard (%d drops)" % bare[0])
	_camp(feet, [])
	var over := _bot_drops(bots, feet, BOT_DROPS)
	var share := float(over[1]) / maxf(1.0, over[0])
	var chose := "%d of %d bot drops onto a live camp land hard (%.0f%%, %.0f to %.0f)" % [
		over[1], over[0], share * 100.0, HARD_SHARE[0] * 100.0, HARD_SHARE[1] * 100.0]
	ok(over[0] >= BOT_DROPS and share >= HARD_SHARE[0] and share <= HARD_SHARE[1], chose)

## Drops `bots` onto `spot` from the hint height until `n` have landed. Returns [landed, landed hard].
func _bot_drops(bots: Array, spot: Vector3, n: int) -> Array:
	var landed := 0
	var hard := 0
	var rounds := 0
	while landed < n and rounds < n:
		rounds += 1
		for b: Hunter in bots:
			b.teleport(spot + Vector3(randf_range(-5.0, 5.0), 40.0, randf_range(-5.0, 5.0)))
			b.vel = Vector3.ZERO
			b.dropping = true
			b.diving = true
			b.gliding = true
			b.grounded = false
			b.glide_k = 1.0
			b.inv_t = 60.0      # (rival squads land on one spot: nobody is hurt between drops)
			b.land_t = 0.0
			b.ai["land"] = spot
			b.ai.erase("hard")
		var t := 0.0
		while t < 30.0 and bots.any(func(b: Hunter) -> bool: return b.dropping):
			var falling := bots.filter(func(b: Hunter) -> bool: return b.dropping)
			m.step(Match.DT)
			t += Match.DT
			for b: Hunter in falling:
				if not b.dropping:
					landed += 1
					hard += 1 if b.land_t > 0.0 else 0
	return [landed, hard]

func _particles() -> int:
	var n := 0
	for cls in ["GPUParticles3D", "CPUParticles3D"]:
		for p in main.get_tree().root.find_children("*", cls, true, false):
			if p.get("emitting"):
				n += int(p.get("amount"))
	return n

## BURST Hard Landings inside one second, on real frames.
func _burst() -> void:
	var P := _arena(0.0)
	await m.warm_up()      # as behind the loading screen: in play a first landing finds its shaders built
	m.set_process(true)
	for i in 30:
		await main.get_tree().process_frame
	var quiet := 0.0      # the worst frame of the second before, with nothing landing
	var t0 := Time.get_ticks_usec()
	var now := t0
	while now - t0 < 1000000:
		await main.get_tree().process_frame
		quiet = maxf(quiet, (Time.get_ticks_usec() - now) * 0.001)
		now = Time.get_ticks_usec()
	var worst := 0.0
	var worst_at := 0
	var most := 0
	var fired := 0
	t0 = now
	while now - t0 < 1500000:
		while fired < BURST and (now - t0) * 0.000001 >= float(fired) / BURST:
			var turn := TAU * float(fired) / BURST
			HardLanding.show(m, P, P.pos + Vector3(cos(turn), 0, sin(turn)) * 8.0)
			fired += 1
		await main.get_tree().process_frame
		var ms := (Time.get_ticks_usec() - now) * 0.001
		if ms > worst:
			worst = ms
			worst_at = fired
		most = maxi(most, _particles())
		now = Time.get_ticks_usec()      # (after the count: walking the tree is this check's cost, not a landing's)
	m.set_process(false)
	ok(fired == BURST and most < PARTICLE_CAP, "%d Hard Landings in a second: %d particles at most (under %d)" % [
		fired, most, PARTICLE_CAP])
	# A frame limit is only read where frames hold it with nothing landing: no renderer, or a worker whose
	# quiet second already breaks it (docs/DEBT.md, the GPU workers' frame time), cannot judge a landing.
	if DisplayServer.get_name() == "headless" or quiet > FRAME_MS:
		var unfit := "DROP SKIP the burst's frame time needs a renderer that holds %.0f ms with nothing landing"
		print((unfit + " (%.1f here, %.1f in the burst)") % [FRAME_MS, quiet, worst])
	else:
		var held := "...and the worst frame is %.1f ms, after landing %d (at most %.0f; %.1f the second before)"
		ok(worst <= FRAME_MS, held % [worst, worst_at, FRAME_MS, quiet])

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
	_hard_landing()
	_soft_landing()
	_hint()
	_bots()
	await _burst()
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
