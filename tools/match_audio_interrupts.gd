extends RefCounted
## --match-audio-check, part: a broken cast's wind-up sound ends (KitWindup). One interrupt per kit that has
## one: the cast starts, its wind-up voice plays, a stun breaks it, and within CUT_MAX that voice is silent,
## the caster heard the "broken" tick, and Sfx made no new player for any of it (the pool's voices only).

const CUT_MAX := 100           # ms: the wind-up's voice must be silent this soon after the cast breaks
const HOLD := 1.0              # s: held casts (a bow draw, a fist) are held at most this long for their sound
## arch -> the slot its wind-up sounds are kept under (KitWindup)
const SLOTS := {"bulwark": "x", "dredge": "e", "gunslinger": "e", "juggernaut": "rmb", "ostra": "rmb",
	"mage": "dash", "tender": "x", "thief": "rmb", "rimewright": "rmb", "ashwick": "x", "archer": "lmb",
	"dolm": "lmb"}

var c: RefCounted              # the match audio check (ok, _step)
var team0 := 0                 # the mate's own team (Meeko's call needs it on hers for a moment)

func run(check: RefCounted, m: Match, P: Hunter, mate: Hunter) -> void:
	c = check
	team0 = mate.team
	var was := [P.cls, P.arch, P.ctrl]
	P.ctrl = "local"               # the caster is you (the tick is yours), and no bot brain presses keys
	var kin: Kin = P.kin           # (the check's downed Boki would start a rescue, which blocks firing: send it off)
	if kin != null:
		if kin.rescue_on:
			KinDowned.stop(kin, P, "drop")
		kin.pos = P.pos + Vector3(90, 0, 0)
	for arch: String in SLOTS:
		await _case(m, P, mate, arch, String(SLOTS[arch]))
	P.reclass(was[0], was[1])
	P.ctrl = was[2]

func _case(m: Match, P: Hunter, mate: Hunter, arch: String, slot: String) -> void:
	P.stun_t = 0.0
	P.reclass(Arch.weight(arch), arch)
	P.unlock_all()
	var k: ArchKit = P.ak
	Sfx.listener = P.pos
	Sfx.last_played.clear()
	var voices := Sfx.get_child_count()
	await _start(m, P, k, mate, arch, slot)
	var held: Array = k.windups.get(slot, [])
	c.ok(held.any(Sfx.sounding), "%s %s: the wind-up's voice plays (%s)" % [arch, slot, held])
	P.stun_t = 0.6
	var t := 0.0
	while k.windups.has(slot) and t < 0.3:
		m.step(Match.DT)
		t += Match.DT
	c.ok(not k.windups.has(slot), "%s %s: a stun breaks the cast" % [arch, slot])
	var at := Time.get_ticks_msec()
	while held.any(Sfx.sounding) and Time.get_ticks_msec() - at <= CUT_MAX * 3:
		await m.get_tree().process_frame
	var took := Time.get_ticks_msec() - at
	var gone := not held.any(Sfx.sounding)
	c.ok(gone and took <= CUT_MAX, "%s: the wind-up's voice ends %d ms after the break" % [arch, took])
	c.ok(Sfx.last_played.has(KitWindup.BROKEN), "%s: the caster hears the broken tick" % arch)
	c.ok(Sfx.get_child_count() == voices, "%s: no new player for the cast or the cut" % arch)
	P.inp["fire"] = false
	mate.team = team0

## Starts the arch's interruptible cast the way the kit does (the input, or the kit's own start).
func _start(m: Match, P: Hunter, k: ArchKit, mate: Hunter, arch: String, slot: String) -> void:
	match arch:
		"bulwark": (k as BulwarkKit).ult.cast()
		"dredge", "gunslinger": k.cast_e()
		"juggernaut", "ostra", "thief", "rimewright": k.fire_rmb({"variant": ""})
		"mage": k.on_dash(false)
		"ashwick": (k as AshwickKit).jet.start()
		"tender":
			mate.team = P.team
			mate.pos = P.pos + Vector3(3, 0, 0)
			P.inp["aim"] = mate.pos
			(k as TenderKit)._start_call()
		"archer", "dolm":
			var t := 0.0
			while not k.windups.has(slot) and t < HOLD:
				P.inp["fire"] = true       # (a shot lets go of the key; the hold presses it every step)
				m.step(Match.DT)
				t += Match.DT
	await m.get_tree().process_frame
