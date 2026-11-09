extends RefCounted
## The "over the abyss" rows of the ground-placed casts (docs/heroes/*.md, "Over the abyss"): a cast whose
## cursor lies past the island's lip. The source says nothing for these (wiki and footage), so the rule is
## the one it does show (Void's Swap and Ghost's "target location" land where aimed, Kingpin's Slam only
## drops its downward push over the abyss): the cast forms anyway at the cursor, on the caster's height.
## Called from the hero's own combo check; each method adds to n / fails.

var main: Node
var fails := 0
var n := 0
var ac: RefCounted
const LIP := 3          # tiles east of the caster's tile where the island ends
const GAP := 8          # tiles of abyss past the lip

func ok(name_: String, cond: bool, info := "") -> void:
	n += 1
	print("ABYSS %-60s %s  %s" % [name_, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## The shared strip with the island ending LIP tiles east of the caster; returns [m, P, T, home].
func _strip(arch: String) -> Array:
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup(arch, 6.0)
	var m: Match = r[0]
	var W: World = m.world
	var home: Vector3 = r[4]
	var hx := int(floor(home.x))
	var hz := int(floor(home.z))
	for dz in range(-10, 11):
		for dx in range(LIP, LIP + GAP):
			W.kind[W.idx(hx + dx, hz + dz)] = World.T_VOID
	var T: Hunter = r[2]
	T.teleport(home + Vector3(float(LIP) + 1.5, 0, 0))
	return [m, r[1], T, home]

## A dummy held up in the air over the abyss (nothing under it).
func _hover(T: Hunter, y: float) -> void:
	T.vel = Vector3.ZERO
	T.pos.y = y

func _reaches_void(m: Match, p: Vector3) -> bool:
	return m.world.is_void(p.x, p.z)

# ------------------------------------------------------------------ Albert: Faultline
func bulwark() -> void:
	var r := _strip("bulwark")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: BulwarkKit = P.ak
	ac.aim_at(P, home + Vector3(float(LIP + GAP - 1), 0, 0))
	K.cd["x"] = 0.0
	ok("abyss: Faultline cast at a cursor past the lip goes off", K.cast_ult())
	ok("abyss: the lane runs on over the abyss, all four cells",
			K.ult.cells.size() == 4 and _reaches_void(m, K.ult.cells[1]), "cells %d" % K.ult.cells.size())
	ac.step(m, 1.8)
	ok("abyss: every cell erupts and the cooldown runs (no clamp, no refund)",
			K.ult.erupted == 4 and float(K.cd["x"]) > 1.0, "erupted %d" % K.ult.erupted)

# ------------------------------------------------------------------ Neve: Rink Wall and Rimelock
func rimewright() -> void:
	var r := _strip("rimewright")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: RimewrightKit = P.ak
	ac.aim_at(P, home + Vector3(float(LIP + GAP - 1), 0, 0))
	K.cd["e"] = 0.0
	K.use_e()
	ok("abyss: Rink Wall cast toward the abyss goes off and its cooldown runs", float(K.cd["e"]) > 1.0)
	ac.step(m, 0.5)
	var w: Dictionary = K.wall.get("w", {})
	ok("abyss: the wall erupts on the island and slides no further than its lip",
			not w.is_empty() and float((w["a"] as Vector2).x) < home.x + float(LIP) + 0.5, "wall %s" % str(w.get("a")))
	ac.step(m, 4.0)
	var ww: Dictionary = K.wall.get("w", {})
	var mid_x := 0.0 if ww.is_empty() else ((ww["a"] as Vector2).x + (ww["b"] as Vector2).x) * 0.5
	ok("abyss: it stands at the lip, not over the abyss", not ww.is_empty() and not m.world.is_void(mid_x, home.z))
	# cast from the lip itself: the point a metre ahead is over the abyss and she still erupts it there
	P.teleport(home + Vector3(float(LIP) - 0.6, 0, 0))
	ac.step(m, 0.2)
	K.cd["e"] = 0.0
	K.wall = {}
	ac.aim_at(P, home + Vector3(float(LIP + GAP - 1), 0, 0))
	K.use_e()
	ok("abyss: from the lip itself the wall still forms", float(K.cd["e"]) > 1.0)
	ac.step(m, 0.5)
	ok("abyss: the wall forms a metre out, over the abyss", not K.wall.is_empty() and m.verbs.walls.has(K.wall["w"]))
	# Rimelock: the rink opens round her and chills a foe hanging over the abyss
	P.teleport(home + Vector3(float(LIP) - 0.6, 0, 0))
	T.teleport(home + Vector3(float(LIP) + 1.5, 0, 0))
	K.cd["x"] = 0.0
	ok("abyss: Rimelock cast at the lip goes off", K.cast_ult())
	ac.step(m, 0.4, func(): _hover(T, home.y + 0.5))
	ok("abyss: the rink opens and chills a foe over the abyss",
			K.ult_running() and T.slow_t > 0.0, "slow %.2f" % T.slow_t)

# ------------------------------------------------------------------ Meeko: Hearthlight
func tender() -> void:
	var r := _strip("tender")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[3]
	var K: TenderKit = P.ak
	var cursor := home + Vector3(float(LIP + 4), 0, 0)
	ac.aim_at(P, cursor)
	K.cd["e"] = 0.0
	K.use_e()
	ok("abyss: Hearthlight goes off and its cooldown runs", float(K.cd["e"]) > 1.0)
	K.use_e()
	ok("abyss: the toss over the abyss is thrown", bool(K.hearth.get("tossed", false)))
	ac.step(m, 1.0)
	var at: Vector3 = K.hearth_center()
	ok("abyss: the light lands at the cursor, over the abyss, and stays",
			not K.hearth.is_empty() and _reaches_void(m, at) and absf(at.x - cursor.x) < 0.6,
			"at %.1f want %.1f" % [at.x, cursor.x])

# ------------------------------------------------------------------ Vex: Cinderfall
func gunslinger() -> void:
	var r := _strip("gunslinger")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: GunslingerKit = P.ak
	var cursor := home + Vector3(float(LIP + 4), 0, 0)
	ac.aim_at(P, cursor)
	K.cd["x"] = 0.0
	ok("abyss: Cinderfall cast at a cursor over the abyss goes off", K.cast_ult())
	var at: Vector3 = K.ult.shells[0]["at"]
	ok("abyss: the shell is aimed at the cursor over the abyss",
			_reaches_void(m, at) and absf(at.x - cursor.x) < 0.6, "x %.1f want %.1f" % [at.x, cursor.x])
	var hp0 := T.hp
	T.teleport(Vector3(cursor.x, home.y + 0.5, cursor.z))
	ac.step(m, float(K.x_def()["delay"]) + 0.6, func(): _hover(T, home.y + 0.5))
	ok("abyss: it lands and burns a foe hanging over the abyss", T.hp < hp0, "hp %.1f" % (hp0 - T.hp))
	ok("abyss: the cooldown runs", float(K.cd["x"]) > 1.0)

# ------------------------------------------------------------------ Grimble: Anchor Drop
func dredge() -> void:
	var r := _strip("dredge")
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: DredgeKit = P.ak
	P.teleport(home + Vector3(float(LIP) - 0.6, 0, 0))
	ac.step(m, 0.2)
	T.teleport(home + Vector3(float(LIP) + 1.5, 0.5, 0))
	T.hp = T.max_hp
	ac.aim_at(P, T.pos)
	K.cd["e"] = 0.0
	ok("abyss: the Anchor Drop cast at the lip goes off", K.cast_e())
	ac.step(m, float(K.e_def()["windup"]) + 0.3, func(): _hover(T, home.y + 0.5))
	ok("abyss: the cone lands over the abyss and hits a foe hanging there",
			T.hp < T.max_hp, "dmg %.1f" % (T.max_hp - T.hp))
	ok("abyss: he stays on the island (no push down, no lunge)",
			P.pos.y >= home.y - 0.1 and not _reaches_void(m, P.pos))
