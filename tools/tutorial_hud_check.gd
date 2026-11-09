extends RefCounted
## --tutorial-hud-check: the tutorial shows one voice at a time, in its own lanes.
##   1. the lanes at 1280x720 and 1920x1080: the banner is at most 35% of the width and 10% of the
##      height, no two lanes (banner, pill, check, toasts, intro) intersect, none sits in the middle
##   2. a scripted run of the whole course (the driver, with a Boki): while the banner is up no toast is
##      showing (one fired at each step start waits and then shows) and no Boki bubble is up; the
##      hunter and the Boki are never under the banner
##   3. the pill counter, the right click taught from its kit data, the Boki step by its state
##   4. the lookout: every course stop is climbable from the one before it with plain movement

var bad := 0
var m: Match
var main: Node

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080)]

func ok(cond: bool, what: String) -> void:
	print("TUTHUD %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_lanes()
	_course()
	_reach()
	print("TUTHUD DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. the lanes
func _lanes() -> void:
	for sz: Vector2 in SIZES:
		var ln := TutorialHud.lanes(sz)
		var b: Rect2 = ln["banner"]
		var tag := "%dx%d" % [sz.x, sz.y]
		var small: bool = b.size.x <= sz.x * 0.35 + 0.5 and b.size.y <= sz.y * 0.10 + 0.5
		ok(small, "%s: the banner is at most 35%% x 10%% of the screen (%s)" % [tag, str(b.size)])
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

# ------------------------------------------------------------------ 2, 3. a run of the course
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
	var counts_ok: bool = String(counters.get("shoot", "")) == "0/3" and String(counters.get("sig", "")) == "0/2"
	ok(counts_ok, "the pill counts hits and casts (%s)" % str(counters))
	var ak: ArchKit = m.player.ak
	if ak != null:
		var hold := float(ak.rmb_def().get("hold", 0.0)) > 0.0
		var why := "(%s hold %s)" % [ak.id, str(hold)]
		ok(tu.rmb_has_hold() == hold, "the right click step follows the kit's hold variant " + why)
		var line := String(texts.get("utility", ""))
		ok(line.to_lower().contains("hold") == hold, "and its words say so ('%s')" % line)
	var tl := String(texts.get("throw", ""))
	ok(tl.contains("call") or tl.contains("send"), "the Boki step says whether to call back or send ('%s')" % tl)

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

# ------------------------------------------------------------------ 4. every stop can be reached
## From each stop to the next on the same island, plain walking: no step up taller than half a jump.
func _reach() -> void:
	var tu: Tutorial = m.tut
	var jump_apex := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV)
	var order := ["land", "move", "dash", "exdash", "glide", "crouch", "pickup", "yard", "chest"]
	var worst := 0.0
	var worst_at := ""
	for i in range(1, order.size()):
		var a := tu.stop(order[i - 1])
		var b := tu.stop(order[i])
		if a == Vector3.INF or b == Vector3.INF:
			continue
		if m.world.island_of(a.x, a.z) != m.world.island_of(b.x, b.z):
			continue      # (a gap: the dash, jump and glide steps and the bridges, which the run above plays)
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
	ok(cr.y <= jump_apex * 0.6, "the lookout top is %.2fm up, under 60%% of a jump (%.2fm)" % [cr.y, jump_apex])
