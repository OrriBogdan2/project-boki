extends RefCounted
## Cinder's ultimate on X, Flue Flight, for --ashwick-combo-check (docs/heroes/ashwick.md): the level gate,
## the lift-off telegraph and move, the steering lane, the capped turn, the early landing, the carpet's burn,
## slow and Char, bond only on a land (the best of hit or knock per cast), the cloak and the Cinder Shot
## mid-flight, the lance off for the whole flight, a knockback speeding it up, a stun ending it, never over the
## abyss, the merge drop, the cooldown and the burst cap.

const BURST := preload("res://tools/ult_burst.gd")

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func ok(label: String, cond: bool, info := "") -> void:
	ok_fn.call(label, cond, info)

## What the bond meter owes the current ult cast (KinBond.from_ult keeps the best event per cast id).
func _owed(P: Hunter) -> float:
	var c: Dictionary = P.get_meta("bond_cast", {})
	return float(c.get("got", 0.0)) if String(c.get("id", "")) == HeroUlt.cast_id(P.ak) else 0.0

func run() -> void:
	await _flight()
	await _carpet()
	await _burst()

## Starts the flight toward `at` (cooldown cleared) and returns the jet.
func _cast(P: Hunter, at: Vector3) -> AshwickJet:
	var K: AshwickKit = P.ak
	K.cd["x"] = 0.0
	ak.aim_at(P, at)
	HunterKeys.ult_pressed(P)
	return K.jet

