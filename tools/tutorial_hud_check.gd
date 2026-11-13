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

var bad := 0
var m: Match
var main: Node

const SIZES := [Vector2(1280, 720), Vector2(1920, 1080), Vector2(3440, 1440)]

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
	var talk_at := -1.0
	var ran_in_talk := 0
	var not_in_box := 0
	var ahead := {}
	var rv := {}
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
			counters[tu.id()] = tu.progress_text()
		if not texts.has(tu.id()):
			texts[tu.id()] = tu.text
		step_t += Match.DT
		_rival_probe(tu, rv)
		if tu.pell.talking():
			talk_at = m.time if talk_at < 0.0 else talk_at
			ran_in_talk += int(m.time != talk_at)
			not_in_box += int(not is_instance_valid(tu.pell.box) or tu.pell.box.get_parent() != m.hud)
		else:
			talk_at = -1.0
			var g := tu._lead_goal(tu.id())
			var to_g := func(at: Vector3): return Vector2(g.x - at.x, g.z - at.z).length()
			var near: bool = g != Vector3.INF and to_g.call(tu.pell.pos) < 2.5
			if near or g != Vector3.INF and to_g.call(tu.pell.pos) < to_g.call(m.player.pos) - 1.0:
				ahead[tu.id()] = true
		if m.hud == null:
			continue
		if tu.card_up():
			toast_in_card += m.hud.msgs.texts().size()
			bubble_in_card += m.bubbles.size()
			under += _under_banner()
		elif not m.hud.msgs.texts().is_empty():
			shown_after += 1
			m.hud.msgs.clear()
	print("TUTHUD course %.1fs of play, %d steps" % [t, Tutorial.steps().size()])      # (the before/after timing)
	ok(m.player.extracted, "the course still finishes")
	var pl := tu.pell
	ok(pl.beacon != null and pl.beacon.wants_arrow, "Pell wears a beacon (glow, name, edge arrow)")
	var stops := Tutorial.steps().all(func(st): return String(st[0]) in pl.talked)
	ok(stops and pl.talked.size() == Tutorial.steps().size(),
		"Pell stops you before each new thing (%s)" % ", ".join(pl.talked))
	ok(ran_in_talk == 0 and not_in_box == 0, "the match holds while Pell talks, in the dialogue box"
		+ " (%d frames ran, %d without the box)" % [ran_in_talk, not_in_box])
	var led := ["dash", "chest", "extract"].all(func(x): return ahead.has(x))
	ok(led, "Pell flies ahead to the pad, the chest and the outpost (%s)" % str(ahead.keys()))
	ok(toast_in_card == 0, "no toast shows while a banner is up (%d seen)" % toast_in_card)
	ok(bubble_in_card == 0, "no Boki bubble shows while a banner is up (%d seen)" % bubble_in_card)
	var waited := "(%d asked, %d shown)" % [asked, shown_after]
	ok(asked > 0 and shown_after > 0, "a toast fired during a banner waits and shows after it " + waited)
	ok(under == 0, "the hunter and the Boki are never under the banner (%d frames)" % under)
	ok(worst < 45.0, "no step took more than 45s of plain play (%.0fs)" % worst)
	ok(Tutorial.steps().size() == 10 and texts.size() == 10, "10 steps, 10 banner lines (%s)" % str(texts.keys()))
	_rival_beats(tu, rv)
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

