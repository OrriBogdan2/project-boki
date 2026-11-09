class_name KinWants
extends RefCounted
## What a Boki wants, readable at a glance. The most urgent need floats over it as one thought
## bubble with an icon (food bowl, Zzz, bath, ball or heart); the more urgent, the bigger and
## livelier. A few bubbles at most show at once, a Boki that gets what it wanted answers with a
## little heart, and walking up to it names the want and what the interact key does about it.

## A need under this is a want (matches Care.want).
const WANT_BELOW := 38.0
## Under this the want is urgent: a big, pulsing bubble.
const URGENT_BELOW := 18.0
## At most this many bubbles show at once.
const MAX_SHOWN := 3
## Bubbles closer together than this (tiles) don't both show.
const SPACING := 1.8
## A mild want only shows this close to you (tiles).
const MILD_RANGE := 9.0
const ICONS := ["bowl", "zzz", "bath", "ball", "heart"]

## 0 when nothing is wanted, up to 1 when a need is empty.
static func urgency(rec: Dictionary) -> float:
	var w := Care.want(rec)
	if w == "":
		return 0.0
	return clampf((WANT_BELOW - Care.need(rec, w)) / WANT_BELOW, 0.05, 1.0)

## The icon for what the Boki wants ("" for nothing). A low mood is a ball for a Boki that likes
## fetch and a heart for the rest.
static func icon(rec: Dictionary) -> String:
	match Care.want(rec):
		"food": return "bowl"
		"energy": return "zzz"
		"clean": return "bath"
		"joy": return "ball" if String(rec["likes"]["play"]) == "fetch" else "heart"
	return ""

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

## Every frame: shows the most urgent wants, hides the rest, and plays the happy answer.
static func update(home: Node, dt: float, now: float) -> void:
	if FarmUnlocks.base_mode():
		KinMood.update(home, dt, now)
		return
	var cands: Array = []
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var w := Care.want(rec) if home.visit.is_empty() else ""
		_relief(home, k, w)
		if w != "" and free_to_show(k):
			cands.append(k)
	cands.sort_custom(func(a, b): return urgency(a["rec"]) > urgency(b["rec"]))
	var shown: Array = []
	for k in cands:
		if _may_show(k, shown, home.ppos):
			shown.append(k)
	for k in home.kins:
		_pose(home, k, shown.has(k), dt, now)

static func free_to_show(k: Dictionary) -> bool:
	if k.has("indoors") or k.has("fetch") or k.has("bath") or k.get("busy", false):
		return false
	for busy_for in ["nap_t", "say_t", "hold_t"]:
		if float(k.get(busy_for, 0.0)) > 0.0:
			return false
	return true

static func _may_show(k: Dictionary, shown: Array, player: Vector3) -> bool:
	if shown.size() >= MAX_SHOWN:
		return false
	var at: Vector3 = k["pos"]
	if urgency(k["rec"]) < 0.5 and Vector2(at.x - player.x, at.z - player.z).length() > MILD_RANGE:
		return false
	for o in shown:
		if Vector2(at.x - o["pos"].x, at.z - o["pos"].z).length() < SPACING:
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

static func _pose(home: Node, k: Dictionary, shown: bool, dt: float, now: float) -> void:
	var bub: Node3D = k.get("bubble")
	if bub == null or not is_instance_valid(bub):
		bub = bubble()
		(k["node"] as Node3D).add_child(bub)
		k["bubble"] = bub
		k["bubble_k"] = 0.0
	var goal := 0.0
	if shown:
		var u := urgency(k["rec"])
		goal = 1.1 + u
		if Care.need(k["rec"], Care.want(k["rec"])) < URGENT_BELOW:
			goal *= 1.0 + 0.1 * sin(now * 7.0)
	var grow := lerpf(float(k["bubble_k"]), goal, 1.0 - exp(-9.0 * dt))
	k["bubble_k"] = grow
	bub.visible = grow > 0.03
	if not bub.visible:
		return
	var want_icon := icon(k["rec"])
	for nm in ICONS:
		(bub.get_node(nm) as Node3D).visible = nm == want_icon
	bub.position = Vector3(0.25, 1.5 + sin(now * 2.2) * 0.04, 0)
	bub.look_at(home.cam.global_position, Vector3.UP)
	bub.scale = Vector3.ONE * grow

## The bubble: a white cloud with a tail and one child per icon (only the wanted one is shown).
static func bubble() -> Node3D:
	var root := Node3D.new()
	var white := Models.toon(Color("f6f2ea"), true)
	Models.part(root, Models.sphere(0.22, 14), white, Vector3.ZERO, Vector3(1.15, 0.95, 0.5))
	Models.part(root, Models.sphere(0.06, 8), white, Vector3(-0.17, -0.24, 0))
	Models.part(root, Models.sphere(0.035, 6), white, Vector3(-0.25, -0.34, 0))
	bowl(root)
	zzz(root)
	_bath(root)
	ball(root)
	heart(root)
	return root

static func icon_node(root: Node3D, nm: String) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	root.add_child(n)
	return n

static func bowl(root: Node3D) -> void:
	var n := icon_node(root, "bowl")
	Models.part(n, Models.cyl(0.11, 0.07, 0.07, 12), Models.toon(Color("c9604a"), false), Vector3(0, -0.06, -0.1))
	for x in [-0.05, 0.0, 0.05]:
		Models.part(n, Models.sphere(0.04, 6), Models.toon(Color("c8a26a"), false, 0.2), Vector3(x, 0.0, -0.1))

static func zzz(root: Node3D) -> void:
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

static func _bath(root: Node3D) -> void:
	var n := icon_node(root, "bath")
	var blue := Models.toon(Color("5ab8f0"), false, 0.4)
	Models.part(n, Models.sphere(0.07, 10), blue, Vector3(0, -0.03, -0.1), Vector3(1, 1.25, 1))
	Models.part(n, Models.cyl(0.0, 0.05, 0.08, 8), blue, Vector3(0, 0.08, -0.1))
	for b in [Vector3(-0.1, 0.06, -0.1), Vector3(0.1, 0.0, -0.1)]:
		Models.part(n, Models.sphere(0.03, 6), Models.toon(Color("e8f6ff"), false, 0.3), b)

static func ball(root: Node3D) -> void:
	var n := icon_node(root, "ball")
	Models.part(n, Models.sphere(0.09, 10), Models.toon(Color("ff6a5a"), false, 0.2), Vector3(0, 0, -0.1))
	Models.part(n, Models.cyl(0.091, 0.091, 0.025, 12), Models.toon(Color("f6f2ea"), false), Vector3(0, 0, -0.1),
		Vector3.ONE, Vector3(0, 0, 0.5))

static func heart(root: Node3D) -> void:
	var lbl := Label3D.new()
	lbl.name = "heart"
	lbl.text = "♥"
	lbl.font = UI.big
	lbl.font_size = 56
	lbl.pixel_size = 0.0065
	lbl.modulate = Color("ff6a8a")
	lbl.outline_size = 0
	lbl.position = Vector3(0, 0, -0.12)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)
