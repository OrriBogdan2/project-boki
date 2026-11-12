extends RefCounted
## --stolen-hud-check: the stolen wisps on the HUD (BokiHud.stolen_wisps, TeamBoki; decision 0041, WISP_DESIGN_OPEN.md
## Q6/Q8). The thief's Boki box gets one row per stolen wisp (at most carry_max): name, its carry passive at passive_k
## of the stat, and its one summon ready / out / used; a teammate's squad row shows the count; nothing is drawn with
## no stolen wisp, and a wisp that is loose or gone leaves its row. With --shots-dir=<dir> (real renderer) it saves the
## HUD as <dir>/<WxH>_NN_<state>.png. Prints PASS/FAIL.

const DT := 1.0 / 60.0

var main: Node
var m: Match
var bad := 0
var n := 0
var dir := ""

func ok(cond: bool, what: String) -> void:
	print("STOLENHUD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Game.god = false      # (god mode would stand the downed thief straight back up)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 78, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if dir != "" and fade != null:
		await fade.reveal(0.01)
	await _rows()
	print("STOLENHUD %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		for h in m.hunters:
			h.render(DT, 1.0)
		t += DT

func _steal(thief: Hunter, victim: Hunter) -> Kin:
	var k: Kin = victim.kin
	k.summon.cd = 40.0      # a ready summon would come out to guard its downed hunter (0040): rest it, so the wisp breaks loose
	m.knock(victim, thief, {})
	_frames(0.1)
	ok(KinSteal.grab(k, thief), "%s's wisp is grabbed by %s" % [k.rec.get("name", "Boki"), thief.pname])
	return k

func _drawn() -> void:
	m.hud.visible = true
	await m.hud.panels.draw
	await m.hud.panels.draw

func _rows() -> void:
	var p: Hunter = m.player
	var mate: Hunter = m.hunters.filter(func(h: Hunter): return h.team == p.team and h != p and h.kin != null)[0]
	var foes: Array = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)
	_frames(0.3)
	await _drawn()
	ok(BokiHud.stolen_shown.is_empty() and TeamBoki.stolen_shown.is_empty(), "no stolen wisps: no row, no badge")
	var k1 := _steal(p, foes[0])
	var share := float(KinSteal.rules()["passive_k"])
	await _drawn()
	ok(BokiHud.stolen_shown.size() == 1, "one stolen wisp: one row (%d)" % BokiHud.stolen_shown.size())
	var row: Dictionary = BokiHud.stolen_shown[0] if not BokiHud.stolen_shown.is_empty() else {}
	var want := "no carry bonus"
	if not k1.ks.carry_passives.is_empty():
		want = KinText.passives(k1.ks.carry_passives, share)
	ok(row.get("passive", "") == want and row.get("name", "") == String(k1.rec.get("name", "Boki")),
		"...its name and its carry passive at %d%% (%s)" % [int(share * 100.0), str(row.get("passive"))])
	ok(row.get("state", "") == "ready" and TeamBoki.stolen_shown.is_empty(),
		"...its one summon ready; no teammate badge for your own")
	p.kin.summon.cd = 40.0
	ok(KinSummon.press(p), "the stolen wisp is summoned")
	_frames(0.5)
	await _drawn()
	ok(BokiHud.stolen_shown[0]["state"] == "out", "summoned: the row says it is out")
	_frames(float(maxf(5.0, ceilf(k1.summon.dur * 0.5))) + KinSummon.SHRINK_S + 0.2)
	await _drawn()
	ok(BokiHud.stolen_shown[0]["state"] == "used", "after its one summon: the row says used")
	await _shot("one_used")
	var k2 := _steal(p, foes[1])
	k2.summon.cd = 0.0
	await _drawn()
	ok(BokiHud.stolen_shown.size() == 2 and BokiHud.stolen_shown[1]["state"] == "ready",
		"a second wisp: two rows, the new one ready")
	await _shot("two")
	var k3 := _steal(mate, foes[2])
	ok(KinSteal.count(mate) == 1 and KinSteal.stolen(k3), "a teammate carries a wisp")
	await _drawn()
	ok(TeamBoki.stolen_shown.get(mate.nid, 0) == 1,
		"...their squad row shows the count 1 (%s)" % str(TeamBoki.stolen_shown))
	await _shot("mate")
	for f in foes:
		if f.downed:
			m.revive_hunter(f, null)
	m.knock(p, null, {})
	_frames(0.1)
	ok(p.downed and BokiHud.stolen_rows(p).is_empty(), "the thief goes down: both wisps are loose, the rows go")

## The HUD as it is (real renderer only).
func _shot(what: String) -> void:
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [img.get_width(), img.get_height(), n, what]))
