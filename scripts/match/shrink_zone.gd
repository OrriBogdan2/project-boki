class_name ShrinkZone
extends RefCounted
## The closing zone (docs/decisions/0060-shrinking-zone.md, the 11-11 order). Each expedition picks
## its final area from the shared match seed, the way HotZone picks its region, so every player gets
## the same one: a dock or outpost, and the circle round it leaning into its island, so the last exits
## are inside. The playable circle closes toward it in phases (content/rules/shrink_zone.json): it
## holds for a phase's wait, then closes to the phase's radius, each circle inside the one before.
## Outside the edge hurts, more each phase; when the last close ends, the islands wholly outside the
## final circle fall. The fall at the end of the clock (Match._update_rules) stays.
## Shown on the drop/full map, the minimap, a row under the match clock, and in the world as a glowing
## wall; the kin warns before each close; bots keep inside (bot_goal). Nothing goes over Net: the
## circles come from the seed and the match clock alone, and each game hurts only its own bodies.

const RULES_PATH := "res://content/rules/shrink_zone.json"
const COL := Color("5cc8ff")               # the edge, on the maps and in the world
const NEXT_COL := Color(1, 1, 1, 0.8)      # the next circle
const OUT_SHADE := Color(0.3, 0.08, 0.4, 0.3)   # outside the edge on the full map
const SHADE_W := 1400.0                    # px of that shade past the edge (past the map at any zoom)
const MAP_SEGS := 96                       # segments of a circle on the maps
const WALL_H := 120.0                      # m, the wall in the world (its foot well under the islands)
const WALL_Y := -40.0                      # m, the wall's foot
const BAND_M := 3.0                        # m, the width of one glowing band on the wall
const WALL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.5, 0.83, 1.0, 1.0);
// bands: whole bands round the wall, so the seam doesn't show
uniform float bands = 200.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float a = atan(lp.z, lp.x);
	// 0 at the foot, 1 at the top (the mesh is 1 high)
	float up = lp.y + 0.5;
	float band = smoothstep(0.6, 1.0, 0.5 + 0.5 * sin(a * bands + up * 60.0 - TIME * 2.5));
	float fade = smoothstep(0.0, 0.25, up) * (1.0 - smoothstep(0.45, 1.0, up));
	ALBEDO = mix(col.rgb, vec3(1.0), band * 0.5);
	ALPHA = (0.32 + 0.43 * band) * fade * col.a;
}
"""

static var _rules := {}

var m: Match
var cs := PackedVector2Array()   # each circle's centre (x, z): [0] covers the map, the last is the final area
var rs := PackedFloat32Array()   # each circle's radius (m)
var t0 := PackedFloat32Array()   # match time circle k starts closing in (k >= 1)
var t1 := PackedFloat32Array()   # ... and is closed
var dps := PackedFloat32Array()  # share of max health a second outside, from circle k's close on
var exit_at := Vector2.ZERO      # the exit the final area is built round
var area_name := ""
var k := 0                       # closes begun so far (0 = none yet)
var cur_c := Vector2.ZERO        # the edge right now
var cur_r := 0.0
var fallen := false
var told := 0                    # the last close the feed and the kin warned of (the first-match guide reads it)
var _owed := {}                  # Hunter -> outside damage not landed yet
var _wall: MeshInstance3D = null
var _mat: ShaderMaterial = null

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## The zone for a real fixed-length expedition with a dock or outpost to close on; null otherwise
## (tutorial, training, duels, the arena, rolling sessions).
static func make(match_node: Match) -> ShrinkZone:
	var o := match_node.opts
	if not match_node.big or match_node.rolling:
		return null
	if ["tutorial", "training", "duel", "arena"].any(func(x): return o.get(x, false)):
		return null
	if not match_node.world.exit_defs.any(func(d): return String(d["kind"]) in ["dock", "outpost"]):
		return null
	return ShrinkZone.new(match_node)

func _init(match_node: Match) -> void:
	m = match_node
	var R := rules()
	var tk := m.length / float(R["length_ref"])
	var mk := float(m.world.w) / float(R["map_ref"])
	var ph: Array = R["phases"]
	var n := ph.size()
	for arr in [cs, rs, t0, t1, dps]:
		arr.resize(n + 1)
	var picks := m.world.exit_defs.filter(func(d): return String(d["kind"]) in ["dock", "outpost"])
	exit_at = picks[posmod(hash([m.seed_val, "shrink_zone"]), picks.size())]["at"]
	rs[n] = float(ph[n - 1]["r"]) * mk
	cs[n] = exit_at
	var ii := m.world.island_of(exit_at.x, exit_at.y)
	if ii >= 0:
		var I: Dictionary = m.world.islands[ii]
		area_name = String(I.get("name", ""))
		var inland: Vector2 = I.get("poi_at", I["c"])
		cs[n] = exit_at + (inland - exit_at).limit_length(rs[n] * float(R["final_lean"]))
	# back out from the final circle: each earlier one holds the next and leans toward the middle
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([m.seed_val, "shrink_zone_drift"])
	var mid := Vector2(m.world.w, m.world.h) * 0.5
	var drift: Array = R["drift"]
	for j in range(n - 1, 0, -1):
		rs[j] = float(ph[j - 1]["r"]) * mk
		var to_mid := mid - cs[j + 1]
		var room := (rs[j] - rs[j + 1]) * rng.randf_range(float(drift[0]), float(drift[1]))
		cs[j] = cs[j + 1] + to_mid.normalized().rotated(rng.randf_range(-0.5, 0.5)) * minf(room, to_mid.length())
	cs[0] = cs[1]
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(m.world.w, 0), Vector2(0, m.world.h), Vector2(m.world.w, m.world.h)]:
		far = maxf(far, cs[1].distance_to(corner))
	rs[0] = far + float(R["start_pad"])
	var t := 0.0
	for j in range(1, n + 1):
		t += float(ph[j - 1]["wait"]) * tk
		t0[j] = t
		t += float(ph[j - 1]["shrink"]) * tk
		t1[j] = t
		dps[j] = float(ph[j - 1]["dps"])
	cur_c = cs[0]
	cur_r = rs[0]
	_build_wall()

func last() -> int:
	return cs.size() - 1

## The edge at match time t: [centre, radius].
func edge_at(t: float) -> Array:
	var j := 0
	while j < last() and t >= t0[j + 1]:
		j += 1
	if j == 0 or t >= t1[j]:
		return [cs[j], rs[j]]
	var f := (t - t0[j]) / maxf(0.01, t1[j] - t0[j])
	return [cs[j - 1].lerp(cs[j], f), lerpf(rs[j - 1], rs[j], f)]

func outside(p: Vector3) -> bool:
	return Vector2(p.x, p.z).distance_to(cur_c) > cur_r

## When the closing edge has passed p for good (1e9: p is in the final area).
func out_at(p: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	for j in range(1, last() + 1):
		if q.distance_to(cs[j]) > rs[j]:
			return t1[j]
	return 1e9

## The docks close as the edge passes them (Exits.setup); the one nearest the final area is the last.
func time_docks(docks: Array) -> void:
	var best := -1
	var bd := 1e9
	for i in docks.size():
		docks[i]["close_at"] = out_at(docks[i]["pos"])
		var d := cs[last()].distance_to(Vector2(docks[i]["pos"].x, docks[i]["pos"].z))
		if d < bd:
			bd = d
			best = i
	if best >= 0 and float(docks[best]["close_at"]) >= 1e8:
		docks[best]["last"] = true

func tick(dt: float) -> void:
	var e := edge_at(m.time)
	cur_c = e[0]
	cur_r = e[1]
	while k < last() and m.time >= t0[k + 1]:
		k += 1
	_warn()
	if k > 0:
		_hurt_outside(dt)
	if not fallen and m.time >= t1[last()]:
		_fall()
	if _wall:
		_wall.position = Vector3(cur_c.x, WALL_Y + WALL_H * 0.5, cur_c.y)
		_wall.scale = Vector3(cur_r, WALL_H, cur_r)
		_mat.set_shader_parameter("bands", maxf(1.0, round(TAU * cur_r / BAND_M)))

func _warn() -> void:
	var nx := k + 1
	if nx > last() or told >= nx or t0[nx] - m.time > float(rules()["warn_s"]):
		return
	told = nx
	var secs := int(ceil(t0[nx] - m.time))
	var tail := ": the islands outside the last circle will fall!" if nx == last() else ". Get inside the ring!"
	m.add_feed("The zone closes in %d s%s" % [secs, tail])
	if m.player and m.player.kin: BokiChatter.say(m, m.player.kin, "zone")
	if m.hud: m.hud.toast_small("ZONE CLOSES IN %d s" % secs, COL)
	m.sfx("warn", null, 0.0)

## Outside the edge: a share of max health a second, landing in ticks (no armor, no glider drain).
func _hurt_outside(dt: float) -> void:
	var R := rules()
	for h in m.hunters:
		if h.out or h.extracted or h.remote or h.riding or h.dropping or h.downed or not outside(h.pos):
			_owed.erase(h)
			continue
		var owed: float = float(_owed.get(h, 0.0)) + dps[k] * h.max_hp * dt
		if owed >= dps[k] * h.max_hp * float(R["tick_s"]):
			h.hurt(owed, null, {"src": "zone"})
			owed = 0.0
		_owed[h] = owed

## The last close is done: the islands with no ground in the final circle fall, with whoever is on them.
func _fall() -> void:
	fallen = true
	var fc := cs[last()]
	var gone := {}
	for ii in m.world.islands.size():
		var keep := false
		for cell in m.world.islands[ii]["cells"]:
			if fc.distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= rs[last()]:
				keep = true
				break
		if not keep: gone[ii] = true
	m.add_feed("The islands outside the last circle are falling!")
	for h in m.hunters:
		if not (h.out or h.extracted or h.remote) and gone.has(m.world.island_of(h.pos.x, h.pos.z)):
			m.eliminate(h, null, "abyss", true)

## Where a bot should be heading: its own goal while that and the bot are inside the circle that
## counts (the next one once its close is near), else a spot on solid ground inside it.
func bot_goal(h: Hunter, goal: Vector3) -> Vector3:
	var c := cur_c
	var r := cur_r
	if k < last() and t0[k + 1] - m.time < float(rules()["bot_lead_s"]):
		c = cs[k + 1]
		r = rs[k + 1]
	var here := Vector2(h.pos.x, h.pos.z)
	if here.distance_to(c) < r * 0.85 and (goal == Vector3.INF or Vector2(goal.x, goal.z).distance_to(c) < r * 0.85):
		return goal
	var key := Vector3(c.x, r, c.y)
	# Bot._choose gave up on the spot we gave it (no way there): pick another
	var gave_up := float(h.ai.get("banned", {}).get(h.ai.get("zone_at"), -1.0)) > m.time
	if h.ai.get("zone_key", Vector3.INF) != key or gave_up:
		h.ai["zone_key"] = key
		var p := c + (here - c).limit_length(r * 0.5)
		if gave_up:
			p = c + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * r * 0.45
		var spot := m.world.free_spot_near(Vector3(p.x, 0, p.y), [], 1.0, 0.45, 16.0)
		if spot == Vector3.INF:
			spot = m.world.free_spot_near(Vector3(c.x, 0, c.y), [], 1.0, 0.45, r * 0.7)
		h.ai["zone_at"] = spot
	return h.ai["zone_at"]

func _build_wall() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 192
	cm.rings = 1
	var sh := Shader.new()
	sh.code = WALL_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("col", COL)
	_wall = MeshInstance3D.new()
	_wall.name = "ZoneWall"
	_wall.mesh = cm
	_wall.material_override = _mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(_wall)

func _secs_text() -> String:
	if k < last() and m.time < t0[k + 1]:
		return "ZONE CLOSES  %s" % m.hud._fmt(t0[k + 1] - m.time)
	if k > 0 and m.time < t1[k]:
		return "ZONE CLOSING  %s" % m.hud._fmt(t1[k] - m.time)
	return "FINAL ZONE"

## The row under the match clock: the next close, and a warning while you're outside. Its bottom.
func hud_row(hud, r: Rect2) -> float:
	hud._rounded(r, Color(0.04, 0.05, 0.08, 0.7), 6)
	hud.c.draw_circle(r.position + Vector2(11, 10), 4.0, COL)
	hud._text(r.position + Vector2(21, 14), _secs_text(), 10, COL, hud.big)
	if m.player and not m.player.out and k > 0 and outside(m.player.pos):
		var t := "OUTSIDE  -%d%%/s" % int(round(dps[k] * 100.0))
		var a := 0.6 + 0.4 * sin(m.time * 8.0)
		var tw: float = hud.big.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		hud._text(Vector2(r.end.x - 8 - tw, r.position.y + 14), t, 10, Color(hud.BAD, a), hud.big)
	return r.end.y

## The edge and the next circle on the minimap (only the parts in view).
func minimap(hud, to_map: Callable, on_map: Callable) -> void:
	_ring(hud, to_map, on_map, cur_c, cur_r, COL, 2.0)
	if k < last():
		_ring(hud, to_map, on_map, cs[k + 1], rs[k + 1], NEXT_COL, 1.0)

func _ring(hud, to_map: Callable, on_map: Callable, c: Vector2, r: float, col: Color, wdt: float) -> void:
	var prev := Vector2.ZERO
	var prev_in := false
	for i in MAP_SEGS + 1:
		var a := TAU * i / MAP_SEGS
		var p: Vector2 = to_map.call(Vector3(c.x + cos(a) * r, 0, c.y + sin(a) * r))
		var now_in: bool = on_map.call(p, 0.0)
		if now_in and prev_in:
			hud.c.draw_line(prev, p, col, wdt, true)
		prev = p
		prev_in = now_in

## On the drop map / full map (FullMap.draw): shade outside the edge, the edge, the next circle, the time.
func full_map(fm, kk: float) -> void:
	var cv: CanvasItem = fm.hud.c
	var pv: Vector2 = fm.to_screen(Vector3(cur_c.x, 0, cur_c.y))
	cv.draw_arc(pv, cur_r * kk + SHADE_W * 0.5, 0.0, TAU, MAP_SEGS, OUT_SHADE, SHADE_W)
	cv.draw_arc(pv, cur_r * kk, 0.0, TAU, MAP_SEGS, COL, 3.0, true)
	if k < last():
		var nv: Vector2 = fm.to_screen(Vector3(cs[k + 1].x, 0, cs[k + 1].y))
		cv.draw_arc(nv, rs[k + 1] * kk, 0.0, TAU, MAP_SEGS, NEXT_COL, 2.0, true)
	var top := Vector2(pv.x, maxf(pv.y - cur_r * kk - 10.0, fm.rect.position.y + 24.0))
	fm.hud._ctext(top, _secs_text(), 13, COL, fm.hud.big)
