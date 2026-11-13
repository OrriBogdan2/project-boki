extends RefCounted
## --safe-area-check: the HUD and the main screens at five window sizes (1280x720, 1920x1080, 2560x1440,
## 2560x1080 ultrawide, 1024x640). At each, every group (a registered HUD panel, or a top-level control of a
## screen) sits inside SafeArea's margin and no two groups of one screen overlap. The match HUD is read from
## SafeArea's registry; the pick (prematch), pause, results, farm HUD and expedition panel from their controls.
## The Ways Out widgets (the strip, its one line, the Gate prompt, the uplink's status, the Blight line and the
## edge markers) are checked in each of their states, and every direction an edge marker can point.
## --hud-scale=0.8..1.3 runs either at that HUD size (Settings hud_scale).
## --safe-area-shots [--size=WxH] --shots-dir=<dir>: the same run with a real renderer, one PNG per screen
## and size (<dir>/<W>x<H>_<screen>.png) and a contact sheet of them.

const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(2560, 1080),
		Vector2i(1024, 640)]
const RESULT := {"extracted": true, "gems": 42, "seeds": {"sunroot": 1}, "caught": [], "knocks": 3, "damage": 512,
		"taken": 388, "kills": 1, "downs": 1, "deaths": 0, "revives": 2, "armor_tier": 3, "time": 201.0}

var main: Node
var bad := 0
var shots := ""
var sizes: Array = SIZES.duplicate()
var m: Match
var home

func ok(cond: bool, what: String) -> void:
	print("SAFEAREA %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
		if String(a).begins_with("--hud-scale="):      # (HUD size for this run only: nothing is saved)
			Settings.v["hud_scale"] = float(String(a).substr(12))
		if String(a).begins_with("--size="):
			var wh := String(a).substr(7).split("x")
			sizes = [Vector2i(int(wh[0]), int(wh[1]))]
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(shots)
	if main.fade:
		await main.fade.reveal(0.01)
	await _hud()
	await _ways_out()
	await _screens()
	await _farm()
	print("SAFEAREA DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Resizes the window and returns the logical size the interface is laid out in.
func _resize(win: Vector2i) -> Vector2:
	main.get_tree().root.size = win
	await _frames(3)
	return main.get_tree().root.get_visible_rect().size

func _judge(screen: String, win: Vector2i, groups: Dictionary, sz: Vector2) -> void:
	var tag := "%dx%d %s" % [win.x, win.y, screen]
	var problems := SafeArea.problems(groups, sz)
	var what := "%s: %d groups in the %d px margin, no overlap (logical %s) %s"
	ok(not groups.is_empty() and problems.is_empty(),
			what % [tag, groups.size(), int(SafeArea.MARGIN), sz, problems.slice(0, 4)])
	if shots != "":
		await _frames(2)
		main.get_viewport().get_texture().get_image().save_png("%s/%dx%d_%s.png" % [shots, win.x, win.y, screen])

func _hud() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 3, "tier": 0, "length": 1500.0, "seed": 7, "demo_kin": "cindle"})
	m.set_process(false)
	main.current = m      # (the pause menu reads its options; the next screen frees it)
	for line in ["Kael knocked Ryzz down", "Team 3 is out", "Ember revived Pip"]:
		m.feed.append({"text": line, "t": 0.0})
	m.hud.toast("Picked up a long-range rifle", Color.WHITE)
	m.hud.toast("Armor cracked: it held one more hit", Color.WHITE)
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		await _hud_at(win, sz, "drop")
		m.player.riding = false
		m.player.dropping = false
		await _hud_at(win, sz, "hud")
		Overlay.open_pause("match")
		await main.get_tree().create_timer(0.8).timeout
		await _judge("pause", win, SafeArea.groups_of(Overlay.host, sz), sz)
		Overlay.close()

