extends RefCounted
## --garden-zones-check (GARDEN.md 10.4 and 10.7 step 5, the moving part): every Boki lives in one zone
## (rec["zone"], Bramblebank when missing) and only the loaded zone's Boki walk it, plus your partner. "Move to..."
## sends a Boki to the return pad and it blinks out; after a reload it is gone from the old zone and present in
## the new one. A zone holds the farm cap (6); the 7th move is refused. A Boki that leans to another open zone asks
## at the pad (a Watch), and the key sends it. A Boki set down on the Waystone opens the zone list. Never touches
## the real save.

const DT := 0.25         # s per farm step
const WALK_SECS := 60.0  # s the sent Boki gets to reach the pad
const CAST := ["zapple", "burrlet", "cindle", "pebbit", "lodestick", "marchleaf", "basaltoad", "marchleaf"]

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("GARDENZONES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A partner, a mover and six Boki already living in Glasswater (a full zone); Glasswater is open.
func _save() -> Array:
	var d := Save.fresh()
	var recs: Array = []
	for i in CAST.size():
		var rec := Save.new_kin(CAST[i], "B%d" % i)
		Care.ensure(rec)
		recs.append(rec)
	for i in range(2, recs.size()):
		recs[i]["zone"] = "glasswater"
	recs[0]["starter"] = true
	d["roster"] = recs
	d["active"] = recs[0]["uid"]
	d["zones"] = {"glasswater": {}}
	d["box_v"] = true
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)
	return recs

func _load(zone: String):
	Game.match_opts = {"zone": zone}
	var home = await main._hb_home()
	home.ppos = Vector3(-500, 0, -500)
	home.day_t = 0.4      # midday: nobody naps for the night
	return home

func _unload(home) -> void:
	home.queue_free()
	await main.get_tree().process_frame

func _names(home) -> Array:
	return home.kins.map(func(k): return String(k["rec"]["name"]))

## Steps the farm for `secs`, or until `stop` says so.
func _run(home, secs: float, stop := Callable()) -> void:
	var t := 0.0
	while t < secs and not (stop.is_valid() and stop.call()):
		home._move_kin(DT)
		t += DT

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	seed(7)
	FarmUnlocks.rules()["base_mode"] = true
	var recs := _save()
	var partner: Dictionary = recs[0]
	var mover: Dictionary = recs[1]
	ok(GardenZones.zone_of(partner) == "bramblebank", "a Boki with no zone lives in Bramblebank")
	ok(GardenZones.open_ids() == ["bramblebank", "glasswater"], "Bramblebank is always open, and Glasswater is")
	var home = await _load("bramblebank")
	ok(_names(home) == ["B0", "B1"], "Bramblebank loads its two residents only (%s)" % [_names(home)])
	_run(home, 1.0)
	ok(home.life.pad.pad_at != Vector3.INF, "another zone is open: the return pad stands")
	var kin: Dictionary = home.kins.filter(func(k): return k["rec"] == mover)[0]
	var partner_kin: Dictionary = home.kins.filter(func(k): return k["rec"] == partner)[0]
	ok(home.life.pad.send(partner_kin, "glasswater") != "", "the partner is not moved: it follows you")
	ok(home.life.pad.send(kin, "kitewind") != "", "a zone that is not open refuses")
	ok(home.life.pad.send(kin, "glasswater") != "", "Glasswater is full with six: the 7th move is refused")
	recs[7].erase("zone")      # one of the six leaves; Glasswater has room for exactly one
	ok(home.life.pad.send(kin, "glasswater") == "", "with room, the move is accepted: it walks to the pad")
	_run(home, WALK_SECS)
	ok(not _names(home).has("B1") and mover["zone"] == "glasswater", "the moved Boki blinked out of Bramblebank")
	await _unload(home)
	home = await _load("bramblebank")
	ok(not _names(home).has("B1"), "after a reload it is still gone from the old zone")
	await _unload(home)
	home = await _load("glasswater")
	var names := _names(home)
	ok(names.has("B1") and names.has("B0") and names.size() == 7, "after a reload it is in Glasswater with the partner")
	ok(GardenZones.move(recs[7], "glasswater") != "", "the 7th resident is refused")
	await _unload(home)
	await _ask()
	Game.match_opts = {}
	FarmUnlocks.rules()["base_mode"] = false
	print("GARDENZONES DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## A Boki leaning to Glasswater's types asks at the pad and the key sends it; on the Waystone it gets the list.
func _ask() -> void:
	var recs := _save()
	recs[2]["zone"] = "bramblebank"
	recs[2]["lean"] = {"water": 20.0}
	for i in range(3, recs.size()):
		recs[i].erase("zone")
	var rules := GardenZones.rules()
	rules["ask_chance"] = 1.0
	var home = await _load("bramblebank")
	var kin: Dictionary = home.kins.filter(func(k): return k["rec"] == recs[2])[0]
	ok(GardenZones.wants(recs[2]) == "glasswater", "a Boki leaning water wants Glasswater")
	ok(GardenZones.wants(recs[3]) == "", "a Boki with no lean wants nothing")
	for k in home.kins:
		if k != kin:
			k["rec"]["lean"] = {}
			k["busy"] = true      # the others stand still: nobody tags the asker on its way
	_run(home, 300.0, func(): return kin.has("zone_wait"))
	var watching: bool = (kin["life"] as Fsm).is_in(BaseLife.S.WATCH)
	ok(kin.has("zone_wait") and watching, "it walked to the pad and waits there, watching it")
	ok(kin.get("life_at", {}) == home.life.pad.target, "its Watch target is the pad")
	ok(String(kin["say"].text).contains("Glasswater"), "its bubble says where")
	ok(home.life.pad.answer(kin), "the key answers it")
	_run(home, WALK_SECS)
	ok(not home.kins.has(kin) and recs[2]["zone"] == "glasswater", "the answered Boki went to Glasswater")
	ok(not home.life.pad.answer(home.kins[0]), "a Boki that asked nothing is not sent")
	var other: Dictionary = home.kins[0]
	ok(not home.life.pad.dropped(other, home.life.pad.pad_at), "set down away from the Waystone: nothing opens")
	var before: int = home.root_ui.get_child_count()
	var opened: bool = home.life.pad.dropped(other, home.life.pad.stone_at)
	ok(opened and home.root_ui.get_child_count() == before + 1, "set down on the Waystone: the zone list opens")
	rules["ask_chance"] = 0.1
	await _unload(home)
