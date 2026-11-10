class_name MobCap
extends RefCounted
## Monsters awake near the local player are capped by graphics preset (Settings.QUALITY "mob_cap").
## The nearest idle ones past the cap sleep (Mob.capped: no wandering, no physics) and wake when the
## count drops or someone hurts them, so camps, loot and lairs keep their state: nothing despawns.
## Fights are never cut: a monster with a target stays awake and counts against the cap. It is a client
## activity limit only: online matches and bot runs use the High cap, and a monster with a bot or another
## Hunter at its side is never put to sleep, so nobody is handicapped by it.

const RADIUS := 60.0         # m around the local player that the cap counts
const EVERY := 0.5           # s between recounts

var m: Match
var _t := 0.0

func _init(match_node: Match) -> void:
	m = match_node

## The cap that applies to this match.
func limit() -> int:
	var preset := "high" if Net.online() or m.opts.get("autoplay", false) else Settings.quality()
	return int(Settings.QUALITY[preset]["mob_cap"])

func tick(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or m.player == null:
		return
	_t = EVERY
	var busy := 0
	var idle: Array = []
	for mb in m.mobs:
		mb.capped = false
		if mb.dead or mb.remote or mb.flat_dist(m.player) > RADIUS:
			continue
		if mb.st != "idle" or mb.tgt != null or mb.md.get("flee", false) or _hunter_beside(mb):
			busy += 1
		else:
			idle.append(mb)
	var room := limit() - busy
	if idle.size() <= room:
		return
	idle.sort_custom(func(a: Mob, b: Mob) -> bool: return a.flat_dist(m.player) < b.flat_dist(m.player))
	for i in range(maxi(room, 0), idle.size()):
		(idle[i] as Mob).capped = true

func _hunter_beside(mb: Mob) -> bool:
	for h in m.hunters:
		if h != m.player and not h.out and mb.flat_dist(h) < Mob.NAP_M:
			return true
	return false

## The monsters the cap is holding asleep right now (tests).
func sleeping() -> int:
	return m.mobs.filter(func(mb: Mob) -> bool: return mb.capped and not mb.dead).size()
