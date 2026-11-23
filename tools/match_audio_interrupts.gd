extends RefCounted
## --match-audio-check, part: a broken cast's wind-up sound ends (KitWindup). One interrupt per kit that has
## one: the cast starts, its wind-up voice plays, a stun breaks it, and within CUT_MAX that voice is silent,
## the caster heard the "broken" tick, and Sfx made no new player for any of it (the pool's voices only).

const CUT_MAX := 100  # ms of game time: the wind-up's voice must be silent this soon after the cast breaks
const CUT_FRAMES := 60  # frames the check waits for the voice to end (a slow box draws few per second)
const HOLD := 1.0  # s: held casts (a bow draw, a fist) are held at most this long for their sound
## arch -> the slot its wind-up sounds are kept under (KitWindup)
const SLOTS := {
	"bulwark": "x",
	"dredge": "e",
	"gunslinger": "e",
	"juggernaut": "rmb",
	"ostra": "rmb",
	"mage": "dash",
	"tender": "x",
	"thief": "rmb",
	"rimewright": "rmb",
	"ashwick": "x",
	"archer": "lmb",
	"dolm": "lmb"
}

var c: RefCounted  # the match audio check (ok, _step)
var team0 := 0  # the mate's own team (Meeko's call needs it on hers for a moment)


func run(check: RefCounted, m: Match, p_v: Hunter, mate: Hunter) -> void:
	c = check
	team0 = mate.team
	var was := [p_v.cls, p_v.arch, p_v.ctrl]
	p_v.ctrl = "local"  # the caster is you (the tick is yours), and no bot brain presses keys
	var kin: Kin = p_v.kin  # (the check's downed Boki would start a rescue, which blocks firing: send it off)
	if kin != null:
		if kin.rescue_on:
			KinDowned.stop(kin, p_v, "drop")
		kin.pos = p_v.pos + Vector3(90, 0, 0)
	for arch: String in SLOTS:
		await _case(m, p_v, mate, arch, String(SLOTS[arch]))
	p_v.reclass(was[0], was[1])
	p_v.ctrl = was[2]


func _case(m: Match, p_v: Hunter, mate: Hunter, arch: String, slot: String) -> void:
	p_v.stun_t = 0.0
	p_v.reclass(Arch.weight(arch), arch)
	p_v.unlock_all()
	var k: ArchKit = p_v.ak
	Sfx.listener = p_v.pos
	Sfx.last_played.clear()
	await _start(m, p_v, k, mate, arch, slot)
	var held: Array = k.windups.get(slot, [])
	var kids0 := Sfx.get_children()  # (taken after the cast: a channel's held loop is its own player on main)
	c.ok(held.any(Sfx.sounding), "%s %s: the wind-up's voice plays (%s)" % [arch, slot, held])
	p_v.stun_t = 0.6
	var t := 0.0
	var seen := []  # every loop's own player while the stun runs (a loop that starts and stops in it is not the cast's)
	while k.windups.has(slot) and t < 0.3:
		m.step(Match.DT)
		t += Match.DT
		seen.append_array(Sfx.loops.values().map(func(l): return l["p"]))
	c.ok(not k.windups.has(slot), "%s %s: a stun breaks the cast" % [arch, slot])
	var took := 0  # ms of game time before the frame the voice ended in (not the box's speed)
	var frames := 0
	while held.any(Sfx.sounding) and frames < CUT_FRAMES:
		await m.get_tree().process_frame
		frames += 1
		seen.append_array(Sfx.loops.values().map(func(l): return l["p"]))
		if held.any(Sfx.sounding):
			took += roundi(m.get_process_delta_time() * 1000.0)
	var gone := not held.any(Sfx.sounding)
	c.ok(gone and took <= CUT_MAX, "%s: the wind-up's voice ends %d ms after the break" % [arch, took])
	c.ok(Sfx.last_played.has(KitWindup.BROKEN), "%s: the caster hears the broken tick" % arch)
	var own := Sfx.loops.values().map(func(l): return l["p"])
	own.append_array(seen)
	own.append(Sfx.get("_sting_p"))  # (made once, on the first sting, never per cast)
	own.append_array(Sfx.amb_layers.values().map(func(l): return l["p"]))  # (ambience beds: where you stand)
	var fresh := Sfx.get_children().filter(func(ch): return not ch in kids0 and not ch in own)
	var named := fresh.map(
		func(ch): return "%s:%s" % [ch.name, ch.get("stream").resource_path if ch.get("stream") else ""]
	)
	c.ok(fresh.is_empty(), "%s: no new player for the cast or the cut (%d %s)" % [arch, fresh.size(), named])
	p_v.inp["fire"] = false
	mate.team = team0


## Starts the arch's interruptible cast the way the kit does (the input, or the kit's own start).
func _start(m: Match, p_v: Hunter, k: ArchKit, mate: Hunter, arch: String, slot: String) -> void:
	match arch:
		"bulwark":
			(k as BulwarkKit).ult.cast()
		"dredge", "gunslinger":
			k.cast_e()
		"juggernaut", "ostra", "thief", "rimewright":
			k.fire_rmb({"variant": ""})
		"mage":
			k.on_dash(false)
		"ashwick":
			(k as AshwickKit).jet.start()
		"tender":
			mate.team = p_v.team
			mate.pos = p_v.pos + Vector3(3, 0, 0)
			p_v.inp["aim"] = mate.pos
			(k as TenderKit)._start_call()
		"archer", "dolm":
			var t := 0.0
			while not k.windups.has(slot) and t < HOLD:
				p_v.inp["fire"] = true  # (a shot lets go of the key; the hold presses it every step)
				m.step(Match.DT)
				t += Match.DT
	await m.get_tree().process_frame
