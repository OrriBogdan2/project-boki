extends RefCounted
## --cd-gate-reel --reel-only=gate|tutorial: the two cooldown changes at the match camera, for a short clip.
## gate: the archer's Heavy Shot drawn and loosed, then RMB and E pressed on cooldown (no draw: the slot shakes and
## dims with "On cooldown" over it). tutorial: the E step, three tries aimed away (the miss line, E back at once,
## the ground ping on the third), then one on the group. Run it under the movie writer:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 30 \
##       --write-movie <dir>/clip.avi -- --cd-gate-reel --reel-only=gate

const STEPS_PER_FRAME := 2     # sim steps per drawn frame (60 Hz sim, a 30 fps clip)

var main: Node
var m: Match

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var only := "gate"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--reel-only="):
			only = String(a).substr(12)
	if only == "tutorial":
		await _tutorial()
	else:
		await _gate()
	main.get_tree().quit(0)

## `secs` of play: `each` (optional) sets the hunter's keys before every sim step, given the time into the shot.
func _play(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		for i in STEPS_PER_FRAME:
			if each.is_valid(): each.call(t)
			m.step(Match.DT)
			t += Match.DT
		m.cam.snap(m.player.pos)
		await main.get_tree().process_frame

func _gate() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight("archer"), "arch": "archer", "weapon": Arch.signature("archer")})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var p := m.player
	p.unlock_all()
	p.lvl = 10
	for o in m.hunters:
		if o != p: o.ctrl = "idle"
	p.inp["aim"] = p.pos + Vector3(0, 0, -6)
	await _play(1.0)
	await _play(1.6, func(t: float):
		p.inp["sec"] = t < Match.DT
		p.inp["sec_hold"] = t < 1.3)      # the Heavy Shot drawn and loosed: RMB is on cooldown now
	await _play(0.8)
	for i in 3:
		await _play(1.0, func(t: float):
			p.inp["sec"] = t < Match.DT
			p.inp["sec_hold"] = t < 0.7)  # pressed and held on cooldown: nothing draws
	p.ak.cd["e"] = 8.0
	await _play(1.2, func(t: float): p.inp["sig"] = t < Match.DT)
	await _play(0.6)

func _tutorial() -> void:
	seed(5)
	m = Match.new()
	main.add_child(m)
	await m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0,
		"demo_kin": "cindle", "arch": "gunslinger", "cls": Arch.weight("gunslinger")})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var tu: Tutorial = m.tut
	tu.ack()          # (no intro card; not tut_test, whose driver would play the step itself)
	m.step(Match.DT)
	m.player.dropping = false         # (landed: the drop is the course's first beat, not this one)
	m.player.gliding = false
	m.player.teleport(tu.stop("land"))
	tu._skip_to(Tutorial.steps().map(func(s): return s[0]).find(TutorialAim.STEP))
	tu._enter()
	await _play(1.8)
	var p := m.player
	for i in TutorialAim.HELP_AFTER:
		var mb := tu.camps.nearest()
		var away := ((p.pos - mb.pos) * Vector3(1, 0, 1)).normalized()
		await _play(TutorialAim.AIM_WAIT + 1.0, func(t: float):
			p.inp["aim"] = p.pos + away * 6.0
			p.inp["sig"] = t < Match.DT)
	var target := tu.camps.nearest()
	await _play(2.5, func(t: float):
		p.inp["aim"] = target.pos
		p.inp["sig"] = t < Match.DT)
	print("CDGREEL tutorial: %d misses, hit %s, step %s" % [tu.aim.misses, tu.aim.hit, tu.id()])
