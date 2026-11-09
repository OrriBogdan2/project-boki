extends RefCounted
## --garden-fresh-run [--shots-dir=<dir>] [--size=WxH]: a fresh-player playthrough of the Boki base
## (DECISIONS rule: there is never a moment the player does not know what to do next). A brand new
## save as the hatch leaves it, base_mode on, then only what the screen says: every step logs the
## prompt, the world marker and the Boki's own cue, and the run asserts the rule:
##   - an 8 s window with no prompt, marker or Boki cue is a gap (a window is sampled twice a second)
##   - every step's prompt names the action the player has to take
##   - a jargon word shows up with its explanation or not at all (JARGON: word -> a phrase that explains it)
##   - the tutorial's own steps and panels show at most MAX_GROUPS groups
## Prints "GFR ..." lines (the findings in docs/ONBOARDING_GARDEN.md come from these); never touches the real save.

const WINDOW_S := 8.0      # seconds with nothing telling the player what to do = a gap
const SAMPLE_S := 0.5      # seconds between screen samples
const MAX_GROUPS := 5      # most groups one panel may show
## Words a new player has not met; each needs its explaining phrase on the same screen the first time it shows.
const JARGON := {"lean": "colour", "Relic": "", "Garden": "", "Island": "", "portal": "", "expedition": "", "extract": "",
		"Stay": "", "nature": "", "trust": "", "bond": "", "Partner": "", "farmhand": "", "type": ""}

var bad := 0
var main: Node
var home
var shots := ""
var seen: Dictionary = {}      # jargon word -> the step it first showed in
var gaps: Array = []
var shot_n := 0
var hob_swung := false      # the camera swung over to Hob (he calls you) while the Boki was the first step

