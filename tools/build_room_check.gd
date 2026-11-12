extends RefCounted
## --build-room-check: room to walk round what you build (BuildClearance, HomeBuild.keeps_paths, StuckGuard)
## and the trough's panel.
##   1. a house hard against a fence is refused and the red ghost's cursor tag says why; one open tile between is fine;
##      a trough against a fence is refused too
##   2. a piece that would shut a Boki into a pocket of ground is refused; the same piece elsewhere is fine
##   3. a Boki or the player stuck in a pocket or inside something solid is freed within 2 s; one standing on
##      open ground is left alone
##   4. the trough's fill button reads "Fill it up", with no "Enter" anywhere on the panel
## Never touches the real save.

const FREE_WITHIN_S := 2.0      # s, how soon someone stuck must be out
const STEP_S := 0.05
const AREA := Vector2i(15, 10)  # open tiles the test layout needs

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BUILDROOM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = _new_save()
	HomeLayout.ensure(Save.d)
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame      # the interface builds over a few frames
	home._close_panel()
	var hb: HomeBuild = home.hb
	var o := open_area(hb)
	ok(o.x >= 0, "found %dx%d open tiles to build on (at %s)" % [AREA.x, AREA.y, o])
	if o.x < 0:
		_finish()
		return
	clear_area(hb, o)
	_room_rules(home, hb, o)
	_pocket_rules(home, hb, o)
	await _stuck_rules(home, hb, o)
	await _trough_panel(home)
	_finish()

func _finish() -> void:
	print("BUILDROOM DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _new_save() -> Dictionary:
	var d := Save.fresh()
	for nm in ["Pip", "Dot"]:
		var k := Save.new_kin("zapple", nm)
		k["starter"] = nm == "Pip"
		d["roster"].append(k)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "ft": {"did": {}, "done": true, "skipped": true, "gift": true}}
	return d

## The corner of an AREA-sized patch of buildable open ground, nearest the landing (gameplay_media clip 9 too).
func open_area(hb: HomeBuild) -> Vector2i:
	var w: World = hb.h.world
	var best := Vector2i(-1, -1)
	var best_d := INF
	for z in w.h - AREA.y:
		for x in w.w - AREA.x:
			var d := Vector2(x, z).distance_to(Vector2(HomeLayout.LANDING.x, HomeLayout.LANDING.z))
			if d < best_d and _all_open(hb, Vector2i(x, z)):
				best = Vector2i(x, z)
				best_d = d
	return best

## Every tile buildable once its wild (trees, rocks) is cleared.
func _all_open(hb: HomeBuild, o: Vector2i) -> bool:
	var w: World = hb.h.world
	for z in AREA.y:
		for x in AREA.x:
			var t := Vector2i(o.x + x, o.y + z)
			if not w.inb(t.x, t.y):
				return false
			var i := w.idx(t.x, t.y)
			var wild := String(hb.wild_t.get(i, ""))
			if wild in ["cliff", "water"] or hb.cliff_t.has(i) or hb.occ.has(i) or hb.reserved.has(i):
				return false
			if w.kind[i] == World.T_VOID or w.bridge.has(i) or w.island[i] != 0:
				return false
			if hb._near_feeder(t) or hb._near_plot(t):
				return false
	return true

func clear_area(hb: HomeBuild, o: Vector2i) -> void:
	for z in AREA.y:
		for x in AREA.x:
			hb.clear_wild(Vector2i(o.x + x, o.y + z))
	hb.apply(false)

func put(hb: HomeBuild, id: String, t: Vector2i) -> void:
	var lay := hb.L()
	(lay["deco"] as Array).append({"u": HomeLayout._next_uid(lay), "id": id, "x": t.x, "z": t.y, "r": 0})

func _house(o: Vector2i, x: int) -> Array:
	return HomeLayout.cells_of([o.x + x, o.y + 4, o.x + x + 4, o.y + 6])

# ------------------------------------------------------------------ 1. room round a building
func _room_rules(home, hb: HomeBuild, o: Vector2i) -> void:
	for z in range(3, 8):
		put(hb, "fence", o + Vector2i(9, z))
	hb.apply(false)
	var house := {"kind": "deco", "id": "house", "r": 0, "from": -1}
	var tight := _house(o, 4)
	ok(not hb.fits(house, tight) and hb.why.contains("leave room") and hb.why.contains("fence"),
			"a house hard against a fence is refused: '%s'" % hb.why)
	hb.toggle()
	ok(hb.active and hb.keys != null, "build mode opens")
	if hb.keys == null:
		return
	hb.held = house
	hb._make_ghost()
	hb.cells = tight
	hb._check_cells()
	hb._draw_cells()
	hb._update_keys()
	var tag_text := ""
	for l in hb.keys.find_children("*", "Label", true, false):
		if (l as Label).text == hb.why and l.is_visible_in_tree():
			tag_text = (l as Label).text
	ok(not hb.ghost_ok and tag_text != "", "the red ghost's tag by the cursor gives the reason: '%s'" % tag_text)
	var tint: StandardMaterial3D = null
	for mi in hb.ghost.find_children("*", "MeshInstance3D", true, false):
		tint = (mi as MeshInstance3D).material_overlay
	ok(tint != null and tint.albedo_color.r > tint.albedo_color.g, "the ghost itself is tinted red")
	hb._drop_held()
	hb.toggle()
	var gap_ok := hb.fits(house, _house(o, 3))
	ok(gap_ok, "with one open tile between the house and the fence it fits ('%s')" % hb.why)
	ok(not hb.feeder_fits(o + Vector2i(10, 5), "") and hb.why.contains("leave room"),
			"a trough against the fence is refused: '%s'" % hb.why)
	ok(hb.feeder_fits(o + Vector2i(11, 9), ""), "a trough with room round it fits ('%s')" % hb.why)

