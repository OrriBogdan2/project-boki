class_name KinWants
extends RefCounted
## What a Boki wants, readable at a glance. The most urgent need floats over it as one thought
## bubble with an icon (food bowl, Zzz, bath, ball or heart, a sad face when its mood is very low); the
## more urgent, the bigger and livelier. A few bubbles at most show at once, a Boki that gets what it
## wanted answers with a little heart, and walking up to it names the want and what the interact key
## does about it. A content Boki you walk up to smiles at you for a moment (a smaller, calm bubble).

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
const ICONS := ["bowl", "zzz", "bath", "ball", "heart", "sad", "happy"]
## Every need at least this (points of 100) and it is content: it may smile at you.
const HAPPY_ABOVE := 70.0
## It smiles when you come this close (tiles): near enough that you see its face at the farm camera.
const HAPPY_RANGE := 4.0
## How long the smile stays up (s).
const HAPPY_S := 2.5
## Before the same Boki smiles at you again (s), so a crowd of happy Boki is not a field of bubbles.
const HAPPY_AGAIN_S := 40.0
## The smile's size against a want's (a mild want is 1.1 and up).
const HAPPY_SIZE := 0.85

## 0 when nothing is wanted, up to 1 when a need is empty.
static func urgency(rec: Dictionary) -> float:
	var w := Care.want(rec)
	if w == "":
		return 0.0
	return clampf((WANT_BELOW - Care.need(rec, w)) / WANT_BELOW, 0.05, 1.0)

## The icon for what the Boki wants ("" for nothing). A low mood is a ball for a Boki that likes
## fetch and a heart for the rest; a very low one (urgent) is a sad face.
static func icon(rec: Dictionary) -> String:
	match Care.want(rec):
		"food": return "bowl"
		"energy": return "zzz"
		"clean": return "bath"
		"joy":
			if Care.need(rec, "joy") < URGENT_BELOW:
				return "sad"
			return "ball" if String(rec["likes"]["play"]) == "fetch" else "heart"
	return ""

## True when it wants nothing and every need is at least HAPPY_ABOVE.
static func content(rec: Dictionary) -> bool:
	if Care.want(rec) != "":
		return false
	for n in Care.NEEDS:
		if Care.need(rec, n) < HAPPY_ABOVE:
			return false
	return true

## The best food you have for it: its favourite first, then anything it doesn't hate. "" for none.
static func best_food(rec: Dictionary) -> String:
	var likes: Dictionary = rec["likes"]
	var have := func(f: String) -> int:
		return int(Save.d["crops"].get(f, 0)) if Data.CROPS.has(f) else int(Save.d["items"].get(f, 0))
	if Care.ailing(rec):
		# weak or sick: the snack crop is the medicine
		for f in Data.CROPS:
			if Data.CROPS[f]["use"] == "snack" and f != likes["hates"] and have.call(String(f)) > 0:
				return String(f)
	if have.call(String(likes["food"])) > 0:
		return String(likes["food"])
	for f in Data.CROPS.keys() + Care.foods_v.keys():
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
		"joy": return ("%s is sad: pet it" if Care.need(rec, "joy") < URGENT_BELOW else "%s is lonely: pet it") % nm
	return "Pet " + nm

## Every frame: shows the most urgent wants, hides the rest, and plays the happy answer.
static func update(home: Node, dt: float, now: float) -> void:
	var cands: Array = []
	for k in home.kins:
		var rec: Dictionary = k["rec"]
		var w := Care.want(rec) if home.visit.is_empty() else ""
		_relief(home, k, w)
		if not k.has("indoors"):
			HomeVoice.sulk_edge(k, w)
		if w != "" and _free_to_show(k):
			cands.append(k)
	cands.sort_custom(func(a, b): return urgency(a["rec"]) > urgency(b["rec"]))
	var shown: Array = []
	for k in cands:
		if _may_show(k, shown, home.ppos):
			shown.append(k)
	_smiles(home, dt, shown)
	for k in home.kins:
		_pose(home, k, shown.has(k), dt, now)

