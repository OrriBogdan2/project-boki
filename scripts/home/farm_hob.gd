class_name FarmHob
extends RefCounted
## Hob Brackenridge in the world (home.gd owns one): a person (HobModel) who waits by the market stall and
## walks over to work at the house while it goes up. On the first arrival the camera swings over to him while
## he waves and calls you over, and his name shows over him until you have talked. Walk up and press interact
## and he talks face to face (HobTalk: the farm tutorial, blueprints from FarmBuilder, and the second Mask).
## A "!" floats over him while he has something for you. Holding the same interact key hammers a house or
## building going up, beat after beat, when the tutorial option player_swing is on; your Boki nearby come and
## help, and the materials are spent as it goes (FarmSites).

const FACE_YOU_M := 9.0          # m: closer than this he turns to watch you come
const SITE_REACH := 2.2          # m beyond the site's half-size you can keep hammering from

var h
var node: HobModel = null
var chat: HobTalk = null
var t := 0.0
var poll_t := 0.0
var call_t := 0.0
var site_u := -1                 # the construction site you are hammering (deco uid)
var pos := Vector3.INF           # where he is standing (or walking to)

func _init(home) -> void:
	h = home
	chat = HobTalk.new(self)

func rules() -> Dictionary:
	return FarmBuilder.rules()

## Where he stands: working beside the house while it is a construction site, else by the market stall
## (out in front of it and to its side). INF when neither is on the island.
func stand_at() -> Vector3:
	var e := house_entry()
	if not e.is_empty() and FarmSites.has_site(e):
		var face: Vector3 = HomeLayout.facing(int(e.get("r", 0)))
		var side := Vector3(-face.z, 0, face.x)
		var st: Dictionary = rules()["stand"]
		return HomeLayout.deco_center(e) + face * float(st["along"]) + side * float(st["side"])
	var stalls := HomeLayout.fixtures(Save.d, "stall")
	if stalls.is_empty():
		return Vector3.INF
	var face: Vector3 = HomeLayout.facing(int(stalls[0].get("r", 0)))
	var side := Vector3(-face.z, 0, face.x)
	var ss: Dictionary = rules()["stall_stand"]
	return HomeLayout.deco_center(stalls[0]) + face * float(ss["out"]) + side * float(ss["side"])

## Whether he is at work on the house site (hammering) rather than waiting by the stall.
func at_site() -> bool:
	var e := house_entry()
	return not e.is_empty() and FarmSites.has_site(e)

static func house_entry() -> Dictionary:
	for e in HomeLayout.of(Save.d).get("deco", []):
		if String(e.get("id", "")) == "house":
			return e
	return {}

## Puts him where he belongs (or takes him away when there is no stall). home.gd calls it when the layout
## changes; he walks over from where he was.
func sync() -> void:
	if not FarmUnlocks.gated() or not h.visit.is_empty():
		return
	pos = stand_at()
	if pos.x == INF:
		if is_instance_valid(node):
			node.queue_free()
		node = null
		return
	if not is_instance_valid(node):
		node = HobModel.new()
		h.add_child(node)
		node.position = pos
		node.rotation.y = PI      # (facing out over the farm)

func tick(dt: float) -> void:
	t += dt
	_hammer(dt)
	if not is_instance_valid(node):
		return
	_walk(dt)
	node.tag.visible = not bool(FarmBuilder.state().get("met", false))
	node.mark.visible = FarmBuilder.pending().size() > 0 or chat.offer_due()
	chat.tick(dt)
	_call_out(dt)
	poll_t -= dt
	if poll_t <= 0.0:
		poll_t = 1.0
		if FarmBuilder.toast_due():
			h._toast(String(rules()["toast"]))
			Sfx.play("unlock", node.position, -8.0)

## Walks to where he stands; there he hammers at a site, else waits facing you (or out over the farm).
func _walk(dt: float) -> void:
	var to := Vector3(pos.x - node.position.x, 0, pos.z - node.position.z)
	var step := float(rules()["walk_mps"]) * dt
	if chat.busy():
		return
	if to.length() > step:
		node.position += to.normalized() * step
		node.position.y = absf(sin(t * 9.0)) * 0.05
		node.face_to = pos
		node.pose = "idle"
		return
	node.position = Vector3(pos.x, 0, pos.z)
	node.pose = "hammer" if at_site() else "idle"
	if at_site():
		node.face_to = HomeLayout.deco_center(house_entry())
	elif chat.offer_due() or Vector2(h.ppos.x - pos.x, h.ppos.z - pos.z).length() < FACE_YOU_M:
		node.face_to = h.ppos
	else:
		node.face_to = Vector3.INF

