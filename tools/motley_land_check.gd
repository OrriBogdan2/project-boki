extends "res://tools/archetype_check.gd"
## --motley-land-check: Motley's Lantern Trade onto high and awkward spots: he can throw it onto high ledges and
## get there, and it never leaves him inside a wall. On every shipped map
## (arena, tutorial, Skyreach, Hollow Crown) it throws, through the real Shift press, at:
##   ledge   the cliff face of a terrace >= 2 levels above him (cursor just in front of it): he ends on its top
##   high    the middle of a platform >= 3 levels up (over the cursor's 3-level band): he ends on its top
##   wall    a rock, tree or wall tile: he ends clear of it
##   ceiling the same from a 3m hover (he arrives up there and drops: never into the rock)
##   rim     the island's edge over the abyss
## Every throw must end with his body free (World.occupy) and not on a blocker tile; ledge and high throws must
## end on the target terrace. The maps are terrace heightmaps (no overhangs), so a 3m rock under a hovering
## drop is the ceiling case. Prints "MLAND DONE, N checks, failures: M".

const MAPS := ["arena", "tutorial", "skyreach", "hollowcrown"]
const PER_KIND := 4  # throws of each kind on each map
const RUN_UP := 4.0  # m he stands back from the face or the rock
const WAIT_S := 5.0  # s a Trade gets to land (1.8s, plus a tutorial beat that holds his kit ~2s)
const SETTLE_S := 1.0  # s after the Trade for a hover to come down
const KINDS := ["ledge", "high", "wall", "ceiling", "rim"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var W: World
var rng := RandomNumberGenerator.new()
var seen := {}  # kind -> throws made over all maps (a map may have none of a kind: the arena is flat)


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for id in MAPS:
		await _map(String(id))
	for kind in KINDS:
		ok("%s: thrown on some map (%d)" % [kind, int(seen.get(kind, 0))], int(seen.get(kind, 0)) >= PER_KIND)
	print("MLAND DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func _map(id: String) -> void:
	var o := {
		"teams": 1,
		"squad": 1,
		"tier": 0,
		"length": 1e9,
		"seed": 77,
		"no_drop": true,
		"god": true,
		"cls": Arch.weight("ostra"),
		"arch": "ostra",
		"weapon": Arch.signature("ostra")
	}
	match id:
		"arena":
			o.merge({"arena": true, "training": true})
		"tutorial":
			o["tutorial"] = true
		_:
			o["map"] = id
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	W = m.world
	rng.seed = 1111
	var P: Hunter = m.player
	for h in m.hunters:
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	P.set_arch("ostra")
	P.unlock_all()
	var cases := _cases(P.r)
	for kind in KINDS:
		var list: Array = cases[kind]
		var good := 0
		var why := ""
		for c in list:
			var res := _throw(m, P, c, kind)
			if res == "":
				good += 1
			elif why == "":
				why = res
		seen[kind] = int(seen.get(kind, 0)) + list.size()
		var what := " and on the ledge" if kind in ["ledge", "high"] else ""
		ok("%s %s: %d of %d throws end free%s" % [id, kind, good, list.size(), what], good == list.size(), why)
	await done(m)


## Throws once; "" when he ends free (and on the ledge for ledge/high), else what went wrong.
func _throw(m: Match, P: Hunter, c: Dictionary, kind: String) -> String:
	var K := P.ak as OstraKit
	K._drop_holds()
	var start: Vector3 = c["start"]
	if kind == "ceiling":
		start.y += 3.0
	P.teleport(start)
	P.vel = Vector3.ZERO
	P.grounded = kind != "ceiling"
	P.stun_t = 0.0
	P.dashes = P.max_dashes()
	aim_at(P, c["aim"])
	P.inp["dash_down"] = false
	var before := K.swaps
	K.on_dash(false)
	var t := 0.0
	while (K.swaps == before or not K.swap.is_empty()) and t < WAIT_S:
		step(m, DT)
		t += DT
	if K.swaps == before:
		return "no Trade at %s" % str(c["aim"])
	step(m, SETTLE_S)
	var p := P.pos
	if W.occupy(p.x, p.z, P.r, p.y, false) != 0.0 or W.is_block(p.x, p.z):
		return "stuck at %s (aim %s)" % [str(p), str(c["aim"])]
	if c.has("top") and absf(p.y - float(c["top"])) > World.STEP:
		return "y %.2f, ledge top %.2f (aim %s)" % [p.y, float(c["top"]), str(c["aim"])]
	return ""


func _ctr(x: int, z: int) -> Vector3:
	return Vector3(x + 0.5, W.ground_at(x + 0.5, z + 0.5), z + 0.5)


func _fits(p: Vector3, r: float) -> bool:
	return not W.is_void(p.x, p.z) and W.occupy(p.x, p.z, r, p.y, false) == 0.0


func _plain(x: int, z: int) -> bool:
	return W.inb(x, z) and W.kind[W.idx(x, z)] == World.T_GROUND and not W.stairs.has(W.idx(x, z))


## Up to PER_KIND cases of each kind, picked at random from every spot on the map that makes one:
## {start, aim, top (ledge and high: the terrace he must end on)}.
func _cases(r: float) -> Dictionary:
	var all := {}
	for k in KINDS:
		all[k] = []
	for z in range(1, W.h - 1):
		for x in range(1, W.w - 1):
			if _plain(x, z):
				for d in DIRS:
					_spot(all, x, z, d, r)
	var out := {}
	for k in KINDS:
		var list: Array = all[k]
		var pick: Array = []
		while pick.size() < PER_KIND and not list.is_empty():
			pick.append(list.pop_at(rng.randi_range(0, list.size() - 1)))
		out[k] = pick
	return out


## The throws tile (x, z) offers toward d: a rock, the abyss or a terrace just past it.
func _spot(all: Dictionary, x: int, z: int, d: Vector2i, r: float) -> void:
	var a := _ctr(x, z)
	var back := Vector3(a.x - d.x * RUN_UP, 0, a.z - d.y * RUN_UP)
	back.y = W.ground_at(back.x, back.z)
	if not _fits(back, r) or absf(back.y - a.y) > World.STEP:
		return
	var bx := x + d.x
	var bz := z + d.y
	var b := W.idx(bx, bz)
	var face := Vector3(a.x + d.x * 0.3, a.y, a.z + d.y * 0.3)  # 0.2 m short of the next tile
	if W.kind[b] == World.T_BLOCK:
		all["wall"].append({"start": back, "aim": _ctr(bx, bz)})
		all["ceiling"].append({"start": back, "aim": _ctr(bx, bz)})
	elif W.kind[b] == World.T_VOID and _fits(a, r):
		all["rim"].append({"start": back, "aim": face})
	elif _plain(bx, bz) and _plain(bx + d.x, bz + d.y) and W.level[b] == W.level[W.idx(bx + d.x, bz + d.y)]:
		var top := _ctr(bx, bz)
		var top2 := _ctr(bx + d.x, bz + d.y)
		if not _fits(top2, r) or not _fits(top, r):
			return
		var rise := top.y - a.y
		if rise >= 2.0 * World.LEVEL - 0.01 and _fits(a, r):
			all["ledge"].append({"start": back, "aim": face, "top": top.y})
		if rise >= 3.0 * World.LEVEL + 0.01:
			all["high"].append({"start": back, "aim": top2, "top": top.y})
