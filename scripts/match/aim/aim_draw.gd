class_name AimDraw
extends Node3D
## The one node per match that draws every AimKit telegraph (docs/AIMKIT.md). Entries live in a
## dictionary keyed by hunter and id; each frame the whole set is rebuilt into one surface of a single
## ImmediateMesh, so showing, moving or hiding a telegraph never creates a node. Its child AimReticle
## draws the cursor states. Local visuals only: nothing here is synced (a remote hunter's kit draws its
## own on its own machine).

const ZONE_GRACE := 0.25   # s a finished zone's node may stay faded out before it is handed back
const KEEP := 0.1          # s of match time an entry lives after its last refresh (kits refresh per step)

var m: Node
var entries := {}          # "<hunter id>:<id>" -> resolved entry (AimKit._entry)
var mesh := ImmediateMesh.new()
var mi := MeshInstance3D.new()
var geo := AimGeo.new()
var mat := StandardMaterial3D.new()
var reticle: AimReticle
var built := 0             # entries drawn by the last rebuild (tests)
var zones := {}            # "<hunter id>:<id>" -> {node, geo (its meshes), ends, t}: expiring zones (AimKit.zone)
var ret := {}              # hunter instance id -> the cursor states: {h, k, t, col, flare, perfect, pcol}

func _init(match_node: Node) -> void:
	m = match_node
	name = "AimKit"

func _ready() -> void:
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = 2
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0       # the mesh is rebuilt every frame; never cull it by a stale AABB
	add_child(mi)
	var cl := CanvasLayer.new()
	cl.layer = 6                         # just over the HUD (5), so the states sit on its crosshair
	add_child(cl)
	reticle = AimReticle.new()
	reticle.d = self
	cl.add_child(reticle)

static func key(h: Node, id: String) -> String:
	return "%d:%s" % [h.get_instance_id(), id]

func put(h: Hunter, id: String, e: Dictionary) -> void:
	e["h"] = h
	e["t"] = float(m.time)
	entries[key(h, id)] = e

## A zone's cue state for this step: `left` seconds to go, from the kit's per-step call.
func zone(h: Hunter, id: String, left: float, node: Node3D) -> void:
	var k := key(h, id)
	var z: Dictionary = zones.get(k, {})
	if z.is_empty() or z["node"] != node:
		_end_zone(k)
		z = {"node": node, "geo": _meshes(node)}
	z["ends"] = float(m.time) + left
	z["t"] = float(m.time)
	zones[k] = z

## The meshes a zone's node is faded through: itself and every mesh under it (found once, not per step).
func _meshes(node: Node3D) -> Array:
	var out: Array = []
	if node is GeometryInstance3D:
		out.append(node)
	if node != null:
		out.append_array(node.find_children("*", "GeometryInstance3D", true, false))
	return out

func drop(h: Node, id: String) -> void:
	entries.erase(key(h, id))
	_end_zone(key(h, id))

func _end_zone(k: String) -> void:
	var z: Dictionary = zones.get(k, {})
	if z.is_empty():
		return
	_fade_meshes(z, 0.0)
	zones.erase(k)

func drop_all(h: Node) -> void:
	ret.erase(h.get_instance_id())
	var pre := "%d:" % h.get_instance_id()
	for k in entries.keys():
		if String(k).begins_with(pre):
			entries.erase(k)
	for k in zones.keys():
		if String(k).begins_with(pre):
			_end_zone(k)

func live(e: Dictionary) -> bool:
	var h = e["h"]
	if not is_instance_valid(h) or (h as Hunter).out or AimKit.blocked(h):
		return false
	return float(m.time) - float(e["t"]) <= float(e["keep"])

func _process(delta: float) -> void:
	rebuild()
	tick_reticle(delta)

## The cursor states run on real time, so a perfect-window flash still shows through a hit stop.
func tick_reticle(delta: float) -> void:
	for k in ret.keys():
		var r: Dictionary = ret[k]
		r["flare"] = maxf(0.0, float(r["flare"]) - delta)
		r["perfect"] = maxf(0.0, float(r["perfect"]) - delta)
		if not is_instance_valid(r["h"]) or AimKit.blocked(r["h"]) or (float(m.time) - float(r["t"]) > KEEP and r["flare"] <= 0.0 and r["perfect"] <= 0.0):
			ret.erase(k)
	reticle.queue_redraw()

func ret_of(h: Hunter) -> Dictionary:
	var k := h.get_instance_id()
	if not ret.has(k):
		ret[k] = {"h": h, "k": -1.0, "t": -99.0, "col": Color.WHITE, "flare": 0.0, "perfect": 0.0, "pcol": Color.WHITE, "fcol": Color.WHITE}
	return ret[k]

## The expiry cue (AimShapes.rim_k / look_k) onto each zone's entry (the rim) and node (the fill); a zone the
## kit stopped calling is released.
func _tick_zones() -> void:
	for k in zones.keys():
		var z: Dictionary = zones[k]
		if float(m.time) - float(z["t"]) > KEEP:
			_end_zone(k)
			continue
		var left := float(z["ends"]) - float(m.time)
		if left <= 0.0 and (left < -ZONE_GRACE or not _shown(z["node"])):
			_end_zone(k)             # over: its owner has hidden the node (or never will: give it back)
			continue
		if entries.has(k):
			entries[k]["left"] = left
		_fade_meshes(z, 1.0 - AimShapes.look_k(left))

func _shown(node) -> bool:      # (untyped: a freed node must not trip the argument check)
	return is_instance_valid(node) and (node as Node3D).is_visible_in_tree()

func _fade_meshes(z: Dictionary, transparency: float) -> void:
	for g in z["geo"]:
		if is_instance_valid(g):
			(g as GeometryInstance3D).transparency = transparency

## Prune expired entries and draw the rest (also called directly by tests).
func rebuild() -> void:
	_tick_zones()
	for k in entries.keys():
		if not live(entries[k]):
			entries.erase(k)
	mesh.clear_surfaces()
	built = 0
	geo.world = m.get("world")
	geo.reset()
	var me = m.get("player")
	for k in entries:
		var e: Dictionary = entries[k]
		if not e["all"] and e["h"] != me:
			continue                    # an aim reticle: only its own player sees it
		if e["all"] and me != null and int((e["h"] as Hunter).team) != int(me.team):
			e = e.duplicate()
			e["col"] = (e["col"] as Color).lerp(Feel.RIM_ENEMY, 0.45)     # a foe's telegraph reads hostile
			e["col2"] = (e["col2"] as Color).lerp(Feel.RIM_ENEMY, 0.3)
		AimShapes.build(geo, e)
		built += 1
	if geo.v.is_empty():
		mi.visible = false
		return
	mi.visible = true
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for i in geo.v.size():
		mesh.surface_set_color(geo.c[i])
		mesh.surface_add_vertex(geo.v[i])
	mesh.surface_end()
