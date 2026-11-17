class_name GripNet
extends RefCounted
## What a remote hunter's overhead row needs (GripOverhead), carried in the hunter's "h" snapshot
## after KinNet's fields (Net.VERSION 0.16.1): both gloves as "id:rar" ("" for none), each glove's
## cooldown left (s), and the bond meter (0..1, full = a Merge is ready).

const AT := ArchKit.NET_MOVE_AT + 2     # after KinNet.hunter_extra (5 fields) and ArchKit.net_move (2)
const N := 5

static func hunter_extra(h: Hunter) -> Array:
	var out: Array = []
	for i in Gloves.SLOTS:
		var g: Dictionary = h.gear[i]
		out.append("" if g.is_empty() else "%s:%d" % [String(g["id"]), int(g.get("rar", 0))])
	for i in Gloves.SLOTS:
		out.append(snappedf(float(h.gear_cd[i]), 0.1))
	out.append(snappedf(h.ult, 0.01))
	return out

static func apply_hunter(h: Hunter, it: Array) -> void:
	if it.size() < AT + N:
		return
	for i in Gloves.SLOTS:
		var s := String(it[AT + i])
		var bits := s.split(":")
		h.gear[i] = {} if s == "" \
				or not Gear.ALL.has(bits[0]) else {"id": bits[0], "rar": int(bits[1]) if bits.size() > 1 else 0}
		h.gear_cd[i] = float(it[AT + 2 + i])
	h.ult = float(it[AT + 4])
