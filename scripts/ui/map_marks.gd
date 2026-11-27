class_name MapMarks
extends RefCounted
## The things you walk up to (monster camps, shops, chests, shrines, jump pads), drawn the same way everywhere:
## one badge on the minimap and the full map, and on the ground near you a ring and a short name. A thing's
## colour is its category: enemy red, loot gold, travel cyan, objective white (also the key's swatches).
## The Boki nest, boss lairs, exits, beacons and the Ways Out have their own marks (NestMap, ExitMark, ...) in the
## same four colours. tools/minimap_check.gd asserts the registry, the colours and the key.

const ENEMY := Color("ff5a4a")
const LOOT := Color("f2c84a")
const TRAVEL := Color("45d3e8")
const OBJECTIVE := Color("f2f4ff")
const MAP_NEAR_M := 45.0  # m: a thing this close is on the minimap without Tab (MapDetail "thing")
const ZOOMED_K := 1.45  # the full map zoomed this far past fit shows the chests (as FullMap shows small names)
const NEAR_M := 16.0  # m: inside this a thing gets its ground ring and name
const FADE_M := 6.0  # m: the ring and name fade out over the last FADE_M of NEAR_M
const RING_PTS := 20
const RING_R := {"camp": 5.0, "shop": 2.2, "chest": 1.7, "shrine": 1.9, "pad": 1.6}
const WORDS := {"camp": "Monster camp", "chest": "Chest", "shrine": "Shrine: a power-up", "pad": "Jump pad"}
const CAT := {"camp": ENEMY, "shop": LOOT, "chest": LOOT, "shrine": OBJECTIVE, "pad": TRAVEL}
const NAMELESS := ["shop", "pad"]  # they carry their own name in the world
const HUNTER_CLEAR_PX := 70.0  # px: a name never sits within this of the hunter
const NAME_PX := 13

static var _rows: Array = []  # {id, pos, src}: rebuilt when the match, or what it holds, changes
static var _owner := 0
static var _ring := PackedVector2Array()


## Every camp, shop, chest, shrine and pad of the match: {id, pos: Vector3, src: Dictionary, name: String}.
static func rows(m: Match) -> Array:
	var count: int = (
		m.camps.list.size() + Shops.list(m).size() + m.chests.size() + m.shrines.size() + m.world.pads.size()
	)
	if _owner != m.get_instance_id() or _rows.size() != count:
		_owner = m.get_instance_id()
		_rows.clear()
		for cp in m.camps.list:
			_rows.append({"id": "camp", "pos": cp["pos"], "src": cp, "name": WORDS["camp"]})
		for v in Shops.list(m):
			_rows.append({"id": "shop", "pos": v["pos"], "src": v, "name": ShopStock.theme(String(v["theme"]))["name"]})
		for ch in m.chests:
			_rows.append({"id": "chest", "pos": ch["pos"], "src": ch, "name": WORDS["chest"]})
		for sh in m.shrines:
			_rows.append({"id": "shrine", "pos": sh["pos"], "src": sh, "name": WORDS["shrine"]})
		for pd in m.world.pads:
			_rows.append({"id": "pad", "pos": pd["pos"], "src": pd, "name": WORDS["pad"]})
	return _rows


## The first live thing of this kind, or {} (the key draws its icon from it).
static func first(m: Match, id: String) -> Dictionary:
	for row in rows(m):
		if row["id"] == id and live(m, row):
			return row
	return {}


## Is it still worth a mark: a camp not cleared, a chest not opened, a shrine not used.
static func live(m: Match, row: Dictionary) -> bool:
	var src: Dictionary = row["src"]
	match String(row["id"]):
		"camp":
			return not m.camps.cleared(m.camps.list.find(src))
		"chest":
			return not src.get("open", false)
		"shrine":
			return not src.get("used", false)
	return true


