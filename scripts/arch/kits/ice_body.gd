class_name IceBody
extends RefCounted
## A hunter's body turned to ice (Rimelock): every visible mesh of her model trades its material for
## shaders/hero_ice.gdshader, keeping its own colour and atlas, so the body itself is ice, not a shell.
## freeze(t) swaps the materials and runs a frost front from the feet up over t seconds; thaw() runs it
## back down and then gives the original materials back. Works on the procedural model (one
## material_override a part) and a Warden .glb (one override material a surface).

const SHADER := preload("res://shaders/hero_ice.gdshader")
const HEAD := 2.4                                 # m above the feet the front climbs to, past any hero's head
const SKIP := ["Ring", "TeamRing", "Glider"]      # the hit ring, team ring and glider are not her body

var h: Hunter
var swaps: Array = []       # {mi, slot (-1: the override), was: Material or null}
var mats: Array = []        # the ice materials, one a swapped surface
var k := 0.0                # the frost front, 0 (flesh) to 1 (all ice)
var thawing := false
var rate := 5.0             # 1/s the front moves


func _init(hunter: Hunter) -> void:
	h = hunter


func active() -> bool:
	return not swaps.is_empty()


## All ice and holding.
func frozen() -> bool:
	return active() and not thawing and k >= 0.999


## A mesh of her model that is her body: drawn, with a mesh, not the hit ring, team ring or glider.
static func is_body(mi: MeshInstance3D) -> bool:
	return not mi.name in SKIP and mi.mesh != null and mi.is_visible_in_tree()


## Swap every body material for ice and start the front climbing, feet to head, over t seconds.
func freeze(t: float) -> void:
	rate = 1.0 / maxf(0.05, t)
	thawing = false
	if active() or h.model == null:
		return
	for n in h.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not is_body(mi):
			continue
		if mi.material_override != null:
			_swap(mi, -1, mi.material_override, mi.material_override)
			continue
		for si in mi.mesh.get_surface_count():
			_swap(mi, si, mi.get_surface_override_material(si), mi.get_active_material(si))
	_set_front(0.0)


## Run the front back down; the original materials return when it reaches the feet.
func thaw() -> void:
	if active():
		thawing = true


## Per step: moves the front, keeps it on her feet (a skating cast slides her), restores after a thaw.
func tick(dt: float) -> void:
	if not active():
		return
	k = clampf(k + (-dt if thawing else dt) * rate, 0.0, 1.0)
	_set_front(k)
	if thawing and k <= 0.0:
		restore()


## The original materials back at once (teardown, or the end of a thaw).
func restore() -> void:
	for s in swaps:
		var mi: MeshInstance3D = s["mi"]
		if not is_instance_valid(mi):
			continue
		if int(s["slot"]) < 0:
			mi.material_override = s["was"]
		else:
			mi.set_surface_override_material(int(s["slot"]), s["was"])
	swaps.clear()
	mats.clear()
	k = 0.0
	thawing = false


func _swap(mi: MeshInstance3D, slot: int, was: Material, skin: Material) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	_copy_skin(m, skin)
	if skin is ShaderMaterial:
		m.next_pass = (skin as ShaderMaterial).next_pass       # the ink outline stays on the ice
	if slot < 0:
		mi.material_override = m
	else:
		mi.set_surface_override_material(slot, m)
	swaps.append({"mi": mi, "slot": slot, "was": was})
	mats.append(m)


## Her own colour and atlas, so the part keeps its look above the front while it climbs.
func _copy_skin(m: ShaderMaterial, skin: Material) -> void:
	if skin is ShaderMaterial:
		var sm := skin as ShaderMaterial
		for key in ["albedo", "use_tex", "albedo_tex", "use_vertex_color"]:
			var v = sm.get_shader_parameter(key)
			if v != null:
				m.set_shader_parameter(key, v)
	elif skin is BaseMaterial3D:
		var bm := skin as BaseMaterial3D
		m.set_shader_parameter("albedo", bm.albedo_color)
		if bm.albedo_texture != null:
			m.set_shader_parameter("use_tex", true)
			m.set_shader_parameter("albedo_tex", bm.albedo_texture)


func _set_front(fk: float) -> void:
	var foot := h.pos.y
	for m in mats:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("freeze", fk)
		sm.set_shader_parameter("foot_y", foot)
		sm.set_shader_parameter("head_y", foot + HEAD)
