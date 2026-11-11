class_name CarryArrival
extends RefCounted
## A Boki you claimed in a match and carried out comes home as an event (DECISIONS "carry 2 in, 1 extra out",
## GARDEN.md section 4): it stands at the arrival point, the residents come to look (ComeLook), it keeps one
## memory line, and a short card says where it came from and where it went. One in the Burrow (the garden's
## out-cap was full) gets the card too, and the card says so.

const ARRIVE_OFFSET := Vector3(1.8, 0.0, 1.2)      # m from where you arrive: close enough to see it come
const CARD_W := 460.0                              # px

## uids of Boki carried home since the garden last looked (Game.apply_result adds, Home's welcome takes).
static var pending: Array = []

## Memory line: 'came home from <map> with <Hunter>' (where = the origin's "where": map, hunter).
static func line(where: Dictionary) -> String:
	var map := String(where.get("map", ""))
	var s := "came home from %s" % (map if map != "" else "the islands")
	var hunter := String(where.get("hunter", ""))
	return s if hunter == "" else "%s with %s" % [s, hunter]

## Was this uid carried home just now? Forgets it.
static func take(uid: String) -> bool:
	var i := pending.find(uid)
	if i >= 0:
		pending.remove_at(i)
	return i >= 0

## The card's two lines: where it came from, and where it went.
static func card_lines(rec: Dictionary) -> Array:
	var from := line(rec.get("origin", {}).get("where", {}))
	var nm := String(rec["name"])
	if KinBox.is_boxed(rec):
		var full := "The garden already has %d out, so %s went to the Burrow." % [KinBox.farm_cap(), nm]
		return ["%s %s." % [nm, from], full]
	return ["%s %s." % [nm, from], "It is out in the garden, and the others are coming to look."]

## The garden's welcome: a Boki just carried home that is out stands at the arrival point; one that went to the
## Burrow has no body here, so its card is all there is. Each gets its card.
static func arrive(h, arrived: Array) -> void:
	for k in arrived:
		if take(String(k["rec"]["uid"])):
			place(h, k)
			show_card(h, k["rec"])
	for uid in pending.duplicate():
		var rec := Save.kin(String(uid))
		if KinBox.is_boxed(rec) and take(String(uid)):
			show_card(h, rec)

## Stands the Boki at the arrival point (where you appear), clear of the others.
static func place(h, k: Dictionary) -> void:
	var taken: Array = h.kins.map(func(o): return o["pos"])
	var at: Vector3 = h.world.free_spot_near(h.ppos + ARRIVE_OFFSET, taken, 1.3)
	k["pos"] = at
	(k["node"] as Node3D).position = at
	k["goal"] = Vector3.INF

## The card, once nothing else is open.
static func show_card(h, rec: Dictionary) -> void:
	h.arrivals.add(func():
		var v: VBoxContainer = h._new_panel("%s came home" % rec["name"], CARD_W)
		for l in card_lines(rec):
			v.add_child(UI.label(String(l), 15, UI.INK)))
