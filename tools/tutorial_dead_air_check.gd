extends RefCounted
## --tutorial-dead-air-check: the player always knows what to do next (DECISIONS, First 10 minutes).
## A bot plays a fresh save through the farm tutorial and the match tutorial with each starter pick
## (Lace, Kael, Vex), and every frame is judged:
##   - dead air: no objective prompt and no visible marker. No span of it may pass GAP_MAX s.
##   - a step with a place never loses its marker for more than GAP_MAX s (beam or pin on the match
##     course, the "▼" label on the farm)
##   - two prompts never compete: on the match course no toast or Boki bubble speaks over a fresh
##     banner, and the intro card and the banner are not up together; on the farm the hint line and
##     the world marker are hidden together while you talk to Hob
## Runs on a throw-away save (Save.no_write). One table row per starter and course is printed.

const GAP_MAX := 4.0       # s: the longest the player may be left without a prompt or marker
const BOT_FARM_S := 6.0    # s the farm bot takes over each step before it does it
const SLOW_WAIT_S := 5.0   # s the slow player stands still at the start of each match step
const QUICK_QUIET_MAX := 5.0  # s: the longest a one-key or one-walk step (Tutorial.NAG_QUICK) may go quiet
const QUIET_MAX := 8.0     # s: the longest a slow player may go with nothing new to go on
const HAMMER_BEAT_S := 0.8  # s one hammer swing of yours takes (farm_build.json)
const MARKER_MOVE_M := 3.0  # m the marker has to shift to count as moving on
const STARTERS := {"Lace": "archer", "Kael": "juggernaut", "Vex": "gunslinger"}

var bad := 0
var main: Node
var gap := {}      # span -> s so far
var worst := {}    # span -> longest s
var quiet := []    # the stretches over QUIET_MAX s: "where | step | at s | long s"
var quick := {}    # step -> longest quiet s, for the steps in Tutorial.NAG_QUICK
var calm := 0.0    # s since something new showed
var last := {}     # what the player saw last frame: line, marker anchor, Boki and nag state
var farm_t := 0.0  # s on the farm so far

