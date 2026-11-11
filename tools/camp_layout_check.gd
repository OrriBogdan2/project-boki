extends RefCounted
## --camp-layout-check: the 28 camps of the 2x Hollow Crown (docs/MAP_2X.md, camps section; the map is built
## by tools/make_hollowcrown.py). Builds the real world for a few seeds and asserts, on the camps the match
## would spawn: how many of each kind per region (12 light, 9 normal, 7 heavy, 79 monsters), and the placing
## rules: 30-70 m apart inside a region; 14 m from a train halt; 20 m from a lair gate, a vault and a way-out
## seat (dock, outpost, hatch); cover within 12 m; a region's biggest camp (heavy, else normal) is its
## nearest to the map centre (the Crown: its three heavy camps are nearer than its normal one); within
## 190 m of the centre; and on flat, level, walkable ground (no slope, stair, rock or tree). Never touches the save.

const SEEDS := [3, 9, 21]
const WANT := {
	"crown": {"normal": 1, "heavy": 3},
	"frostgate": {"light": 1, "normal": 1, "heavy": 1}, "cinder": {"light": 1, "normal": 1, "heavy": 1},
	"storm": {"light": 1, "normal": 1, "heavy": 1}, "thorn": {"light": 1, "normal": 1, "heavy": 1},
	"lark": {"light": 2, "normal": 1}, "highwatch": {"light": 2, "normal": 1},
	"duskmoor": {"light": 2, "normal": 1}, "saltmere": {"light": 2, "normal": 1},
}
const MONSTERS := {"light": 2, "normal": 3, "heavy": 4}
const RANK := {"light": 0, "normal": 1, "heavy": 2}
const GAP := [30.0, 70.0]
const FROM_HALT := 14.0
const FROM_SEAT := 20.0
const COVER := 12.0
const REACH := 190.0
const FLAT := 2          # tiles each way that must be walkable, level and clear

var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CAMPLAYOUT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var L := World.load_layout("hollowcrown")
	var region_of := {}
	for R in L["regions"]:
		for iid in R["islands"]: region_of[String(iid)] = String(R["id"])
	var far: Array = []         # points the camps keep clear of: [pos, min distance, what]
	for s in L["train"]["stations"]: far.append([Vector2(s[0], s[1]), FROM_HALT, "halt"])
	for p in L["spawn_points"]["vault"]["points"]: far.append([Vector2(p[0], p[1]), FROM_SEAT, "vault"])
	for s in L["outposts"]: far.append([Vector2(s[0], s[1]), FROM_SEAT, "outpost"])      # (the only exit sites since Ways Out)
	for sd in SEEDS:
		var w := World.new()
		w.generate_authored(L, sd)
		_seed(w, sd, region_of, far)
		w.free()
	print("CAMPLAYOUT DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(0 if bad == 0 else 1)

func _seed(w: World, sd: int, region_of: Dictionary, far: Array) -> void:
	var centre := Vector2(w.w / 2.0, w.h / 2.0)
	var gates: Array = []
	for D in w.lair_defs:
		var g: Vector2 = D["c"] + D["out"] * float(D["half"])
		gates.append([g, FROM_SEAT, "lair gate " + String(D["id"])])
	var by := {}
	var kinds := {"light": 0, "normal": 0, "heavy": 0}
	for c in w.camp_spots:
		var rid: String = region_of[String(w.islands[int(c["island"])]["id"])]
		if not by.has(rid): by[rid] = []
		by[rid].append({"p": Vector2(c["pos"].x, c["pos"].z), "kind": String(c["kind"])})
		kinds[String(c["kind"])] += 1
	var monsters := 0
	for k in kinds: monsters += int(kinds[k]) * int(MONSTERS[k])
	ok(w.camp_spots.size() == 28 and kinds == {"light": 12, "normal": 9, "heavy": 7} and monsters == 79,
		"seed %d: 28 camps (%s), %d monsters" % [sd, kinds, monsters])
	for rid in by:
		ok(WANT.has(rid), "seed %d: %s is a region with camps" % [sd, rid])
	for rid in WANT:
		var got := {}
		for c in by.get(rid, []): got[c["kind"]] = int(got.get(c["kind"], 0)) + 1
		ok(got == WANT[rid], "seed %d: %s holds %s" % [sd, rid, got])
		_region(w, sd, rid, by.get(rid, []), centre, far + gates)

func _region(w: World, sd: int, rid: String, camps: Array, centre: Vector2, far: Array) -> void:
	var tag := "seed %d %s" % [sd, rid]
	var dc: Array = camps.map(func(c): return (c["p"] as Vector2).distance_to(centre))
	var gap_bad := ""
	for i in camps.size():
		var p: Vector2 = camps[i]["p"]
		var who := "%s camp (%d,%d)" % [camps[i]["kind"], int(p.x), int(p.y)]
		for j in range(i + 1, camps.size()):
			var d := p.distance_to(camps[j]["p"])
			if d < GAP[0] or d > GAP[1]: gap_bad += " %s-%d:%.0f m" % [who, j, d]
		for f in far:
			var df := p.distance_to(f[0])
			if df < float(f[1]): ok(false, "%s: %s is %.1f m from a %s (needs %d)" % [tag, who, df, f[2], int(f[1])])
		ok(dc[i] <= REACH, "%s: %s is %.0f m from the centre (max %d)" % [tag, who, dc[i], int(REACH)])
		ok(_flat(w, p), "%s: %s stands on flat, clear, level ground" % [tag, who])
		ok(_cover(w, p), "%s: %s has cover within %d m" % [tag, who, int(COVER)])
	ok(gap_bad == "", "%s: camps are %d-%d m apart%s" % [tag, int(GAP[0]), int(GAP[1]), gap_bad])
	var near := 0
	for i in camps.size():
		if dc[i] < dc[near]: near = i
	var top := "light"          # the region's biggest kind: heavy where it has one, else normal (rim isles)
	for c in camps:
		if RANK[c["kind"]] > RANK[top]: top = c["kind"]
	var what := "%s: the camp nearest the centre (%.0f m) is its biggest, %s" % [tag, dc[near], top]
	ok(String(camps[near]["kind"]) == top, what)
	if rid == "crown":
		var farthest := 0
		for i in camps.size():
			if dc[i] > dc[farthest]: farthest = i
		ok(String(camps[farthest]["kind"]) == "normal", "%s: the normal camp is the farthest from the centre" % tag)

## Ground, no stair, no rock or tree, one level, FLAT tiles each way.
func _flat(w: World, p: Vector2) -> bool:
	var cx := int(floor(p.x))
	var cz := int(floor(p.y))
	if not w.inb(cx, cz): return false
	var lv := int(w.level[w.idx(cx, cz)])
	for z in range(cz - FLAT, cz + FLAT + 1):
		for x in range(cx - FLAT, cx + FLAT + 1):
			if not w.inb(x, z): return false
			var i := w.idx(x, z)
			if w.kind[i] != World.T_GROUND or w.stairs.has(i) or int(w.level[i]) != lv: return false
	return true

## Tall grass or a blocker (rock, tree, wall, crate) to hide behind, centre to centre.
func _cover(w: World, p: Vector2) -> bool:
	var r := int(ceil(COVER))
	var cx := int(floor(p.x))
	var cz := int(floor(p.y))
	for z in range(cz - r, cz + r + 1):
		for x in range(cx - r, cx + r + 1):
			if not w.inb(x, z) or Vector2(x + 0.5, z + 0.5).distance_to(p) > COVER: continue
			var i := w.idx(x, z)
			if w.bush.has(i) or w.kind[i] == World.T_BLOCK: return true
	return false
