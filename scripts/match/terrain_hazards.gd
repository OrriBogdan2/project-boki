class_name TerrainHazards
extends RefCounted
## Terrain hazard areas on an authored map (docs/decisions/0060-terrain-hazards.md): lava fields, deep
## water, ice sheets, static flats and bramble, each an outline in the map's islands[].hazard_areas.
## What the ground does and which Boki walks it safely is content/rules/terrain_hazards.json.
##
## The outlines are rasterized once into a per-tile lookup (tile -> area + 1), so "what's underfoot"
## is one array read; the surface is one quad per area drawn from a small distance field (smooth edge,
## no per-frame work but the static flats' charge). BiomeRun owns it (place_hazards, tick).
## Effects only touch bodies this game owns (never a remote one), like the biome traps.

const PATH := "res://content/rules/terrain_hazards.json"
const SDF_PX := 2.0          # distance-field texels per metre of an area's surface
const SDF_PAD := 1.0         # m of margin round an outline in its surface quad (the soft edge)
const SDF_BAND := 3.5        # m: how deep inside an edge the shader still shades (terrain_hazard.gdshader's `deep`)
const STAND_Y := 0.35        # m: this close to the area's ground you're in it (a jump or a glide clears it)
const TICK_S := 0.5          # s between drowning or scratch hits
const FX_S := 0.35           # s between splashes or sparks at the feet of someone moving through
const HINT_DIRS := 8         # directions the Boki looks for a hazard nearby

static var _rules := {}

var m: Match
var w: World
var areas: Array = []                 # {kind, def, y, box, centre, cells: Array[Vector2i], mat, t, phase}
var cell := PackedInt32Array()        # per tile: area index + 1, 0 = no hazard
var state := {}                       # hunter instance id -> {area, safe, breath, tick, fx}
var hint_t := 0.0
var hinted := {}                      # kind -> m.time the player's Boki last spoke of it
var ahead := {}                       # underfoot()'s reading for a hazard the player is next to and immune to
var audio: HazardSfx                  # the beds and cues (content/sfx/hazards.json)

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_rules = parsed if parsed is Dictionary else {"hint": {}, "kinds": {}}
	return _rules

static func kind_def(kind: String) -> Dictionary:
	return rules()["kinds"].get(kind, {})

## This match's hazards (null off an authored map).
static func of(mm: Node) -> TerrainHazards:
	if mm is Match and (mm as Match).biomes:
		return (mm as Match).biomes.terrain
	return null

func _init(match_node: Match) -> void:
	m = match_node
	w = m.world
	cell.resize(w.w * w.h)
	cell.fill(0)
	for D in World.load_layout(w.layout_id).get("islands", []):
		for A in D.get("hazard_areas", []):
			_add_area(A)
	audio = HazardSfx.new(self)

# ------------------------------------------------------------------ the areas
## One area: its outline, minus its "safe" shapes (paths, fords, islets: circles or polygons that stay
## walkable ground inside a big field).
func _add_area(A: Dictionary) -> void:
	var kind := String(A["kind"])
	var def := kind_def(kind)
	if def.is_empty():
		push_warning("TerrainHazards: unknown hazard kind '%s'" % kind)
		return
	var poly := PackedVector2Array()
	for p in A["poly"]:
		poly.append(Vector2(float(p[0]), float(p[1])))
	var safe := safe_shapes(A.get("safe", []))
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var ai := areas.size()
	var cells: Array[Vector2i] = []
	var sum := Vector2.ZERO
	for z in range(int(box.position.y), int(box.end.y) + 1):
		for x in range(int(box.position.x), int(box.end.x) + 1):
			var at := Vector2(x + 0.5, z + 0.5)
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND or not Geometry2D.is_point_in_polygon(at, poly):
				continue
			if on_safe(safe, at):
				continue
			cell[w.idx(x, z)] = ai + 1
			cells.append(Vector2i(x, z))
			sum += at
	if cells.is_empty():
		return
	var mean := sum / cells.size()
	var mid := cells[0]
	var mean_tile := mean - Vector2(0.5, 0.5)
	for c in cells:
		if Vector2(c).distance_squared_to(mean_tile) < Vector2(mid).distance_squared_to(mean_tile):
			mid = c
	var y := w.ground_at(cells[0].x + 0.5, cells[0].y + 0.5)
	var centre := Vector3(mid.x + 0.5, y, mid.y + 0.5)
	var A2 := {"kind": kind, "def": def, "y": y, "box": box, "centre": centre, "cells": cells,
		"t": float(def["effect"].get("every_s", 0.0)), "phase": "idle"}
	A2["mat"] = _surface(poly, safe, box.grow(SDF_PAD), y, def["look"])
	if kind == "bramble":
		_thorns(cells, y)
	areas.append(A2)

