extends "res://tools/archetype_check.gd"
## --ledge-walk-check: walking off a ledge is always allowed (a decision of the owner's). Every Hunter walks at the
## edge of a two-terrace plateau, then at an island rim over the abyss, in each state that could gate movement,
## and must leave it. States: plain walk, LMB held (Lace's draw, Albert's Crushing Blow wind-up, Kael's charge),
## RMB held for a second first (Albert's shield, Kael's Lunge hold, every other charge), E held (Sparkle's drag),
## E pressed (the recast window), R pressed (the ultimate's window), crouch, and Meeko carrying a downed
## teammate's Wisp. Time a kit roots him outright (a statue, a planted ultimate) isn't counted against the walk.
## Prints AKCHECK lines and "LWALK DONE, N checks, failures: M".

const TERRACES := 2         # plateau height over the strip, in terraces
const WALK_S := 4.0         # s allowed to cross the 3 m run-up and fall off (the slowest walk is ~0.3 of a run)
const RUN_UP := 3.0         # m from the start to the edge
const PRE_HOLD_S := 1.0     # s a held RMB charges before the walk starts (past every tap window)
const MAX_ROOT_S := 15.0    # s of kit root waited out before a walk that never started counts as failed
const STATES := ["walk", "lmb", "rmb", "e", "e_press", "r_press", "crouch", "carry"]

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("ledge_walk_check", self)
	for arch in Arch.ids():
		await _hero(arch)
	print("LWALK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _hero(arch: String) -> void:
	var r := setup(arch, 10.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var lv: int = r[5]
	var W: World = m.world
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-4, 5):
		for dx in range(-8, 1):
			W.level[W.idx(hx + dx, hz + dz)] = lv + TERRACES
	var top := (lv + TERRACES) * World.LEVEL
	var edge := hx + 1.0
	await _walks(m, P, arch, "ledge", top, edge, hz)
	for dz in range(-4, 5):      # the same edge, now the rim of an island: the abyss beyond
		for dx in range(1, 7):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	await _walks(m, P, arch, "rim", top, edge, hz)
	await done(m)

func _walks(m: Match, P: Hunter, arch: String, edge_kind: String, top: float, edge: float, hz: int) -> void:
	for st in STATES:
		if st == "carry" and arch != "tender":
			continue
		P.set_arch(arch)
		P.unlock_all()
		P.lvl = 6
		P.slot_lv["ult"] = 1
		P.hp = P.max_hp
		P.teleport(Vector3(edge - RUN_UP, top, hz + 0.5))
		P.vel = Vector3.ZERO
		# an E aims along the edge: Neve's Rink Wall would stand in the way, and that is not the ledge
		var cursor_z := hz - 7.5 if st.begins_with("e") else hz + 0.5
		P.inp["aim"] = Vector3(edge + 8.0, top, cursor_z)
		P.inp["aim_y"] = top
		step(m, 0.2)      # lands: a cast from the air takes its air variant
		_begin(m, P, st, arch, top, edge)
		var t := 0.0        # s walked free
		var seen := false   # the state really took hold at some point of the walk
		var rooted := 0.0   # s a kit rooted him outright (a statue, a planted ultimate): not a ledge gate
		while t < WALK_S and rooted < MAX_ROOT_S and P.pos.y > top - 0.5:
			if _free(P):
				t += DT
			else:
				rooted += DT
			_drive(P, st)
			step(m, DT)
			seen = seen or _engaged(P, st, arch)
		var info := "x=%.2f y=%.2f of %.2f, %.1fs walking, %.1fs rooted by the kit" % [P.pos.x, P.pos.y, top, t, rooted]
		ok("%s: %s leaves the %s" % [arch, st, edge_kind], P.pos.y <= top - 0.5, info)
		ok("%s: %s took hold on the %s" % [arch, st, edge_kind], seen)
		_end(P)

func _begin(m: Match, P: Hunter, st: String, arch: String, top: float, edge: float) -> void:
	match st:
		"rmb":
			hold_start(m, P)
		"e", "e_press":
			P.ult = 0.0
			P.inp["e_down"] = st == "e"
			P.ak.use_e()
			step(m, 0.2, func(): P.inp["e_down"] = st == "e")
		"r_press":
			P.ult = 1.0
			P.ak.use_r()
			step(m, 0.2)
		"carry":
			var at := P.pos + Vector3(0.6, 0, 0)
			var mate: Hunter = m.make_hunter("Mate", P.team, "medium", "Mate", "idle", {}, at, {"arch": "none"})
			step(m, 0.1)
			mate.downed = true
			mate.revive = 0.0
			mate.down_hp = 1000.0
			CareUtil.set_carry(m, mate, P.nid)

func hold_start(m: Match, P: Hunter) -> void:
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	step(m, PRE_HOLD_S, func(): P.inp["sec_hold"] = true)

## Free to walk: no stun, root or statue lock, and the kit's own pace isn't zero.
func _free(P: Hunter) -> bool:
	return P.stun_t <= 0.0 and P.root_t <= 0.0 and P.ak.move_k() > 0.0 and not P.ak.cast_locked()

## The state is on: the bow drawn, the shield up, the Lunge held, the drag open, the ultimate spent...
func _engaged(P: Hunter, st: String, arch: String) -> bool:
	match st:
		"lmb":
			return P.draw_t >= 0.0 if arch == "archer" else P.inp["fire"]
		"rmb":
			# (a hold that fires by itself, or a press cast, has run its cast)
			var held: bool = P.ak.rmb_down or float(P.ak.cd["rmb"]) > 0.0
			return held and (arch != "bulwark" or not (P.ak as BulwarkKit).wall.is_empty())
		"e":
			return not (P.ak as MageKit).strikes.is_empty() if arch == "mage" else true
		"r_press":
			return P.ult < 1.0 or P.ak.r_def().is_empty()     # (the support pair has no R)
		"crouch":
			return P.crouch
		"carry":
			return not (P.ak as TenderKit).carrying().is_empty()
	return true

## One frame of keys: walk east, plus the state's held key.
func _drive(P: Hunter, st: String) -> void:
	P.inp["move"] = Vector2(1, 0)
	P.inp["fire"] = st == "lmb"
	P.inp["sec_hold"] = st == "rmb"
	P.inp["e_down"] = st == "e"
	P.inp["crouch"] = st == "crouch"

func _end(P: Hunter) -> void:
	for k in ["move", "fire", "sec_hold", "e_down", "crouch"]:
		P.inp[k] = Vector2.ZERO if k == "move" else false
	P.ak.drop_holds()
