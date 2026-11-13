extends RefCounted
## --zone-air-check: every garden zone has its own ambient layer (ZoneAir, content/rules/zone_air.json), one
## unshaded looping GPUParticles3D with a small count and no light; none in the hub, none without base_mode,
## none at the lowest quality preset, and fewer motes at Medium than at High. Then a real Home in each zone holds
## exactly one. Never touches the real save or the player's settings.

const MOST := 64       # motes a layer may have at fx 1 (the GARDEN.md 10.6 budget counts emitters, keep each tiny)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ZONEAIR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var was_quality = Settings.v.get("quality", "auto")
	var was_mode = FarmUnlocks.rules()["base_mode"]
	FarmUnlocks.rules()["base_mode"] = true
	Settings.v["quality"] = "high"
	var zones: Array = GardenZones.rules()["zones"].keys()
	var looks := {}
	for zone in zones:
		GardenZones.here = zone
		var spec := ZoneAir.layer()
		ok(not spec.is_empty(), "%s has a layer (%s)" % [zone, spec.get("name", "none")])
		if spec.is_empty():
			continue
		looks[spec["name"]] = true
		_unit(zone, spec)
	ok(looks.size() == zones.size(), "%d zones, %d different layers" % [zones.size(), looks.size()])
	GardenZones.here = GardenZones.HUB
	ok(ZoneAir.layer().is_empty(), "no layer in the hub")
	GardenZones.here = GardenZones.start()
	FarmUnlocks.rules()["base_mode"] = false
	ok(ZoneAir.layer().is_empty(), "no layer on a farm without base_mode")
	FarmUnlocks.rules()["base_mode"] = true
	for zone in zones:
		await _in_home(main, zone)
	Settings.v["quality"] = was_quality
	FarmUnlocks.rules()["base_mode"] = was_mode
	GardenZones.here = ""
	print("ZONEAIR DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The layer's node on its own: looping, unshaded, no shadow, the count scaled by quality and off at the lowest.
func _unit(zone: String, spec: Dictionary) -> void:
	var holder := Node3D.new()
	var p := ZoneAir.add(holder)
	ok(p != null and not p.one_shot and p.emitting and p.explosiveness == 0.0, "%s: a looping layer, no burst" % zone)
	if p == null:
		return
	var mat := (p.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	ok(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s: unshaded" % zone)
	ok(p.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s: casts no shadow" % zone)
	ok(p.amount <= MOST, "%s: %d motes at High (at most %d)" % [zone, p.amount, MOST])
	ok(holder.find_children("*", "Light3D", true, false).is_empty(), "%s: no light" % zone)
	Settings.v["quality"] = "medium"
	var medium := ZoneAir.count(spec)
	Settings.v["quality"] = String(ZoneAir.rules()["off_at"])
	ok(ZoneAir.count(spec) == 0 and ZoneAir.add(Node3D.new()) == null, "%s: off at %s" % [zone, Settings.v["quality"]])
	Settings.v["quality"] = "high"
	ok(medium > 0 and medium < p.amount, "%s: %d motes at Medium, %d at High" % [zone, medium, p.amount])
	holder.free()

## A Home opened in the zone builds exactly one layer.
func _in_home(main: Node, zone: String) -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "B0")
	Care.ensure(rec)
	rec["zone"] = zone
	rec["starter"] = true
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"home": true, "day1_done": true, "hatched": true, "intro": true}
	d["zones"][zone] = {"open": true}
	Save.d = d
	var home = load("res://scripts/home/home.gd").new()
	home.zone = zone
	main.add_child(home)
	main.current = home
	for i in 900:
		if home.root_ui != null and home.player != null and home.hb != null:
			break
		await main.get_tree().process_frame
	ok(home.find_children(ZoneAir.NAME, "GPUParticles3D", false, false).size() == 1, "%s: one layer in Home" % zone)
	home.queue_free()
	await main.get_tree().process_frame
