extends RefCounted
## Screenshots for --aimkit-check --shots-dir=<dir>: one per telegraph shape and cursor state, each in a
## hero's own colour, set up the way a hero sheet uses it. Writes <dir>/MANIFEST.txt
## (aimkit|<file>|<caption>). Run under xvfb with a renderer (docs/AIMKIT.md).

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var dir := ""
var home := Vector3.ZERO
var lines: Array = []

## [file stem, aim distance, camera lead (m east of the hunter), zoomed crop, caption]
const SHOTS := [
	["lane_fixed", 6.0, 4.0, false, "Fixed lane with an arrow tip, past the cursor (Vex RMB grenade aim, gunslinger colour)"],
	["lane_growing", 6.0, 3.0, false, "Growing lane mid-charge, k 0.45 (Juggernaut RMB Charge Dash)"],
	["lane_full", 6.0, 3.0, false, "The same lane at full charge: full length, hot, col_full magenta"],
	["lane_narrow", 6.0, 5.0, false, "Lane narrowing while charging, k 0.7 (Vex E Ion Cannon cast)"],
	["lane_rails", 6.0, 5.0, false, "Rails lane with chevrons, end circle with ticks and a glint sliding out with the charge (Sparkle Shift Surge)"],
	["circle_pointer", 6.0, 3.5, false, "Placed circle with ticks, a rim chevron and an arrow lane for the drag direction (Sparkle E)"],
	["lane_chevrons", 6.0, 4.0, false, "Chevron lane with an end cap (Sable RMB Trickshot cast window, thief colour)"],
	["vee_open", 6.0, 3.0, false, "Draw V opening 25 degrees at k 0.3, a glint riding the line (Lisette LMB draw toward Empowered)"],
	["vee_closed", 6.0, 3.0, false, "Draw V closed into one bright line at k 1 (Lisette Empowered ready)"],
	["cone_fill", 6.0, 4.0, false, "Filled cone from a stuck point back out, filling over its fuse, seen by all (Vex wall cone)"],
	["cone_edges", 6.0, 3.0, false, "Cone edges only: a 30 degree spread out to the slug range (Grimble LMB Buckshot)"],
	["circle_landing", 6.5, 3.5, false, "Landing circle at the cursor with four ticks, plus the thin aim line (Vex R Mini Nuke placement)"],
	["sweet_spot", 6.0, 2.5, false, "Slam circle a hop ahead with the inner sweet-spot ring growing, k 0.5 (Tarek RMB Volcano Crusher)"],
	["arc_wall", 6.0, 4.0, false, "Curved arc wall at the cursor distance, 120 degrees in 7 panels (Lisette E Rain of Arrows)"],
	["dotted", 6.0, 5.0, false, "Dotted lane to max range, past the cursor (Pip RMB seed)"],
	["swap", 7.0, 3.5, false, "Two-end swap marker: origin ring, destination ring with its sigil filling, a link with arrows both ways (Motley Shift)"],
	["line_span", 6.0, 4.0, false, "Gold aim line to the cursor with an arrow tick (Sable empowered LMB) and a long span with inward chevrons (Tarek R)"],
	["foe_view", 6.0, 5.0, false, "A foe's \"all\" telegraph tinted hostile (their slam ring); their own aim lane is not drawn for you"],
	["reticle_charge", 5.0, 2.5, true, "Cursor charge ring at 60%, hero colour"],
	["reticle_flare", 5.0, 2.5, true, "Cursor full-charge flare: a ring snapping out and a glint"],
	["reticle_perfect", 5.0, 2.5, true, "Cursor perfect-window star flash, gold, 0.12 s"],
]

func col(id: String) -> Color:
	return Color(String(Arch.def(id).get("color", "#ffffff")))

