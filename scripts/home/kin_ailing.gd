class_name KinAiling
extends RefCounted
## A weak or sick Boki at home: the company that helps it get better. The cures themselves are Care's
## (RECOVER_*, Care.tick, Care.feed).

## A friend is another Boki this close (FarmChatter.FRIEND_R): it keeps a sick one company and speeds the cure.
static func friend_near(kins: Array, k: Dictionary) -> bool:
	if not Care.ailing(k["rec"]):
		return false
	for o in kins:
		if o != k and not o.has("indoors") and (o["pos"] as Vector3).distance_to(k["pos"]) < FarmChatter.FRIEND_R:
			return true
	return false
