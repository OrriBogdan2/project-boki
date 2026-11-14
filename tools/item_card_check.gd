extends RefCounted
## --item-card-check (GARDEN_MODERN.md 1.3): the hold-to-preview card (ItemPreviewCard) and the held item at home
## (ItemHold). The card only reads GardenItems.preview / EvoPath / StatBudget: its ghost numbers, budget and lean
## rings, path meter and Why? lines equal theirs, and building it changes nothing. At home: a feed menu row shows
## the card on hover, the try-on wears the change for tryon_s, a held item shows the card near a Boki, interact
## gives it and walking away ends the hold with the item still in the bag. Sounds: the held card ticks softly while
## it is up (GardenSfx.card_tick) and the give plays the item's cue at the Boki (GardenSfx.item).
## --item-card-shots --shots-dir=<dir> (needs a renderer): card_stat.png, card_path.png, card_sweet.png.
## Never touches the real save.

var bad := 0
var main: Node
var dir := ""

func ok(cond: bool, what: String) -> void:
	print("ITEMCARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A Zapple at level 6 with Power and Focus even (its path meter undecided), no lean, plain traits.
func _boki(nm: String) -> Dictionary:
	var rec := Save.new_kin("zapple", nm)
	Care.ensure(rec)
	rec["level"] = 6
	for s in Care.STATS:
		rec["stats"][s] = 20
	for t in rec["traits"]:
		rec["traits"][t] = 0.5
	rec["lean"] = {}
	rec["path"] = []
	return rec

## Every Label text under n, joined by newlines.
func _texts(n: Node) -> String:
	var out := []
	for c in n.find_children("*", "Label", true, false):
		out.append((c as Label).text)
	return "\n".join(out)

func run(m: Node, mode: String = "check") -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	if mode == "shots":
		await _shots()
		return
	_card_numbers()
	_card_path()
	await _home()
	print("ITEMCARD DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _card_numbers() -> void:
	var rec := _boki("Pip")
	rec["stats"]["power"] = StatBudget.cap(rec) - 2
	var before := JSON.stringify(rec)
	var pv := GardenItems.preview(rec, "thumpnut")
	var got := _texts(ItemPreviewCard.build(rec, "thumpnut"))
	ok(JSON.stringify(rec) == before, "building the card changes nothing on the Boki")
	var d: Array = pv["deltas"]["stats.power"]
	var line := "%d +%d (of +3, level cap)" % [d[0], d[1] - d[0]]
	ok(got.contains(line), "capped Thumpnut: ghost row says '%s' (preview after caps)" % line)
	ok(got.contains(String(pv["text"])), "the card shows the preview line '%s'" % pv["text"])
	var spent := StatBudget.total(rec)
	var budget := "Budget %d to %d of %d" % [spent, spent + d[1] - d[0], int(StatBudget.rules()["total_cap"])]
	ok(got.contains(budget), "budget ring: '%s'" % budget)
	ok(got.contains("Lean: none"), "no lean before or after: the lean ring says none")
	var sweet := GardenItems.preview(rec, "glassdew")
	var to := float(sweet["deltas"]["lean"][1]["water"])
	var lean := "Lean Water 0%% to %d%%" % roundi(100.0 * to / Evo.LEAN_FULL)
	ok(_texts(ItemPreviewCard.build(rec, "glassdew")).contains(lean), "Glassdew: lean ring '%s'" % lean)
	rec["stats"]["power"] = StatBudget.cap(rec)
	var full := _texts(ItemPreviewCard.build(rec, "thumpnut"))
	ok(full.contains("at its limit") and not full.contains(" +"), "a full stat: the card says why and draws no ghost")
	var then := GardenItems.after(rec, sweet)
	ok(then["lean"] == sweet["deltas"]["lean"][1] and rec["lean"].is_empty(),
			"after() is the preview's deltas on a copy")

func _card_path() -> void:
	var rec := _boki("Tock")
	var got := _texts(ItemPreviewCard.build(rec, "puzzlenut"))
	var ends: Array = EvoPath.line(rec)["ends"]
	var then := GardenItems.after(rec, GardenItems.preview(rec, "puzzlenut"))
	ok(EvoPath.winner(rec) == -1 and EvoPath.winner(then) == 1, "Puzzlenut tips an undecided Zapple to its curious end")
	var verdict := ItemPreviewCard.verdict(rec, then, "puzzlenut")
	ok(verdict == "With this Puzzlenut Tock turns toward ? (1 to 0)." and got.contains(verdict),
			"verdict line names the unmet final '?' with the pips after (got '%s')" % verdict)
	ok(got.contains("? 0    |    ? 0 to 1"), "path meter: each end's pips before and after")
	var why := ItemPreviewCard.why_lines(EvoPath.pips(rec)[1], EvoPath.pips(then)[1], ends[1])
	ok(why == ["?: tokens 0 to 1"], "Why? lists the token pip and where it came from (got %s)" % [why])
	Save.d["dex"] = {String(ends[1]["form"]): {"seen": true}}
	var named := ItemPreviewCard.verdict(rec, then, "puzzlenut")
	ok(named.contains(String(ends[1]["name"])), "a met final is named: '%s'" % named)
	rec["stats"]["power"] = 30
	var lead := GardenItems.after(rec, GardenItems.preview(rec, "bristlethorn"))
	var keeps := ItemPreviewCard.verdict(rec, lead, "bristlethorn")
	ok(keeps.begins_with("With this Bristlethorn Tock keeps growing toward"),
			"a token for the leading end: keeps growing")
	var plain := Save.new_kin("cindle", "Ash")
	ok(not _texts(ItemPreviewCard.build(plain, "thumpnut")).contains("|"),
			"no branching line: no path meter on the card")

## A garden home with Pip (Zapple) and Moss, the player beside Pip.
func _boot() -> Node:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for spec in [["zapple", "Pip"], ["burrlet", "Moss"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		Care.ensure(rec)
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d
	var home = await main._hb_home()
	main.fade.reveal(0.01)
	for k in home.kins:
		k["t"] = 1e9
		k["goal"] = k["pos"]
	return home

func _place(home: Node, k: Dictionary, gap: float) -> void:
	home.ppos = k["pos"] + Vector3(gap, 0, 0)
	home.player.position = home.ppos

func _home() -> void:
	var home = await _boot()
	var k: Dictionary = home.kins[0]
	var rec: Dictionary = k["rec"]
	Save.add_item("thumpnut", 2)
	Save.add_item("glassdew", 1)
	home._open_feed(rec)
	await _tick()
	var hovered := false
	for b in home.panel_host.find_children("*", "Button", true, false):
		var row := _texts(b.get_parent())
		if (b as Button).text == "Feed" and row.contains("Glassdew") and row.contains(": Water"):
			(b as Button).mouse_entered.emit()
			hovered = true
			break
	ok(hovered and home.hold.card.key == "%s:glassdew:water" % rec["uid"], "hovering a feed row shows its card")
	ok(not (k["node"] as Node3D).visible, "try-on: the Boki wears the new colour (its model swapped out)")
	await main.get_tree().create_timer(float(ItemHold.rules()["tryon_s"]) + 0.2).timeout
	ok((k["node"] as Node3D).visible and rec.get("lean", {}).get("water", 0.0) == 0.0,
			"after tryon_s it is itself again, no lean given")
	home._close_panel()
	await _tick()
	ok(not home.hold.card.showing(), "closing the feed menu slides the card out")
	_place(home, k, 8.0)
	ItemHold.want("thumpnut")
	await _tick()
	ok(home.hold.item == "thumpnut" and not home.hold.card.showing(), "held from the bag: no card away from a Boki")
	var ticks := _heard("garden_item_tick")
	_place(home, k, 1.0)
	await _tick()
	ok(is_same(home.hold.near, k) and home.hold.card.key.begins_with(String(rec["uid"])),
			"near Pip: its card slides in")
	ok(_heard("garden_item_tick") == ticks + 1, "...with one soft tick")
	await main.get_tree().create_timer(GardenSfx.TICK_S * 3.0).timeout
	var more := _heard("garden_item_tick") - ticks - 1
	ok(more >= 2 and more <= 4, "...and about one every %.1f s while it is up (%d in %.1f s)"
			% [GardenSfx.TICK_S, more, GardenSfx.TICK_S * 3.0])
	_place(home, k, 8.0)
	await _tick()
	ok(home.hold.item == "" and not home.hold.card.showing() and int(Save.d["items"]["thumpnut"]) == 2,
			"walking away ends the hold, both Thumpnuts still in the bag")
	ticks = _heard("garden_item_tick")
	await main.get_tree().create_timer(GardenSfx.TICK_S * 1.5).timeout
	ok(_heard("garden_item_tick") == ticks, "no ticks once the card is gone")
	var pv := GardenItems.preview(rec, "thumpnut")
	ItemHold.want("thumpnut")
	_place(home, k, 1.0)
	await _tick()
	var bites := _heard("garden_item_bite")
	Input.action_press("interact")
	await _tick()
	Input.action_release("interact")
	await main.get_tree().create_timer(2.0).timeout
	var after: Array = pv["deltas"]["stats.power"]
	ok(home.hold.item == "" and int(rec["stats"]["power"]) == int(after[1]),
			"interact on Pip gives it: Power %d to %d" % after)
	ok(_heard("garden_item_bite") == bites + 1, "...and Pip's give plays one stat bite")
	ok(int(Save.d["items"]["thumpnut"]) == 1, "one Thumpnut left in the bag")
	var last := String(rec["journal"][-1]["words"]) if not rec.get("journal", []).is_empty() else ""
	ok(last.contains("Thumpnut"), "one journal line with the cause: '%s'" % last)
	FarmUnlocks.rules()["base_mode"] = false

func _heard(sname: String) -> int:
	return int(GardenSfx.heard.get(sname, 0))

## Two frames: process_frame fires before Home's _process, so the second one has seen a full tick.
func _tick() -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame

func _grab(file: String) -> void:
	await main.get_tree().create_timer(0.4).timeout
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	print("ITEMCARDSHOT ", file)

func _shots() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var home = await _boot()
	var k: Dictionary = home.kins[0]
	for id in ["thumpnut", "puzzlenut", "glassdew"]:
		Save.add_item(id, 1)
	for shot in [["thumpnut", "card_stat"], ["puzzlenut", "card_path"], ["glassdew", "card_sweet"]]:
		home.hold.drop()
		_place(home, k, 8.0)
		await _tick()
		ItemHold.want(shot[0])
		_place(home, k, 1.2)
		await main.get_tree().create_timer(0.25).timeout
		await _grab(shot[1])
	FarmUnlocks.rules()["base_mode"] = false
	main.get_tree().quit()
