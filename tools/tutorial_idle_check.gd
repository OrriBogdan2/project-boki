extends RefCounted
## --tutorial-idle-check: nobody is ever left without a next thing to do (DECISIONS, First 10 minutes).
## Plays the match tutorial with its driver and, at every step, does nothing for IDLE_S seconds:
##   - a hint banner or the Boki lead is up within HINT_BY seconds, and the step's line stays on the pill
##   - a step with a place keeps its marker (beam, pin or edge arrow, and the distance label) every frame
##   - a nag (the pill and marker pulse, the Boki says it again) lands inside the window, so no wait
##     goes SILENT_MAX seconds without a prompt; the timed waits all outlast a nag
## Then the farm tutorial: each step, with everything before it done, shows its hint line for IDLE_S
## seconds and, where it has a place, keeps its world marker. One table row per step is printed.

const IDLE_S := 10.0      # s of doing nothing at each step
const HINT_BY := 8.0      # s: the banner or the Boki lead is up by then
const SILENT_MAX := 15.0  # s: nothing may wait this long without a prompt

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("IDLE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_match_course()
	await _farm_course()
	print("IDLE DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the match tutorial
func _match_course() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "tut_test": true,
			"demo_kin": "cindle"})
	m.set_process(false)
	var tu: Tutorial = m.tut
	ok(Tutorial.NAG_T < IDLE_S, "a nag comes inside the %.0f s window (NAG_T %.0f s)" % [IDLE_S, Tutorial.NAG_T])
	ok(Tutorial.NAG_T < SILENT_MAX, "and a nag comes before %.0f s of silence" % SILENT_MAX)
	var timed := {"RANK_WAIT_T": Tutorial.RANK_WAIT_T, "KEY_WAIT_T": Tutorial.KEY_WAIT_T,
			"KIN_WATCH_T": Tutorial.KIN_WATCH_T}
	for k in timed:
		ok(float(timed[k]) > Tutorial.NAG_T, "%s (%.0f s) outlasts a nag, so it never waits in silence" % [k, timed[k]])
	print("IDLE match | step | hint s | Boki | nag s | marker | note")
	var seen := {}
	var t := 0.0
	while t < 900.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		if tu.step >= 0 and tu.step < Tutorial.steps().size() and not seen.has(tu.step):
			seen[tu.step] = true
			_idle_step(m, tu)
	ok(seen.size() >= 15, "the idle window ran on %d steps" % seen.size())
	m.queue_free()

## Does nothing for IDLE_S s (or until the step ends by itself) and judges what the player saw.
func _idle_step(m: Match, tu: Tutorial) -> void:
	var sid := tu.id()
	var s0 := tu.step
	var p := m.player
	var hint_t := -1.0
	var nag_t := -1.0
	var boki := ""
	var lost := 0
	var frames := 0
	var no_text := 0
	var t := 0.0
	var has_place := tu.goal(sid) != Vector3.INF
	while t < IDLE_S and tu.step == s0 and not p.extracted:
		for k in ["fire", "glide", "interact", "crouch", "sec", "sig", "jump", "dash", "throw"]:
			p.inp[k] = false
		p.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
		t += Match.DT
		if tu.step != s0:
			break
		frames += 1
		var comp: KinCompanion = p.kin.comp if p.kin else null
		var says := m.bubbles.any(func(b): return b["ent"] == p.kin)
		var leads := comp != null and comp.leading()
		if boki == "" and (leads or says):
			boki = "lead" if leads else "says"
		if hint_t < 0.0 and (tu.card_up() or leads or says or tu.nag_t > 0.0):
			hint_t = t
		if nag_t < 0.0 and tu.nag_t > 0.0:
			nag_t = t
		if tu.text == "":
			no_text += 1
		if has_place and not (tu.target != Vector3.INF and tu.label != "" and tu.beams_on() > 0):
			lost += 1
	var early := tu.step != s0 or p.extracted
	var note := "ends by itself at %.1f s" % t if early else ""
	var hint_ok := (hint_t >= 0.0 and hint_t <= HINT_BY) or (early and t <= HINT_BY)
	var nag_ok := early or (nag_t >= 0.0 and nag_t <= minf(IDLE_S, SILENT_MAX))
	print("IDLE match | %s | hint %s | %s | nag %s | %s | %s" % [sid, _s(hint_t), boki if boki != "" else "-",
			_s(nag_t), _marker_note(has_place, lost), note])
	ok(hint_ok, "%s: a hint banner or the Boki lead is up within %.0f s (%s)" % [sid, HINT_BY, _s(hint_t)])
	ok(no_text == 0, "%s: the step's line stays on the pill (%d empty frames)" % [sid, no_text])
	ok(lost == 0, "%s: the marker stays up (beam, pin or arrow + distance), %d of %d frames lost" % [sid, lost, frames])
	ok(nag_ok, "%s: nothing waits silently, a nag lands by %.0f s (%s)" % [sid, SILENT_MAX, _s(nag_t)])

func _marker_note(has_place: bool, lost: int) -> String:
	if not has_place:
		return "n/a"
	return "kept" if lost == 0 else "LOST %d" % lost

func _s(v: float) -> String:
	return "%.1f" % v if v >= 0.0 else "never"

# ------------------------------------------------------------------ the farm tutorial
func _farm_course() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
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
	ok(FarmTutorial.active() and g != null, "the farm tutorial is running on a new save")
	print("IDLE farm | step.stage | hint | marker | note")
	var last := FarmTutorial.steps().size() - 1
	while FarmTutorial.done_count() < last and FarmTutorial.current() != "":
		var id := FarmTutorial.current()
		_idle_farm(g, id)
		if id == "house":
			ok(g.place_house(), "the house goes down as a site")
			home._sync_fixtures()
			_idle_farm(g, id)      # (the site is up: its "wait" hint)
		elif id == "hammer":
			FarmSites.finish(FarmHob.house_entry())      # (built, so the steps that wait for it open)
		FarmTutorial.mark(id)
	home.queue_free()
	await main.get_tree().process_frame

## Ticks the guide for IDLE_S s with the player still, on the step that is current, and judges it.
func _idle_farm(g: FarmGuide, id: String) -> void:
	g.refresh()
	var cur := FarmTutorial.current()
	var stage := FarmTutorial.stage(cur)
	var place := FarmTutorial.world_text(cur) != ""
	var hint_t := -1.0
	var lost := 0
	var t := 0.0
	while t < IDLE_S:
		g.tick(0.1)
		t += 0.1
		if hint_t < 0.0 and g.hint_visible() and g.hint_lbl.text != "":
			hint_t = t
		if place and not (is_instance_valid(g.marker) and g.marker.visible and g.marker.text != ""):
			lost += 1
	var tag := "%s.%s" % [cur, stage]
	print("IDLE farm | %s | hint %s | %s" % [tag, _s(hint_t), _marker_note(place, lost)])
	ok(cur == id, "%s: it is the step on show (%s)" % [id, cur])
	ok(hint_t >= 0.0 and hint_t <= HINT_BY, "%s: the hint line is up within %.0f s (%s)" % [tag, HINT_BY, _s(hint_t)])
	ok(lost == 0, "%s: the world marker stays up (%d ticks without)" % [tag, lost])
