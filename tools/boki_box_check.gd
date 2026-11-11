extends RefCounted
## --boki-box-check: the summon ring and tags on the Boki box (BokiHud.summon_view / stolen) through a whole
## summon cycle on the player's Cindle (8 s out, 60 s cooldown): SUMMONED drains the ring, RESTING fills it,
## READY flashes once when the cooldown ends and then goes quiet, a knock-down rests longer, STOLEN follows a
## rival holding your Boki. Prints PASS/FAIL. With --shots-dir=<dir> (real renderer) it also saves the box in
## each state as <dir>/<WxH>_NN_<state>.png.

const DT := 1.0 / 60.0
const EPS := 0.02      # ring fraction tolerance (one step is ~0.002 of an 8 s window)

var main: Node
var m: Match
var bad := 0
var n := 0
var dir := ""

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if dir != "" and fade != null:
		await fade.reveal(0.01)      # the boot splash stays up when a check starts the match by hand
	await _cycle()
	print("BOKIBOX %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("BOKIBOX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		t += DT

func _cycle() -> void:
	var p: Hunter = m.player
	var s: KinSummon = p.kin.summon
	_frames(0.3)
	var v := BokiHud.summon_view(s)
	ok(v[0] == 1.0 and v[1] == "", "ready from the start: full ring, no tag (%s)" % [v])
	await _shot("ready")
	KinSummon.press(p)
	_frames(4.0)
	v = BokiHud.summon_view(s)
	ok(absf(v[0] - 0.5) < EPS and v[1] == "SUMMONED", "4 s into an 8 s window: ring half drained, SUMMONED (%s)" % [v])
	await _shot("summoned")
	_frames(4.0 + KinSummon.SHRINK_S)
	v = BokiHud.summon_view(s)
	ok(v[0] < EPS and v[1] == "RESTING", "window over: the ring starts empty, RESTING (%s)" % [v])
	s.cd = s.cd_full * 0.5          # (30 s of the 60 s rested, without stepping them)
	v = BokiHud.summon_view(s)
	ok(absf(v[0] - 0.5) < EPS and v[1] == "RESTING", "30 s of 60 s rested: ring half full (%s)" % [v])
	await _shot("resting")
	s.cd = 0.05
	_frames(0.1)
	v = BokiHud.summon_view(s)
	ok(v[0] == 1.0 and v[1] == "READY", "cooldown over: full ring, READY flash (%s)" % [v])
	await _shot("ready_flash")
	_frames(KinSummon.READY_FLASH_S + 0.1)
	v = BokiHud.summon_view(s)
	ok(v[0] == 1.0 and v[1] == "", "the flash happens once: then the ring is full and quiet (%s)" % [v])
	KinSummon.press(p)
	p.kin.hurt(p.kin.max_hp * 5.0, null)
	_frames(0.1)
	v = BokiHud.summon_view(s)
	ok(v[1] == "RESTING" and s.cd_full > 74.0 and v[0] < EPS, "knocked down: RESTING, longer 75 s cooldown (%s)" % [v])
	var thief: Hunter = m.hunters.filter(func(x: Hunter): return x.team != p.team)[0]
	ok(not BokiHud.stolen(m, p), "STOLEN: not while nobody holds your Boki")
	m.player_lost.append({"uid": "x", "kin": null, "holder": thief, "rec": {}})
	ok(BokiHud.stolen(m, p), "STOLEN: a rival holds your Boki")
	if dir != "":
		var kin := p.kin
		p.kin = null
		await _shot("stolen")
		p.kin = kin
	m.player_lost.clear()
	ok(not BokiHud.stolen(m, p), "STOLEN: gone when it is back")

## The HUD with the box in its current state (real renderer only).
func _shot(what: String) -> void:
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	m.hud.visible = true
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	var sz := img.get_size()
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [sz.x, sz.y, n, what]))