## A content Boki you walk up to smiles once (HAPPY_S), then not again for HAPPY_AGAIN_S. Wants come first.
static func _smiles(home: Node, dt: float, shown: Array) -> void:
	for k in home.kins:
		k["smile_t"] = maxf(float(k.get("smile_t", 0.0)) - dt, 0.0)
		k["smile_again"] = maxf(float(k.get("smile_again", 0.0)) - dt, 0.0)
		if not home.visit.is_empty() or not _free_to_show(k) or not content(k["rec"]):
			k["smile_t"] = 0.0
			continue
		var at: Vector3 = k["pos"]
		var near := Vector2(at.x - home.ppos.x, at.z - home.ppos.z).length() <= HAPPY_RANGE
		if float(k["smile_t"]) <= 0.0 and near and float(k["smile_again"]) <= 0.0:
			k["smile_t"] = HAPPY_S
			k["smile_again"] = HAPPY_AGAIN_S
		if float(k["smile_t"]) > 0.0 and _may_show(k, shown, home.ppos):
			shown.append(k)

static func _free_to_show(k: Dictionary) -> bool:
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
	HomeVoice.say(k["rec"], "happy", k["pos"])

static func _pose(home: Node, k: Dictionary, shown: bool, dt: float, now: float) -> void:
	var bub: Node3D = k.get("bubble")
	if bub == null or not is_instance_valid(bub):
		bub = bubble()
		(k["node"] as Node3D).add_child(bub)
		k["bubble"] = bub
		k["bubble_k"] = 0.0
	var goal := 0.0
	var want_icon := icon(k["rec"])
	if shown and want_icon == "":
		want_icon = "happy"
		goal = HAPPY_SIZE
	elif shown:
		var u := urgency(k["rec"])
		goal = 1.1 + u
		if Care.need(k["rec"], Care.want(k["rec"])) < URGENT_BELOW:
			goal *= 1.0 + 0.1 * sin(now * 7.0)
	k["bubble_icon"] = want_icon
	var grow := lerpf(float(k["bubble_k"]), goal, 1.0 - exp(-9.0 * dt))
	k["bubble_k"] = grow
	bub.visible = grow > 0.03
	if not bub.visible:
		return
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
	_bowl(root)
	_zzz(root)
	_bath(root)
	_ball(root)
	_heart(root)
	_face(root, "sad", Color("7aa6e8"), -1.0)
	_face(root, "happy", Color("ffd35a"), 1.0)
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

static func _bath(root: Node3D) -> void:
	var n := _node(root, "bath")
	var blue := Models.toon(Color("5ab8f0"), false, 0.4)
	Models.part(n, Models.sphere(0.07, 10), blue, Vector3(0, -0.03, -0.1), Vector3(1, 1.25, 1))
	Models.part(n, Models.cyl(0.0, 0.05, 0.08, 8), blue, Vector3(0, 0.08, -0.1))
	for b in [Vector3(-0.1, 0.06, -0.1), Vector3(0.1, 0.0, -0.1)]:
		Models.part(n, Models.sphere(0.03, 6), Models.toon(Color("e8f6ff"), false, 0.3), b)

static func _ball(root: Node3D) -> void:
	var n := _node(root, "ball")
	Models.part(n, Models.sphere(0.09, 10), Models.toon(Color("ff6a5a"), false, 0.2), Vector3(0, 0, -0.1))
	Models.part(n, Models.cyl(0.091, 0.091, 0.025, 12), Models.toon(Color("f6f2ea"), false), Vector3(0, 0, -0.1),
		Vector3.ONE, Vector3(0, 0, 0.5))

static func _heart(root: Node3D) -> void:
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

## A round face: two eyes and a mouth of dots, curved up (smile 1) or down (-1); the sad one has a tear.
static func _face(root: Node3D, nm: String, col: Color, smile: float) -> void:
	var n := _node(root, nm)
	var ink := Models.toon(Color("3a2a2a"), false)
	const FRONT := -0.19  # (the face's front, toward the camera: the bubble looks at it down -z)
	Models.part(n, Models.sphere(0.1, 12), Models.toon(col, false, 0.2), Vector3(0, 0, -0.1))
	for x in [-0.035, 0.035]:
		Models.part(n, Models.sphere(0.014, 6), ink, Vector3(x, 0.025, FRONT))
	for i in 5:
		var x := -0.04 + 0.02 * i
		var y := -0.035 + smile * (0.03 * pow(x / 0.04, 2.0) - 0.012)
		Models.part(n, Models.sphere(0.009, 5), ink, Vector3(x, y, FRONT))
	if smile < 0.0:
		Models.part(n, Models.sphere(0.016, 6), Models.toon(Color("e8f6ff"), false, 0.3), Vector3(0.055, -0.005, FRONT),
			Vector3(1, 1.4, 1))
