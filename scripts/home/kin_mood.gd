class_name KinMood
extends RefCounted
## The mood bubble over each Boki at the base (farm_build.json base_mode only; KinWants shows the
## plain wants otherwise). One small dark bubble with one icon for the strongest current feeling:
## hungry, sleepy, wants to play, happy (just fed or won), sulking (lost a race) or cross (a rival
## close by). It pops up when the feeling changes, fades after SHOW_S, and comes back while you
## hover the Boki or stand near it. No numbers. Only at home: matches never build one.

const SHOW_S := 3.0                  # s a new feeling stays up before it fades
const NEAR := 2.6                    # tiles: standing this close to a Boki shows its feeling again
const RIVAL_NEAR := 4.0              # tiles: a rival this close makes a Boki cross
const RIVAL_AT := -0.4               # rec["bonds"][uid] at or below this: rivals (-1..1)
const EVENT_S := 6.0                 # s a win or a loss colours the mood
const SCAN_S := 0.25                 # s between feeling checks (not every frame)
const NEEDS := {"food": "hungry", "energy": "sleepy", "joy": "play"}
## Rim colour per feeling (Void & Masks palette, ui.gd).
const RIM := {"hungry": UI.ACCENT, "sleepy": UI.INFO, "play": UI.TEAL, "happy": UI.GOLD,
	"sulk": UI.MUTED, "cross": UI.BAD}
const DISC := Color("1c1824")        # bubble face: a warm night, like UI.SURFACE but opaque
const ICON_Z := -0.1                 # icons float just in front of the face (toward the camera)

## A win or a loss from a Boki minigame: the bubble answers with happy or sulking for a while.
static func react(k: Dictionary, won: bool) -> void:
	k["mood_ev"] = "happy" if won else "sulk"
	k["mood_ev_t"] = EVENT_S

## What a Boki feels right now ("" for nothing in particular).
static func feeling(home: Node, k: Dictionary) -> String:
	if float(k.get("mood_ev_t", 0.0)) > 0.0:
		return String(k["mood_ev"])
	if _rival_near(home, k):
		return "cross"
	var low := KinWants.WANT_BELOW
	var out := ""
	for n in NEEDS:
		var v := Care.need(k["rec"], n)
		if v < low:
			low = v
			out = NEEDS[n]
	return out

static func _rival_near(home: Node, k: Dictionary) -> bool:
	var bonds: Dictionary = k["rec"].get("bonds", {})
	if bonds.is_empty():
		return false
	var at: Vector3 = k["pos"]
	for o in home.kins:
		if not is_same(o, k) and float(bonds.get(String(o["rec"]["uid"]), 0.0)) <= RIVAL_AT \
				and Vector2(at.x - o["pos"].x, at.z - o["pos"].z).length() < RIVAL_NEAR:
			return true
	return false

## Every frame: tracks each Boki's feeling and shows, fades or hides its bubble.
static func update(home: Node, dt: float, now: float) -> void:
	for k in home.kins:
		var on_show: bool = home.visit.is_empty() and KinWants.free_to_show(k)
		if on_show:
			_track(home, k, dt)
		_pose(home, k, on_show and _wanted(home, k), dt, now)

## Re-reads the feeling every SCAN_S; a changed feeling restarts the SHOW_S timer.
static func _track(home: Node, k: Dictionary, dt: float) -> void:
	k["mood_ev_t"] = maxf(float(k.get("mood_ev_t", 0.0)) - dt, 0.0)
	k["mood_show"] = maxf(float(k.get("mood_show", 0.0)) - dt, 0.0)
	k["mood_scan"] = float(k.get("mood_scan", 0.0)) - dt
	if float(k["mood_scan"]) > 0.0:
		return
	k["mood_scan"] = SCAN_S
	var now_feel := feeling(home, k)
	var before := String(k.get("mood", ""))
	k["mood"] = now_feel
	if now_feel == before:
		return
	k["mood_show"] = SHOW_S
	if now_feel == "" and before in NEEDS.values():
		react(k, true)
		k["mood"] = "happy"

static func _wanted(home: Node, k: Dictionary) -> bool:
	if String(k.get("mood", "")) == "":
		return false
	if float(k.get("mood_show", 0.0)) > 0.0 or is_same(home.hover_k, k):
		return true
	var at: Vector3 = k["pos"]
	return Vector2(at.x - home.ppos.x, at.z - home.ppos.z).length() < NEAR

static func _pose(home: Node, k: Dictionary, shown: bool, dt: float, now: float) -> void:
	var bub: Node3D = k.get("mood_bub")
	if bub == null or not is_instance_valid(bub):
		bub = bubble()
		(k["node"] as Node3D).add_child(bub)
		k["mood_bub"] = bub
		k["mood_k"] = 0.0
	var grow := lerpf(float(k["mood_k"]), 1.0 if shown else 0.0, 1.0 - exp(-9.0 * dt))
	k["mood_k"] = grow
	bub.visible = grow > 0.03
	if not bub.visible:
		return
	for f in RIM:
		(bub.get_node(f) as Node3D).visible = f == String(k["mood"])
	bub.position = Vector3(0.0, 1.55 + sin(now * 2.2) * 0.04, 0)
	bub.look_at(home.cam.global_position, Vector3.UP)
	bub.scale = Vector3.ONE * grow

## The bubble: a dark rounded face and, per feeling, a rim in its colour with its icon on it.
static func bubble() -> Node3D:
	var root := Node3D.new()
	Models.part(root, Models.sphere(0.23, 14), Models.toon(DISC, false), Vector3.ZERO, Vector3(1, 1, 0.35))
	for f in RIM:
		var n := KinWants.icon_node(root, f)
		var rim := Models.toon(RIM[f], false, 0.3)
		Models.part(n, Models.sphere(0.255, 14), rim, Vector3(0, 0, 0.03), Vector3(1, 1, 0.3))
	KinWants.bowl(root.get_node("hungry"))
	KinWants.zzz(root.get_node("sleepy"))
	KinWants.ball(root.get_node("play"))
	KinWants.heart(root.get_node("happy"))
	_cloud(root.get_node("sulk"))
	_brows(root.get_node("cross"))
	return root

## Sulking: a small grey rain cloud with two drops.
static func _cloud(n: Node3D) -> void:
	var grey := Models.toon(UI.MUTED, false, 0.2)
	Models.part(n, Models.sphere(0.07, 10), grey, Vector3(-0.05, 0.03, ICON_Z))
	Models.part(n, Models.sphere(0.085, 10), grey, Vector3(0.05, 0.04, ICON_Z))
	Models.part(n, Models.sphere(0.06, 10), grey, Vector3(0.0, 0.0, ICON_Z), Vector3(1.8, 0.7, 1))
	var rain := Models.toon(UI.INFO, false, 0.4)
	for x in [-0.045, 0.045]:
		Models.part(n, Models.sphere(0.022, 6), rain, Vector3(x, -0.1, ICON_Z), Vector3(1, 1.5, 1))

## Cross: two slanted angry brows over two small eyes.
static func _brows(n: Node3D) -> void:
	var red := Models.toon(UI.BAD, false, 0.4)
	for s in [-1.0, 1.0]:
		var x: float = 0.06 * s
		Models.part(n, Models.box(0.1, 0.03, 0.03), red, Vector3(x, 0.05, ICON_Z), Vector3.ONE, Vector3(0, 0, -0.5 * s))
		Models.part(n, Models.sphere(0.025, 6), red, Vector3(x, -0.04, ICON_Z))
