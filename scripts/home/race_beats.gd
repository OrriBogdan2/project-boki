class_name RaceBeats
extends RefCounted
## The Dash's body beats (briefs/design/GARDEN.md 5.1): every runner crouches on the line through the countdown,
## bursts off it in a stretched run, and at the line the first ones home hop and spin while the rest sulk, picked
## by temper (HomeCarry.temper_of). Clips only, through the rig's "kact" (BokiHomeClips builds crouch, burst and
## sulk; hop is the rig's own, spin is Echo Steps'). The race (BaseRace.Run) waits for "go" and never reads them,
## so they cannot change a time: --race-check races with and without them and compares.
## Tuning: content/rules/base_race.json "beats".

const REST_S := 1.5              # s a runner stands about once let go before it wanders off

var kins: Array                 # the home's kin entries, in run order
var wait := GardenSfx.GO_S      # s of countdown left: the race holds on the line
var todo: Array = []            # per runner: the clips still to play, the one playing first
var left: Array = []            # per runner: s left on the clip playing now
var at_line: Array = []         # per runner: home, its finish clips queued
var over := false               # the race ended: each runner is let go once its clips are played

static func rules() -> Dictionary:
	return BaseRace.rules()["beats"]

## How long each of the race's clips plays (s); BokiHomeClips builds crouch, burst and sulk to these lengths.
static func clip_s(clip: String) -> float:
	match clip:
		"crouch": return GardenSfx.GO_S
		"spin": return EchoSteps.spin_s()
	return float(rules()[clip + "_s"])

## The finish clips of a runner home `rank`-th (0 the winner) of `count`: the first `top` celebrate, the rest
## and the last one home sulk (a solo lap celebrates).
static func finish(rec: Dictionary, rank: int, count: int) -> Array:
	var B := rules()
	if rank < int(B["top"]) and (rank < count - 1 or count == 1):
		return B["celebrate"].get(HomeCarry.temper_of(rec), B["celebrate"]["else"])
	return ["sulk"]

func _init(runners: Array) -> void:
	kins = runners
	for i in kins.size():
		todo.append([])
		left.append(0.0)
		at_line.append(false)
		_queue(i, ["crouch", "burst"])

## One frame of the race and its beats: the race holds through the countdown, then steps; run is null once the
## race is over and only the clips still playing go on.
func step(run: BaseRace.Run, d: float) -> void:
	if run != null and wait <= 0.0:
		run.step(d)
	wait -= d
	for i in kins.size():
		if run != null and float(run.done_t[i]) >= 0.0 and not at_line[i]:
			at_line[i] = true
			_queue(i, finish(kins[i]["rec"], _rank(run, i), kins.size()))
		if todo[i].is_empty():
			continue
		left[i] = float(left[i]) - d
		if float(left[i]) > 0.0:
			continue
		todo[i].pop_front()
		if todo[i].is_empty():
			_done(i)
		else:
			_play(i)

## The countdown is still running: the race has not started.
func counting() -> bool:
	return wait > 0.0

## The race ended: runners whose clips are played are let go now, the rest as theirs end.
func end() -> void:
	over = true
	for i in kins.size():
		if todo[i].is_empty():
			_release(kins[i])

## The race was called off: every runner stops its clip and is let go now.
func stop() -> void:
	over = true
	for i in kins.size():
		todo[i] = []
		_done(i)

## A runner still plays a clip (it is let go after).
func playing() -> bool:
	return todo.any(func(q: Array) -> bool: return not q.is_empty())

func _rank(run: BaseRace.Run, i: int) -> int:
	var mine := float(run.done_t[i])
	return run.done_t.filter(func(t: float) -> bool: return t >= 0.0 and t < mine).size()

func _queue(i: int, clips: Array) -> void:
	todo[i] = clips.duplicate()
	_play(i)

func _play(i: int) -> void:
	var clip := String(todo[i][0])
	var n: Node3D = kins[i]["node"]
	left[i] = clip_s(clip)
	n.set_meta("kact", clip)
	if clip == "sulk":
		var faces: Dictionary = rules()["sulk_face"]
		n.set_meta("face", String(faces.get(HomeCarry.temper_of(kins[i]["rec"]), faces["else"])))

func _done(i: int) -> void:
	var n: Node3D = kins[i]["node"]
	n.remove_meta("kact")
	n.remove_meta("face")
	if over:
		_release(kins[i])

func _release(k: Dictionary) -> void:
	k["busy"] = false
	k["t"] = REST_S
