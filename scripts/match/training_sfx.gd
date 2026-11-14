class_name TrainingSfx
extends RefCounted
## The Training Grounds' own sounds (opts "training": the practice island, the Arena and the duel room;
## docs/AUDIO.md, content/sfx/training.json, tools/gen_sfx_training.py). The grounds don't borrow the
## match's beds (the title wind, the abyss howl, the ruins, the creature calls): MusicDir asks ambience()
## instead, every quarter second, for two beds of their own by where you are. The open expanse (the
## biggest island, and the open air off it) has the wind; on the sky islands round it the wind drops to
## ISLAND_WIND under a sheltered bed. The stations have cues of their own (a hit on a dummy, a reset, a
## sparring bot appearing) and the duel ring counts each round in, 3-2-1 and a horn. Every cue goes
## through cue(), on the SFX bus, and is counted in `heard` for the checks; the beds go through
## Sfx.amb_layer, on the Ambience bus.

const WIND := "training_wind"          # bed: audio/amb_training_wind.ogg
const ISLAND := "training_island"      # bed: audio/amb_training_island.ogg
const ISLAND_WIND := 0.35              # share of the expanse's wind still heard on a sky island
const COUNT := "training_count"
const HORN := "training_horn"
const DUMMY_HIT := "training_dummy_hit"
const RESET := "training_reset"
const BOT_SPAWN := "training_bot_spawn"
const CUES := [COUNT, HORN, DUMMY_HIT, RESET, BOT_SPAWN]
const COUNT_S := 3.0                   # s: a duel round's count-in, one beat a second, the horn at the end
const COUNT_PITCH := [1.0, 1.06, 1.12] # the beats 3, 2 and 1, each a step higher
const DB := -4.0                       # dB: the cues sit under the fight's own sounds

static var heard := {}                 # cue name -> times played, for the checks
var _expanse := -2                     # index in World.islands of the open expanse (-2: not looked up yet)

static func cue(sname: String, pos = null, pitch := 1.0) -> void:
	heard[sname] = int(heard.get(sname, 0)) + 1
	Sfx.play(sname, pos, DB, 0.03, pitch)

## The first beat of a duel round's count-in; count_in() plays the rest as the time runs down.
static func count_start() -> void:
	cue(COUNT, null, COUNT_PITCH[0])

## One step of the count-in, given the time left before and after it: a beat as each whole second
## passes, and the horn as it runs out (once: nothing once the time is already gone).
static func count_in(left_before: float, left_after: float) -> void:
	if left_before <= 0.0:
		return
	if left_after <= 0.0:
		cue(HORN)
	elif ceili(left_after) < ceili(left_before):
		cue(COUNT, null, COUNT_PITCH[COUNT_PITCH.size() - ceili(left_after)])

## The island that is the open expanse: the one with the most ground.
static func expanse_of(w: World) -> int:
	var best := -1
	var most := 0
	for i in w.islands.size():
		var cells: int = (w.islands[i].get("cells", []) as Array).size()
		if cells > most:
			best = i
			most = cells
	return best

## The two beds' levels (0..1) at a point of the grounds; anywhere off the sky islands is the expanse.
func beds_at(w: World, x: float, z: float) -> Dictionary:
	if _expanse == -2:
		_expanse = expanse_of(w)
	var i := w.island_of(x, z)
	if w.is_void(x, z) or i < 0 or i == _expanse:
		return {WIND: 1.0, ISLAND: 0.0}
	return {WIND: ISLAND_WIND, ISLAND: 1.0}

## Sets the beds for where the player is (gliding or dropping is out in the open wind).
func ambience(w: World, p: Hunter) -> void:
	var levels := {WIND: 1.0, ISLAND: 0.0} if p.gliding or p.dropping else beds_at(w, p.pos.x, p.pos.z)
	for bed in levels:
		Sfx.amb_layer(bed, levels[bed])