func ok(cond: bool, what: String) -> void:
	print("DEADAIR %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

## The lane's lines but a fallen Boki's (URGENT, the one kind a banner lets through).
func _lines(m: Match) -> Array[String]:
	return m.hud.msgs.texts().filter(func(t: String) -> bool: return not " is down  ·" in t)

func run(mn: Node) -> void:
	Settings.v["boki_wisps"] = false  # (walking-Boki rules: the wisp is the default now, see --wisp-check)
	FarmUnlocks.rules()["base_mode"] = false      # walks the old farm (base_mode is the shipped default)
	main = mn
	Save.no_write = true
	for who in STARTERS:
		await _farm(who, STARTERS[who])
		_match(who, STARTERS[who])
	for q in quiet:
		print("DEADAIR quiet | ", q)
	ok(quiet.is_empty(), "a slow player never goes %.0f s with nothing new (%d stretches)" % [QUIET_MAX, quiet.size()])
	for step in Tutorial.NAG_QUICK:
		var w := float(quick.get(step, 0.0))
		var what := "the %s step never goes more than %.0f s quiet (longest %.1f s)"
		ok(w <= QUICK_QUIET_MAX, what % [step, QUICK_QUIET_MAX, w])
	print("DEADAIR DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Counts a span of frames in which `lost` holds, and keeps the longest one.
func _span(key: String, lost: bool, dt: float) -> void:
	gap[key] = (float(gap.get(key, 0.0)) + dt) if lost else 0.0
	worst[key] = maxf(float(worst.get(key, 0.0)), float(gap[key]))

func _judge(tag: String, key: String, what: String) -> void:
	var w := float(worst.get(key, 0.0))
	ok(w <= GAP_MAX, "%s: %s for at most %.0f s (longest %.1f s)" % [tag, what, GAP_MAX, w])

func _reset() -> void:
	gap.clear()
	worst.clear()
	calm = 0.0
	last.clear()


## Adds dt to the quiet clock, or ends the quiet stretch when something new shows (logging one over QUIET_MAX).
func _calm(fresh: bool, dt: float, where: String, at: float) -> void:
	if not fresh:
		calm += dt
		worst["quiet"] = maxf(float(worst.get("quiet", 0.0)), calm)
		return
	var step := String(last.get("prev", ""))
	if step in Tutorial.NAG_QUICK:
		quick[step] = maxf(float(quick.get(step, 0.0)), calm)
	if calm > QUIET_MAX:
		quiet.append("%s | %s | at %.1f s | %.1f s" % [where, last.get("sid", "?"), at - calm, calm])
	calm = 0.0


## Whether the match tutorial shows the player something new this frame (the step or its line, the marker moving
## on, the Boki leading, speaking or nagging).
func _match_fresh(m: Match, tu: Tutorial) -> bool:
	var line := "%d|%s|%s" % [tu.step, tu.text, tu.label]
	var anchor: Vector3 = last.get("anchor", Vector3.INF)
	var moved := (tu.target == Vector3.INF) != (anchor == Vector3.INF)
	moved = moved or (anchor != Vector3.INF and anchor.distance_to(tu.target) > MARKER_MOVE_M)
	if moved or anchor == Vector3.INF:
		last["anchor"] = tu.target
	var comp: KinCompanion = m.player.kin.comp if m.player.kin else null
	var says := m.bubbles.any(func(b): return b["ent"] == m.player.kin)
	var nags := tu.nag_t > 0.0
	var fresh: bool = line != last.get("line", "") or moved or (comp != null and comp.leading())
	fresh = fresh or (says and not last.get("says", false)) or (nags and not last.get("nags", false))
	last["line"] = line
	last["says"] = says
	last["nags"] = nags
	last["prev"] = last.get("sid", "")
	last["sid"] = tu.id()
	return fresh

# ------------------------------------------------------------------ the match tutorial
func _match(who: String, arch: String) -> void:
	_reset()
	seed(11)
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "tut_test": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
			"demo_kin": "cindle", "arch": arch, "cls": Arch.weight(arch)})
	m.set_process(false)
	var tu: Tutorial = m.tut
	var tag := "%s match" % who
	var rival := 0
	var t := 0.0
	var steps_seen := {}
	var place_steps := 0
	var at_step := -1
	var wait := 0.0
	while t < 900.0 and not m.player.extracted:
		if tu.step != at_step:
			at_step = tu.step
			wait = SLOW_WAIT_S
		wait -= Match.DT
		if wait > 0.0:
			_stand_still(m.player)
		else:
			TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step < 0 or tu.step >= Tutorial.steps().size():
			continue
		_calm(_match_fresh(m, tu), Match.DT, tag, t)
		steps_seen[tu.id()] = true
		var prompt := tu.intro or tu.text != ""
		var marker := tu.target != Vector3.INF and tu.label != "" and tu.beams_on() > 0
		_span("m_dead", not prompt and not marker, Match.DT)
		if tu.goal(tu.id()) != Vector3.INF:
			place_steps += 1
			_span("m_marker", not marker, Match.DT)
		var loud: bool = m.hud != null and (_lines(m).size() > 0 or not m.bubbles.is_empty())
		if tu.intro and tu.text != "" or (tu.card_up() and loud):
			rival += 1
	ok(m.player.extracted, "%s: the course finishes (%d steps seen)" % [tag, steps_seen.size()])
	_judge(tag, "m_dead", "no span without a prompt or a marker")
	_judge(tag, "m_marker", "a step with a place keeps its marker (%d frames)" % place_steps)
	ok(rival == 0, "%s: no two prompts compete (%d frames)" % [tag, rival])
	print("DEADAIR match | %s | dead %.1f s | marker lost %.1f s | rival %d | quiet %.1f s" % [who,
			worst.get("m_dead", 0.0), worst.get("m_marker", 0.0), rival, worst.get("quiet", 0.0)])
	m.queue_free()

## The slow player's wait: no stick, no key.
func _stand_still(p) -> void:
	for k in TutorialDrive.KEYS:
		p.inp[k] = false
	p.inp["move"] = Vector2.ZERO


# ------------------------------------------------------------------ the farm tutorial
func _farm(who: String, arch: String) -> void:
	_reset()
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["arch"] = arch
	d["cls"] = Arch.weight(arch)
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	Save.d["stats"] = {"extracts": 0, "bosses": 0, "caught": 0, "harvested": 0, "hatched": 0, "fb_built": 0}
	var home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await main.get_tree().process_frame
	home._close_panel()
	var g: FarmGuide = home.guide
	var tag := "%s farm" % who
	ok(FarmTutorial.active() and g != null, "%s: the farm tutorial runs on the fresh save" % tag)
	var rival := 0
	var turns := 0
	while FarmTutorial.current() != "" and turns < 4 * FarmTutorial.steps().size():
		turns += 1
		var id := FarmTutorial.current()
		rival += _farm_step(g, id)
		if id == "house":
			g.place_house()
			home._sync_fixtures()
		elif id == "hammer":
			_hammer(g)
		elif id == "crop":
			rival += _crop_course(home, g)
		FarmTutorial.mark(id)
	ok(FarmTutorial.state()["done"], "%s: every step was shown, to the last (%d turns)" % [tag, turns])
	_judge(tag, "f_dead", "no span without a hint line or a marker")
	_judge(tag, "f_marker", "a step with a place keeps its marker")
	ok(rival == 0, "%s: no two prompts compete (%d ticks)" % [tag, rival])
	print("DEADAIR farm | %s | dead %.1f s | marker lost %.1f s | rival %d | quiet %.1f s" % [who,
			worst.get("f_dead", 0.0), worst.get("f_marker", 0.0), rival, worst.get("quiet", 0.0)])
	home.queue_free()
	await main.get_tree().process_frame

