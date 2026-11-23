class_name BokiNapSfx
extends RefCounted
## The garden's sleepers (docs/AUDIO.md): every napping Boki (k["nap_t"] running: alone, in a pile with friends,
## or curled up outside) breathes a soft in-and-out loop with a little snore, pitched by its body size (a big Boki
## breathes slower and lower). Only the MAX_HEARD sleepers nearest you breathe, and each carries just its reach
## (content/sfx/boki.json), so a garden of 30 asleep is a few quiet breaths, not a drone. A Boki that wakes
## gives a small yawn. Both play through Sfx at the Boki, so they take whatever bus Sfx picks for that spot.

const LOOP := "boki_sleep"
const YAWN := "boki_yawn"
const STEP := 0.1          # s between looks at who sleeps (Sfx.loop_hold lets go 250 ms after the last call)
const MAX_HEARD := 3       # sleepers breathing at once, the nearest to you
const LOOP_DB := -12.0     # dB: a breath under the garden ambience, noticed as you walk up to it
const YAWN_DB := -8.0      # dB: as loud as a Boki at work (home_work.gd)
const REF_CM := 30.0       # cm: a Boki this tall breathes at pitch 1 (Unique.DEFAULT_SIZE)
const PITCH_LOW := 0.75    # the lowest pitch, for the biggest Boki
const PITCH_HIGH := 1.35   # the highest, for the smallest

var _acc := 0.0
var _asleep := {}          # uid -> true for each Boki that was napping at the last look

## Called each farm frame (home.gd _move_kin) with all the Boki out on the farm.
func step(kins: Array, d: float) -> void:
	_acc += d
	if _acc < STEP:
		return
	_acc = 0.0
	var sleepers := []
	var now := {}
	for k in kins:
		var uid := String(k["rec"]["uid"])
		if float(k.get("nap_t", 0.0)) > 0.0 and not k.has("indoors"):
			sleepers.append(k)
			now[uid] = true
		elif _asleep.has(uid):
			Sfx.play(YAWN, k["pos"], YAWN_DB, 0.06, pitch_of(k["rec"]))
	_asleep = now
	if sleepers.is_empty() or not Sfx.ensure(LOOP):
		return
	for k in heard(sleepers, Sfx.listener):
		Sfx.loop_hold("nap:" + String(k["rec"]["uid"]), LOOP, k["pos"], LOOP_DB, pitch_of(k["rec"]))

## The sleepers within the breath's reach of `at`, nearest first, at most MAX_HEARD.
static func heard(sleepers: Array, at: Vector3) -> Array:
	var reach := float(Sfx.sound_reach.get(LOOP, Sfx.hear_range))
	var near := sleepers.filter(func(k): return _flat(k["pos"], at) < reach)
	near.sort_custom(func(a, b): return _flat(a["pos"], at) < _flat(b["pos"], at))
	return near.slice(0, MAX_HEARD)

## Pitch by height: the square root of REF_CM over its own height (species size times its own roll).
static func pitch_of(rec: Dictionary) -> float:
	return clampf(sqrt(REF_CM / float(Unique.size_info(rec)["cm"])), PITCH_LOW, PITCH_HIGH)

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
