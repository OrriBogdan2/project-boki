extends "res://tools/archetype_check.gd"
## --recast-sound-check: the recast sounds (DECISIONS 2026-11-08, two-step abilities; RecastSound). For every recast
## kit, from a fresh setup with the target 6m east: after the first step recast_open plays once as the window opens
## and recast_tick once, TICK_LEAD before it closes (a window that waits for you, Bulwark's hammer, never ticks).
## Then: a hunter that isn't the local player hears nothing, and every slot has its own pitch.

const WAIT := 4.0              # s the first step gets to open its window (Rimelock's late crack comes last)
const RUN := 20.0              # s a window gets to close (Ostra's seed waits longest, about 16s)
const LATE := 3.0 * DT         # s of slack on the tick's lead (it lands on a step)

## [hero, slot]: each recast kit; _first() takes the first step.
const CASES := [["thief", "e"], ["tender", "e"], ["ostra", "e"], ["rimewright", "e"], ["rimewright", "x"],
	["juggernaut", "e"], ["mage", "x"], ["ashwick", "x"], ["bulwark", "lmb"], ["dolm", "dash"]]

func _first(m: Match, P: Hunter, slot: String) -> void:
	match slot:
		"e": P.ak.use_e()
		"x": P.ak.cast_ult()
		"dash": P.do_dash()
		"lmb":
			P.inp["fire"] = true
			m.step(DT)
			P.inp["fire"] = false

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for c in CASES:
		await _window(String(c[0]), String(c[1]))
	await _caster_only()
	var pitches := RecastSound.PITCH.values()
	var distinct := pitches.filter(func(p): return pitches.count(p) == 1).size() == pitches.size()
	var covered := CASES.all(func(c): return RecastSound.PITCH.has(c[1]))
	ok("every recast slot has its own pitch", distinct and covered, str(pitches))
	print("RECASTSOUND DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Steps until the kit reports `slot`'s window; false if it never opened in WAIT.
func _open(m: Match, P: Hunter, slot: String) -> bool:
	var t := 0.0
	while t < WAIT:
		if String(P.ak.recast_window().get("slot", "")) == slot:
			return true
		m.step(DT)
		t += DT
	return false

func _window(hero: String, slot: String) -> void:
	var s := setup(hero, 6.0)
	var m: Match = s[0]
	var P: Hunter = s[1]
	aim_at(P, (s[2] as Hunter).pos)
	_first(m, P, slot)
	var opened := _open(m, P, slot)
	m.step(DT)
	var heard: Dictionary = P.ak.recast_heard
	var waits := is_inf(float(P.ak.recast_window().get("left", 0.0)))
	var tick_t := -1.0
	var t := 0.0
	while t < RUN and String(P.ak.recast_window().get("slot", "")) == slot:
		var ticks := int(heard["recast_tick"])
		m.step(DT)
		t += DT
		if int(heard["recast_tick"]) > ticks:
			tick_t = t
	var closed := String(P.ak.recast_window().get("slot", "")) != slot
	var lead := t - tick_t
	if waits:
		ok("%s %s: the window opens with one chime and waits, no tick" % [hero, slot],
				opened and int(heard["recast_open"]) == 1 and int(heard["recast_tick"]) == 0, str(heard))
	else:
		ok("%s %s: one chime as it opens, one tick %.1fs before it closes" % [hero, slot, RecastSound.TICK_LEAD],
				opened and closed and int(heard["recast_open"]) == 1 and int(heard["recast_tick"]) == 1
				and absf(lead - RecastSound.TICK_LEAD) <= LATE, "%s closed %s lead %.3f" % [heard, closed, lead])
	await done(m)

## A recast on a hunter that isn't the local player (the target, a Thief here) is silent: caster only.
func _caster_only() -> void:
	var s := setup("thief", 6.0)
	var m: Match = s[0]
	var T: Hunter = s[2]
	T.cls = Arch.weight("thief")
	T.set_arch("thief")
	T.unlock_all()
	m.step(DT)
	aim_at(T, (s[1] as Hunter).pos)
	T.ak.use_e()
	var opened := _open(m, T, "e")
	step(m, 0.5)
	ok("a recast on another hunter plays nothing", opened and int(T.ak.recast_heard["recast_open"]) == 0,
			"%s %s" % [opened, T.ak.recast_heard])
	await done(m)
