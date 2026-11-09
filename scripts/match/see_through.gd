class_name SeeThrough
extends RefCounted
## See-through props: trees and ruin pillars between the camera and your own hunter (or your Boki)
## thin out to a light stipple, as in most top-down games, so a big canopy never hides you. The
## shaders do the test per prop (shaders/see.gdshaderinc, used by flora.gdshader and its outline);
## this hands them the camera and the two points to keep in view, every frame, from the match and
## the farm. Purely visual: what blocks sight and shots is still the map data.

static var _on := false
static var _disabled := -1     # --no-see (before/after screenshots): never thin anything out

## Keep `hunter` (feet) and, when it's out on the ground, `boki` (feet) in view from `cam`.
static func update(cam: Camera3D, hunter: Vector3, boki: Variant = null) -> void:
	if _disabled < 0:
		_disabled = 1 if "--no-see" in OS.get_cmdline_user_args() else 0
	if cam == null or not cam.is_inside_tree() or _disabled == 1:
		off()
		return
	RenderingServer.global_shader_parameter_set("see_cam", cam.global_position)
	RenderingServer.global_shader_parameter_set("see_a", Vector4(hunter.x, hunter.y, hunter.z, 1.0))
	if boki is Vector3:
		var b: Vector3 = boki
		RenderingServer.global_shader_parameter_set("see_b", Vector4(b.x, b.y, b.z, 1.0))
	else:
		RenderingServer.global_shader_parameter_set("see_b", Vector4(0, 0, 0, 0))
	_on = true

## Nothing to keep in view (dead, extracted, leaving the screen): every prop solid again.
static func off() -> void:
	if not _on:
		return
	_on = false
	RenderingServer.global_shader_parameter_set("see_a", Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_set("see_b", Vector4(0, 0, 0, 0))

## The match: your hunter while you're on the ground or gliding (not on the skyship, not out), and
## your Boki when it's out of your pocket and alive.
static func for_match(m) -> void:
	var p = m.player
	if p == null or p.out or p.extracted or p.riding or m.cam == null:
		off()
		return
	var at: Vector3 = p.model.global_position if p.model else p.pos
	var b = null
	var k = p.kin
	if k != null and is_instance_valid(k) and not k.dead and k.visible and String(k.get("state")) != "shoulder":
		b = (k as Node3D).global_position
	update(m.cam, at, b)

## --see-demo[=<style>] (screenshot tooling): your hunter stands just past a big tree of that biome
## style (bloom: the pink canopies), on the far side from the camera.
static func demo(m, style: String) -> void:
	var w = m.world
	var p = m.player
	var best = null
	for t in w.tree_spots:
		var tp: Vector3 = t
		var i: int = w.idx(int(tp.x), int(tp.z))
		if Flora.style_ok(w.style_at(i)) != style and best != null:
			continue
		var at := tp + Vector3(0.15, 0, -1.6)
		if w.is_void(at.x, at.z) or w.is_block(at.x, at.z) or absf(w.ground_at(at.x, at.z) - tp.y) > 0.3:
			continue
		best = Vector3(at.x, w.ground_at(at.x, at.z), at.z)
		if Flora.style_ok(w.style_at(i)) == style:
			break
	if best == null:
		print("SEEDEMO no tree with open ground behind it")
		return
	p.teleport(best)
	m.cam.snap(best)
	print("SEEDEMO hunter at %s" % str(best))
