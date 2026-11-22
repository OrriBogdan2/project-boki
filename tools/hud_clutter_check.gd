extends RefCounted
## --hud-clutter-check [--hunter=<id>] [--shots-dir=<dir>]: an ABSOLUTE combat-HUD check for the merge gate.
## A real match, the player on autoplay with a rival bot dropped next to them, runs ~5 s of fight, then:
##   1. the HUD's visible element count (Control nodes, labels, toasts, banners, loot rows, drawn panel
##      groups) stays within ops/hud-budget.json, per category and in total; the count is printed
##   2. no visible HUD rect (Control nodes, drawn panels, message cards, the knock banner) overlaps the
##      hunter's screen box (HunterZone.rect: feet to the top of the overhead plate)
##   3. with a renderer (xvfb, not --headless) a screenshot is saved to --shots-dir (default: user data dir)
## --hunter=<id>[,<id>..] plays those Hunters (the full HUD) in a duo: the teammate is down and the Boki is
## summoned, then each --moments=cast,ult,fusion (default cast,ult): E just pressed, the ultimate just pressed,
## the Fusion live (Fusion is off in the shipped rules; the check turns it on for its own scenes).
##   --statuses       a buff (haste, crit, guard, shield) and a debuff (slowed, burning, weakened) on the Hunter
##   --sizes=WxH,..   each scene at those window sizes (default: the window as it is)
##   --accumulate     count every draw over the frames, as the first version did (swings with the redraws)
##   --all            every Hunter, --moments=ult,fusion, --statuses, --sizes=1920x1080,1280x720
## Every scene prints its failures on one line and the run ends with the list of failing scenes.
## To raise the budget on purpose, change ops/hud-budget.json in the same PR and say why; the owner must OK it.
## Never touches the save.

const BUDGET_PATH := "res://ops/hud-budget.json"
const FIGHT_S := 5.0  # s of match time before the HUD is judged
const RIVAL_GAP := 5.0  # m between the player and the rival dropped beside them
const FIGHT_EXTRA_S := 15.0  # s more a Hunter scene may wait for a hit given or taken
const CAST_S := 0.3  # s after the cast or ult press that the HUD is judged
const MATE_GAP := 30.0  # m behind the player the teammate waits, away from the rival
const BANNER_FRAMES := 600  # match steps the knock banner is aged to close it
const RECORD_FRAMES := 4  # frames the HUD is watched for its draw
const MOMENTS := ["cast", "ult"]
const ALL_SIZES := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const FUSION_S := 4.0  # s to wait for the Fusion form to go live after X
const STATUS_S := 8.0  # s the buff and debuff last
const FULL_SCREEN := 0.9  # share of the screen a Control must cover to be a backdrop (looked inside, not counted)

var bad := 0
var main: Node
var failed: Array = []  # scene tags with a failure
var scene_bad := 0
var accumulate := false
var _hud  # the match's HUD (untyped: the script has no class name)


