class_name SquadAlerts
extends RefCounted
## Four short stingers for your own squad, heard wherever the teammate is (trios, ten teams: the
## fight is rarely on screen): a teammate goes down, a teammate is back up, your squad wiped a
## rival squad, you are the last one standing. One cue per GAP, the ambience ducks under it.
## Called from Match.knock / revive_hunter / eliminate and their net events ("knock", "up", "out").

const GAP := 1.5            # s: at most one cue per this long, so a bad moment never stacks them
const DUCK_S := 0.5         # s: the ambience and music hold down this long
const DUCK_DB := -6.0       # dB: how far they give way
const VOL_DB := -2.0        # dB: a little under the combat sounds
const CUE_T := "squad_cue_t"      # match meta: match time of the last cue
const LAST_ON := "squad_last_on"  # match meta: the last-alive cue has played and nobody has been revived since

## A squadmate of the player (never the player) went down.
static func down(m: Match, h: Hunter) -> void:
	if not _mate(m, h):
		return
	if not _last_cue(m):
		_cue(m, "squad_down")

## A squadmate was stood back up.
static func up(m: Match, h: Hunter) -> void:
	if not _mate(m, h):
		return
	m.set_meta(LAST_ON, false)
	_cue(m, "squad_up")

## Someone is out for good: a squadmate (you may be the last one left), or a rival squad's last member.
static func out(m: Match, h: Hunter) -> void:
	if m.player == null:
		return
	if _mate(m, h):
		_last_cue(m)
	elif h.team != m.player.team and _wiped_by_us(m, h.team):
		_cue(m, "squad_wipe")

static func _mate(m: Match, h: Hunter) -> bool:
	return m.player != null and h != m.player and h.team == m.player.team

## You stand and every other squadmate is down or out (an extracted one left, so you are not alone with the fight).
static func _last_alive(m: Match) -> bool:
	var p: Hunter = m.player
	if p.downed or p.out or p.extracted:
		return false
	var mates := m.hunters.filter(func(x): return x.team == p.team and x != p)
	return not mates.is_empty() and mates.all(func(x): return x.downed or x.out)

## The last-alive cue, played once until a revive. True when you are the last one alive (cue or not).
static func _last_cue(m: Match) -> bool:
	if not _last_alive(m) or bool(m.get_meta(LAST_ON, false)):
		return false
	if _cue(m, "squad_last"):
		m.set_meta(LAST_ON, true)
	return true

## Every member of `team` is out or extracted and one of them was last hit by someone on your side.
static func _wiped_by_us(m: Match, team: int) -> bool:
	var theirs := m.hunters.filter(func(x): return x.team == team)
	if theirs.any(func(x): return not x.out and not x.extracted):
		return false
	return theirs.any(func(x): return x.out and _team_of(x.last_hit_by) == m.player.team)

static func _team_of(e: Ent) -> int:
	if e is Kin and (e as Kin).owner_h:
		return (e as Kin).owner_h.team
	return (e as Hunter).team if e is Hunter else -1

static func _cue(m: Match, cue: String) -> bool:
	if m.time - float(m.get_meta(CUE_T, -1e9)) < GAP:
		return false
	m.set_meta(CUE_T, m.time)
	m.sfx(cue, null, VOL_DB)
	Sfx.duck(DUCK_S, DUCK_DB, true)
	return true
