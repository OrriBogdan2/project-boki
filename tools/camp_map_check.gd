extends RefCounted
## --camp-map-check: camps on the maps (docs/decisions/0048-camps-and-xp.md, scripts/ui/camp_map.gd).
## In the planning phase every camp is a live marker of the right size (SpawnPlan "camp"); every region
## has its "N camps: to level L" line; a clear dims a marker and a comeback fills its ring, only for a
## squad that has been within 60 m since the clear; the minimap's range decides which camps it shows;
## the smoke columns equal the camps during the drop and are gone 5 s after landing; every new string
## fits one line. Never touches the save.

const FLAMES := {"small": 1, "camp": 2, "great": 3, "chief": 3}
const ONE_LINE_PX := 340.0      # the legend's width for a row, at the size it draws

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAMPMAP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 6, "squad": 3, "tier": 0, "length": 1e9, "seed": 5})
	m.set_process(false)
	_markers(m)
	_regions(m)
	_states(m)
	_minimap(m)
	_smoke(m)
	_strings(m)
	print("CAMPMAP DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _markers(m: Match) -> void:
	var sp := m.spawn_plan
	ok(m.skydrop != null and m.skydrop.planning, "the match opens in the planning phase")
	var cs := sp.of("camp")
	ok(cs.size() == 28 and cs.size() == m.camps.camps.size(), "28 camp markers on the drop map (%d)" % cs.size())
	ok(bool(sp.cats["camp"]["announce"]) and "camp" in sp.shown_cats(), "camps are an announced category")
	var right := true
	var live := true
	for c in cs:
		var size_id: String = Camps.size_def(int(m.camps.camps[int(c["camp"])]["size"]))["id"]
		right = right and sp.shape_of(c) == "camp%d" % ((FLAMES[size_id]) + int(size_id == "chief"))
		live = live and sp.state_for(c, m.player.team) == "active" and c["active"]
	ok(right, "each marker's icon matches its camp's size (1, 2, 3 flames, a crown on a Chief)")
	ok(live, "every camp is live for the squad from 0:00")
	ok(sp.cands.filter(func(c): return c["cat"] == "camp").size() == 28 and sp.active_ids().size() >= 28,
		"no roll: camps are never picked from a pool")

## The line under each region: its camps and the level their XP reaches.
func _regions(m: Match) -> void:
	var fm: FullMap = m.hud.full_map if m.hud else null
	ok(fm != null, "the full map exists")
	if fm == null:
		return
	var all := true
	var n_lines := 0
	for ii in m.world.islands.size():
		var ri: int = m.biomes.hot.region_of[ii]
		if ri < 0:
			continue
		var camps := m.camps.list().filter(func(e): return e["region"] == ri)
		var xp := 0.0
		for e in m.camps.camps.filter(func(c): return c["region"] == ri):   # list() leaves the mobs out
			for mb in e["mobs"]: xp += XpRules.kill_xp(mb)
		var lvl := 1
		for i in range(1, Hunter.XP_TO.size()):
			if xp >= Hunter.XP_TO[i]: lvl = i + 1
		var want := "%d camp%s: to level %d" % [camps.size(), "" if camps.size() == 1 else "s", lvl]
		var got := fm._region_line(String(m.world.islands[ii].get("name", "")))
		if camps.is_empty():
			all = all and got == ""
		else:
			all = all and got == want
			n_lines += 1
		if not (got == want or camps.is_empty()): print("  region %d: want '%s' got '%s'" % [ri, want, got])
	ok(all and n_lines >= 9, "every region's line reads camps and level from its camps' XP (%d lines)" % n_lines)
	ok(CampMap.region_line(3, 460.0) == "3 camps: to level 5" and CampMap.region_line(1, 60.0) == "1 camp: to level 1",
		"the line's wording")
	m.skydrop.planning = false
	ok(fm._region_line(String(m.world.islands[1].get("name", ""))) == "", "no region lines once the ship has gone")
	m.skydrop.planning = true

## A clear dims the marker for a squad that was near, not for one far away; a comeback fills the ring.
func _states(m: Match) -> void:
	var sp := m.spawn_plan
	var P: Hunter = m.player
	for h in m.hunters:                       # (on the ground: SpawnPlan only counts hunters who are not riding)
		h.riding = false
		if h != P: h.pos = Vector3(-1e4, 0, -1e4)
	var c: Dictionary = sp.of("camp")[0]
	var camp: Dictionary = m.camps.camps[int(c["camp"])]
	var far: int = (P.team + 1) % 6
	P.pos = (camp["pos"] as Vector3) + Vector3(1, 0, 0)
	m.time = 30.0
	for mb in (camp["mobs"] as Array).filter(func(o): return is_instance_valid(o) and not o.dead):
		mb.hurt(1e6, P)
	sp._t = 0.0
	sp.tick(0.1)
	ok(camp["state"] == Camps.State.CLEARED, "the camp is cleared")
	ok(sp.state_for(c, P.team) == "returning",
		"a squad that stood at the clear sees it dim with a ring (%s)" % sp.state_for(c, P.team))
	ok(sp.state_for(c, far) == "active", "a squad that never came near still sees it live")
	var f0 := sp.comeback_frac(c)
	m.time = 30.0 + 75.0
	ok(absf(sp.comeback_frac(c) - 0.5) < 0.05 and f0 < 0.05,
		"the ring fills toward the comeback (%.2f then %.2f)" % [f0, sp.comeback_frac(c)])
	P.pos = (camp["pos"] as Vector3) + Vector3(200, 0, 0)
	var other: Hunter = m.hunters.filter(func(h): return h.team == far)[0]
	other.pos = (camp["pos"] as Vector3) + Vector3(70, 0, 0)
	sp._t = 0.0
	sp.tick(0.1)
	ok(sp.state_for(c, far) == "active", "70 m away is not near enough to see the clear")
	other.pos = (camp["pos"] as Vector3) + Vector3(50, 0, 0)
	sp._t = 0.0
	sp.tick(0.1)
	ok(sp.state_for(c, far) == "returning", "within 60 m of a cleared camp, any squad sees its state")
	for h in m.hunters: h.pos = Vector3(-1e4, 0, -1e4)
	m.time = float(camp["back_t"]) + 1.0
	m.camps._tick_t = 0.0
	m.camps.tick(0.1)
	sp._t = 0.0
	sp.tick(0.1)
	var all_live: bool = sp.state_for(c, far) == "active" and sp.state_for(c, P.team) == "active"
	ok(camp["state"] == Camps.State.RETURNING and all_live,
		"back again: live for everyone, one size up (%s)" % String(c["name"]))

## The minimap (HUD's disc on the ground, MapDetail.ground_view) shows exactly the camps inside it,
## without a hold, through the same filter HUD draws from (FullMap.minimap_spawns).
func _minimap(m: Match) -> void:
	var P: Hunter = m.player
	var c: Dictionary = m.spawn_plan.of("camp")[1]
	P.pos = (c["pos"] as Vector3) + Vector3(10, 0, 0)
	var disc := 100.0                          # px: the disc's radius (any size: it scales with the view)
	var view := MapDetail.ground_view(P.pos)
	var k := disc * 2.0 / view.size.x
	var to_map := func(p3: Vector3) -> Vector2: return (Vector2(p3.x, p3.z) - view.position) * k
	var on_map := func(v: Vector2, pad := 0.0) -> bool: return v.distance_to(Vector2(disc, disc)) <= disc - pad
	var shown: Array = m.hud.full_map.minimap_spawns(P.team, false, to_map, on_map) \
		.filter(func(o): return o["cat"] == "camp")
	var reach := MapDetail.GROUND_R - 5.0 / k
	var near := m.spawn_plan.of("camp").filter(func(o):
		return Vector2(o["pos"].x - P.pos.x, o["pos"].z - P.pos.z).length() <= reach)
	ok(not near.is_empty() and near.size() < 28 and shown == near,
		"the minimap shows only the camps in its range (%d shown, %d in range, of 28)" % [shown.size(), near.size()])

func _smoke(m: Match) -> void:
	var S: CampSmoke = m.camp_smoke
	var nodes: Array = []
	var P: Hunter = m.player
	ok(S != null and S.quads.is_empty(), "no smoke before the drop")
	P.dropping = true
	S.tick(0.1)
	ok(S.quads.size() == 28 and S.get_child_count() == 28,
		"one smoke quad per camp during the drop (%d)" % S.quads.size())
	var q: Dictionary = S.quads[0]
	var mat := (q["node"].mesh as QuadMesh).material as StandardMaterial3D
	var billboard: bool = mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED
	ok(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and billboard, "unshaded billboard quads")
	var fancy := S.find_children("*", "GPUParticles3D", true, false) + S.find_children("*", "Light3D", true, false)
	ok(fancy.is_empty(), "no particles, no lights")
	P.pos = (q["cand"]["pos"] as Vector3) + Vector3(100, 0, 0)
	S._look_t = 0.0
	S.tick(0.1)
	ok(q["node"].visible, "a column shows within 160 m")
	P.pos = (q["cand"]["pos"] as Vector3) + Vector3(200, 0, 0)
	S._look_t = 0.0
	S.tick(0.1)
	ok(not q["node"].visible, "and not beyond it")
	var strands := {}
	var hot_n := 0
	var hot: int = m.biomes.hot.hot
	for e in S.quads:
		strands[(e["node"].mesh as QuadMesh).size.x] = true
		var col: Color = ((e["node"].mesh as QuadMesh).material as StandardMaterial3D).albedo_color
		hot_n += int(col.is_equal_approx(CampSmoke.HOT_COL) == (e["cand"]["region"] == hot))
	ok(strands.size() >= 2 and hot_n == 28, "strands follow the size, orange only in the hot zone")
	for e in S.quads: nodes.append(e["node"])
	P.dropping = false
	S.tick(0.1)
	S.tick(4.0)
	ok(S.quads.size() == 28, "still up 4 s after landing")
	S.tick(2.0)
	ok(S.quads.is_empty(), "gone six seconds after landing")
	ok(nodes.size() == 28 and nodes.all(func(n): return n.is_queued_for_deletion()), "the nodes are freed")

func _strings(m: Match) -> void:
	var font: Font = ThemeDB.fallback_font
	var texts := [CampMap.HOT_LABEL, CampMap.LEGEND_ROW, CampMap.region_line(12, 1700.0),
		"Pick a camp and ping it", "Clear the camp to level up"]
	for s in texts:
		var wide := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		ok(not "\n" in s and wide < ONE_LINE_PX, "fits one line: %s" % s)
	var rows := {}
	for row: Array in FirstMatchGuide.rules()["lines"]: rows[row[0]] = row[1]
	ok(rows.get("pick") == "Pick a camp and ping it" and rows.get("camp") == "Clear the camp to level up",
		"the guide's two camp prompts")
