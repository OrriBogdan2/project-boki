extends "res://tools/archetype_check.gd"
## --point-blank-check: every Hunter's shots at point blank (docs/WEAPON_FIRING_DATA.md, "Where shots start";
## ShotOrigin). For each of the 12: a foe touching you (0.5 m, centre to centre) pressed against a wall or a
## cliff takes the LMB and the RMB; an LMB fired into a wall or cliff 0.3 m ahead ends in a miss puff in view
## at the face, not buried inside it; with a wall at your back, the LMB hits a foe 3 m ahead and nothing puffs
## behind you. Prints PBCHECK lines and "PBCHECK DONE, N checks, failures: F".

const IDS := ["gunslinger", "bulwark", "thief", "juggernaut", "ostra", "rimewright", "dredge", "tender", "ashwick",
	"dolm", "archer", "mage"]
const NO_HIT_RMB := ["bulwark"]           # Aegis is a shield, not a strike
const THROUGH_WALLS := ["ostra"]          # Tether Lantern's orbs fly through walls (its data): no puff to make
const WALL_AT := 0.3                      # m from your centre to the wall's face
const FOE_AT := 0.5                       # m from your centre to the touching foe's
const PUFF_NEAR := 0.5                    # m: a miss puff this far in front of the face counts as at the face
const RMB_WAIT := 1.4                     # s after the RMB press: Burrseed winds up for 1.0 s before the throw
var fire_walls: Array = []                # Cinder's fire flattened on a wall while firing (puffs only live 0.12 s)
var behind := 0                           # frames a shot of yours flew back toward the wall behind you
var far_x := -INF                         # the furthest x a shot of yours reached

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("PBCHECK %-52s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("point_blank_check", self)
	for id in IDS:
		await _hero(id)
	print("PBCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## A wall of blocks, or a cliff (raised ground), whose west face is at x = face, across the strip.
func _wall(m: Match, face: int, z: int, cliff: bool) -> void:
	var W: World = m.world
	for dz in range(-4, 5):
		for dx in range(0, 3):
			var i: int = W.idx(face + dx, z + dz)
			if cliff:
				W.level[i] = W.level[i] + 4
			else:
				W.kind[i] = World.T_BLOCK

func _fire(m: Match, P: Hunter, key: String, at: Vector3) -> void:
	P.fire_cd = 0.0
	P.reload_t = 0.0
	P.ammo = maxi(P.ammo, 3)
	for k in P.ak.cd: P.ak.cd[k] = 0.0
	P.ak.ch_rmb = maxf(P.ak.ch_rmb, 1.0)
	fire_walls = []
	behind = 0
	far_x = -INF
	var watch := func():
		aim_at(P, at)
		for sh in m.shots:
			if sh["by"] != P: continue
			far_x = maxf(far_x, (sh["pos"] as Vector3).x)
			if (sh["vel"] as Vector2).x < -1.0: behind += 1      # (a 180-degree swing reaches out sideways, not back)
		if P.ak is AshwickKit:
			for pf in (P.ak as AshwickKit).hose.puffs:
				if pf.get("wall", false): fire_walls.append(pf["p"])
	if key == "lmb":
		var spool := float(P.ak.d.get("lmb", {}).get("spool", 0.0))      # (Cinder's pilot flame first)
		var press := func():
			P.inp["fire"] = true
			watch.call()
		step(m, 0.2 + spool, press)
		P.inp["fire"] = false
		step(m, 0.7, watch)
	else:
		aim_at(P, at)
		hold(m, P, 0.25)
		step(m, RMB_WAIT, watch)

## Puffs since burst slot b0 (and Cinder's fire flattened on a wall): [in view near the face, buried past it].
func _puffs(m: Match, P: Hunter, b0: int, face: float) -> Array:
	var pts: Array = []
	var k := b0
	while k != m.fx.bi:
		pts.append(m.fx.bursts[k].global_position)
		k = (k + 1) % m.fx.bursts.size()
	pts.append_array(fire_walls)
	var W: World = m.world
	var near := 0
	var buried := 0
	for p in pts:
		var top: float = W.ground_at(p.x, p.z) + (World.BLOCK_H if W.is_block(p.x, p.z) else 0.0)
		var inside: bool = p.y < top
		if inside and p.x < face + 0.8: buried += 1
		elif not inside and p.x <= face + 0.01 and p.x >= face - PUFF_NEAR: near += 1
	return [near, buried]

func _hero(id: String) -> void:
	var r := setup(id, 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var W: World = m.world
	var face := int(home.x) + 3
	var kind0 := W.kind.duplicate()
	var level0 := W.level.duplicate()
	for cliff in [false, true]:
		var what := "cliff" if cliff else "wall"
		_wall(m, face, int(home.z), cliff)
		# into the wall 0.3 m ahead
		T.teleport(home + Vector3(-6, 0, 5))
		P.teleport(Vector3(face - WALL_AT, home.y, home.z))
		P.vel = Vector3.ZERO
		m.step(DT)
		var b0: int = m.fx.bi
		_fire(m, P, "lmb", P.pos + Vector3(4, 0, 0))
		var pf := _puffs(m, P, b0, float(face))
		if id in THROUGH_WALLS:
			var past := "reached %.1f past the face" % (far_x - face)
			ok("%s LMB into a %s: flies through (its data)" % [id, what], far_x > face + 3.0, past)
		else:
			ok(
				"%s LMB into a %s at %.1fm: puff at the face" % [id, what, WALL_AT],
				int(pf[0]) > 0 and int(pf[1]) == 0, "in view %d buried %d" % [pf[0], pf[1]]
			)
		# a foe touching you, pressed against it
		for key in ["lmb", "rmb"]:
			if key == "rmb" and id in NO_HIT_RMB: continue
			fresh(T)
			T.teleport(Vector3(float(face) - T.r - 0.02, home.y, home.z))
			P.teleport(Vector3(T.pos.x - FOE_AT, home.y, home.z))
			P.vel = Vector3.ZERO
			m.step(DT)
			_fire(m, P, key, T.pos)
			var foe := "%s %s: a foe touching you at a %s takes it" % [id, key.to_upper(), what]
			ok(foe, dmg(T) > 0.0, "took %.0f" % dmg(T))
		W.kind = kind0.duplicate()
		W.level = level0.duplicate()
	# back to a wall: the shot goes forward only
	_wall(m, face, int(home.z), false)
	P.teleport(Vector3(face + 3.0 + WALL_AT, home.y, home.z))
	P.vel = Vector3.ZERO
	fresh(T)
	T.teleport(P.pos + Vector3(3, 0, 0))
	m.step(DT)
	_fire(m, P, "lmb", T.pos)
	ok(
		"%s LMB with a wall at your back: hits ahead, none behind" % id,
		dmg(T) > 0.0 and behind == 0, "took %.0f behind %d" % [dmg(T), behind]
	)
	await done(m)
