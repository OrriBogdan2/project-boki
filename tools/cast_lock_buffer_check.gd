extends RefCounted
## --cast-lock-buffer-check (docs/decisions/0022-cc-exit-buffer.md, addendum): for every hero whose ult holds the
## body in a cast lock (ArchKit.busy() beyond disabled(): Motley's Nightwell cast, Kael's Riposte guard and cleave,
## Vex's Kitefall), an RMB or E pressed LATE_S before the lock ends is held (DashFlow) and goes off once the lock
## lets it, never inside it; one pressed at the lock's start (outside Loco.press_buffer) is refused, not held for
## the whole lock. The heroes that lock are asserted (LOCKED), so a new lock gets its row here. Reuses the dash-flow
## check's training match and slot presses. Never touches the save.

const LATE_S := 0.1             # s of lock left when the late press is made (inside Loco.press_buffer)
const EARLY_AT := 2             # steps into the lock for the press that comes too early to be held
const SETTLE := 20              # steps the ult may take to start its lock
const LOCK_MAX := 600           # steps a lock may run before the check gives up on it
const PAST := 0.4               # s past the lock's end we watch for the press
const LOCKED := ["juggernaut", "mage", "ostra"]     # the kits whose ult locks the body today

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
