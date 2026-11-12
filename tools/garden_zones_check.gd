extends RefCounted
## --garden-zones-check (briefs/design/GARDEN.md 10.7 steps 2, 4 and 5): the zones on the save, travel
## by the Waystone and moving Boki between zones. Save: a v12 save upgrades with only the start zone
## open and every Boki living in it; a new save has the same. Keys: a locked zone's two keys tick when
## you have them. Travel (with base_mode on, through the real Game.goto and ink wipe): the hub shows
## only your partner and the Waystone; a hop to a locked zone is refused and its card lists both keys;
## the hub to Bramblebank and back keeps your partner with you and every Boki where it lives; with an
## unminded egg in the Nook, a Boki with the Ember knack comes to the hub to mind it. Hub fixtures
## (step 3): each one stands and works, the games board shows this week's Dash twist and has the
## showcase wall beside it, no side-isle bridges, build mode offers only the Garden tab. Moving
## (step 5): a Boki sent with "Move to..." walks to the pad and blinks out, is gone from Bramblebank
## and there in Glasswater after the hop; once Glasswater holds the cap, the next move is refused; one
## that would thrive in Glasswater waits at the pad asking and E sends it; setting one down on the pad
## opens its cards. Glasswater (step 7a): its own island from data (theme, tub, patch, shallow court
## and scatter), build mode off, the patch's timer on the save, and nothing of it left in Bramblebank.
## Cinderstep (step 7b): its theme, a warm stone and a climbing post, a Fire/Rock/Steel/Dragon patch,
## the Stump Shove stump on its own spot with no Training post, terraces and glowing cracks in batches.
## With --shots-dir=<dir> (needs a renderer) it also saves hub.png, the whole hub, and
## hub_horizon_day.png and _night.png: the hub at arrival zoom with its five zone islands, three lit, two in mist.
## opens its cards. Thrive (step 8): a Boki leaning toward the zone's types (or with its trait over 0.6)
## loses joy at half speed and trains +25% at the zone's toys; one that doesn't loses joy as before;
## the zone's daily trait pull stops at 0.8 (calm Glasswater pulls temper down to 0.2).
## opens its cards. Unlock (step 6): no Wayseed, a Wayseed but no lean, and both: only both wake the zone,
## the Wayseed is used up and the Boki that leaned becomes the founder (it lives there, with a memory and a
## journal line, and the stone lights); lairs of a matching biome hold a Wayseed only for a locked zone; the
## trader holds one weekly Wayseed, never for an open zone.
## opens its cards. Visits (step 10): your profile doc carries the hub and each open zone's layout and
## each Boki's zone; a visitor lands in the friend's hub and hops to their zones, seeing only that zone's
## Boki; an older doc stays one island; a hostile layout is cut down to what the island needs.
## Hub fixtures (docs/decisions/0078): with the garden on, Bramblebank's own house, Nook, stall and Burrow go to its
## storage (an old save file too, and it round-trips), it builds none and build mode there does not offer them.

const WAIT_S := 30.0      # s to wait for a home to finish building before failing
const SHOT_ZOOM := 1.5    # camera zoom for the hub shot (0.8 close .. 1.6 wide)
const FRAME_MARGIN := 0.92  # an island counts as in frame with its middle this far from the centre (1 = the edge)
const SHOT_WAIT_S := 1.5  # s for the ink wipe to clear and the minder to set off before the shot

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ZONES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	_save_part()
	_claim_part()
	_keys_part()
	await _travel_part(m)
	await _move_part(m)
	await _glasswater_part(m)
	await _cinderstep_part(m)
	await _reload_part(m)
	_thrive_part()
	await _unlock_part(m)
	await _visit_part(m)
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

