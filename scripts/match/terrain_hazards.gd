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
const STAND_Y := 0.35        # m: this close to the area's ground you're in it (a jump or a glide clears it)
const TICK_S := 0.5          # s between drowning or scratch hits
const FX_S := 0.35           # s between splashes or sparks at the feet of someone moving through
const HINT_DIRS := 8         # directions the Boki looks for a hazard nearby

static var _rules := {}

var m: Match
var w: World
var areas: Array = []                 # {kind, def, y, centre, cells: Array[Vector2i], poly, box, mat, t, phase}
var cell := PackedInt32Array()        # per tile: area index + 1, 0 = no hazard
var state := {}                       # hunter instance id -> {area, safe, breath, tick, fx}
var hint_t := 0.0
var hinted := {}                      # kind -> m.time the player's Boki last spoke of it

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
			_add_area(String(A["kind"]), A["poly"])

# ------------------------------------------------------------------ the areas
func _add_area(kind: String, pts: Array) -> void:
	var def := kind_def(kind)
	if def.is_empty():
		push_warning("TerrainHazards: unknown hazard kind '%s'" % kind)
		return
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(float(p[0]), float(p[1])))
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var ai := areas.size()
	var cells: Array[Vector2i] = []
	var sum := Vector2.ZERO
	for z in range(int(box.position.y), int(box.end.y) + 1):
		for x in range(int(box.position.x), int(box.end.x) + 1):
			if not w.inb(x, z) or w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, z + 0.5), poly):
				cell[w.idx(x, z)] = ai + 1
				cells.append(Vector2i(x, z))
				sum += Vector2(x + 0.5, z + 0.5)
	if cells.is_empty():
		return
	var c := sum / cells.size()
	var y := w.ground_at(cells[0].x + 0.5, cells[0].y + 0.5)
	var A := {"kind": kind, "def": def, "y": y, "centre": Vector3(c.x, y, c.y), "cells": cells,
		"poly": poly, "box": box,
		"t": float(def["effect"].get("every_s", 0.0)), "phase": "idle"}
	A["mat"] = _surface(poly, box.grow(SDF_PAD), y, def["look"])
	if kind == "bramble":
		_thorns(cells, y)
	areas.append(A)

## The area's surface: one flat quad over its box; the shader cuts the outline out of a distance field.
func _surface(poly: PackedVector2Array, box: Rect2, y: float, look: Dictionary) -> ShaderMaterial:
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

## Whether h's active Boki walks this kind of ground safely (its type or its species is a counter).
func guards(h: Hunter, kind: String) -> bool:
	var k := h.kin as Kin
	if k == null or k.state == "downed":
		return false
	var C: Dictionary = kind_def(kind).get("counter", {})
	return String(k.sp.get("theme", "")) in C.get("themes", []) or k.species in C.get("kin", [])

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

## Hits from a hunter wading in deep water without a swimmer are weaker.
static func hit_mult(mm: Node, by: Ent) -> float:
	var tz := of(mm)
	if tz == null or not by is Hunter:
		return 1.0
	var st: Dictionary = tz.state.get(by.get_instance_id(), {})
	return float(st.get("weak", 1.0))

## What the player is standing in, for the HUD: {} or {name, col, safe, hurts, breath (0..1), kin}.
func underfoot(h: Hunter) -> Dictionary:
	var st: Dictionary = state.get(h.get_instance_id(), {})
	if int(st.get("area", -1)) < 0:
		return {}
	var A: Dictionary = areas[int(st["area"])]
	var E: Dictionary = A["def"]["effect"]
	var k := h.kin as Kin
	var kin_name := String(k.rec.get("name", k.sp.get("name", "Your Boki"))) if k else ""
	return {"name": String(A["def"]["name"]), "col": Color(String(A["def"]["look"]["edge"])), "safe": bool(st["safe"]),
		"hurts": String(A["def"]["hurts"]), "kin": kin_name,
		"breath": clampf(float(st["breath"]) / float(E["breath_s"]), 0.0, 1.0) if E.has("breath_s") else -1.0}

# ------------------------------------------------------------------ every frame
func tick(dt: float) -> void:
	if areas.is_empty():
		return
	for ai in areas.size():
		if areas[ai]["kind"] == "static":
			_tick_static(ai, dt)
	for h in m.hunters:
		_tick_hunter(h, dt)
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
	if int(st["area"]) != a or bool(st.get("safe", false)) != safe:
		st["area"] = a
		st["safe"] = safe
		if safe: _protect_fx(h)
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
			_protect_fx(h)
		else:
			m.fx.burst(h.pos + Vector3(0, 0.8, 0), Color("fff9c0"), 16, 5.0, 0.3, 1.0)
			h.hurt(float(E["dmg"]) * _tier(), null, {"src": "hazard", "tags": ["hazard"], "stun": float(E["stun_s"])})

# ------------------------------------------------------------------ feedback
## The Boki keeps you safe here: a burst in its colour at your feet (and a chime for the player).
func _protect_fx(h: Hunter) -> void:
	var k := h.kin as Kin
	var col: Color = k.sp.get("glow", Color.WHITE) if k else Color.WHITE
	m.fx.burst(h.pos + Vector3(0, 0.3, 0), col, 12, 3.0, 0.45, -1.0)
	if h == m.player:
		m.sfx("shield", h.pos, -10.0, 1.3)

const FEET_FX := {"lava": "ff9a3a", "deep_water": "cfeaff", "ice": "f4fcff", "static": "fff27a", "bramble": "8ac04a"}

func _feet_fx(h: Hunter, st: Dictionary, kind: String, dt: float) -> void:
	st["fx"] = float(st["fx"]) - dt
	if float(st["fx"]) > 0.0 or Vector2(h.vel.x, h.vel.z).length() < 1.0:
		return
	st["fx"] = FX_S
	m.fx.burst(h.pos + Vector3(0, 0.1, 0), Color(FEET_FX[kind]), 6, 2.0, 0.35, 6.0, 0.8)

## The player's Boki says when a hazard is near, and whether it can handle it.
func _hint() -> void:
	var P := m.player
	if P == null or P.out or not P.kin is Kin:
		return
	var kind := _near_kind(P.pos, float(rules()["hint"]["near_m"]))
	if kind == "" or m.time - float(hinted.get(kind, -1e9)) < float(rules()["hint"]["again_s"]):
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
