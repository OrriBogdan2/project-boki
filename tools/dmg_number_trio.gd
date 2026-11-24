extends RefCounted
## The trio-focus case for --dmg-number-check and --dmg-number-shots: you and two teammates focus one
## rival dummy for SECS s through the real damage path (shots with a crit every third, your burn ticks,
## an ability hit, your Boki's hits). Each frame counts how many live damage numbers print over each
## other on screen (MsgLane.label_rect); the most over one spot must stay at MAX_OVERLAP or under.

const DT := 1.0 / 60.0
const SECS := 3.0
const MAX_OVERLAP := 3


## setup: {"m", "P", "mates", "dummy"}. The match is the caller's (trio, two teams).
static func setup(m: Match) -> Dictionary:
	var p: Hunter = m.player
	var mates := m.hunters.filter(func(x): return x.team == p.team and x != p)
	var dummy: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	dummy.max_hp = 1e6
	dummy.hp = 1e6
	dummy.teleport(m.world.free_spot_near(p.pos + Vector3(4.5, 0, 0), [], 1.0, 0.4, 6.0))
	return {"m": m, "P": p, "mates": mates.slice(0, 2), "dummy": dummy}


## Frame `f`'s hits: each attacker shoots on its own cadence (every third shot a crit), you also burn the
## dummy (a tick a quarter second) and land an ability at 1.5 s; your Boki bites every half second.
static func hit(s: Dictionary, f: int) -> void:
	var dummy: Hunter = s["dummy"]
	var p: Hunter = s["P"]
	var who: Array = [p] + s["mates"]
	var every := [18, 21, 24]
	for i in who.size():
		if f % int(every[i]) == i * 5:
			var k: int = int(f / float(int(every[i])))
			dummy.hurt(22.0, who[i], {"src": "shot", "crit": k % 3 == 2})
	if f % 15 == 0:
		dummy.hurt(4.0, p, {"src": "burn"})
	if f == 90:
		dummy.hurt(80.0, p, {"src": "abil"})
	if f % 30 == 10 and p.kin != null:
		dummy.hurt(12.0, p.kin, {"src": "abil"})


## The most live damage numbers over one spot this frame: for each, itself plus those whose screen
## rect meets its own.
static func overlap(fx: Fx, cam: Camera3D) -> int:
	var rs: Array[Rect2] = []
	for n in fx.nums:
		var l: Label3D = n["node"]
		if n.has("val") and l.visible and l.modulate.a > 0.05 and not cam.is_position_behind(l.global_position):
			rs.append(MsgLane.label_rect(l, cam))
	var most := 0
	for a in rs:
		var c := 0
		for b in rs:
			c += 1 if a.intersects(b) else 0
		most = maxi(most, c)
	return most
