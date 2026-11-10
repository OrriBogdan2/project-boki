extends RefCounted
## --hushwood-check: the Hushwood zone (briefs/design/GARDEN.md 10.2, 10.7 step 7c; scripts/home/zone_look.gd).
## It is its own island on the save (Bramblebank's layout stays as it was), dark-green ground, a sky that stays
## at dusk, lantern moss in one MultiMesh with its few mote emitters, a dig patch and a snack patch growing
## mindmint and glowcap, and Seek hunting by the night rules at noon. Never touches the real save.

const ZONE := "hushwood"
const MOTES_MAX := 6        # emitting systems the whole zone may add (GARDEN.md 10.6 allows 12 in a zone)
const GROUND := "4a6a52"    # THEMES hushwood top

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HUSHWOOD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _save() -> void:
	FarmUnlocks.rules()["base_mode"] = true
	var d := Save.fresh()
	for i in 3:
		var rec := Save.new_kin(["zapple", "cindle", "burrlet"][i], "B%d" % i)
		Care.ensure(rec)
		rec["zone"] = ZONE
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"][ZONE] = {"open": true}
	HomeLayout.new_fs(d, 5)
	Save.d = d

func _has(lay: Dictionary, id: String) -> bool:
	return (lay["deco"] as Array).any(func(e): return String(e["id"]) == id)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_save()
	var home_deco := (Save.d["layout"]["deco"] as Array).size()
	var home = load("res://scripts/home/home.gd").new()
	home.zone = ZONE
	main.add_child(home)
	main.current = home
	for i in 600:      # under the ink wipe Home builds in slices: wait for the whole island
		await main.get_tree().process_frame
		if i >= 2 and not home.building: break
	var lay: Dictionary = Save.d["zones"][ZONE]["layout"]
	ok(HomeLayout.of(Save.d) == lay and lay["theme"] == "hushwood", "the zone has its own island, in its ground")
	var base: Dictionary = Save.d["layout"]
	ok((base["deco"] as Array).size() == home_deco and not _has(base, "toy_dig"), "Bramblebank's island is untouched")
	for id in ["toy_dig", "snack_patch", "training_post"]:
		ok(_has(lay, id), "%s stands in the zone" % id)
	ok(home.world.biome["top"].to_html(false) == GROUND, "the ground takes the zone's colour")
	home._update_sky(0.1)
	ok(home.sun_l.light_energy < 0.8, "the sky stays at dusk (sun %.2f)" % home.sun_l.light_energy)
	var moss := home.get_node_or_null("LanternMoss") as MultiMeshInstance3D
	var cap := int(ZoneLook.look(ZONE)["moss"]["count"])
	ok(moss != null and moss.multimesh.instance_count > cap / 2 and moss.multimesh.instance_count <= cap,
			"lantern moss: one MultiMesh of %d tufts" % (moss.multimesh.instance_count if moss else 0))
	var all: Array = home.find_children("*", "CPUParticles3D", false, false)
	var motes := all.filter(func(n): return "MossMotes" in n.name).size()
	ok(motes >= 1 and motes <= MOTES_MAX, "%d mote emitters (at most %d)" % [motes, MOTES_MAX])
	ok(SnackPatch.snacks() == ["mindmint", "glowcap"], "the snack patch grows mindmint and glowcap")
	var e := SnackPatch.entry(Save.d)
	for i in 120:      # the patch's timer starts on its first look tick after it is put down
		if e.has("t"): break
		await main.get_tree().process_frame
	var got := SnackPatch.harvest(Save.d, Time.get_unix_time_from_system() + 9999.0)
	ok(not e.is_empty() and got == ["mindmint", "glowcap"] and int(Save.d["crops"]["glowcap"]) == 1,
			"picking it fills the pantry with both")
	ok(home.hseek != null and is_instance_valid(home.hseek.basket), "Seek has its scent basket by the Training post")
	ok(BaseSeek.is_dark(0.5), "Seek hunts by the night rules at noon here")
	ok(ZoneLook.sky_t("bramblebank", 0.5) == 0.5, "other zones keep the real clock")
	ok(home.kins.size() == 3, "%d Boki live here" % home.kins.size())
	home.queue_free()
	await main.get_tree().process_frame
	FarmUnlocks.rules()["base_mode"] = false
	ok(not BaseSeek.is_dark(0.5), "off the zone, noon is day again")
	print("HUSHWOOD DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
