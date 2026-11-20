extends RefCounted
## --camp-layout-check: camps keep clear of the Ways Out outposts (the only exit sites since Ways Out; the
## docks and hatches are gone, so this reads the layout's `outposts` and nothing else). Builds the real world
## for a few seeds and asserts, for every camp the match would spawn, that it stands at least FROM_OUTPOST
## metres from every outpost, so a squad leaving by an uplink is not dropped into a camp's aggro ring.
## Two Frostgate/Cinder heavy camps were 7.9 m off the moved outposts before this check. Never touches the save.

const SEEDS := [3, 9, 21]
const FROM_OUTPOST := 20.0

var bad := 0
var n := 0

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CAMPLAYOUT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var L := World.load_layout("hollowcrown")
	var outposts: Array = L.get("outposts", [])
	ok(outposts.size() > 0, "the layout lists %d outposts" % outposts.size())
	for sd in SEEDS:
		var w := World.new()
		w.generate_authored(L, sd)
		ok(w.camp_spots.size() > 0, "seed %d: %d camps spawn" % [sd, w.camp_spots.size()])
		for c in w.camp_spots:
			var p := Vector2(c["pos"].x, c["pos"].z)
			var near := INF
			for o in outposts: near = minf(near, p.distance_to(Vector2(o[0], o[1])))
			var what := "seed %d: %s camp (%d,%d) is %.1f m from the nearest outpost (needs %d)"
			ok(near >= FROM_OUTPOST, what % [sd, c["kind"], int(p.x), int(p.y), near, int(FROM_OUTPOST)])
		w.free()
	print("CAMPLAYOUT DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(0 if bad == 0 else 1)
