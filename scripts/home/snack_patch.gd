class_name SnackPatch
extends RefCounted
## The garden's one snack patch (briefs/design/GARDEN.md section 10 question 1, default). With base_mode on, a save has
## exactly one patch (granted to storage if there is none, put down in the Garden tab). It ripens four element snacks
## on a timer (content/rules/snack_patch.json) and walking over it picks them up for the pantry, to feed the lean
## foods. Never sold, no seeds, no watering. The timer is the deco entry's "t" (unix seconds of the last pick).

const ID := "snack_patch"

var h                                    # the Home screen
var _look_t := 0.0
var _ripe := false

func _init(home) -> void:
	h = home

static func rules() -> Dictionary:
	return Content.rules("snack_patch")

## base_mode saves keep one patch: a missing one waits in storage to be put down.
static func grant(d: Dictionary) -> void:
	if FarmUnlocks.base_mode() and HomeLayout.count_of(ID, d) == 0:
		HomeLayout.of(d)["inv"][ID] = 1

## The placed patch's deco entry, or {}.
static func entry(d: Dictionary) -> Dictionary:
	for e in HomeLayout.of(d).get("deco", []):
		if String(e.get("id", "")) == ID:
			return e
	return {}

static func ripe(e: Dictionary, now: float) -> bool:
	return not e.is_empty() and now - float(e.get("t", now)) >= float(rules()["grow_secs"])

## Picks the ripe snacks into the pantry. Returns the snack ids picked ([] when not ripe).
static func harvest(d: Dictionary, now: float) -> Array:
	var e := entry(d)
	if not ripe(e, now):
		return []
	e["t"] = now
	var got: Array = (rules()["snacks"] as Array).duplicate()
	for s in got:
		d["crops"][s] = int(d["crops"].get(s, 0)) + 1
	return got

## Part of the deco signature, so the model changes when it ripens.
static func sig(e: Dictionary) -> String:
	return "r" if String(e["id"]) == ID and ripe(e, Time.get_unix_time_from_system()) else ""

## Four little beds, each with its snack's colour: sprouts while growing, fat berries once ripe.
static func model(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	var is_ripe := ripe(e, Time.get_unix_time_from_system())
	Models.part(n, Models.box(1.9, 0.08, 1.9), Models.toon(Color("7a5a3a"), false), Vector3(0, 0.04, 0))
	var snacks: Array = rules()["snacks"]
	for i in snacks.size():
		var at := Vector3((i % 2) * 0.9 - 0.45, 0, floori(i * 0.5) * 0.9 - 0.45)
		var leaf := Models.toon(Color("5f9a45"))
		Models.part(n, Models.sphere(0.2, 8), leaf, at + Vector3(0, 0.22, 0), Vector3(1, 0.7, 1))
		if is_ripe:
			var col: Color = Data.CROPS[snacks[i]]["color"]
			Models.part(n, Models.sphere(0.13, 8), Models.toon(col), at + Vector3(0, 0.5, 0))
	return n

func tick(d: float) -> void:
	_look_t -= d
	if _look_t > 0.0 or not FarmUnlocks.base_mode() or not h.visit.is_empty():
		return
	_look_t = 0.2
	var now := Time.get_unix_time_from_system()
	var e := entry(Save.d)
	if not e.is_empty() and not e.has("t"):
		e["t"] = now          # the timer starts when it is put down
	var now_ripe := ripe(e, now)
	if now_ripe != _ripe:
		_ripe = now_ripe
		h.hb.apply(false)          # redraws the patch in its new stage
	if now_ripe and _on_it(e):
		var got := harvest(Save.d, now)
		_ripe = false
		h.hb.apply(false)
		h._toast("Picked: " + ", ".join(got.map(func(s): return String(Data.CROPS[s]["name"]))))
		h.fx.burst(HomeLayout.deco_center(e) + Vector3(0, 0.5, 0), Color("ffe08a"), 10, 1.5, 0.4)

func _on_it(e: Dictionary) -> bool:
	var c := HomeLayout.deco_center(e)
	var sz := HomeLayout.size_of(ID, int(e.get("r", 0)))
	var r := float(rules()["reach"])
	return absf(h.ppos.x - c.x) <= sz.x * 0.5 + r and absf(h.ppos.z - c.z) <= sz.y * 0.5 + r
