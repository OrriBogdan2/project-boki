extends RefCounted
## --cc-press-check: a press made while a hunter is stunned, rooted or knocked, for every hero and slot (LMB,
## RMB, E, X, Shift). Source (briefs/hero-ref footage, presses right as a stun ends): the press goes on the first
## free frame if the lock ends within a short window, and a stale press from early in the lock is refused.
## Ours: DashFlow holds a locked press for BUFFER_S (one rule for every kit, the dash buffer's window), then
## replays it through the slot's own path. Trials: pressed 0.1 s and 0.05 s before a 1 s stun ends (goes on the
## first free step), 0.5 s before (refused), during a knock (no slot is locked: goes at once) and, for Shift, 0.1 s
## before a 1 s root ends (abilities aren't locked by a root, so they aren't tried in one). --cc-press-check=<id>,<id>
## runs only those heroes. Reuses the dash-flow check's match, press and went-off helpers. Never touches the save.

const WATCH := 60               # steps after the press that we watch for the slot
const SLOTS := ["lmb", "rmb", "e", "x", "dash"]
## [name, lock, seconds the lock still has at the press]; "knock" sets knock_t (no press is locked by it)
const CASES := [["stun late", "stun", 0.1], ["stun last", "stun", 0.05], ["stun early", "stun", 0.5],
		["knock", "knock", 0.3], ["root", "root", 0.1]]
const NEXT_STEP := Match.DT * 1.5        # s: a tap that goes on its release (a sword) shows one step later
const LOCK_S := 1.0             # s: the stun or root of each trial
const SETTLE := 60              # steps between trials: a kit's thrown thing (the Juggernaut's hook) comes back first

var bad := 0
var skipped := 0
var D := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("CCPRESS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	ok(absf(DashFlow.BUFFER_S - 0.15) < 0.001, "one window for every kit: DashFlow.BUFFER_S 0.15 s")
	CombatBus.ability_used.connect(D._on_used)
	for hero in _heroes():
		var m: Match = D._match(main, hero)
		for slot in SLOTS:
			_slot(m, hero, slot)
		m.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(D._on_used)
	print("CCPRESS DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cc-press-check=") and arg.length() > 17:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

func _slot(m: Match, hero: String, slot: String) -> void:
	if not _goes_idle(m, slot):
		skipped += 1
		print("CCPRESS skip %s %s: it doesn't go off unlocked here either" % [hero, slot])
		return
	for c in CASES:
		if c[1] == "root" and slot != "dash":
			continue
		var got := _trial(m, c[1], float(c[2]), slot)
		var what := "%s %s, %s: %s" % [hero, slot, c[0], got]
		match c[0]:
			"stun early":
				ok(got == "refused", what)
			"knock":
				ok(got == "at once" or _soon(got), what)
			_:
				ok(got == "first free step" or _soon(got), what)

## "late +0.02s": one step after the reference step (a release-fired tap).
func _soon(got: String) -> bool:
	return got.begins_with("late +") and got.substr(6).to_float() < NEXT_STEP

## Control: the slot goes off when pressed free.
func _goes_idle(m: Match, slot: String) -> bool:
	if slot != "dash":
		return D._goes_idle(m, slot, false)
	D._ready_up(m)
	_press(slot)
	m.step(Match.DT)
	return D.hunter.ak.in_dash()

## One press `lead` seconds before `lock` ends: "at once" (went off the step of the press, not locked by it),
## "first free step" (went off the step the lock ended), "late +0.00s" (steps after the press or the lock's end),
## "refused" (never went off within WATCH) or "early" (a locked press went off before the lock ended).
func _trial(m: Match, lock: String, lead: float, slot: String) -> String:
	D._steps(m, SETTLE)
	D._ready_up(m)
	var h: Hunter = D.hunter
	match lock:
		"stun": h.stun_t = LOCK_S
		"root": h.root_t = LOCK_S
		"knock":
			h.knock_t = lead
			h.vel = Vector3(8, 0, 0)
	while _left(h, lock) > lead + Match.DT * 0.5:
		m.step(Match.DT)
	var before: Dictionary = D._snap()
	var dashes := h.dashes
	_press(slot)
	var locked := _locks(lock, slot)
	var ended := -1 if locked else 0          # the reference step: the lock's end, or the press itself
	for i in WATCH:
		m.step(Match.DT)
		h.inp["fire"] = false
		if locked and ended < 0 and _left(h, lock) <= 0.0:
			ended = i
		if _went_off(before, dashes, slot):
			if ended < 0:
				return "early"
			if ended == i:
				return "first free step" if locked else "at once"
			return "late +%.2fs" % (float(i - ended) * Match.DT)
	return "refused"

## A stun locks every slot; a root only Shift; a knock none.
func _locks(lock: String, slot: String) -> bool:
	return lock == "stun" or (lock == "root" and slot == "dash")

func _left(h: Hunter, lock: String) -> float:
	return h.stun_t if lock == "stun" else h.root_t

func _press(slot: String) -> void:
	if slot == "dash":
		D.hunter.inp["dash"] = true
	else:
		D._press(slot)

func _went_off(before: Dictionary, dashes: float, slot: String) -> bool:
	if slot == "dash":
		return D.hunter.ak.in_dash() or D.hunter.dashes < dashes - 0.001
	return D._went_off(before, slot)
