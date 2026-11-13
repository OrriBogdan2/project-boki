extends RefCounted
## --boki-steps-check: the Boki footsteps (BokiSteps, docs/AUDIO.md).
##   1. BokiSteps.TOUCH is what the clips measure: where each foot comes down in every rigged Boki's walk and run;
##      the ones with no stepping feet (the audit's EXEMPT) and the wisp have no entry, so they make no sound
##   2. every size family on every ground has its sound, and the weight picks the family (a size roll can move it)
##   3. a walking Boki plays steps at its cadence (the touchdowns per loop times the loops per second), and one
##      whose legs beat faster than BokiSteps.MIN_GAP_S plays one per gap
##   4. a flyer, a serpent, a blob and the wisp play none
##   5. with 12 Boki walking around the listener only the nearest MAX_VOICES step
## Drives the rigs by hand (fixed frames), so it needs no renderer. Never touches the save.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Audit := preload("res://tools/boki_anim_audit.gd")
const Check := preload("res://tools/boki_rig_check.gd")
const SURFACES := ["grass", "stone", "wood", "snow"]
const SILENT := ["wisplet"]       # steps in its clips, but a wisp makes no footsteps
const MERGE := 3                  # poses: feet landing this close together are one step
const DT := 1.0 / 60.0            # s per driven frame
const WARM_S := 1.0               # s the rig takes to settle into its gait
const COUNT_S := 4.0              # s a step count is taken over
const SPEED := 1.5                # m/s: a stroll (home.gd)
const SLOW := 0.8                 # m/s: a dawdle, where the legs beat slower than MIN_GAP_S
const CROWD := 12                 # Boki walking at once for the voice cap
const CROWD_NEAR := 2.0           # m: the nearest of them
const CROWD_GAP := 0.9            # m between them

var bad := 0
var speed := SPEED            # m/s the driven Boki walk at

