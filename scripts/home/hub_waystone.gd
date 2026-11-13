class_name HubWaystone
extends RefCounted
## Travel between the hub and the garden's zones (briefs/design/GARDEN.md 10.5). In the hub the
## Waystone stands north of where you land; in a zone a return pad stands by the landing. Step on
## either and press E: the zone cards (ZoneCards). Picking an open zone lights the stone up for
## hop_fade_s, then Game.goto("home", {"zone": id}) loads it under the ink wipe and you arrive on its
## pad (or beside the Waystone). A locked zone is refused. Your partner comes along: it is out in
## every zone (HubLayout keeps it in the hub's snapshot). Tuning: content/rules/garden_zones.json.
## Boki go through the pad too (GARDEN.md 10.4): one you send ("Move to..." on its card, setting it
## down on the stone, or E when it waits at the pad asking) walks to the pad and blinks out; it is in
## the other zone from then on. `pad` is the stone as a look target ({"pos"}) for BaseLife's ask.

const HUB_AT := Vector3(38.5, 0, 33.5)     # the Waystone, the middle of the hub, north of the landing
const PAD_NEAR := Vector3(40.5, 0, 36.5)   # a zone's return pad goes on open ground nearest this
const REACH := 2.2                          # m from the ring's or pad's middle to press E
const ARRIVE_OFF := Vector3(0, 0, 2.6)      # m from the Waystone to where you arrive in the hub

var h                          # the Home screen
var node: Node3D = null        # the Waystone or the return pad
var board: Node3D = null       # the hub's games board
var aim := ""                  # "board" while the games board is what E would use (set by find)
var hopping := ""              # the zone being travelled to, during the light-up
var pad := {}                  # the stone as something a Boki can look at: {"pos"}

func _init(home) -> void:
	h = home

## The zone this Home shows (GardenZones.HUB for the hub).
func here() -> String:
	return h.zone if h.zone != "" else GardenZones.start()

## Is zone `id` open: in your garden, or in the friend's you are visiting?
func is_open(id: String) -> bool:
	return VisitZones.is_open(h.visit, id) if VisitZones.has(h.visit) else GardenZones.is_open(id)

func place() -> void:
	if here() == GardenZones.HUB:
		var stones: Array = []
		for id in GardenZones.ids():
			var lit := is_open(id)
			stones.append({"colour": String(GardenZones.info(id)["colour"]), "open": lit,
				"keys": {} if lit or VisitZones.has(h.visit) else GardenZones.keys_for(id)})
		node = FarmModels.waystone(stones)
		node.position = HUB_AT
		if not VisitZones.has(h.visit):
			board = FarmModels.games_board()
			board.position = HubLayout.BOARD_AT
			board.rotation.y = -PI * 0.5
			h.add_child(board)
			var wall := BaseShowcase.build(HubLayout.BOARD_AT + HubLayout.WALL_OFF, Save.d.get("showcase", []))
			wall.rotation.y = board.rotation.y
			h.add_child(wall)
		HubHorizon.place(h, HUB_AT)
	else:
		node = FarmModels.return_pad(String(GardenZones.info(here()).get("colour", "c9c2b2")))
		node.position = h.world.free_spot_near(PAD_NEAR, [], 1.2, 0.9)
	node.name = "Waystone"
	h.add_child(node)
	if here() == GardenZones.HUB and not VisitZones.has(h.visit):
		ZoneReveal.play_owed(h, node)
	pad = {"pos": node.position}
	if h.zone != "" and here() != GardenZones.HUB:
		Sfx.play("garden_arrive_" + here())     # the landing chime, tuned to the zone's bed

## Wakes a locked zone with both keys: the Boki plants the Wayseed (toast, sound, burst); at the hub its stone
## lights up (ZoneReveal), elsewhere it does when you next come to the hub.
func attune(id: String) -> void:
	var r := GardenZones.attune(id)
	if not r["ok"]:
		h._toast(String(r["why"]))
		return
	h._close_panel()
	var z := GardenZones.info(id)
	h.fx.burst(node.position + Vector3(0, 0.8, 0), Color(String(z["colour"])), 30, 3.0, 0.8, -1.0)
	Sfx.play("unlock")
	if here() == GardenZones.HUB:
		node.queue_free()
		place()
	Save.save_game()
	h._toast("%s planted the Wayseed: %s is awake" % [r["founder"]["name"], z["name"]])

