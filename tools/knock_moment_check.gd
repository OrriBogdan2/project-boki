extends RefCounted
## --knock-moment-check: the step a Hunter is knocked, for all 12 Hunters holding LMB, RMB and Shift
## (docs/MOVEMENT_FEEL.md "The knock moment"). It drives the real match step with scripted inputs,
## knocks the player through Hunter.hurt, keeps every key held (and taps them again) for half a second
## and asserts that nothing goes off, the dash ends on the spot, and the Wisp answers the keys at once.
## Prints "KMOM ok|FAIL <hero> <what>" per assertion and "KNOCK MOMENT CHECK DONE, failures: N".

const DT := 1.0 / 60.0
const AFTER := 30               # steps watched after the knock (0.5 s)
const HOLD_STEPS := 6           # steps the keys are held before the knock (0.1 s: a hold is open, a bow drawing)
const WISP_STOP_M := 0.5        # m: [game data] a walking stop slides 0.38-0.49 m; a cut dash slides no more
const POP_IN_S := [0.2, 0.4]    # s: [footage] the victim is a Wisp within two frames at 5 fps
const HEROES := ["gunslinger", "bulwark", "thief", "juggernaut", "mage", "rimewright",
		"dredge", "tender", "ashwick", "dolm", "ostra", "archer"]

var bad := 0
var m: Match
var P: Hunter
var flat := Vector3.ZERO
var mate: Hunter                # the idle squadmate who keeps the team in the fight (a knock, not a wipe)
var casts := 0                  # CombatBus.ability_used by the player
var holds_open := 0             # Hunters whose RMB hold was open at the knock

