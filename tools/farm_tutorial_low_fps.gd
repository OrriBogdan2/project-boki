extends "res://tools/farm_tutorial_check.gd"
## --farm-tutorial-check --tutorial-low-fps: the garden tutorial (meet, patch, eat, toy, out) played to its end in
## the home's own frame loop on the Low preset (docs/DECISIONS 2026-11-08), once at a 30 fps cap and once at 60 fps
## with a 100 ms stall every 5th frame. No step is ticked by hand: the guide's own poll, your Boki's lead and the
## toy's play session have to move each step on, and every step must do so within STEP_CAP_S.
## Only what the player does is injected (walk up to the Boki, drop the patch, feed it, put a toy down, use the portal).

const TC := preload("res://tools/tutorial_check.gd")
const STEP_CAP_S := 60.0  # s a step may take (the check's own clock: CheckClock)
const FAR_M := 8.0  # m: standing this far from your Boki is not meeting it
const NEAR_M := 1.0  # m: next to it
const IDLE_FRAMES := 45  # frames far away: the meet step must stay put

var frames := 0
var stall := false


func run(m: Node, _mode := "") -> void:
	main = m
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var quality_was = Settings.v.get("quality", "auto")
	Settings.v["quality"] = "low"
	Settings.apply("quality")
	ok(Settings.quality() == "low", "the garden rounds run on the Low preset")
	for r in TC.LOW_ROUNDS:
		await _round(String(r[0]), int(r[1]), bool(r[2]))
	Settings.v["quality"] = quality_was
	Settings.apply("quality")
	print("FTUT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _round(label: String, fps: int, stalled: bool) -> void:
	var home = await _home(1)
	var k: Dictionary = home.kins[0]
	var guide: FarmGuide = home.guide
	stall = stalled
	frames = 0
	Engine.max_fps = fps
	var t0 := Time.get_ticks_msec()
	var took := {}
	home.ppos = k["node"].position + Vector3(FAR_M, 0, 0)
	for i in IDLE_FRAMES:
		await _frame()
	ok(FarmTutorial.current() == "meet", "%s: far from your Boki is not meeting it" % label)
	home.ppos = k["node"].position + Vector3(NEAR_M, 0, 0)
	took["meet"] = await _until("patch")
	var hl := HomeLayout.of(Save.d)
	(hl["deco"] as Array).append({"u": HomeLayout._next_uid(hl), "id": SnackPatch.ID, "x": 44, "z": 30, "r": 0})
	took["patch"] = await _until("eat")
	ok(_berries() == 3, "%s: the patch down hands over the food" % label)
	home._after_feed(k, "emberberry", Care.feed(k["rec"], "emberberry"))
	took["eat"] = await _until("toy")
	guide.place_toy()
	home.ppos = k["node"].position + Vector3(NEAR_M, 0, 0)
	took["toy"] = await _until("out")
	var portal: Vector3 = home.spots["portal"]
	ok(guide.target("out") == portal, "%s: head out marks the portal" % label)
	FarmTutorial.event("portal")  # (Home._open_expedition's first call)
	ok(not FarmTutorial.active(), "%s: using the portal ends the tutorial" % label)
	var ms := float(Time.get_ticks_msec() - t0) / maxi(frames, 1)
	print("FTUT LOW %s: %d frames, %.1f ms a frame, step times %s" % [label, frames, ms, _secs(took)])
	if not stalled:
		ok(ms >= 1000.0 / TC.LOW_CAP_FPS * 0.85, "%s: frames capped at %d fps" % [label, TC.LOW_CAP_FPS])
	Engine.max_fps = 0
	home.queue_free()
	await main.get_tree().process_frame


## One frame of the home's own loop, with this round's stall.
func _frame() -> void:
	await main.get_tree().process_frame
	frames += 1
	if stall and frames % TC.LOW_STALL_EVERY == 0:
		OS.delay_msec(TC.LOW_STALL_MS)


## Frames until the tutorial's current step is `next`; the seconds it took, or -1 past STEP_CAP_S.
func _until(next: String) -> float:
	var t0 := CheckClock.own_msec()
	while FarmTutorial.current() != next:
		if CheckClock.own_msec() - t0 > STEP_CAP_S * 1000.0:
			ok(false, "%s never reached after %.0f s (stuck at %s)" % [next, STEP_CAP_S, FarmTutorial.current()])
			return -1.0
		await _frame()
	ok(true, "%s reached after %.1f s" % [next, (CheckClock.own_msec() - t0) / 1000.0])
	return (CheckClock.own_msec() - t0) / 1000.0


func _secs(took: Dictionary) -> String:
	var out := []
	for id in took:
		out.append("%s %.1f s" % [id, took[id]])
	return ", ".join(out)
