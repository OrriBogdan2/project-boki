class_name KinGuardStance
extends RefCounted
## How a guardian Boki (KinGuardian) carries itself, so the window reads at a glance. It lands facing the
## nearest threat, stands low and wide with its ears up between fights (the "stance" pose KinPuppet and
## BokiRig draw per body plan on the Flex node, no new rig), and turns to follow whoever it is guarding
## against. Fights use the clips it already has (the lunge sets "kstate" attack); the end of the window is
## the summon's own shrink back into the wisp.

const TURN_RATE := 12.0   # 1/s: how fast it swings to face the threat (a half turn in about 0.3 s)
const SEE_RANGE := 14.0   # m: a foe this near the Hunter Wisp counts as a threat to turn to
const STILL_SPEED := 0.5  # m/s: slower than this it is standing, so it holds the stance

## The stance per body plan (KinPuppet.BODY): sy lower, sx wider, rx lean (+ head down), ear (- up), tail
## (- up). Quadrupeds crouch and plant, bipeds sink on their legs, flyers hover lower with wings out, the
## serpent coils up flat, blobs squat.
const STANCE := {
	"quad": {"sy": 0.86, "sx": 1.14, "sz": 1.04, "rx": 0.1, "ear": -0.3, "tail": -0.45},
	"biped": {"sy": 0.84, "sx": 1.1, "sz": 1.0, "rx": 0.08, "ear": -0.35, "tail": -0.3},
	"flyer": {"sy": 0.92, "sx": 1.16, "sz": 1.0, "rx": 0.06, "ear": -0.2, "tail": -0.2},
	"serpent": {"sy": 0.88, "sx": 1.08, "sz": 1.06, "rx": 0.04, "ear": -0.2, "tail": -0.3},
	"blob": {"sy": 0.82, "sx": 1.18, "sz": 1.0, "rx": 0.05, "ear": -0.25, "tail": -0.3},
}

## The pose row for a body plan ("blob" for anything unknown).
static func row(plan: String) -> Dictionary:
	return STANCE.get(plan, STANCE["blob"])

## What the guardian is watching: its own target while it is a real one, else the foe nearest the Hunter Wisp.
static func threat(k: Kin) -> Ent:
	var t := k.target
	if t != null and is_instance_valid(t) and not t.dead and t.hittable():
		return t
	var o := k.owner_h
	if o == null:
		return null
	var best: Ent = null
	var best_d := SEE_RANGE
	for f in k.m.foes_of(k.team):
		if f is Hunter and (f.downed or f.cloak_t > 0.0):
			continue
		if not f.hittable():
			continue
		var d := o.flat_dist(f)
		if d < best_d:
			best_d = d
			best = f
	return best

## The yaw that faces a spot from the Boki (Kin.face looks down -Z).
static func yaw_to(k: Kin, at: Vector3) -> float:
	return atan2(-(at.x - k.pos.x), -(at.z - k.pos.z))

## It has just burst out: it lands already facing the threat.
static func land(k: Kin) -> void:
	var t := threat(k)
	if t != null:
		k.face = yaw_to(k, t.pos)

## The fixed step of the window: turn to the threat (it keeps its own heading when there is none).
static func track(k: Kin, dt: float) -> void:
	var t := threat(k)
	if t != null and k.flat_dist(t) > 0.2:
		k.face = lerp_angle(k.face, yaw_to(k, t.pos), minf(1.0, dt * TURN_RATE))

## Standing guard (not striking, not travelling): the pose meta KinPuppet and BokiRig read.
## It wins over the companion's own guard/whine poses over a downed owner (Kin.render).
static func holding(k: Kin) -> bool:
	var still := Vector2(k.vel.x, k.vel.z).length() < STILL_SPEED
	return k.summon != null and k.summon.guardian and k.lunge_t <= 0.0 and still
