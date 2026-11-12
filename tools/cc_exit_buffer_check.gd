extends RefCounted
## --cc-exit-buffer-check (docs/decisions/0022-cc-exit-buffer.md): for every hero, a press of LMB, RMB, E, R, Shift
## or jump made PRESS_S before the end of a crowd control that forbids it is held (DashFlow) and goes off on the
## first step the CC allows it: as many steps after that one as the same press with no CC takes (a slot's own
## wind-up), and never while the CC still forbids it. The CCs: a stun (every slot), a root (Shift), Grounded (Shift
## and jump). Also: a stun running into a longer root lets LMB go at the stun's end but never Shift, and an E
## pressed EARLY_S before a stun's end (outside Loco.buf_ability_hold) is not held. Reuses the dash-flow check's
## training match and slot presses. Never touches the save.

const PRESS_S := 0.1            # s of CC left when the press is made (inside Loco.buf_ability_hold)
const EARLY_S := 0.3            # s of stun left for the press that comes too early to be held
const ROOT_PAST := 0.4          # s the root runs past the stun in the stun-into-root trial
const WATCH := 90               # steps after the press we watch
const CC_SLOTS := {"stun": ["lmb", "rmb", "e", "x", "dash", "jump"], "root": ["dash"], "gnd": ["dash", "jump"]}
const LOST := -1                # never went off
const EARLY := -2               # went off while the CC still forbade it

var bad := 0
var skipped := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("CCEXIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(flow._on_used)
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		_hero(m, hero)
		m.queue_free()
		await main.get_tree().process_frame
	print("CCEXIT DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

func _hero(m: Match, hero: String) -> void:
	var idle := {}
	for slot in CC_SLOTS["stun"]:
		idle[slot] = _latency(m, slot, "", 0.0)
		if int(idle[slot]) < 0:
			skipped += 1
			print("CCEXIT skip %s %s: it doesn't go off without a CC here either" % [hero, slot])
	for cc in CC_SLOTS:
		for slot in CC_SLOTS[cc]:
			if int(idle[slot]) < 0:
				continue
			var got := _latency(m, slot, cc, PRESS_S)
			ok(got == int(idle[slot]), "%s %s pressed %.2fs before the %s ends: %s (no CC: %d steps)"
					% [hero, slot, PRESS_S, cc, _said(got), int(idle[slot])])
	if int(idle["lmb"]) >= 0:
		var lmb := _latency(m, "lmb", "stun", PRESS_S, ROOT_PAST)
		ok(lmb == int(idle["lmb"]), "%s lmb at a stun's end with a root still on: %s" % [hero, _said(lmb)])
	if int(idle["dash"]) >= 0:
		var dash := _latency(m, "dash", "stun", PRESS_S, ROOT_PAST)
		ok(dash < 0 and dash != EARLY, "%s Shift at a stun's end with a root still on: %s" % [hero, _said(dash)])
	if int(idle["e"]) >= 0:
		var e := _latency(m, "e", "stun", EARLY_S)
		ok(e == LOST, "%s e pressed %.2fs before the stun ends is not held: %s" % [hero, EARLY_S, _said(e)])

func _said(got: int) -> String:
	if got == LOST:
		return "never went off"
	if got == EARLY:
		return "went off while the CC forbade it"
	return "went off %d steps after the CC let it" % got

## Steps from the first step `cc` (with `left` s to run; "" for none) lets `slot` go to the step the press made now
## goes off; LOST or EARLY. `root_past`: a root that outlasts the stun by this much.
func _latency(m: Match, slot: String, cc: String, left: float, root_past := 0.0) -> int:
	var h: Hunter = flow.hunter
	h.root_t = 0.0
	h.set_meta("gnd_until", 0.0)
	flow._ready_up(m)
	match cc:
		"stun":
			h.stun_t = left
		"root":
			h.root_t = left
		"gnd":
			KitStatus.apply(h, "gnd", left, 0.0, false)
	if root_past > 0.0:
		h.root_t = left + root_past
	var before := _snap()
	_press(slot)
	var allowed_at := -1
	for i in WATCH:
		m.step(Match.DT)
		h.inp["fire"] = false      # DashFlow's replayed LMB is a tap
		if allowed_at < 0 and h.ak.flow.cc_left(slot) <= 0.0:
			allowed_at = i
		if _went_off(before, slot):
			return i - allowed_at if allowed_at >= 0 else EARLY
	return LOST

func _press(slot: String) -> void:
	if slot in ["dash", "jump"]:
		flow.hunter.inp[slot] = true
	else:
		flow._press(slot)

func _snap() -> Dictionary:
	var h: Hunter = flow.hunter
	return flow._snap().merged({"dashes": h.dashes, "jump_at": h.jump_at})

func _went_off(before: Dictionary, slot: String) -> bool:
	var h: Hunter = flow.hunter
	match slot:
		"dash":
			return h.ak.in_dash() or h.roll_t > 0.0 or h.dashes < float(before["dashes"])
		"jump":
			return h.jump_at > float(before["jump_at"])
	return flow._went_off(before, slot)