## The hub owns the house, Nook, stall and Burrow (docs/decisions/0078-hub-owns-fixtures.md): with the garden on, an
## older save's own copies go to Bramblebank's storage, a Sturdy Nook stays Sturdy in the hub, a house still going
## up pays back what went in, the egg is left as it is, and a second load changes nothing. Garden off: all kept.
func _claim_part() -> void:
	_new_save()
	var L: Dictionary = Save.d["layout"]
	var house_site := {"need": 9, "got": 2, "to": 1, "paid": {"gems": 20}}
	var mine := [{"u": 9001, "id": "nesting_nook", "x": 20, "z": 20, "r": 0, "t": 2},
		{"u": 9002, "id": "market_stall", "x": 26, "z": 20, "r": 0},
		{"u": 9003, "id": "boki_burrow", "x": 30, "z": 20, "r": 0},
		{"u": 9004, "id": "house", "x": 20, "z": 26, "r": 0, "site": house_site}]
	(L["deco"] as Array).append_array(mine.map(func(e): return e.duplicate(true)))
	HomeLayout.ensure(Save.d)
	ok(HubLayout.OWN.all(func(id): return (L["deco"] as Array).any(func(e): return e["id"] == id)),
		"garden off: Bramblebank keeps its own house, Nook, stall and Burrow")
	Content.rules("farm_build")["base_mode"] = true
	Save.d["egg"] = {"a": "o1", "b": "o2", "m": 3, "t": 1.0}
	var egg: Dictionary = Save.d["egg"].duplicate()
	var gems0 := int(Save.d["gems"])
	HomeLayout.ensure(Save.d)
	var left: Array = (L["deco"] as Array).filter(func(e): return HubLayout.OWN.has(String(e["id"])))
	ok(left.is_empty(), "garden on: none of them is left in Bramblebank")
	var stored := func() -> Array: return HubLayout.OWN.map(func(id): return int(L["inv"].get(id, 0)))
	ok(stored.call() == [0, 1, 1, 1],
		"the built ones wait in its storage, the unfinished house does not (%s)" % str(L["inv"]))
	ok(int(Save.d["gems"]) == gems0 + 20, "the house site paid back its 20 gems")
	var hub_nook: Array = (Save.d["hub_layout"]["deco"] as Array).filter(func(e): return e["id"] == "nesting_nook")
	ok(hub_nook.size() == 1 and FarmSites.tier(hub_nook[0]) == 2, "the Sturdy Nook is Sturdy in the hub")
	ok(Save.d["egg"] == egg, "the egg is the save's: the hub's Nook shows it as it was")
	HomeLayout.ensure(Save.d)
	ok(stored.call() == [0, 1, 1, 1] and int(Save.d["gems"]) == gems0 + 20, "a second load changes nothing")
	_claim_file_part(mine, egg)
	Content.rules("farm_build")["base_mode"] = false

## An old save file (v12, its own house, Nook, stall and Burrow, an egg in the Nook) loads with the garden on,
## gives them to the hub, is written back and loads again the same.
func _claim_file_part(mine: Array, egg: Dictionary) -> void:
	var old := Save.fresh()
	old["v"] = 12
	old.erase("zones")
	old["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	HomeLayout.ensure(old)
	(old["layout"]["deco"] as Array).append_array(mine.map(func(e): return e.duplicate(true)))
	old["egg"] = egg
	var p := "user://hub_claim_old_save.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(p)
	HomeLayout.ensure(Save.d)
	var claimed := JSON.stringify(Save.d)
	f = FileAccess.open(p, FileAccess.WRITE)
	f.store_string(claimed)
	f.close()
	Save.load_from(p)
	HomeLayout.ensure(Save.d)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var own: Array = (Save.d["layout"]["deco"] as Array).filter(func(e): return HubLayout.OWN.has(String(e["id"])))
	var egg_kept := _json(Save.d["egg"]) == _json(egg)
	ok(int(Save.d["v"]) == Save.VERSION and own.is_empty() and egg_kept and Save.d.has("hub_layout"),
		"an old save file loads with its fixtures given to the hub and the egg as it was")
	ok(_json(Save.d) == _json(JSON.parse_string(claimed)), "written back and loaded again, it is the same")

## A value as the save file holds it (JSON: every number a float).
func _json(v) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)))

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