func ok(cond: bool, what: String) -> void:
	print("KMOM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _steps(n: int) -> void:
	for i in n: m.step(DT)

func _hv() -> Vector2:
	return Vector2(P.vel.x, P.vel.z)

func _clear_inp() -> void:
	for k in ["sec", "sec_hold", "sig", "ult", "gear1", "gear2", "glide", "jump", "dash", "dash_down", "fire",
			"crouch", "throw", "reload", "skill", "swap"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = flat + Vector3(8, 0, 0)

## A standing hunter at the flat spot, everything ready, holding nothing; the Wisp (if any) gone.
func _reset() -> void:
	Life.bring_back(m, P, flat, 1.0, false)
	for i in 60: HunterWisp.tick(P, DT)
	P.teleport(flat)
	P.inv_t = 0.0
	P.vel = Vector3.ZERO
	P.grounded = true
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	P.dash_buf = 0.0
	P.fire_cd = 0.0
	P.knock_t = 0.0
	P.ammo = int(P.wpn["mag"])
	P.reload_t = 0.0
	P.draw_t = -1.0
	P.swing_buf = 0.0
	for k in P.ak.cd: P.ak.cd[k] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())
	mate.out = false
	mate.downed = false
	mate.hp = mate.max_hp
	mate.teleport(m.world.random_ground())
	_clear_inp()
	_steps(2)

func _knock(hero: String) -> void:
	var took := P.hurt(P.hp + P.armor + 1e5, null, {})
	ok(P.downed, "%s knocked (took %.0f, hp %.0f, inv %.2f, dead %s, dropping %s, god %s)" % [hero, took, P.hp,
			P.inv_t, P.dead, P.dropping, Game.god])

## The player's shots not seen before (each is tagged once); shots that land or expire don't count down.
func _new_shots() -> int:
	var n := 0
	for s in m.shots:
		if s["by"] == P and not s.has("kmom"):
			s["kmom"] = true
			n += 1
	return n

func _snap() -> Dictionary:
	var used := 0
	for k in P.used: used += int(P.used[k])
	_new_shots()
	return {"casts": casts, "used": used, "swing_at": P.swing_at}

func _quiet(hero: String, what: String, s0: Dictionary) -> void:
	var s1 := _snap()
	var shots := _new_shots()
	var same: bool = shots == 0 and s1["casts"] == s0["casts"] and s1["used"] == s0["used"] \
		and is_equal_approx(float(s1["swing_at"]), float(s0["swing_at"]))
	ok(same, "%s %s (new shots %d, casts %d->%d, used %d->%d)" % [hero, what, shots, s0["casts"], s1["casts"],
			s0["used"], s1["used"]])

## Flat open ground 4 m all round, as the move-feel check picks it.
func _flat_spot() -> Vector3:
	var w: World = m.world
	for k in 4000:
		var g: Vector3 = w.random_ground()
		var open := not w.is_void(g.x, g.z) and not w.is_block(g.x, g.z)
		for i in 12:
			var a := TAU * i / 12.0
			for d in [2.0, 4.0]:
				var x: float = g.x + cos(a) * d
				var z: float = g.z + sin(a) * d
				if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
					open = false
		if open:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return w.random_ground()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h.team == P.team and h != P: mate = h
		elif h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	CombatBus.ability_used.connect(func(c: Node, _id: String, _slot: String): if c == P: casts += 1)
	flat = _flat_spot()
	print("KMOM flat spot %s" % str(flat))
	for hero in HEROES:
		P.reclass(Arch.weight(hero), hero)       # the hero's own class: set_arch alone would fix a mismatch away
		P.unlock_all()
		_holds(hero)
		_dash(hero)
		_wisp(hero)
	ok(holds_open >= 6, "an RMB hold was open at the knock for %d Hunters (the hold path is exercised)" % holds_open)
	print("KNOCK MOMENT CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## LMB and RMB held into the knock, kept held after it, then tapped again with E, R, Shift and jump.
func _holds(hero: String) -> void:
	_reset()
	P.inp["fire"] = true
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	_steps(HOLD_STEPS)
	var hold_var := float(P.ak.rmb_def().get("hold", 0.0)) > 0.0
	if P.ak.rmb_down: holds_open += 1
	print("KMOM info %s: RMB hold variant %s, hold open at the knock %s, drawing %s, charging %s" % [hero,
			hold_var, P.ak.rmb_down, P.draw_t >= 0.0, not P.charge.is_empty() or P.mel_hold > 0.0])
	var s0 := _snap()
	_knock(hero)
	ok(not P.ak.rmb_down, "%s held RMB dropped on the knock step (no cast, the aim ring shuts)" % hero)
	ok(P.draw_t < 0.0 and P.swing_buf == 0.0 and P.warm_t == 0.0 and P.charge.is_empty() and P.mel_hold == 0.0,
			"%s held LMB dropped on the knock step" % hero)
	_steps(1)
	_quiet(hero, "the knock step itself fires nothing", s0)
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	_steps(1)
	for k in ["fire", "sec", "sec_hold", "dash", "dash_down", "jump", "sig", "ult"]:
		P.inp[k] = true
	_steps(AFTER)
	_quiet(hero, "nothing fires in the 0.5 s after (held and fresh LMB, RMB, E, R, Shift, jump)", s0)
	ok(not P.ak.rmb_down, "%s RMB pressed after the knock opens no hold" % hero)

## A dash in flight at the knock, Shift still held, and a Shift tapped the step after.
func _dash(hero: String) -> void:
	_reset()
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	_steps(2)
	var in_flight := P.roll_t > 0.0 or P.fly_t > 0.0
	print("KMOM info %s: dash in flight at the knock %s (roll %.2f s, fly %.2f s, %.1f m/s)" % [hero, in_flight,
			P.roll_t, P.fly_t, _hv().length()])
	var s0 := _snap()
	var p0 := P.pos
	P.inv_t = 0.0            # the hit lands inside the dash's dodge window: this knock is the one that got through
	_knock(hero)
	ok(P.roll_t <= 0.0, "%s a dash in flight ends on the knock step" % hero)
	P.inp["move"] = Vector2.ZERO
	_steps(1)
	P.inp["dash"] = true
	_steps(AFTER)
	var slid := Vector2(P.pos.x - p0.x, P.pos.z - p0.z).length()
	ok(slid <= WISP_STOP_M,
			"%s the Wisp stops where the knock lands it: slid %.2f m (<= %.1f)" % [hero, slid, WISP_STOP_M])
	ok(P.roll_t <= 0.0 and P.fly_t <= 0.0 and P.dash_buf == 0.0, "%s no dash after the knock" % hero)
	_quiet(hero, "a Shift held through and tapped after the knock fires nothing", s0)

## Wisp control: the keys answer on the first step after the knock; the Wisp pops in on the footage's beat.
func _wisp(hero: String) -> void:
	_reset()
	_knock(hero)
	HunterWisp.tick(P, 0.0)
	ok(HunterWisp.mode_of(P) == HunterWisp.IN, "%s the Wisp starts popping in on the knock step" % hero)
	P.inp["move"] = Vector2(1, 0)
	var control := -1
	var pop := -1
	for i in AFTER:
		m.step(DT)
		HunterWisp.tick(P, DT)
		if control < 0 and _hv().length() > 0.3: control = i + 1
		if pop < 0 and HunterWisp.mode_of(P) == HunterWisp.ON: pop = i + 1
	ok(control == 1, "%s Wisp control: the keys answer on step %d after the knock (target 1)" % [hero, control])
	var pop_s := pop * DT
	ok(pop >= 0 and pop_s >= POP_IN_S[0] and pop_s <= POP_IN_S[1],
			"%s Wisp pop-in done at %.2f s (target %.1f-%.1f)" % [hero, pop_s, POP_IN_S[0], POP_IN_S[1]])