## Until you have met him, and while he has the second Mask for you, he calls you over now and then.
func _call_out(dt: float) -> void:
	call_t -= dt
	var talk: Dictionary = rules()["talk"]
	var met := bool(FarmBuilder.state().get("met", false))
	var line := "" if met or FarmUnlocks.base_mode() else String(talk["call"])      # the base's lead is your Boki
	if chat.offer_due():
		line = String(talk["call_offer"])
	if call_t > 0.0 or chat.busy() or line == "":
		return
	call_t = float(talk["call_every_s"])
	node.shout(line)
	Sfx.play("ping", node.position, -10.0)

# ------------------------------------------------------------------ interaction
## The thing to interact with near the player, or {}: Hob, or a site you can help build.
func find(p2: Vector2) -> Dictionary:
	if not h.visit.is_empty() or not FarmUnlocks.gated():
		return {}
	var reach := float(rules()["talk_reach"])
	if is_instance_valid(node) and p2.distance_to(Vector2(node.position.x, node.position.z)) < reach:
		return {"kind": "hob"}
	if not swing_on():
		return {}
	for e in FarmSites.sites():
		if FarmSites.is_site(e):
			var c := HomeLayout.deco_center(e)
			var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
			if p2.distance_to(Vector2(c.x, c.z)) < maxf(sz.x, sz.y) * 0.5 + 1.8:
				return {"kind": "site", "u": int(e["u"])}
	return {}

func swing_on() -> bool:
	return bool(FarmTutorial.option("player_swing"))

func label(it: Dictionary) -> String:
	if String(it["kind"]) == "hob":
		var n := FarmBuilder.pending().size()
		return "Talk to %s%s" % [FarmBuilder.short_name(), (" (%d new blueprints)" % n) if n > 0 else ""]
	var e := FarmSites.entry(int(it["u"]))
	if e.is_empty():
		return ""
	var need := FarmSites.need_text(e)
	if need != "":
		return need
	var nm := String(HomeLayout.CATALOG[String(e["id"])]["name"]).to_lower()
	return "Hold to hammer the %s (%d/%d)" % [nm, int(e["site"]["got"]), int(e["site"]["need"])]

func use(it: Dictionary) -> void:
	if String(it["kind"]) == "hob":
		talk()
		return
	var e := FarmSites.entry(int(it["u"]))
	if e.is_empty() or not FarmSites.has_site(e) or h.tw.active():
		return
	var need := FarmSites.need_text(e)
	if need != "":
		h._toast(need)
		return
	site_u = int(e["u"])
	h.tw.begin("hammer", HomeLayout.deco_center(e), _land_swing, HunterTool.period("hammer") * 0.4)
	FarmSites.call_helpers(h.hw, e)

## The hammer comes down on the site: one swing of labour. False when the build is done or waiting.
func _land_swing() -> bool:
	var e := FarmSites.entry(site_u)
	if e.is_empty() or not FarmSites.has_site(e):
		return false
	FarmSites.player_swing(h.hw, e)
	FarmTutorial.event("swing")
	h._refresh_top()
	e = FarmSites.entry(site_u)
	if e.is_empty() or not FarmSites.has_site(e):
		return false
	var need := FarmSites.need_text(e)
	if need != "":
		h._toast(need)
		return false
	return true

## Every frame: keeps the hammering going while you hold the key and stay at the site.
func _hammer(dt: float) -> void:
	if h.tw.tool != "hammer":
		site_u = -1
		return
	var e := FarmSites.entry(site_u)
	var at := Vector2(h.ppos.x, h.ppos.z)
	var away := e.is_empty() or at.distance_to(Vector2(h.tw.target.x, h.tw.target.z)) > _reach(e)
	var walking := Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).length() > 0.2
	if away or walking or h.panel_open != "":
		h.tw.stop()
		return
	h.tw.tick(dt, h.tw.held())

## How far from the middle of a site you can keep hammering (the same reach as finding it).
func _reach(e: Dictionary) -> float:
	var sz := HomeLayout.size_of(String(e["id"]), int(e.get("r", 0)))
	return maxf(sz.x, sz.y) * 0.5 + SITE_REACH

## The swing in progress on a site, for its bar: {u, k} with k the share of the swing done (else {}).
func live() -> Dictionary:
	if h.tw.tool != "hammer" or site_u < 0:
		return {}
	var period := HunterTool.period("hammer")
	return {"u": site_u, "k": clampf(h.tw.swing_t / (period * HunterTool.IMPACT), 0.0, 1.0)}

## Talks to him face to face (HobTalk).
func talk() -> void:
	chat.start()
