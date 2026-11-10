extends RefCounted
## --cinderstep-check [--shots-dir=<dir>]: Cinderstep, the garden's warm terraces (briefs/design/GARDEN.md 10.2 and
## 10.7 step 7b; content/rules/garden_zones.json "build"). Entering the zone gives it its own island on the save (the
## cinderstep theme, a warm stone, the climbing post, a Training post with its stump on the ember-slate ledge, and a
## snack patch growing Fire, Rock, Steel and Dragon snacks); Bramblebank's layout and troughs are left alone; the
## island survives a save round trip; the return pad stands in it and Stump Shove is on. With --shots-dir (needs a
## renderer) it also saves cinderstep_day.png and cinderstep_night.png. Never touches the real save.

const ZONE := "cinderstep"
const WAIT_FRAMES := 900      # frames to wait at most for the home to build
const WIPE_S := 1.2           # s for the ink wipe to clear before a shot
const DAY := 0.42             # day_t for the day shot
const NIGHT := 0.97           # day_t for the night shot
const ZOOM := 1.25            # camera zoom (0.8 close .. 1.6 wide)
const PROPS := ["toy_stone", "toy_post", "training_post", "snack_patch"]
const TYPES := ["fire", "rock", "steel", "dragon"]

var bad := 0
var main: Node
var dir := ""

func ok(cond: bool, what: String) -> void:
	print("CINDER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	_save()
	var bramble := JSON.stringify(HomeLayout.of(Save.d))
	var troughs := JSON.stringify(Save.d["feeders"])
	var home = await _load()
	if home != null:
		_zone(home)
		_untouched(bramble, troughs)
		_round_trip()
		if dir != "":
			await _shots(home)
		home.queue_free()
		await main.get_tree().process_frame
	FarmUnlocks.rules()["base_mode"] = false
	print("CINDER DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A Fire Boki and a Water Boki living in an open Cinderstep.
func _save() -> void:
	var d := Save.fresh()
	for spec in [["cindle", "Ash"], ["zapple", "Pip"]]:
		var rec := Save.new_kin(spec[0], spec[1])
		Care.ensure(rec)
		rec["zone"] = ZONE
		d["roster"].append(rec)
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"][ZONE] = {"open": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d

func _load():
	var home: Node = load("res://scripts/home/home.gd").new()
	home.zone = ZONE
	main.add_child(home)
	main.current = home
	for i in WAIT_FRAMES:
		await main.get_tree().process_frame
		if home.root_ui != null and home.hb != null and home.player != null and home.hshove != null:
			return home
	ok(false, "the zone home builds")
	return null

func _zone(home) -> void:
	var L := GardenZones.own_layout()
	ok(String(L.get("theme", "")) == ZONE and Save.d["zones"][ZONE]["layout"] == L, "Cinderstep has its own island")
	var ids: Array = L["deco"].map(func(e): return String(e["id"]))
	ok(PROPS.all(func(p): return ids.has(p)), "it holds the stone, posts and patch (%s)" % ", ".join(ids))
	var theme: Dictionary = HomeLayout.THEMES[ZONE]
	ok(theme.has("zone") and theme["style"] == "ember", "the theme is a zone theme with the ember flora set")
	var ledge: Array = L["paths"].values().filter(func(id): return id == "path_ember")
	ok(not ledge.is_empty(), "the ledge is ember slate (%d tiles)" % ledge.size())
	var toys: Array = home.toys.toys().map(func(t): return String(t["id"]))
	ok(toys.has("toy_stone") and toys.has("toy_post"), "the stone and the post are toys (%s)" % ", ".join(toys))
	var recs: Array = home.kins.map(func(k): return k["rec"])
	var fire: Dictionary = recs.filter(func(r): return r["species"] == "cindle")[0]
	var other: Dictionary = recs.filter(func(r): return r != fire)[0]
	fire["lean"] = {"fire": 20.0}
	ok(home.toys.weight(fire, "toy_stone") > home.toys.weight(other, "toy_stone"), "Fire Boki like the warm stone best")
	var stump: Node3D = home.hshove.stump
	ok(stump != null and stump.position.distance_to(home.YARD_AT) < 4.0, "the stump stands by the Training post")
	ok(home.hway != null and home.hway.here() == ZONE and home.hway.node.name == "Waystone", "the return pad is here")
	var types: Array = SnackPatch.snacks(Save.d).map(func(s): return Lean.key_of(String(s)))
	ok(types == TYPES, "the patch grows Fire, Rock, Steel and Dragon snacks (%s)" % ", ".join(types))
	ok(home.kins.size() == 2, "both residents are out in the zone")

## Loading the zone did not move Bramblebank's layout or its troughs.
func _untouched(bramble: String, troughs: String) -> void:
	ok(JSON.stringify(Save.d["layout"]) == bramble, "Bramblebank's layout is as it was")
	ok(JSON.stringify(Save.d["feeders"]) == troughs and Econ.feeders().is_empty(), "its troughs are not in Cinderstep")

## The island comes back from a save as it was (JSON turns every number into a float).
func _round_trip() -> void:
	var before := JSON.stringify(GardenZones.own_layout()["deco"])
	Save.d["zones"] = JSON.parse_string(JSON.stringify(Save.d["zones"]))
	GardenZones.enter(ZONE)
	var L := GardenZones.own_layout()
	var ints: bool = L["deco"].all(func(e): return typeof(e["x"]) == TYPE_INT)
	ok(JSON.stringify(L["deco"]) == before and ints, "it loads again from a save, props where they were")

func _shot(home, shot: String) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(WIPE_S).timeout
	home._close_panel()
	home.hover_box.visible = false
	home.prompt_box.visible = false
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot])
	print("CINDER shot %s" % shot)

func _shots(home) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var at: Vector3 = home.YARD_AT + Vector3(-2.0, 0, 2.0)
	home.ppos = at
	home.player.position = at
	home.cam.zoom_to = ZOOM
	home.cam.zoom = ZOOM
	home.cam.snap(at)
	home.day_t = DAY
	await _shot(home, "cinderstep_day")
	home.day_t = NIGHT
	await main.get_tree().create_timer(0.5).timeout
	await _shot(home, "cinderstep_night")