func take(main_node: Node, out: String) -> void:
	main = main_node; dir = out
	DirAccess.make_dir_recursive_absolute(dir)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("gunslinger"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # the boot splash stays up when a check starts the match by hand
	home = _spot(P.pos)
	P.teleport(home); P.vel = Vector3.ZERO
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for i in 5: m.step(1.0 / 60.0)
	P.teleport(home); T.teleport(home + Vector3(7.0, 0, 0))
	if m.hud: m.hud.visible = false     # the ground and the cursor states, without the panels over them
	for x in m.hunters:
		if x != P and x != T: x.teleport(home + Vector3(-30, 0, 30))
	for s in SHOTS:
		await _shot(String(s[0]), float(s[1]), float(s[2]), bool(s[3]), String(s[4]))
	m.queue_free()
	await main.get_tree().process_frame
	await _tiers()
	var f := FileAccess.open(dir.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	print("AIMKIT shots: %d in %s" % [lines.size(), dir])

## A real flat stretch of island (the check's strip is flattened in data only, so it draws as abyss):
## 16 x 7 tiles of plain ground on one level, away from the start.
func _spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(6, W.h - 6, 3):
		for x in range(6, W.w - 18, 3):
			if Vector2(x - start.x, z - start.z).length() < 24.0:
				continue
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-3, 4):
				for dx in range(-3, 13):
					var i: int = W.idx(x + dx, z + dz)
					if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false; break
				if not good: break
			if good:
				print("AIMKIT shots at %d,%d (start %.0f,%.0f)" % [x, z, start.x, start.z])
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	print("AIMKIT shots: no open stretch found, using the start")
	return start

func _show(what: String) -> void:
	match what:
		"lane_fixed": AimKit.lane(P, "a", {"len": 10.0, "width": 0.72, "tip": true})
		"lane_growing": AimKit.lane(P, "a", {"len": 5.4, "len0": 1.2, "k": 0.45, "width": 1.3, "fill": 0.45, "col": col("juggernaut")})
		"lane_full": AimKit.lane(P, "a", {"len": 5.4, "len0": 1.2, "k": 1.0, "width": 1.3, "fill": 1.0, "col": col("juggernaut"), "col_full": Color("ff3df0")})
		"lane_narrow": AimKit.lane(P, "a", {"len": 16.0, "width": 1.0, "width_to": 0.12, "k": 0.7, "col": Color("d9c8ff"), "col2": Color("c8ff6a")})
		"lane_rails":
			AimKit.lane(P, "a", {"len": 13.0, "width": 0.35, "rails": true, "chevrons": 5, "col": col("mage")})
			AimKit.circle(P, "b", {"at": home + Vector3(13.0 * 0.6, 0, 0), "r": 2.25, "ticks": true, "star": true, "col": col("mage")})
		"circle_pointer":
			var at := home + Vector3(4.0, 0, 1.5)
			AimKit.circle(P, "a", {"at": at, "r": 1.8, "ticks": true, "pointer": Vector2(0.6, -0.8), "col": col("mage"), "col2": Color("ffd25a")})
			AimKit.lane(P, "b", {"from": at, "dir": Vector2(0.6, -0.8), "len": 4.0, "width": 0.5, "tip": true, "col": col("mage")})
		"lane_chevrons": AimKit.lane(P, "a", {"len": 11.0, "width": 1.8, "chevrons": 4, "col": col("thief")})
		"vee_open": AimKit.vee(P, "a", {"k": 0.3, "glint": 0.35, "col": col("archer")})
		"vee_closed": AimKit.vee(P, "a", {"k": 1.0, "glint": 0.0, "col": col("archer")})
		"cone_fill": AimKit.cone(P, "a", {"from": home + Vector3(8.0, 0, 0), "dir": Vector2(-1, 0), "len": 6.0, "deg": 100.0, "fill": 0.55, "col": Color("6cf0a0"), "col2": Color("6ae8ff"), "all": true})
		"cone_edges": AimKit.cone(P, "a", {"len": 6.3, "deg": 30.0, "edges": true, "col": Color("f4f1e6")})
		"circle_landing":
			AimKit.circle(P, "a", {"r": 2.9, "ticks": true, "col": Color("f4f1e6")})
			AimKit.line(P, "b", {"col": Color("f4f1e6")})
		"sweet_spot": AimKit.sweet(P, "a", {"at": home + Vector3(2.6, 0, 0), "k": 0.5, "fill": 0.5, "col": Color("ff5a36"), "col2": Color("ffc23a"), "all": true})
		"arc_wall": AimKit.arc_wall(P, "a", {"col": col("archer")})
		"dotted": AimKit.dotted(P, "a", {"len": 15.0, "col": Color("fff4dc")})
		"swap": AimKit.swap(P, "a", {"fill": 0.6, "col": col("ostra")})
		"line_span":
			AimKit.line(P, "a", {"col": Color("ffd25a"), "hot": 0.6})
			AimKit.span(P, "b", {"at": home + Vector3(7.0, 0, 0), "len": 14.0, "chevrons": 3, "col": Color("f4f1e6")})
		"foe_view":
			AimKit.circle(T, "a", {"self": true, "r": 2.3, "fill": 0.6, "all": true, "col": col("juggernaut")})
			AimKit.lane(T, "b", {"dir": Vector2(-1, 0)})
		"reticle_charge": AimKit.charge(P, 0.6, {"col": col("archer")})
		"reticle_flare":
			AimKit.charge(P, 1.0, {"col": col("archer"), "flare": false})
			AimKit.flare(P, {"col2": Color("ffffff")})
			AimKit.layer(m).ret_of(P)["flare"] = AimReticle.FLARE_T * 0.7
		"reticle_perfect": AimKit.perfect(P)

func _shot(what: String, aim_d: float, lead: float, zoom: bool, caption: String) -> void:
	var L := AimKit.layer(m)
	var file := "aimkit_%s.png" % what
	AimKit.clear(P); AimKit.clear(T)
	P.inp["aim"] = P.pos + Vector3(aim_d, 0.9, 0); P.inp["aim_y"] = P.pos.y
	for i in 8:
		_show(what)
		P.face = atan2(-(P.inp["aim"].x - P.pos.x), -(P.inp["aim"].z - P.pos.z))
		m.cam.snap(P.pos + Vector3(lead, 0, 0))
		for h in m.hunters: h.render(1.0 / 60.0, 1.0)
		await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file))
	lines.append("aimkit|%s|%s" % [file, caption])
	if zoom:
		var c := L.reticle.cursor(P)
		var sz := Vector2i(180, 120)
		var rg := Rect2i(Vector2i(int(c.x) - sz.x / 2, int(c.y) - sz.y / 2), sz).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := img.get_region(rg)
		crop.resize(rg.size.x * 3, rg.size.y * 3, Image.INTERPOLATE_NEAREST)
		var zf := file.replace(".png", "_zoom.png")
		crop.save_png(dir.path_join(zf))
		lines.append("aimkit|%s|%s (3x crop round the cursor)" % [zf, caption])
	AimKit.clear(P); AimKit.clear(T)

