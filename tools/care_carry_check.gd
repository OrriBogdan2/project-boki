extends RefCounted
## Meeko's Soulpack (docs/heroes/tender.md, passive Bearer), run by tools/support_check.gd inside
## --tender-combo-check. Carrying gives her a shield; it breaking (a hit past it) or a stun drops the carried
## Wisps, stuns her and locks re-pick for 4 s; nothing else. Each way a carrier can be hit is
## asserted: a hit the shield soaks, a hit that breaks it, a DoT tick, a knock-back, a stun, a root, a slow
## and a teammate's heal.

var sc  # the SupportCheck running us (setup, step, ok, aim_at)


func ok(what: String, cond: bool, info := "") -> void:
	sc.ok(what, cond, info)


## Clears the lock and the stun, stands the Wisp beside her and lets her scoop it up.
func _pick(m: Match, pc: Hunter, ally: Hunter, kit: TenderKit) -> bool:
	pc.stun_t = 0.0
	pc.root_t = 0.0
	pc.slow_t = 0.0
	kit.lock_t = 0.0
	ally.down_hp = 60.0
	ally.revive = 0.0
	ally.teleport(pc.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.1)
	return CareUtil.is_carried(ally)


## A hit big enough to get past her carry shield as it stands.
func _breaker(pc: Hunter) -> float:
	return pc.shield + 30.0


func tender() -> void:
	var r: Array = sc.setup("tender", 14.0)
	var m: Match = r[0]
	var pc: Hunter = r[1]
	var ally: Hunter = r[2]
	var tgt: Hunter = r[3]
	var kit: TenderKit = pc.ak
	sc.down(m, ally)
	# --- the shield: a pickup gives it, a small hit is soaked, one past it breaks it
	var held := _pick(m, pc, ally, kit)
	var sh := pc.shield
	var want: float = float(kit.d["passive"]["shield"]) * LevelGrowth.hp(pc)
	ok(
		"mm carry: a pickup gives her the carry shield",
		held and kit.carry_shield and absf(sh - want) < 0.5,
		"shield %.1f want %.1f" % [sh, want]
	)
	pc.hurt(sh * 0.4, tgt, {"src": "primary"})
	sc.step(m, 0.1)
	ok(
		"mm carry: a hit the shield soaks keeps them, no stun",
		CareUtil.is_carried(ally) and pc.stun_t <= 0.0 and kit.lock_t <= 0.0 and pc.shield > 0.0,
		"shield %.1f stun %.2f" % [pc.shield, pc.stun_t]
	)
	# --- drops: a hit past the shield (stuns her), a DoT tick past it, a stun
	held = _pick(m, pc, ally, kit)
	pc.hurt(_breaker(pc), tgt, {"src": "primary"})
	sc.step(m, 0.1)
	var bs := float(kit.d["passive"]["break_stun"])
	ok(
		"mm carry: a hit past the shield drops them, 4 s lock, she is stunned",
		held and not CareUtil.is_carried(ally) and kit.lock_t > 3.8 and pc.stun_t >= bs - 0.15,
		"lock %.2f stun %.2f (want %.2f)" % [kit.lock_t, pc.stun_t, bs]
	)
	held = _pick(m, pc, ally, kit)
	pc.hurt(_breaker(pc), tgt, {"src": "burn"})
	sc.step(m, 0.1)
	ok(
		"mm carry: a burn tick past the shield drops them",
		held and not CareUtil.is_carried(ally) and kit.lock_t > 3.8
	)
	held = _pick(m, pc, ally, kit)
	pc.stun_t = 0.5
	sc.step(m, 0.1)
	ok(
		"mm carry: a stun drops them, 4 s lock",
		held and not CareUtil.is_carried(ally) and kit.lock_t > 3.8,
		"lock %.2f" % kit.lock_t
	)
	# --- holds: knock-back with no damage, a root, a slow, a teammate's heal
	held = _pick(m, pc, ally, kit)
	m.displace.knock(pc, Vector2(6, 0))
	sc.step(m, 0.3)
	ok(
		"mm carry: a knock-back with no damage or stun holds them",
		held and CareUtil.is_carried(ally) and pc.stun_t <= 0.0
	)
	held = _pick(m, pc, ally, kit)
	pc.root_t = 0.8
	sc.step(m, 0.3)
	ok("mm carry: a root holds them", held and CareUtil.is_carried(ally) and kit.lock_t <= 0.0)
	held = _pick(m, pc, ally, kit)
	pc.slow_t = 1.0
	pc.slow_k = 0.5
	sc.step(m, 0.3)
	ok("mm carry: a slow holds them", held and CareUtil.is_carried(ally) and kit.lock_t <= 0.0)
	held = _pick(m, pc, ally, kit)
	pc.hp = pc.max_hp * 0.5
	pc.heal(20.0)
	sc.step(m, 0.3)
	ok("mm carry: a teammate's heal on her holds them", held and CareUtil.is_carried(ally) and kit.lock_t <= 0.0)
	# --- a rooted Meeko can still scoop one up (the source has no root rule)
	pc.root_t = 2.0
	kit.lock_t = 0.0
	kit.drop_all(false)
	kit.lock_t = 0.0
	ally.teleport(pc.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.1)
	ok("mm carry: a rooted Meeko can still pick one up", CareUtil.is_carried(ally))
	pc.root_t = 0.0
	# --- the lock: no re-pick for 4 s after a drop, then they can be scooped up again
	held = _pick(m, pc, ally, kit)
	pc.hurt(_breaker(pc), tgt, {"src": "primary"})
	sc.step(m, 0.1)
	var locked := held and not CareUtil.is_carried(ally)
	for i in 7:
		ally.down_hp = 60.0
		ally.revive = 0.0
		ally.teleport(pc.pos + Vector3(0.4, 0, 0))
		sc.step(m, 0.5)
		locked = locked and not CareUtil.is_carried(ally)
	ok("mm carry: no re-pick for 4 s after a drop", locked, "lock %.2f" % kit.lock_t)
	ally.down_hp = 60.0
	ally.revive = 0.0
	ally.teleport(pc.pos + Vector3(0.4, 0, 0))
	sc.step(m, 0.8)
	ok("mm carry: after the 4 s they can be scooped up again", CareUtil.is_carried(ally), "lock %.2f" % kit.lock_t)
	m.queue_free()
