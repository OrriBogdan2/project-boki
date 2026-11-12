extends RefCounted
## --hub-hints-check [--shots-dir=<dir>] (briefs/design/GARDEN.md 10): the first-time hints in the garden
## hub. A new player arriving there gets the Waystone line, then (near the nest corner) the nest line,
## then the sleeping zone's two-keys line, and by the Incubator once its first egg is placed (never
## before) the egg's line: each once, one at a time, in the message lane and never a panel. A second
## visit says nothing. With --shots-dir (needs a renderer) the first hint is saved as <dir>/hub_hint.png.

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

## By the Incubator: nothing while no egg is in it; the first egg placed brings its one line, which names
## no number (the hatch time is data).
func _egg(hub, lane: MsgLane, seen: Dictionary, gap: float) -> void:
	hub.INCUB_AT = hub.ppos + Vector3(-3, 0, 0)
	lane.clear()
	hub.hhints.tick(gap)
	ok(lane.count() == 0 and not seen.has("egg"), "by the Incubator with no egg in it: no egg line")
	Incubator.add(String(Data.common_kin()[0]))
	hub.hhints.tick(gap)
	var said := ", ".join(lane.texts())
	var one_line: bool = seen.has("egg") and lane.count() == 1 and said.begins_with("It grows while you play")
	ok(one_line, "the first egg placed: its line (%s)" % said)
	ok(RegEx.create_from_string("\\d").search(said) == null, "the line names no number")

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
	_egg(hub, lane, seen, gap)
	var n := lane.count()
	hub.hhints.tick(gap)
	ok(lane.count() == n and seen.size() == 4, "each hint shows once")
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(100.0)
	ok(lane.count() == n, "a later visit says nothing")
	seen.clear()
	hub.hhints = HubHints.new(hub)
	hub.panel_open = "x"
	hub.hhints.tick(100.0)
	ok(lane.count() == n and seen.is_empty(), "nothing shows over an open panel")
	hub.panel_open = ""
	_seed(hub)
	Content.rules("farm_build")["base_mode"] = false

class FakeHud:
	var lines: Array = []
	func tip(text: String) -> void:
		lines.append(text)

## The Wayseed's two once-per-save hints: the line on a run, then the Waystone's pulse at home.
func _seed(hub) -> void:
	var tut: Dictionary = Save.d["tutorial"]
	var hud := FakeHud.new()
	tut.erase("wayseed_tip")
	HubHints.seed_in_bag(hud)
	var plain := "Wayseed: plant it at the Waystone at home to open a new garden zone."
	ok(hud.lines == [plain], "the first Wayseed in the pack says what it is")
	var longest := 0
	for e in HubHints.rules()["list"]:
		longest = maxi(longest, String(e["text"]).length())
	ok(plain.length() <= longest, "no longer than the hub's own hints (%d of %d chars)" % [plain.length(), longest])
	HubHints.seed_in_bag(hud)
	ok(hud.lines.size() == 1, "once per save: the second says nothing")
	tut.erase("wayseed_tip")
	Settings.v["tips"] = false
	HubHints.seed_in_bag(hud)
	ok(hud.lines.size() == 1 and not tut.has("wayseed_tip"), "tips off: nothing, and it stays unseen")
	Settings.v["tips"] = true
	var seen: Dictionary = tut["hub_hints"]
	seen.erase("seed_pulse")
	Save.d["items"].erase("wayseed_glasswater")
	var node: Node3D = hub.hway.node
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(100.0)
	ok(not seen.has("seed_pulse") and node.scale == Vector3.ONE, "no Wayseed held: no pulse")
	Save.add_item("wayseed_glasswater", 1)
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(float(HubHints.rules()["start_s"]))
	ok(seen.has("seed_pulse"), "holding one on arrival: the Waystone pulses")
	hub.hhints.tick(0.1)
	ok(node.scale != Vector3.ONE and hub.panel_open == "" and not Overlay.is_open(), "it is moving and blocks nothing")
	hub.hhints.tick(float(HubHints.rules()["pulse_s"]))
	ok(node.scale == Vector3.ONE, "it settles back to its size")
	hub.hhints = HubHints.new(hub)
	hub.hhints.tick(float(HubHints.rules()["start_s"]))
	hub.hhints.tick(0.1)
	ok(node.scale == Vector3.ONE, "a later arrival holding one: no second pulse")
	Save.add_item("wayseed_glasswater", -1)
