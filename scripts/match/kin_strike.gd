class_name KinStrike
extends RefCounted
## What a commanded Boki hits on the way (docs/decisions/0001): a thrown Boki's landing staggers what it
## lands on (an engage tool), and a recalled or merging Boki hits everything on its path back to you.
## Both use a hit-set per flight (one hit per foe) and a swept test for the leap, so a fast Boki can't
## skip over a foe between two steps. Numbers: content/rules/boki_system.json land_stagger / recall_hit.

## The landing: foes within the radius that the flight itself didn't already hit get the stagger.
## A charging mount (it carried you, then charged) lands harder: a wider ring, a longer stun, a bigger shove.
static func land(k: Kin, hit: Dictionary, charge := false) -> void:
	var r: Dictionary = KinCommand.rules()["land_stagger"]
	var cm: Dictionary = KinCommand.rules()["charge_impact"] if charge else {"radius_k": 1.0, "stun_add": 0.0, "kb_k": 1.0}
	var rad := float(r["radius"]) * float(cm["radius_k"])
	k.m.fx.ring(k.pos, rad, Color(k.sp["color"], 0.8), 0.25)
	for f in k.m.foes_of(k.team):
		if hit.has(f.nid) or Vector2(f.pos.x - k.pos.x, f.pos.z - k.pos.z).length() > rad + f.r or absf(f.pos.y - k.pos.y) > 1.8:
			continue
		hit[f.nid] = true
		_strike(k, f, k.dmg * float(r["dmg_k"]), float(r["stun"]) + float(cm["stun_add"]), float(r["kb"]) * float(cm["kb_k"]), (Vector2(f.pos.x - k.pos.x, f.pos.z - k.pos.z)).normalized(), "land")
	k.m.shake(0.3, k.pos)

## A leap home from `a` to `b` this step: foes within the path's width get hit once.
static func sweep(k: Kin, a: Vector3, b: Vector3) -> void:
	if k.fly.is_empty():
		return
	var r: Dictionary = KinCommand.rules()["recall_hit"]
	var w := float(r["width"])
	var seg := Vector2(b.x - a.x, b.z - a.z)
	var hit: Dictionary = k.fly["hit"]
	for f in k.m.foes_of(k.team):
		if hit.has(f.nid) or absf(f.pos.y + 0.6 - b.y) > 2.4:
			continue
		var q := Vector2(f.pos.x - a.x, f.pos.z - a.z)
		var t := clampf(q.dot(seg) / maxf(0.0001, seg.length_squared()), 0.0, 1.0)
		if (q - seg * t).length() > f.r + w:
			continue
		hit[f.nid] = true
		var d := seg.normalized() if seg.length() > 0.001 else Vector2.ZERO
		_strike(k, f, k.dmg * float(r["dmg_k"]), float(r["stun"]), float(r["kb"]), d.rotated(PI / 2.0 * (1.0 if randf() < 0.5 else -1.0)), "recall")
		if k.fly.is_empty():
			return

static func _strike(k: Kin, f: Ent, dmg: float, stun: float, kb: float, dir: Vector2, tag: String) -> void:
	var o := {"src": "kin", "ab": tag, "tags": [tag, "kin"], "stun": stun, "kb": dir * kb, "dr": true}
	f.hurt(maxf(1.0, dmg * k.power), k, o)
	k.m.fx.burst(f.pos + Vector3(0, 0.6, 0), k.sp["color"], 10, 3.5)
	k.m.sfx("kinhit", f.pos, -2.0)
	if k.owner_h and k.owner_h.is_local():
		k.m.freeze_frame(0.04)