## The cursor at terrace lips, on the regular tier-0 map (the arena is flat; its terraces are one tier).
func _tiers() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	P = m.player
	if m.hud: m.hud.visible = false
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for x in m.hunters:
		if x != P: x.teleport(Vector3(-50, 0, -50))
	await _tier_shot("tier_up", 1, 0.2, "Cursor (cross) on the upper terrace 0.2 m past a lip that faces the camera")
	await _tier_shot("tier_down", -1, 0.6, "Cursor (cross) on the lower terrace 0.6 m behind the lip you stand on")
	m.queue_free()
	await main.get_tree().process_frame

## A lip across the camera's view: rows z..z+2 on level lv, rows z-2..z-1 on lv + k, 3 tiles wide, plain
## ground. Returns [x, z, lv], or [] when the map has none.
func _lip(k: int) -> Array:
	var W = m.world
	for z in range(8, W.h - 8):
		for x in range(6, W.w - 6):
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-2, 3):
				for dx in range(-1, 2):
					var i: int = W.idx(x + dx, z + dz)
					var want := lv if dz >= 0 else lv + k
					if W.kind[i] != World.T_GROUND or int(W.level[i]) != want or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false; break
				if not good: break
			if good: return [x, z, lv]
	return []

## The cursor put on the far terrace `past` m beyond a lip (Match._mouse_aim reads that screen point) and a
## ground circle where a cast lands (AimMode.point). The red cross marks the cursor.
func _tier_shot(what: String, k: int, past: float, caption: String) -> void:
	var c := _lip(k)
	if c.is_empty():
		print("AIMKIT shots: no lip for %s" % what)
		return
	var x: int = c[0]; var z: int = c[1]; var lv: int = c[2]
	P.teleport(Vector3(x + 0.5, lv * World.LEVEL, z + 2.5)); P.vel = Vector3.ZERO
	var spot := Vector3(x + 0.5, (lv + k) * World.LEVEL, z - past)
	var sp := Vector2.ZERO
	for i in 8:
		m.cam.snap(P.pos + Vector3(0, 0, -2.0))
		sp = m.cam.unproject_position(spot)
		P.inp["aim"] = m._mouse_aim(sp); P.inp["aim_y"] = m.aim_y
		AimKit.circle(P, "a", {"at": AimMode.point(P, 12.0), "r": 0.5, "col": Color("f4f1e6")})
		P.face = atan2(-(spot.x - P.pos.x), -(spot.z - P.pos.z))
		for h in m.hunters: h.render(1.0 / 60.0, 1.0)
		await main.get_tree().process_frame
	var at := AimMode.point(P, 12.0)
	var off := Vector2(at.x - spot.x, at.z - spot.z).length()
	print("AIMKIT %s: cursor on %s, aim_y %.2f, cast lands %s (%.2f m off)" % [what, str(spot), m.aim_y, str(at.snapped(Vector3.ONE * 0.01)), off])
	var img := main.get_viewport().get_texture().get_image()
	if img == null:
		return
	img.fill_rect(Rect2i(int(sp.x) - 9, int(sp.y) - 1, 19, 3), Color.RED)
	img.fill_rect(Rect2i(int(sp.x) - 1, int(sp.y) - 9, 3, 19), Color.RED)
	var file := "aimkit_%s.png" % what
	img.save_png(dir.path_join(file))
	lines.append("aimkit|%s|%s: the cast lands at y %.2f (cursor's ground %.2f), %.2f m from it" % [file, caption, at.y, spot.y, off])
	AimKit.clear(P)
