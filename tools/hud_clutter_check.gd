extends RefCounted
## --hud-clutter-check [--hunter=<id>] [--shots-dir=<dir>]: an ABSOLUTE combat-HUD check for the merge gate.
## A real match, the player on autoplay with a rival bot dropped next to them, runs ~5 s of fight, then:
##   1. the HUD's visible element count (Control nodes, labels, toasts, banners, loot rows, drawn panel
##      groups) stays within ops/hud-budget.json, per category and in total; the count is printed
##   2. no visible HUD rect (Control nodes, drawn panels, message cards, the knock banner) overlaps the
##      hunter's screen box (HunterZone.rect: feet to the top of the overhead plate)
##   3. with a renderer (xvfb, not --headless) a screenshot is saved to --shots-dir (default: user data dir)
## --hunter=<id> plays that Hunter (the full HUD) mid-cast (E) and mid-ult (X) in a duo: the teammate is down and
## the Boki is summoned. Run one Hunter per process (the HUD keeps some state between matches).
## To raise the budget on purpose, change ops/hud-budget.json in the same PR and say why; the owner must OK it.
## Never touches the save.

const BUDGET_PATH := "res://ops/hud-budget.json"
const FIGHT_S := 5.0  # s of match time before the HUD is judged
const RIVAL_GAP := 5.0  # m between the player and the rival dropped beside them
const HIT_BEFORE_S := 1.0  # s before FIGHT_S that the player lands one real hit on the rival
const FIGHT_EXTRA_S := 15.0  # s more a Hunter scene may wait for a hit given or taken
const CAST_S := 0.3  # s after the cast or ult press that the HUD is judged
const MATE_GAP := 30.0  # m behind the player the teammate waits, away from the rival
const BANNER_FRAMES := 600  # frames to wait for the knock banner to close
const MOMENTS := ["cast", "ult"]
const FULL_SCREEN := 0.9  # share of the screen a Control must cover to be a backdrop (looked inside, not counted)

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("HUDCLUTTER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	var shots := ""
	var hunter := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		elif String(a).begins_with("--hunter="):
			hunter = String(a).substr(9)
	Save.no_write = true
	Econ.ensure()
	if hunter == "":
		await _scene("", "", shots)
	else:
		for moment in MOMENTS:
			await _scene(hunter, moment, shots)
	print("HUDCLUTTER DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## One judged match. With a hunter id the player is that Hunter in a duo whose teammate is down, with their
## Boki summoned and a rival beside them, caught `moment` ("cast": the E ability, "ult": the ultimate) just
## after the press; without one it is the plain fight.
func _scene(arch: String, moment: String, shots: String) -> void:
	var tag := "" if arch == "" else "%s %s: " % [arch, moment]
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
	var hit_at := int((FIGHT_S - HIT_BEFORE_S) / Match.DT)
	for i in int((FIGHT_S + (FIGHT_EXTRA_S if arch != "" else 0.0)) / Match.DT):
		m.step(Match.DT)
		if i == hit_at:  # one landed hit before judging: the fight never hangs on the seed's AI
			rival.hurt(10.0, m.player)
		if i % 20 == 0:
			await main.get_tree().process_frame
		if arch != "" and m.time >= FIGHT_S and m.hud.in_fight():
			break
	if arch != "":
		await _stage(m, rival)
		_press(m.player, moment)
		for i in int(CAST_S / Match.DT):
			m.step(Match.DT)
	m.hud.panels.queue_redraw()
	await main.get_tree().process_frame
	SafeArea.seen.clear()
	SafeArea.recording = true
	m.hud.panels.queue_redraw()
	for i in 4:
		await main.get_tree().process_frame
	SafeArea.recording = false
	var zone := HunterZone.rect(m)
	var seen: Dictionary = SafeArea.seen.duplicate()
	var counts := _counts(m, seen)
	ok(
		m.hud.in_fight(),
		"%sthe HUD is judged in a fight (a hit given or taken within %d s)" % [tag, int(m.hud.MSG_FIGHT_S)]
	)
	_budget(counts, tag)
	_overlap(zone, _hud_rects(m, seen), tag)
	await _shot(shots if arch == "" else shots.path_join("%s_%s" % [arch, moment]))
	m.queue_free()
	await main.get_tree().process_frame


## The teammate knocked (they stay down; the banner is waited out, the match clock stands still) and the Boki
## summoned.
func _stage(m: Match, rival: Hunter) -> void:
	m.knock(_mate(m), rival, {})
	KinSummon.press(m.player)
	for i in BANNER_FRAMES:
		if m.hud.knocks.kind == "":
			return
		await main.get_tree().process_frame


func _mate(m: Match) -> Hunter:
	return m.hunters.filter(func(h): return h != m.player and h.team == m.player.team)[0]


## The E cast or the ultimate pressed.
func _press(p: Hunter, moment: String) -> void:
	p.ak.cd["e"] = 0.0
	p.ak.cd["x"] = 0.0
	if moment == "ult":
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


func _shot(dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("HUDCLUTTER   no renderer: no screenshot")
		return
	if dir == "":
		dir = OS.get_user_data_dir().path_join("hud_clutter")
	DirAccess.make_dir_recursive_absolute(dir)
	await main.get_tree().process_frame
	var path := dir.path_join("hud_clutter.png")
	main.get_viewport().get_texture().get_image().save_png(path)
	print("HUDCLUTTER   screenshot ", path)