## An egg in the Nook, waiting to be minded; returns the uid of the Boki with the Ember knack who minds it.
func _lay_egg(partner: String) -> String:
	var rec := Save.new_kin("kindlewren", "Wick")
	rec["zone"] = GardenZones.start()
	(Save.d["roster"] as Array).append(rec)
	var other: Dictionary = (Save.d["roster"] as Array).filter(func(r): return r["uid"] != partner)[0]
	Save.d["egg"] = {"a": partner, "b": other["uid"], "m": int(Save.d["matches"]) + 5,
		"t": Time.get_unix_time_from_system() + 600.0}
	var found := HubLayout.minder()
	ok(not found.is_empty() and Work.of(found).has("ember"), "an unminded egg calls a Boki with the Ember knack")
	return String(found.get("uid", ""))

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
	_fixtures_part(hub)
	_horizon_part(hub, [GardenZones.start()])
	hub.ppos = HubWaystone.HUB_AT + HubWaystone.ARRIVE_OFF
	hub._find_interact()
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
	ok([bb.spots["house"], bb.spots["stall"], bb.NEST_AT, bb.INCUB_AT, bb.BURROW_AT].all(func(p): return p == bb.FAR)
		and bb.house_node == null and bb.burrow_node == null and bb.nest == null,
		"Bramblebank has no house, Nook, Incubator, stall or Burrow of its own: the hub's are the only ones")
	var offered: Array = bb.hb.entries.tab("Buildings").map(func(e): return String(e.get("id", "")))
	ok(not HubLayout.OWN.any(func(id): return offered.has(id)), "and its build mode does not offer them")
	var minder := _lay_egg(partner)
	ok(bb.hway.hop(GardenZones.HUB), "the return pad takes you to the hub")
	var back = await _arrived(m, bb)
	var walkers := [partner, minder]
	walkers.sort()
	ok(back != null and _uids(back) == walkers, "back in the hub with your partner and the egg-minder")
	if back != null:
		var mrec: Dictionary = (Save.d["roster"] as Array).filter(func(r): return r["uid"] == minder)[0]
		var mk: Dictionary = back._kin_entry(mrec)
		ok(back.life != null and back.life._chore(mk) and String(mk["life_chore"]["kind"]) == "mind",
			"the egg-minder sets off to mind the egg in the Nook")
		await _hub_shot(m, back, "hub.png", SHOT_ZOOM)
	ok(GardenZones.residents("bramblebank").size() == home_uids.size() + 1 and (Save.d["roster"] as Array).size() == 4,
		"nobody moved or went missing on the way")
	Content.rules("farm_build")["base_mode"] = false

## The hub's fixtures: each one is there and E works at it; build mode there offers only the Garden tab.
func _fixtures_part(hub) -> void:
	var lay: Dictionary = hub._d()
	for fx in ["house", "stall", "nook", "burrow"]:
		ok(not HomeLayout.fixtures(lay, fx).is_empty(), "the hub has its %s" % fx)
	ok(HomeLayout.placed("shrine", lay) and hub.lots["shrine"]["at"].x > -100.0, "the Soul Shrine has its lot")
	ok(hub.rack_node != null and hub.hinc != null and hub.hway.board != null, "rack, Incubator and games board stand")
	ok(is_instance_valid(hub.house_node) and is_instance_valid(hub.burrow_node), "the house and the Burrow are built")
	var at := {"house": hub._house_door(), "stall": hub.spots["stall"] + Vector3(0, 0, 1.2),
		"portal": hub.spots["portal"], "rack": hub.spots["rack"], "burrow": hub.BURROW_AT + Vector3(0, 0, 1.55),
		"nook": hub.NEST_AT, "incubator": hub.INCUB_AT, "waystone": HubLayout.BOARD_AT + Vector3(-1.2, 0, 0)}
	for kind in at:
		hub.ppos = at[kind]
		hub._find_interact()
		ok(String(hub.interact.get("kind", "")) == kind or (kind == "nook" and hub.interact.get("kind") == "egg"),
			"E at the %s uses it (got %s)" % [kind, hub.interact.get("kind", "nothing")])
	var w: World = hub.world
	var afloat := func(c: Vector2i) -> bool: return w.inb(c.x, c.y) and w.kind[w.idx(c.x, c.y)] != World.T_VOID
	var decos: Array = lay["layout"]["deco"]
	ok(decos.all(func(e): return HomeLayout.deco_cells(e).all(afloat)), "every fixture stands on land")
	var spots: Array = [HubWaystone.HUB_AT, HubLayout.BOARD_AT]
	ok(spots.all(func(p): return afloat.call(Vector2i(int(p.x), int(p.z)))), "the Waystone and the board are on land")
	ok(hub.hway.label() == "Games board", "the games board reads as one")
	hub.hway.use()
	var said: String = _texts(hub.root_ui)
	ok(BaseRace.twist()["name"] in said and "Showcase wall" in said, "the board shows this week's twist and the wall")
	hub._close_panel()
	var wall: Node3D = hub.get_node_or_null("Showcase")
	ok(wall != null and wall.position.distance_to(HubLayout.BOARD_AT + HubLayout.WALL_OFF) < 0.1,
		"the showcase wall hangs beside the board")
	ok(hub.bridges.is_empty(), "no side-isle bridges or signposts in the hub")
	ok(hub.hb._tabs() == ["Garden"] and hub.hb.can_build(), "build mode in the hub offers only the Garden tab")
	ok(typeof(Save.d.get("hub_layout")) == TYPE_DICTIONARY, "the hub's layout is on the save")

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

