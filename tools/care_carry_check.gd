extends RefCounted
## Meeko's Soulpack (docs/heroes/tender.md, passive Bearer), run by tools/support_check.gd inside
## --tender-combo-check. Source (supervive_kits.md, Elluna): taking too much damage or being stunned
## drops the carried Wisps and locks re-pick for 4 s; nothing else. Each way a carrier can be hit is
## asserted: shot damage, a DoT tick, a knock-back, a stun, a root, a slow and a teammate's heal.

var sc        # the SupportCheck running us (setup, step, ok, aim_at)


func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)


## Clears the lock and the stun, stands the Wisp beside her and lets her scoop it up.
func _pick(m: Match, P: Hunter, A: Hunter, K: TenderKit) -> bool:
	P.stun_t = 0.0
	P.root_t = 0.0
	P.slow_t = 0.0
	K.lock_t = 0.0
	A.down_hp = 60.0
	A.revive = 0.0
	A.teleport(P.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.1)
	return CareUtil.is_carried(A)


func tender() -> void:
	var r: Array = sc.setup("tender", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var A: Hunter = r[2]
	var T: Hunter = r[3]
	var K: TenderKit = P.ak
	sc.down(m, A)
	# --- drops: shot damage (no stun on her), a DoT tick, a stun
	var held := _pick(m, P, A, K)
	P.hurt(10.0, T, {"src": "primary"})
	sc.step(m, 0.1)
	ok("mm carry: a rival's shot drops them, 4 s lock, no stun on her",
		held and not CareUtil.is_carried(A) and K.lock_t > 3.8 and P.stun_t <= 0.0,
		"lock %.2f stun %.2f" % [K.lock_t, P.stun_t])
	held = _pick(m, P, A, K)
	P.hurt(1.0, T, {"src": "burn"})
	sc.step(m, 0.1)
	ok("mm carry: a burn tick drops them (any damage, no figure in source)",
		held and not CareUtil.is_carried(A) and K.lock_t > 3.8)
	held = _pick(m, P, A, K)
	P.stun_t = 0.5
	sc.step(m, 0.1)
	ok("mm carry: a stun drops them, 4 s lock",
		held and not CareUtil.is_carried(A) and K.lock_t > 3.8, "lock %.2f" % K.lock_t)
	# --- holds: knock-back with no damage, a root, a slow, a teammate's heal
	held = _pick(m, P, A, K)
	m.displace.knock(P, Vector2(6, 0))
	sc.step(m, 0.3)
	ok("mm carry: a knock-back with no damage or stun holds them", held and CareUtil.is_carried(A) and P.stun_t <= 0.0)
	held = _pick(m, P, A, K)
	P.root_t = 0.8
	sc.step(m, 0.3)
	ok("mm carry: a root holds them", held and CareUtil.is_carried(A) and K.lock_t <= 0.0)
	held = _pick(m, P, A, K)
	P.slow_t = 1.0
	P.slow_k = 0.5
	sc.step(m, 0.3)
	ok("mm carry: a slow holds them", held and CareUtil.is_carried(A) and K.lock_t <= 0.0)
	held = _pick(m, P, A, K)
	P.hp = P.max_hp * 0.5
	P.heal(20.0)
	sc.step(m, 0.3)
	ok("mm carry: a teammate's heal on her holds them", held and CareUtil.is_carried(A) and K.lock_t <= 0.0)
	# --- a rooted Meeko can still scoop one up (the source has no root rule)
	P.root_t = 2.0
	K.lock_t = 0.0
	K.drop_all(false)
	K.lock_t = 0.0
	A.teleport(P.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.1)
	ok("mm carry: a rooted Meeko can still pick one up", CareUtil.is_carried(A))
	P.root_t = 0.0
	# --- the lock: no re-pick for 4 s after a drop, then they can be scooped up again
	held = _pick(m, P, A, K)
	P.hurt(10.0, T, {"src": "primary"})
	sc.step(m, 0.1)
	var locked := held and not CareUtil.is_carried(A)
	for i in 7:
		A.down_hp = 60.0
		A.revive = 0.0
		A.teleport(P.pos + Vector3(0.4, 0, 0))
		sc.step(m, 0.5)
		locked = locked and not CareUtil.is_carried(A)
	ok("mm carry: no re-pick for 4 s after a drop", locked, "lock %.2f" % K.lock_t)
	A.down_hp = 60.0
	A.revive = 0.0
	A.teleport(P.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.8)
	ok("mm carry: after the 4 s they can be scooped up again", CareUtil.is_carried(A), "lock %.2f" % K.lock_t)
	m.queue_free()
