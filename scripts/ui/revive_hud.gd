class_name ReviveHud
extends RefCounted
## Deathboxes and revive beacons on screen (docs/decisions/0018), for the Hud and the FullMap:
##   - whose box it is: a teammate's in their squad colour with their face and name, a rival's red
##     (Life.owner_col); your squad's boxes always show on the minimap and the full map, a rival's
##     only while it's within your sight;
##   - a box revive's progress: a ring on the ground round the box and one round the reviver;
##   - every beacon on the maps; a lit one (Beacons.lit) pulses there, with an arrow at the map's
##     edge and a marker in the world from anywhere, for every player whatever their team.

const PORTRAIT_PX := 30.0        # the teammate's face over their box
const HEAD_RING_PX := 34.0       # the progress ring round the reviver (clear of their health plate)
const HEAD_RING_UP := 0.9        # metres up: round the reviver's body
const USED_COL := Color(0.6, 0.66, 0.64, 0.6)
const GOOD := Color("8fe0a0")     # the Hud's revive green

# ------------------------------------------------------------------ the world
## Labels over boxes and beacons, and the marker for every lit beacon.
static func world_labels(hud) -> void:
	var m: Match = hud.m
	var cam: Camera3D = m.cam
	for b in m.boxes:
		var bp := LabelCull.at(hud, b["pos"] + Vector3(0, 1.9, 0))      # (item 94)
		if bp.is_finite():
			_box_label(hud, b, bp)
	for bc in m.beacons:
		if bc["used"]:
			continue
		if bc["lit"] and m.player:
			hud._draw_waypoint(bc["pos"] + Vector3(0, 1.0, 0), "Beacon", Beacons.COL)
		if cam.is_position_behind(bc["pos"]):
			continue
		if m.player and m.player.flat_dist(bc["pos"]) > 26.0 and float(bc["prog"]) <= 0.0:
			continue
		var bp := LabelCull.at(hud, bc["pos"] + Vector3(0, 3.2, 0))
		if not bp.is_finite():
			continue
		hud._ctext(bp, "Revive beacon" + ("  ·  contested" if bc["contested"] else ""), 12, Beacons.COL, hud.big)
		if float(bc["prog"]) > 0.0:
			hud._bar(Rect2(bp + Vector2(-40, 6), Vector2(80, 5)), float(bc["prog"]), Beacons.COL)

static func _box_label(hud, b: Dictionary, bp: Vector2) -> void:
	var m: Match = hud.m
	var o: Hunter = b["owner"]
	var col := Life.owner_col(m, b)
	var ally: bool = m.player != null and o.team == m.player.team
	if ally and o != m.player and Life.soul_here(m, b):
		var face := Rect2(bp - Vector2(PORTRAIT_PX * 0.5, PORTRAIT_PX + 14.0), Vector2(PORTRAIT_PX, PORTRAIT_PX))
		hud._draw_portrait(face, o, "dead", col)
		hud._ctext(bp, "%s  ·  %ds" % [o.pname, int(ceil(float(b["soul_until"]) - m.time))], 13, col, hud.big)
	elif not b["empty"] and m.player and m.player.flat_dist(b["pos"]) < 14.0:
		hud._ctext(bp, "%s's box" % o.pname if o != m.player else "Your box", 12, col, hud.big)

## Box revives in progress: a ring round the box and one round the reviver, with who and how far.
static func revive_rings(hud) -> void:
	var m: Match = hud.m
	for b in m.boxes:
		if m.time - float(b.get("rev_at", -9.0)) > 0.15 or m.cam.is_position_behind(b["pos"]):
			continue
		var prog := clampf(float(b.get("rev_prog", 0.0)), 0.0, 1.0)
		hud._ground_ring(b["pos"], 1.6, Color(GOOD, 0.3), 2.0)
		hud._ground_ring(b["pos"], 1.6, Color(GOOD, 0.95), 5.0, prog)
		var o: Hunter = b["owner"]
		var by = b.get("rev_by")
		var who := "Someone"
		if is_instance_valid(by):
			who = (by as Hunter).pname
			_head_ring(hud, by as Hunter, prog)
		var bp := m.cam.unproject_position(b["pos"] + Vector3(0, 2.0, 0))
		hud._ctext(bp, "%s bringing back %s  %d%%" % [who, o.pname, int(prog * 100.0)], 12, GOOD, hud.big)

