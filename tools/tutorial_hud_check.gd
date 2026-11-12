extends RefCounted
## --tutorial-hud-check: the tutorial shows one voice at a time, in its own lanes.
##   1. the lanes at 1280x720, 1920x1080 and 3440x1440: the step strip is one line, at most 42% of the width
##      and 6% of the height, at the top-centre inside the safe margin; no two lanes (strip, check,
##      toasts, intro) intersect, none sits in the middle
##   2. a scripted run of the whole course (the driver, with a Boki): while the banner is up no toast is
##      showing (one fired at each step start waits and then shows) and no Boki bubble is up; the
##      hunter and the Boki are never under the banner
##   3. the marker: a target ahead shows its pin, one behind the camera or under the hunter gets the arrow
##   4. the panel counter, the right click taught from its kit data, the Boki step's words
##   5. the course: every stop is walkable from the one before it on its island, and the lookout takes a
##      wall kick (taller than a jump, within a jump and a kick's climb)
##   6. framing at the match camera, per starter (Lace, Kael, Vex), at 1280x720: at every step the thing to
##      act on (the camp's monster, the pad's sign, the glove, the outpost, the stop) is on screen for most
##      of the step (a walk to a far stop: by the time you get there; the marker's edge arrow and the Boki
##      lead the way meanwhile) and, where it is a thing, at least MIN_PX tall. One row per step is printed.

var bad := 0
var m: Match
var main: Node

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080), Vector2(3440, 1440)]
const STARTERS := ["archer", "juggernaut", "gunslinger"]
const FRAME_VIEW := Vector2(1280, 720)   # the smallest screen the tutorial is built for
const MIN_PX := 24.0                     # px at 1280x720: the least a thing to act on may be drawn tall
const ON_SHARE := 0.6                    # of a step's frames: its thing is on screen at least this often

