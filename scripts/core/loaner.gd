class_name Loaner
## The free-kit run (owner idea, ROADMAP §2): queue with a basic loadout and a loaner Boki, with
## nothing at risk. It's the floor that means anyone can always play and earn (Lifeline).
##
## What you take: your class's plain weapon (never armory pieces), the two free tonics everyone sets
## out with (your stash stays home), no Rift Keys, no treat, and a loaner Boki: a fresh roll of a
## random starter egg (ordinary rolls, level 1). The loaner is lent for this run only: it isn't on
## your roster, it can't be lost (it never drops into a deathbox or gets left behind; it keeps out
## of sight and goes home to Wenna), and it can't be kept (it never joins your save, learns, levels
## or remembers). Your own Boki, armory, tonics, keys and treat are untouched whatever happens.
##
## Loot rules stay the usual ones: whatever you extract with comes home (gems, seeds, treasure, found
## weapons and gloves, a Boki you captured); die and it's in your deathbox like anyone's. An extract
## pays at least MIN_PAY gems in all (Wenna's stipend), enough for the cheapest Boki at the pens.

const MIN_PAY := 45
const STARTERS := ["cindle", "puddlet", "burrlet"]

## Free-kit runs are open once you've started (hatched your first Boki or played).
static func available() -> bool:
	return Lifeline.started()

## A loaner Boki: a reroll of a starter egg.
static func roll(seed := -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0: rng.seed = seed
	else: rng.randomize()
	var sp := String(STARTERS[rng.randi_range(0, STARTERS.size() - 1)])
	var rec := Save.new_kin(sp, "", int(rng.randi() & 0x7fffffff))
	rec["loaner"] = true
	rec["level"] = 1
	rec["trust"] = 55.0            # it's used to hunters: it does what it's asked
	rec["shimmer"] = false
	rec.erase("mutations")
	rec["origin"] = {"how": "loaner", "where": {"place": "pens"}, "t": int(Time.get_unix_time_from_system())}
	return rec

static func is_loaner(rec: Dictionary) -> bool:
	return bool(rec.get("loaner", false))

## Match options for a free-kit run on top of the usual ones.
static func opts(o: Dictionary, seed := -1) -> Dictionary:
	o["loaner"] = true
	o["loaner_rec"] = roll(seed)
	o["kit_items"] = []            # the armory stays home
	return o

## What a free-kit result does to the save on top of the usual (Game.apply_result calls it first):
## the stipend on an extract. Returns the gems added.
static func settle(r: Dictionary) -> int:
	if not r.get("loaner", false) or not r.get("extracted", false):
		return 0
	var got := int(r.get("gems", 0))
	if got >= MIN_PAY:
		return 0
	r["gems"] = MIN_PAY
	return MIN_PAY - got
