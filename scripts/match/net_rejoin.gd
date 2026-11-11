class_name NetRejoin
extends RefCounted
## A game that rejoins a match in progress (docs/decisions/0022-rejoin.md) gets its Hunter and Boki
## back as the relay last saw them: Net.back holds their "st" rows (Match._ser). The rejoined Hunter
## skips the opening drop and stands where it was, with its health, shield and downed state; the Boki
## gets its place and health. Everything else comes from the host's snapshots as usual.

## Puts the player back from Net.back. False when this isn't a rejoin (the match then drops in as usual).
static func restore(m: Match) -> bool:
	if Net.back.is_empty() or m.player == null:
		return false
	for it in Net.back:
		if String(it[1]) == m.player.nid:
			_hunter(m.player, it)
		elif String(it[1]) == m.player.nid + "k" and m.player.kin:
			_kin(m.player.kin, it)
	Net.back = []
	return true

static func _hunter(h: Hunter, it: Array) -> void:
	h.teleport(Vector3(it[2], it[3], it[4]))
	h.face = float(it[8])
	h.max_hp = float(it[10])
	h.hp = float(it[9])
	h.downed = int(it[11]) & 1 != 0
	h.down_hp = float(it[12])
	h.shield = float(it[17])

static func _kin(k: Kin, it: Array) -> void:
	k.teleport(Vector3(it[2], it[3], it[4]))
	k.max_hp = float(it[7])
	k.hp = float(it[6])
