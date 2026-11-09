class_name DropMerge
extends RefCounted
## Gems come out of a monster, chest or prop as ONE pickup holding the total, a little bigger the more
## it holds, instead of a scatter of small ones. The player gets the same gems; the ground (and the
## pickup loop, the nodes and the Net "drop" events) carries a fraction of the objects.

const SIZE_PER_GEM := 0.06      # extra scale per gem in the pile
const MAX_SIZE := 1.7           # a pile never looks bigger than this

## `count` gems worth `each` apiece, as one pickup at `at`. vel0: the launch (null = a random pop).
static func gems(m: Match, at: Vector3, count: int, each: int, vel0 = null) -> void:
	if count <= 0:
		return
	var before := m.pickups.size()
	m.drop("gem", at, count * each, "", "", vel0)
	if m.pickups.size() > before:      # (a client makes none: the host's drop arrives by Net)
		(m.pickups[-1]["node"] as Node3D).scale = Vector3.ONE * minf(1.0 + SIZE_PER_GEM * (count - 1), MAX_SIZE)