## Every label's text under a node, joined.
## The hub's horizon (step 9): five islands, one lit for each zone in `open_ids`, two shared materials,
## and the lit ones are warmer and the locked ones greyer than their zone colour.
func _horizon_part(hub, open_ids: Array) -> void:
	var isles: Array = hub.get_children().filter(func(n): return n.name.begins_with("Horizon_"))
	ok(isles.size() == GardenZones.ids().size(), "the hub shows %d islands on its horizon" % isles.size())
	var follows := true
	var mats := {}
	for isle in isles:
		var id := String(isle.name).trim_prefix("Horizon_")
		var lit: bool = isle.get_meta("open")
		follows = follows and lit == open_ids.has(id) and lit == GardenZones.is_open(id)
		mats[isle.material_override] = true
		var top: Color = isle.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR][0]
		var zone_col := Color(String(GardenZones.info(id)["colour"]))
		ok(lit == (top.s > zone_col.s * 0.6), "%s's island reads %s" % [id, "lit" if lit else "grey in mist"])
	ok(follows, "the islands follow Save.d zones (open: %s)" % ", ".join(open_ids))
	ok(mats.size() == (2 if open_ids.size() < isles.size() else 1), "islands share one material per state")
	# seen as you arrive: the hub's own camera (arrival zoom, on the landing spot) takes in every island
	hub.cam.zoom_to = hub.HOME_ZOOM
	hub.cam.zoom = hub.HOME_ZOOM
	hub.cam.snap(HubWaystone.HUB_AT + HubWaystone.ARRIVE_OFF)
	var seen := isles.filter(func(n): return _in_frame(hub.cam, n.global_position))
	ok(seen.size() == isles.size(), "at arrival zoom %d of %d islands are in frame" % [seen.size(), isles.size()])

