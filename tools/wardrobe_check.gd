extends RefCounted
## --wardrobe-check: the farm's wardrobe. Buying with gems, wearing and colouring items, and the
## farm look surviving a save and reload; the hunter at home wearing them (and no archetype gear);
## in a real match the same hunter shows only its archetype's silhouette, none of the farm items;
## and a per-archetype colourway picked at the wardrobe recolours the match model without changing
## a single vertex of its shape. Never touches the save file.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

static func _ward_nodes(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("Ward_*", "", true, false):
		out.append(String(c.name).substr(5))
	out.sort()
	return out

## The model's shape: every mesh with its vertex count (and its node path for named parts),
## materials left out. (Poses are left out too: a match animates its hunter.)
static func _shape(n: Node3D) -> String:
	var parts: Array = []
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null: continue
		var nv := 0
		for s in mi.mesh.get_surface_count():
			nv += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		parts.append("%s:%d" % [String(mi.get_parent().name) + "/" + (String(mi.name) if not String(mi.name).begins_with("@") else "_"), nv])
	parts.sort()
	return "|".join(parts)

## The model's colours: every toon material's albedo.
static func _cols(n: Node3D) -> Array:
	var out: Array = []
	for m in Models.collect_mats(n):
		out.append((m as ShaderMaterial).get_shader_parameter("albedo").to_html(false))
	out.sort()
	return out

func run(main: Node) -> void:
	Save.no_write = true
	var save_path := Save.path_for(Save.slot)
	var before := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else "<none>"
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip"); Save.d["roster"].append(pk); Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true; Save.d["tutorial"]["day1_done"] = true
	Save.d["cls"] = "medium"; Save.d["weapon"] = "rifle"
	Save.d["look"] = {"race": 0, "gender": 0, "outfit": 3, "hair": 1}
	Save.d["gems"] = 100
	Econ.ensure()
	Wardrobe.ensure()
	# ---- the catalogue, buying and wearing
	var n_items := Wardrobe.ITEMS.size()
	var paid := Wardrobe.ITEMS.keys().filter(func(k): return int(Wardrobe.ITEMS[k][2]) > 0).size()
	ok(n_items >= 15 and paid >= 8, "%d wardrobe items (%d bought with gems, the rest free)" % [n_items, paid])
	ok(Wardrobe.owns("straw_hat") and not Wardrobe.owns("flower_crown"), "free items are yours, the others are for sale")
	ok(not Wardrobe.wear("hat", "flower_crown"), "you can't wear something you haven't bought")
	ok(Wardrobe.buy("flower_crown") and int(Save.d["gems"]) == 40 and Wardrobe.owns("flower_crown"), "the flower crown costs 60 gems (40 left)")
	ok(not Wardrobe.buy("plush") and int(Save.d["gems"]) == 40, "the 120-gem plush is out of reach with 40")
	ok(Wardrobe.wear("hat", "flower_crown") and Wardrobe.wear("top", "overalls") and Wardrobe.wear("acc", "scarf") and not Wardrobe.wear("hat", "scarf"), "a hat, overalls and a scarf go on (a scarf isn't a hat)")
	Wardrobe.set_col("overalls", 4); Wardrobe.set_col("scarf", 2)
	# ---- it all survives a save and reload
	var js := JSON.stringify(Save.d)
	Save.d = JSON.parse_string(js)
	var fl := Wardrobe.farm_look()
	ok(String(fl.get("hat", [""])[0]) == "flower_crown" and String(fl.get("top", [""])[0]) == "overalls" and (fl["top"][1] as Color).is_equal_approx(Wardrobe.PALETTE[4]) and (fl["acc"][1] as Color).is_equal_approx(Wardrobe.PALETTE[2]),
		"after a save and reload the farm look is the same: %s" % str(Wardrobe.ensure()["wear"]))
	# ---- at home: the farm look, no archetype gear
	var H = load("res://scripts/home/home.gd")
	var home = H.new()
	main.add_child(home)
	main.current = home
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var arch := HeroKit.arch_for("medium", "", Save.d["look"])
	var hm: Node3D = home.player
	ok(bool(hm.get_meta("farm", false)) and _ward_nodes(hm) == ["flower_crown", "overalls", "scarf"], "at home the hunter wears them: %s" % str(_ward_nodes(hm)))
	var match_ref := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", Save.d["look"])
	main.add_child(match_ref)
	var farm_ref := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", Wardrobe.farm_appearance())
	main.add_child(farm_ref)
	ok(_shape(farm_ref) != _shape(match_ref), "the farm silhouette isn't the %s's" % arch)
	# the wardrobe station and its panel
	ok(is_instance_valid(home.hwd.node) and home.hwd.near(home.hwd.spot()), "the wardrobe stands by the house")
	home.ppos = home.hwd.spot(); home._find_interact()
	ok(String(home.interact.get("kind", "")) == "wardrobe" and home._label_for(home.interact) == "Open the wardrobe", "standing at it, F opens the wardrobe")
	for tb in ["hat", "top", "acc", "match"]:
		home.hwd.open(tb)
	ok(home.panel_open == "Wardrobe" and is_instance_valid(home.hwd.match_mdl) and not bool(home.hwd.match_mdl.get_meta("farm", false)), "the wardrobe's tabs open, the Expedition tab previews the match look")
	home.hwd.open("hat")
	home.hwd._pick("beanie")
	ok(_ward_nodes(home.player).has("beanie") and not _ward_nodes(home.player).has("flower_crown"), "picking the beanie puts it on your hunter on the spot")
	home._close_panel()
	Wardrobe.wear("hat", "flower_crown")
	# ---- a per-archetype colourway (colour only)
	Wardrobe.set_arch_col(arch, 5)
	var tinted := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", Save.d["look"])
	main.add_child(tinted)
	ok(_shape(tinted) == _shape(match_ref), "the %s colourway leaves the match silhouette exactly as it was" % arch)
	ok(_cols(tinted) != _cols(match_ref), "and changes its colours")
	var other := "mage" if arch != "mage" else "gunslinger"
	var o0 := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", Save.d["look"], other)
	var lk_no: Dictionary = Save.d["look"].duplicate(true); lk_no.erase("arch_cols")
	var o1 := Models.hunter("medium", Data.TEAM_COLORS[0], "rifle", "", lk_no, other)
	main.add_child(o0); main.add_child(o1)
	ok(_cols(o0) == _cols(o1), "it's that archetype's alone (the %s keeps your outfit's colours)" % other)
	home.queue_free()
	await main.get_tree().process_frame
	# ---- in a real match: the archetype's silhouette in the chosen colours, no farm items
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	await main.get_tree().process_frame
	var pm: Node3D = m.player.model
	ok(_ward_nodes(pm).is_empty() and not bool(pm.get_meta("farm", true)), "in a match the hunter wears none of the farm items")
	ok(String(pm.get_meta("arch", "")) == arch and _shape(pm) == _shape(tinted), "it has the %s's own silhouette" % arch)
	ok(_cols(pm) == _cols(tinted) and _cols(pm) != _cols(match_ref), "in the colourway picked at the wardrobe")
	var after := FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else "<none>"
	ok(before == after, "the save file on disk is untouched")
	print("WARDROBE CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()