func _flight() -> void:
	var r: Array = ak.setup("ashwick", 16.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	var J := K.jet
	T.teleport(home + Vector3(0, 0, 6.0))
	T2.teleport(home + Vector3(-4.0, 0, 6.0))
	var listed: bool = Settings.ACTIONS.any(func(a): return a[0] == "hunter_ult")
	ok("ult: X is the hero ultimate (rebindable, its own action)", InputMap.has_action("hunter_ult") and listed)
	P.lvl = 5
	_cast(P, home + Vector3(10, 0, 0))
	ok("ult: no cast below level 6", not J.running() and float(K.cd["x"]) == 0.0 and J.flights == 0, "level %d" % P.lvl)
	P.lvl = 6
	var casts0: int = J.flights
	_cast(P, home + Vector3(10, 0, 0))
	ak.step(m, 0.05)
	var no_disc := not AimKit.shown(P, "x_burst")
	ok(
		"ult cast: lifts off in its ember puffs, no aim disc (it hits nothing)", J.running() and no_disc
				and K.anim_id == "lw_jet",
		"move %s" % K.anim_id
	)
	ok(
		"ult: one X press is one cast (main's X path only)", J.flights == casts0 + 1,
		"flights +%d" % (J.flights - casts0)
	)
	ok(
		"ult cast: its own cooldown starts (36s, the data's 45s at the kit's 0.8)",
		absf(float(K.cd["x"]) - 36.0) < 0.2 and float(K.cd["e"]) == 0.0,
		"cd %.1f" % float(K.cd["x"])
	)
	ak.step(m, 0.25, func(): ak.aim_at(P, home + Vector3(10, 0, 0)))
	ok(
		"ult telegraph: the heading lane shows while flying", AimKit.shown(P, "x_steer"),
		"len %.1f" % float(AimKit.entry(P, "x_steer").get("len", 0.0))
	)
	ok(
		"ult: flies low, off the ground", P.pos.y - m.world.ground_at(P.pos.x, P.pos.z) > 0.2,
		"height %.2f" % (P.pos.y - home.y)
	)
	HunterKeys.ult_pressed(P)
	var start := P.pos
	ok(
		"ult recast: X again lands early", not J.running() and J.early >= 1 and K.anim_id == "lw_land",
		"early %d" % J.early
	)
	ak.step(m, 0.3)
	ok(
		"ult recast: he stops soon after the early landing", P.pos.distance_to(start) < 1.6,
		"slid %.1f" % P.pos.distance_to(start)
	)
	# a full flight: 1.8s (about 30% past the source's 1.4s), about 22.7m
	var xd := K.x_def()
	var fly_t := float(xd["time"])
	var want := float(xd["speed"]) * fly_t
	P.teleport(home)
	_cast(P, home + Vector3(20, 0, 0))
	ak.step(m, fly_t - 0.1, func(): ak.aim_at(P, home + Vector3(20, 0, 0)))
	var still_up := J.running()
	ak.step(m, 0.2, func(): ak.aim_at(P, home + Vector3(20, 0, 0)))
	var flown := Vector2(P.pos.x - home.x, P.pos.z - home.z).length()
	ok(
		"ult: the flight lasts 1.8s (+25-35% on 1.4s) and covers about 22.7m",
		absf(fly_t - 1.8) < 0.01 and still_up and not J.running() and absf(flown - want) < want * 0.1,
		"%.1fm of %.1f, up at %.1fs %s" % [flown, want, fly_t - 0.1, still_up]
	)
	ok("ult: the flight ends on its own with the landing move", J.landings >= 2 and K.anim_id == "lw_land")
	ok("ult bond: nothing for a cast that lands on nobody", _owed(P) == 0.0, "owed %.2f" % _owed(P))
	HunterKeys.ult_pressed(P)
	ok("ult: the cooldown denies a new flight", not J.running() and J.flights == 2, "cd %.1f" % float(K.cd["x"]))
	await _steer(m, P, K, home)
	await ak.done(m)

## Steering: the flight follows the cursor at no more than 120 degrees a second, so the carpet curves.
func _steer(m: Match, P: Hunter, K: AshwickKit, home: Vector3) -> void:
	var J := K.jet
	P.teleport(home)
	_cast(P, home + Vector3(12, 0, 0))
	ak.step(m, 0.3, func(): ak.aim_at(P, P.pos + Vector3(12, 0, 0)))
	var d0: Vector2 = J.flight["dir"]
	ak.step(m, 0.2, func(): ak.aim_at(P, P.pos + Vector3(0, 0, 12)))
	var d1: Vector2 = J.flight["dir"]
	var turned := rad_to_deg(absf(d0.angle_to(d1)))
	ok(
		"ult steer: the heading turns toward the cursor, capped at 120 deg/s",
		turned > 15.0 and turned <= 120.0 * 0.2 + 3.0, "%.0f deg in 0.2s" % turned
	)
	ak.step(m, 1.2, func(): ak.aim_at(P, P.pos + Vector3(0, 0, 12)))
	ok(
		"ult steer: the flight curves (it ends well to the side)", P.pos.z - home.z > 3.0 and P.pos.x - home.x > 3.0,
		"x %.1f z %.1f" % [P.pos.x - home.x, P.pos.z - home.z]
	)

func _carpet() -> void:
	var r: Array = ak.setup("ashwick", 16.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: AshwickKit = P.ak
	var J := K.jet
	T.teleport(home + Vector3(5.0, 0, 0))
	T2.teleport(home + Vector3(9.0, 0, 0.4))
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 2.0, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var left := 0.0
	if not J.trail.is_empty():
		left = float(J.trail[-1]["until"]) - m.time
	var linger := float(K.x_def()["trail_t"])
	ok(
		"ult payoff: a molten carpet along the flight that lingers 5.2s (the flight's +30%)",
		J.trail.size() >= 14 and absf(linger - 5.2) < 0.01 and left > linger - 0.5 and left <= linger,
		"pieces %d left %.1f" % [J.trail.size(), left]
	)
	var look_w := 0.0
	for e in K.fx.live:
		if e["kind"] == "lava": look_w = (e["s0"] as Vector3).z * 2.0
	ok("ult look: the carpet is drawn as wide as it burns (trail_w)", absf(look_w - float(K.x_def()["trail_w"])) < 0.01,
		"look %.2f m, burns %.2f m" % [look_w, float(K.x_def()["trail_w"])])
	ak.step(m, 0.7)
	var char_t := K.char_of(T) + 31.0 * float(K.burning(T))
	ok(
		"ult payoff: the carpet burns, slows and builds Char", ak.dmg(T) > 0.5 and T.slow_t > 0.0 and char_t > 0.0,
		"dmg %.1f slow %.2f char %.0f" % [ak.dmg(T), T.slow_t, char_t]
	)
	ok("ult payoff: the slow is about 30%", absf(T.slow_k - 0.3) < 0.01, "slow_k %.2f" % T.slow_k)
	var sent := _owed(P)
	ok(
		"ult bond: burning a hunter pays once per cast through KinBond.from_ult (a hit: 0.6, two hunters still 0.6)",
		absf(sent - 0.6) < 0.001 and HeroUlt.cast_id(K).begins_with("ashwick_"), "owed %.2f" % sent
	)
	# a knock with it tops the cast up to the knock's share (once the last carpet has burnt out)
	ak.step(m, 6.0)
	ak.fresh(T)
	T.hp = 0.5
	T.teleport(home + Vector3(6.0, 0, 0))
	T2.teleport(home + Vector3(0, 0, -6.0))
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 2.0, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	sent = _owed(P)
	ok(
		"ult bond: a knock with the carpet counts as the cast's best event (0.7)",
		T.downed and absf(sent - 0.7) < 0.001, "downed %s sent %.2f" % [T.downed, sent]
	)
	T.downed = false
	ak.fresh(T)
	# a new flight with nobody near: only the cloak works mid-flight (item 66, owner)
	ak.step(m, 4.0)
	T.teleport(home + Vector3(0, 0, -5.0))
	T2.teleport(home + Vector3(-3.0, 0, -5.0))
	P.teleport(home)
	K.cd["e"] = 0.0
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.4, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var used0: int = K.cloaks
	P.ak.use_e()
	ok("ult: E (Furnace Cloak) still works mid-flight, the flight goes on", K.cloaks == used0 + 1 and J.running())
	await _locked_inputs(m, P, K, home + Vector3(16, 0, 0))
	K.ch_rmb = float(K.rmb_charges())
	var em0: int = K.hose.emitted
	var denied0: int = K.lmb_denied
	ak.step(m, 0.4, func():
		P.inp["fire"] = true
		ak.aim_at(P, home + Vector3(16, 0, 0)))
	P.inp["fire"] = false
	ok("ult 66: the lance does not roar mid-flight (no flame, no queued shot)", K.hose.emitted == em0 and J.running(),
			"puffs +%d" % (K.hose.emitted - em0))
	ok("ult 66: a press ticks softly once (denied), not once a frame", K.lmb_denied == denied0 + 1,
			"denied %d" % (K.lmb_denied - denied0))
	ak.step(m, 1.6, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	# Ablaze in about 2.4s of standing in it (4 Char every 0.3s)
	ak.fresh(T)
	K.chars = {}
	K.ignites = {}
	var spot: Vector3 = J.trail[-1]["b"]
	ak.step(m, 1.4, func(): T.teleport(spot))
	var at_14 := K.burning(T)
	ak.step(m, 1.2, func(): T.teleport(spot))
	ok(
		"ult payoff: standing in it, Ablaze after about 2.4s", at_14 == 0 and K.burning(T) >= 1,
		"at 1.4s %d, at 2.6s %d" % [at_14, K.burning(T)]
	)
	await _lance_off(m, P, K, T, home)
	await _abyss(m, P, K, home, m.world)
	await _knock_stun_merge(m, P, K, home)
	await ak.done(m)

## The carpet never forms over the abyss; he flies on over it.
func _abyss(m: Match, P: Hunter, K: AshwickKit, home: Vector3, W) -> void:
	var J := K.jet
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-4, 5):
		for dx in range(5, 8):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	J.trail = []
	P.teleport(home)
	var skips := J.void_skips
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 1.9, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var over := false
	for t in J.trail:
		for p in [t["a"], t["b"]]:
			if W.ground_at((p as Vector3).x, (p as Vector3).z) <= World.VOID + 1.0:
				over = true
	ok(
		"ult abyss: the carpet never forms over the void, he flies across",
		not over and J.void_skips > skips and P.pos.x - home.x > 9.0,
		"skips %d x %.1f" % [J.void_skips - skips, P.pos.x - home.x]
	)
	for dz in range(-4, 5):
		for dx in range(5, 8):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_GROUND

## A knockback speeds the flight up; a stun ends it; a Boki merge drops it with nothing more laid.
func _knock_stun_merge(m: Match, P: Hunter, K: AshwickKit, home: Vector3) -> void:
	var J := K.jet
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.2, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	var sp0 := float(J.flight["speed"])
	P.impulse(Vector2(0.0, 16.0))
	ak.step(m, 0.05, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
	ok(
		"ult: a knockback mid-flight speeds it up", J.boosts >= 1 and float(J.flight.get("speed", 0.0)) > sp0 + 3.0,
		"speed %.1f -> %.1f" % [sp0, float(J.flight.get("speed", 0.0))]
	)
	ak.step(m, 1.8)
	await _shift_and_jump(m, P, K, home)
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.3)
	P.stun_t = 0.5
	ak.step(m, 0.05)
	ok("ult: a stun ends the flight", not J.running() and P.roll_t <= 0.0)
	P.stun_t = 0.0
	P.teleport(home)
	_cast(P, home + Vector3(16, 0, 0))
	ak.step(m, 0.3)
	ok("merge hold: the flight is up before the merge", J.running())
	ok("merge hold: a merge is under way", ak.merge_now(P))
	var laid := J.laid
	ak.step(m, 0.6)
	ok(
		"merge hold: linwick's flight is dropped, nothing more is laid",
		not J.running() and J.laid == laid and P.roll_t <= 0.0, "laid +%d" % (J.laid - laid)
	)
	KinMerge.end(P, "test")

## LMB does nothing in Flue Flight (no flame, nothing queued, a soft tick on a press), and the lance
## is back on the first frame after it, however the flight ended.
func _lance_off(m: Match, P: Hunter, K: AshwickKit, T: Hunter, home: Vector3) -> void:
	# held through the whole flight, a foe at the nozzle, watched every frame
	var pilot := "pilot%d" % P.get_instance_id()
	ak.step(m, 6.0)                 # (the carpet of the last flight gone)
	P.teleport(home + Vector3(-5.0, 0, 0))      # the flight runs along the flat strip
	P.vel = Vector3.ZERO
	ak.step(m, 0.3)
	ok("ult 66: the idle pilot flame shows on the ground", K.fx.shown(pilot))
	ak.fresh(T)
	K.chars = {}
	K.ignites = {}
	var side := Vector3(0, 0, 3.0)      # beside her, off the carpet, inside the lance's reach
	T.teleport(P.pos + side)
	var at := home + Vector3(40.0, 0, 0)
	var J := _cast(P, at)
	var em := K.hose.emitted
	var denied := K.lmb_denied
	var held_in := 0
	var pilot_in := 0
	var frames := 0
	while J.running() and frames < 300:
		P.inp["fire"] = true
		T.teleport(P.pos + side)
		ak.aim_at(P, at)
		ak.step(m, 0.001)
		frames += 1
		if J.running():
			held_in += int(K.was_held)
			pilot_in += int(K.fx.shown(pilot))
	ok("ult 66: LMB held through the whole flight: no flame, no pilot, no lance damage, Char or burn",
			frames > 90 and held_in == 0 and pilot_in == 0 and K.hose.emitted == em and ak.dmg(T) < 0.5
			and K.chars.is_empty() and K.burning(T) == 0,
			"%d frames, held %d, pilot %d, puffs +%d, dmg %.1f, chars %d, burn %d" % [
				frames, held_in, pilot_in, K.hose.emitted - em, ak.dmg(T), K.chars.size(), K.burning(T)])
	ok("ult 66: that hold ticks once, on its press", K.lmb_denied == denied + 1, "denied +%d" % (K.lmb_denied - denied))
	ok("ult 66: LMB works on the first frame after the flight (the lance lights)",
			K.was_held and K.spool > 0.0 and P.ak.anim_id == "as_lance",
			"held %s spool %.3f anim %s" % [K.was_held, K.spool, P.ak.anim_id])
	P.inp["fire"] = true
	m.step(ak.DT)
	ok("ult 66: its pilot flame is back a frame later", K.fx.shown(pilot))
	ak.step(m, float(K.lmbd()["spool"]) + 0.3, func():
		P.inp["fire"] = true
		T.teleport(P.pos + side)
		ak.aim_at(P, T.pos))
	P.inp["fire"] = false
	ok("ult 66: out of the flight the lance roars and hits, after only its usual pilot",
			K.hose.emitted > em and ak.dmg(T) > 0.5, "puffs +%d, dmg %.1f" % [K.hose.emitted - em, ak.dmg(T)])
	ak.step(m, 0.5)
	# tapped in the flight and let go: nothing waits for the landing
	J = _cast(P, at)
	ak.step(m, 0.3)
	denied = K.lmb_denied
	for i in 3:
		ak.step(m, 0.05, func(): P.inp["fire"] = true)
		P.inp["fire"] = false
		ak.step(m, 0.05)
	ok("ult 66: each press ticks", K.lmb_denied == denied + 3, "denied +%d" % (K.lmb_denied - denied))
	em = K.hose.emitted
	ak.step(m, 2.0)
	ok("ult 66: a tap in the flight is ignored, not buffered (nothing fires on landing)",
			not J.running() and not K.was_held and K.hose.emitted == em, "puffs +%d" % (K.hose.emitted - em))
	# a stream running at lift-off goes out, and a hold carried in is no press
	ak.step(m, 0.5, func(): P.inp["fire"] = true)
	ok("ult 66: (the lance is roaring before the cast)", K.was_held and K.spool > 0.1)
	denied = K.lmb_denied
	J = _cast(P, at)
	ak.step(m, 0.05, func(): P.inp["fire"] = true)
	em = K.hose.emitted
	ak.step(m, 0.2, func(): P.inp["fire"] = true)
	ok("ult 66: a stream running at lift-off goes out; a hold carried in doesn't tick",
			J.running() and not K.was_held and K.hose.emitted == em and K.lmb_denied == denied,
			"held %s puffs +%d denied +%d" % [K.was_held, K.hose.emitted - em, K.lmb_denied - denied])
	# X again lands: the very next frame the lance is live, with the release's relight gap gone too
	P.inp["fire"] = false
	J.recast()
	ak.step(m, 0.5)
	ak.step(m, 0.5, func(): P.inp["fire"] = true)
	P.inp["fire"] = false
	m.step(ak.DT)
	ok("ult 66: (a release leaves its relight gap running)", float(K.relight_t) > 0.0, "%.2f" % K.relight_t)
	J = _cast(P, at)
	ak.step(m, 0.05)
	J.recast()
	P.inp["fire"] = true
	m.step(ak.DT)
	P.inp["fire"] = false
	ok("ult 66: landing early with X: LMB lights on the first frame, no relight gap left over", K.was_held,
			"relight %.2f" % K.relight_t)
	ak.step(m, 0.5)
	# whatever is in her hand, and the tick is the local player's own
	J = _cast(P, at)
	ak.step(m, 0.05)
	var wid0 := P.wid
	P.wid = "rifle"
	P.inp["fire"] = true
	ok("ult 66: another weapon in her hand doesn't fire in the flight either", K.lmb_override(true, ak.DT))
	P.inp["fire"] = false
	K.lmb_override(false, ak.DT)
	P.wid = wid0
	m.hud.slot_fx.erase("base")
	K.lmb_override(true, ak.DT)
	ok("ult 66: a press answers on the LMB slot with the deny cue",
			String((m.hud.slot_fx.get("base", {}) as Dictionary).get("kind", "")) == "deny")
	K.lmb_override(false, ak.DT)
	m.hud.slot_fx.erase("base")
	var ctrl0 := P.ctrl
	P.ctrl = "bot"
	K.lmb_override(true, ak.DT)
	K.lmb_override(false, ak.DT)
	P.ctrl = ctrl0
	ok("ult 66: a bot's press is refused the same way, with no tick in your ears", not m.hud.slot_fx.has("base"))
	J.recast()
	ak.step(m, 0.5)

## Item 66: Shift in the flight does nothing; item 51: a jump leaps off it at once, keeping a share of its speed
## into the air (plain flight movement is not an ability and stays).
func _shift_and_jump(m: Match, P: Hunter, K: AshwickKit, home: Vector3) -> void:
	var J := K.jet
	var at := home + Vector3(16, 0, 0)
	P.teleport(home)
	P.ex_cd = 0.0
	_cast(P, at)
	ak.step(m, 0.3, func(): ak.aim_at(P, at))
	var sp0 := float(J.flight["speed"])
	var b0 := J.boosts
	var ex0 := P.ex_cd
	var dashes0 := P.dashes
	P.inp["move"] = Vector2(0, 1)
	P.inp["dash"] = true
	ak.step(m, 0.05, func(): ak.aim_at(P, at))
	P.inp["dash"] = false
	P.inp["move"] = Vector2.ZERO
	ok(
		"ult: Shift in the flight does nothing now (no poof, no dash spent, no speed; owner: only E works)",
		J.running() and J.boosts == b0 and P.ex_cd == ex0 and P.dashes == dashes0
				and float(J.flight["speed"]) <= sp0 + 0.01,
		"speed %.1f -> %.1f, boosts %d" % [sp0, float(J.flight.get("speed", 0.0)), J.boosts - b0]
	)
	ak.step(m, 2.0)
	P.teleport(home)
	_cast(P, at)
	ak.step(m, 0.3, func(): ak.aim_at(P, at))
	var sp := float(J.flight["speed"])
	var y0 := P.pos.y
	P.inp["jump"] = true
	ak.step(m, 0.1)
	P.inp["jump"] = false
	var flat := Vector2(P.vel.x, P.vel.z).length()
	ok(
		"ult: a jump in the flight leaps off it within 0.1s, keeping its speed into the air (item 51)",
		not J.running() and J.leaps >= 1 and P.pos.y > y0 + 0.2 and P.vel.y > 0.0
				and flat >= sp * Hunter.DASH_JUMP_CARRY * 0.9,
		"rose %.2f m, %.1f m/s of %.1f" % [P.pos.y - y0, flat, sp]
	)
	ak.step(m, 1.5)

func _burst() -> void:
	var res: Dictionary = await BURST.run(ak, "ashwick", 4.0, func(m: Match, P: Hunter, T: Hunter):
		var home := P.pos
		T.teleport(home + Vector3(5.0, 0, 0))
		_cast(P, home + Vector3(16, 0, 0))
		ak.step(m, 1.9, func(): ak.aim_at(P, home + Vector3(16, 0, 0)))
		var end_p: Vector3 = P.ak.jet.trail[-1]["b"] if not P.ak.jet.trail.is_empty() else P.pos
		ak.step(m, 2.4, func(): T.teleport(end_p))
		P.teleport(T.pos + Vector3(-2.0, 0, 0))
		P.ak.cd["e"] = 0.0
		P.ak.use_e()
		ak.step(m, 0.4))
	var info := "ult %.0f, ult + merge %.0f of %d" % [res["ult"], res["total"], int(Data.CLASSES["light"]["hp"])]
	ok(
		"burst: Flue Flight then the merge never one-shots a full-health light hunter",
		bool(res["merged"]) and bool(res["alive"]), info
	)

## Owner decision (item 66): in Flue Flight ONLY E works. RMB, Shift, the glove and utility slots, gear, a throw and
## the Boki's C are dropped before their handlers: no cooldown or charge spent, no projectile, no item used. E and
## X (land early) still work, and RMB is back the moment the flight ends. Called mid-flight, E-checked after.
func _locked_inputs(m: Match, P: Hunter, K: AshwickKit, at: Vector3) -> void:
	var J := K.jet
	UtilityBelt.set_slot(P, 0, "tonic", 3)
	UtilityBelt.set_slot(P, 1, "smoke", 2)
	P.gear[0] = {"id": "blink", "rar": 1}
	P.gear[1] = {"id": "blink", "rar": 1}
	P.gear_cd = [0.0, 0.0]
	K.ch_rmb = float(K.rmb_charges())
	K.cd["rmb"] = 0.0
	P.ex_cd = 0.0
	var shots0: int = m.shots.size()
	var ch0 := K.ch_rmb
	var hp0 := P.hp
	var pos_y := P.pos.y
	var l0 := J.locked
	var keys := ["sec", "dash", "util1", "util2", "util3", "util4", "gear1", "gear2", "kin_ab", "skill", "throw"]
	for key in keys:
		ak.step(m, 0.05, func():
			P.inp[key] = true
			if key == "sec": P.inp["sec_hold"] = true
			ak.aim_at(P, at))
		P.inp[key] = false
		P.inp["sec_hold"] = false
	ak.step(m, 0.05, func(): ak.aim_at(P, at))
	ok("ult 66: RMB mid-flight spends no charge and fires nothing", K.ch_rmb == ch0 and K.cd["rmb"] == 0.0
			and m.shots.size() == shots0 and not K.aiming and not K.rmb_down,
			"charges %.1f -> %.1f, shots +%d" % [ch0, K.ch_rmb, m.shots.size() - shots0])
	ok("ult 66: Shift (dash), Q/V gloves, Boki C, skill and throw spend nothing",
			P.ex_cd == 0.0 and P.dash_buf == 0.0 and float(P.gear_cd[0]) == 0.0 and float(P.gear_cd[1]) == 0.0,
			"ex_cd %.2f gear_cd %s" % [P.ex_cd, P.gear_cd])
	ok("ult 66: the utility slots use no item (tonic and smoke stay, nothing drunk)",
			int(P.belt[0]["n"]) == 3 and int(P.belt[1]["n"]) == 2 and P.drink_t <= 0.0 and P.hp <= hp0 + 0.01,
			"tonic %s smoke %s" % [P.belt[0]["n"], P.belt[1]["n"]])
	ok("ult 66: every blocked press was swallowed and the flight went on", J.locked - l0 >= keys.size() and J.running(),
			"swallowed %d of %d" % [J.locked - l0, keys.size()])
	ok("ult 66: flight steering still works (still flying, low)", P.pos.y < pos_y + 1.0, "y %.2f" % P.pos.y)
	var cl0: int = K.cloaks
	K.cd["e"] = 0.0
	P.ak.use_e()
	ok("ult 66: E still works after all that", K.cloaks == cl0 + 1 and J.running())
	J.recast()
	ak.step(m, 0.5)
	ok("ult 66: X lands it early", not J.running())
	P.ak.press_rmb()
	ak.step(m, 0.02)
	ok("ult 66: the moment it ends RMB fires again", K.ch_rmb < ch0, "charges %.1f -> %.1f" % [ch0, K.ch_rmb])
	K.ch_rmb = float(K.rmb_charges())
	_cast(P, at)
	ak.step(m, 0.4, func(): ak.aim_at(P, at))