## Beats 7 and 8, noted frame by frame while the driver plays them (rv collects what was seen).
func _rival_probe(tu: Tutorial, rv: Dictionary) -> void:
	var r := tu.rival
	if r.h == null:
		return
	if not rv.has("hp"):
		rv["hp"] = r.h.hp / r.h.max_hp
		rv["dmg"] = float(r.h.ai["diff"]["dmg"])
		rv["wisp"] = r.wisp != null
	if r.phase == TutorialRival.Phase.LOOSE and not rv.has("slow"):
		rv["slow"] = m.slowmo > 0.0
		rv["round"] = r.h.downed and not r.h.out      # (HunterWisp draws it in a render frame)
		rv["labels"] = r._labels.map(func(l): return String(l.text))
		rv["loose_m"] = r.h.pos.distance_to(r.loose_at)
	if r.phase == TutorialRival.Phase.LOOSE and not tu.card_up() and tu.id() == "grab" and not rv.has("told"):
		_walk_to_round_wisp_first(r, rv)
	if r.phase == TutorialRival.Phase.CARRIED:
		rv["carried"] = r.wisp.position.distance_to(m.player.pos)
		rv["tether"] = r._tether != null and r._tether.visible and r.wisp.get_child_count() > 3
	if r.h.out or r.phase == TutorialRival.Phase.GONE:
		rv["gone"] = r.carried_t

## Standing at the round wisp and holding interact shows the toast and grabs nothing.
func _walk_to_round_wisp_first(r: TutorialRival, rv: Dictionary) -> void:
	var p := m.player
	var back := p.pos
	p.teleport(r.h.pos + Vector3(1.0, 0.0, 0.0))
	p.inp["interact"] = true
	r.hold = 0.0
	r.tick(0.0)
	rv["told"] = r.told
	rv["held"] = r.hold
	rv["phase"] = r.phase
	p.teleport(back)

func _rival_beats(tu: Tutorial, rv: Dictionary) -> void:
	var cfg: Dictionary = tu.rival.cfg
	var hp := float(rv.get("hp", 1.0))
	var want_hp := float(cfg["hp"])
	ok(absf(hp - want_hp) < 0.01, "the rival glides in at %d%% health (%.2f)" % [int(want_hp * 100), hp])
	var dmg := float(rv.get("dmg", 1.0))
	ok(dmg <= 0.1 and bool(rv.get("wisp", false)), "it fights at tutorial damage (%.2f) with its own Boki wisp" % dmg)
	var popped: bool = bool(rv.get("slow", false)) and bool(rv.get("round", false))
	ok(popped, "on the knock time slows and it pops into the round Hunter Wisp")
	var labels: Array = rv.get("labels", [])
	var named: bool = labels.size() == 2 and String(labels[0]) == "Hunter: can't be taken"
	ok(named and String(labels[1]).begins_with("Boki: hold "), "both wisps are labelled (%s)" % str(labels))
	var apart := float(rv.get("loose_m", 0.0))
	ok(apart > 3.0, "the loose Boki wisp floats clear of the Hunter Wisp, out of stomp reach (%.1fm)" % apart)
	var toast_ok: bool = bool(rv.get("told", false)) and float(rv.get("held", 1.0)) == 0.0
	var still_loose: bool = rv.get("phase") == TutorialRival.Phase.LOOSE
	ok(toast_ok and still_loose, "walking to the round wisp first shows the toast and grabs nothing")
	var orbit := float(rv.get("carried", 99.0))
	var carried: bool = orbit < 3.0 and bool(rv.get("tether", false))
	ok(carried, "the grabbed wisp orbits you with a ring and tether (%.1fm)" % orbit)
	var gone := float(rv.get("gone", 0.0))
	ok(gone >= float(cfg["gone_s"]), "the downed rival is gone %ds after the grab (%.1fs)" % [cfg["gone_s"], gone])

## Two falls on the gap step bring the plain help line; a downed Boki never passes the Boki step.
func _gap_help_and_downed(tu: Tutorial) -> void:
	var ids := Tutorial.steps().map(func(st): return String(st[0]))
	tu.step = ids.find("dash")
	tu.falls = 2
	tu._words()
	ok(tu.text.begins_with("Just jump"), "two falls on the gap step show the plain help ('%s')" % tu.text)
	tu.step = ids.find("throw")
	tu.falls = 0
	tu.recalled = false
	tu.need_back = false
	tu.throws0 = m.player.kin.st_throws
	m.player.kin.state = "downed"
	ok(not tu._is_done("throw"), "a downed Boki does not pass the Boki step")

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
