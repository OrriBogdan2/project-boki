class_name KinWants
extends RefCounted
## What a Boki wants, readable at a glance: the icons (bowl, Zzz, ball, heart, rain cloud, lilac
## heart) that KinMood floats over its head when its mood changes, a little heart and hop when it
## gets what it wanted, and the prompt that names the want and what the interact key does about it.

## A need under this is a want (matches Care.want).
const WANT_BELOW := 38.0
const ICONS := ["bowl", "zzz", "ball", "heart", "cloud", "miss"]

## The best food you have for it: its favourite first, then anything it doesn't hate. "" for none.
static func best_food(rec: Dictionary) -> String:
	var likes: Dictionary = rec["likes"]
	var have := func(f: String) -> int:
		return int(Save.d["crops"].get(f, 0)) if Data.CROPS.has(f) else int(Save.d["items"].get(f, 0))
	if have.call(String(likes["food"])) > 0:
		return String(likes["food"])
	for f in Data.CROPS.keys() + Care.FOODS.keys():
		if f != likes["hates"] and have.call(String(f)) > 0:
			return String(f)
	return ""

## What the interact key does for this Boki: "feed", "nap", "bath", "brush" (no pond) or "pet".
static func action(rec: Dictionary, pond: bool) -> String:
	match Care.want(rec):
		"food": return "feed" if best_food(rec) != "" else "pet"
		"energy": return "nap"
		"clean": return "bath" if pond else "brush"
	return "pet"

## The one-line prompt when you stand next to it.
static func line(rec: Dictionary, pond: bool) -> String:
	var nm := String(rec["name"])
	match Care.want(rec):
		"food":
			if best_food(rec) == "":
				return "%s is hungry: you have no food" % nm
			return "%s is hungry: give food" % nm
		"energy": return "%s is sleepy: tuck it in" % nm
		"clean": return "%s is dirty: %s" % [nm, "give a bath" if pond else "brush it"]
		"joy": return "%s is lonely: pet it" % nm
	return "Pet " + nm

## Every frame: the happy answer to a met want, then the mood icons (KinMood).
static func update(home: Node, dt: float, now: float) -> void:
	for k in home.kins:
		_relief(home, k, Care.want(k["rec"]) if home.visit.is_empty() else "")
	KinMood.update(home, dt, now)

static func free_to_show(k: Dictionary) -> bool:
	if k.has("indoors") or k.has("fetch") or k.has("bath") or k.get("busy", false):
		return false
	for busy_for in ["nap_t", "say_t", "hold_t"]:
		if float(k.get(busy_for, 0.0)) > 0.0:
			return false
	return true

## Gets what it wanted: a heart and a little hop.
static func _relief(home: Node, k: Dictionary, w: String) -> void:
	var before := String(k.get("want_was", ""))
	k["want_was"] = w
	if before == "" or w != "" or k.has("indoors") or not home.visit.is_empty():
		return
	k["joy_t"] = 0.9
	home._emote(k, "♥", true)
	home.fx.burst(k["pos"] + Vector3(0, 0.9, 0), Color("ff8fb0"), 8, 1.6)

## The bubble: a white cloud with a tail and one child per icon (only the current one is shown).
static func bubble() -> Node3D:
	var root := Node3D.new()
	var white := Models.toon(Color("f6f2ea"), true)
	Models.part(root, Models.sphere(0.22, 14), white, Vector3.ZERO, Vector3(1.15, 0.95, 0.5))
	Models.part(root, Models.sphere(0.06, 8), white, Vector3(-0.17, -0.24, 0))
	Models.part(root, Models.sphere(0.035, 6), white, Vector3(-0.25, -0.34, 0))
	_bowl(root)
	_zzz(root)
	_ball(root)
	_heart(root, "heart", Color("ff6a8a"))
	_cloud(root)
	_heart(root, "miss", Color("b79cff"))
	return root

static func _node(root: Node3D, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	root.add_child(n)
	return n

static func _bowl(root: Node3D) -> void:
	var n := _node(root, "bowl")
	Models.part(n, Models.cyl(0.11, 0.07, 0.07, 12), Models.toon(Color("c9604a"), false), Vector3(0, -0.06, -0.1))
	for x in [-0.05, 0.0, 0.05]:
		Models.part(n, Models.sphere(0.04, 6), Models.toon(Color("c8a26a"), false, 0.2), Vector3(x, 0.0, -0.1))

static func _zzz(root: Node3D) -> void:
	var lbl := Label3D.new()
	lbl.name = "zzz"
	lbl.text = "Zzz"
	lbl.font = UI.big
	lbl.font_size = 40
	lbl.pixel_size = 0.0065
	lbl.modulate = Color("5a7ae0")
	lbl.outline_size = 0
	lbl.position = Vector3(0, 0, -0.12)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)

static func _ball(root: Node3D) -> void:
	var n := _node(root, "ball")
	Models.part(n, Models.sphere(0.09, 10), Models.toon(Color("ff6a5a"), false, 0.2), Vector3(0, 0, -0.1))
	Models.part(n, Models.cyl(0.091, 0.091, 0.025, 12), Models.toon(Color("f6f2ea"), false), Vector3(0, 0, -0.1),
		Vector3.ONE, Vector3(0, 0, 0.5))

static func _heart(root: Node3D, nm: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.name = nm
	lbl.text = "♥"
	lbl.font = UI.big
	lbl.font_size = 56
	lbl.pixel_size = 0.0065
	lbl.modulate = col
	lbl.outline_size = 0
	lbl.position = Vector3(0, 0, -0.12)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)

## Sulking: a small grey rain cloud with two drops.
static func _cloud(root: Node3D) -> void:
	var n := _node(root, "cloud")
	var grey := Models.toon(Color("9aa0ad"), false, 0.2)
	Models.part(n, Models.sphere(0.07, 10), grey, Vector3(-0.05, 0.03, -0.1))
	Models.part(n, Models.sphere(0.085, 10), grey, Vector3(0.05, 0.04, -0.1))
	Models.part(n, Models.sphere(0.06, 10), grey, Vector3(0.0, 0.0, -0.1), Vector3(1.8, 0.7, 1))
	var rain := Models.toon(UI.INFO, false, 0.4)
	for x in [-0.045, 0.045]:
		Models.part(n, Models.sphere(0.022, 6), rain, Vector3(x, -0.1, -0.1), Vector3(1, 1.5, 1))