## Whether `p` shows on a 16:9 screen (inside FRAME_MARGIN of its edges) through `cam`'s lens. The
## headless viewport is square, so the screen point is rescaled to 16:9 at the same height (Godot keeps
## the vertical lens and widens the view sideways).
func _in_frame(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var vs := cam.get_viewport().get_visible_rect().size
	var s := (cam.unproject_position(p) - vs * 0.5) / (vs * 0.5)
	return absf(s.x * (vs.x / vs.y) / (16.0 / 9.0)) < FRAME_MARGIN and absf(s.y) < FRAME_MARGIN

## Opening a zone lights its island the next time the hub loads.
func _reload_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Save.d["zones"]["glasswater"] = {"open": true}
	Save.d["zones"]["cinderstep"] = {"open": true}
	var was = Game.main.current
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await _arrived(m, was)
	ok(hub != null, "the hub reloads with Cinderstep open")
	if hub != null:
		_horizon_part(hub, [GardenZones.start(), "glasswater", "cinderstep"])
		hub.day_t = 0.5
		await _hub_shot(m, hub, "hub_horizon_day.png", hub.HOME_ZOOM, true)
		hub.day_t = 0.97
		await _hub_shot(m, hub, "hub_horizon_night.png", hub.HOME_ZOOM, true)
	Content.rules("farm_build")["base_mode"] = false

func _texts(n: Node) -> String:
	var out := (n as Label).text if n is Label else ""
	for c in n.get_children():
		out += "\n" + _texts(c)
	return out

## hub.png in --shots-dir, when one is given: the whole hub from above, for review by eye.
func _hub_shot(m: Node, hub, file: String, zoom: float, arrival := false) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	hub.cam.zoom_to = zoom
	hub.cam.zoom = zoom
	hub.cam.snap(HubWaystone.HUB_AT + (HubWaystone.ARRIVE_OFF if arrival else Vector3.ZERO))
	await m.get_tree().create_timer(SHOT_WAIT_S).timeout
	hub.prompt_box.visible = false
	await m.get_tree().process_frame
	m.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("ZONES shot %s" % dir.path_join(file))

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
	ok(ids.has("toy_stone") and ids.has("toy_post"), "a warm stone and a climbing post (%s)" % ", ".join(ids))
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
	var terrace: MultiMeshInstance3D = cs.find_child("terrace", false, false)
	ok(kinds.get("terrace", 0) >= 2 and kinds.get("crack", 0) > 0 and crack.multimesh.use_colors
		and crack.material_override == terrace.material_override,
		"terraces and glowing cracks, one batch each on one material (%s)" % str(kinds))
	Content.rules("farm_build")["base_mode"] = false
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
	rec["zone"] = GardenZones.start()      # lives elsewhere: only thrive counts (--zone-affinity-check has the rest)
	var gain := [0, 0]
	for i in 400:
		gain[0] += GardenZones.train_gain(rec, 1)
		gain[1] += GardenZones.train_gain(other, 1)
	ok(gain[1] == 400 and gain[0] > 440 and gain[0] < 560,
		"a thriver's toys train about +25%% (%d vs %d per 400)" % [gain[0], gain[1]])
	rec["zone"] = "cinderstep"
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
## The Waystone in the hub with the Boki on the base: Ash leans Fire, so Cinderstep is the zone to wake.
func _unlock_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	Game.goto("home", {"zone": GardenZones.HUB})
	var hub = await _arrived(m, Game.main.current)
	ok(hub != null, "the hub loads for the unlock")
	if hub == null:
		return
	var ash: Dictionary = Save.d["roster"][1]
	var key := float(GardenZones.rules()["lean_key"])
	var stone: Node = hub.hway.node.get_node("Stone2")
	var marks: bool = hub.hway.node.has_node("Key2_0") and hub.hway.node.has_node("Key2_1")
	ok(not stone.get_meta("open") and marks, "the locked Cinderstep stone shows its two keys")
	ok(not GardenZones.attune("cinderstep")["ok"], "no Wayseed and no lean: Cinderstep stays asleep")
	ash["lean"] = {"fire": key}
	hub.hway.attune("cinderstep")
	ok(not GardenZones.is_open("cinderstep"), "a lean but no Wayseed does not wake it")
	ash["lean"] = {"fire": key - 1.0}
	Save.add_item(GardenZones.wayseed("cinderstep"), 1)
	hub.hway.attune("cinderstep")
	ok(not GardenZones.is_open("cinderstep") and int(Save.d["items"][GardenZones.wayseed("cinderstep")]) == 1,
		"a Wayseed and a lean just under 12 does not wake it, and keeps the seed")
	ash["lean"] = {"fire": key}
	hub.hway.attune("cinderstep")
	ok(GardenZones.is_open("cinderstep") and _seeds("cinderstep") == 0, "both keys wake Cinderstep, the seed is used")
	ok(GardenZones.founder("cinderstep") == ash and GardenZones.zone_of(ash) == "cinderstep", "Ash is the founder")
	ok(ash["memory"].any(func(e): return "the day I woke Cinderstep" in String(e["text"])), "it remembers the day")
	ok(ash["journal"].any(func(e): return CareJournal.text(e) == "woke Cinderstep"), "its journal says so")
	ok(hub.hway.node.get_node("Stone2").get_meta("open") and hub.hway.node.has_node("Cap2"), "its stone is lit")
	ok(not GardenZones.attune("cinderstep")["ok"], "an open zone cannot be woken again")
	var lines: Array = ZoneCards._open_lines("cinderstep").map(func(l): return (l as Label).text)
	ok(lines.has("Woken by Ash"), "its card names the founder")
	_lair_and_trader_part()
	Content.rules("farm_build")["base_mode"] = false

func _lair_and_trader_part() -> void:
	ok(GardenZones.seed_zone_for("ember") == "" and GardenZones.seed_zone_for("frost") == "glasswater"
		and GardenZones.seed_zone_for("gloom") == "hushwood" and GardenZones.seed_zone_for("meadow") == "",
		"a lair's Wayseed is for a locked zone of its biome: not Cinderstep (open), not the meadow")
	var seed_item := Loot.valuable(GardenZones.wayseed("ridge"))
	ok(Loot.is_wayseed(seed_item) and Loot.keepable(seed_item), "a Wayseed is carried home")
	Econ._store(seed_item)
	ok(_seeds("ridge") == 1 and not Save.d["valuables"].has("wayseed_ridge"), "it comes home as a bag item")
	Save.d["gems"] = 5000
	var held: Array = BlackMarket.stock().filter(func(e): return BlackMarket.is_seed(String(e["key"])))
	ok(held.size() == 1 and not GardenZones.is_open(BlackMarket.id_of(String(held[0]["key"]))),
		"the trader holds one Wayseed, for a zone still locked")
	var zone := BlackMarket.id_of(String(held[0]["key"]))
	ok(BlackMarket.buy(String(held[0]["id"]))["ok"] and _seeds(zone) >= 1, "buying it puts the Wayseed in the bag")
	ok(not _trader_has_seed(), "no second Wayseed the same week")
	Save.d["market"]["black"]["seed_week"] = -1
	for id in GardenZones.ids():
		Save.d["zones"][id] = {"open": true}
	ok(not _trader_has_seed(), "with every zone open the trader holds no Wayseed")

func _seeds(zone: String) -> int:
	return int(Save.d["items"].get(GardenZones.wayseed(zone), 0))

func _trader_has_seed() -> bool:
	return BlackMarket.stock().any(func(e): return BlackMarket.is_seed(String(e["key"])))
func _island(seed: int) -> Dictionary:
	var L := HomeLayout.fresh()
	L["seed"] = seed
	L["fs"] = 1
	L["sk"] = 0.55
	return L

## A friend's garden through the profile doc (the JSON round trip a real doc takes), then in the real scene.
func _visit_part(m: Node) -> void:
	Content.rules("farm_build")["base_mode"] = true
	_new_save()
	var ash: Dictionary = Save.d["roster"][1]
	ash["zone"] = "glasswater"
	Save.d["layout"] = _island(11)
	Save.d["zones"]["glasswater"] = {"open": true, "layout": _island(22)}
	var doc: Dictionary = JSON.parse_string(JSON.stringify(Social.profile_doc()))
	var snap := Social.clean_island(doc)
	ok(VisitZones.has(snap) and snap["zones"].keys() == ["bramblebank", "glasswater"]
			and int(snap["zones"]["glasswater"]["seed"]) == 22,
		"the snapshot carries the hub and both open zones' layouts")
	ok(GardenZones.landing({"visit": snap}) == GardenZones.HUB, "a visitor lands in the hub")
	var gw := VisitZones.view(snap, "glasswater")
	ok(gw["roster"].map(func(r): return r["name"]) == ["Ash"]
			and VisitZones.view(snap, GardenZones.HUB)["roster"].is_empty(),
		"a zone shows only its own Boki, the hub none")
	var old := doc.duplicate()
	old.erase("zones")
	old.erase("hub_layout")
	ok(not VisitZones.has(Social.clean_island(old)) and GardenZones.landing({"visit": Social.clean_island(old)}) == "",
		"an older doc is the single island it was")
	var junk := {"theme": "<b>", "grow": 99, "deco": []}
	for i in 500:
		junk["deco"].append({"id": "lamp_post" if i % 2 == 0 else "nope", "x": 9999, "z": -5})
	var cut := VisitZones.clean_layout(junk)
	ok(cut["deco"].size() == VisitZones.DECO_MAX and cut["theme"] == "meadow"
			and cut["grow"] == HomeLayout.EXPAND.size() and cut["deco"][0]["x"] == VisitZones.TILE_MAX,
			"a hostile layout is cut to the catalog, the tiles, a cap")
	Game.goto("home", {"visit": snap, "visit_id": "t"})
	var hub = await _arrived(m, null)
	ok(hub != null and hub.zone == GardenZones.HUB and hub.hway.is_open("glasswater")
			and not hub.hway.is_open("hushwood"),
		"the visitor stands in the friend's hub")
	if hub == null:
		return
	ok(hub.kins.is_empty() and hub.hway.board == null, "nobody lives in their hub, and their games board is not yours")
	ok(hub.hway.hop("glasswater"), "the visitor hops to their Glasswater")
	var zone = await _arrived(m, hub)
	ok(zone != null and zone._visiting() and zone.zone == "glasswater" and _uids(zone) == [String(ash["uid"])],
		"and finds only Ash there, still a visit")
	var egg := Incubator.add(String(Data.common_kin()[0]))
	for _f in 20: await m.get_tree().process_frame
	ok(zone != null and zone.hinc == null and float(Incubator.find(String(egg["id"])).get("heat", 0.0)) > 0.0,
		"your own Rare Egg keeps warming while you visit (play time; decision 0080)")
	Content.rules("farm_build")["base_mode"] = false
