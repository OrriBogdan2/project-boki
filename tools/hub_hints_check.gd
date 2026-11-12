extends RefCounted
## --hub-hints-check [--shots-dir=<dir>] (briefs/design/GARDEN.md 10): the first-time hints in the garden
## hub. A new player arriving there gets the Waystone line, then (near the nest corner) the nest line,
## then the sleeping zone's two-keys line: each once, one at a time, in the message lane and never a
## panel. A second visit says nothing. With --shots-dir (needs a renderer) the first hint is saved as
## <dir>/hub_hint.png.

const WAIT_S := 30.0      # s to wait for the hub to finish building before failing

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("HUBHINT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	await _hub(m)
	print("HUBHINT %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)

func _new_save() -> void:
	var d := Save.fresh()
	(d["roster"] as Array).append(Save.new_kin("zapple", "Pip"))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)

func _arrived(m: Node):
	var t := 0.0
	while t < WAIT_S:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
		var cur = Game.main.current
		var built: bool = is_instance_valid(cur) and cur.get("hhints") != null and cur.get("player") != null
		if built and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered:
			return cur
	return null

func _shot(m: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			var dir := String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
			await Game.main.fade.reveal(0.01)      # the boot splash stays up when a check goes straight to a scene
			await m.get_tree().create_timer(0.8).timeout      # the hint fades in
			await RenderingServer.frame_post_draw
			m.get_viewport().get_texture().get_image().save_png(dir.path_join("hub_hint.png"))

func _hub(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await _arrived(m)
	ok(hub != null, "the hub loads")
	if hub == null:
		return
	var lane := MsgLane.of(hub.root_ui)
	var rules := HubHints.rules()
	var gap := float(rules["gap_s"])
	var seen: Dictionary = Save.d["tutorial"].get_or_add("hub_hints", {})
	lane.clear()
	seen.clear()
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(0.1)
	ok(lane.count() == 0 and seen.is_empty(), "nothing shows in the first moment")
	hub.hhints.tick(float(rules["start_s"]))
	ok(lane.count() == 1 and seen.has("waystone") and "ring" in lane.texts()[0], "the Waystone hint shows first")
	ok(Settings.key_cap("interact") in lane.texts()[0], "it names the interact key")
	ok(hub.panel_open == "" and not Overlay.is_open(), "it is a line in the lane, not a panel")
	await _shot(m)
	hub.hhints.tick(gap * 0.5)
	ok(lane.count() == 1 and seen.size() == 1, "no second hint while the first is still up")
	hub.hhints.tick(gap)
	ok(seen.has("keys") and not seen.has("nest") and "two keys" in lane.texts().back(), "next: the keys (no nest yet)")
	hub.NEST_AT = hub.ppos + Vector3(3, 0, 0)
	hub.hhints.tick(gap)
	ok(seen.has("nest") and "nest corner" in lane.texts().back(), "near the nest corner: its hint shows")
	var n := lane.count()
	hub.hhints.tick(gap)
	ok(lane.count() == n and seen.size() == 3, "each hint shows once")
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(100.0)
	ok(lane.count() == n, "a later visit says nothing")
	seen.clear()
	hub.hhints = HubHints.new(hub)
	hub.panel_open = "x"
	hub.hhints.tick(100.0)
	ok(lane.count() == n and seen.is_empty(), "nothing shows over an open panel")
	hub.panel_open = ""
	Content.rules("farm_build")["base_mode"] = false
