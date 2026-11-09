extends RefCounted
## Kael's feel: the Warchain, the RMB variants, the Meteor Drop and his dash moves. Runs inside
## --juggernaut-combo-check (tools/dancer_jug_check.gd). One assert per row of docs/heroes/juggernaut.md
## "Warchain: the state machine" and "RMB: the interaction table", the Meteor Drop's phases and timings
## against the footage, and his two dash moves. A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck

func run(a) -> void:
	A = a
	await meteor()
	await chain_states()
	await chain_pull()
	await chain_steer()
	await chain_swing()
	await rmb_rows()
	await dash_moves()
	await parity_lmb()
	await parity_rmb()
	await load("res://tools/kael_accuracy_check.gd").new().run(A)
	await load("res://tools/kael_turn_check.gd").new().run(A)
	var rows_bad: int = await load("res://tools/dash_flow_check.gd").new().check_hero(A.main, "juggernaut")
	A.ok("jug item 51: every slot casts mid-jump, holds through a jump and a dash and lets go in the air, and a "
			+ "jump or Shift moves him out of it in 0.1s (or its row's exception)",
			rows_bad == 0, "%d failures" % rows_bad)

# ------------------------------------------------------------------ item 21: the Meteor Drop
func meteor() -> void:
	var r := A.setup("juggernaut", 5.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var dd: Dictionary = K.rmb_def()["drop"]
	var D := K.meteor
	# from about a jump's height, the cursor 9m off: it lands 5m out (the clamp), on T; T2 just outside the core
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	A.fresh(T)
	A.fresh(T2)
	T.teleport(home + Vector3(5.0, 0, 0))
	T2.teleport(home + Vector3(5.0, 0, float(dd["core"]) + T2.r + 0.4))
	A.aim_at(P, home + Vector3(9.0, 0, 0))
	var y0 := P.pos.y
	P.ak.press_rmb()
	var core: Dictionary = AimKit.entry(P, "drop_core")
	A.ok("jug meteor: the hang starts on the press over a marker everyone sees (the damage disc and the stun core)",
			D.phase == "hang" and K.anim_id == "jug_meteor" and AimKit.shown(P, "drop") and bool(core.get("all", false))
			and absf(float(core.get("r", 0.0)) - float(dd["core"])) < 0.01,
			"phase %s anim %s" % [D.phase, K.anim_id])
	A.step(m, 0.1)
	A.ok("jug meteor: he holds in the air through the hang, planted (no slam yet)",
			absf(P.pos.y - y0) < 0.3 and D.phase == "hang" and D.drops == 0 and K.move_k() <= 0.0,
			"dy %.2f" % (P.pos.y - y0))
	var t := 0.1
	while D.phase == "hang" and t < 0.5:
		m.step(A.DT)
		t += A.DT
	var hang_t := t
	var top := P.pos.y
	var mid_frames := 0
	while D.phase == "dive" and t < 1.2:
		m.step(A.DT)
		t += A.DT
		if D.phase == "dive" and P.pos.y < top - 0.05 and P.pos.y > D.land.y + 0.05: mid_frames += 1
	A.ok("jug meteor: the hang lasts 0.15-0.25s (footage: the apex beat before the drive)",
			hang_t >= 0.15 and hang_t <= 0.27, "%.2fs" % hang_t)
	A.ok("jug meteor: a visible dive, not a teleport (frames between the top and the ground)",
			mid_frames >= 8, "%d frames" % mid_frames)
	A.ok("jug meteor: the phases run wind-up (hang), dive, impact, recovery",
			D.phases == ["hang", "dive", "impact", "recover"] and K.anim_id == "jug_meteor_land", str(D.phases))
	A.ok("jug meteor: press to impact 0.4-0.7s (footage: apex 412.3s to impact 412.85s)",
			D.last_air >= 0.4 and D.last_air <= 0.7, "%.2fs" % D.last_air)
	var land_from := Vector2(D.last_drop.x - home.x, D.last_drop.z - home.z).length()
	A.ok("jug meteor: it lands at the cursor clamped to its 5m reach",
			absf(land_from - float(dd["reach"])) < 0.35 and absf(D.last_drop.z - home.z) < 0.3, "%.2fm out" % land_from)
	A.ok("jug meteor: the shock ring is the stun's real radius; inside it stunned, just outside only slowed",
			absf(D.last_shock_r - float(dd["core"])) < 0.001 and T.stun_t > 0.0 and T2.stun_t <= 0.0 and T2.slow_t > 0.0
			and D.stunned_at(D.last_drop + Vector3(float(dd["core"]) + 0.4, 0, 0), 0.5, D.last_drop)
			and not D.stunned_at(D.last_drop + Vector3(float(dd["core"]) + 0.7, 0, 0), 0.5, D.last_drop),
			"ring %.2f T stun %.2f T2 stun %.2f slow %.2f" % [D.last_shock_r, T.stun_t, T2.stun_t, T2.slow_t])
	A.step(m, 0.1)
	var planted := K.move_k()
	A.ok("jug meteor: planted at the start of the recovery", planted <= 0.0, "move_k %.2f" % planted)
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.tap(m, P)                   # 0.1s into the recovery: too early for the buffer
	t = 0.0
	while D.phase == "recover" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	A.ok("jug meteor: the recovery rises over the source's ~0.5s",
			D.last_recover >= 0.45 and D.last_recover <= 0.6, "%.2fs" % D.last_recover)
	A.step(m, 0.05)
	A.ok("jug meteor: a Smash pressed early in the recovery is dropped (not fired late)",
			K.slam_w.is_empty() and K.ch_rmb >= 1.0)
	# a second drop: a Smash pressed in the last 0.1s of the recovery goes off when it ends; Shift after 0.25s
	K.cd["air"] = 0.0
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	A.aim_at(P, home + Vector3(3.0, 0, 0))
	P.ak.press_rmb()
	t = 0.0
	while D.phase != "recover" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	A.step(m, float(dd["recover"]) - 0.08)
	A.tap(m, P)
	A.step(m, 0.12)
	A.ok("jug meteor: a Smash pressed just before the recovery ends goes off as it ends (buffered, once)",
			not K.slam_w.is_empty() and K.last_variant == "tap" and K.ch_rmb < 1.0)
	A.step(m, 1.0)
	K.cd["air"] = 0.0
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	P.ak.press_rmb()
	t = 0.0
	while D.phase != "recover" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	A.step(m, 0.05)
	P.dashes = 3.0
	P.do_dash()
	A.step(m, 0.1)
	A.ok("jug meteor: Shift early in the recovery goes within 0.1s and ends it (item 51)",
			P.dashes < 2.5 and D.phase == "", "dashes %.1f phase %s" % [P.dashes, D.phase])
	# Shift in the hang: the air dash goes at once, then the dive comes down onto the marker from where it took him
	A.step(m, 1.0)
	K.cd["air"] = 0.0
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	A.aim_at(P, home + Vector3(3.0, 0, 0))
	P.ak.press_rmb()
	m.step(A.DT)
	var marker := D.land
	P.ex_cd = 0.0
	P.dashes = 3.0
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	A.step(m, 0.1)
	var went := P.roll_t > 0.0 and D.phase == "hang" and K.anim_id == "jug_meteor"
	P.inp["move"] = Vector2.ZERO
	t = 0.0
	while D.phase != "recover" and t < 2.0:
		m.step(A.DT)
		t += A.DT
	var off := Vector2(D.last_drop.x - marker.x, D.last_drop.z - marker.z).length()
	A.ok("jug meteor: Shift in the hang air-dashes at once (the gather pose kept), then it dives onto the marker",
			went and D.phase == "recover" and off < 0.3, "went %s phase %s %.2fm off the marker" % [went, D.phase, off])
	await A.done(m)

# ------------------------------------------------------------------ item 22: the Warchain's states
func _hook(m: Match, P: Hunter, K: JuggernautKit, at: Vector3, secs := 0.5) -> void:
	K.cd["e"] = 0.0
	A.aim_at(P, at)
	K.use_e()
	A.step(m, secs)

func _settle(m: Match, P: Hunter, K: JuggernautKit, home: Vector3) -> void:
	A.step(m, 0.6)
	K.warchain.snap("")
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.stun_t = 0.0
	P.root_t = 0.0
	K.cd["e"] = 0.0
	m.step(A.DT)

func chain_states() -> void:
	var r := A.setup("juggernaut", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var W := K.warchain
	var ed := K.e_def()
	A.fresh(T)
	_hook(m, P, K, T.pos)
	A.ok("jug chain: Ready > E > Throwing > Hooked to a foe 12m away (range 13m, from the footage's 7 bh)",
			absf(float(ed["range"]) - 13.0) < 0.01 and W.hooked() and W.target == T,
			"state %s" % W.state)
	_settle(m, P, K, home)
	T.teleport(home + Vector3(0, 0, 5.5))
	_hook(m, P, K, home + Vector3(18.0, 0, 0), 0.7)
	A.ok("jug chain: Throwing > Missed past its range: MISS, the cooldown starts",
			W.state == "ready" and W.misses == 1 and float(K.cd["e"]) > 5.0, "state %s misses %d" % [W.state, W.misses])
	# an ally (and your own side) is passed through: it bites the foe behind
	_settle(m, P, K, home)
	T.teleport(home + Vector3(9.0, 0, 0))
	A.fresh(T)
	var ally: Hunter = m.make_hunter("AL", P.team, "medium", "Ally", "idle", {}, home + Vector3(4.0, 0, 0),
			{"arch": "none"})
	_hook(m, P, K, T.pos)
	A.ok("jug chain: Throwing passes an ally, hooks the foe behind",
			W.hooked() and W.target == T and ally.hp >= ally.max_hp, "target %s ally hp %.0f" % [W.target, ally.hp])
	ally.teleport(home + Vector3(-6.0, 0, -5.0))
	# E pressed a hair before the hook bites: the pull starts on the bite; pressed much earlier: nothing
	_settle(m, P, K, home)
	var reels0 := W.reels
	K.cd["e"] = 0.0
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.03)
	K.use_e()
	A.step(m, 0.4)
	A.ok("jug chain: E pressed early in the throw is not kept (no surprise pull)",
			W.hooked() and W.reels == reels0, "state %s" % W.state)
	_settle(m, P, K, home)
	K.use_e()
	var t := 0.0
	var pressed := false
	while W.state == "throwing" and t < 0.6:
		if not pressed and t >= 9.0 / float(ed["speed"]) - 0.1:
			K.use_e()
			pressed = true
		m.step(A.DT)
		t += A.DT
	A.ok("jug chain: E pressed in the last 0.1s of the throw becomes the pull on the bite (buffered)",
			pressed and W.reels == reels0 + 1, "state %s reels %d" % [W.state, W.reels - reels0])
	_settle(m, P, K, home)
	K.use_e()
	A.step(m, 0.1)
	P.stun_t = 0.2
	A.step(m, 0.05)
	A.ok("jug chain: a stun in the throw breaks it, the cooldown starts",
			W.state == "ready" and float(K.cd["e"]) > 5.0 and W.breaks >= 1)
	# hooked: it holds 5s while you walk, then breaks
	_settle(m, P, K, home)
	T.teleport(home + Vector3(6.0, 0, 0))
	_hook(m, P, K, T.pos, 0.3)
	A.step(m, 4.3, func(): P.inp["move"] = Vector2(0, 1 if fmod(m.time, 1.0) < 0.5 else -1))
	var held := W.hooked()
	A.step(m, 0.6, func(): P.inp["move"] = Vector2.ZERO)
	A.ok("jug chain: Hooked holds 5s while you walk, then breaks and the cooldown starts",
			held and W.state == "ready" and float(K.cd["e"]) > 5.0, "held %s state %s" % [held, W.state])
	# stretched: it pays out as he backs away, taut and hot near its full length, and holds there (no break)
	_settle(m, P, K, home)
	T.teleport(home + Vector3(-7.0, 0, 0))
	_hook(m, P, K, T.pos, 0.3)
	var slack := W.strained
	var most := float(ed["tether_max"])
	var far := 0.0
	var tb := 0.0
	while tb < 4.2:
		P.inp["move"] = Vector2(1, 0)
		m.step(A.DT)
		tb += A.DT
		far = maxf(far, P.flat_dist(T))
	P.inp["move"] = Vector2.ZERO
	A.ok("jug chain: backing away it pays out to its full %.0fm, pulls taut (glow, creak) and holds there" % most,
			not slack and W.hooked() and W.strained and W.holds >= 1 and far <= most + 0.1 and far > most - 0.5,
			"slack %s hooked %s farthest %.2f holds %d" % [slack, W.hooked(), far, W.holds])
	# ... and a hooked foe walking off at its full length is held at the end of it
	T.teleport(P.pos + Vector3(most + 0.8, 0, 0))
	m.step(A.DT)
	A.ok("jug chain: a hooked foe pulling past the full length is held at the end of it",
			W.hooked() and absf(P.flat_dist(T) - most) < 0.1, "dist %.2f" % P.flat_dist(T))
	# Hooked + a merge-style break: drop_holds breaks it
	_settle(m, P, K, home)
	T.teleport(home + Vector3(6.0, 0, 0))
	_hook(m, P, K, T.pos, 0.3)
	K.drop_holds()
	A.ok("jug chain: a Boki merge starting breaks a held chain", W.state == "ready")
	await A.done(m)

# ------------------------------------------------------------------ item 22: the pull
func chain_pull() -> void:
	var r := A.setup("juggernaut", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: JuggernautKit = P.ak
	var W := K.warchain
	var ed := K.e_def()
	# the pull follows a hooked foe that moves; E again in the pull does nothing
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	var reels0 := W.reels
	A.step(m, 0.1)
	K.use_e()
	T.teleport(T.pos + Vector3(0, 0, 2.0))
	var t := 0.0
	var look: Vector3 = P.inp["aim"] - P.pos           # the cursor stays put on screen as the camera follows him
	while W.state == "pulling" and t < 1.0:
		P.inp["aim"] = P.pos + look
		m.step(A.DT)
		t += A.DT
	A.ok("jug pull: it homes on a hooked foe that moves, and arrives against them",
			W.exits == "arrived" and P.flat_dist(T) < T.r + P.r + 0.6, "exit %s dist %.2f" % [W.exits, P.flat_dist(T)])
	A.ok("jug pull: E in the pull is ignored (one pull, no stop)", W.reels == reels0)
	A.ok("jug pull: Arriving keeps some of the pull's speed (momentum into the next move)",
			W.state == "arriving" and Vector2(P.vel.x, P.vel.z).length() > 3.0,
			"%.1f m/s" % Vector2(P.vel.x, P.vel.z).length())
	# Shift in the pull: the Rampage takes over at once (no crouch: the pull's speed runs into the drive)
	_settle(m, P, K, home)
	T.teleport(home + Vector3(8.0, 0, 0))
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	A.step(m, 0.08)
	P.dashes = 3.0
	P.do_dash()
	A.step(m, 0.04)
	A.ok("jug pull: Shift exits into the Rampage's drive at once",
			W.exits == "dash" and W.state == "ready" and P.roll_t > 0.0 and P.move_kind == "dash"
			and K.rampage_wind <= 0.0,
			"exit %s roll %.2f kind %s" % [W.exits, P.roll_t, P.move_kind])
	# a jump in the pull: a chain launch that keeps most of the speed; RMB then is the Meteor Drop
	_settle(m, P, K, home)
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	A.step(m, 0.08)
	P.do_jump()
	m.step(A.DT)
	var hv := Vector2(P.vel.x, P.vel.z).length()
	A.ok("jug pull: a jump exits into a launch that keeps ~70% of the pull's speed",
			W.exits == "jump" and not P.grounded and hv >= float(ed["reel_speed"]) * 0.55,
			"exit %s %.1f m/s" % [W.exits, hv])
	K.cd["air"] = 0.0
	A.step(m, 0.1)
	P.ak.press_rmb()
	A.ok("jug RMB row: airborne after a chain launch = Meteor Drop", K.meteor.running() and K.last_variant == "air",
			"variant %s" % K.last_variant)
	A.step(m, 1.4)
	# a stun in the pull stops it dead
	_settle(m, P, K, home)
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	A.step(m, 0.08)
	P.stun_t = 0.3
	A.step(m, 0.03)
	A.ok("jug pull: a stun stops it dead", W.exits == "stopped" and Vector2(P.vel.x, P.vel.z).length() < 1.5,
			"exit %s" % W.exits)
	A.step(m, 0.4)
	# across a gap: the pull holds its height over the void and lands on the far side
	_settle(m, P, K, home)
	var Wd = m.world
	for dz in range(-3, 4):
		for dx in range(3, 6):
			Wd.kind[Wd.idx(int(home.x) + dx, int(home.z) + dz)] = World.T_VOID
		for dx in range(9, 11):
			Wd.level[Wd.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	T.teleport(home + Vector3(0, 0, -5.5))
	_hook(m, P, K, home + Vector3(9.5, 0, 0), 0.45)
	var on_wall := W.hooked() and W.target == null
	K.use_e()
	var low := 99.0
	t = 0.0
	while W.state == "pulling" and t < 1.0:
		m.step(A.DT)
		t += A.DT
		low = minf(low, P.pos.y)
	A.ok("jug pull: across the abyss to a wall it holds its height and lands on the far side",
			on_wall and W.exits == "arrived" and P.pos.x > home.x + 6.0 and low > home.y - 0.3,
			"x %.1f lowest %.2f" % [P.pos.x - home.x, low - home.y])
	await A.done(m)

# ------------------------------------------------------------------ item 22: the RMB rows
func rmb_rows() -> void:
	var r := A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: JuggernautKit = P.ak
	var W := K.warchain
	var ready_smash := func():
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
	# Throwing + tap: the Slam winds up, the throw goes on and still bites
	ready_smash.call()
	K.cd["e"] = 0.0
	A.aim_at(P, T.pos)
	K.use_e()
	A.tap(m, P)
	var slam_in_throw := not K.slam_w.is_empty() and K.last_variant == "tap"
	A.step(m, 0.4)
	A.ok("jug RMB row: throwing + tap = Finishing Slam, the chain still bites", slam_in_throw and W.hooked())
	A.step(m, 0.6)
	# Pulling + press: the spin goes on the press (no wait for a release), once
	_settle(m, P, K, home)
	ready_smash.call()
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	A.step(m, 0.05)
	var spins0 := K.spins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var at_once := K.spins == spins0 + 1 and K.last_variant == "during_e"
	A.step(m, 0.3, func(): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	A.step(m, 0.1)
	A.ok("jug RMB row: pulling + press = Cinder Spin on the press, nothing on the release",
			at_once and K.spins == spins0 + 1 and K.lunge.is_empty() and K.slam_w.is_empty())
	# Arriving + press: still the spin; after the window: the Slam (a body hit beside them, no sweet spot)
	_settle(m, P, K, home)
	ready_smash.call()
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	var t := 0.0
	while W.state == "pulling" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	A.tap(m, P)
	A.ok("jug RMB row: arriving (0.25s) + tap = Cinder Spin", K.spins == spins0 + 2 and K.last_variant == "during_e",
			"spins %d" % (K.spins - spins0))
	A.step(m, 0.4)
	ready_smash.call()
	var sweet0 := K.sweet_spots
	A.aim_at(P, T.pos)
	A.tap(m, P)
	var slam_after := not K.slam_w.is_empty() and K.last_variant == "tap"
	A.step(m, 0.8)
	A.ok("jug RMB row: after the window, tap = Finishing Slam; beside the foe it's a body hit (no sweet spot)",
			slam_after and K.sweet_spots == sweet0, "sweet %d" % (K.sweet_spots - sweet0))
	# a wall pull that leaves a foe 3.2m off: the Slam's sweet spot is there
	_settle(m, P, K, home)
	var Wd = m.world
	for dz in range(-2, 3):
		for dx in range(7, 9):
			Wd.level[Wd.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	T.teleport(home + Vector3(6.2, 0, 3.4))
	A.fresh(T)
	_hook(m, P, K, home + Vector3(8.0, 0, 0), 0.4)
	K.use_e()
	A.step(m, 0.7)
	ready_smash.call()
	A.aim_at(P, T.pos)
	var gap := P.flat_dist(T)
	A.tap(m, P)
	A.step(m, 0.8)
	A.ok("jug RMB row: a wall pull that leaves the foe 2.4-4.2m ahead gives the Slam its sweet spot",
			K.sweet_spots == sweet0 + 1, "gap %.2f spots %d" % [gap, K.sweet_spots - sweet0])
	for dz in range(-2, 3):
		for dx in range(7, 9):
			Wd.level[Wd.idx(int(home.x) + dx, int(home.z) + dz)] = lv
	# a Haul Slam armed for the pull: a press in the pull is not a second move
	_settle(m, P, K, home)
	T.teleport(home + Vector3(6.0, 0, 0))
	ready_smash.call()
	_hook(m, P, K, T.pos, 0.4)
	var hauls0 := K.haul_slams
	spins0 = K.spins
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.45, func(): P.inp["sec_hold"] = true)
	K.use_e()
	P.inp["sec_hold"] = false
	A.step(m, 0.04)
	A.tap(m, P)
	A.step(m, 0.5)
	A.ok("jug RMB row: hooked + charging + E = Haul Slam on arrival; a press in that pull adds nothing",
			K.haul_slams == hauls0 + 1 and K.spins == spins0,
			"hauls %d spins %d" % [K.haul_slams - hauls0, K.spins - spins0])
	# the Lunge charging, then E: the throw keeps the charge, the release runs down the chain
	_settle(m, P, K, home)
	A.fresh(T)
	ready_smash.call()
	var cl0 := K.chain_lunges
	A.aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	A.step(m, 0.35, func(): P.inp["sec_hold"] = true)
	K.use_e()
	A.step(m, 0.45, func(): P.inp["sec_hold"] = true)
	var charging := K.rmb_down and W.hooked()
	P.inp["sec_hold"] = false
	A.step(m, 0.4)
	A.ok("jug RMB row: the Lunge charging + E = the throw keeps the charge; released hooked = Chain Lunge",
			charging and K.chain_lunges == cl0 + 1 and A.dmg(T) > 15.0, "charging %s" % charging)
	# a slash pressed in the pull is not lost: it swings when the pull ends
	_settle(m, P, K, home)
	T.teleport(home + Vector3(6.0, 0, 0))
	_hook(m, P, K, T.pos, 0.4)
	K.use_e()
	A.step(m, 0.12)
	var n0 := K.slash_n
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.3)
	A.ok("jug buffer: a slash pressed late in the pull swings on arrival (not lost)", K.slash_n == n0 + 1,
			"slashes %d" % (K.slash_n - n0))
	# a Smash pressed in the last 0.1s of the Slam's wind-up goes off after it, once
	_settle(m, P, K, home)
	ready_smash.call()
	A.tap(m, P)
	A.step(m, float(K.rmb_def()["windup"]) - 0.1)
	ready_smash.call()
	A.tap(m, P)
	var queued := K.slam_w.is_empty() == false
	A.step(m, 0.15)
	A.ok("jug buffer: a Smash pressed late in the Slam's wind-up winds up the next one after it (once)",
			queued and not K.slam_w.is_empty() and K.ch_rmb < 1.0)
	await A.done(m)

# ------------------------------------------------------------------ item 35: his own dash moves
func dash_moves() -> void:
	var r := A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: JuggernautKit = P.ak
	var dd := K.dash_def()
	var feel := K.dash_feel()
	P.dashes = 3.0
	P.inp["move"] = Vector2(0, 1)
	P.do_dash()
	m.step(A.DT)
	var ground := K.anim_id
	A.step(m, 1.0)
	P.do_jump()
	A.step(m, 0.12)
	P.ex_cd = 0.0
	P.dashes = 0.0
	P.do_dash()
	m.step(A.DT)
	var air := K.anim_id
	P.inp["move"] = Vector2.ZERO
	var g_len := _last_key(ground)
	var a_len := _last_key(air)
	var g_dash := float(dd["windup"]) + float(dd["time"]) * float(feel["time"])
	var a_dash := float(P.cdat.get("ex_time", 0.21)) * float(feel["time"])
	A.ok("jug dash moves: his own ground and air dashes (jug_dash, jug_exdash), nobody else's table has them",
			ground == "jug_dash" and air == "jug_exdash" and KMovesDJ.MOVES.has(ground) and KMovesDJ.MOVES.has(air)
			and not HunterAnim.KMOVES.has(ground) and not HunterAnim.KMOVES.has(air)
			and not KMovesPair.MOVES.has(air) and not KMovesPinBjorn.MOVES.has(air),
			"%s / %s" % [ground, air])
	A.ok("jug dash moves: each fits its dash (keys cover the move, recovery at most 0.45s past it)",
			g_len >= g_dash and g_len <= g_dash + 0.45 and a_len >= a_dash and a_len <= a_dash + 0.45,
			"ground %.2f for %.2f, air %.2f for %.2f" % [g_len, g_dash, a_len, a_dash])
	await _into_dash(m, P, K, r[4])
	await A.done(m)

## Shift during his moves, by the into_dash rows of content/dash_flow/juggernaut.json.
func _into_dash(m: Match, P: Hunter, K: JuggernautKit, home: Vector3) -> void:
	A.step(m, 1.0)
	P.teleport(home)
	P.vel = Vector3.ZERO
	m.step(A.DT)
	# rmb: fire. Shift in the Slam's wind-up is a Slam Drive: the drive at once along the strike's aim, the Slam's
	# own pose kept, and the Slam lands where it arrives
	K.ch_rmb = 1.0
	K.cd["rmb"] = 0.0
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	P.inp["move"] = Vector2(0, 1)          # (moving the other way: the drive still follows the strike's aim)
	A.tap(m, P)
	var from := P.pos
	P.dashes = 3.0
	P.do_dash()
	A.step(m, 0.1)
	var drove := P.dashes < 2.5 and P.roll_t > 0.0 and not K.slam_w.is_empty() and K.anim_id == "jug_slam"
	P.inp["move"] = Vector2.ZERO
	A.step(m, 0.7)
	var ran := P.pos.x - from.x
	A.ok("jug into_dash rmb (fire): Shift in the Slam's wind-up drives at once along its aim, the Slam lands after",
			drove and K.slam_w.is_empty() and ran > 3.0 and absf(P.pos.z - from.z) < 0.8,
			"drove %s, %.1fm along the aim, %.1fm across" % [drove, ran, P.pos.z - from.z])
	A.step(m, 1.0)
	# x: buffer in the guard and the cleave (the source plants him), then free: Shift goes the step the cleave lands
	K.cd["x"] = 0.0
	P.dashes = 3.0
	HunterKeys.ult_pressed(P)
	m.step(A.DT)
	P.do_dash()
	A.step(m, 0.3)
	var guarded := P.dashes == 3.0 and K.riposte.guarding()
	var t := 0.0
	while P.dashes == 3.0 and t < 1.5:
		m.step(A.DT)
		t += A.DT
	var guard_t := float(K.x_def()["guard"]) + float(K.x_def()["strike_t"])
	A.ok("jug into_dash x (buffer): Shift in the guard waits, then goes the step the cleave lands",
			guarded and not K.riposte.running() and t <= guard_t - 0.3 + 0.05,
			"guarded %s, went %.2fs after the wait" % [guarded, t])
	for move in ["dash", "jump"]:
		A.step(m, 1.0)
		K.cd["x"] = 0.0
		P.dashes = 3.0
		HunterKeys.ult_pressed(P)
		t = 0.0
		while String(K.riposte.st.get("phase", "")) != "recover" and t < 1.5:
			m.step(A.DT)
			t += A.DT
		var y0 := P.pos.y
		P.inp[move] = true
		A.step(m, 0.1)
		P.inp[move] = false
		var moved := P.dashes < 2.5 if move == "dash" else P.pos.y > y0 + 0.1
		A.ok("jug x recovery: a %s goes within 0.1s and ends it (item 51)" % move,
				moved and not K.riposte.running(), "moved %s running %s" % [moved, K.riposte.running()])
	A.step(m, 1.0)
	# lmb: the Searing Wave charge carries through the Rampage (hold.lmb.ground: keep) and goes when let go
	for in_air in [false, true]:
		A.step(m, 0.5)
		P.teleport(home)
		P.vel = Vector3.ZERO
		m.step(A.DT)
		var waves0 := K.waves
		P.dashes = 3.0
		P.ex_cd = 0.0
		A.step(m, 0.5, func(): P.inp["fire"] = true)
		if in_air:
			P.do_jump()
			A.step(m, 0.15, func(): P.inp["fire"] = true)
		P.do_dash()
		A.step(m, 0.1, func(): P.inp["fire"] = true)
		var charging := K.lmb_t > 0.0 and K.waves == waves0
		var moved := P.dashes < 2.5 or P.ex_cd > 0.0
		var end := 0.0
		while (P.roll_t > 0.0 or K.rampage_wind > 0.0) and end < 1.0:
			P.inp["fire"] = true
			m.step(A.DT)
			end += A.DT
		P.inp["fire"] = false
		var aloft := not P.grounded
		var fired := false
		for i in 6:
			m.step(A.DT)
			fired = fired or K.waves > waves0
		var which := "air dash, let go in the air" if in_air else "ground dash"
		A.ok("jug hold lmb through the %s (keep): the charge waits, the wave goes on the release" % which,
				charging and moved and fired and (aloft or not in_air),
				"charging %s moved %s fired %s aloft %s" % [charging, moved, fired, aloft])

func _last_key(id: String) -> float:
	var keys: Array = HunterAnim.km_def(id).get("keys", [])
	return float(keys[-1][0]) if not keys.is_empty() else 0.0

# ------------------------------------------------------------------ parity pass (docs/heroes/juggernaut.md)
## LMB: slashes go where the cursor is at the swing, on the move, every 0.34s; the held Searing Wave's lane grows
## with the hold and the wave it throws is that long and wide, flying at the footage's ~20 bh/s.
func parity_lmb() -> void:
	var r := A.setup("juggernaut", 2.4)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var ld := K.lmb_def()
	# tracking: aimed away (west) a slash misses the dummy east of him; swung back at it, it hits
	A.aim_at(P, home + Vector3(-5.0, 0, 0))
	P.fire_cd = 0.0
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.05)
	var away := A.dmg(T)
	A.step(m, 0.35)
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false
	A.step(m, 0.05)
	A.ok("jug parity lmb: each slash goes where the cursor is at the swing (aimed away it misses, turned back it hits)",
			away == 0.0 and A.dmg(T) > 0.0, "away %.0f back %.0f" % [away, A.dmg(T)])
	# cadence and walking: tapped every step while walking, one slash per 0.34s and he keeps his walk
	A.step(m, 0.5)
	P.teleport(home + Vector3(0, 0, 4.0))
	var swings0 := P.swing_n
	var slashes0 := K.slash_n
	var from := P.pos
	var t := 0.0
	while t < 1.02:
		P.inp["move"] = Vector2(0, 1)
		P.inp["fire"] = int(t / A.DT) % 2 == 0      # (pressed and let go every other step: taps)
		m.step(A.DT)
		t += A.DT
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	var slashes := K.slash_n - slashes0
	var walk := P.flat_dist(from) / 1.02
	A.ok("jug parity lmb: taps chain one slash per 0.34s (3 in 1s) and he walks on while swinging",
			slashes == 3 and walk >= P.base_speed * 0.85,
			"%d slashes, %.1f m/s of %.1f" % [slashes, walk, P.base_speed])
	A.step(m, 0.6)
	P.teleport(home)
	# the hold: the lane grows with the charge, and the wave matches it
	var lens: Array = []
	for hold_t in [float(ld["tap"]) + 0.15, float(ld["full"]) + 0.1]:
		A.step(m, 0.7)
		K.res = 0.0
		P.fire_cd = 0.0
		A.step(m, hold_t, func(): P.inp["fire"] = true)
		var lane: Dictionary = AimKit.entry(P, "lmb")
		var n0 := m.shots.size()
		P.inp["fire"] = false
		m.step(A.DT)
		var sd: Dictionary = m.shots[-1] if m.shots.size() > n0 else {}
		var speed := (sd.get("vel", Vector2.ZERO) as Vector2).length()
		lens.append([float(lane.get("len", 0.0)), float(lane.get("width", 0.0)), speed, float(sd.get("r", 0.0))])
	A.ok("jug parity lmb hold: the lane grows with the hold (longer and wider), the wave matches it",
			lens[1][0] > lens[0][0] + 4.0 and lens[1][1] > lens[0][1] + 0.4 and lens[1][3] > lens[0][3] + 0.2
					and absf(lens[1][0] - float(ld["wave_range"][1])) < 0.2,
			str(lens))
	A.ok("jug parity lmb hold: the wave flies at the footage's ~20 bh/s (36 m/s)", absf(float(lens[1][2]) - 36.0) < 1.0,
			"%.1f m/s" % float(lens[1][2]))
	await A.done(m)

## RMB: the Lunge holds as long as you like with the blade over his head, and a release on the blade's flash (a
## perfect window at full, then once a second) flings him further (docs/heroes/juggernaut.md "Parity pass").
func parity_rmb() -> void:
	var r := A.setup("juggernaut", 2.4)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	T.teleport(home + Vector3(0, 0, 12.0))         # (off the Lunge's line: it must strike nothing)
	var aim := home + Vector3(10.0, 0, 0)
	var runs := {}
	for hold_t in [5.0, K.rmb_charge_full() + 0.05, K.rmb_charge_full() + 0.5]:
		P.teleport(home)
		P.vel = Vector3.ZERO
		A.step(m, 0.2)
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		A.aim_at(P, aim)
		P.inp["sec_hold"] = true
		P.inp["sec"] = true
		K.press_rmb()
		P.inp["sec"] = false
		var overhead := false
		var flashes := 0
		var t := 0.0
		var lunges0 := K.perfects
		while t < hold_t:
			P.inp["sec_hold"] = true
			A.aim_at(P, aim)
			var before := K.perfect_flashed
			m.step(A.DT)
			t += A.DT
			flashes += 1 if K.perfect_flashed != before and K.perfect_flashed >= 0 else 0
			overhead = overhead or (K.anim_id == "jug_lunge_wind" and t > 0.5)
		var held_on := K.rmb_down and K.lunge.is_empty()
		var from := P.pos
		P.inp["sec_hold"] = false
		A.step(m, 0.7)
		runs[hold_t] = {"held": held_on, "dist": P.flat_dist(from), "perfect": K.perfects > lunges0,
				"flashes": flashes, "overhead": overhead}
	var long_hold: Dictionary = runs[5.0]
	A.ok("jug parity rmb: held 5s it never fires, the blade over his head, flashing once a second at full",
			long_hold["held"] and long_hold["overhead"] and int(long_hold["flashes"]) >= 4, str(long_hold))
	var on_flash: Dictionary = runs[K.rmb_charge_full() + 0.05]
	var off_flash: Dictionary = runs[K.rmb_charge_full() + 0.5]
	A.ok("jug parity rmb: let go after 5s, it flings him the full-charge distance (as a release just after full)",
			absf(float(long_hold["dist"]) - float(off_flash["dist"])) < 0.3 and float(off_flash["dist"]) > 5.0,
			"%.1f m against %.1f" % [float(long_hold["dist"]), float(off_flash["dist"])])
	A.ok("jug parity rmb: let go on the flash it flings him ~20% further than just outside it",
			on_flash["perfect"] and not off_flash["perfect"]
					and float(on_flash["dist"]) > float(off_flash["dist"]) * 1.12,
			"on %.1f m, off %.1f m" % [float(on_flash["dist"]), float(off_flash["dist"])])
	await A.done(m)

# ------------------------------------------------------------------ owner item 57: the swing
## One pull at a foe 13 m east: `aim` is where the cursor is off him, `move` the held key. Returns the landing, the
## heading turned, the slowest step and the predicted arc's end.
func _haul(m: Match, P: Hunter, K: JuggernautKit, home: Vector3, T: Hunter, aim: Vector3, move: Vector2) -> Dictionary:
	var W := K.warchain
	_settle(m, P, K, home)
	A.aim_at(P, T.pos)
	_hook(m, P, K, T.pos, 0.5)
	var hooked := W.hooked() and W.target == T
	A.aim_at(P, P.pos + aim)
	P.inp["move"] = move
	m.step(A.DT)
	var arc: Dictionary = K.fx().chains.get(W._fx_id() + "arc", {})
	var shown: bool = not arc.is_empty() and (arc["node"] as Node3D).visible
	var promised := W.preview[-1] if shown else Vector3.ZERO
	var from := P.pos
	K.use_e()
	var t := 0.0
	var slowest := 99.0
	var was := P.pos
	while W.state == "pulling" and t < 1.5:
		A.aim_at(P, P.pos + aim)                    # the cursor stays put on screen as the camera follows him
		m.step(A.DT)
		t += A.DT
		if W.state == "pulling":
			slowest = minf(slowest, Vector2(P.pos.x - was.x, P.pos.z - was.z).length() / A.DT)
		was = P.pos
	var heading := W.pull_dir
	var moving := Vector2(P.vel.x, P.vel.z)
	P.inp["move"] = Vector2.ZERO
	return {"hooked": hooked, "exit": W.exits, "end": P.pos, "z": P.pos.z - from.z, "turned": rad_to_deg(
			absf(W.line.angle_to(heading))), "slowest": slowest, "t": t, "moving": moving, "heading": heading,
			"shown": shown, "promised": promised, "dist": T.pos.distance_to(P.pos)}

## Owner item 57: looking aside swings the pull out in a clear arc around the anchor, at full speed.
func chain_swing() -> void:
	var r := A.setup("juggernaut", 13.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var ed := K.e_def()
	var east := Vector3(13.0, 0, 0)
	var left := Vector3(0, 0, -13.0)
	T.teleport(home + east)
	var ahead := _haul(m, P, K, home, T, east, Vector2.ZERO)
	var aside := _haul(m, P, K, home, T, left, Vector2.ZERO)
	var right := _haul(m, P, K, home, T, -left, Vector2.ZERO)
	var keys := _haul(m, P, K, home, T, east, Vector2(0, -1))
	var both := _haul(m, P, K, home, T, left, Vector2(0, -1))
	var against := _haul(m, P, K, home, T, left, Vector2(0, 1))
	A.ok("jug swing: the cursor straight ahead lands direct, against the foe, no predicted arc",
			ahead["hooked"] and ahead["exit"] == "arrived" and absf(float(ahead["z"])) < 0.3
					and float(ahead["dist"]) < 1.6 and not ahead["shown"], str(ahead))
	var off := absf((aside["end"] as Vector3).z - (ahead["end"] as Vector3).z)
	A.ok("jug swing: the cursor 90 deg left lands >= 3 m left of the straight endpoint",
			aside["exit"] == "arrived" and float(aside["z"]) <= -3.0 and off >= 3.0, "%.2f m: %s" % [off, aside])
	A.ok("jug swing: the cursor 90 deg right swings the other way as far",
			absf(float(right["z"]) + float(aside["z"])) < 0.3, "%.2f / %.2f" % [right["z"], aside["z"]])
	A.ok("jug swing: at 13 m the arc turns him 35-45 deg", float(aside["turned"]) >= 35.0
			and float(aside["turned"]) <= 45.0, "%.1f deg" % float(aside["turned"]))
	A.ok("jug swing: speed through the curve stays >= 90% of the straight haul",
			float(aside["slowest"]) >= float(ahead["slowest"]) * 0.9, "%.1f against %.1f m/s" % [
					float(aside["slowest"]), float(ahead["slowest"])])
	A.ok("jug swing: he arrives still moving along the curve", float((aside["moving"] as Vector2).length()) > 5.0
			and (aside["moving"] as Vector2).normalized().dot(aside["heading"]) > 0.95, str(aside["moving"]))
	A.ok("jug swing: a held key swings as far as the look, and stacks with it (capped at steer_max)",
			absf(float(keys["z"]) - float(aside["z"])) < 0.5 and float(both["z"]) < float(aside["z"]) - 0.5
					and absf(float(both["z"])) <= float(ed["steer_max"]) + 0.3, "keys %.2f both %.2f" % [
					keys["z"], both["z"]])
	A.ok("jug swing: a key against the look cancels it", absf(float(against["z"])) < 0.5, str(against["z"]))
	A.ok("jug swing: the predicted arc shows before the press and ends where he lands (within 1 m)",
			aside["shown"] and (aside["promised"] as Vector3).distance_to(aside["end"]) < 1.0,
			"%s against %s" % [aside["promised"], aside["end"]])
	# a wall on the swing's side: he doesn't grind on it, the pull ends there
	var Wd = m.world
	var lv: int = r[5]
	for dx in range(6, 16):
		Wd.level[Wd.idx(int(home.x) + dx, int(home.z) - 2)] = lv + 3
	var walled := _haul(m, P, K, home, T, left, Vector2.ZERO)
	A.ok("jug swing: swung into a wall the pull ends there, not grinding along it",
			walled["exit"] == "arrived" and float(walled["t"]) < 0.8, str(walled))
	await A.done(m)

# ------------------------------------------------------------------ the pull model (steer, curve, slingshot)
## The pull is an impulse toward the anchor that his movement input and facing curve, and backing away first
## slingshots (docs/heroes/juggernaut.md "Warchain: the state machine"). Pulled to a wall 9 m east each time.
func chain_steer() -> void:
	var r := A.setup("juggernaut", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var K: JuggernautKit = P.ak
	var W := K.warchain
	var ed := K.e_def()
	var Wd = m.world
	for dz in range(-4, 5):
		for dx in range(9, 11):
			Wd.level[Wd.idx(int(home.x) + dx, int(home.z) + dz)] = lv + 3
	T.teleport(home + Vector3(-6.0, 0, 8.0))
	var runs := {}
	for how in ["straight", "strafe", "face", "sling"]:
		_settle(m, P, K, home)
		if how == "sling":
			P.teleport(home + Vector3(3.0, 0, 0))
		_hook(m, P, K, home + Vector3(9.0, 0, 0), 0.35)
		var hooked := W.hooked() and W.target == null
		if how == "sling":
			A.step(m, 0.35, func(): P.inp["move"] = Vector2(-1, 0))      # backing away, then pulled while still going
		if how == "face":
			A.aim_at(P, P.pos + Vector3(0, 0, 9.0))
		var from := P.pos
		K.use_e()
		var t := 0.0
		var wide := 0.0
		var start_z := W.pull_dir.y
		var look: Vector3 = P.inp["aim"] - P.pos       # the cursor stays put on screen as the camera follows him
		while W.state == "pulling" and t < 1.5:
			P.inp["move"] = Vector2(0, 1) if how == "strafe" else Vector2.ZERO
			P.inp["aim"] = P.pos + look
			m.step(A.DT)
			t += A.DT
			wide = maxf(wide, absf(P.pos.z - home.z))
		P.inp["move"] = Vector2.ZERO
		runs[how] = {"hooked": hooked, "exit": W.exits, "wide": wide, "end_z": P.pos.z - home.z, "t": t,
				"speed": W.pull_speed, "sling": W.sling, "avg": P.flat_dist(from) / maxf(t, 0.01), "start_z": start_z}
		A.aim_at(P, home + Vector3(9.0, 0, 0))
	var st: Dictionary = runs["straight"]
	A.ok("jug chain pull: no input, it flies straight in to the wall", st["hooked"] and st["exit"] == "arrived"
			and float(st["wide"]) < 0.3, str(st))
	var sf: Dictionary = runs["strafe"]
	A.ok("jug chain pull: holding a strafe curves it, arriving well beside the anchor (>= 1.5 m)",
			sf["exit"] == "arrived" and float(sf["end_z"]) >= 1.5, str(sf))
	var fc: Dictionary = runs["face"]
	A.ok("jug chain pull: looking aside bends it that way just as far as a strafe",
			absf(float(fc["end_z"]) - float(sf["end_z"])) < 0.5, str(fc))
	var sl: Dictionary = runs["sling"]
	A.ok("jug chain pull: pulled while backing away it slingshots in faster",
			float(sl["sling"]) > 2.5 and float(sl["speed"]) > float(ed["reel_speed"]) + 2.5
					and float(sl["avg"]) > float(st["avg"]) + 1.5, "sling %.1f, avg %.1f against %.1f m/s" % [
					float(sl["sling"]), float(sl["avg"]), float(st["avg"])])
	# strafing at the press: the pull starts swung wide that way (the sideways speed carries in)
	_settle(m, P, K, home)
	_hook(m, P, K, home + Vector3(9.0, 0, 0), 0.35)
	A.step(m, 0.3, func(): P.inp["move"] = Vector2(0, 1))
	K.use_e()
	A.ok("jug chain pull: strafing when it starts swings it out that way from the start",
			W.pulling() and W.pull_dir.y > 0.04, "start heading %s" % W.pull_dir)
	P.inp["move"] = Vector2.ZERO
	await A.done(m)
