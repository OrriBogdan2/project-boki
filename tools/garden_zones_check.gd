extends RefCounted
## --garden-zones-check (briefs/design/GARDEN.md 10.7 steps 2 and 4): the zones on the save and travel
## by the Waystone. Save: a v12 save upgrades with only the start zone open and every Boki living in
## it; a new save has the same. Keys: a locked zone's two keys tick when you have them. Travel (with
## base_mode on, through the real Game.goto and ink wipe): the hub shows only your partner and the
## Waystone; a hop to a locked zone is refused and its card lists both keys; the hub to Bramblebank
## and back keeps your partner with you and every Boki where it lives.

const WAIT_S := 30.0      # s to wait for a home to finish building before failing

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ZONES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	_save_part()
	_keys_part()
	await _travel_part(m)
	print("ZONES %s (%d failures)" % ["PASS" if bad == 0 else "FAIL", bad])
	m.get_tree().quit(0 if bad == 0 else 1)

func _save_part() -> void:
	var start := GardenZones.start()
	var old := Save.fresh()
	old["v"] = 12
	old.erase("zones")
	old["roster"] = [{"uid": "o1", "species": "zapple", "name": "Old", "traits": {}, "trust": 35.0, "bonds": {}},
		{"uid": "o2", "species": "cindle", "name": "Ash", "traits": {}, "trust": 35.0, "bonds": {}}]
	ok(Save.migrate(old) and int(old["v"]) == Save.VERSION, "a v12 save upgrades to v%d" % Save.VERSION)
	var zones: Dictionary = old["zones"]
	ok(zones.keys() == [start] and bool(zones[start]["open"]), "only %s is open" % start)
	ok(old["roster"].all(func(r): return r.get("zone") == start), "every Boki lives in %s" % start)
	ok(Save.fresh()["zones"] == GardenZones.fresh(), "a new save starts with only %s open" % start)

func _keys_part() -> void:
	Save.d = Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	ok(GardenZones.is_open("bramblebank") and not GardenZones.is_open("glasswater"), "Glasswater starts locked")
	ok(GardenZones.keys_for("glasswater") == {"seed": false, "lean": false}, "no keys yet")
	rec["lean"] = {"ice": float(GardenZones.rules()["lean_key"]) - 1.0}
	ok(not GardenZones.keys_for("glasswater")["lean"], "a Boki just under the lean key is not enough")
	rec["lean"]["ice"] = float(GardenZones.rules()["lean_key"])
	Save.d["items"][GardenZones.wayseed("glasswater")] = 1
	ok(GardenZones.keys_for("glasswater") == {"seed": true, "lean": true},
		"a Wayseed and a Boki leaning Ice tick both keys")
	var lines := ZoneCards.key_lines("glasswater")
	ok(lines.size() == 2 and "[x] A Wayseed" in lines[0] and "[x] A Boki leaning Water, Ice or Crystal" in lines[1],
		"the card lists both keys: %s" % " / ".join(lines))

func _new_save() -> void:
	var d := Save.fresh()
	for spec in [["zapple", "Pip"], ["cindle", "Ash"], ["burrlet", "Moss"]]:
		(d["roster"] as Array).append(Save.new_kin(spec[0], spec[1]))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true}
	Save.d = d
	HomeLayout.ensure(d)

## Waits for the home a goto started to be built and revealed; returns it, or null on a timeout.
func _arrived(m: Node, was: Node):
	var t := 0.0
	while t < WAIT_S:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
		var cur = Game.main.current
		if cur != was and is_instance_valid(cur) and cur.get("hway") != null and cur.get("player") != null \
				and cur.get("building") != true and cur.get("root_ui") != null and not Game.main.fade.covered:
			return cur
	return null

func _uids(home) -> Array:
	var out: Array = home.kins.map(func(k): return String(k["rec"]["uid"]))
	out.sort()
	return out

func _travel_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	var partner := String(Save.d["active"])
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await _arrived(m, null)
	ok(hub != null, "the hub loads")
	if hub == null:
		return
	ok(_uids(hub) == [partner], "only your partner is in the hub (%d Boki out)" % hub.kins.size())
	var off: float = hub.player.position.distance_to(hub.hway.node.position)
	ok(hub.hway.node.name == "Waystone" and off < HubWaystone.ARRIVE_OFF.length() + 0.5,
		"you arrive beside the Waystone")
	ok(hub.toys.toys().is_empty() and hub.hrace == null, "no toys or games in the hub")
	hub.hway.use()
	ok(hub.panel_open == "The Waystone", "E on the Waystone opens the cards")
	ok(not hub.hway.hop("glasswater") and hub.hway.hopping == "", "a hop to locked Glasswater is refused")
	var lines := ZoneCards.key_lines("glasswater")
	ok(lines.size() == 2 and "Wayseed" in lines[0] and "leaning" in lines[1], "its card lists both keys")
	var home_uids: Array = GardenZones.residents("bramblebank").map(func(r): return String(r["uid"]))
	home_uids.sort()
	ok(hub.hway.hop("bramblebank"), "a hop to open Bramblebank starts")
	var bb = await _arrived(m, hub)
	ok(bb != null and bb.zone == "bramblebank", "Bramblebank loads")
	if bb == null:
		return
	ok(_uids(bb) == home_uids and home_uids.has(partner),
		"Bramblebank has its %d Boki, your partner among them" % home_uids.size())
	ok(bb.player.position.distance_to(bb.hway.node.position) < 0.5, "you arrive on its return pad")
	ok(bb.hway.hop(GardenZones.HUB), "the return pad takes you to the hub")
	var back = await _arrived(m, bb)
	ok(back != null and _uids(back) == [partner], "back in the hub with your partner")
	ok(GardenZones.residents("bramblebank").size() == home_uids.size() and (Save.d["roster"] as Array).size() == 3,
		"nobody moved or went missing on the way")
	Content.rules("farm_build")["base_mode"] = false
