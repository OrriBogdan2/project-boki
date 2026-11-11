extends RefCounted
## --map-names-check: names on the full map never print over each other or under a marker (FullMap.label,
## docs/UI_STYLE.md section 7). On real Hollow Crown matches (two spawn layouts), laid out as the HUD draws it:
##   1. region names move off the markers (spawn spots, ways out, Ways Out seats) and the pinned words (a seat's,
##      the hot zone's) without leaving their island (at most one is left on one), and never over another name
##   2. a name that would print over one already drawn (a halt under a region name) is left off
## Never touches the save.

const REGION_PX := 17          # a region name's size at the map's opening zoom (FullMap._labels)
const SEEDS := [7, 7401]       # two spawn layouts (7 is the one --ui-screens-shots films)

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
	print("MAPNAMES %s  %s" % ["ok  " if cond else "FAIL", what])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for seed_n in SEEDS:
		var m := Match.new()
		main.add_child(m)
		await m.start({"teams": Data.MATCH_PLAYERS, "squad": 1, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": seed_n})
		for f in 30:
			await main.get_tree().process_frame
		var fm: FullMap = m.hud.full_map
		fm.open()
		fm._layout(m.hud.c.size)      # (the HUD's own canvas: 1280x720 units, scaled up on a bigger screen)
		fm._taken.clear()
		fm._obstacles()
		ok(m.world.layout_id == "hollowcrown" and fm._spots.size() > 10,
			"seed %d: %s, %d markers on the map" % [seed_n, m.world.layout_id, fm._spots.size()])
		_regions(m, fm)
		if seed_n == SEEDS[0]:
			fm._taken = [fm._label_rect("STORMCROWN GAOL", Vector2(800, 500), REGION_PX)]
			ok(not fm.label("Watch Halt", Vector2(800, 505), 10, Color.WHITE),
				"a halt name over a region name is left off")
		fm._taken.clear()
		fm.close()
		m.queue_free()
		await main.get_tree().process_frame
	print("MAPNAMES DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## 1: each region name at its own spot (how it was drawn before) and at the spot FullMap picks.
func _regions(m: Match, fm: FullMap) -> void:
	var regions := {}
	for isl in m.world.islands:
		regions[String(isl.get("name", ""))] = isl
	var pinned := fm._taken.duplicate()      # the words reserved before any name (FullMap._obstacles)
	var placed: Array = []
	var was := 0
	var touching: Array = []      # names left on a marker or a pinned word
	var over: Array = []          # names over another region name
	for lb in m.world.labels:
		var nm := String(lb["name"]).to_upper()
		if String(lb["kind"]) in ["perch", "rail", "choke"] or not regions.has(String(lb["name"])):
			continue
		var at: Vector2 = fm.to_screen(lb["pos"]) + Vector2(0, 5)
		if _on_marker(fm, nm, at):
			was += 1
		var reach := float(regions[String(lb["name"])].get("r", 0.0)) * fm.k() * FullMap.ISLAND_REACH
		var spot := fm._clear_spot(nm, at, REGION_PX, reach)
		var r := fm._label_rect(nm, spot, REGION_PX)
		if _on_marker(fm, nm, spot) or pinned.any(func(q): return r.intersects(q)):
			touching.append(nm)
		if placed.any(func(q): return r.intersects(q)):
			over.append(nm)
		placed.append(r)
		fm._taken.append(r)      # (as FullMap._labels places them, one after another)
	ok(placed.size() >= 8, "%d region names" % placed.size())
	ok(touching.size() <= 1 and was >= 5, ("names on a marker: %d at their own spot; now on a marker or a pinned"
			+ " word: %s (at most one: a name wider than its crowded island)") % [was, touching])
	ok(over.is_empty(), "no region name over another: %s" % [over])

func _on_marker(fm: FullMap, txt: String, at: Vector2) -> bool:
	var r: Rect2 = fm._label_rect(txt, at, REGION_PX).grow(FullMap.MARKER_PAD)
	for s in fm._spots:
		if r.has_point(s):
			return true
	return false
