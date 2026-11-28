class_name VoicePicks
extends RefCounted
## Which take of a Boki's voice plays next (docs/AUDIO.md). Each species voice (bk_<species>_<mood>) has two
## takes; with a coin flip a Boki that barks three times in a few seconds says the same clip twice. A cue
## now deals its takes, each at a few pitch steps, out of a shuffled bag: every take-and-step is used once
## before any comes round again, and the clips that played lately (half a bag) are held back from the first half
## of the next one.
## So a clip (take and step) is not heard again within half a bag of barks, and never twice in a row.

const PREFIX := "bk_"  # the species voices; every other cue keeps Sfx's own take picking
const STEPS: Array[float] = [1.0, 1.07, 0.94]  # pitch ratios: about a semitone up and down

static var _bags := {}  # cue -> the picks left in the bag (ints: take * STEPS.size() + step)
static var _recent := {}  # cue -> the last picks (half a bag of them)
static var _rng := RandomNumberGenerator.new()  # its own, so a seeded check's draws are not shifted


## The next pick for `cue` which has `takes` takes: {"take": int, "step": float (a pitch ratio)}.
static func next(cue: String, takes: int) -> Dictionary:
	var n := maxi(takes, 1) * STEPS.size()
	var bag: Array = _bags.get(cue, [])
	if bag.is_empty() or bag.max() >= n:
		bag = range(n)
		for i in range(n - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var held: Variant = bag[i]
			bag[i] = bag[j]
			bag[j] = held
		_hold_back_recent(bag, _recent.get(cue, []))
	var pick: int = bag.pop_back()
	_bags[cue] = bag
	var recent: Array = _recent.get(cue, [])
	recent.append(pick)
	_recent[cue] = recent.slice(maxi(0, recent.size() - n / 2))
	return {"take": int(pick / STEPS.size()), "step": STEPS[pick % STEPS.size()]}


## Swaps the clips that played lately out of the half of a new bag that is dealt first (the end of the array).
static func _hold_back_recent(bag: Array, recent: Array) -> void:
	var late := bag.size() - bag.size() / 2
	for p in range(late, bag.size()):
		if not bag[p] in recent:
			continue
		for q in late:
			if not bag[q] in recent:
				var held: Variant = bag[p]
				bag[p] = bag[q]
				bag[q] = held
				break


## Forgets every bag and seeds the shuffle (a check's start).
static func reset(seed_value := 1) -> void:
	_rng.seed = seed_value
	_bags.clear()
	_recent.clear()
