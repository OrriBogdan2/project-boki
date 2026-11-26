extends RefCounted
## Whose Boki is it, at match zoom (docs/COMBAT_CLARITY.md "Boki ownership read"). For each Boki on a fight frame: the
## pixels its ownership mark owns (a wisp's side-coloured rim, a walking Boki's ring: the Boki drawn alone with the mark
## and without it, the difference), the share of them that the own side's colour paints rather than the other two
## (SideColor: you, ally, rival), and the share still changing the played frame (casts, bodies and effects lie over
## the rest).
## Numbers only; the pictures are the fight frames. Used by --wisp-read-shots.

const SOLO_LAYER := 1 << 19  # render layer 20, as in ClarityRead
const MARK_DIFF := 0.04  # most-changed channel above which a pixel belongs to the mark
const NEUTRAL := Color(0.5, 0.5, 0.5)  # the wisp's rim with no side colour on it
const BOX := 150.0  # px (1080p) each way from a Boki: its rim or ring fits inside
const MIN_PX := 40  # a mark under this many 1080p pixels is not a mark at match zoom
const MIN_RIGHT := 0.7  # share of mark pixels nearest the right side colour
const MIN_CASE := 0.8  # share of a case's Boki-frames that must read
const MIN_SEEN := 0.5  # share of the mark that survives the fight on screen


## One row per shown Boki: {role "own"|"ally"|"foe", form "wisp"|"walk", species, at (1080p pixel), mark, right, seen}.
## `right` and `seen` are shares of the `mark` pixels (0 with no mark).
static func frame(fm: Match) -> Array:
	var rows: Array = []
	var vp := fm.get_viewport()
	await RenderingServer.frame_post_draw
	var played := vp.get_texture().get_image()
	var cam := vp.get_camera_3d()
	var mask := cam.cull_mask
	var hud := fm.hud as CanvasLayer
	for k: Kin in fm.kins:
		if k.owner_h == null or not k.visible or not k.is_inside_tree() or k.model == null or k.state == "away":
			continue
		if not cam.is_position_in_frustum(k.global_position):
			continue
		var own := SideColor.of(fm, k)
		var solo: GeometryInstance3D = k.model.get_node("Body") if k.wisp else k.ring
		if solo == null or not solo.is_visible_in_tree():
			continue
		var layers := solo.layers
		solo.layers = SOLO_LAYER
		cam.cull_mask = SOLO_LAYER
		hud.visible = false
		await RenderingServer.frame_post_draw
		var on := vp.get_texture().get_image()
		_mark_off(k, true, own)
		await RenderingServer.frame_post_draw
		var off := vp.get_texture().get_image()
		hud.visible = true
		cam.cull_mask = mask
		solo.layers = layers
		await RenderingServer.frame_post_draw
		var played_off := vp.get_texture().get_image()
		_mark_off(k, false, own)
		var sides := [SideColor.you(), SideColor.ally(), SideColor.foe()]
		var want := sides.find(own)
		var at := cam.unproject_position(k.global_position) * Vector2(on.get_size()) / vp.get_visible_rect().size
		var box := Rect2i(Rect2(at - Vector2(BOX, BOX), Vector2(BOX, BOX) * 2.0)).intersection(
			Rect2i(Vector2i.ZERO, on.get_size())
		)
		var row := _row(fm, k, want, sides, [on, off, played, played_off], box)
		row["at"] = Vector2i(at)
		rows.append(row)
	return rows


static func describe(r: Dictionary) -> String:
	return (
		"%s %s %s at=%d,%d mark=%dpx right=%.0f%% seen=%.0f%% %s"
		% [
			r["role"],
			r["form"],
			r["species"],
			r["at"].x,
			r["at"].y,
			r["mark"],
			100.0 * r["right"],
			100.0 * r["seen"],
			"ok" if passes(r) else "FAIL"
		]
	)


## Whether a Boki's mark reads: big enough, painted in the right side colour, and not buried under the fight.
static func passes(r: Dictionary) -> bool:
	return r["mark"] >= MIN_PX and r["right"] >= MIN_RIGHT and r["seen"] >= MIN_SEEN


static func _row(fm: Match, k: Kin, want: int, sides: Array, pics: Array, box: Rect2i) -> Dictionary:
	var on: Image = pics[0]
	var off: Image = pics[1]
	var played: Image = pics[2]
	var played_off: Image = pics[3]
	var mark := 0
	var right := 0
	var seen := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := on.get_pixel(x, y)
			if _gap(c, off.get_pixel(x, y)) <= MARK_DIFF:
				continue
			mark += 1
			if _paints(c, off.get_pixel(x, y), sides) == want:
				right += 1
			if _gap(played.get_pixel(x, y), played_off.get_pixel(x, y)) > MARK_DIFF:
				seen += 1
	var h: Hunter = k.owner_h
	return {
		"role": _role(fm, h),
		"form": "wisp" if k.wisp else "walk",
		"species": k.species,
		"mark": mark,
		"right": float(right) / maxf(mark, 1.0),
		"seen": float(seen) / maxf(mark, 1.0),
	}


static func _role(fm: Match, h: Hunter) -> String:
	if h == fm.player:
		return "own"
	return "ally" if h.team == fm.player.team else "foe"


## The mark taken off the Boki (a wisp's rim back to neutral, a walking Boki's ring hidden) or put back.
static func _mark_off(k: Kin, off: bool, side: Color) -> void:
	if k.wisp:
		(k.model.get_node("Body") as GeometryInstance3D).set_instance_shader_parameter(
			"rim_col", NEUTRAL if off else side
		)
	else:
		k.ring.visible = not off


## Which side colour the mark painted over this pixel: the one whose pull from the pixel without the mark lines up
## best with what the mark changed (the Boki's own colours in the rim and the ground under a ring cancel out).
static func _paints(on: Color, off: Color, sides: Array) -> int:
	var change := Vector3(on.r - off.r, on.g - off.g, on.b - off.b)
	var best := -1
	var score := -1e9
	for i in sides.size():
		var c: Color = sides[i]
		var pull := Vector3(c.r - off.r, c.g - off.g, c.b - off.b)
		var s := change.dot(pull) / maxf(pull.length(), 0.001)
		if s > score:
			score = s
			best = i
	return best


static func _gap(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
