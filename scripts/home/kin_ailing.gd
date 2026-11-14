class_name KinAiling
extends RefCounted
## A weak or sick Boki at home: the company that helps it get better, a slow drooped walk (Care.pace,
## pose) and a perk-up when it is well again. The cures themselves are Care's
## (RECOVER_*, Care.tick, Care.feed).

## A friend is another Boki this close (FarmChatter.FRIEND_R): it keeps a sick one company and speeds the cure.
static func friend_near(kins: Array, k: Dictionary) -> bool:
	if not Care.ailing(k["rec"]):
		return false
	for o in kins:
		if o != k and not o.has("indoors") and (o["pos"] as Vector3).distance_to(k["pos"]) < FarmChatter.FRIEND_R:
			return true
	return false

## Forward lean of the body, radians: weak, sick (0 when well).
const DROOP_WEAK := 0.15
const DROOP_SICK := 0.30
## How fast the body eases to its lean, per second.
const DROOP_RATE := 4.0
## A hop is this much smaller while it is ailing.
const HOP_SCALE := 0.4

## Every frame, after the walk bob: lean forward and hop less while ailing, ease back upright when well.
static func pose(k: Dictionary, n: Node3D, d: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	var rec: Dictionary = k["rec"]
	if body == null or float(k.get("q_on", 0.0)) > 0.0 or float(k.get("nap_t", 0.0)) > 0.0:
		return
	var lean := 0.0
	if Care.ailing(rec):
		lean = DROOP_SICK if Care.starve_h(rec) >= Care.STARVE["sick"] else DROOP_WEAK
		body.position.y *= HOP_SCALE
		k["droop"] = true
	elif not k.get("droop", false):
		return
	body.rotation.x = lerpf(body.rotation.x, lean, minf(1.0, d * DROOP_RATE))
	if lean == 0.0 and absf(body.rotation.x) < 0.01:
		body.rotation.x = 0.0
		k.erase("droop")

## It just got well: a happy bounce, a heart and a sparkle (the body straightens in pose()).
static func perk_up(h, k: Dictionary) -> void:
	k["joy_t"] = 1.6
	h._emote(k, "♥", true)
	h._say(k, BokiLines.say(k["rec"], "fed"), 0.0, false)
	h.fx.burst((k["pos"] as Vector3) + Vector3(0, 0.6, 0), Color("fff3a0"), 14, 2.4, 0.5)
	h._toast("%s is feeling better" % k["rec"]["name"])
