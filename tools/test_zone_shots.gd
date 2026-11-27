extends RefCounted
## --test-zone-shots [--shots-dir=<dir>] [--sizes=WxH,..]: the owner's Test Zone as a player sees it (run under a
## renderer, GPU for the owner sheet): just entered, its page open, a monster and a Boki partner spawned, a fight
## with a dummy, the Practice tools switched on, and the L practice menu. Each stage saves
## <dir>/tz_<stage>_<W>x<H>.png and prints
## TZSHOT lines: every pair of HUD groups that overlap (SafeArea) and every group over your Hunter (HunterZone).
## `overlaps` is also what --test-zone-check holds to zero. The Test Zone page and the L menu are modals over a
## dimmed or blurred screen, so they are shot but not counted: the HUD behind them is judged in the stages around them.

const SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SETTLE_FRAMES := 12  # frames after a stage change (HUD slide-ins, toasts) before it is judged
const SETTLE_MAX := 300  # frames at most to wait for the camera to stop easing (it drifts after a resize or a teleport)
const SETTLE_PX := 0.5  # the Hunter's screen box moved less than this between frames: the camera has settled
const FIGHT_S := 2.0  # s of match time with a dummy hit every 0.5 s before the fight shot
const OWN_DRAWN := ["plate", "grip_icons"]  # your own plate and its grip icons: part of your Hunter, by design
const STATIONS := ["bench", "toast", "drills"]  # the popups to open one at a time (station())
const STATION_GROUP := {"bench": "ParityBench/", "toast": "toast #", "drills": "MoveDrills/"}  # (the group name each station's popup shows up under)
const HUD := "Hud"
const FPS := "fps_counter"  # the frame-rate readout's group (Overlay.fps_lbl, on its own layer above the match)
const FPS_MODE := 2  # Settings show_fps: 2 = the performance overlay, the largest readout
const DUMMY_GAP := 4.0  # m between you and the dummy in the fight stage

var main: Node
var dir := ""


## The HUD groups on screen: the HUD's own, the practice tools' layer, drawn panels and toasts (name -> Rects).
static func groups(m: Match) -> Dictionary:
	var sz := Vector2(m.hud.c.size)
	var out := {}
	# every layer of the match: the HUD, the Arena's key line and meter, the Practice bar, the kit drill banner
	var layers: Array = m.find_children("*", "CanvasLayer", true, false)
	if not layers.has(m.hud):
		layers.append(m.hud)
	var cards: Array[Rect2] = m.hud.msgs.rects()  # (the message lane's cards are toasts, a group each)
	for layer: CanvasLayer in layers:
		if layer == m.arena.menu_layer:
			continue  # the L menu is a modal on a dimmed screen: it is drawn over the HUD on purpose
		var found := SafeArea.groups_of(layer, sz)
		for g: String in found:
			if layer != m.hud or not cards.has(found[g][0]):
				out["%s/%s" % [_owner(m, layer), g]] = found[g]
	for i in cards.size():
		out["toast #%d" % i] = [cards[i]]
	for g: String in SafeArea.seen:
		if g not in OWN_DRAWN:
			out["drawn " + g] = SafeArea.seen[g]
	var fps: Control = Overlay.fps_lbl
	if fps.visible and fps.size.x > 0.0:
		out[FPS] = [fps.get_global_rect()]
	return out


## "<a> overlaps <b>" lines for the groups, and each group that sits on your Hunter.
static func overlaps(m: Match) -> Array:
	var gs := groups(m)
	var found: Array = SafeArea.problems(gs, Vector2(m.hud.c.size)).filter(func(p): return " overlaps " in String(p))
	var zone := HunterZone.rect(m)
	for g: String in gs:
		for r: Rect2 in gs[g]:
			if zone.has_area() and r.intersects(zone):
				found.append("%s %s covers your Hunter %s" % [g, r, zone])
	return found


## A layer's readable name: the node that owns it (a generated "@CanvasLayer@12" says nothing).
static func _owner(m: Match, layer: CanvasLayer) -> String:
	if layer == m.hud:
		return HUD
	return "Arena" if layer == m.arena.layer else String(layer.get_parent().name)


## The popups, panels and toasts: every group that is not the HUD's own panels (nor the fps readout itself).
static func popups(gs: Dictionary) -> Array:
	var own := func(g: String) -> bool: return g == FPS or g.begins_with(HUD + "/") or g.begins_with("drawn ")
	return gs.keys().filter(func(g: String): return not own.call(g))


## The pairs the owner reported (11-26), each judged on its own so a regression names them: the frame-rate counter
## against every popup, and the minimap against every popup (the practice stations' above all
## among them). Each entry is [a, b, overlaps].
static func pairs(gs: Dictionary) -> Array:
	var out: Array = []
	var map: Array = gs.get("drawn minimap", [])
	for g: String in popups(gs):
		for edge: Array in [[FPS, gs.get(FPS, [])], ["minimap", map]]:
			var hit := false
			for r: Rect2 in gs[g]:
				hit = hit or (edge[1] as Array).any(func(o: Rect2): return r.intersects(o))
			out.append([edge[0], g, hit])
	return out