func ok(cond: bool, what: String) -> void:
	print("BOKISTEPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	ok(Audit.SAMPLES == BokiSteps.SAMPLES, "the table and the audit slice the loop the same way")
	for id in Check.SPECIES_LIST:
		await _table(main, id)
	_families()
	await _cadence(main)
	await _crowd(main)
	print("BOKISTEPS DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The poses where a foot comes down in `clip`: the planted spans' starts, feet landing together merged.
static func measure(rig: BokiRig, clip: String) -> Array:
	var starts := {}
	for foot: Array in Audit.contact_steps(rig, clip):
		for i in BokiSteps.SAMPLES:
			if not is_nan(foot[i]) and is_nan(foot[(i + BokiSteps.SAMPLES - 1) % BokiSteps.SAMPLES]):
				starts[i] = true
	var poses: Array = starts.keys()
	poses.sort()
	var out: Array = []
	for p: int in poses:
		if out.is_empty() or p - int(out[-1]) > MERGE:
			out.append(p)
	if out.size() > 1 and int(out[0]) + BokiSteps.SAMPLES - int(out[-1]) <= MERGE:
		out.pop_back()
	return out

func _table(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.manual = true
	var row := {}
	for clip in ["walk", "run"]:
		row[clip] = measure(rig, clip)
	print("BOKISTEPS TABLE %s %s" % [id, row])
	if id in Audit.EXEMPT or id in SILENT:
		ok(not BokiSteps.TOUCH.has(id), "%s makes no steps, so it has no entry" % id)
	else:
		ok(BokiSteps.TOUCH.get(id, {}) == row, "%s: the table's touchdowns are the clips' %s" % [id, row])
	k.queue_free()

func _families() -> void:
	var missing: Array = []
	for fam: Array in BokiSteps.FAMILY_KG + [["heavy", 0.0]]:
		for s in SURFACES:
			if not Sfx.ensure("boki_step_%s_%s" % [fam[0], s]):
				missing.append("%s_%s" % [fam[0], s])
	ok(missing.is_empty(), "every size family has its sound on every ground (missing %s)" % [missing])
	ok(BokiSteps.family("burrlet", 1.0) == "tiny" and BokiSteps.family("pebbit", 1.0) == "small"
		and BokiSteps.family("basaltoad", 1.0) == "medium" and BokiSteps.family("cairnback", 1.0) == "heavy",
		"a Boki's weight picks its family")
	ok(BokiSteps.family("burrlet", 1.25) == "small" and BokiSteps.family("pebbit", 0.6) == "tiny",
		"a size roll can move it up or down a family")

## A Boki on the scene at `at`, set walking its way at SPEED (the rig is stepped by hand).
func _walker(main: Node, id: String, at: Vector3) -> BokiRig:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	k.position = at
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	rig.set_process(false)
	rig.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return rig

## One frame for each rig: the body moves (the listener with it, so the distances hold), then the rig reads it
## and plays.
func _frame(rigs: Array) -> void:
	Sfx.listener.z -= speed * DT
	for rig: BokiRig in rigs:
		rig.root.position.z -= speed * DT
		rig._process(DT)
		rig.player.advance(DT)

func _cadence(main: Node) -> void:
	for walk: Array in [["cindle", SLOW], ["burrlet", SLOW], ["cairnback", SPEED]]:
		var id: String = walk[0]
		speed = walk[1]
		BokiSteps._live.clear()
		Sfx.listener = Vector3.ZERO
		var rig := _walker(main, id, Vector3(0, 0, 4))
		var played: Array = []
		rig.stepped.connect(func(sname: String) -> void: played.append(sname))
		await main.get_tree().process_frame
		for f in int(WARM_S / DT):
			_frame([rig])
		played.clear()
		var loops := 0.0
		for f in int(COUNT_S / DT):
			_frame([rig])
			loops += rig.player.speed_scale * DT / rig.player.get_animation(rig.clip).length
		var want := BokiSteps.touches(id, rig.clip).size() * loops
		var cap := COUNT_S / BokiSteps.MIN_GAP_S
		var what := "%s %s at %.1f m/s: %d steps in %.0f s, the legs beat %.1f" % [id, rig.clip, speed, played.size(),
			COUNT_S, want]
		if want < cap * 0.8:
			ok(absf(played.size() - want) <= 1.0, what + ": one for every foot down")
		else:
			ok(played.size() <= cap + 1.0 and played.size() >= cap / 3.0, what + ", past %.0f: one per %.1f s" % [cap,
				BokiSteps.MIN_GAP_S])
		ok(played.all(func(s: String) -> bool: return s.begins_with("boki_step_") and s.ends_with("_grass")),
			"%s steps are boki_step_<family>_<ground> (a lone Boki stands on grass)" % id)
		rig.root.queue_free()
	for id in ["thrumbird", "zephyrak", "glomwort", "wisplet"]:
		speed = SPEED
		Sfx.listener = Vector3.ZERO
		var rig := _walker(main, id, Vector3(0, 0, 4))
		var played: Array = []
		rig.stepped.connect(func(sname: String) -> void: played.append(sname))
		await main.get_tree().process_frame
		for f in int((WARM_S + COUNT_S) / DT):
			_frame([rig])
		ok(played.is_empty(), "%s walks and plays no step (%d)" % [id, played.size()])
		rig.root.queue_free()

func _crowd(main: Node) -> void:
	speed = SPEED
	BokiSteps._live.clear()
	Sfx.listener = Vector3.ZERO
	var rigs: Array = []
	var heard := {}
	for i in CROWD:
		var rig := _walker(main, "cindle", Vector3(0, 0, CROWD_NEAR + CROWD_GAP * i))
		rig.stepped.connect(func(_sname: String) -> void: heard[i] = int(heard.get(i, 0)) + 1)
		rigs.append(rig)
	await main.get_tree().process_frame
	for f in int(WARM_S / DT):
		_frame(rigs)
	heard.clear()
	for f in int(COUNT_S / DT):
		_frame(rigs)
	var nearest: Array = range(BokiSteps.MAX_VOICES)
	var who: Array = heard.keys()
	who.sort()
	ok(who == nearest, "with %d Boki walking about you, only the nearest %d step (heard %s)" % [CROWD,
		BokiSteps.MAX_VOICES, who])
	ok(who.all(func(i: int) -> bool: return int(heard[i]) >= 4), "and each of them keeps stepping %s" % [heard])
