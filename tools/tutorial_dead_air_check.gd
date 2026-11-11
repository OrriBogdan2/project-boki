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
const STARTERS := {"Lace": "archer", "Kael": "juggernaut", "Vex": "gunslinger"}

var bad := 0
var main: Node
var gap := {}      # span -> s so far
var worst := {}    # span -> longest s

func ok(cond: bool, what: String) -> void:
	print("DEADAIR %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	for who in STARTERS:
		await _farm(who, STARTERS[who])
		_match(who, STARTERS[who])
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
	while t < 900.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step < 0 or tu.step >= Tutorial.steps().size():
			continue
		steps_seen[tu.id()] = true
		var prompt := tu.intro or tu.text != ""
		var marker := tu.target != Vector3.INF and tu.label != "" and tu.beams_on() > 0
		_span("m_dead", not prompt and not marker, Match.DT)
		if tu.goal(tu.id()) != Vector3.INF:
			place_steps += 1
			_span("m_marker", not marker, Match.DT)
		var loud: bool = m.hud != null and (not m.hud.msgs.texts().is_empty() or not m.bubbles.is_empty())
		if tu.intro and tu.text != "" or (tu.card_up() and loud):
			rival += 1
	ok(m.player.extracted, "%s: the course finishes (%d steps seen)" % [tag, steps_seen.size()])
	_judge(tag, "m_dead", "no span without a prompt or a marker")
	_judge(tag, "m_marker", "a step with a place keeps its marker (%d frames)" % place_steps)
	ok(rival == 0, "%s: no two prompts compete (%d frames)" % [tag, rival])
	print("DEADAIR match | %s | dead %.1f s | marker lost %.1f s | rival %d" % [who, worst.get("m_dead", 0.0),
			worst.get("m_marker", 0.0), rival])
	m.queue_free()

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
			rival += _farm_step(g, id)      # (the site is up: its "wait" hint)
		elif id == "hammer":
			FarmSites.finish(FarmHob.house_entry())
		elif id == "crop":
			rival += _crop_course(home, g)
		FarmTutorial.mark(id)
	ok(FarmTutorial.state()["done"], "%s: every step was shown, to the last (%d turns)" % [tag, turns])
	_judge(tag, "f_dead", "no span without a hint line or a marker")
	_judge(tag, "f_marker", "a step with a place keeps its marker")
	ok(rival == 0, "%s: no two prompts compete (%d ticks)" % [tag, rival])
	print("DEADAIR farm | %s | dead %.1f s | marker lost %.1f s | rival %d" % [who, worst.get("f_dead", 0.0),
			worst.get("f_marker", 0.0), rival])
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
		var hint: bool = g.hint_visible() and g.hint_box.visible and g.hint_lbl.text != ""
		var marker: bool = is_instance_valid(g.marker) and g.marker.visible and g.marker.text != ""
		_span("f_dead", not hint and not marker, 0.1)
		if place:
			_span("f_marker", not marker, 0.1)
		# the same two checks while Hob is being talked to (the guide steps aside)
		g.set_quiet(true)
		if (g.hint_visible() and g.hint_box.visible) or (is_instance_valid(g.marker) and g.marker.visible):
			rival += 1
		g.set_quiet(false)
	ok(cur == id or not expect_id, "%s: it is the step on show (%s)" % [id, cur])
	return rival

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
