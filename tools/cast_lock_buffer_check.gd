extends RefCounted
## --cast-lock-buffer-check (docs/decisions/0022-cc-exit-buffer.md, addendum): for every hero whose ult holds the
## body in a cast lock (ArchKit.busy() beyond disabled(): Motley's Nightwell cast, Kael's Riposte guard and cleave,
## Vex's Kitefall), an RMB or E pressed LATE_S before the lock ends is held (DashFlow) and goes off once the lock
## lets it, never inside it; one pressed at the lock's start (outside Loco.press_buffer) is refused, not held for
## the whole lock. The heroes that lock are asserted (LOCKED), so a new lock gets its row here. Reuses the dash-flow
## check's training match and slot presses. Part 2: E pressed inside every RMB hold wind-up is not lost. Part 3: the
## owner's exception, Cinder's Flue Flight ignores LMB, RMB and Shift (item 66), E works. Never touches the save.

const LATE_S := 0.1             # s of lock left when the late press is made (inside Loco.press_buffer)
const EARLY_AT := 2             # steps into the lock for the press that comes too early to be held
const SETTLE := 20              # steps the ult may take to start its lock
const LOCK_MAX := 600           # steps a lock may run before the check gives up on it
const PAST := 0.4               # s past the lock's end we watch for the press
const LOCKED := ["juggernaut", "mage", "ostra"]     # the kits whose ult locks the body today
const HOLD_S := 0.1             # s an RMB hold runs on past the E press before the key is let go
const INTO := 10                # steps into Cinder's flight the press is made
const FLIGHT := {"lmb": LOST, "rmb": LOST, "dash": LOST, "e": 0}       # item 66: only E works, the rest is ignored

