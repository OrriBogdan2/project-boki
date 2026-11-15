class_name KillCues
extends RefCounted
## The sounds of a monster kill (decision 2026-11-10: monster XP is a kill reward for the last hitter's
## squad). Run from Match.on_mob_dead, on the host as the monster dies and on every other game from the
## "mobdead" event, so each game plays only what its own hunter should hear:
##   xp_tick     a soft tick when kill XP lands for you (once per kill, never on a DoT tick)
##   steal_won   a short sting: your squad took the last hit on a monster another squad hurt more
##   steal_lost  the same moment from the squad that was robbed
## Nothing plays for a squadmate farther than SHARE_RADIUS from the kill, or for a third squad.

const SHARE_RADIUS := 30.0      # m: squadmates this close to a kill share its XP (and hear its cues)
const TICK_DB := -9.0           # the tick sits well under the sting: it lands on every kill
const STING_DB := -3.0
const STING_DUCK_S := 0.4       # s the music dips under a sting (a short, shallow dip: Sfx.duck)
const STING_DUCK_DB := -4.0

## The Hunter team that dealt the most damage to the monster, or -1 if no hunter hurt it.
static func top_team(mb: Mob) -> int:
	var best := -1
	var most := 0.0
	for t in mb.damage_by:
		if float(mb.damage_by[t]) > most:
			most = float(mb.damage_by[t])
			best = int(t)
	return best

## Who shares the kill XP of a monster at `at` taken by `killer`: the killer and their squadmates in range.
static func sharers(m: Match, at: Vector3, killer: Hunter) -> Array[Hunter]:
	var out: Array[Hunter] = []
	for h in m.hunters:
		if h.team == killer.team and not h.out and (h == killer or _near(h, at)):
			out.append(h)
	return out

static func _near(h: Hunter, at: Vector3) -> bool:
	return Vector2(h.pos.x - at.x, h.pos.z - at.z).length() <= SHARE_RADIUS

## `credit` took the last hit (a Boki counts as its owner); `top` is the team that did most of the damage.
static func on_kill(m: Match, mb: Mob, credit: Ent, top: int) -> void:
	var killer := HunterFeats.credit_of(credit)
	var me := m.player
	if killer == null or me == null or me.out:
		return
	var stolen := top >= 0 and top != killer.team
	var robbed := stolen and me.team == top
	var tick := me in sharers(m, mb.pos, killer)
	if not tick and not (robbed and _near(me, mb.pos)):
		return
	if tick:
		m.sfx("xp_tick", null, TICK_DB)
	if stolen:
		m.sfx("steal_lost" if robbed else "steal_won", null, STING_DB)
		Sfx.duck(STING_DUCK_S, STING_DUCK_DB)