## The safe shapes as {c, r} circles or {poly, box} polygons.
static func safe_shapes(list: Array) -> Array:
	var out: Array = []
	for S in list:
		if S.has("circle"):
			out.append({"c": Vector2(float(S["circle"][0]), float(S["circle"][1])), "r": float(S["r"])})
			continue
		var pts := PackedVector2Array()
		for p in S["poly"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		var box := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			box = box.expand(p)
		out.append({"poly": pts, "box": box})
	return out

static func on_safe(safe: Array, p: Vector2) -> bool:
	for S in safe:
		if S.has("c"):
			if p.distance_squared_to(S["c"]) < float(S["r"]) * float(S["r"]):
				return true
		elif (S["box"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, S["poly"]):
			return true
	return false

## How far inside a safe shape p is (metres; negative outside it).
static func _safe_depth(S: Dictionary, p: Vector2) -> float:
	if S.has("c"):
		return float(S["r"]) - p.distance_to(S["c"])
	var pts: PackedVector2Array = S["poly"]
	var d := INF
	for k in pts.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[(k + 1) % pts.size()])))
	return d if Geometry2D.is_point_in_polygon(p, pts) else -d

## The area's surface: one flat quad over its box; the shader cuts the outline out of a distance field
## (metres inside: the outline's, but never deeper than the nearest safe shape's edge).
func _surface(poly: PackedVector2Array, safe: Array, box: Rect2, y: float, look: Dictionary) -> ShaderMaterial:
	var iw := maxi(2, int(ceil(box.size.x * SDF_PX)))
	var ih := maxi(2, int(ceil(box.size.y * SDF_PX)))
	var img := Image.create(iw, ih, false, Image.FORMAT_RF)
	for j in ih:
		for i in iw:
			var p := box.position + Vector2((i + 0.5) / SDF_PX, (j + 0.5) / SDF_PX)
			var d := INF
			for k in poly.size():
				var q := Geometry2D.get_closest_point_to_segment(p, poly[k], poly[(k + 1) % poly.size()])
				d = minf(d, p.distance_to(q))
			img.set_pixel(i, j, Color(d if Geometry2D.is_point_in_polygon(p, poly) else -d, 0, 0))
	for S in safe:
		_carve(img, box, S)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain_hazard.gdshader")
	mat.set_shader_parameter("sdf", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("origin", box.position)
	mat.set_shader_parameter("size", box.size)
	mat.set_shader_parameter("mode", int(look["mode"]))
	for k in ["deep", "shallow", "edge"]:
		mat.set_shader_parameter("col_" + k, Color(String(look[k])))
	mat.set_shader_parameter("glow", float(look["glow"]))
	mat.set_shader_parameter("alpha", float(look["alpha"]))
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = box.size
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	mi.global_position = Vector3(box.get_center().x, y + 0.05, box.get_center().y)
	return mat

## Cuts a safe shape out of the distance field, over the texels within the shader's soft band of it.
func _carve(img: Image, box: Rect2, S: Dictionary) -> void:
	var reach: Rect2 = S["box"] if S.has("box") else Rect2(S["c"] - Vector2.ONE * S["r"], Vector2.ONE * S["r"] * 2.0)
	reach = reach.grow(SDF_BAND)
	var i0 := maxi(0, int((reach.position.x - box.position.x) * SDF_PX))
	var i1 := mini(img.get_width() - 1, int((reach.end.x - box.position.x) * SDF_PX))
	var j0 := maxi(0, int((reach.position.y - box.position.y) * SDF_PX))
	var j1 := mini(img.get_height() - 1, int((reach.end.y - box.position.y) * SDF_PX))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := box.position + Vector2((i + 0.5) / SDF_PX, (j + 0.5) / SDF_PX)
			img.set_pixel(i, j, Color(minf(img.get_pixel(i, j).r, -_safe_depth(S, p)), 0, 0))

## Bramble stands up out of the ground: a thorn tuft on every other tile, one draw call per area.
func _thorns(cells: Array[Vector2i], y: float) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = cells[0].x * 7919 + cells[0].y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.cyl(0.0, 0.07, 0.6, 5)
	mm.instance_count = cells.size() * 2
	for i in mm.instance_count:
		var c: Vector2i = cells[i / 2]
		var b := Basis.from_euler(Vector3(rr.randf_range(-0.6, 0.6), rr.randf() * TAU, rr.randf_range(-0.6, 0.6)))
		var at := Vector3(c.x + rr.randf(), y + 0.2, c.y + rr.randf())
		mm.set_instance_transform(i, Transform3D(b.scaled(Vector3.ONE * rr.randf_range(0.7, 1.4)), at))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Models.toon(Color("5a4628"), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)

# ------------------------------------------------------------------ lookups
## The area index at p (standing on its ground), or -1.
func area_at(p: Vector3) -> int:
	var x := int(floor(p.x))
	var z := int(floor(p.z))
	if not w.inb(x, z):
		return -1
	var a := cell[w.idx(x, z)] - 1
	if a < 0 or absf(p.y - float(areas[a]["y"])) > STAND_Y:
		return -1
	return a

## How well h is protected from this kind of ground: the best single source, never added up
## (content/rules/terrain_hazards.json "ward"). Sources: the ward perk for the kind, or the Boki that is
## out with a counter type or species (a downed or carried one counts for nothing).
static func shield(h, kind: String) -> float:
	if not h is Hunter:
		return 0.0
	var S: Dictionary = rules()["ward"]["strength"]
	var best := 0.0
	if ward_held(h, kind) != "":
		best = float(S["perk"])
	if _boki_guards(h, kind):
		best = maxf(best, float(S["boki"]))
	return best

## Does h walk this kind of ground safely (a full shield)?
static func guards(h, kind: String) -> bool:
	return shield(h, kind) >= 1.0

## The ward perk h holds against this kind of ground (Data.PERKS ward), or "".
static func ward_held(h: Hunter, kind: String) -> String:
	for id in h.perks:
		if String(Data.PERKS[id].get("ward", "")) == kind:
			return String(id)
	return ""

## The ward perk for this kind of ground, or "" (none sold or dropped for it).
static func ward_for(kind: String) -> String:
	for id in Data.PERKS:
		if String(Data.PERKS[id].get("ward", "")) == kind:
			return String(id)
	return ""

static func _boki_guards(h: Hunter, kind: String) -> bool:
	var k := h.kin as Kin
	if k == null or k.state == "downed":
		return false
	var C: Dictionary = kind_def(kind).get("counter", {})
	return String(k.sp.get("theme", "")) in C.get("themes", []) or k.species in C.get("kin", [])

## Who keeps h safe here, for the HUD: the Boki's name, else the perk's; "" when nothing does.
func protector(h: Hunter, kind: String) -> String:
	if _boki_guards(h, kind):
		var k := h.kin as Kin
		return String(k.rec.get("name", k.sp.get("name", "Your Boki")))
	var pk := ward_held(h, kind)
	return String(Data.PERKS[pk]["name"]) if pk != "" else ""

## Footing at p for h: low on an ice sheet unless its Boki is a frost one.
func grip(p: Vector3, h: Hunter) -> float:
	var a := area_at(p)
	if a < 0 or areas[a]["kind"] != "ice" or (h != null and guards(h, "ice")):
		return 1.0
	return float(areas[a]["def"]["effect"]["grip"])

## A bot keeps off hazard ground its Boki can't handle (unless it's already in it: then out is the way).
static func avoid(mm: Node, h: Hunter, x: float, z: float) -> bool:
	var tz := of(mm)
	if tz == null or h.remote:
		return false
	var xi := int(floor(x))
	var zi := int(floor(z))
	if not tz.w.inb(xi, zi):
		return false
	var a := tz.cell[tz.w.idx(xi, zi)] - 1
	return a >= 0 and tz.area_at(h.pos) < 0 and not tz.guards(h, String(tz.areas[a]["kind"]))

## The ward perk for the hazard nearest p, if one lies within `near_m` of it ("" otherwise): loot
## dropped by a lava field leans to Emberwalk (PerkOrbs).
static func perk_near(mm: Node, p: Vector3, near_m: float) -> String:
	var tz := of(mm)
	if tz == null:
		return ""
	var best := ""
	var best_d := near_m
	for A in tz.areas:
		var ward := ward_for(String(A["kind"]))
		var box: Rect2 = A["box"]
		var off := Vector2(box.position.x - p.x, box.position.y - p.z).max(Vector2(p.x - box.end.x, p.z - box.end.y))
		var d := off.max(Vector2.ZERO).length()
		if ward != "" and d < best_d:
			best = ward
			best_d = d
	return best

## Hits from a hunter wading in deep water without a swimmer are weaker.
static func hit_mult(mm: Node, by: Ent) -> float:
	var tz := of(mm)
	if tz == null or not by is Hunter:
		return 1.0
	var st: Dictionary = tz.state.get(by.get_instance_id(), {})
	return float(st.get("weak", 1.0))

## What the player is standing in, for the HUD: {} or {name, col, safe, hurts, by (who keeps them safe),
## breath (0..1, -1 when none)}. Next to a hazard they're immune to it's the same, so the HUD says so.
func underfoot(h: Hunter) -> Dictionary:
	var st: Dictionary = state.get(h.get_instance_id(), {})
	var ai := int(st.get("area", -1))
	if ai < 0:
		return ahead
	var E: Dictionary = areas[ai]["def"]["effect"]
	var breath := clampf(float(st["breath"]) / float(E["breath_s"]), 0.0, 1.0) if E.has("breath_s") else -1.0
	return _reading(h, String(areas[ai]["kind"]), breath)

func _reading(h: Hunter, kind: String, breath: float) -> Dictionary:
	var def := kind_def(kind)
	var by := protector(h, kind)
	return {"name": String(def["name"]), "col": Color(String(def["look"]["edge"])), "safe": by != "",
		"hurts": String(def["hurts"]), "by": by, "breath": breath}

# ------------------------------------------------------------------ every frame
func tick(dt: float) -> void:
	if areas.is_empty():
		return
	for ai in areas.size():
		if areas[ai]["kind"] == "static":
			_tick_static(ai, dt)
	for h in m.hunters:
		_tick_hunter(h, dt)
	audio.tick(dt)
	hint_t -= dt
	if hint_t <= 0.0:
		hint_t = float(rules()["hint"]["every_s"])
		_hint()

func _tick_hunter(h: Hunter, dt: float) -> void:
	if h.remote or h.out or h.dead:
		return
	var id := h.get_instance_id()
	var a := area_at(h.pos)
	if a < 0:
		if state.has(id):
			_recover(id, dt)
		return
	var A: Dictionary = areas[a]
	var kind := String(A["kind"])
	var E: Dictionary = A["def"]["effect"]
	var st: Dictionary = state.get(id, {})
	if st.is_empty():
		st = {"area": -1, "breath": float(E.get("breath_s", 0.0)), "tick": TICK_S, "fx": 0.0, "weak": 1.0}
		state[id] = st
	var safe := guards(h, kind)
	var entered := int(st["area"]) != a
	if entered or bool(st.get("safe", false)) != safe:
		st["area"] = a
		st["safe"] = safe
		if safe: _protect_fx(h, kind)
	st["weak"] = float(E.get("dmg_out", 1.0)) if not safe else 1.0
	match kind:
		"lava":
			if not safe:
				if h.burn_t <= 0.0 or h.burn_dps < float(E["burn_dps"]) * _tier():
					h.burn_dps = float(E["burn_dps"]) * _tier()
				h.burn_t = maxf(h.burn_t, float(E["burn_linger_s"]))
		"deep_water":
			if safe:
				if E.get("swim_haste", false): h.haste_t = maxf(h.haste_t, 0.2)
			else:
				_slow(h, 1.0 - float(E["speed"]))
				st["breath"] = float(st["breath"]) - dt
				if float(st["breath"]) <= 0.0 and _every(st, dt):
					h.hurt(float(E["drown_dps"]) * TICK_S * _tier(), null, {"src": "hazard", "tags": ["hazard"]})
		"bramble":
			if not safe:
				_slow(h, 1.0 - float(E["speed"]))
				if _every(st, dt):
					h.hurt(float(E["dps"]) * TICK_S * _tier(), null, {"src": "hazard", "tags": ["hazard"]})
	_feet_fx(h, st, kind, dt)
	audio.contact(h, kind, safe, st, entered, dt)

## Out of the hazard: breath comes back twice as fast as it went; the state goes once it's full.
func _recover(id: int, dt: float) -> void:
	var st: Dictionary = state[id]
	st["area"] = -1
	st["weak"] = 1.0
	var full := float(kind_def("deep_water")["effect"]["breath_s"])
	st["breath"] = minf(full, float(st["breath"]) + dt * 2.0)
	if float(st["breath"]) >= full:
		state.erase(id)

func _every(st: Dictionary, dt: float) -> bool:
	st["tick"] = float(st["tick"]) - dt
	if float(st["tick"]) > 0.0:
		return false
	st["tick"] = TICK_S
	return true

## Hazard damage grows with the tier, as the biome traps' does.
func _tier() -> float:
	return float(m.T.get("mob", 1.0))

func _slow(h: Hunter, k: float) -> void:
	h.slow_t = maxf(h.slow_t, 0.15)
	h.slow_k = maxf(h.slow_k, k)

## The static flats charge up (the ground's veins brighten) and then shock everyone standing on them.
func _tick_static(ai: int, dt: float) -> void:
	var A: Dictionary = areas[ai]
	var E: Dictionary = A["def"]["effect"]
	var mat: ShaderMaterial = A["mat"]
	A["t"] = float(A["t"]) - dt
	if A["phase"] == "idle" and float(A["t"]) <= float(E["warn_s"]):
		A["phase"] = "warn"
		m.sfx("warn", A["centre"], -14.0, 1.6)
	if A["phase"] == "warn":
		mat.set_shader_parameter("charge", clampf(1.0 - float(A["t"]) / float(E["warn_s"]), 0.0, 1.0))
	if float(A["t"]) > 0.0:
		return
	A["t"] = float(E["every_s"])
	A["phase"] = "idle"
	mat.set_shader_parameter("charge", 0.0)
	var cells: Array[Vector2i] = A["cells"]
	for i in 3:
		var c: Vector2i = cells[m.rng.randi_range(0, cells.size() - 1)]
		m.fx.burst(Vector3(c.x + 0.5, float(A["y"]) + 0.2, c.y + 0.5), Color("fff27a"), 10, 5.0, 0.3, 2.0)
	m.sfx("zap", A["centre"], -6.0, 1.2)
	for h in m.hunters:
		if h.remote or h.out or h.dead or area_at(h.pos) != ai:
			continue
		if guards(h, "static"):
			_protect_fx(h, "static")
		else:
			m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("fff9c0"), 16, 5.0, 0.3, 1.0)
			h.hurt(float(E["dmg"]) * _tier(), null, {"src": "hazard", "tags": ["hazard"], "stun": float(E["stun_s"])})
			audio.shock(h)