func ok(cond: bool, what: String) -> void:
	print("TUTHUD %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_lanes()
	_course()
	_reach()
	for id in STARTERS:
		_framing(id)
	print("TUTHUD DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. the lanes
func _lanes() -> void:
	for sz: Vector2 in SIZES:
		var ln := TutorialHud.lanes(sz)
		var b: Rect2 = ln["banner"]
		var tag := "%dx%d" % [sz.x, sz.y]
		var small: bool = b.size.x <= sz.x * TutorialStrip.WIDTH_FRAC + 0.5 and b.size.y <= sz.y * 0.06 + 0.5
		ok(small, "%s: the strip is at most 42%% x 6%% of the screen (%s)" % [tag, str(b.size)])
		var margin := maxf(24.0, sz.y * 0.04)
		var in_safe := b.position.y >= margin - 0.5 and b.position.x >= margin
		ok(in_safe, "%s: the strip is inside the safe margin (%.0f)" % [tag, b.position.y])
		ok(absf(b.get_center().x - sz.x * 0.5) < 1.0, "%s: the strip is at the top-centre" % tag)
		var pulse_ok := TutorialStrip.glow(0.0) == 1.0 and TutorialStrip.glow(TutorialStrip.PULSE_T) == 0.0
		ok(pulse_ok, "%s: the glow starts full on a new objective and is calm after PULSE_T" % tag)
		var centre := Rect2(sz * Vector2(0.3, 0.25), sz * Vector2(0.4, 0.45))
		var names: Array = ln.keys()
		var clash := ""
		for i in names.size():
			var r: Rect2 = ln[names[i]]
			if names[i] != "intro" and r.intersects(centre):
				clash += " %s in the middle" % names[i]
			for j in range(i + 1, names.size()):
				if names[i] != "intro" and names[j] != "intro" and r.intersects(ln[names[j]]):
					clash += " %s/%s" % [names[i], names[j]]
			ok(Rect2(Vector2.ZERO, sz).encloses(r), "%s: the %s lane is on screen" % [tag, names[i]])
		ok(clash == "", "%s: no two lanes intersect and none is in the middle%s" % [tag, clash])
		# a real match (the first-match guide): the strip drops under the Ways Out strip and its line
		var wo_w := maxf(WaysOutHud.CELL.x * 4.0 + WaysOutHud.SQUADS_W, 240.0)
		var wo_b := WaysOutHud.TOP_Y + WaysOutHud.CELL.y + 31.0
		var wo := Rect2(Vector2(sz.x * 0.5 - wo_w * 0.5, WaysOutHud.TOP_Y), Vector2(wo_w, wo_b - WaysOutHud.TOP_Y))
		var gb := TutorialStrip.rect(sz, wo_b)
		var g_ok := not gb.intersects(wo) and gb.size.y <= sz.y * 0.06 + 0.5 and gb.end.y <= sz.y - margin
		ok(g_ok, "%s: in a real match the strip sits under the Ways Out zone clocks (%s)" % [tag, str(gb)])

# ------------------------------------------------------------------ 2, 3, 4. a run of the course
func _course() -> void:
	m = Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	var tu: Tutorial = m.tut
	ok(m.hud != null, "the HUD is up")
	ok(tu.intro, "the first run starts with the intro card")
	m.step(Match.DT)
	var held_at := 0.0
	while m.time < 0.0001 and held_at < 5.0:
		m.step(Match.DT)
		held_at += Match.DT
	var closed := not tu.intro and held_at < Tutorial.INTRO_T + 0.2
	ok(closed, "the intro card closes by itself within %.1fs (%.2fs)" % [Tutorial.INTRO_T, held_at])
	ok(bool(Save.d["tutorial"].get("tut_intro", false)), "and is remembered, so it only shows the first time")
	_marker()
	var t := 0.0
	var last := -1
	var step_t := 0.0
	var worst := 0.0
	var toast_in_card := 0
	var bubble_in_card := 0
	var shown_after := 0
	var asked := 0
	var under := 0
	var texts := {}
	var counters := {}
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step != last:
			if last >= 0:
				worst = maxf(worst, step_t)
			last = tu.step
			step_t = 0.0
			if m.hud and not m.player.extracted:
				m.hud.toast("check %d" % last, Color.WHITE)
				asked += 1
			texts[tu.id()] = tu.text
			counters[tu.id()] = tu.progress_text()
		step_t += Match.DT
		if m.hud == null:
			continue
		if tu.card_up():
			toast_in_card += m.hud.msgs.texts().size()
			bubble_in_card += m.bubbles.size()
			under += _under_banner()
		elif not m.hud.msgs.texts().is_empty():
			shown_after += 1
			m.hud.msgs.clear()
	ok(m.player.extracted, "the course still finishes")
	ok(toast_in_card == 0, "no toast shows while a banner is up (%d seen)" % toast_in_card)
	ok(bubble_in_card == 0, "no Boki bubble shows while a banner is up (%d seen)" % bubble_in_card)
	var waited := "(%d asked, %d shown)" % [asked, shown_after]
	ok(asked > 0 and shown_after > 0, "a toast fired during a banner waits and shows after it " + waited)
	ok(under == 0, "the hunter and the Boki are never under the banner (%d frames)" % under)
	ok(worst < 45.0, "no step took more than 45s of plain play (%.0fs)" % worst)
	var wide := texts.values().filter(func(x): return String(x).length() > 34)
	ok(wide.is_empty(), "every banner line fits one short line (%s)" % str(wide))
	var counts_ok: bool = String(counters.get("shoot", "")) == "0/2"
	ok(counts_ok, "the panel counts hits and casts (%s)" % str(counters))
	var ak: ArchKit = m.player.ak
	if ak != null:
		var hold := float(ak.rmb_def().get("hold", 0.0)) > 0.0
		var why := "(%s hold %s)" % [ak.id, str(hold)]
		ok(tu.rmb_has_hold() == hold, "the right click step follows the kit's hold variant " + why)
		var line := String(texts.get("sec", ""))
		ok(line.to_lower().contains("hold") == hold, "and its words say so ('%s')" % line)
	var tl := String(texts.get("gkey", "")).to_lower()
	ok(tl.begins_with("send"), "the Boki step says to send it ('%s')" % tl)

## The marker's pin or arrow: a spot at your feet or ahead in view shows its pin, one behind you the arrow.
func _marker() -> void:
	var cam := m.cam
	var sz := m.get_viewport().get_visible_rect().size
	var fwd := -cam.global_transform.basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var me := m.player.pos
	var near := MarkerDir.off_dir(cam, sz, me + fwd * 1.0, me)
	ok(near == Vector2.ZERO, "a target at the hunter's feet shows its pin, not an arrow (%s)" % str(near))
	var aim := sz * Vector2(0.5, 0.3)      # where the pin should land: in the play box, above the hunter
	var o := cam.project_ray_origin(aim)
	var ray := cam.project_ray_normal(aim)
	var pin := o + ray * ((me.y + MarkerDir.PIN_UP - o.y) / ray.y)
	var ahead := MarkerDir.off_dir(cam, sz, pin - Vector3(0, MarkerDir.PIN_UP, 0), me)
	ok(ahead == Vector2.ZERO, "a target ahead whose pin is in the play box shows its pin (%s)" % str(ahead))
	var back := MarkerDir.off_dir(cam, sz, me - fwd * 4.0, me)
	ok(back != Vector2.ZERO and back.y > 0.0, "one behind the hunter gets an arrow pointing down (%s)" % str(back))

## Frames where the hunter or the Boki sit under the banner (at the screen sizes it is built for).
func _under_banner() -> int:
	var cam := m.cam
	var vp := m.get_viewport().get_visible_rect().size
	if cam == null or vp.x < 1.0:
		return 0
	var hit := 0
	var spots: Array = [m.player.pos + Vector3(0, 0.9, 0)]
	if m.player.kin:
		spots.append(m.player.kin.seen_pos() + Vector3(0, 0.6, 0))
	for sz: Vector2 in SIZES:
		var b: Rect2 = TutorialHud.lanes(sz)["banner"]
		for at: Vector3 in spots:
			if cam.is_position_behind(at):
				continue
			var f := cam.unproject_position(at) / vp
			if b.has_point(f * sz):
				hit += 1
	return hit

# ------------------------------------------------------------------ 5. every stop can be reached
## From each stop to the next on the same island, plain walking: no step up taller than half a jump.
func _reach() -> void:
	var tu: Tutorial = m.tut
	var jump_apex := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV)
	var order := ["land", "dash", "exdash", "glide", "crouch", "pickup", "yard"]
	var worst := 0.0
	var worst_at := ""
	for i in range(1, order.size()):
		var a := tu.stop(order[i - 1])
		var b := tu.stop(order[i])
		if a == Vector3.INF or b == Vector3.INF:
			continue
		if m.world.island_of(a.x, a.z) != m.world.island_of(b.x, b.z):
			continue      # (a gap: the dash, jump and glide steps and the bridges, which the run above plays)
		if order[i] == "crouch":
			continue      # (the lookout: climbed with a wall kick, checked below)
		var prev := a.y
		var n := int(a.distance_to(b) / 0.4) + 1
		for k in range(1, n + 1):
			var q := a.lerp(b, float(k) / n)
			var y: float = m.world.ground_at(q.x, q.z)
			if y - prev > worst:
				worst = y - prev
				worst_at = "%s -> %s" % [order[i - 1], order[i]]
			prev = y
	var msg := "every walk between stops climbs at most 60%% of a jump (%.2fm of %.2fm, %s)"
	ok(worst <= jump_apex * 0.6, msg % [worst, jump_apex, worst_at])
	var cr := tu.stop("crouch")
	var kick_ok := cr.y > jump_apex and cr.y <= jump_apex + WallMoves.HOP_CLIMB_CAP
	ok(kick_ok, "the lookout top is %.2fm up: over a jump (%.2fm), within a wall kick climb" % [cr.y, jump_apex])

# ------------------------------------------------------------------ 6. framing at the match camera
## Plays the course as one starter, the camera on the hunter (the default view, no cursor lean), and
## judges each step's thing to act on at 1280x720: how often it is on screen and how tall it is drawn.
func _framing(arch: String) -> void:
	seed(11)       # (the run --tutorial-fight-check plays, the same each time)
	var fm := Match.new()
	main.add_child(fm)
	fm.start({"tutorial": true, "tut_test": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
			"demo_kin": "cindle", "arch": arch, "cls": Arch.weight(arch)})
	fm.set_process(false)
	var tu: Tutorial = fm.tut
	var rows := {}      # step id -> [frames, frames on screen, px tall while on screen, on screen last frame]
	var t := 0.0
	while t < 600.0 and not fm.player.extracted:
		TutorialDrive.drive(fm)
		fm.step(Match.DT)
		t += Match.DT
		fm.cam.snap(fm.player.pos)
		var sid := tu.id()
		var at := _act_at(tu, sid)
		if at == Vector3.INF:
			continue
		var row: Array = rows.get(sid, [0, 0, [], false])
		rows[sid] = row
		row[0] += 1
		row[3] = _on_screen(fm.cam, at)
		if row[3]:
			row[1] += 1
			var node := _act_node(tu, sid)
			if node != null:
				(row[2] as Array).append(_tall_px(fm.cam, node))
	print("TUTHUD frame %s | step | on screen | px tall (min / median)" % arch)
	for sid in rows:
		var row: Array = rows[sid]
		var share := float(row[1]) / maxf(1.0, float(row[0]))
		var px: Array = row[2]
		px.sort()
		var tall := "-" if px.is_empty() else "%.0f / %.0f" % [px[0], px[px.size() / 2]]
		print("TUTHUD frame %s | %s | %.0f%% | %s" % [arch, sid, share * 100.0, tall])
		if sid in Tutorial.WALK_LEAD:
			ok(row[3], "%s %s: the place you walk to is on screen when you get there" % [arch, sid])
		else:
			ok(share >= ON_SHARE, "%s %s: its thing is on screen %.0f%% of the step" % [arch, sid, share * 100.0])
		if not px.is_empty():
			ok(float(px[px.size() / 2]) >= MIN_PX, "%s %s: drawn %s px tall" % [arch, sid, tall])
	ok(fm.player.extracted, arch + ": the framing run finishes the course")
	fm.queue_free()

## Where the thing a step asks you to act on stands (INF for a step on the HUD alone): a gap step's pad
## (you leave from it), else the step's goal.
func _act_at(tu: Tutorial, sid: String) -> Vector3:
	if sid in Tutorial.GAP_STEPS and tu.pad_sign(sid) != null:
		return tu.stop(sid, "pad")
	return tu.goal(sid)

## The thing itself, when there is one to measure (the ground stops have none).
func _act_node(tu: Tutorial, sid: String) -> Node3D:
	if sid in Tutorial.GAP_STEPS:
		return tu.pad_sign(sid)
	if sid in Tutorial.FOE_STEPS:
		var mb := tu.camps.nearest("sentinel" if sid == "hook" else "")
		if mb == null:
			mb = tu.camps.nearest()
		return mb.model if mb else null
	var item := tu.ground_item() if sid == "glove" else tu.outpost()
	return item.get("node") if sid in ["glove", "wayout", "uplink", "defend", "extract"] else null

func _on_screen(cam: Camera3D, at: Vector3) -> bool:
	if cam.is_position_behind(at):
		return false
	return Rect2(Vector2.ZERO, FRAME_VIEW).has_point(_to_view(cam, at))

## A world point on the 1280x720 screen.
func _to_view(cam: Camera3D, at: Vector3) -> Vector2:
	return cam.unproject_position(at) / cam.get_viewport().get_visible_rect().size * FRAME_VIEW

## How tall a thing is drawn on screen: a sign faces the camera, so its line's height; anything else, the
## height of its box's outline (seen from above, a flat monster's back counts, not just how high it stands).
func _tall_px(cam: Camera3D, node: Node3D) -> float:
	if node is Label3D:
		var lab := node as Label3D
		var half := cam.global_transform.basis.y * lab.font_size * lab.pixel_size * 0.5
		return absf(_to_view(cam, lab.global_position + half).y - _to_view(cam, lab.global_position - half).y)
	var box := _box(node)
	var lo := INF
	var hi := -INF
	for i in 8:
		var y := _to_view(cam, box.get_endpoint(i)).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return hi - lo

## The world box a node draws in: all its visible meshes.
func _box(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	for vi in node.find_children("*", "VisualInstance3D", true, false):
		if (vi as VisualInstance3D).is_visible_in_tree():
			box = box.merge((vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb())
	return box