var bad := 0
var skipped := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("CASTLOCK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(flow._on_used)
	var found := []
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		if _hero(m, hero):
			found.append(hero)
		m.queue_free()
		await main.get_tree().process_frame
	ok(found == LOCKED, "the ults that lock the body: %s (expected %s)" % [found, LOCKED])
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		_hold_row(m, hero)
		if hero == "ashwick":
			_flight_rows(m)
		m.queue_free()
		await main.get_tree().process_frame
	print("CASTLOCK DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

## True when the hero's ult locks the body.
func _hero(m: Match, hero: String) -> bool:
	var lock_n := _lock_steps(m)
	if lock_n <= 0:
		return false
	for slot in ["rmb", "e"]:
		if not flow._goes_idle(m, slot, false):
			skipped += 1
			print("CASTLOCK skip %s %s: it doesn't go off without a lock here either" % [hero, slot])
			continue
		var late := lock_n - int(LATE_S / Match.DT)
		var got := _trial(m, late, slot)
		ok(got >= 0 and got != INSIDE, "%s %s pressed %.2fs before its %.2fs lock ends: %s"
				% [hero, slot, (lock_n - late) * Match.DT, lock_n * Match.DT, _said(got)])
		if lock_n * Match.DT > Loco.press_buffer + LATE_S:
			got = _trial(m, EARLY_AT, slot)
			ok(got == LOST, "%s %s pressed %.2fs before its lock ends is not held: %s"
					% [hero, slot, (lock_n - EARLY_AT) * Match.DT, _said(got)])
	return true

const LOST := -1                # never went off
const INSIDE := -2              # went off while the lock still held

func _said(got: int) -> String:
	if got == LOST:
		return "never went off"
	if got == INSIDE:
		return "went off inside the lock"
	return "went off %d steps after the lock let it" % got

func _locked() -> bool:
	var k := flow.hunter.ak
	return k.busy() and not k.disabled()

## Casts the ult and counts the steps its lock holds the kit (0: no lock within SETTLE steps).
func _lock_steps(m: Match) -> int:
	_start(m)
	if not _locked():
		return 0
	var n := 0
	while _locked() and n < LOCK_MAX:
		m.step(Match.DT)
		n += 1
	return n

## Readies the hunter, casts the ult and steps to the lock's first step (or SETTLE steps when none comes).
func _start(m: Match) -> void:
	flow._ready_up(m)
	flow._press("x")
	for i in SETTLE:
		if _locked():
			return
		m.step(Match.DT)

## Steps from the first step the lock lets `slot` go to the step a press made `at` steps into the lock goes off;
## LOST or INSIDE.
func _trial(m: Match, at: int, slot: String) -> int:
	_start(m)
	flow._steps(m, at)
	var before := flow._snap()
	flow._press(slot)
	var freed_at := -1
	for i in int((LOCK_MAX + PAST / Match.DT)):
		m.step(Match.DT)
		if freed_at < 0 and not _locked():
			freed_at = i
		if flow._went_off(before, slot):
			return i - freed_at if freed_at >= 0 else INSIDE
		if freed_at >= 0 and i - freed_at > int(PAST / Match.DT):
			break
	return LOST

## Part 2, a hold wind-up: for every kit whose RMB is a hold (Tenzo's Quakefall charge, Albert's Lunge, Sparkle's
## Storm Rod...), E pressed HOLD_S before the key is let go. The press is not lost: it goes inside the hold if the kit
## casts through its charge, or on the first step after the release.
func _hold_row(m: Match, hero: String) -> void:
	if not flow._is_hold(m, "rmb"):
		return
	flow._ready_up(m)
	flow._hold_key("rmb", true)
	flow._steps(m, int((flow._threshold("rmb") + flow.HOLD_PAST) / Match.DT))
	if not flow.hunter.ak.rmb_down:
		skipped += 1
		print("CASTLOCK skip %s: its RMB hold doesn't start here" % hero)
		return
	var before := flow._snap()
	flow._press("e")
	var got := LOST
	for i in int(HOLD_S / Match.DT):
		m.step(Match.DT)
		if flow._went_off(before, "e"):
			got = INSIDE
			break
	flow._hold_key("rmb", false)
	if got == LOST:
		for i in int(PAST / Match.DT):
			m.step(Match.DT)
			if flow._went_off(before, "e"):
				got = i
				break
	ok(got != LOST, "%s E pressed %.2fs before its RMB hold is let go: %s" % [hero, HOLD_S, _said_hold(got)])

func _said_hold(got: int) -> String:
	if got == INSIDE:
		return "went off inside the hold"
	return _said(got).replace("the lock let it", "the release")

## Part 3, the owner's exception (item 66, AshwickJet.lock_inputs): in Cinder's Flue Flight only E works; LMB, RMB
## and Shift are ignored, not buffered: nothing inside the flight and nothing when it lands.
func _flight_rows(m: Match) -> void:
	for slot in FLIGHT:
		flow._ready_up(m)
		flow._press("x")
		for i in SETTLE:
			if flow.hunter.ak.ult_running():
				break
			m.step(Match.DT)
		if not flow.hunter.ak.ult_running():
			skipped += 1
			print("CASTLOCK skip ashwick %s: Flue Flight didn't start" % slot)
			return
		flow._steps(m, INTO)
		var h := flow.hunter
		var before := flow._snap()
		var dashes0 := h.dashes
		if slot == "dash":
			h.inp["dash"] = true
		else:
			flow._press(slot)
		var got := LOST
		var landed := -1
		for i in int(LOCK_MAX + PAST / Match.DT):
			m.step(Match.DT)
			h.inp["fire"] = false
			if landed < 0 and not h.ak.ult_running():
				landed = i
			var went: bool = h.dashes < dashes0 if slot == "dash" else flow._went_off(before, slot)
			if went:
				got = i - landed if landed >= 0 else INSIDE
				break
			if landed >= 0 and i - landed > int(PAST / Match.DT):
				break
		var want: int = FLIGHT[slot]
		var fine: bool = got == want or (want == 0 and got == INSIDE)
		var said := _said(got).replace("the lock let it", "the landing")
		ok(fine, "ashwick %s pressed in Flue Flight: %s (item 66: %s)"
				% [slot, said, "works" if want == 0 else "ignored, not buffered"])
