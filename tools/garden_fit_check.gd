extends RefCounted
## --garden-fit-check [--shots-dir=<dir>]: the garden's newer screens (the Waystone's zone cards with locked
## zones and "Move to...", the games board, the Waystone wishes card, the games picker, the Nesting Nook
## preview, the Boki card's Family tab with its lineage) at 1280x720, 1920x1080, 2560x1080, a small
## 960x540 window and 1280x720 with the Interface size slider at its top (1.5). Every visible control must
## sit inside its panel (no overflowing text, nothing cut off sideways), no one-line label or button may clip or
## ellipsize its text, and the panel must sit inside the window's safe margin. With --shots-dir (a real
## renderer: jobq --needs gpu) each is saved as <dir>/<W>x<H>_<screen>.png. Never touches the real save.

const SIZES := [[Vector2i(1280, 720), 1.0], [Vector2i(1920, 1080), 1.0], [Vector2i(2560, 1080), 1.0],
		[Vector2i(960, 540), 1.0], [Vector2i(1280, 720), 1.5]]      # [window, Settings "ui_scale"]
const SAFE_MIN := 16.0       # px (logical), the least gap from a panel to the window's edge (as UI.scroll_panel)
const SLACK := 1.5           # px a control may stick out of its panel (rounding of the torn frames)
const SETTLE := 8            # frames for a panel and its scroll to size themselves
const GROWN := 8             # level at which a Boki can go in the Nook

var bad := 0
var main: Node
var home
var shots_dir := ""
var screens := {
	"zone_cards": func(): ZoneCards.open(home, home.hway.here()),
	"zone_move_to": func(): ZoneCards.move_to(home, home._kin_entry(Save.d["roster"][0])),
	"games_board": func(): ZoneCards.board(home),
	"wishes": func(): _wishes(),
	"games_picker": func(): MinigameHub.open(home),
	"nook_preview": func(): _nook(),
	"boki_card_family": func(): _boki_card(),
}

func ok(cond: bool, what: String) -> void:
	print("GARDENFIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots_dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(shots_dir)
	var nav = load("res://tools/garden_nav_check.gd").new()
	nav.main = m
	nav._save()
	_dress_save()
	home = await nav._open_home()
	ok(not home.hg.demo_place("training_post", HomeLayout.LANDING + Vector3(5.0, 0, 3.0)).is_empty(),
			"a Training post placed (the picker lists its games)")
	await _frames(2)
	ok(not MinigameHub.listed(home).is_empty(), "the picker has games to list")
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	for row in SIZES:
		var px: Vector2i = row[0]
		var user_scale: float = row[1]
		Settings.set_v("ui_scale", user_scale, false)
		main.get_window().size = px
		await _frames(SETTLE)
		for id in screens:
			screens[id].call()
			await _frames(SETTLE)
			var tag := "%dx%d%s_%s" % [px.x, px.y, "" if user_scale == 1.0 else "_ui%s" % user_scale, id]
			_scan(tag)
			if shots_dir != "":
				var img := main.get_viewport().get_texture().get_image()
				img.save_png(shots_dir.path_join(tag + ".png"))
			home._close_panel()
			await _frames(2)
	print("GARDENFIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Six Boki, two Grown friends (the first with a record of parents), three with wishes, a Dash winner on the wall.
func _dress_save() -> void:
	var roster: Array = Save.d["roster"]
	for i in 2:
		roster[i]["level"] = GROWN
		roster[i]["trust"] = 60.0
	roster[0]["lineage"] = {"parents": [], "names": ["Pennyroyal the Wandering", "Bartholomew-Longname"], "gen": 3,
			"nest": {"gifts": 2, "species": true, "habit": true}}
	for i in range(2, 5):
		for n in roster[i]["needs"]:
			roster[i]["needs"][n] = 5.0
	Save.d.erase("wishes")
	Save.d["showcase"] = [{"name": "Pennyroyal the Wandering", "date": "day 12", "twist": "Low-gravity gust week"}]

func _wishes() -> void:
	var v: VBoxContainer = home._new_panel("Today's wishes", 520)
	var w := GardenWishes.today(Time.get_unix_time_from_system())
	ok(not w["list"].is_empty(), "the wishes card has wishes")
	GardenWishes.fill(v, w)

func _nook() -> void:
	home.nook_pick = [Save.d["roster"][0]["uid"], Save.d["roster"][1]["uid"]]
	home._open_nook()

func _boki_card() -> void:
	home.kin_tab = "Family"
	home._open_kin(Save.d["roster"][0])

## Checks the open panel against the window and its own frame.
func _scan(tag: String) -> void:
	var panels: Array = home.panel_host.get_children().filter(func(c): return not c.is_queued_for_deletion())
	ok(not panels.is_empty(), "%s: opens a panel" % tag)
	if panels.is_empty():
		return
	var panel: Control = panels[-1]
	var win := Rect2(Vector2.ZERO, panel.get_viewport_rect().size)
	var frame := panel.get_global_rect()
	ok(win.grow(-SAFE_MIN + 1.0).encloses(frame), "%s: panel %s inside the window %s" % [tag, frame, win.size])
	var stray: Array = []
	for c: Control in panel.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		var limit := frame
		var p := c.get_parent()
		while p != panel and p != null:
			if p is ScrollContainer:
				limit = Rect2(p.global_position.x, -1e6, p.size.x, 2e6)      # scrolls down, never sideways
				break
			p = p.get_parent()
		if not limit.grow(SLACK).encloses(c.get_global_rect()):
			stray.append("%s %s at %s" % [c.get_class(), c.name, c.get_global_rect()])
	ok(stray.is_empty(), "%s: nothing sticks out of its panel (%d: %s)" % [tag, stray.size(), stray.slice(0, 3)])
	var cut: Array = panel.find_children("*", "Control", true, false).filter(_cut_short)
	var texts: Array = cut.slice(0, 3).map(func(c): return c.text)
	ok(cut.is_empty(), "%s: no text cut short (%d: %s)" % [tag, cut.size(), texts])

## A one-line label or button that clips or ellipsizes a text wider than itself.
func _cut_short(c: Control) -> bool:
	if not c.is_visible_in_tree() or c.size.x <= 0.0 or not (c is Label or c is Button) or c.text == "":
		return false
	if c is Label and (c.autowrap_mode != TextServer.AUTOWRAP_OFF or (not c.clip_text
			and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING)):
		return false
	if c is Button and not c.clip_text and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		return false
	var font: Font = c.get_theme_font("font")
	var wide := font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x
	var room: float = c.size.x
	if c is Button:
		room -= c.get_theme_stylebox("normal").get_minimum_size().x + (c.icon.get_width() if c.icon else 0.0)
	return wide > room + SLACK