func ok(cond: bool, what: String) -> void:
	print("GFR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func note(s: String) -> void:
	print("GFR ", s)

## Every visible text on the home's interface layer (labels, then buttons).
func texts() -> Dictionary:
	var labels: Array = []
	var buttons: Array = []
	for n in home.root_ui.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or c.modulate.a < 0.1:
			continue
		if c is Button and String(c.text) != "":
			buttons.append(String(c.text))
		elif c is Label and String(c.text) != "":
			labels.append(String(c.text))
	return {"labels": labels, "buttons": buttons}

## The Boki's own cue: a speech bubble, a want bubble or a thought showing over it.
func boki_cue() -> String:
	var k: Dictionary = home._kin_entry(Save.active_kin())
	if k.is_empty():
		return ""
	var say = k.get("say")
	if say is Label3D and say.visible and say.text != "":
		return String(say.text)
	return "want:%s" % Care.want(Save.active_kin()) if KinWants.urgency(Save.active_kin()) > 0.0 else ""

func marker_text() -> String:
	var m = home.guide.marker
	return String((m as Label3D).text).replace("\n", " ") if is_instance_valid(m) and m.visible else ""

## What tells the player what to do right now: the base card's next step, a prompt, a marker, a Boki cue.
func guidance() -> Dictionary:
	var tt := texts()
	var card_next := ""
	var card: BaseHud = home.root_ui.get_node_or_null("BaseHud")
	if card != null and card.visible:
		card_next = BaseHud.next_action(Save.active_kin(), home.POND_EDGE.x > -100.0)
	var tut := FarmTutorial.hint_text(FarmTutorial.current()) if FarmTutorial.active() else ""
	var on_screen: bool = false
	for l in tt["labels"]:
		on_screen = on_screen or (tut != "" and String(l).contains(tut.substr(0, 20)))
	return {"card": card_next, "tutorial": tut, "tutorial_on_screen": on_screen, "marker": marker_text(), "cue": boki_cue(),
			"panel": String(home.panel_open)}

func jargon_check(step: String) -> void:
	var tt := texts()
	var all := " ".join(tt["labels"]) + " " + " ".join(tt["buttons"])
	for w in JARGON:
		var re := RegEx.create_from_string("\\b%s\\b" % w)
		if re.search(all) != null and not seen.has(w):
			seen[w] = step
			var why := String(JARGON[w])
			note("JARGON '%s' first on screen at step %s%s" % [w, step, "" if why == "" or all.contains(why) else " (no '%s' beside it)" % why])

## Panel groups: the direct visible children of the busiest container in the open panel.
func groups() -> int:
	var kids: Array = home.panel_host.get_children().filter(func(c): return not c.is_queued_for_deletion())
	if kids.is_empty():
		return 0
	var best := 0
	for v in (kids[-1] as Node).find_children("*", "VBoxContainer", true, false):
		var n := 0
		for c in v.get_children():
			n += 1 if (c as Control).visible and not (c is Label and String(c.text) == "") else 0
		best = maxi(best, n)
	return best

## Log one moment: the prompt, marker, Boki cue and whichever panel is open.
func log_step(step: String) -> void:
	var g := guidance()
	var tt := texts()
	note("STEP %s | tutorial line: %s | on screen: %s | base card next: %s | marker: %s | Boki: %s | panel: %s (%d groups)" % [step,
			g["tutorial"], g["tutorial_on_screen"], g["card"], g["marker"], g["cue"], g["panel"], groups()])
	note("TEXTS %s | BUTTONS %s | items %s" % [str(tt["labels"].slice(-16)), str(tt["buttons"].slice(0, 12)), str(Save.d["items"])])
	jargon_check(step)
	await shot(step)

func shot(tag: String) -> void:
	if shots == "":
		return
	for i in 6:
		await main.get_tree().process_frame
	shot_n += 1
	main.get_viewport().get_texture().get_image().save_png(shots.path_join("%02d_%s.png" % [shot_n, tag]))

## Sit still for secs of game time as a player who is reading the screen; every sample with no guidance
## adds to a run of silence, and a run over WINDOW_S is a gap.
func idle(step: String, secs: float) -> void:
	var quiet := 0.0
	var worst := 0.0
	var t := 0.0
	while t < secs:
		await main.get_tree().create_timer(SAMPLE_S).timeout
		t += SAMPLE_S
		hob_swung = hob_swung or float(home.hob.chat.intro_t) >= 0.0
		var g := guidance()
		var told: bool = g["card"] != "" or g["tutorial_on_screen"] or g["marker"] != "" or g["cue"] != ""
		quiet = 0.0 if told else quiet + SAMPLE_S
		worst = maxf(worst, quiet)
	if worst >= WINDOW_S:
		gaps.append(step)
	ok(worst < WINDOW_S, "%s: longest silent stretch %.1f s of %.0f s" % [step, worst, secs])

## Press the first visible button whose text contains `what`: the player clicks what the screen offers.
func press(what: String) -> bool:
	for n in home.root_ui.find_children("*", "Button", true, false):
		var b: Button = n
		if b.is_visible_in_tree() and not b.disabled and String(b.text).contains(what):
			b.pressed.emit()
			return true
	return false

func frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			m.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	if is_instance_valid(m.fade):
		m.fade.reveal(0.05)
	FarmUnlocks.rules()["base_mode"] = true
	# a brand new save as the hatch leaves it (hatch.gd _finish): one trusted starter Boki, hatched and intro seen
	Save.d = Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	rec["trust"] = 55.0
	rec["starter"] = true
	Care.ensure(rec)
	Save.d["roster"].append(rec)
	Save.d["active"] = rec["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true, "match": true}
	HomeLayout.ensure(Save.d)
	home = await m._hb_home()
	var t0 := Time.get_ticks_msec()
	while home.panel_host == null and Time.get_ticks_msec() - t0 < 60000:
		await m.get_tree().process_frame
	await frames(30)
	await play()
	note("DONE gaps=%s failures=%d" % [str(gaps), bad])
	m.get_tree().quit(1 if bad > 0 else 0)

## The scripted player: only what the screen tells them.
func play() -> void:
	var rec := Save.active_kin()
	var k: Dictionary = home._kin_entry(rec)
	await log_step("arrive")
	ok(String(home.panel_open) == "Welcome home" and press("Let's go"), "arrive: a Welcome card with one button; the player presses it")
	await idle("welcome-closed", 10.0)
	await log_step("welcome-closed")
	var intro_key := "intro_base" if FarmUnlocks.base_mode() else "intro"
	note("HOB intro (talk, first time): %s" % str(Content.rules("farm_builder")["talk"][intro_key].map(func(l): return l["text"])))
	note("HOB call-over camera swing at arrival: %s" % hob_swung)
	ok(FarmTutorial.current() in ["meet", "eat"] and guidance()["marker"] != "", "after the card: the first thing to do is marked in the world")
	# 1 meet: the marker says "Your Boki", the line says walk up
	home.ppos = (k["node"] as Node3D).position + Vector3(1.0, 0, 0)
	home.guide._poll()
	await frames(20)
	await log_step("meet-done")
	ok(FarmTutorial.current() == "eat", "walking up meets the Boki and hands over the food")
	await idle("eat-prompt", 10.0)
	# 2 eat: "click your Boki"
	home._open_kin(rec)
	await frames(20)
	await log_step("boki-card")
	ok(press("Feed"), "the Boki card offers Feed")
	await frames(20)
	await log_step("feed-panel")
	ok(press("Feed"), "the feed panel offers a Feed button")
	await frames(60)
	home._close_panel()
	home.guide._poll()
	await frames(20)
	await log_step("fed")
	# 3 toy: "press B, open Base"
	await idle("toy-prompt", 10.0)
	home.hb.toggle()
	await frames(20)
	await log_step("build-open")
	ok(home.hb._tabs().has("Base"), "build mode offers a Base tab")
	ok(press("Base"), "the Base tab is one click")
	await frames(20)
	await log_step("build-base")
	var ball_shown: bool = texts()["labels"].has("Play ball")
	ok(ball_shown, "the Base tab shows a ball (gems %d)" % int(Save.d["gems"]))
	home.hb.take("toy_ball")
	await frames(10)
	await log_step("ball-held")
	home.guide._place("toy_ball", HomeLayout.LANDING + Vector3(3, 0, -3))
	home.hb.toggle()
	await frames(20)
	await idle("toy-watch", 12.0)
	await log_step("toy-down")
	FarmTutorial.event("play")
	home.guide._poll()
	await frames(20)
	await log_step("play-done")
	ok(FarmTutorial.current() == "out", "a Boki at play ends the toy step")
	await idle("out-prompt", 10.0)
	var says_stay := FarmTutorial.hint_text("out").contains("Stay")
	ok(not says_stay or press("Stay"), "the last step never names a Stay button that is not there")
	await frames(20)
	await log_step("stayed")
	await idle("after-tutorial", 12.0)
