extends RefCounted
## --test-zone-shots [--shots-dir=<dir>] [--sizes=WxH,..]: the owner's Test Zone as a player sees it (run under a
## renderer, GPU for the owner sheet): just entered, its page open, a monster and a Boki partner spawned, a fight
## with a dummy, and the L practice menu. Each stage saves <dir>/tz_<stage>_<W>x<H>.png and prints
## TZSHOT lines: every pair of HUD groups that overlap (SafeArea) and every group over your Hunter (HunterZone).
## `overlaps` is also what --test-zone-check holds to zero.

const SIZES := [Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SETTLE_FRAMES := 12  # frames after a stage change (HUD slide-ins, toasts) before it is judged
const FIGHT_S := 2.0  # s of match time with a dummy hit every 0.5 s before the fight shot
const OWN_DRAWN := ["plate", "grip_icons"]  # your overhead plate and the grip icons on it: part of your own Hunter, by design
const DUMMY_GAP := 4.0  # m between you and the dummy in the fight stage

var main: Node
var dir := ""


## The HUD groups on screen: the HUD's own, the practice tools' layer, drawn panels and toasts (name -> Rects).
static func groups(m: Match, overlay_open: bool) -> Dictionary:
	var sz := Vector2(m.hud.c.size)
	var out := SafeArea.groups_of(m.hud, sz)
	if m.arena and m.arena.layer:
		out.merge(SafeArea.groups_of(m.arena.layer, sz))
	for g: String in SafeArea.seen:
		if g not in OWN_DRAWN:
			out["drawn " + g] = SafeArea.seen[g]
	if overlay_open:
		out.merge(SafeArea.groups_of(Overlay.host, sz))
	return out


## "<a> overlaps <b>" lines for the groups, and each group that sits on your Hunter.
static func overlaps(m: Match, overlay_open: bool) -> Array:
	var gs := groups(m, overlay_open)
	var found: Array = SafeArea.problems(gs, Vector2(m.hud.c.size)).filter(func(p): return " overlaps " in String(p))
	var zone := HunterZone.rect(m)
	for g: String in gs:
		for r: Rect2 in gs[g]:
			if zone.has_area() and r.intersects(zone) and not g.begins_with("Overlay"):
				found.append("%s %s covers your Hunter %s" % [g, r, zone])
	return found


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
	main.get_tree().quit(0)


func _zone(size: Vector2i) -> void:
	main.get_window().size = size
	for i in 3:
		await main.get_tree().process_frame
	Save.no_write = true
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
	await _stage(m, "entered", size, false)
	Overlay.open_test_zone()
	await _stage(m, "page", size, true)
	Overlay.close()
	TestZone.spawn_mob(m, String(Data.MOBS.keys()[0]))
	m.arena.set_kin("cindle")
	await _stage(m, "spawned", size, false)
	var dm: Hunter = m.arena.dummies[0]["h"]
	dm.teleport(m.player.pos - Vector3(sin(m.player.face), 0.0, cos(m.player.face)) * DUMMY_GAP)
	for i in int(FIGHT_S / Match.DT):
		m.step(Match.DT)
		if i % 30 == 0:
			dm.hurt(80.0, m.player)
	await _stage(m, "fight", size, false)
	m.arena.open_menu()
	await _stage(m, "menu", size, true)
	m.arena.close_menu()
	m.queue_free()
	await main.get_tree().process_frame


func _stage(m: Match, stage: String, size: Vector2i, overlay_open: bool) -> void:
	SafeArea.recording = true
	for i in SETTLE_FRAMES:
		SafeArea.seen.clear()
		m.hud.panels.queue_redraw()
		await main.get_tree().process_frame
	SafeArea.recording = false
	var tag := "%s %dx%d" % [stage, size.x, size.y]
	var found := overlaps(m, overlay_open or m.arena.menu_layer != null)
	print("TZSHOT %s: %d overlaps (window %s, HUD %s)" % [tag, found.size(), main.get_window().size, m.hud.c.size])
	for f in found:
		print("TZSHOT   %s | %s" % [tag, f])
	if dir != "":
		main.get_viewport().get_texture().get_image().save_png(dir.path_join("tz_%s_%dx%d.png" % [stage, size.x, size.y]))