func _hud_at(win: Vector2i, sz: Vector2, screen: String, with_toasts := true) -> void:
	for i in 3:      # (HUD size holds a corner's growth to what its neighbour leaves, read from the pass before)
		m.hud.panels.queue_redraw()
		await _frames(1)
	SafeArea.seen.clear()
	SafeArea.recording = true
	m.hud.panels.queue_redraw()
	await _frames(4)
	SafeArea.recording = false
	if with_toasts and not m.hud.map_open():      # (the full map hides the lane)
		SafeArea.seen["toasts"] = m.hud.msgs.rects()
	var groups := SafeArea.seen.duplicate()
	var faded: Array = groups.get("waypoint_faded", [])
	groups.erase("waypoint_faded")
	if not faded.is_empty():      # (an edge marker faded under a message: it may sit under the lane, nothing else)
		var rest := groups.duplicate()
		rest.erase("toasts")
		rest["waypoint_faded"] = faded
		var bad := SafeArea.problems(rest, sz)
		ok(bad.is_empty(), "%dx%d %s: the faded edge marker stays in the margin, off everything but the lane %s"
				% [win.x, win.y, screen, bad.slice(0, 4)])
	await _judge(screen, win, groups, sz)

# ------------------------------------------------------------------ the Ways Out widgets
const WAYS_STATES := ["locked", "unlocked", "quest_racing", "uplink_far", "last_way_out", "last_way_out_dead",
		"gate_prompt", "outside_ring"]
const WAYS_GROUP := {"locked": "ways_strip", "unlocked": "waypoint", "quest_racing": "exit_status",
		"uplink_far": "waypoint", "last_way_out": "ways_strip", "last_way_out_dead": "ways_line",
		"gate_prompt": "gate_prompt", "outside_ring": "blight_line"}
const EDGE_ANGLES := 16
const BELT := ["vitals", "abilities", "weapon", "gear", "kin"]      # what a marker's box must stay off

func _ways_out() -> void:
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		var prompt: Array = []
		for st: String in WAYS_STATES:
			_ways_set(st)
			await _hud_at(win, sz, "ways_" + st)
			var g: String = WAYS_GROUP[st]
			var drew := SafeArea.seen.has(g) or (g == "waypoint" and SafeArea.seen.has("waypoint_faded"))
			var want := HudGroups.ways_out_shown(m) or st != "locked"      # (the strip waits for a seat)
			ok(drew == want, "%dx%d ways_%s: draws its %s" % [win.x, win.y, st, WAYS_GROUP[st]])
			if st == "gate_prompt":
				prompt = SafeArea.seen["gate_prompt"] + SafeArea.seen["gate_stay"]
		_ways_set("locked")
		await _hud_at(win, sz, "ways_locked")
		_edge_sweep(win, sz, prompt)

