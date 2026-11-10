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
## opens its cards. Thrive (step 8): a Boki leaning toward the zone's types (or with its trait over 0.6)
## loses joy at half speed and trains +25% at the zone's toys; one that doesn't loses joy as before;
## the zone's daily trait pull stops at 0.8 (calm Glasswater pulls temper down to 0.2).

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
	_thrive_part()
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

## Thriving is a lean in the zone's types or a matching trait over 0.6; joy, toy training and the daily pull follow.
func _thrive_part() -> void:
	Content.rules("farm_build")["base_mode"] = true
	Save.d = Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	var other := Save.new_kin("zapple", "Fen")
	var T: Dictionary = GardenZones.rules()["thrive"]
	GardenZones.here = "cinderstep"
	rec["lean"] = {"fire": 6.0}
	other["lean"] = {"water": 6.0}
	rec["traits"]["temper"] = 0.5
	other["traits"]["temper"] = 0.5
	ok(GardenZones.thrives(rec) and not GardenZones.thrives(other),
		"a Boki leaning Fire thrives in Cinderstep, one leaning Water does not")
	other["traits"]["temper"] = float(T["trait_over"]) + 0.05
	ok(GardenZones.thrives(other), "a temper over %.1f thrives there too" % float(T["trait_over"]))
	other["traits"]["temper"] = 0.5
	var lost := [0.0, 0.0]
	for i in 2:
		var r: Dictionary = [rec, other][i]
		r["needs"] = {"food": 90.0, "clean": 90.0, "energy": 90.0, "joy": 90.0}
		Care.tick(r, 600.0)
		lost[i] = 90.0 - Care.need(r, "joy")
	ok(lost[1] > 0.0 and is_equal_approx(lost[0], lost[1] * float(T["joy_rate"])),
		"thriving joy falls at %.1fx (%.1f vs %.1f)" % [float(T["joy_rate"]), lost[0], lost[1]])
	GardenZones.here = "glasswater"
	ok(GardenZones.thrives(other) and not GardenZones.thrives(rec),
		"Glasswater: Water lean thrives, Fire with temper 0.5 does not")
	rec["traits"]["temper"] = 0.2
	ok(GardenZones.thrives(rec), "a calm Boki (temper 0.2) thrives in Glasswater")
	_train_pull_part(rec, other)
	GardenZones.here = ""
	Content.rules("farm_build")["base_mode"] = false

## Toy training +25% for a thriver (never less), and the daily pull stops at the limit.
func _train_pull_part(rec: Dictionary, other: Dictionary) -> void:
	GardenZones.here = "cinderstep"
	rec["zone"] = "cinderstep"
	var gain := [0, 0]
	for i in 400:
		gain[0] += GardenZones.train_gain(rec, 1)
		gain[1] += GardenZones.train_gain(other, 1)
	ok(gain[1] == 400 and gain[0] > 440 and gain[0] < 560,
		"a thriver's toys train about +25%% (%d vs %d per 400)" % [gain[0], gain[1]])
	var P: Dictionary = GardenZones.rules()["trait_pull"]
	rec["traits"]["temper"] = 0.5
	BaseDrift.day([rec])
	ok(is_equal_approx(float(rec["traits"]["temper"]), 0.5 + float(P["per_day"])),
		"a day in Cinderstep: temper +%.2f" % float(P["per_day"]))
	for i in 60:
		BaseDrift.day([rec])
	ok(is_equal_approx(float(rec["traits"]["temper"]), float(P["stop_at"])),
		"the pull stops at %.1f" % float(P["stop_at"]))
	rec["traits"]["temper"] = 0.9
	BaseDrift.day([rec])
	ok(is_equal_approx(float(rec["traits"]["temper"]), 0.9), "a trait already past the limit is left alone")
	GardenZones.here = "glasswater"
	rec["zone"] = "glasswater"
	rec["traits"]["temper"] = 0.5
	for i in 60:
		BaseDrift.day([rec])
	ok(is_equal_approx(float(rec["traits"]["temper"]), 1.0 - float(P["stop_at"])),
		"calm Glasswater pulls temper down and stops at %.1f" % (1.0 - float(P["stop_at"])))
	var away := Save.new_kin("zapple", "Away")
	var temper := float(away["traits"]["temper"])
	BaseDrift.day([away])
	ok(is_equal_approx(float(away["traits"]["temper"]), temper), "a Boki from another zone is not pulled")
