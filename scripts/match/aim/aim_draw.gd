class_name AimDraw
extends Node3D
## The one node per match that draws every AimKit telegraph (docs/AIMKIT.md). Entries live in a
## dictionary keyed by hunter and id; each frame the whole set is rebuilt into one surface of a single
## ImmediateMesh, so showing, moving or hiding a telegraph never creates a node. Its child AimReticle
## draws the cursor states. Local visuals only: nothing here is synced (a remote hunter's kit draws its
## own on its own machine).

const KEEP := 0.1          # s of match time an entry lives after its last refresh (kits refresh per step)

var m: Node
var entries := {}          # "<hunter id>:<id>" -> resolved entry (AimKit._entry)
var mesh := ImmediateMesh.new()
var mi := MeshInstance3D.new()
var geo := AimGeo.new()
var mat := StandardMaterial3D.new()
var reticle: AimReticle
var built := 0             # entries drawn by the last rebuild (tests)
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

func drop(h: Node, id: String) -> void:
	entries.erase(key(h, id))

func drop_all(h: Node) -> void:
	ret.erase(h.get_instance_id())
	var pre := "%d:" % h.get_instance_id()
	for k in entries.keys():
		if String(k).begins_with(pre):
			entries.erase(k)

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

## Prune expired entries and draw the rest (also called directly by tests).
func rebuild() -> void:
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
		if e["all"]:
			e["side"] = SideColor.of(m, e["h"])     # an area others see: rim in whose-it-is colour, fill the hero's
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
