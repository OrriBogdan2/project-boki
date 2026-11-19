class_name PlaySfx
extends RefCounted
## The sounds of the Boki's own play in the garden (docs/AUDIO.md): the tag chase starting and each catch, a game of
## tag ending in a cheer, a squabble ending in a huff, a toy played out. All from the garden library through
## GardenSfx.cue, quieter than the minigames and at the Boki. A zone allows MAX_CUES of them per WINDOW_S, so ten Boki
## at play stay a murmur; a cue over the cap is dropped (counted in `dropped`).

const DB := GardenSfx.DB - 6.0     # dB: under the minigame cues
const WINDOW_S := 3.0              # s of game time the cap counts over
const MAX_CUES := 3                # most cues one zone plays inside WINDOW_S

var now := 0.0                     # s since the base loaded (BaseLife.step feeds it)
var dropped := 0                   # cues the cap held back, for the checks
var _times := {}                   # zone -> the times (now) of its cues still inside the window

func tick(dt: float) -> void:
	now += dt

## The chaser sets off after a Boki.
func tag_start(rec: Dictionary, pos: Vector3) -> void:
	_cue("garden_go", rec, pos)

## The Boki just caught takes over as the chaser: its paws scuff.
func tag_catch(rec: Dictionary, pos: Vector3) -> void:
	_cue("tumble_push", rec, pos)

## The game runs its course: the pair cheers between them.
func tag_end(rec: Dictionary, pos: Vector3) -> void:
	_cue("garden_cheer_good", rec, pos)

## A squabble: the one that lost its temper huffs, in its own size.
func squabble(rec: Dictionary, pos: Vector3) -> void:
	_cue("garden_sulk_" + GardenSfx.size_word(rec), rec, pos)

## A toy played out: a happy chirp at the toy.
func toy_done(rec: Dictionary, pos: Vector3) -> void:
	_cue("garden_cheer_good", rec, pos)

func _cue(sname: String, rec: Dictionary, pos: Vector3) -> void:
	var zone := GardenZones.here
	var recent: Array = _times.get(zone, []).filter(func(t): return now - float(t) < WINDOW_S)
	if recent.size() >= MAX_CUES:
		dropped += 1
		_times[zone] = recent
		return
	recent.append(now)
	_times[zone] = recent
	GardenSfx.cue(sname, pos, HomeChimes.pitch(rec), DB)
