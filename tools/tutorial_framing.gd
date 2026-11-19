class_name TutorialFraming
extends RefCounted
## Framing at the match camera for --tutorial-fight-check (tut-wide-cam, owner 11-11): while the driver plays
## the course as one starter, the camera on the hunter (the default view, no cursor lean), each step's thing to
## act on (the camp's monster, the pad's sign, the glove, the outpost, the stop) is judged at 1280x720: on
## screen for most of the step (a walk to a far stop: by the time you get there; the marker and the Boki lead
## the way meanwhile) and, where it is a thing, at least MIN_PX tall. One row per step is printed.

const VIEW := Vector2(1280, 720)  # the smallest screen the tutorial is built for
const MIN_PX := 24.0  # px at 1280x720: the least a thing to act on may be drawn tall
const ON_SHARE := 0.6  # of a step's frames: its thing is on screen at least this often

var rows := {}  # step id -> [frames, frames on screen, px tall while on screen, on screen last frame]


## One frame, after the match stepped: the camera snaps to the hunter, then the step's thing is measured.
func tick(m: Match) -> void:
	m.cam.snap(m.player.pos)
	var tu: Tutorial = m.tut
	var sid := tu.id()
	var at := _act_at(tu, sid)
	if at == Vector3.INF:
		return
	var row: Array = rows.get(sid, [0, 0, [], false])
	rows[sid] = row
	row[0] += 1
	row[3] = _on_screen(m.cam, at)
	if row[3]:
		row[1] += 1
		var node := _act_node(tu, sid)
		if node != null:
			(row[2] as Array).append(_tall_px(m.cam, node))


## Prints a row per step and judges it through `ok` ((cond: bool, what: String) -> void).
func judge(arch: String, ok: Callable) -> void:
	for sid: String in rows:
		var row: Array = rows[sid]
		var share := float(row[1]) / maxf(1.0, float(row[0]))
		var px: Array = row[2]
		px.sort()
		var tall := "-" if px.is_empty() else "%.0f / %.0f" % [px[0], px[px.size() / 2]]
		var pct := share * 100.0
		print("TUTFIGHT frame %s | %s | on screen %.0f%% | px tall (min / median) %s" % [arch, sid, pct, tall])
		if sid in Tutorial.WALK_LEAD:
			ok.call(row[3], "%s %s: the place you walk to is on screen when you get there" % [arch, sid])
		else:
			ok.call(share >= ON_SHARE, "%s %s: its thing is on screen %.0f%% of the step" % [arch, sid, pct])
		if not px.is_empty():
			ok.call(float(px[px.size() / 2]) >= MIN_PX, "%s %s: drawn %s px tall" % [arch, sid, tall])


## Where the thing a step asks you to act on stands (INF for a step on the HUD alone): a gap step's pad
## (you leave from it), else the step's goal.
static func _act_at(tu: Tutorial, sid: String) -> Vector3:
	if sid in Tutorial.GAP_STEPS and tu.pad_sign(sid) != null:
		return tu.stop(sid, "pad")
	return tu.goal(sid)


## The thing itself, when there is one to measure (the ground stops have none).
static func _act_node(tu: Tutorial, sid: String) -> Node3D:
	if sid in Tutorial.GAP_STEPS:
		return tu.pad_sign(sid)
	if sid in Tutorial.FOE_STEPS:
		var mb := tu.camps.nearest("sentinel" if sid == "hook" else "")
		if mb == null:
			mb = tu.camps.nearest()
		return mb.model if mb else null
	if sid not in ["glove", "wayout", "uplink", "defend", "extract"]:
		return null
	var item := tu.ground_item() if sid == "glove" else tu.outpost()
	return item.get("node")


static func _on_screen(cam: Camera3D, at: Vector3) -> bool:
	if cam.is_position_behind(at):
		return false
	return Rect2(Vector2.ZERO, VIEW).has_point(_to_view(cam, at))


## A world point on the 1280x720 screen.
static func _to_view(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at) / cam.get_viewport().get_visible_rect().size * VIEW


## How tall a thing is drawn on screen: a sign faces the camera, so its line's height; anything else, the
## height of its box's outline (seen from above, a flat monster's back counts, not just how high it stands).
static func _tall_px(cam: Camera3D, node: Node3D) -> float:
	if node is Label3D:
		var lab := node as Label3D
		var half := cam.global_transform.basis.y * lab.font_size * lab.pixel_size * 0.5
		return absf(_to_view(cam, lab.global_position + half).y - _to_view(cam, lab.global_position - half).y)
	var box := AABB(node.global_position, Vector3.ZERO)
	for vi: VisualInstance3D in node.find_children("*", "VisualInstance3D", true, false):
		if vi.is_visible_in_tree():
			box = box.merge(vi.global_transform * vi.get_aabb())
	var lo := INF
	var hi := -INF
	for i in 8:
		var y := _to_view(cam, box.get_endpoint(i)).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo
