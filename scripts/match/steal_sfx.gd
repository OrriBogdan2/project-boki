class_name StealSfx
extends RefCounted
## The sounds that make a last-hit steal readable (docs/AUDIO.md "Steal cues", tools/gen_sfx_steals.py). A prize
## monster (a lair boss, an elite, a key carrier) cries out once, in its own voice kind, the first time it drops
## to CRY_AT of its health, and lands a heavy thud each time it reels (its stagger). The stolen-kill stings
## (steal_won / steal_lost) are KillCues'. Every machine plays the cry and the thud off the health and stagger
## it sees (a rival's monster from its snapshot), so nothing new is synced.

const CRY_AT := 0.25  # of max health: the line the cry marks
const CRY_DB := 2.0  # dB: over the monster's own attack voice (-9), so the cue reads in a fight
## Voice kinds with their own cry (the monster voices, v_<kind>); the lair bosses speak as the warden.
const CRY_KINDS := ["bomber", "brute", "glimmer", "sentinel", "skitter", "spitter", "warden"]


static func prize(mb: Mob) -> bool:
	return KeyBonus.mob_source(mb) in ["boss", "elite"] or KeyCarry.carries(mb)


## The cry `mb` gives at the quarter mark.
static func cry_name(mb: Mob) -> String:
	return "steal_cry_" + (mb.mkind if mb.mkind in CRY_KINDS else "warden")


## Every frame `mb` is alive, on every machine: the cry the first time it is at or under CRY_AT, the thud
## when a reel starts. Two compares when nothing happens.
static func tick(mb: Mob) -> void:
	var reeling := mb.stagger_t > 0.0
	if reeling != mb.reel_heard:
		mb.reel_heard = reeling
		if reeling and prize(mb):
			mb.m.sfx("steal_reel", mb.pos)
	if mb.cried or mb.hp > mb.max_hp * CRY_AT:
		return
	mb.cried = true
	if prize(mb):
		mb.m.sfx(cry_name(mb), mb.pos, CRY_DB)