func ok(cond: bool, what: String) -> void:
	print("HUDCLUTTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1
		scene_bad += 1


func run(main_node: Node) -> void:
	main = main_node
	var shots := ""
	var hunters: Array = []
	var moments: Array = MOMENTS
	var sizes: Array = [Vector2i.ZERO]
	var statuses := false
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			shots = arg.substr(12)
		elif arg.begins_with("--hunter="):
			hunters = Array(arg.substr(9).split(",", false))
		elif arg.begins_with("--moments="):
			moments = Array(arg.substr(10).split(",", false))
		elif arg.begins_with("--sizes="):
			sizes = []
			for t in arg.substr(8).split(",", false):
				var wh := t.split("x")
				sizes.append(Vector2i(int(wh[0]), int(wh[1])))
		elif arg == "--accumulate":
			accumulate = true
		elif arg == "--statuses":
			statuses = true
		elif arg == "--all":
			hunters = Arch.ids()
			moments = ["ult", "fusion"]
			sizes = ALL_SIZES
			statuses = true
	Save.no_write = true
	Econ.ensure()
	if hunters.is_empty():
		await _scene("", "", Vector2i.ZERO, false, shots)
	else:
		for arch in hunters:
			for size: Vector2i in sizes:
				for moment in moments:
					await _scene(String(arch), String(moment), size, statuses, shots)
	print("HUDCLUTTER DONE, failures: %d, scenes failing: %s" % [bad, failed])
	main.get_tree().quit(1 if bad > 0 else 0)


## One judged match. With a hunter id the player is that Hunter in a duo whose teammate is down, with their
## Boki summoned and a rival beside them, caught `moment` ("cast": the E ability, "ult": the ultimate) just
## after the press ("fusion": the Fusion live); without one it is the plain fight. `size` (not zero) sets the
## window; `statuses` puts a buff and a debuff on the Hunter just before the press.
func _scene(arch: String, moment: String, size: Vector2i, statuses: bool, shots: String) -> void:
	var win := "%dx%d" % [size.x, size.y] if size.x > 0 else "-"
	var tag := "" if arch == "" else "%s %s %s: " % [arch, moment, win]
	scene_bad = 0
	if size.x > 0:
		main.get_window().size = size
		for i in 3:
			await main.get_tree().process_frame
	if moment == "fusion":
		Content.rules("merge_forms")["fusion_enabled"] = true  # (shipped off; this scene is the form's HUD)
	Save.d = Save.fresh()
	if arch != "":
		Save.d.erase("hud_reveal")  # the full HUD, as a veteran sees it (a new player's is staged, HudReveal)
	var o := {
		"teams": 2, "squad": 1, "tier": 0, "seed": 4, "no_drop": true, "autoplay": true, "god": true, "length": 1e9
	}
	if arch != "":
		o.merge(
			{"squad": 2, "arch": arch, "cls": Arch.weight(arch), "weapon": Arch.signature(arch), "demo_kin": "cindle"},
			true
		)
	var m := Match.new()
	main.add_child(m)
	await m.start(o)
	if main.fade != null:
		await main.fade.reveal(0.01)
	m.set_process(false)
	var rival: Hunter = m.hunters.filter(func(h): return h.team != m.player.team)[0]
	rival.teleport(m.player.pos + Vector3(RIVAL_GAP, 0.0, 0.0))
	if arch != "":
		m.player.lvl = maxi(m.player.lvl, int(Hunter.ULT_AT[0]))  # the ultimate is open (its shine passes)
		for slot: String in m.player.slot_lv:
			m.player.slot_lv[slot] = 1  # every ability learned, so the press casts
		var mate := _mate(m)
		var at := m.player.pos - Vector3(MATE_GAP, 0.0, 0.0)
		mate.ctrl = "idle"  # out of the fight, so the rival does not finish them into a deathbox
		mate.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	for i in int((FIGHT_S + (FIGHT_EXTRA_S if arch != "" else 0.0)) / Match.DT):
		m.step(Match.DT)
		m.hud.loot.tick(Match.DT)  # pickup rows age with the match clock too (a busy box ran frames slower)
		if i % 20 == 0:
			await main.get_tree().process_frame
		if arch != "" and m.time >= FIGHT_S and m.hud.in_fight():
			break
	if arch != "":
		await main.get_tree().process_frame  # (the HUD takes the fight in: its loot feed goes quiet)
		_stage(m, rival)
		if statuses:
			_statuses(m.player)
		_press(m.player, moment)
		if moment == "fusion":
			for i in int(FUSION_S / Match.DT):
				m.step(Match.DT)
				if not m.player.merge_st.is_empty() and String(m.player.merge_st["phase"]) == "live":
					break
			ok(
				not m.player.merge_st.is_empty() and String(m.player.merge_st["phase"]) == "live",
				"%sthe Fusion is live" % tag
			)
		for i in int(CAST_S / Match.DT):
			m.step(Match.DT)
	m.hud.panels.queue_redraw()
	await main.get_tree().process_frame
	_hud = m.hud
	if arch != "":
		# the fight is on at the judged frame: a hit landed on you as the cast went off (the rival is next to you;
		# a cast that kills time on the match clock, as a Fusion's windup, let the 4 s lapse on 4 of 39 scenes)
		m.player.hurt_at = m.time
	var seen := await _record_draws()
	var zone := HunterZone.rect(m)
	var counts := _counts(m, seen)
	ok(
		m.hud.in_fight(),
		"%sthe HUD is judged in a fight (a hit given or taken within %d s)" % [tag, int(m.hud.MSG_FIGHT_S)]
	)
	var groups: Array = []
	for g: String in seen:
		groups.append("%s=%d" % [g, (seen[g] as Array).size()])
	print("HUDCLUTTER   %sdrawn groups: %s" % [tag, " ".join(groups)])
	print("HUDCLUTTER   %swindow %s, HUD canvas %s" % [tag, str(main.get_window().size), str(m.hud.c.size)])
	_budget(counts, tag)
	_overlap(zone, _hud_rects(m, seen), tag)
	await _shot(shots, "hud_clutter" if arch == "" else "%s_%s_%dx%d" % [arch, moment, size.x, size.y])
	if scene_bad > 0:
		failed.append(tag.trim_suffix(": ") if tag != "" else "plain")
		print("HUDCLUTTER FAIL SCENE %s (%d failing lines)" % [tag.trim_suffix(": "), scene_bad])
	Content.rules("merge_forms")["fusion_enabled"] = false
	m.queue_free()
	await main.get_tree().process_frame


## What the HUD draws in one frame, as group -> Rects: over a few frames only the last frame that drew anything
## counts. SafeArea.seen piles up every draw and the HUD draws once or twice a frame, so the same panel can be
## noted twice: a panel is counted once per distinct rect (the old count swung 54 to 82 on one scene).
func _record_draws() -> Dictionary:
	var last := {}
	var draws := 0
	SafeArea.recording = true
	if accumulate:  # the first version's count: every draw over the frames piles up (varies with the redraws)
		SafeArea.seen.clear()
		for i in RECORD_FRAMES:
			_hud.panels.queue_redraw()
			await main.get_tree().process_frame
		SafeArea.recording = false
		return SafeArea.seen.duplicate()
	for i in RECORD_FRAMES:
		SafeArea.seen.clear()
		_hud.panels.queue_redraw()
		await main.get_tree().process_frame
		if not SafeArea.seen.is_empty():
			last = _unique(SafeArea.seen)
			draws += 1
	SafeArea.recording = false
	print("HUDCLUTTER   (%d of %d frames drew the HUD; the last one is judged)" % [draws, RECORD_FRAMES])
	return last


## The teammate knocked (they stay down; the banner is waited out, the match clock stands still) and the Boki
## summoned.
func _stage(m: Match, rival: Hunter) -> void:
	m.knock(_mate(m), rival, {})
	KinSummon.press(m.player)
	for i in BANNER_FRAMES:
		if m.hud.knocks.kind == "":
			return
		m.hud.knocks._process(Match.DT)  # the banner ages with the match clock, not with how fast frames come


func _unique(seen: Dictionary) -> Dictionary:
	var out := {}
	for g: String in seen:
		var keys := {}
		var rects: Array = []
		for r: Rect2 in seen[g]:
			var k := "%d,%d,%d,%d" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
			if not keys.has(k):
				keys[k] = true
				rects.append(r)
		out[g] = rects
	return out


func _mate(m: Match) -> Hunter:
	return m.hunters.filter(func(h): return h != m.player and h.team == m.player.team)[0]


## A buff (haste, crit, guard, a shield: the right-edge stack) and a debuff (slowed, burning, weakened: the
## status row) on the Hunter, as a fight leaves them.
func _statuses(p: Hunter) -> void:
	p.haste_t = STATUS_S
	p.crit_t = STATUS_S
	p.guard_t = STATUS_S
	p.guard_k = 0.3
	p.shield = 30.0
	p.shield_t = STATUS_S
	p.slow_t = STATUS_S
	p.slow_k = 0.4
	p.burn_t = STATUS_S
	p.burn_dps = 1.0
	p.weak_t = STATUS_S


## The E cast, the ultimate or the Fusion pressed.
func _press(p: Hunter, moment: String) -> void:
	p.ak.cd["e"] = 0.0
	p.ak.cd["x"] = 0.0
	if moment == "fusion":
		p.ult = 1.0
		p.merge_cd = 0.0
		if KinMerge.plan(p) == "rescue":
			KinDowned.rescue(p.kin)  # a Boki the rival downed in the fight is back up, so the form can start
		KinMerge.press(p)
	elif moment == "ult":
		HunterKeys.ult_pressed(p)
	else:
		p.ak.use_e()


## Every visible element on the HUD with its screen rect, as [name, Rect2]: the Control nodes, the panels
## drawn this frame (SafeArea), the message cards and the knock banner.
func _hud_rects(m: Match, seen: Dictionary) -> Array:
	var out: Array = []
	var sz: Vector2 = m.hud.c.size
	_controls(m.hud, sz, out)
	for g: String in seen:
		for r: Rect2 in seen[g]:
			out.append([g, r])
	for r in m.hud.msgs.rects():
		out.append(["toast", r])
	return out


func _controls(node: Node, sz: Vector2, out: Array) -> void:
	for ch in node.get_children():
		var c := ch as Control
		if c == null or not c.visible or c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		var r := c.get_global_rect()
		if r.size.x >= sz.x * FULL_SCREEN and r.size.y >= sz.y * FULL_SCREEN:
			_controls(c, sz, out)
		else:
			out.append([String(c.name), r])
			_controls(c, sz, out)


## The element count by category.
func _counts(m: Match, seen: Dictionary) -> Dictionary:
	var rects: Array = []
	_controls(m.hud, Vector2(m.hud.c.size), rects)
	var labels := 0
	for l in m.hud.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text != "":
			labels += 1
	var drawn := 0
	for g: String in seen:
		drawn += (seen[g] as Array).size()
	var c := {
		"controls": rects.size(),
		"labels": labels,
		"toasts": m.hud.msgs.rects().size(),
		"banners": 1 if m.hud.knocks.kind != "" else 0,
		"loot_rows": m.hud.loot.rows.size(),
		"drawn_panels": drawn,
	}
	var total := 0
	for k: String in c:
		total += int(c[k])
	c["total"] = total
	return c


func _budget(counts: Dictionary, tag: String) -> void:
	var f := FileAccess.open(BUDGET_PATH, FileAccess.READ)
	ok(f != null, "the budget file %s exists" % BUDGET_PATH)
	if f == null:
		return
	var budget: Dictionary = JSON.parse_string(f.get_as_text())
	for k: String in counts:
		var cap := int(budget.get(k, -1))
		print("HUDCLUTTER   %s%s: %d (budget %d)" % [tag, k, counts[k], cap])
		ok(cap >= 0 and int(counts[k]) <= cap, "%s%s: %d within the budget of %d" % [tag, k, counts[k], cap])


func _overlap(zone: Rect2, rects: Array, tag: String) -> void:
	ok(zone.has_area(), tag + "the hunter is on screen (zone %s)" % str(zone))
	var hits: Array = []
	for e in rects:
		if (e[1] as Rect2).intersects(zone):
			hits.append("%s %s" % [e[0], str(e[1])])
	ok(hits.is_empty(), tag + "no HUD element over the hunter (%d checked): %s" % [rects.size(), hits.slice(0, 4)])


func _shot(dir: String, file: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("HUDCLUTTER   no renderer: no screenshot")
		return
	if dir == "":
		dir = OS.get_user_data_dir().path_join("hud_clutter")
	DirAccess.make_dir_recursive_absolute(dir)
	await main.get_tree().process_frame
	var path := dir.path_join(file + ".png")
	main.get_viewport().get_texture().get_image().save_png(path)
	print("HUDCLUTTER   screenshot ", path)
