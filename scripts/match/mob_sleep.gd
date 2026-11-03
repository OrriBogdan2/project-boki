class_name MobSleep
extends RefCounted
## Monster streaming for a big map (a layout with "stream": true, the Riven Wilds; see
## docs/decisions/0014-tier-map.md). A monster idling at its camp, or a wild Boki pottering about its
## nest, with no hunter or hunter's Boki within WAKE_R sleeps: it skips its step (a monster also the
## push-apart between bodies) until someone comes near, then picks up where it was. Nobody can see it
## (the camera shows ~24 m across; a monster notices you at 7.5-11 m), so a far camp or nest costs
## nothing and a frame costs the same however many the map holds.

const WAKE_R := 48.0       # m from the nearest hunter or Boki out in the world
const RECHECK := 0.25      # s between looks at who is near

var on := false
var _until := 0.0
var _kins_asleep := {}      # wild Boki asleep (Kin -> true)

func _init(layout: Dictionary) -> void:
	on = bool(layout.get("stream", false))

## Match.step's monster loop: every awake monster takes its step.
func sim_all(m: Match, dt: float) -> void:
	if on and m.time >= _until:
		_until = m.time + RECHECK
		_refresh(m)
	for mb in m.mobs:
		if not mb.asleep:
			mb.sim(dt)

## Match.step's Boki loop: every Boki that is awake takes its step.
func sim_kins(m: Match, dt: float) -> void:
	for k in m.kins:
		if not _kins_asleep.has(k):
			k.sim(dt)

func _refresh(m: Match) -> void:
	var near := PackedVector2Array()
	for h in m.hunters:
		if not h.out and not h.extracted:
			near.append(Vector2(h.pos.x, h.pos.z))
	for k in m.kins:
		if k.state != "wild" and not k.dead:
			near.append(Vector2(k.pos.x, k.pos.z))
	for mb in m.mobs:
		mb.asleep = _can_sleep(mb) and _alone(mb.pos, near)
	_kins_asleep.clear()
	for k in m.kins:
		if k.state == "wild" and not k.dead and not k.remote and k.angry_at == null and _alone(k.pos, near):
			_kins_asleep[k] = true

## Shrublings (1-3 a match) keep their own clock: their cover follows them and their tells run.
static func _can_sleep(mb: Mob) -> bool:
	return not (mb.dead or mb.remote or mb.st != "idle" or mb.tgt != null or mb.engaged or mb is Shrubling)

static func _alone(at: Vector3, near: PackedVector2Array) -> bool:
	var p := Vector2(at.x, at.z)
	for q in near:
		if p.distance_squared_to(q) < WAKE_R * WAKE_R:
			return false
	return true
