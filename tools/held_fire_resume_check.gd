extends RefCounted
## --held-fire-resume-check: LMB is a held input (source parity, docs/heroes/dash_interactions.md): held through
## a dash, RMB, E, the ult or a glove, fire resumes the frame that action's lock ends, with no re-press. For
## every Hunter and every slot, three runs on the dash-flow check's training match: LMB held until the weapon
## fires steadily (or its hold has started), the slot pressed, then (A) LMB kept down, or (B) let go on the press
## and tapped on every other frame, odd then even. B's first accepted tap is the frame the lock ends, as the kit
## itself defines it (cooldowns, cadence, a dash row's buffer, an ult that owns the key); A's next shot must come
## within RESUME_F of it. A hold kit (a draw, a charge, a hose: ArchKit.lmb_holding) must be holding again by
## then and must not loose a stale release between the press and the restart. --held-fire-resume-check=<id>,<id>
## runs only those heroes. Never touches the save.

const RESUME_F := 1             # frames: fire is back within this of the lock's end (the source: the frame it ends)
const WARM := 90                # steps LMB is held before the press: the weapon fires steadily
const HOLD_PAST := 0.15         # s past the kit's tap a hold charges before the press (short of any auto-release)
const ACT_WAIT := 30            # steps: the slot goes off within this
const WATCH := 240              # steps after the press that we watch for the lock's end and the next shot
const SETTLE := 60              # steps the key is up between runs: the last hold's release swings and cools down
## slot -> its one-step Hunter.inp key ("" for X: HunterKeys); the dash is Shift
const KEYS := {"dash": "dash", "rmb": "sec", "e": "sig", "x": "", "q": "gear1"}
const HELD := 0                 # the runs: LMB kept down; tapped on odd frames; tapped on even frames
const TAP_ODD := 1
const TAP_EVEN := 2

var flow                        # the dash-flow check: its training match, ready-up and went-off detectors
var hunter: Hunter
var bad := 0
var skipped := 0