static func _still(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < SETTLE_PX and a.size.distance_to(b.size) < SETTLE_PX


## Lets the HUD and the camera settle (slide-ins, toasts, the view easing onto your Hunter), recording what it draws,
## and returns overlaps().
static func judge(tree: SceneTree, m: Match) -> Array:
	SafeArea.recording = true
	var last := HunterZone.rect(m)
	var i := 0
	while i < SETTLE_FRAMES or (i < SETTLE_MAX and not _still(last, HunterZone.rect(m))):
		last = HunterZone.rect(m)
		SafeArea.seen.clear()
		m.hud.panels.queue_redraw()
		await tree.process_frame
		i += 1
	SafeArea.recording = false
	return overlaps(m)


func run(main_node: Node) -> void:
	main = main_node
	var sizes: Array = SIZES
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		elif arg.begins_with("--sizes="):
			sizes = []
			for s in arg.substr(8).split(","):
				sizes.append(Vector2i(int(s.get_slice("x", 0)), int(s.get_slice("x", 1))))
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	for size: Vector2i in sizes:
		await _zone(size)
		await _grounds(size)
	main.get_tree().quit(0)


func _zone(size: Vector2i) -> void:
	main.get_window().size = size
	for i in 3:
		await main.get_tree().process_frame
	Save.no_write = true
	Settings.set_v("show_fps", FPS_MODE, false)
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start(TestZone.opts())
	if main.fade != null:
		await main.fade.reveal(0.01)
	main.set("current", m)
	await _stage(m, "entered", size)
	Overlay.open_test_zone()
	await _stage(m, "page", size)
	Overlay.close()
	TestZone.spawn_mob(m, String(Data.MOBS.keys()[0]))
	m.arena.set_kin("cindle")
	await _stage(m, "spawned", size)
	var dm: Hunter = m.arena.dummies[0]["h"]
	dm.teleport(m.player.pos - Vector3(sin(m.player.face), 0.0, cos(m.player.face)) * DUMMY_GAP)
	for i in int(FIGHT_S / Match.DT):
		m.step(Match.DT)
		if i % 30 == 0:
			dm.hurt(80.0, m.player)
	await _stage(m, "fight", size)
	if m.arena.has_method("set_tools"):  # (the old Test Zone had no such switch: its tools were always on)
		m.arena.set_tools(true)
	await _stage(m, "tools", size)
	m.arena.open_menu()
	await _stage(m, "menu", size)
	m.arena.close_menu()
	await _popups(m, size, "zone")
	m.queue_free()
	await main.get_tree().process_frame


## Opens (or closes) one popup of the practice stations: the parity bench, a toast, and the
## Drills banner (it runs on once started: the Training Area's drills only).
static func station(m: Match, id: String, on: bool) -> void:
	var pr := Practice.of(m)
	match id:
		"bench":
			if pr.bench.is_open() != on:
				pr.bench.toggle()
		"toast":
			if on:
				m.hud.toast("Practice stations: bench, Drills", Color("f3eee2"))
		"drills":
			if on and pr.drills and pr.drills.state == MoveDrills.State.OFF:
				pr.drills.press()


## Each practice station's popup on its own, over the tools.
func _popups(m: Match, size: Vector2i, zone: String) -> void:
	for id: String in STATIONS:
		if id == "drills" and Practice.of(m).drills == null:
			continue
		station(m, id, true)
		await _stage(m, "%s-%s" % [zone, id], size)
		station(m, id, false)


## The Training Grounds (the Arena): its first-time kit drill panel up, then the same popups.
func _grounds(size: Vector2i) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts())
	if main.fade != null:
		await main.fade.reveal(0.01)
	main.set("current", m)
	await _stage(m, "grounds-entered", size)
	await _popups(m, size, "grounds")
	m.queue_free()
	await main.get_tree().process_frame


func _stage(m: Match, stage: String, size: Vector2i) -> void:
	var found: Array = await judge(main.get_tree(), m)
	for pr: Array in pairs(groups(m)):
		print("TZSHOT   PAIR %s | %s vs %s: %s" % [stage, pr[0], pr[1], "OVERLAP" if pr[2] else "clear"])
	var tag := "%s %dx%d" % [stage, size.x, size.y]
	print("TZSHOT %s: %d overlaps (window %s, HUD %s)" % [tag, found.size(), main.get_window().size, m.hud.c.size])
	for f in found:
		print("TZSHOT   %s | %s" % [tag, f])
	if dir != "":
		var file := "tz_%s_%dx%d.png" % [stage, size.x, size.y]
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
