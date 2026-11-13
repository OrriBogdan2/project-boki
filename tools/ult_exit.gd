extends RefCounted
## An ult's cast lock and the press made at its end (docs/heroes/ults.md, docs/decisions/0022-cc-exit-buffer.md):
## a Shift, LMB or jump pressed PRESS_S before the lock ends goes off on the first free step, as in the source.
## Used by the hero ult checks (Albert, Kael, Motley, Sparkle). A press is timed in steps from the last step that
## forbade it (or from the press, with no lock): 1 is the next step. Kael's LMB, say, goes on its release, a step on.

const PRESS_S := 0.1           # s of lock left when the press is made (inside DashFlow.BUFFER_S)
const SLOTS := ["dash", "lmb", "jump"]
const LOCK_MAX := 240          # steps an ult may lock its caster in these trials (Sparkle's hover is the longest)
const WATCH := 60              # steps after the press we watch for it
const LOST := -1               # never went off
const EARLY := -2              # went off while the lock still held

## Plays the ult of `arch` once per slot with the press made PRESS_S before the lock lifts; returns
## {slot: [steps to go off at the lock's end (or LOST / EARLY), steps with no lock]}.
static func run(ak, arch: String) -> Dictionary:
	var r: Array = ak.setup(arch, 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var flow = preload("res://tools/dash_flow_check.gd").new()
	flow.hunter = P
	CombatBus.ability_used.connect(flow._on_used)
	P.lvl = 10
	var lock_n := _cast(m, P, LOCK_MAX)
	var out := {}
	for slot in SLOTS:
		_cast(m, P, lock_n - roundi(PRESS_S / Match.DT))
		var got := _press(m, P, flow, slot)
		_cast(m, P, 0, false)
		out[slot] = [got, _press(m, P, flow, slot)]
	CombatBus.ability_used.disconnect(flow._on_used)
	await ak.done(m)
	return out

## Whether the ult still holds its caster: no other key, or no walking.
static func locked(P: Hunter) -> bool:
	return P.ak.busy() or P.ak.move_k() <= 0.0

## Readies the hunter, casts the ult (unless not `ult`) and plays `n` steps of it (fewer if the lock ends first);
## the steps.
static func _cast(m: Match, P: Hunter, n: int, ult := true) -> int:
	var k := P.ak
	for i in LOCK_MAX * 2:
		if not k.ult_running() and not locked(P) and P.grounded and k.dash_left() <= 0.0 and P.roll_t <= 0.0:
			break
		m.step(Match.DT)
	for key in k.cd:
		k.cd[key] = 0.0
	P.dashes = P.max_dashes()
	P.fire_cd = 0.0
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	P.inp["aim"] = P.pos + Vector3(4, 0.9, 0)
	if ult:
		HunterKeys.ult_pressed(P)
	var steps := 0
	while steps < n and locked(P):
		m.step(Match.DT)
		steps += 1
	return steps

static func _press(m: Match, P: Hunter, flow, slot: String) -> int:
	var before: Dictionary = flow._snap().merged({"dashes": P.dashes, "jump_at": P.jump_at})
	if slot == "lmb":
		P.inp["fire"] = true
	else:
		P.inp[slot] = true
	var held := locked(P)
	var lock_end := -1
	for i in WATCH:
		var was_locked := locked(P)
		m.step(Match.DT)
		P.inp["fire"] = false          # a tap
		if lock_end < 0 and was_locked and not locked(P):
			lock_end = i
		if _went_off(P, flow, before, slot):
			return EARLY if held and lock_end < 0 else i - lock_end
	return LOST

static func _went_off(P: Hunter, flow, before: Dictionary, slot: String) -> bool:
	match slot:
		"dash":
			return P.dashes < float(before["dashes"])       # (Kael's cleave lunges as a dash: not a Shift)
		"jump":
			return P.jump_at > float(before["jump_at"])
	return flow._went_off(before, slot)

## One line of the result for a check's info.
static func said(got: Dictionary) -> String:
	var parts := []
	for slot in SLOTS:
		var n := int(got[slot][0])
		var at: String = {LOST: "lost", EARLY: "early"}.get(n, "+%d" % n)
		parts.append("%s %s (no lock +%d)" % [slot, at, int(got[slot][1])])
	return ", ".join(parts)

## Every press went off, after the lock and no later than the same press with no lock.
static func on_time(got: Dictionary) -> bool:
	for slot in SLOTS:
		var n := int(got[slot][0])
		if n < 0 or n > int(got[slot][1]):
			return false
	return true
