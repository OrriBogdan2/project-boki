extends RefCounted
## --hitstop-input-check: a press made inside a hit-stop plays out the moment the freeze ends (source parity:
## heavy hitters never feel sticky). For every Hunter, the kit's heaviest own-body freeze lands on a dummy
## (Kael's Smash in its sweet band, Mossy's perfect swing, Tenzo's punch, Grimble's anchor slam, Cinder's ram,
## the others' top hit), then Shift, LMB, E or Space is tapped inside the freeze, and in a replica of the same
## match the same tap is made on the first frame after it: the inside tap must act no later than the outside
## one, and never be lost while the outside one acts. The frames run through Match._process (the hit-stop gate
## and _gather_input) and the keys through Input.action_press, so the real input path is under test. A kit
## whose top hit never freezes its own body (ranged hits don't, docs/DASHES_AND_ABILITY_FEEL.md §5.4) gets the
## T4 freeze injected at its hit and the row says so. --hitstop-input-check=<id>,<id> runs only those heroes.
## Never touches the save.

const LAND_WAIT := 150          # steps: the heavy hit lands within this (holds included)
const WATCH_F := 90             # frames: the freeze and the tapped action both fit in this
const SETTLE := 40              # steps before the hit: the fresh match's own hit-stop budget and pair window clear
const SEED := 77                # the two trials of a pair replay the same match: only the tap's timing differs
## hero -> [the top hit's slot, how long it's held (steps), the dummy's distance in front (m)]
const HEAVY := {
	"juggernaut": ["rmb", 60, 3.2],     # Smash held to full, the dummy in the sweet band (2.4-4.2 m): payoff
	"bulwark": ["lmb", 78, 2.0],        # Crushing Blow let go in the perfect window (full 1.25 s + 0.18 s)
	"dolm": ["lmb", 30, 2.5],           # the punch (a hold past lmb.tap)
	"dredge": ["e", 1, 4.0],            # the anchor slam
	"ashwick": ["dash", 1, 3.0],        # the ram
	"gunslinger": ["e", 1, 4.0],
	"mage": ["dash", 1, 2.0],
	"ostra": ["e", 60, 3.0],
	"rimewright": ["lmb", 1, 4.0],
	"archer": ["lmb", 20, 5.0],
	"tender": ["lmb", 1, 4.0],
	"thief": ["lmb", 1, 2.0],
	"gil": ["lmb", 1, 4.0],              # Tide Lunge, tapped (row added when Gil landed)
}
const KEYS := {"dash": "dash", "lmb": "fire", "e": "signature", "jump": "jump"}      # tapped -> its input action
const FWD := Vector3(0, 0, -1)       # the dummy stands where ready-up aims the hunter

var flow                        # the dash-flow check: its training match, ready-up and went-off detector
var hunter: Hunter
var dummy: Hunter
var bad := 0
var injected := 0
var unlanded := 0

func ok(cond: bool, what: String) -> void:
	print("HITSTOP-INPUT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	flow = load("res://tools/dash_flow_check.gd").new()
	CombatBus.ability_used.connect(flow._on_used)
	for hero in _heroes():
		for key in KEYS:
			var inside: Array = await _trial(main, hero, key, true)
			var after: Array = await _trial(main, hero, key, false)
			var a := int(inside[0])
			var b := int(after[0])
			var fine := (a < 0 and b < 0) or (a >= 0 and (b < 0 or a <= b))
			var note := " (neither acts: the kit takes no tap here)" if a < 0 and b < 0 else ""
			ok(fine, "%s %s: tapped inside the freeze acts %s, tapped after it %s; freeze %d frames, %s%s" % [
					hero, key, _when(a), _when(b), int(inside[1]), String(inside[2]), note])
	CombatBus.ability_used.disconnect(flow._on_used)
	print("HITSTOP-INPUT DONE, failures: %d, injected freezes: %d, hits that didn't land: %d" % [
			bad, injected, unlanded])
	main.get_tree().quit()

## Every hero, or the ones named in --hitstop-input-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hitstop-input-check=") and arg.length() > 22:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

func _when(frames: int) -> String:
	return "lost" if frames < 0 else "on frame %d" % frames

## One trial in a fresh, seeded match: the heavy hit, then `key` tapped on the first two frames of the freeze
## (or the first two after it). Returns [frames after the freeze until the action starts (-1: lost), the
## freeze's frames, its source].
func _trial(main: Node, hero: String, key: String, inside: bool) -> Array:
	seed(SEED)
	var m: Match = flow._match(main, hero)
	hunter = flow.hunter
	dummy = null
	for other in m.hunters:
		if other.team != hunter.team:
			dummy = other
			break
	flow._ready_up(m)
	flow._steps(m, SETTLE)
	_place_dummy()
	var source := _land(m, HEAVY[hero])
	hunter.inp["fire"] = false
	hunter.inp["sec_hold"] = false
	var before: Dictionary = flow._snap()
	var dashes0 := float(hunter.dashes)
	var roll0 := hunter.roll_t
	var jump0 := hunter.jump_at
	var action := String(KEYS[key])
	var pressed := 0
	var freeze_frames := 0
	var frames := 0
	var start := -1
	m.acc = 0.0
	for f in WATCH_F:
		var frozen := m.hitstop > 0.0
		if frozen:
			freeze_frames += 1
		if pressed == 0 and frozen == inside:
			Input.action_press(action)
			pressed = 1
		elif pressed == 1:
			Input.action_release(action)
			pressed = 2
		m._process(Match.DT)
		await main.get_tree().process_frame
		if frozen:
			continue
		if _acted(before, key, dashes0, roll0, jump0):
			start = frames
			break
		frames += 1
	if pressed == 1:
		Input.action_release(action)
	m.queue_free()
	await main.get_tree().process_frame
	return [start, freeze_frames, source]

func _place_dummy() -> void:
	dummy.ctrl = "idle"
	dummy.teleport(hunter.pos + FWD * float(HEAVY[hunter.arch][2]))
	dummy.vel = Vector3.ZERO
	dummy.hp = dummy.max_hp
	hunter.inp["aim"] = dummy.pos + Vector3(0, 0.9, 0)

## Presses the top hit and steps until it freezes the hunter's own body ("real"), or lands without one and
## gets the T4 freeze injected ("injected"), or never lands (the freeze is injected anyway: "no hit").
func _land(m: Match, how: Array) -> String:
	var slot := String(how[0])
	var hold := int(how[1])
	var hp0 := dummy.hp
	m.hitstop = 0.0
	for i in LAND_WAIT:
		var down := i < hold
		match slot:
			"lmb":
				hunter.inp["fire"] = down
			"rmb":
				hunter.inp["sec"] = i == 0
				hunter.inp["sec_hold"] = down
			"e":
				hunter.inp["sig"] = i == 0
			"dash":
				hunter.inp["move"] = Vector2(FWD.x, FWD.z)
				hunter.inp["dash"] = i == 0
		m.step(Match.DT)
		if m.hitstop > 0.0:
			return "real"
		if dummy.hp < hp0 - 0.01:
			injected += 1
			m.freeze_frame(float(Feel.HITSTOP[4][0]))
			return "injected"
	unlanded += 1
	m.freeze_frame(float(Feel.HITSTOP[4][0]))
	return "no hit"

func _acted(before: Dictionary, key: String, dashes0: float, roll0: float, jump0: float) -> bool:
	match key:
		"dash":
			return float(hunter.dashes) < dashes0 or (hunter.roll_t > 0.0 and roll0 <= 0.0)
		"jump":
			return hunter.jump_at > jump0
	return flow._went_off(before, key)