# ------------------------------------------------------------------ 2. no pockets
## A ring of fence round tile P, open on its south side; P's Boki would be shut in by a pillar there.
func _pocket_rules(home, hb: HomeBuild, o: Vector2i) -> void:
	var p := o + Vector2i(13, 5)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if Vector2i(dx, dz) != Vector2i.ZERO and Vector2i(dx, dz) != Vector2i(0, 1):
				put(hb, "fence", p + Vector2i(dx, dz))
	hb.apply(false)
	var k: Dictionary = home.kins[0]
	_place_kin(k, p)
	var pillar := {"kind": "deco", "id": "pillar", "r": 0, "from": -1}
	ok(not hb.fits(pillar, [p + Vector2i(0, 1)]) and hb.why == PlaceClearance.why(String(k["rec"]["name"])),
			"a pillar that would shut %s into the fenced corner is refused: '%s'" % [k["rec"]["name"], hb.why])
	ok(hb.fits(pillar, [o + Vector2i(13, 9)]), "the same pillar on open ground fits ('%s')" % hb.why)

# ------------------------------------------------------------------ 3. the safety net
func _stuck_rules(home, hb: HomeBuild, o: Vector2i) -> void:
	var p := o + Vector2i(13, 5)
	put(hb, "pillar", p + Vector2i(0, 1))      # the pocket shut anyway (an old save, or a layout reset)
	hb.apply(false)
	var shut: Dictionary = home.kins[0]
	_place_kin(shut, p)
	ok(hb.stuck.stuck(shut["pos"]), "a Boki in the shut-in corner reads as stuck")
	var t := await _time_to_free(home, func(): return shut["pos"])
	ok(t <= FREE_WITHIN_S and not hb.stuck.stuck(shut["pos"]), "the Boki in the pocket is out in %.2f s" % t)
	var inside: Dictionary = home.kins[1]
	_place_kin(inside, o + Vector2i(9, 5))
	t = await _time_to_free(home, func(): return inside["pos"])
	ok(t <= FREE_WITHIN_S, "a Boki inside the fence is out in %.2f s" % t)
	home.ppos = Vector3(p.x + 0.5, 0, p.y + 0.5)
	home.py = 0.0
	t = await _time_to_free(home, func(): return home.ppos)
	ok(t <= FREE_WITHIN_S, "the player in the pocket is out in %.2f s" % t)
	var calm := Vector3(o.x + 2.5, 0, o.y + 9.5)
	shut["pos"] = calm
	(shut["node"] as Node3D).position = calm
	for i in int(FREE_WITHIN_S / STEP_S):
		hb.stuck.tick(STEP_S)
	ok((shut["pos"] as Vector3).distance_to(calm) < 0.01, "a Boki on open ground is left where it is")

func _place_kin(k: Dictionary, t: Vector2i) -> void:
	k["pos"] = Vector3(t.x + 0.5, 0, t.y + 0.5)
	k["goal"] = Vector3.INF
	(k["node"] as Node3D).position = k["pos"]

## Seconds of play until the body at where() is no longer stuck (the kin walk as in play), or INF.
func _time_to_free(home, where: Callable) -> float:
	var t := 0.0
	while t <= FREE_WITHIN_S + STEP_S:
		if not home.hb.stuck.stuck(where.call()):
			return t
		home._move_kin(STEP_S)
		home.hb.stuck.tick(STEP_S)
		t += STEP_S
	await main.get_tree().process_frame
	return INF

# ------------------------------------------------------------------ 4. the trough's panel
func _trough_panel(home) -> void:
	var f := {"id": "f9", "kind": "trough", "x": 40.5, "z": 30.5, "food": [], "auto": true}
	Save.d["feeders"].append(f)
	home.hecon.open_feeder(f)
	await main.get_tree().process_frame
	var fill: Button = null
	for b in home.find_children("*", "Button", true, false):
		if (b as Button).text == "Fill it up" and b.is_visible_in_tree():
			fill = b
	ok(fill != null, "the trough panel's button reads 'Fill it up'")
	var shell: Node = fill
	while shell != null and not shell.has_meta("primary"):
		shell = shell.get_parent()
	var words: Array = []
	for c in (shell if shell != null else home).find_children("*", "Control", true, false):
		if (c is Label or c is Button or c is RichTextLabel) and String(c.text).contains("Enter"):
			words.append(String(c.text))
	ok(shell != null and words.is_empty(), "nothing on the trough panel says Enter %s" % [words])