## Where you stand after a hop: on the pad, or just south of the Waystone. Elsewhere: where you'd be.
func arrive_at(p: Vector3) -> Vector3:
	if h.zone == "" or node == null:
		return p
	return node.position + (ARRIVE_OFF if here() == GardenZones.HUB else Vector3.ZERO)

func find(p2: Vector2) -> Dictionary:
	aim = ""
	if board != null and p2.distance_to(Vector2(board.position.x, board.position.z)) <= REACH:
		aim = "board"
		return {"kind": "waystone"}
	if node == null or hopping != "" or p2.distance_to(Vector2(node.position.x, node.position.z)) > REACH:
		return {}
	return {"kind": "waystone"}

func label() -> String:
	if aim == "board":
		return "Games board"
	return "The Waystone: travel" if here() == GardenZones.HUB else "Return pad: travel"

func use() -> void:
	if aim == "board":
		ZoneCards.board(h)
	elif VisitZones.has(h.visit):
		VisitZones.pick(h)
	else:
		ZoneCards.open(h, here())

## Travel to a zone (or the hub). Returns false, with a toast, for a locked zone or where you are.
func hop(id: String) -> bool:
	if hopping != "" or id == here():
		return false
	if id != GardenZones.HUB and not is_open(id):
		Sfx.play("garden_locked")
		h._toast("%s is still asleep: it needs both keys" % GardenZones.info(id).get("name", id))
		return false
	hopping = id
	h._close_panel()
	var col := Color(String(GardenZones.info(id).get("colour", "c9c2b2")))
	h.fx.burst(node.position + Vector3(0, 0.4, 0), col, 24, 3.0, 0.6, -2.0)
	Sfx.play("garden_hop")        # swells for hop_fade_s, the light-up
	h.get_tree().create_timer(float(GardenZones.rules()["hop_fade_s"])).timeout.connect(_go)
	return true

func _go() -> void:
	var opts := {"zone": hopping}
	if VisitZones.has(h.visit):
		opts.merge({"visit": h.visit["all"], "visit_id": h.visit_id})      # a friend's garden: still theirs
	Sfx.play("garden_depart")     # the whoosh as the screen goes
	Game.goto("home", opts)

# ------------------------------------------------------------------ moving a Boki to another zone
## Sends `k` to zone `id`: it walks to the pad (k["zone_go"]; BaseLife leaves it alone meanwhile).
## Returns "" or why not.
func send(k: Dictionary, id: String) -> String:
	var why := GardenZones.why_not(k["rec"], id)
	if why == "":
		k["zone_go"] = id
		k["zone_t"] = float(GardenZones.rules()["walk_s"])
	return why

## The sent Boki walk on; one at the pad (or out of time) blinks out into its new zone.
func step(dt: float) -> void:
	for k in h.kins.filter(func(o): return o.has("zone_go")):
		k["goal"] = pad["pos"]
		k["t"] = 1.0       # its think timer never runs out on the way: nothing else re-aims it
		k["zone_t"] = float(k["zone_t"]) - dt
		var off := Vector2(k["pos"].x - pad["pos"].x, k["pos"].z - pad["pos"].z).length()
		if off < REACH or float(k["zone_t"]) <= 0.0:
			_blink_out(k)

func _blink_out(k: Dictionary) -> void:
	var id := String(k["zone_go"])
	k.erase("zone_go")
	var why := GardenZones.move(k["rec"], id)
	if why != "":
		h._toast(why)       # the zone filled up while it walked
		return
	var n: Node3D = k["node"]
	h.fx.burst(n.position + Vector3(0, 0.5, 0), Color(String(GardenZones.info(id)["colour"])), 18, 2.5, 0.6, -1.5)
	n.queue_free()
	h.kins.erase(k)
	Save.save_game()
	h._toast("%s went to live in %s" % [k["rec"]["name"], GardenZones.info(id)["name"]])

## E on a Boki waiting at the pad (BaseLife's ask): send it where it wants to go. True if it was asking.
func answer(k: Dictionary) -> bool:
	var asking: bool = h.life != null and h.life.machine(k).is_in(BaseLife.S.REACT) and is_same(k.get("life_at"), pad)
	var id := GardenZones.wants(k["rec"]) if asking else ""
	if id == "":
		return false
	var why := send(k, id)
	if why != "":
		h._toast(why)
	return true

## A Boki you set down at `at`: on the stone, the zone list for it opens.
func dropped(k: Dictionary, at: Vector3) -> void:
	if node != null and Vector2(at.x - node.position.x, at.z - node.position.z).length() <= REACH:
		ZoneCards.move_to(h, k)