static func _head_ring(hud, h: Hunter, prog: float) -> void:
	var m: Match = hud.m
	if m.cam.is_position_behind(h.pos):
		return
	var at := m.cam.unproject_position(h.pos + Vector3(0, HEAD_RING_UP, 0))
	var c: Control = hud.c
	c.draw_arc(at, HEAD_RING_PX + 2.5, 0, TAU, 40, Color(0, 0, 0, 0.5), 3.0, true)
	c.draw_arc(at, HEAD_RING_PX, 0, TAU, 40, Color(GOOD, 0.3), 3.0, true)
	c.draw_arc(at, HEAD_RING_PX, -PI * 0.5, -PI * 0.5 + TAU * prog, 40, GOOD, 4.0, true)

# ------------------------------------------------------------------ the maps
## Boxes and beacons on the minimap (inner: its rect; to_map: world -> map point; on_map: inside it).
static func minimap(hud, inner: Rect2, to_map: Callable, on_map: Callable) -> void:
	var m: Match = hud.m
	for bc in m.beacons:
		var pv: Vector2 = to_map.call(bc["pos"])
		if on_map.call(pv, 4.0):
			beacon_glyph(hud.c, pv, 4.5, bc, m.time)
		elif bc["lit"] and not bc["used"]:
			hud._edge_arrow(inner, inner.get_center(), pv, Beacons.COL)
	for b in _known_boxes(m):
		var pv: Vector2 = to_map.call(b["pos"])
		if on_map.call(pv, 3.0):
			box_glyph(hud.c, pv, 4.0, Life.owner_col(m, b), Life.soul_here(m, b))
		elif Life.soul_here(m, b) and _ally(m, b):
			hud._edge_arrow(inner, inner.get_center(), pv, Life.owner_col(m, b))

## Boxes and beacons on the full map (FullMap.draw).
static func full_map(fm) -> void:
	var m: Match = fm.m
	var area: Rect2 = fm.rect.grow(-4.0)
	for bc in m.beacons:
		var pv: Vector2 = fm.to_screen(bc["pos"])
		if area.has_point(pv):
			beacon_glyph(fm.hud.c, pv, 7.0, bc, m.time)
			if bc["lit"] and not bc["used"]:
				fm.hud._ctext(pv + Vector2(0, 22), "Lit", 12, Beacons.COL, fm.hud.big)
	for b in _known_boxes(m):
		var pv: Vector2 = fm.to_screen(b["pos"])
		if not area.has_point(pv):
			continue
		var col := Life.owner_col(m, b)
		box_glyph(fm.hud.c, pv, 6.0, col, Life.soul_here(m, b))
		if _ally(m, b):
			fm.hud._ctext(pv + Vector2(0, -11), (b["owner"] as Hunter).pname, 11, col, fm.hud.big)

## The boxes your squad knows about: all of its own, and rivals' within your sight.
static func _known_boxes(m: Match) -> Array:
	if m.player == null:
		return []
	var sight := m.view_range()
	return m.boxes.filter(func(b): return _ally(m, b) or (not b["empty"] and m.player.flat_dist(b["pos"]) < sight))

static func _ally(m: Match, b: Dictionary) -> bool:
	return m.player != null and (b["owner"] as Hunter).team == m.player.team

## A deathbox on a map: a little chest in its owner's colour, a bright rim while it can still be revived.
static func box_glyph(c: Control, pv: Vector2, s: float, col: Color, soul: bool) -> void:
	var body := Rect2(pv - Vector2(s, s * 0.7), Vector2(s * 2.0, s * 1.4))
	c.draw_rect(body.grow(1.5), Color(0, 0, 0, 0.7))
	c.draw_rect(body, col if soul else col.darkened(0.45))
	c.draw_line(pv + Vector2(-s, -s * 0.15), pv + Vector2(s, -s * 0.15), Color(0, 0, 0, 0.6), 1.0)
	if soul:
		c.draw_rect(body.grow(2.5), Color(1, 1, 1, 0.85), false, 1.0)

## A beacon on a map (or the legend, with an empty bc): a mint diamond, grey once used; lit, it pulses.
static func beacon_glyph(c: Control, pv: Vector2, s: float, bc: Dictionary, now: float) -> void:
	var col: Color = USED_COL if bc.get("used", false) else Beacons.COL
	if bc.get("lit", false) and not bc.get("used", false):
		var ph := fmod(now * 1.2, 1.0)
		c.draw_arc(pv, s + 2.0 + ph * s * 3.0, 0, TAU, 24, Color(col, 1.0 - ph), 2.0, true)
	var pts := PackedVector2Array([pv + Vector2(0, -s * 1.4), pv + Vector2(s, 0),
		pv + Vector2(0, s * 1.4), pv + Vector2(-s, 0)])
	var back := PackedVector2Array()
	for q in pts:
		back.append(pv + (q - pv) * 1.35)
	c.draw_colored_polygon(back, Color(0, 0, 0, 0.6))
	c.draw_colored_polygon(pts, col)