## Puts the match in one Ways Out state: seats on the clock, the Heart, the outposts, where the player stands.
func _ways_set(st: String) -> void:
	var P: Hunter = m.player
	var H: Heart = m.heart
	var q: Dictionary = Heart.rules()["quest"]
	var foe: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var out_x: Dictionary = m.exits.list.filter(func(x): return x["kind"] == "outpost")[0]
	m.hud.full_map.close()
	P.inp["interact"] = false
	H.interact_for(P)      # (a released key clears the Gate's hold, so each size starts it afresh)
	H.carrier = null
	H.early_team = -1
	H.final_team = -1
	H.final_prog = 0.0
	H.charge = 0.0
	H._force(Heart.S.ASLEEP, "check")
	P.out = false
	m.interact = {}
	out_x["state"] = "idle"
	m.sess_t0 = 30.0 - m.time
	P.teleport(m.world.free_spot_near(H.site + Vector3(14, 0, 10), [], 1.0, 0.45, 6.0))
	match st:
		"unlocked":
			m.sess_t0 = float(q["lair_open_s"]) + 40.0 - m.time
			H.charge = Heart.r("charge_s")
			H._force(Heart.S.READY, "check")
		"quest_racing", "uplink_far":
			m.sess_t0 = float(q["uplink_open_s"]) + 20.0 - m.time
			out_x["state"] = "charging"
			out_x["prog"] = 0.4
			out_x["contested"] = st == "quest_racing"
			out_x["team"] = (foe if st == "quest_racing" else P).team
			if st == "quest_racing":
				P.teleport(m.world.free_spot_near(out_x["pos"], [], 1.0, 0.45, 6.0))
			else:
				P.teleport(m.world.free_spot_near(out_x["pos"] + Vector3(60, 0, 0), [], 1.0, 0.45, 6.0))
		"last_way_out", "last_way_out_dead":
			m.sess_t0 = Heart.r("final_s") + 30.0 - m.time
			H.early_team = foe.team
			H.final_team = P.team
			H.final_prog = 0.4
			H.charge = Heart.r("charge_s")
			H._force(Heart.S.FINAL, "check")
			P.out = st == "last_way_out_dead"
		"gate_prompt":
			H.charge = Heart.r("charge_s")
			H.carrier = P
			H._force(Heart.S.CARRIED, "check")
			P.teleport(H.gate + Vector3(0, 0, 3.0))
			P.inp["interact"] = true
			H.hold(P, H.interact_for(P), 1.7)
			m.interact = H.interact_for(P)
		"outside_ring":
			m.sess_t0 = float(Heart.r("tide_start_s")) + float(Heart.r("tide_close_s")) - m.time
			H._force(Heart.S.CHARGING, "check")
			P.teleport(m.world.free_spot_near(H.site + Vector3(Heart.tide_r(m) + 25.0, 0, 0), [], 1.0, 0.45, 6.0))
	m.cam.snap(P.pos)
	m.hud.toast("Picked up a long-range rifle", Color.WHITE)
	m.hud.c.queue_redraw()

## An edge marker pointing every way round, with the longest label: inside the margin, off the bottom row and
## off the Gate prompt (`prompt`, its boxes), at this size.
func _edge_sweep(win: Vector2i, sz: Vector2, prompt: Array) -> void:
	var avoid: Array = prompt.duplicate()
	for g in BELT:
		avoid.append_array(SafeArea.seen.get(g, []))
	var safe := SafeArea.inner(sz).grow(0.5)
	var label_w := TextCache.width(m.hud.big, "Wolfgang has the Heartspark  9999m", MarkerDir.LABEL_FS)
	var bad_dirs: Array = []
	for i in EDGE_ANGLES:
		var d := Vector2.from_angle(TAU * i / EDGE_ANGLES)
		var edge := MarkerDir.edge_point(sz, d)
		for r: Rect2 in [MarkerDir.arrow_rect(edge, d), MarkerDir.label_rect(edge, d, label_w, sz)]:
			if not safe.encloses(r) or avoid.any(func(o: Rect2): return r.intersects(o)):
				bad_dirs.append(i)
	var what := "%dx%d edge markers, %d directions: inside the margin, off the bottom row and the Gate prompt %s"
	ok(bad_dirs.is_empty(), what % [win.x, win.y, EDGE_ANGLES, bad_dirs])

func _screens() -> void:
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		main.show_screen("prematch", {"teams": 10, "squad": 3, "tier": 0})
		await main.get_tree().create_timer(0.8).timeout
		await _judge("pick", win, SafeArea.groups_of(main.current, sz), sz)
		main.show_screen("results", RESULT)
		await main.get_tree().create_timer(1.0).timeout
		await _judge("results", win, SafeArea.groups_of(main.current, sz), sz)

func _farm() -> void:
	home = await main._hb_home()
	for i in 600:
		if home.root_ui != null and home.hub != null and home.player != null:
			break
		await _frames(1)
	home._close_panel()
	for win: Vector2i in sizes:
		var sz := await _resize(win)
		await main.get_tree().create_timer(0.6).timeout
		home._close_panel()      # (a Boki's evolve card can open by itself: it is a panel, not the farm HUD)
		await main.get_tree().create_timer(0.3).timeout      # the key row steps off the hub bar on a 0.2 s beat
		await _judge("farm", win, SafeArea.groups_of(home.root_ui, sz), sz)
		home._open_expedition()
		await main.get_tree().create_timer(0.8).timeout
		await _judge("expedition", win, SafeArea.groups_of(home.panel_host, sz), sz)
