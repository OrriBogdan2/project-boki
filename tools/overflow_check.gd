extends RefCounted
## --overflow-check: every garden panel (Nesting Nook, Boki Burrow, a Boki card's tabs, feed, zone
## cards, games board, Field Book item pages) opened at Text size 150% in a 1280x720 window. In each: no clipped
## or hidden text (SafeArea.clipped), no two labels on top of each other, no label outside the window and every
## panel group inside the safe-area margin. A new garden panel is covered by adding a line to _panels().
## --overflow-shots --shots-dir=<dir>: the same run with a real renderer, one PNG a panel (<dir>/<panel>.png).

const WIN := Vector2i(1280, 720)
const TEXT_K := 1.5      # the biggest Text size (Settings.TEXT_SIZES)
const CARD_TABS := ["Care", "Training", "Growth", "Family", "About"]      # a Boki card's tabs (Home._open_kin)
const OVERLAP_PX := 3.0      # two labels share at least this much in both directions

var main: Node
var home
var bad := 0
var shots := ""
var kid: Dictionary
var rare: Dictionary
var pair: Array
var win_sz := Vector2.ZERO

func ok(cond: bool, what: String) -> void:
	print("OVERFLOW %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(mn: Node, mode: String) -> void:
	main = mn
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	if mode == "shots":
		DirAccess.make_dir_recursive_absolute(shots)
	if main.fade:
		await main.fade.reveal(0.01)
	UI.set_text_size(TEXT_K)
	home = await main._hb_home()
	for i in 600:
		if home.root_ui != null and home.hub != null and home.player != null:
			break
		await _frames(1)
	main.get_tree().root.size = WIN
	await _frames(3)
	win_sz = main.get_tree().root.get_visible_rect().size
	await _stage()
	for p: Array in _panels():
		await _show(p[0], p[1])
	UI.set_text_size(1.0)
	print("OVERFLOW DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## A full farm with a sprig, a rare kin and a pair for the Nook (Home._nest_demo), every zone awake.
func _stage() -> void:
	KinBoxView.demo_roster()
	home._nest_demo("pair")
	pair = home.nook_pick.duplicate()
	var roster: Array = Save.d["roster"]
	kid = roster[roster.size() - 2]
	rare = roster[roster.size() - 1]
	for id: String in GardenZones.ids():
		Save.d["zones"][id] = {"open": true}
	await _frames(2)

## Five Rare Eggs in the cradles and two on the shelf (as Home._nest_demo "incub" does).
func _eggs() -> void:
	Save.d["incubator"] = {}
	Save.d["rare_eggs"] = []
	Incubator.ensure()
	var bosses: Array = Data.MOBS.keys().filter(func(b): return Data.MOBS[b].has("egg"))
	for i in 7:
		var boss: String = bosses[i % bosses.size()]
		Incubator.add(String(Data.MOBS[boss]["egg"]), boss)
	for e in Incubator.eggs():
		e["heat"] = Incubator.HEAT_NEED * (1.0 - 0.2 * float(int(e["slot"]) % 5))

## [panel name, where it opens: "home" (the farm's panel) or "overlay"]. _open() builds each by its name.
func _panels() -> Array:
	var out: Array = []
	for n in ["nook_pair", "nook_grid", "nook_kin", "nook_rare", "nook_incubator_empty", "nook_incubator_eggs",
			"burrow", "feed", "zone_cards", "games_board", "prizes"]:
		out.append([n, "home"])
	out.append(["field_book", "overlay"])
	for t: String in CARD_TABS:
		out.append(["card_" + t.to_lower(), "home"])
	for id: String in GardenItems.ids():
		out.append(["item_" + id, "overlay"])
	return out

func _open(pname: String) -> void:
	home.nook_view = ""
	home.nook_tab = "Pairs"
	home.nook_pick = []
	match pname:
		"nook_pair":
			home.nook_pick = pair.duplicate()
			home._open_nook()
		"nook_grid":
			home._open_nook()
		"nook_kin":
			home.nook_view = String(kid["uid"])
			home._open_nook()
		"nook_rare":
			home.nook_view = String(rare["uid"])
			home._open_nook()
		"nook_incubator_empty", "nook_incubator_eggs":
			if pname.ends_with("eggs"):
				_eggs()
			home.nook_tab = "Incubator"
			home._open_nook()
		"burrow":
			KinBoxView.sel = String(kid["uid"])
			home._open_burrow()
		"feed":
			home._open_feed(kid)
		"zone_cards":
			ZoneCards.open(home, GardenZones.HUB)
		"games_board":
			ZoneCards.board(home)
		"prizes":
			PrizeBoard.open(home)
		"field_book":
			Overlay.inv_tab = "Field Book"
			Overlay.open_inventory()
		_:
			if pname.begins_with("card_"):
				home.kin_tab = pname.substr(5).capitalize()
				home._open_kin(kid)
			else:
				Overlay.open_dex(pname.substr(5))

func _show(pname: String, where: String) -> void:
	home._close_panel()
	_open(pname)
	await main.get_tree().create_timer(0.5).timeout
	var root: Control = Overlay.host if where == "overlay" else home.panel_host
	var problems := SafeArea.problems(SafeArea.groups_of(root, win_sz), win_sz)
	problems.append_array(SafeArea.clipped(root))
	problems.append_array(overlaps(root, win_sz))
	problems.append_array(trimmed(root))
	ok(problems.is_empty(), "%s at %d%%: %s" % [pname, int(TEXT_K * 100.0), problems.slice(0, 12)])
	if shots != "":
		await _frames(2)
		main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots, pname])
	if where == "overlay":
		Overlay.close()
	else:
		home._close_panel()

## Labels that sit on top of each other, or outside the window. Labels inside a ScrollContainer are not
## measured: the scroll keeps them in reach.
static func overlaps(root: Node, sz: Vector2) -> Array:
	var labels: Array = []
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if l.is_visible_in_tree() and l.text != "" and l.size.x > 0.0 and not _scrolled(l, root):
			labels.append(l)
	var bad_ones: Array = []
	for i in labels.size():
		var a: Label = labels[i]
		var ra := a.get_global_rect()
		if ra.position.x < -1.0 or ra.position.y < -1.0 or ra.end.x > sz.x + 1.0 or ra.end.y > sz.y + 1.0:
			bad_ones.append("outside '%s'" % a.text.left(24))
		for j in range(i + 1, labels.size()):
			var b: Label = labels[j]
			var inter := ra.intersection(b.get_global_rect())
			if inter.size.x > OVERLAP_PX and inter.size.y > OVERLAP_PX:
				bad_ones.append("overlap '%s' / '%s'" % [a.text.left(18), b.text.left(18)])
	return bad_ones

## One-line labels that elide ("...") because they do not fit: the words are lost on screen. A label whose
## tooltip is its whole text (a compact card line) can still be read.
static func trimmed(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "Label", true, false):
		var l := n as Label
		if not l.is_visible_in_tree() or l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.size.x <= 0.0:
			continue
		if l.tooltip_text == l.text:
			continue
		if l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING and SafeArea.wider(l, l.text, l.size.x):
			out.append("trimmed '%s'" % l.text.left(24))
	return out

static func _scrolled(c: Control, root: Node) -> bool:
	var p := c.get_parent()
	while p != null and p != root:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
