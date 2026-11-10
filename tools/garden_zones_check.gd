extends RefCounted
## --garden-zones-check (briefs/design/GARDEN.md 10.7 steps 2, 4 and 5): the zones on the save, travel
## by the Waystone and moving Boki between zones. Save: a v12 save upgrades with only the start zone
## open and every Boki living in it; a new save has the same. Keys: a locked zone's two keys tick when
## you have them. Travel (with base_mode on, through the real Game.goto and ink wipe): the hub shows
## only your partner and the Waystone; a hop to a locked zone is refused and its card lists both keys;
## the hub to Bramblebank and back keeps your partner with you and every Boki where it lives. Moving
## (step 5): a Boki sent with "Move to..." walks to the pad and blinks out, is gone from Bramblebank
## and there in Glasswater after the hop; once Glasswater holds the cap, the next move is refused; one
## that would thrive in Glasswater waits at the pad asking and E sends it; setting one down on the pad
## opens its cards. Glasswater (step 7a): its own island from data (theme, tub, patch, shallow court
## and scatter), build mode off, the patch's timer on the save, and nothing of it left in Bramblebank.
## Cinderstep (step 7b): its theme, two warm stones and a climbing post, a Fire/Rock/Steel/Dragon patch,
## the Stump Shove stump on its own spot with no Training post, terraces and glowing cracks in batches.

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
	await _move_part(m)
	await _glasswater_part(m)
	await _cinderstep_part(m)
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

func _move_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Save.d["zones"]["glasswater"] = {"open": true}
	var partner := String(Save.d["active"])
	Game.goto("home", {"zone": "bramblebank"})
	var bb = await _arrived(m, Game.main.current)
	ok(bb != null and bb.life != null, "Bramblebank loads with base life")
	if bb == null or bb.life == null:
		return
	var k: Dictionary = bb.kins.filter(func(o): return String(o["rec"]["uid"]) != partner)[0]
	var rec: Dictionary = k["rec"]
	ZoneCards.move_to(bb, k)
	ok(bb.panel_open == "Move %s to..." % rec["name"], "Move to... opens its zone cards")
	bb._close_panel()
	ok(bb.hway.send(k, "glasswater") == "", "%s is sent to Glasswater" % rec["name"])
	var t := 0.0
	while bb.kins.has(k) and t < float(GardenZones.rules()["walk_s"]) + 2.0:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
	ok(not bb.kins.has(k) and GardenZones.zone_of(rec) == "glasswater",
		"it walks to the pad and blinks out (%.1f s)" % t)
	ok(bb.hway.send(bb._kin_entry(Save.active_kin()), "glasswater") != "",
		"your partner can't be moved: it follows you")
	_ask_part(bb, partner)
	bb.hway.hop("glasswater")
	var gw = await _arrived(m, bb)
	ok(gw != null and gw.zone == "glasswater", "Glasswater loads")
	if gw == null:
		return
	var want := [partner, String(rec["uid"])]
	want.sort()
	ok(_uids(gw) == want, "in Glasswater after the hop: your partner and %s" % rec["name"])
	ok(GardenZones.residents("bramblebank").all(func(r): return r != rec), "%s is gone from Bramblebank" % rec["name"])
	_cap_part()
	Content.rules("farm_build")["base_mode"] = false

## The ask at the pad, and a carried Boki set down on it.
func _ask_part(bb, partner: String) -> void:
	var k: Dictionary = bb.kins.filter(func(o): return String(o["rec"]["uid"]) != partner)[0]
	k["rec"]["lean"] = {"crystal": 8.0}
	var Z := GardenZones.rules()
	var was := float(Z["ask_chance"])
	Z["ask_chance"] = 1.0
	ok(GardenZones.wants(k["rec"]) == "glasswater", "a Boki leaning Crystal would thrive in Glasswater")
	bb.life.machine(k).go(BaseLife.S.ROAM, "check")
	ok(bb.life._ask(k) and is_same(k["life_at"], bb.hway.pad), "it goes to wait at the pad, asking")
	ok(not bb.life._ask(k), "it asks once per visit")
	Z["ask_chance"] = was
	ok(bb.hway.answer(k) and k.get("zone_go") == "glasswater", "E on it sends it to Glasswater")
	k.erase("zone_go")
	bb.life.machine(k).go(BaseLife.S.ROAM, "check")
	ok(not bb.hway.answer(k), "a Boki not asking is petted as usual")
	bb.hway.dropped(k, bb.hway.node.position)
	ok(bb.panel_open == "Move %s to..." % k["rec"]["name"], "set down on the pad: its zone cards open")
	bb._close_panel()

## The cap is per zone: Glasswater full, the next move is refused; Bramblebank keeps its own room.
func _cap_part() -> void:
	var cap := KinBox.farm_cap()
	while GardenZones.residents("glasswater").size() < cap:
		var r := Save.new_kin("zapple", "Fill%d" % GardenZones.residents("glasswater").size())
		r["zone"] = "glasswater"
		(Save.d["roster"] as Array).append(r)
	var next: Dictionary = GardenZones.residents("bramblebank").filter(func(r): return not GardenZones.is_partner(r))[0]
	ok(GardenZones.move(next, "glasswater") != "" and GardenZones.zone_of(next) == "bramblebank",
		"with %d out in Glasswater, the next move is refused" % cap)
	ok(GardenZones.room("bramblebank") > 0, "Bramblebank still has room of its own")

