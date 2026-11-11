extends RefCounted
## --new-player-flow-check: the whole new-player path on one fresh save, screen to screen, driven by the
## same drivers the other checks use (nothing is jumped over by setting save flags):
##   prologue (held to skip) -> hatch (card, look, egg pick, knocks, the Boki's look, naming) -> the first
##   Relic -> the tutorial match (TutorialDrive) -> results -> the farm (its tutorial walked step by step)
##   -> Hob's second Relic -> the first expedition, played to the skiff.
## Also the skip paths: "Skip the tutorial" on the naming card, and skipping the farm tutorial.
## Every wait has a limit: a step that does not move on in time is a stall and fails the check. Each stage
## prints how long it took. Never touches the real save.

const STALL_S := 60.0      # s a screen may take to offer its next step before it counts as stalled
const PREMATCH_STALL_S := 120.0      # s the pre-match countdown may take
const EXPEDITION_SEED := 4242      # a fixed map and drop, so the driver's landing is the same every run
const DROP_S := 90.0      # s of game time the opening drop may take
const SIM_STALL_S := 45.0      # s of game time one tutorial step may take (as --tutorial-hud-check)
const COURSE_S := 900.0      # s of game time the whole tutorial course may take

var bad := 0
var main: Node
var tree: SceneTree
var stage_name := ""
var stage_start := 0
var timings: Array = []

