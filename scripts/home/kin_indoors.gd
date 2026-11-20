class_name KinIndoors
extends RefCounted
## Boki napping inside the house, and where every Boki that isn't out on the farm is. A Boki only
## goes in when there is a house, naps for a short while, and comes out early when you are around
## (walk up to the door, or whistle). With no house it curls up outside instead. A small sleeping
## badge by the door and the line in the Boki list say who is inside.

## Seconds of a nap by day and by night (min, max).
const NAP_DAY := Vector2(10.0, 22.0)
const NAP_NIGHT := Vector2(22.0, 40.0)
## You are this close to the door (tiles): a Boki that has settled comes out to see you.
const DOOR_REACH := 2.4
## You are this close to the house (tiles): the nap runs this many times faster.
const NEAR_HOUSE := 8.0
const NEAR_SPEEDUP := 4.0
## Seconds a Boki stays in no matter what, so it never pops straight back out.
const SETTLE := 1.2
## Seconds of an outdoor nap, when there is no house to go into.
const YARD_NAP := Vector2(14.0, 26.0)
const BADGE := "InsideBadge"

## Who is inside right now (uid -> seconds left), for the Boki list.
static var inside := {}

## Is there a house to go into? (a farm-start island has none until you place one)
static func has_house(spots: Dictionary) -> bool:
	return spots.has("house") and (spots["house"] as Vector3).x > -100.0

## How long a nap lasts, in seconds.
static func nap_secs(night: bool) -> float:
	var span := NAP_NIGHT if night else NAP_DAY
	return randf_range(span.x, span.y)

## Curls the Boki up where it stands (used when there is no house).
static func nap_outside(k: Dictionary) -> void:
	k["nap_t"] = randf_range(YARD_NAP.x, YARD_NAP.y)
	k["slept"] = 0.0
	k["z_t"] = 0.5
	k["goal"] = k["pos"]
	Sfx.play("boki_sleep", k["pos"], -10.0)

## It goes in for a nap.
static func enter(k: Dictionary, night: bool) -> void:
	k["indoors"] = nap_secs(night)
	k["in_t"] = 0.0
	Sfx.play("boki_sleep", k["pos"], -10.0)
	inside[String(k["rec"]["uid"])] = k["indoors"]

## Counts a nap down. True when the Boki should come out: its time is up, you walked up to the
## door, or the house is gone.
static func step(k: Dictionary, dt: float, player: Vector3, door: Vector3, house_here: bool) -> bool:
	var near := Vector2(player.x - door.x, player.z - door.z).length()
	var speed := NEAR_SPEEDUP if near < NEAR_HOUSE else 1.0
	k["in_t"] = float(k.get("in_t", 0.0)) + dt
	k["indoors"] = float(k["indoors"]) - dt * speed
	inside[String(k["rec"]["uid"])] = maxf(0.0, float(k["indoors"]))
	if not house_here or float(k["indoors"]) <= 0.0:
		return true
	return near < DOOR_REACH and float(k["in_t"]) > SETTLE

## Forgets a Boki that has come out.
static func left(k: Dictionary) -> void:
	inside.erase(String(k["rec"]["uid"]))
	k.erase("in_t")

## The line the Boki list shows when a Boki isn't out on the farm ("" when it is).
static func status(rec: Dictionary) -> String:
	if KinBox.is_boxed(rec):
		return "In the Burrow"
	var uid := String(rec.get("uid", ""))
	if inside.has(uid):
		return "Inside, out in %ds" % ceili(float(inside[uid]))
	return ""

## The names of the Boki napping inside, for the badge.
static func names(kins: Array) -> Array:
	var out: Array = []
	for k in kins:
		if k.has("indoors"):
			out.append(String(k["rec"]["name"]))
	return out

## The sleeping badge by the door: a small "Zz" with a name, and the full sentence when you are close.
static func badge(host: Node3D, door: Vector3, who: Array, player: Vector3) -> void:
	var lbl := host.get_node_or_null(BADGE) as Label3D
	if who.is_empty():
		if lbl:
			lbl.visible = false
		return
	if lbl == null:
		lbl = Label3D.new()
		lbl.name = BADGE
		lbl.font = UI.big
		lbl.font_size = 40
		lbl.pixel_size = 0.0075
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0.1, 0.1, 0.2, 0.85)
		lbl.modulate = Color("cdd8ff")
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		host.add_child(lbl)
	var near := Vector2(player.x - door.x, player.z - door.z).length() < NEAR_HOUSE
	lbl.text = _sentence(who) if near else _short(who)
	lbl.position = door + Vector3(0, 2.3, 0)
	lbl.visible = true

static func _sentence(who: Array) -> String:
	if who.size() == 1:
		return "%s is napping inside" % who[0]
	return "%s and %d more are napping inside" % [who[0], who.size() - 1]

static func _short(who: Array) -> String:
	if who.size() == 1:
		return "Zz " + String(who[0])
	return "Zz %s +%d" % [who[0], who.size() - 1]