## The bot spends BOT_FARM_S s on the step on show (the guide ticking at 10 Hz), judged each tick.
## Returns the ticks in which two prompts competed.
func _farm_step(g: FarmGuide, id: String, expect_id := true) -> int:
	g.refresh()
	var cur := FarmTutorial.current()
	var place := FarmTutorial.world_text(cur) != ""
	var rival := 0
	var t := 0.0
	while t < BOT_FARM_S:
		g.tick(0.1)
		t += 0.1
		var hint: bool = g.hint_visible() and g.hint_box.visible and g.hint_text() != ""
		var marker: bool = is_instance_valid(g.marker) and g.marker.visible and g.marker.text != ""
		_span("f_dead", not hint and not marker, 0.1)
		if place:
			_span("f_marker", not marker, 0.1)
		farm_t += 0.1
		_calm(_farm_fresh(g, cur), 0.1, "farm", farm_t)
		# the same two checks while Hob is being talked to (the guide steps aside)
		g.set_quiet(true)
		if (g.hint_visible() and g.hint_box.visible) or (is_instance_valid(g.marker) and g.marker.visible):
			rival += 1
		g.set_quiet(false)
	ok(cur == id or not expect_id, "%s: it is the step on show (%s)" % [id, cur])
	return rival

## The slow player hammers the house up, one swing a beat, with the quiet clock running each tick.
func _hammer(g: FarmGuide) -> void:
	var e := FarmHob.house_entry()
	for m in ["wood", "stone"]:
		Work.add_mat(m, int(FarmSites.build_cost("house").get(m, 0)))
	var swings := 0
	while FarmSites.has_site(e) and swings < 100:
		swings += 1
		FarmSites.add_swing(e)
		var t := 0.0
		while t < HAMMER_BEAT_S:
			t += 0.1
			farm_t += 0.1
			g.tick(0.1)
			_calm(_farm_fresh(g, "hammer"), 0.1, "farm", farm_t)
	ok(not FarmSites.has_site(e), "hammer: the house goes up in %d swings" % swings)


## Whether the farm guide shows something new this tick (the step's line, or the world marker's words or place).
func _farm_fresh(g: FarmGuide, cur: String) -> bool:
	var shown := "%s|%s" % [g.hint_text(), g.marker.text if is_instance_valid(g.marker) and g.marker.visible else ""]
	var at: Vector3 = g.marker.position if is_instance_valid(g.marker) else Vector3.INF
	var anchor: Vector3 = last.get("anchor", Vector3.INF)
	var moved := at != Vector3.INF and (anchor == Vector3.INF or anchor.distance_to(at) > MARKER_MOVE_M)
	if moved:
		last["anchor"] = at
	var fresh: bool = shown != last.get("line", "") or moved
	last["line"] = shown
	last["sid"] = cur
	return fresh


## The crop step's stages after the patch hint: plant, water, wait for it to grow (another step may
## take the line meanwhile), pick. Returns the ticks in which two prompts competed.
func _crop_course(home, g: FarmGuide) -> int:
	var lay: Dictionary = HomeLayout.of(Save.d)
	var patch := {"u": HomeLayout._next_uid(lay), "id": "crop_patch", "x": 44, "z": 30, "r": 0}
	(lay["deco"] as Array).append(patch)
	(lay["water"] as Dictionary).clear()
	home._sync_fixtures()
	var rival := _farm_step(g, "crop")      # plant
	Save.d["plots"][0] = {"crop": "tidebloom", "stage": 0, "wt": 0.0}
	rival += _farm_step(g, "crop")      # water
	Save.d["plots"][0]["wt"] = 100.0
	rival += _farm_step(g, "crop", false)      # grow
	Save.d["plots"][0]["stage"] = int(Data.CROPS["tidebloom"]["grow"])
	return rival + _farm_step(g, "crop")      # pick