## One icon per kind, at `at` with half-size `s`, in `col`.
static func glyph(hud, id: String, at: Vector2, s: float, col: Color, src: Dictionary) -> void:
	match id:
		"camp":
			Icons.draw(hud.c, "cleave", at, s, col)
		"shop":
			Icons.draw(hud.c, String(ShopStock.theme(String(src["theme"]))["icon"]), at, s, col)
		"chest":
			hud.full_map.icon(hud.c, "vault", at, s, col)
		"shrine":
			hud.full_map.shrine_glyph(hud.c, at, s * 0.8)
		"pad":
			Icons.draw(hud.c, "jump", at, s, col)


## The badge on a map: a dark disc, a ring in the category colour, the icon.
static func badge(hud, id: String, pv: Vector2, s: float, src: Dictionary) -> void:
	var col: Color = CAT[id]
	hud.c.draw_circle(pv, s * 1.35, Color(0.04, 0.05, 0.09, 0.9))
	hud.c.draw_arc(pv, s * 1.35, 0.0, TAU, 24, col, 2.0, true)
	glyph(hud, id, pv, s * 0.8, col, src)


## The minimap: the live things near you, all of them while Tab or the map key is held (MapDetail).
static func minimap(hud, to_map: Callable, on_map: Callable, hold: bool) -> void:
	var m: Match = hud.m
	for row in rows(m):
		if not live(m, row) or not MapDetail.shows("thing", hold, m.player.flat_dist(row["pos"]) < MAP_NEAR_M):
			continue
		var pv: Vector2 = to_map.call(row["pos"])
		if on_map.call(pv, MapDetail.ICON_R):
			badge(hud, String(row["id"]), pv, MapDetail.ICON_R / 1.35, row["src"])


## The full map: the same badges, a little bigger. A map holds dozens of chests, so they show only zoomed in.
static func full_map(fm: FullMap) -> void:
	var m: Match = fm.m
	var s := clampf(4.0 + fm.k() * 0.5, 5.5, 9.0)
	var zoomed: bool = fm.k() >= ZOOMED_K * fm.rect.size.x / m.world.w
	for row in rows(m):
		if not live(m, row) or (row["id"] == "chest" and not zoomed):
			continue
		var pv := fm.to_screen(row["pos"])
		if fm.rect.grow(-s).has_point(pv):
			badge(fm.hud, String(row["id"]), pv, s, row["src"])


## In the world, within NEAR_M of the hunter: a ground ring in the category colour and the thing's name over it
## (shops and pads already carry their own sign, and a name skips the hunter's own spot on the screen).
static func world(hud) -> void:
	var m: Match = hud.m
	var p: Hunter = m.player
	if p == null or p.out or p.extracted:
		return
	var cam := m.cam
	var me := cam.unproject_position(p.pos)
	for row in rows(m):
		var at: Vector3 = row["pos"]
		var d := p.flat_dist(at)
		if d > NEAR_M or cam.is_position_behind(at) or not live(m, row):
			continue
		var id := String(row["id"])
		var col := Color(CAT[id], clampf((NEAR_M - d) / FADE_M, 0.0, 1.0) * 0.9)
		_ring_at(hud, cam, at, RING_R[id], col)
		var lp := cam.unproject_position(at + Vector3(0, 2.6, 0))
		if not id in NAMELESS and lp.distance_to(me) > HUNTER_CLEAR_PX:
			var w := TextCache.width(hud.big, String(row["name"]), NAME_PX)
			hud._rounded(
				Rect2(lp + Vector2(-w * 0.5 - 6.0, -NAME_PX), Vector2(w + 12.0, NAME_PX + 8.0)),
				Color(0.04, 0.05, 0.08, 0.7 * col.a),
				6
			)
			hud._ctext(lp, String(row["name"]), NAME_PX, col, hud.big)


static func _ring_at(hud, cam: Camera3D, at: Vector3, r: float, col: Color) -> void:
	if _ring.size() != RING_PTS + 1:
		_ring.resize(RING_PTS + 1)
	for i in RING_PTS + 1:
		var a := TAU * i / RING_PTS
		_ring[i] = cam.unproject_position(at + Vector3(cos(a) * r, 0.08, sin(a) * r))
	hud.c.draw_polyline(_ring, col, 2.5, true)
