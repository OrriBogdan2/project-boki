extends RefCounted
## --input-latency-check: source feel is instant, the first frame of motion or the shot follows the press. For
## every Hunter it presses LMB, RMB, E, dash and jump through the real input path (Input actions, Match._process:
## gather, pending input, the step, the render) at a known physics tick, and records the first tick on which the
## Hunter's velocity, its animation state (HunterAnim's input) or a projectile of theirs changes. Tick 0 is the
## step that ran in the frame of the press. Target: tick 0 or 1, unless WINDUP names a sourced wind-up.
## Prints one "LATENCY <hero> <slot> ..." row per press and the table in docs/MOVEMENT_FEEL.md. Never touches the save.
## --input-latency-check=<id>,<id> runs only those heroes.

const DT := Match.DT
const WATCH := 45               # ticks after the press we watch (0.75 s)
const TAP := 6                  # ticks a press is held: a quick real tap (0.1 s), so tap/hold kits see a tap
const MAX_TICK := 1             # the same or the next physics tick
const ACTION := {"lmb": "fire", "rmb": "secondary", "e": "signature", "dash": "dash", "jump": "jump"}
## hero -> slot -> [ticks allowed, source]: a wind-up the source has before the first motion or shot. A tap/hold
## RMB can't show which it is until the release (the tap) or the hold threshold: it acts on the tap's release.
const WINDUP := {
	"juggernaut": {"rmb": [TAP + 1, "tap/hold, the tap's Finishing Slam starts on the release (heroes/juggernaut.md)"]},
	"dolm": {"rmb": [TAP + 1, "tap/hold, owner item 61: a tap shows nothing, lands on the release (heroes/dolm.md)"]},
}

var bad := 0
var flow                        # tools/dash_flow_check.gd: its training match, ready-up and press snapshot
var hunter: Hunter
var rows: Array[String] = []

func run(main: Node) -> void:
	Save.no_write = true
	Settings.set_v("cast_on_press", true, false)    # the default: an ability goes off on the press
	flow = load("res://tools/dash_flow_check.gd").new()
	CombatBus.ability_used.connect(flow._on_used)
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		hunter = flow.hunter
		for slot in ACTION:
			await _trial(main, m, hero, slot)
		m.queue_free()
		await main.get_tree().process_frame
	print("LATENCY table (ticks after the press; - = none in %d)" % WATCH)
	print("| Hunter | " + " | ".join(ACTION.keys()) + " |")
	for r in rows:
		print(r)
	print("INPUT LATENCY CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input-latency-check=") and arg.length() > 22:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## One press of `slot` from standing still, ready, on flat ground.
func _trial(main: Node, m: Match, hero: String, slot: String) -> void:
	flow._ready_up(m)
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = DT * 0.5            # every _process runs exactly one step: frame n is tick n
	for i in 3:
		await main.get_tree().process_frame
		m._process(DT)
	var before: Dictionary = flow._snap()
	var vel0 := hunter.vel
	var anim0 := _anim_sig(m)
	var first := {"vel": -1, "anim": -1, "shot": -1, "act": -1}
	Input.action_press(ACTION[slot])
	for tick in WATCH:
		if tick == TAP:
			Input.action_release(ACTION[slot])
		m._process(DT)              # in the press's own frame, so the press is "just pressed" here
		_first(first, "vel", tick, hunter.vel.distance_to(vel0) > 0.05)
		_first(first, "anim", tick, _anim_sig(m) != anim0)
		_first(first, "shot", tick, flow._last_shot() > int(before["shots"]))
		_first(first, "act", tick, _acted(before, slot))
		await main.get_tree().process_frame
	Input.action_release(ACTION[slot])
	var seen: Array = [first["vel"], first["anim"], first["shot"]].filter(func(t): return t >= 0)
	var at: int = seen.min() if not seen.is_empty() else -1
	var allowed: int = MAX_TICK
	var why := ""
	if WINDUP.get(hero, {}).has(slot):
		allowed = int(WINDUP[hero][slot][0])
		why = "  wind-up: " + String(WINDUP[hero][slot][1])
	var pass_ := at >= 0 and at <= allowed
	if not pass_:
		bad += 1
	var each := "vel %2s anim %2s shot %2s act %2s" % [
			_t(first["vel"]), _t(first["anim"]), _t(first["shot"]), _t(first["act"])]
	print("LATENCY %-10s %-4s first %2s (%s) target <= %d %s%s" % [hero, slot, _t(at), each, allowed,
			"ok" if pass_ else "FAIL", why])
	_cell(hero, slot, at, first)

func _first(first: Dictionary, key: String, tick: int, changed: bool) -> void:
	if changed and int(first[key]) < 0:
		first[key] = tick

## The press registered at all (dash_flow's "went off"), or for the moves: rolling, left the ground.
func _acted(before: Dictionary, slot: String) -> bool:
	match slot:
		"dash":
			return hunter.roll_t > 0.0 or hunter.ak.in_dash()
		"jump":
			return not hunter.grounded
	return flow._went_off(before, slot)

## What HunterAnim is told this frame that a press can change (Hunter._anim_state): times of the last cast,
## shot and kit move, the swing count, the dodge, leaving the ground, a charge and the muzzle flash.
func _anim_sig(m: Match) -> Array:
	var s: Dictionary = hunter.anim_s
	return [s.get("rolling"), s.get("grounded"), s.get("gliding"), s.get("swing_n"), s.get("kmove", ""),
			snappedf(m.time - float(s.get("kmove_t", 0.0)), 0.001), snappedf(m.time - float(s.get("cast", 0.0)), 0.001),
			snappedf(m.time - float(s.get("fired", 0.0)), 0.001), float(s.get("charge", 0.0)) > 0.0,
			float(s.get("flash", 0.0)) > 0.0, s.get("act")]

func _t(tick: int) -> String:
	return str(tick) if tick >= 0 else "-"

func _cell(hero: String, slot: String, at: int, first: Dictionary) -> void:
	if slot == "lmb":
		rows.append("| %s |" % hero)
	var what := []
	for key in ["vel", "anim", "shot"]:
		if int(first[key]) == at and at >= 0:
			what.append(key)
	rows[-1] += " %s %s |" % [_t(at), "/".join(what)]
