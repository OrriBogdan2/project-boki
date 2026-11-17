extends RefCounted
## --prompt-queue-check [--shots-dir=<dir>]: the top-centre of a real match shows one prompt at a time.
## The first-match guide's "Send <Boki> at a monster: tap C" line is up and, in the same second, the Boki-key
## hint, another hint and a toast ask to show:
##   1. while the banner is fresh only the banner shows (the lane holds the rest)
##   2. the Boki-key hint merges into the guide's line (it never shows a second time)
##   3. once the banner settles the lane shows the rest under it: no card touches the banner or another card
##   4. the crouch hint waits for the guide's line, then takes the banner and the lane sits under it
## With --shots-dir (a real renderer) the same moments are saved as PNGs (for a before/after pair).

const SEC := 60  # sim steps per second of game time (Match.DT)

var bad := 0
var main: Node
var m: Match
var dir := ""
var n := 0


func ok(cond: bool, what: String) -> void:
	print("PQ %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start(
		{"teams": 1, "squad": 1, "tier": 0, "length": 1000.0, "seed": 4242, "demo_kin": "cindle", "no_drop": true}
	)
	m.set_process(false)
	if main.fade != null:
		await main.fade.reveal(0.01)
	HudReveal.see("counters")  # (a first expedition stages the banner off)
	m.player.dropping = false
	m.player.riding = false
	await _run_for(1.0)
	await _send_and_hint()
	await _crouch_hint()
	print("PQ DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Game time passes, drawn: `secs` of steps with a frame each.
func _run_for(secs: float) -> void:
	for i in int(secs * SEC):
		m.step(Match.DT)
		await main.get_tree().process_frame


func _shot(what: String) -> void:
	if dir == "":
		return
	m.hud.panels.queue_redraw()
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	n += 1
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("%02d_%s.png" % [n, what]))


## The banner's rect now, and every card of the lane.
func _strip() -> Rect2:
	return TutorialStrip.shown(m.hud.c.size, 9.0, WaysOutHud.bottom(m))


func _touching(rects: Array[Rect2]) -> int:
	var hit := 0
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				hit += 1
	return hit


func _send_and_hint() -> void:
	var g := m.guide
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	g.id = ""
	g.line = ""
	for id in FirstMatchGuide.ORDER:
		if id != "send":
			g.shown[id] = true
	g.tick(2.0)
	ok(
		g.id == "send" and g.line.contains(Settings.key_cap("throw")),
		"the guide says how to send the Boki (%s)" % g.line
	)
	m._tip("ability", TipText.ability(true))
	m._tip("t_other", "Hold F to open the chest")
	m.hud.toast("Picked up a gem", Color.WHITE)
	await _run_for(0.5)
	await _shot("fresh")
	ok(
		g.strip_age() < Tutorial.CARD_T and lane.texts().is_empty(),
		"a fresh banner: the lane shows nothing (%s)" % str(lane.texts())
	)
	await _run_for(Tutorial.CARD_T)
	await _shot("settled")
	var texts: Array[String] = lane.texts()
	ok(
		not texts.is_empty() and not str(texts).contains("sends"),
		"the settled lane shows the rest, not the Boki-key hint (%s)" % str(texts)
	)
	ok(
		lane.waiting() == 0 or lane.texts().size() == lane.MAX_SHOWN,
		"nothing is left behind (%d waiting)" % lane.waiting()
	)
	var cards: Array[Rect2] = lane.rects()
	var strip := _strip()
	var under: bool = cards.all(func(r: Rect2) -> bool: return r.position.y >= strip.end.y)
	ok(under and _touching(cards) == 0, "no card touches the banner %s or another card %s" % [strip, str(cards)])
	g.line = ""
	g.id = ""


func _crouch_hint() -> void:
	var lane: MsgLane = m.hud.msgs
	lane.clear()
	var ch := CrouchHint.new()
	ch.m = m
	ch.line = "Hold C to crouch and sneak up on the camp"
	m.crouch_hint = ch
	m.guide.line = "Rank up: press E"
	await _run_for(0.5)
	ok(
		TopStack.strip_age(m) == m.guide.strip_age() and m.guide.strip_age() >= 0.0,
		"the guide's line is the banner; the crouch hint waits"
	)
	m.guide.line = ""
	await _run_for(0.5)
	ok(TopStack.strip_age(m) == ch.strip_age(), "the guide done: the crouch hint takes the banner")
	m.hud.toast("A second toast", Color.WHITE)
	await _run_for(Tutorial.CARD_T)
	await _shot("crouch")
	var cards: Array[Rect2] = lane.rects()
	ok(
		not cards.is_empty() and cards.all(func(r: Rect2) -> bool: return r.position.y >= _strip().end.y),
		"the lane sits under the crouch hint %s: %s" % [_strip(), str(cards)]
	)