func ok(cond: bool, what: String) -> void:
	print("NPF %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	tree = main.get_tree()
	Save.no_write = true
	Save.d = Save.fresh()
	main.get_window().size = Vector2i(1280, 720)
	await _prologue()
	await _hatch()
	var home = await _tutorial_match()
	await _farm_tutorial(home)
	await _second_relic(home)
	await _first_expedition(home)
	await _skip_paths()
	print("NPF TIMES (s): " + ", ".join(timings))
	print("NPF DONE, failures: %d" % bad)
	tree.quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ helpers
func _begin(stage: String) -> void:
	_end()
	stage_name = stage
	stage_start = Time.get_ticks_msec()

func _end() -> void:
	if stage_name != "":
		timings.append("%s %.1f" % [stage_name, (Time.get_ticks_msec() - stage_start) / 1000.0])
	stage_name = ""

## Waits for `cond` (frames at a time) up to `secs`; a miss is a stall.
func _wait(cond: Callable, what: String, secs := STALL_S) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		await tree.process_frame
	var got: bool = cond.call()
	if not got:
		print("NPF STALLED in '%s' on screen %s" % [stage_name, main.current])
	ok(got, "%s (%.1f s)" % [what, (Time.get_ticks_msec() - t0) / 1000.0])
	if not got:
		_end()
		print("NPF TIMES (s): " + ", ".join(timings))
		print("NPF DONE, failures: %d" % bad)
		tree.quit(1)
		await tree.process_frame
	return got

func _button(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree() and not (b as Button).disabled:
			return b
	return null

## A real button the player can see: says so, and presses it.
func _press(root: Node, text: String) -> bool:
	var b := _button(root, text)
	ok(b != null, "there is a way forward: '%s'" % text)
	if b != null:
		b.pressed.emit()
	return b != null

func _child_of(parent: Node, type_name: String) -> Node:
	for c in parent.get_children():
		if c.get_class() == type_name or (c.get_script() != null and c.get_script().get_global_name() == type_name):
			return c
	return null

func _match_running() -> bool:
	var m := main.current as Match
	return m != null and m.player != null and m.is_processing()

func _is_screen(file: String) -> bool:
	return is_instance_valid(main.current) and main.current.get_script() != null \
		and String(main.current.get_script().resource_path).ends_with(file)

func _key(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e

# ------------------------------------------------------------------ 1. the prologue
func _prologue() -> void:
	_begin("prologue")
	await main.show_screen("prologue", {"then": "hatch"})
	if main.fade:
		main.fade.reveal(0.05)
	var pr = main.current
	ok(pr != null and "shots" in pr, "the prologue opens")
	var watched := 0.0
	for s in pr.shots:
		watched += float(s["dur"])
	print("NPF the prologue runs %.0f s if watched" % watched)
	var skips: Array = pr.find_children("*", "HoldSkip", true, false)
	ok(skips.size() == 1, "it can be skipped (hold Esc)")
	(skips[0] as HoldSkip).skipped.emit()
	await _wait(func(): return _is_screen("hatch.gd"), "the skipped prologue lands on the hatch")
	ok(bool(Save.d["tutorial"].get("prologue", false)), "and is remembered as seen")

# ------------------------------------------------------------------ 2. the hatch, the egg, the first Relic
func _hatch() -> void:
	_begin("hatch: card and look")
	var hx = main.current
	await _wait(func(): return hx.stage == "intro", "the hatch opens on its card")
	_press(hx, String(hx.CARD_BUTTON))
	await _wait(func(): return hx.stage == "create", "then you make yourself")
	ok(_button(hx, "Random") != null, "with a Random button as well")
	_press(hx, "Looks good")
	await _wait(func(): return hx.stage == "pick", "then the eggs")
	_begin("hatch: egg pick and knocks")
	_press(hx, "This one")
	var chosen: int = hx.chosen
	ok(chosen >= 0 and _button(hx, "Hatch it") != null, "choosing an egg offers 'Hatch it'")
	_press(hx, "Hatch it")
	await _wait(func(): return hx.stage == "warm", "the egg waits for knocks")
	for i in hx.TAPS:
		hx._unhandled_input(_key("jump"))
		await tree.create_timer(0.25).timeout
	await _wait(func(): return hx.stage == "reveal", "seven knocks hatch it")
	_begin("hatch: its look and naming")
	await _wait(func():
		var rv := _child_of(hx, "KinReveal") as KinReveal
		return rv != null and rv.met, "the new Boki meets you")
	(_child_of(hx, "KinReveal") as KinReveal).name_btn.pressed.emit()
	await _wait(func(): return hx.stage == "name", "then it can be named")
	ok(_button(hx, "Skip the tutorial") != null, "the naming card offers 'Skip the tutorial' as well")
	_press(hx, "Head out together")
	await _relic(hx)

## The first Relic: it drifts in, is put on, its page is read, and "Into the portal" goes on.
func _relic(hx) -> void:
	_begin("first Relic")
	await _wait(func(): return _child_of(hx, "MaskMoment") != null, "naming leads into the first Relic")
	var moment := _child_of(hx, "MaskMoment") as MaskMoment
	await _wait(func(): return moment.phase == "wait", "the Relic waits by your face")
	moment._unhandled_input(_key("interact"))
	await _wait(func(): return moment.phase == "intro", "putting it on opens its page")
	await _wait(func(): return moment.go_button != null, "the page has a way on")
	moment.go_button.pressed.emit()

# ------------------------------------------------------------------ 3. the tutorial match
func _tutorial_match():
	_begin("tutorial match: load")
	await _wait(_match_running, "'Head out together' opens the tutorial match")
	var m: Match = main.current
	m.set_process(false)
	ok(bool(m.opts.get("tutorial", false)), "it is the tutorial course")
	_begin("tutorial match: course")
	var t := 0.0
	var step_t := 0.0
	var last := -1
	var worst := 0.0
	while t < COURSE_S and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		step_t += Match.DT
		if m.tut.step != last:
			last = m.tut.step
			step_t = 0.0
		worst = maxf(worst, step_t)
	ok(m.player.extracted, "the driver finishes the course and extracts (%.0f s of play)" % t)
	ok(worst < SIM_STALL_S, "no step took more than %.0f s of play (%.0f s)" % [SIM_STALL_S, worst])
	_begin("results")
	await _wait(func(): return main.current is CanvasLayer, "the course ends on the results")
	await tree.process_frame
	var tut: Dictionary = Save.d["tutorial"]
	ok(bool(tut.get("match", false)) and int(Save.d.get("matches", 0)) == 1, "it counts as the first expedition")
	ok(ClassUnlock.second_pending(), "and the second Relic is on offer")
	_press(main.current, "Go home")
	_begin("farm: first arrival")
	await _wait(func(): return _is_screen("home.gd"), "'Go home' opens the farm")
	var home = main.current
	await _wait(func(): return home.panel_host != null, "the farm builds")
	return home

# ------------------------------------------------------------------ 4. the farm tutorial
func _farm_tutorial(home) -> void:
	_begin("farm tutorial")
	home._close_panel()
	ok(FarmTutorial.active() and FarmTutorial.current() == "hob", "the farm tutorial starts by calling you to Hob")
	ok(is_instance_valid(home.guide.hint_box), "its first prompt is on screen")
	var gems := int(Save.d["gems"])
	var steps := 0
	while FarmTutorial.active() and steps < FarmTutorial.steps().size() + 2:
		steps += 1
		home.guide._poll()
		var cur := FarmTutorial.current()
		if cur == "":
			ok(false, "a step is always open while the tutorial runs (stalled after %d)" % FarmTutorial.done_count())
			return
		ok(FarmTutorial.hint_text(cur) != "", "'%s' tells you what to do" % cur)
		_do_step(cur)
	ok(bool(FarmTutorial.state()["done"]) and not FarmTutorial.state()["skipped"], "every step can be done in turn")
	ok(HomeGather.has_tool("axe") and HomeGather.has_tool("pickaxe"), "the axe and the pickaxe were handed over")
	ok(int(Save.d["gems"]) >= gems + int(FarmTutorial.option("end_gems")), "the reward at the end is paid")
	home.guide._poll()
	ok(not is_instance_valid(home.guide.hint_box), "and the prompts are gone")

## Does what the player would for one step: the game's own hook where there is one, else its mark.
func _do_step(id: String) -> void:
	var events := {"hob": "hob", "hammer": "swing", "task": "task", "expedition": "portal",
			"buy": "buy", "sell": "sell"}
	if id == "house":
		ok(main.current.guide.place_house(), "the house can be placed on the farm")
		_build_house()
	if events.has(id):
		FarmTutorial.event(String(events[id]))
	FarmTutorial.mark(id)

## The materials the house takes and every swing of labour: what chopping, mining and hammering add up to.
func _build_house() -> void:
	var cost := FarmSites.build_cost("house")
	Work.add_mat("wood", int(cost["wood"]))
	Work.add_mat("stone", int(cost["stone"]))
	var house := FarmHob.house_entry()
	ok(FarmSites.add_swing(house, int(house["site"]["need"])), "its labour can all be done: the house stands")
	main.current._sync_fixtures()

# ------------------------------------------------------------------ 5. the second Relic
func _second_relic(home) -> void:
	_begin("second Relic")
	ok(home.hob.chat.offer_due(), "Hob offers it now the house is down")
	home.hob.talk()
	var chat: HobTalk = home.hob.chat
	for i in 30:
		if chat.offer != null:
			break
		chat.box.advance()
		await tree.process_frame
	ok(chat.offer != null, "talking to him, his lines lead to the three Relics")
	var offer: HobOffer = chat.offer
	ok(offer.ids.size() == 3 and offer.take_button != null, "three to choose from, with a Take button")
	var pick := String(offer.ids[0])
	offer.take_button.pressed.emit()
	ok(ClassUnlock.open_ids().has(pick) and not ClassUnlock.second_pending(), "taking one opens it (%s)" % pick)
	await tree.create_timer(0.2).timeout
	ok(HeroGrid.save_pick(pick) and Arch.of_save() == pick, "and it can be worn for the next expedition")
	home._close_panel()

# ------------------------------------------------------------------ 6. the first expedition
func _first_expedition(home) -> void:
	_begin("first expedition: start")
	home.exp_seed = EXPEDITION_SEED
	home._start_match()
	await _wait(func(): return main.current is CanvasLayer or _match_running(), "'Go' leaves the farm")
	_begin("first expedition: pre-match countdown")
	await _wait(_match_running, "the countdown runs out into the expedition", PREMATCH_STALL_S)
	var m: Match = main.current
	m.set_process(false)
	var worn := Arch.of_save()
	ok(m.player.ak != null and m.player.ak.id == worn, "you play as the Relic you chose (%s)" % worn)
	_begin("first expedition: play")
	await _skiff(m)

## The stick direction from the hunter to a spot on the ground.
func _toward(p: Hunter, at: Vector3) -> Vector2:
	return Vector2(at.x - p.pos.x, at.z - p.pos.z).normalized()

func _skiff(m: Match) -> void:
	var P: Hunter = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fall_t := 0.0
	ok(P.riding, "you start on the skyship")
	while (P.riding or P.dropping or not P.grounded) and fall_t < DROP_S:
		P.inp["jump"] = P.riding and fall_t > float(P.ai.get("jump_at", 0.0)) and int(fall_t * 20.0) % 2 == 0
		P.inp["move"] = _toward(P, P.ai.get("land", P.pos)) if not P.riding else Vector2.ZERO
		m.step(Match.DT)
		fall_t += Match.DT
	P.inp["jump"] = false
	P.inp["move"] = Vector2.ZERO
	var landed: bool = P.grounded and not P.riding and not P.dropping
	ok(landed, "jumping off the ship ends with you on your feet (%.0f s)" % fall_t)
	var docks := m.exits.of_kind("dock")
	ok(not docks.is_empty(), "there is a skiff to take")
	var d: Dictionary = docks[0]
	P.max_hp = 5000.0      # the driver stands at the dock while rivals and the wave come: the exit is what is tested
	P.hp = P.max_hp
	while m.time < float(d["open_at"]) + 1.0 and not P.out:
		P.teleport(d["pos"] + Vector3(0.3, 0, 0.3))
		P.hp = P.max_hp
		m.step(Match.DT)
	ok(not P.out and d["state"] == "idle", "the skiff opens at %.0f s" % float(d["open_at"]))
	for i in int(2.5 / Match.DT):
		P.inp["interact"] = true
		m.step(Match.DT)
	P.inp["interact"] = false
	ok(d["state"] == "called", "holding interact at the dock calls it")
	var t0 := m.time
	while d["state"] in ["called", "boarding"] and m.time - t0 < 120.0:
		P.teleport(d["berth"])
		P.hp = P.max_hp
		m.step(Match.DT)
	ok(P.extracted, "the skiff takes you out (%.0f s of play)" % (m.time - t0))
	_begin("first expedition: results")
	await _wait(func(): return main.current is CanvasLayer, "and the expedition ends on the results")
	_press(main.current, "Back to the farm")
	await _wait(func(): return _is_screen("home.gd"), "back on the farm")
	_end()

# ------------------------------------------------------------------ 7. the skip paths
func _skip_paths() -> void:
	_begin("skip paths")
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true, "prologue": true}
	Save.d["look"] = Unmasked.default_look()
	await main.show_screen("hatch", {})
	var hx = main.current
	await _wait(func(): return hx.stage == "pick", "a second new player reaches the eggs")
	hx.chosen = 0
	hx.stage = "name"
	hx._show_name()
	_press(hx, "Skip the tutorial")
	await _relic(hx)
	_begin("skip paths: farm")
	await _wait(func(): return _is_screen("home.gd"), "'Skip the tutorial' goes straight to the farm")
	var home = main.current
	await _wait(func(): return home.panel_host != null, "the farm builds")
	home._close_panel()
	var tut: Dictionary = Save.d["tutorial"]
	ok(bool(tut.get("match", false)) and int(Save.d.get("matches", 0)) == 0, "the match tutorial is done, not played")
	ok(FarmTutorial.active(), "the farm tutorial still starts")
	var skippable := bool(FarmTutorial.option("skippable"))
	var buttons: int = home.guide.skip_row.get_child_count()
	ok(buttons == (1 if skippable else 0), "its Skip button follows the 'skippable' option (%s)" % skippable)
	var gems := int(Save.d["gems"])
	home.guide.skip()
	ok(not FarmTutorial.active() and FarmSites.is_site(FarmHob.house_entry()), "skipping leaves the house to build")
	ok(HomeGather.has_tool("axe") and HomeGather.has_tool("pickaxe"), "and the axe and the pickaxe")
	ok(int(Save.d["gems"]) >= gems, "nothing was taken")
	_end()