func ok(cond: bool, what: String) -> void:
	print("HELD-FIRE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	flow = load("res://tools/dash_flow_check.gd").new()
	CombatBus.ability_used.connect(flow._on_used)
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		hunter = flow.hunter
		for slot in KEYS:
			_trial(m, hero, slot)
		m.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(flow._on_used)
	print("HELD-FIRE DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

## Every hero, or the ones named in --held-fire-resume-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--held-fire-resume-check=") and arg.length() > 25:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## One hero, one slot: the held run against the two tapped ones.
func _trial(m: Match, hero: String, slot: String) -> void:
	var a := _run(m, slot, HELD)
	if a.has("skip"):
		skipped += 1
		print("HELD-FIRE skip %s %s: %s" % [hero, slot, a["skip"]])
		return
	var odd := _run(m, slot, TAP_ODD, not a["hold"])
	var even := _run(m, slot, TAP_EVEN, not a["hold"])
	var lock_end := _first(int(odd["resume"]), int(even["resume"]))
	# a tap that cuts the action short (Sable's Kitefall comes down on a fresh press) makes it another action: the
	# held run is judged against its own action's end
	var cut: bool = mini(int(odd["ended"]), int(even["ended"])) < int(a["ended"]) - 1
	if cut:
		lock_end = int(a["ended"])
	var resume := int(a["resume"])
	if lock_end < 0 and resume < 0:
		skipped += 1
		print("HELD-FIRE skip %s %s: the lock outlasts %d frames for a tap too" % [hero, slot, WATCH])
		return
	var gap := resume - lock_end if resume >= 0 and lock_end >= 0 else WATCH
	var fine := resume >= 0 and gap <= RESUME_F and not bool(a["stale"])
	ok(fine, "%s %s: %s on frame %s, held LMB %s on frame %s (gap %d)%s" % [hero, slot,
			"a tap cuts the action short, it ends" if cut else "a fresh tap is taken", _frame(lock_end),
			"holds again" if a["hold"] else "fires again", _frame(resume), gap,
			"; a stale release went off" if a["stale"] else ""])

func _first(x: int, y: int) -> int:
	if x < 0 or y < 0:
		return maxi(x, y)
	return mini(x, y)

func _frame(f: int) -> String:
	return "none" if f < 0 else str(f)

## One run: LMB held until it fires (or holds), the slot pressed on frame 0, LMB then held or tapped by `mode`.
## A tapped run of a hold kit starts with the key up (`warm` false): letting a hold go would swing and add the
## swing's own cooldown to the lock. {resume: the frame of the next shot or the hold's restart (-1: none), hold:
## a hold kit, stale: a hold kit loosed something before the restart} or {skip: why}.
func _run(m: Match, slot: String, mode: int, warm := true) -> Dictionary:
	flow._fresh(m)
	_settle(m)
	var k := hunter.ak
	var hold_kit := not warm
	var fired_once := false
	var prev := _snap()
	var tap := float(k.lmb_def().get("tap", 0.0))
	for i in WARM if warm else 0:
		_step(m, true)
		var now := _snap()
		fired_once = fired_once or _lmb_fired(prev, now)
		prev = now
		if k.lmb_holding() and i >= int((tap + HOLD_PAST) / Match.DT):
			hold_kit = true      # a draw, a charge or a hose has started: the hold is what must come back
			break
	if not fired_once and not hold_kit:
		return {"skip": "LMB never fires held on its own here"}
	var at_press: Dictionary = flow._snap()
	_press(slot)
	var acted := false
	var ended := WATCH
	var resume := -1
	var stale := false
	var before := _snap()
	for i in WATCH:
		_step(m, _down(mode, i))
		_unpress(slot)
		acted = acted or _acted(at_press, slot)
		if not acted and i >= ACT_WAIT:
			return {"skip": "the slot doesn't go off here with LMB held"}
		if acted and ended == WATCH and not _running(slot):
			ended = i
		var now := _snap()
		var fired := _lmb_fired(before, now)
		before = now
		if resume < 0 and hold_kit:
			if fired and mode == HELD:
				stale = true
			if k.lmb_holding() and (i > 0 or mode == HELD):
				resume = i
		elif resume < 0 and fired and (i > 0 or mode == HELD):
			resume = i
		if resume >= 0 and ended < WATCH:
			break
	return {"resume": resume, "hold": hold_kit, "stale": stale, "ended": ended}

## The last run's hold let go in ready-up: its swing and cooldown clear before this one starts.
func _settle(m: Match) -> void:
	hunter.inp["fire"] = false
	flow._steps(m, SETTLE)
	hunter.fire_cd = 0.0

## Whether the slot's action is still under way (the probes the dash-flow check's ready-up uses).
func _running(slot: String) -> bool:
	var k := hunter.ak
	match slot:
		"dash":
			return k.in_dash() or hunter.roll_t > 0.0
		"rmb":
			return k.rmb_down
		"e":
			return k.in_e()
		"x":
			return k.ult_running()
	return false

## Whether LMB is down on frame `i` of the run (frame 0 is the press: only the held run keeps it down there).
func _down(mode: int, i: int) -> bool:
	match mode:
		TAP_ODD:
			return i % 2 == 1
		TAP_EVEN:
			return i > 0 and i % 2 == 0
	return true

## One step with LMB down or up (a held key is read fresh every frame).
func _step(m: Match, down: bool) -> void:
	hunter.inp["fire"] = down
	m.step(Match.DT)

func _press(slot: String) -> void:
	if slot == "x":
		HunterKeys.ult_pressed(hunter)
	else:
		hunter.inp[KEYS[slot]] = true
	if slot == "rmb":
		hunter.inp["sec_hold"] = true

func _unpress(slot: String) -> void:
	if slot != "x":
		hunter.inp[KEYS[slot]] = false
	if slot == "rmb":
		hunter.inp["sec_hold"] = false

## Whether the slot went off since the press (a dash: the hunter is dashing or spent a charge).
func _acted(b: Dictionary, slot: String) -> bool:
	if slot == "dash":
		return hunter.ak.in_dash() or hunter.roll_t > 0.0 or hunter.dashes < hunter.max_dashes() - 0.01
	return flow._went_off(b, slot)

## What the attack key leaves behind: the newest attack shot (src "shot", or untagged; an ability's projectile
## carries its slot as "ab" or src "abil", a tell is cosmetic), the magazine, a swing, the primary casts.
func _snap() -> Dictionary:
	var last := -1
	for s in hunter.m.shots:
		var x: Dictionary = s["x"]
		var attack: bool = String(x.get("src", "")) == "shot" or not (x.has("src") or x.has("ab"))
		if s["by"] == hunter and attack and not x.get("cos", false):
			last = maxi(last, int(s["sid"]))
	return {"shot": last, "ammo": hunter.ammo, "swing": hunter.swing_t,
			"cast": int(flow.cast_n.get("primary", 0))}

func _lmb_fired(b: Dictionary, now: Dictionary) -> bool:
	return int(now["shot"]) > int(b["shot"]) or int(now["ammo"]) < int(b["ammo"]) \
			or float(now["swing"]) > float(b["swing"]) + 0.0001 or int(now["cast"]) > int(b["cast"])
