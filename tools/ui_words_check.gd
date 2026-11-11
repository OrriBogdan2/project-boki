extends "res://tools/first15_shots.gd"
## --ui-words-check [--shots-dir=<dir>]: the UI bloat audit (docs/UI_SIMPLIFY_1111.md). Opens every farm
## panel and menu screen in a made-up save and, for each one, counts the words you can see and the words
## in its hover tooltips. Fails when:
##   1. a label has collapsed into a column (fewer pixels wide than three of its letters: the Soul Shrine's
##      vertical text bug, a wrapping label in a row that doesn't give it the width)
##   2. a tooltip is longer than one line (TIP_WORDS)
##   3. one of the simplified screens (BUDGET) shows more words than its budget
## With --shots-dir it also saves one .jpg per screen (needs a renderer: xvfb-run or a GPU).

const TIP_WORDS := 12          # a tooltip is one short line
## Words a simplified screen may show (made-up save below): the screens cut in the 11-11 pass.
const BUDGET := {
	"soul_shrine": 70, "graveyard": 60, "grave": 90, "shrine_lot": 45, "armory": 200, "expedition": 140,
	"kin_page": 170, "job_board": 150, "kitchen": 110, "challenges": 130, "hall": 90, "house": 90,
	"burrow": 140, "nook": 110, "train": 90, "music": 60, "market": 110, "hunters": 190, "black_market": 45,
}

var fails := 0
var shoot := false
var report: PackedStringArray = []

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			shoot = true
	if shoot:
		DirAccess.make_dir_recursive_absolute(dir)
		tree.root.size = Vector2i(1920, 1080)
	Save.no_write = true
	Save.d = Save.fresh()
	_made_up_save()
	_farm_save()
	main.show_screen("home", {})
	var guard := 0
	while guard < 600 and (_screen() == null or _screen().get("player") == null):
		guard += 1
		await _wait(0.5)
	await _wait(2.0)
	var h := _screen()
	for s in _screens(h):
		h._close_panel()
		Overlay.close()
		await _frames(2)
		(s[1] as Callable).call()
		await _wait(0.5 if shoot else 0.15)
		_measure(String(s[0]), h.panel_host.get_children() + Overlay.host.get_children())
		if shoot:
			await _shot(String(s[0]))
	h._close_panel()
	main.show_screen("results", {"extracted": true, "gems": 42, "caught": [Save.new_kin("zapple")], "knocks": 3,
		"damage": 512, "taken": 388, "kills": 1, "time": 201.0, "kin_trust": 57.0})
	await _wait(2.0)
	_measure("results", [_screen()])
	if shoot:
		await _shot("results")
	print("UIWORDS screen                 words  tips  tip-words  longest-tip")
	for line in report:
		print(line)
	print("UIWORDS DONE, failures: %d" % fails)
	tree.quit(1 if fails > 0 else 0)

## Graves (two souls kept), a shrine, three Boki, no embers: the state the owner saw.
func _farm_save() -> void:
	for sp in Data.common_kin().slice(0, 2):
		Save.d["roster"].append(Save.new_kin(sp))
	Save.d["gems"] = 40
	Save.d["extracts"] = 1
	for i in 3:
		var rec := Save.new_kin(Data.common_kin()[i % Data.common_kin().size()], ["Biscuit", "Wren", "Clove"][i])
		Save.remember(rec, "caught", "was scanned by you out in the islands and brought home")
		Save.d["roster"].append(rec)
		var g := Econ.kin_dies(rec, "starved")
		g["soul"] = i < 2
	Save.d["buildings"].append("shrine")

## [name, opener] for every farm panel and menu in the audit (build mode is not a panel: left out).
func _screens(h: Node) -> Array:
	var rec: Dictionary = Save.d["roster"][0]
	var g: Dictionary = Econ.graves()[0]
	return [
		["soul_shrine", func(): h.hecon.open_shrine()],
		["shrine_lot", func():
			Save.d["buildings"].erase("shrine"); h.hecon.open_shrine_lot(); Save.d["buildings"].append("shrine")],
		["graveyard", func(): h.hecon.open_graveyard()],
		["grave", func(): h.hecon.open_grave(g)],
		["armory", func(): h.hecon.open_armory()],
		["expedition", func(): h._open_expedition()],
		["loadout", func(): h._open_loadout()],
		["kin_page", func(): h._open_kin(rec)],
		["feed", func(): h._open_feed(rec)],
		["train", func(): h._open_train(rec)],
		["wear", func(): h._open_wear(rec)],
		["job_board", func(): h.open_job_board()],
		["welcome", func(): h._open_welcome()],
		["kitchen", func(): h._open_kitchen()],
		["challenges", func(): h._open_challenges()],
		["hall", func(): h._open_hall()],
		["music", func(): h._open_music()],
		["ferry", func(): h._open_ferry()],
		["house", func(): h._open_house()],
		["burrow", func(): h._open_burrow()],
		["nook", func(): h._open_nook()],
		["market", func(): h.hmk.open()],
		["black_market", func(): h.hbm.open()],
		["hunters", func(): HomeClasses.open(h, Arch.of_save())],
		["settings", func(): Overlay.open_settings()],
		["pause", func(): Overlay.open_pause("home")],
		["inventory", func(): Overlay.open_inventory()],
	]

## Counts what the open panel (or the overlay page) shows and checks its labels and tooltips.
func _measure(what: String, roots: Array) -> void:
	var acc := {"words": 0, "tips": 0, "tip_words": 0, "longest": ""}
	for r in roots:
		_walk(r, what, acc)
	var budget := int(BUDGET.get(what, 0))
	if budget > 0 and int(acc["words"]) > budget:
		_fail("%s shows %d words (budget %d)" % [what, acc["words"], budget])
	report.append("UIWORDS %-20s %5d %5d %10d  \"%s\"" % [what, acc["words"], acc["tips"], acc["tip_words"],
		String(acc["longest"]).left(70)])

func _walk(nd: Node, what: String, acc: Dictionary) -> void:
	if nd is CanvasItem and not (nd as CanvasItem).is_visible_in_tree():
		return
	if nd is Control:
		var c := nd as Control
		var txt := ""
		if c is Label or c is Button or c is RichTextLabel:
			txt = (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else String(c.get("text"))
		acc["words"] = int(acc["words"]) + _words(txt)
		if c is Label and _collapsed(c as Label):
			_fail("%s: label \"%s\" collapsed to %.0f px wide" % [what, txt.left(40), c.size.x])
		var tip := c.tooltip_text
		if tip != "":
			var tw := _words(tip)
			acc["tips"] = int(acc["tips"]) + 1
			acc["tip_words"] = int(acc["tip_words"]) + tw
			if tw > _words(String(acc["longest"])):
				acc["longest"] = tip
			if tw > TIP_WORDS:
				_fail("%s: tooltip of %d words: \"%s\"" % [what, tw, tip.left(60)])
	for ch in nd.get_children():
		_walk(ch, what, acc)

## A wrapping label squeezed narrower than three of its letters shows one letter per line.
func _collapsed(l: Label) -> bool:
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF or l.text.strip_edges().length() < 4:
		return false
	return l.size.x < 3.0 * float(l.get_theme_font_size("font_size")) * 0.5

## Words in s: runs of text between spaces and line breaks, not counting the "·" separators.
func _words(s: String) -> int:
	return s.replace("\n", " ").replace("·", " ").split(" ", false).size()

func _fail(msg: String) -> void:
	fails += 1
	printerr("UIWORDS FAIL ", msg)