# ------------------------------------------------------------------ feedback
## The Boki keeps you safe here: a burst in its colour at your feet (and, the first time, a cue for the player).
func _protect_fx(h: Hunter, kind: String) -> void:
	var k := h.kin as Kin
	var col: Color = k.sp.get("glow", Color.WHITE) if k else Color.WHITE
	m.fx.burst(h.pos + Vector3(0, 0.3, 0), col, 12, 3.0, 0.45, -1.0)
	audio.ward(h, kind)

const FEET_FX := {"lava": "ff9a3a", "deep_water": "cfeaff", "ice": "f4fcff", "static": "fff27a", "bramble": "8ac04a"}

func _feet_fx(h: Hunter, st: Dictionary, kind: String, dt: float) -> void:
	st["fx"] = float(st["fx"]) - dt
	if float(st["fx"]) > 0.0 or Vector2(h.vel.x, h.vel.z).length() < 1.0:
		return
	st["fx"] = FX_S
	m.fx.burst(h.pos + Vector3(0, 0.1, 0), Color(FEET_FX[kind]), 6, 2.0, 0.35, 6.0, 0.8)

## What's near the player: the HUD says so when they're immune to it, and their Boki says whether it can
## handle it.
func _hint() -> void:
	var P := m.player
	ahead = {}
	if P == null or P.out:
		return
	var kind := _near_kind(P.pos, float(rules()["hint"]["near_m"]))
	if kind == "":
		return
	if guards(P, kind):
		ahead = _reading(P, kind, -1.0)
	if not P.kin is Kin or m.time - float(hinted.get(kind, -1e9)) < float(rules()["hint"]["again_s"]):
		return
	hinted[kind] = m.time
	var trig := "hazard_safe" if guards(P, kind) else "hazard_risk"
	BokiChatter.say(m, P.kin as Kin, trig, {"%H": String(kind_def(kind)["noun"])})

func _near_kind(p: Vector3, r: float) -> String:
	for k in [0.0, 0.5, 1.0]:
		for i in (1 if k == 0.0 else HINT_DIRS):
			var a := TAU * i / HINT_DIRS
			var x := int(floor(p.x + cos(a) * r * k))
			var z := int(floor(p.z + sin(a) * r * k))
			if w.inb(x, z) and cell[w.idx(x, z)] > 0:
				return String(areas[cell[w.idx(x, z)] - 1]["kind"])
	return ""
