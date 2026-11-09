extends RefCounted
## --dash-trail-check: every Hunter's dash (on the ground and in the air) draws only the shared DashTrail, and
## it leaves nothing on the ground. While a dash runs the Hunter's after-images show; 0.3 s after it ends none is
## left; no ring, disc or burst (Fx.radial) and no flat plate on the ground is added at any point, bar the area the
## dash itself marks (AREA). `--dash-trail-check=<id>,<id>` limits it to those Hunters.

const WATCH_STEPS := 150       # sim steps (1/60 s) a dash may run before the check gives up on it ending
const AFTER_S := 0.3           # s after the dash ends by which the trail must be gone
const PLATE_MIN := 0.5         # m: a flat mesh at least this wide both ways, on the ground, is a decal
const PLATE_HIGH := 0.25       # m: flatter than this, and lying within 0.4 m of the floor
## "<hero>/<dash>" pairs where the move itself marks an area or shows a charge: Ostra's Lantern Trade swaps its
## circle, Tenzo's Rock Hop raises rocks, Mossy's 360 Smash hits all round him, and Sparkle's Wirerun in the air and
## Tenzo's air dash show the hold-to-charge tell (ArchKit._tick_charge) before they go.
const AREA := ["ostra/dash", "ostra/air dash", "dolm/dash", "dolm/air dash", "bulwark/dash", "mage/air dash"]

var bad := 0
var flow := preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("DASHTRAIL FAIL %s" % what)
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		for ev in ["dash", "air dash"]:
			await _dash(main, m, hero, ev)
		m.queue_free()
		await main.get_tree().process_frame
	print("DASHTRAIL DONE, failures: %d" % bad)
	main.get_tree().quit()

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dash-trail-check=") and arg.length() > 19:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## The visible flat plates lying on the floor under `node` (instance ids): decals, rings and lanes. Bodies (Ents),
## the aim marker and the scene's depth cues are not effects.
func _plates(node: Node, floor_y: float, into: Dictionary) -> void:
	if node is Ent or node.name in ["AimKit", "DepthCues"]:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree() and (node as MeshInstance3D).mesh:
		var box: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		if box.size.y < PLATE_HIGH and box.size.x >= PLATE_MIN and box.size.z >= PLATE_MIN \
				and box.position.y < floor_y + 0.4 and box.end.y > floor_y - 0.2:
			into[node.get_instance_id()] = true
	for c in node.get_children():
		_plates(c, floor_y, into)

func _what(mi: MeshInstance3D) -> String:
	return "%s %s %s" % [mi.get_parent().name, mi.mesh.get_class(), mi.global_position.snapped(Vector3(0.1, 0.1, 0.1))]

func _echoes(m: Match) -> int:
	return VVFx.of(m).live.filter(func(e): return String(e["kind"]) == "echo").size()

func _dash(main: Node, m: Match, hero: String, ev: String) -> void:
	var h: Hunter = flow.hunter
	flow._ready_up(m)
	for mb in m.mobs:
		mb.dead = true
	for o in m.hunters:
		if o != h:
			o.out = true
	var floor_y := h.pos.y
	var before := {}
	_plates(m, floor_y, before)
	var radial0: int = m.fx.radial
	if ev == "air dash":
		flow._lift()
		floor_y = h.pos.y - 7.0
	h.inp["move"] = Vector2(0, -1)
	h.inp["dash"] = true
	h.inp["dash_down"] = true
	m.step(Match.DT)
	h.inp["dash"] = false
	h.inp["dash_down"] = false          # a tap: holding Shift is a charge tell (Sparkle) or a skate (Neve), not the dash
	var ran := false
	var rolled := false
	var trail := 0
	var plates := {}
	var idle := 0.0
	for i in WATCH_STEPS:
		m.step(Match.DT)
		h.render(Match.DT, 1.0)         # (the match draws in _process, which a check does not run)
		await main.get_tree().process_frame
		if i % 3 == 0:
			_plates(m, floor_y, plates)
		var going := h.roll_t > 0.0 or h.ak.dash_left() > 0.0
		ran = ran or going
		rolled = rolled or h.roll_t > 0.0
		if going:
			trail = maxi(trail, _echoes(m))
			idle = 0.0
		else:
			idle += Match.DT
		if ran and idle >= AFTER_S:
			break
	var tag := "%s/%s" % [hero, ev]
	var area := tag in AREA
	var new_ids := plates.keys().filter(func(id): return not before.has(id) and is_instance_valid(instance_from_id(id)))
	var added := new_ids.size()
	var bursts: int = m.fx.radial - radial0
	print("DASHTRAIL %-10s %-9s ran %s, trail %d, ground plates %d, rings/bursts %d, echoes left %d" % [
			hero, ev, ran, trail, added, bursts, _echoes(m)])
	ok(ran, "%s: the dash never ran" % tag)
	ok(not rolled or trail > 0, "%s: no after-image while it ran" % tag)
	ok(_echoes(m) == 0, "%s: the trail is still there %.1f s after the dash" % [tag, AFTER_S])
	ok(area or added == 0, "%s: the dash left %d decal(s) on the ground: %s" % [tag, added, ", ".join(new_ids.map(func(id): return _what(instance_from_id(id)))) ])
	ok(area or bursts == 0, "%s: the dash spawned %d ring(s) or burst(s)" % [tag, bursts])
