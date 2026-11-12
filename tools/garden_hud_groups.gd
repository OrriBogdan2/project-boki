extends RefCounted
## --garden-hud-groups [--shots-dir=<dir>]: the garden's screen on day 1 and day 5, in the hub and in two zones.
## For each of the six screens it prints the cards that open on arrival and the HUD groups on show (a group = a
## separately placed block the player has to scan: a visible child of the home's UI, with a size), then the signs
## in view. Day 1 must stay at DAY1_MAX groups (asserted by --garden-first-day-check). With --shots-dir it also
## grabs one picture each (needs a renderer: jobq --needs gpu). Never touches the real save.

const ZONES := ["glasswater", "cinderstep"]       # the two zones shot besides the hub
const CAST := ["zapple", "puddlet", "cindle", "kilnbadger"]
const SETTLE := 40                                # frames for the arrival, the first toasts and the light
const FULL_PX := 1200.0                           # px: a full-width block is a dim or a host, not a group
const DAY1_MAX := 5                               # HUD groups on a day-1 screen (DECISIONS 2026-11-08: about 5)
const MAX_CARDS := 8                              # arrival cards followed before giving up
const MIN_PX := 4.0                               # px: a block thinner than this is not a group
const DAY5_JOURNAL := ["ate a snack", "won a race", "napped in the pile", "made a friend"]

var main: Node
var dir := ""

## The save for a day: day 1 is the fresh save with its first-day list running; day 5 has the list paid, four Boki
## with a few journal lines, the zones open and today's wishes drawn.
static func make_save(day: int, zone: String) -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var now := Time.get_unix_time_from_system()
	var d := Save.fresh()
	for i in (2 if day == 1 else CAST.size()):
		var rec := Save.new_kin(CAST[i], "B%d" % i)
		Care.ensure(rec)
		if zone != "":
			rec["zone"] = zone
		if day > 1:
			rec["level"] = 5 + i
			Care.change(rec, "food" if i % 2 == 0 else "joy", -90.0)      # hungry, bored: today's wishes
			for words in DAY5_JOURNAL.slice(0, i + 1):
				CareJournal.note(rec, words, now - 3600.0)
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	var tut: Dictionary = d["tutorial"]
	tut.merge({"hatched": true, "intro": true})
	if day == 1:
		tut["chips_seen"] = {}      # a new save: the counters come when there is something to count
	else:
		tut.merge({"home": true, "day1_done": true})      # a farm save upgraded: it has seen every counter
	d["gems"] = 40 if day == 1 else 600
	if day > 1:
		tut["gfd"]["paid"] = true
		for id in GardenFirstDay.rules()["rows"].map(func(r): return String(r["id"])):
			tut["gfd"]["did"][id] = true
	HomeLayout.new_fs(d, 5)
	if zone != "":
		d["zones"][zone] = {"open": true}
	Save.d = d
	if day > 1:
		d["away_seen"] = now - 7200.0      # last here two hours ago: the arrival has a journal to read
		GardenWishes.today(now)

## The visible blocks of the home's UI (its root and the layer around it): their first words and rect.
static func groups_of(home: Node) -> Array:
	var out: Array = []
	for c in home.root_ui.get_children() + home.ui.get_children().filter(func(n): return n != home.root_ui):
		if c is HomeDashSlot and c.visible:      # drawn across the whole screen: the slot itself is the group
			out.append("Dash slot")
		elif c is Control and c.is_visible_in_tree() and c.modulate.a > 0.05 \
				and c.get_global_rect().size.x > MIN_PX and c.get_global_rect().size.y > MIN_PX \
				and c.get_global_rect().size.x < FULL_PX:
			out.append("%s: %s" % [_what(c), c.get_global_rect()])
	return out

## A short name for a block: its first words.
static func _what(c: Control) -> String:
	var found: Array = c.find_children("*", "Label", true, false).filter(
			func(l): return l.is_visible_in_tree() and l.text != "")
	if found.is_empty():
		return "%s %s" % [c.get_class(), c.name]
	return String((found[0] as Label).text).left(40).replace("\n", " / ")

func _open(zone: String) -> Node:
	if zone == "":
		return await main._hb_home()
	var hm: Node = load("res://scripts/home/home.gd").new()
	hm.zone = zone
	main.add_child(hm)
	main.current = hm
	return hm

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## The cards that open on arrival before the player can act: their titles, each closed to let the next come.
func _arrival_cards(home: Node) -> Array:
	var titles: Array = []
	for i in MAX_CARDS:
		if UiFocus.panel == "":
			break
		titles.append(String(UiFocus.panel))
		home._close_panel()
		await _frames(2)
	return titles

## The signs in the camera's view, one line each.
func _signs(home: Node) -> void:
	var cam := main.get_viewport().get_camera_3d()
	for l in home.find_children("*", "Label3D", true, false):
		if l.is_visible_in_tree() and l.text != "" and cam.is_position_in_frustum(l.global_position):
			print("GARDENHUD   sign: %s" % String(l.text).left(50).replace("\n", " / "))

## One screen: its save, the home, a settle, the arrival cards, the group list, the picture. {groups, cards}.
func screen(day: int, zone: String) -> Dictionary:
	make_save(day, zone)
	var home = await _open(zone)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	await _frames(SETTLE)
	var cards := await _arrival_cards(home)
	await _frames(SETTLE)      # the dim behind the last card fades out
	var groups := groups_of(home)
	var tag := "%s_day%d" % [zone if zone != "" else "hub", day]
	print("GARDENHUD %s: %d groups, %d arrival cards: %s" % [tag, groups.size(), cards.size(), ", ".join(cards)])
	for g in groups:
		print("GARDENHUD   %s" % g)
	_signs(home)
	if dir != "":
		main.get_viewport().get_texture().get_image().save_jpg(dir.path_join(tag + ".jpg"), 0.9)
	home.queue_free()
	await _frames(2)
	return {"groups": groups, "cards": cards}

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	main.get_tree().root.size = Vector2i(1280, 720)
	await _frames(10)
	for day in [1, 5]:
		for zone in [""] + ZONES:
			await screen(day, zone)
	print("GARDENHUD DONE")
	main.get_tree().quit()
