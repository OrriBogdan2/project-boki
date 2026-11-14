extends "res://tools/hero_pair_check.gd"
## The placed-barrier rule (docs/heroes/barriers.md; KnockWall and Blockers), run from --dolm-combo-check with
## Stone Row's rocks and from
## --rimewright-combo-check with a Rink Wall's flags: a barrier of the other team is a wall to everything that
## would stop on terrain. Pins and knocks into it count as terrain, a burr sticks to it, a thrown mace stops at
## it, and a beam that goes through terrain (the Longneedle) is cut by it. Its own team passes it.

## kind: "rock" (HeroZones.rock) or "rimewall" (the Rink Wall's block/move flags through Verbs.add_wall).
func rules(main_node: Node, kind: String) -> void:
	main = main_node
	var r := setup("gunslinger", 14.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: ArchKit = P.ak
	var tag := kind + ": "
	var near := home + Vector3(3.0, 0, 0)
	var D: Hunter = m.make_hunter("D", T.team, "medium", "Near", "idle", {}, near, {"arch": "none"})
	D.max_hp = 10000.0
	D.hp = D.max_hp
	var wall := _raise(m, T, kind, home + Vector3(6.0, 0, 0))
	var mid := Vector3(home.x + 6.0, home.y + 1.0, home.z)
	ok(tag + "stops the other team's things, not its own",
		_stops(m, mid, P.team) and not _stops(m, mid, T.team))
	ok(tag + "a body in front is pinned, one in the open is not",
		KnockWall.behind(m, D, Vector2.RIGHT, 3.2) and not KnockWall.behind(m, D, Vector2.LEFT, 2.0))
	# the Longneedle goes through terrain; content/rules/blockers.json says which placed walls cut it (a Rink Wall
	# does; Tenzo's rocks are terrain to it, so it passes them)
	aim_at(P, T.pos)
	K.cd["e"] = 0.0
	var hp0: float = wall["hp"]
	K._fire_needle()
	if Blockers.wall_stops(wall, "pierce"):
		ok(tag + "Longneedle cut by it: front foe hit, rear foe not, wall hit",
			D.hp < D.max_hp and T.hp >= T.max_hp and float(wall["hp"]) < hp0,
			"D %.0f T %.0f wall %.0f" % [D.hp, T.hp, wall["hp"]])
	else:
		ok(tag + "Longneedle passes it (terrain to a piercer): both foes hit, wall untouched",
			D.hp < D.max_hp and T.hp < T.max_hp and float(wall["hp"]) >= hp0,
			"D %.0f T %.0f wall %.0f" % [D.hp, T.hp, wall["hp"]])
	# a Coin Blast sticks to it instead of flying through (the fuse is 0.9 s, so it is still there to read)
	D.teleport(home + Vector3(-6.0, 0, 6.0))
	K.burrs.clear()
	K.fire_rmb({"variant": "burr"})
	step(m, 0.5)
	var b: Dictionary = K.burrs[0] if not K.burrs.is_empty() else {}
	var at: Vector3 = b.get("pos", Vector3.ZERO)
	var stuck: bool = not b.is_empty() and bool(b["wall"]) and float(b["fuse"]) > 0.0
	ok(tag + "Coin Blast sticks to it as a wall hit, this side", stuck and at.x < home.x + 6.0 and at.x > near.x,
		"stuck at x %.1f" % (at.x - home.x))
	# and the barrier is gone with it: nothing there stops anything
	m.verbs._break_wall(wall)
	ok(tag + "with the barrier gone it is open ground",
		not _stops(m, mid, P.team) and not KnockWall.behind(m, _back(D, near), Vector2.RIGHT, 3.2))
	await done(m)

## Does a Verbs wall at `at` stop a solid thing (a shot) of `team` crossing it along x (Blockers, the one rule)?
func _stops(m: Match, at: Vector3, team: int) -> bool:
	return Blockers.cut(m.verbs.walls, at - Vector3(0.6, 0, 0), at + Vector3(0.6, 0, 0), team, "solid") < INF

## D back where the pin was tested (the Coin Blast part moved it out of the lane).
func _back(d: Hunter, at: Vector3) -> Hunter:
	d.teleport(at)
	return d

func _raise(m: Match, by: Hunter, kind: String, at: Vector3) -> Dictionary:
	if kind == "rock":
		return HeroZones.rock(m, by, at, Vector2.RIGHT, "chk", 3.2, 20.0, 400.0, false)
	var flags := {"length": 4.5, "hp": 400.0, "time": 20.0, "block": "enemy", "move": true}
	return m.verbs.add_wall(by, at, Vector2.RIGHT, flags, 1.0)
