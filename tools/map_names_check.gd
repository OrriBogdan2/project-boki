extends RefCounted
## --map-names-check: names on the full map never print over each other or under a marker (FullMap.label,
## docs/UI_STYLE.md section 7). On a real Hollow Crown match at 1920x1080:
##   1. every region name gets a spot clear of the markers (spawn spots, ways out, the Heart)
##   2. a name that would print over one already drawn (a halt under a region name) is left off
## Never touches the save.

const SIZE := Vector2(1920, 1080)
const REGION_PX := 17          # a region name's size at the map's opening zoom (FullMap._labels)

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		bad += 1
	print("MAPNAMES %s  %s" % ["ok  " if cond else "FAIL", what])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 7401,
		"no_drop": true, "heart": true, "god": true})
	await main.get_tree().process_frame
	var fm: FullMap = m.hud.full_map
	fm.open()
	fm._layout(SIZE)
	fm._marker_spots()
	ok(m.world.layout_id == "hollowcrown" and fm._spots.size() > 10,
		"%s, %d markers on the map" % [m.world.layout_id, fm._spots.size()])
	_regions(m, fm)
	var r := fm._label_rect("STORMCROWN GAOL", Vector2(800, 500), REGION_PX)
	fm._taken = [r]
	ok(not fm.label("Watch Halt", Vector2(800, 505), 10, Color.WHITE), "a halt name over a region name is left off")
	fm._taken.clear()
	fm.close()
	m.queue_free()
	print("MAPNAMES DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## 1: each region name at its own spot (how it was drawn before) and at the spot FullMap picks.
func _regions(m: Match, fm: FullMap) -> void:
	var regions := {}
	for isl in m.world.islands:
		regions[String(isl.get("name", ""))] = true
	var names := 0
	var was := 0
	var now: Array = []
	for lb in m.world.labels:
		var nm := String(lb["name"]).to_upper()
		if String(lb["kind"]) in ["perch", "rail", "choke"] or not regions.has(String(lb["name"])):
			continue
		names += 1
		var at: Vector2 = fm.to_screen(lb["pos"]) + Vector2(0, 5)
		if _on_marker(fm, nm, at):
			was += 1
		if _on_marker(fm, nm, fm._clear_spot(nm, at, REGION_PX)):
			now.append(nm)
	ok(names >= 8, "%d region names" % names)
	ok(now.is_empty(), "no region name under a marker (%d were at their own spot), still under one: %s" % [was, now])

func _on_marker(fm: FullMap, txt: String, at: Vector2) -> bool:
	var r: Rect2 = fm._label_rect(txt, at, REGION_PX).grow(FullMap.MARKER_PAD)
	for s in fm._spots:
		if r.has_point(s):
			return true
	return false