func _glasswater_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Save.d["zones"]["glasswater"] = {"open": true}
	var B: Dictionary = GardenZones.info("glasswater")["build"]
	Game.goto("home", {"zone": "glasswater"})
	var gw = await _arrived(m, Game.main.current)
	ok(gw != null and gw.hvolley != null, "Glasswater loads")
	if gw == null or gw.hvolley == null:
		return
	ok(HomeLayout.of(Save.d)["theme"] == "glasswater" and String(Save.d["layout"]["theme"]) == "meadow",
		"its layout stands in while it is open; the save's own layout stays Bramblebank's")
	ok(gw.toys.toys().any(func(t): return t["id"] == "toy_tub"),
		"the splash tub stands in it")
	var snacks := SnackPatch.snacks(Save.d)
	var types: Array = GardenZones.info("glasswater")["types"]
	ok(snacks.size() == 3 and snacks.all(func(f): return types.has(Content.rules("lean")["foods"][f])),
		"its patch grows Water, Ice and Crystal snacks (%s)" % ", ".join(snacks))
	var log_at: Vector3 = gw.hvolley.log_node.position
	var sh: Array = B["shallow"]
	ok(log_at.x >= sh[0] and log_at.x <= sh[2] + 1.0 and log_at.z >= sh[1] and log_at.z <= sh[3] + 1.0,
		"the Spark Volley log lies in the shallow channel")
	gw.hvolley._splash(0)
	ok(not BaseVolley.court().is_empty(), "a miss splashes on the court")
	ok(gw.hway.node != null and gw.player.position.distance_to(gw.hway.node.position) < 0.5,
		"you arrive on its return pad")
	ok(not gw.hb.can_build(), "build mode is off in the zone")
	var batches: Array = gw.find_children("*", "MultiMeshInstance3D", false, false)
	var mats := {}
	var n := 0
	for mi in batches:
		mats[(mi as MultiMeshInstance3D).material_override] = true
		n += (mi as MultiMeshInstance3D).multimesh.instance_count
	var want: int = int(B["scatter"]["crystal"]) + int(B["scatter"]["reed"]) + int(B["scatter"]["pebble"])
	ok(batches.size() >= 3 and batches.size() <= 6 and mats.size() == 3 and n > want / 2,
		"the scatter is %d props in %d MultiMesh batches over 3 shared materials" % [n, batches.size()])
	gw.hsp.tick(1.0)
	ok(Save.d["zones"]["glasswater"]["patch"].has("t"), "the patch's timer is kept on the save")
	gw.hway.hop(GardenZones.HUB)
	var hub = await _arrived(m, gw)
	ok(hub != null and ZoneLayout.live.is_empty(), "the hub has no zone layout")
	Content.rules("farm_build")["base_mode"] = false

func _cinderstep_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Save.d["zones"]["cinderstep"] = {"open": true}
	Game.goto("home", {"zone": "cinderstep"})
	var cs = await _arrived(m, Game.main.current)
	ok(cs != null and cs.hshove != null, "Cinderstep loads")
	if cs == null or cs.hshove == null:
		return
	ok(HomeLayout.of(Save.d)["theme"] == "cinderstep", "its own cinder ground")
	var ids: Array = cs.toys.toys().map(func(t): return t["id"])
	ok(ids.count("toy_stone") == 2 and ids.has("toy_post"), "two warm stones and a climbing post (%s)" % ", ".join(ids))
	var snacks := SnackPatch.snacks(Save.d)
	var grown := {}
	for f in snacks:
		grown[Content.rules("lean")["foods"][f]] = true
	ok(grown.keys().size() == 4 and GardenZones.info("cinderstep")["types"].all(func(t): return grown.has(t)),
		"its patch grows Fire, Rock, Steel and Dragon snacks (%s)" % ", ".join(snacks))
	var spot: Array = BaseShove.spot()
	var at := Vector2(cs.hshove.stump.position.x, cs.hshove.stump.position.z)
	var on_spot := at.is_equal_approx(Vector2(spot[0], spot[1]))
	ok(cs.YARD_AT.x < -100.0 and on_spot and cs.hshove.find(at) == {"kind": "shove"},
		"the Stump Shove stump stands on its spot with no Training post and offers a bout")
	var kinds := {}
	for mi in cs.find_children("*", "MultiMeshInstance3D", false, false):
		kinds[mi.name] = (mi as MultiMeshInstance3D).multimesh.instance_count
	var crack: MultiMeshInstance3D = cs.find_child("crack", false, false)
	ok(kinds.get("terrace", 0) >= 2 and kinds.get("crack", 0) > 0 and crack.multimesh.get_instance_color(0).a == 0.0,
		"terraces and glowing cracks, one batch each (%s)" % str(kinds))
	Content.rules("farm_build")["base_mode"] = false
