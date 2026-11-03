extends RefCounted
## Zedran's feel: the Warchain, the RMB variants, the Meteor Drop and his dash moves. Runs inside
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
	await rmb_rows()
	await dash_moves()

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
	P.dashes = 3.0
	var dashes0 := P.dashes
	P.do_dash()
	A.ok("jug meteor: planted at the start of the recovery, Shift held off", planted <= 0.0 and P.dashes == dashes0,
			"move_k %.2f" % planted)
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
	A.step(m, float(dd["dash_free"]) + 0.02)
	P.dashes = 3.0
	P.do_dash()
	A.step(m, 0.25)
	A.ok("jug meteor: Shift breaks out of the recovery once he's up off the knees (0.25s)",
			P.dashes < 2.5 and D.phase == "", "dashes %.1f phase %s" % [P.dashes, D.phase])
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
			absf(float(ed["range"]) - 13.0) < 0.01 and W.hooked() and W.target == T and T.blight_t > 0.0,
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
	# stretched: taut and hot near the leash, snapped past it
	_settle(m, P, K, home)
	_hook(m, P, K, T.pos, 0.3)
	var slack := W.strained
	T.teleport(home + Vector3(17.5, 0, 0))
	m.step(A.DT)
	var taut := W.strained and W.hooked()
	T.teleport(home + Vector3(float(ed["range"]) * float(ed["leash_k"]) + 1.0, 0, 0))
	m.step(A.DT)
	A.ok("jug chain: the chain pulls taut near its leash (glow, creak), snaps past 1.5x range",
			not slack and taut and W.state == "ready" and float(K.cd["e"]) > 5.0, "slack %s taut %s" % [slack, taut])
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
	while W.state == "pulling" and t < 1.0:
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
	await A.done(m)

func _last_key(id: String) -> float:
	var keys: Array = HunterAnim.km_def(id).get("keys", [])
	return float(keys[-1][0]) if not keys.is_empty() else 0.0
