extends RefCounted
## --glide-after-attack-check: the glider is never eaten by an attack's recovery (the owner's "lmb, let go, then
## glide doesn't work sometimes"). In the air, every hunter does one action (LMB held
## then released, RMB, E, Q, X, an air Shift), waits DELAYS_S after it, then presses glide: a second Space (jump
## press, glide held) or a short TAP of it (glide let go after TAP_STEPS, as a quick player's finger does). The
## glider must be open within OPEN_S of the press when only a recovery pose is left. While the action itself still
## runs (a hold, a channel, a planted cast, a knock) a held press opens within OPEN_S of its end, and a
## tap does too when the end comes inside Loco.press_buffer (a longer one refuses the tap, as DashFlow does).
## Prints one GLIDEAFTER row per trial.

const DELAYS_S := [0.0, 0.05, 0.1, 0.2]  # s after the action's last input step
const OPEN_S := 0.1  # s the glider may take to open after the press
const TAP_STEPS := 3  # steps a tap keeps glide down (50 ms)
const LMB_HOLD := 6  # steps LMB stays down before the release
const KNOCK_S := 0.4  # s after a knock (Vex's E recoil) that Hunter.can_glide keeps the glider shut
const HEIGHT := 60.0  # m above the patch the trial starts: still in the air when it ends
const SLOTS := ["lmb", "rmb", "e", "q", "x", "dash"]

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()


func ok(cond: bool, what: String) -> void:
	print("GLIDEAFTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	for hero in Arch.ORDER:
		var m: Match = flow._match(main, hero)
		for slot in SLOTS:
			for tap in [false, true]:
				for delay in DELAYS_S:
					_trial(m, hero, slot, tap, delay)
		m.queue_free()
		await main.get_tree().process_frame
	print("GLIDEAFTER DONE, failures: %d" % bad)
	main.get_tree().quit()


## One action, a wait, a glide press: the steps from the press to an open glider (-1: never in WATCH_S).
func _trial(m: Match, hero: String, slot: String, tap: bool, delay: float) -> void:
	var h: Hunter = m.player
	flow._ready_up(m)
	h.teleport(h.pos + Vector3(0, HEIGHT, 0))
	h.grounded = false
	h.glide_fuel = 1.0
	h.inp["glide_press_only"] = true
	var steps := LMB_HOLD if slot == "lmb" else 1
	for i in steps:
		if slot == "dash":
			h.inp["dash"] = true
		else:
			flow._press(slot)
			h.inp["fire"] = slot == "lmb"
		m.step(Match.DT)
	h.inp["dash"] = false
	h.inp["fire"] = false
	for i in int(round(delay / Match.DT)):
		m.step(Match.DT)
	var open := -1
	var lock_last := -1
	for i in 400:
		h.inp["jump"] = i == 0
		h.inp["glide"] = i < TAP_STEPS if tap else true
		h.inp["glide_btn"] = h.inp["glide"]
		m.step(Match.DT)
		if h.gliding:
			open = i
			break
		if h.grounded:
			break  # landed inside the lock (a dive that lasts to the ground)
		if AirLimits.hard_locked(h) or h.glide_cd > 0.0 or m.time - h.kb_t <= KNOCK_S:
			lock_last = i
	h.inp["jump"] = false
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	var lock_s := float(lock_last + 1) * Match.DT
	var what := "%s %s then %s glide %.0f ms later" % [hero, slot, "tap" if tap else "hold", delay * 1000.0]
	if h.grounded:
		ok(true, "%s: landed first (a %.2f s lock to the ground)" % [what, lock_s])
	elif lock_last < 0:
		ok(open >= 0 and float(open) * Match.DT <= OPEN_S, "%s: opened at +%d steps" % [what, open])
	elif tap and lock_s > Loco.press_buffer:
		ok(open < 0, "%s: refused by a %.2f s lock (opened at +%d)" % [what, lock_s, open])
	else:
		var wait := float(open - lock_last - 1) * Match.DT
		ok(open >= 0 and wait <= OPEN_S, "%s: %.2f s lock, opened at +%d" % [what, lock_s, open])
