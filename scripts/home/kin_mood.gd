class_name KinMood
extends RefCounted
## How a Boki feels, from its Care needs (hungry, sleepy, wants to play, sulky, happy) and from you
## being away (missed you). When the feeling changes, one small icon floats over its head for
## SHOW_S seconds, then goes: no numbers. At most MAX_SHOWN icons show at once, nearest to you
## first; a Boki waiting for a free slot keeps its full time. Only at home (never on a visit).

const SHOW_S := 3.0                  # s one icon stays over a Boki's head
const MAX_SHOWN := 3                 # icons on screen at once
const SULKY_BELOW := 15.0            # joy (0-100) under this is sulking; between this and WANT_BELOW it wants to play
const HAPPY_AT := 80.0               # joy (0-100) at or over this, with nothing wanted, is happy
const LONELY_S := 120.0              # s you were away before a Boki says it missed you
const NEAR := 4.0                    # tiles: you are back with a Boki when this close
const MISSED_BELOW := 70.0           # joy (0-100): a Boki this content doesn't miss you
const MISS_S := 6.0                  # s a Boki stays in the missed-you mood after you come back
const ICON := {"hungry": "bowl", "sleepy": "zzz", "play": "ball", "happy": "heart", "sulky": "cloud", "missed": "miss"}
const WORDS := {"hungry": "Hungry", "sleepy": "Sleepy", "play": "Wants to play", "happy": "Happy",
	"sulky": "Sulky", "missed": "Missed you", "": "Calm"}
## The needs that make a mood, and the mood each makes when it is the lowest one under WANT_BELOW.
const NEED_MOOD := {"food": "hungry", "energy": "sleepy", "joy": "play"}
const BUBBLE_POS := Vector3(0.25, 1.5, 0.0)   # over the head, to the side (m)
const BUBBLE_SCALE := 1.3                     # readable from the farm camera

## The mood in one word of WORDS' keys ("" for calm). missed: you just came back to it.
static func mood(rec: Dictionary, missed := false) -> String:
	var low := KinWants.WANT_BELOW
	var out := ""
	for n in NEED_MOOD:
		var v := Care.need(rec, n)
		if v < low:
			low = v
			out = NEED_MOOD[n]
	if out == "play" and Care.need(rec, "joy") < SULKY_BELOW:
		return "sulky"
	if out != "":
		return out
	if missed:
		return "missed"
	return "happy" if Care.need(rec, "joy") >= HAPPY_AT else ""

## The mood of the Boki with this record, in plain words for its card.
static func words(home: Node, rec: Dictionary) -> String:
	for k in home.kins:
		if is_same(k["rec"], rec):
			return WORDS[String(k.get("mood", ""))]
	return WORDS[mood(rec)]

## Every frame: tracks each Boki's mood, then shows the icons that are due, nearest first.
static func update(home: Node, dt: float, now: float) -> void:
	var due: Array = []
	for k in home.kins:
		if home.visit.is_empty():
			_track(home, k, dt)
		if float(k.get("mood_show", 0.0)) > 0.0 and home.visit.is_empty() and KinWants.free_to_show(k):
			due.append(k)
	due.sort_custom(func(a, b): return _dist(home, a) < _dist(home, b))
	var shown := due.slice(0, MAX_SHOWN)
	for k in shown:
		k["mood_show"] = float(k["mood_show"]) - dt
	for k in home.kins:
		_pose(home, k, shown.has(k) and float(k["mood_show"]) > 0.0, dt, now)

static func _dist(home: Node, k: Dictionary) -> float:
	return Vector2(k["pos"].x - home.ppos.x, k["pos"].z - home.ppos.z).length()

## Reads its mood and starts the icon timer when the mood changes.
static func _track(home: Node, k: Dictionary, dt: float) -> void:
	var rec: Dictionary = k["rec"]
	if _dist(home, k) > NEAR:
		k["gone_s"] = float(k.get("gone_s", 0.0)) + dt
	else:
		if float(k.get("gone_s", 0.0)) >= LONELY_S and Care.need(rec, "joy") < MISSED_BELOW:
			k["miss_t"] = MISS_S
		k["gone_s"] = 0.0
	k["miss_t"] = maxf(float(k.get("miss_t", 0.0)) - dt, 0.0)
	var now_mood := mood(rec, float(k["miss_t"]) > 0.0)
	if now_mood == String(k.get("mood", "")):
		return
	k["mood"] = now_mood
	k["mood_show"] = SHOW_S if now_mood != "" else 0.0

static func _pose(home: Node, k: Dictionary, shown: bool, dt: float, now: float) -> void:
	var bub: Node3D = k.get("bubble")
	if bub == null or not is_instance_valid(bub):
		bub = KinWants.bubble()
		(k["node"] as Node3D).add_child(bub)
		k["bubble"] = bub
		k["bubble_k"] = 0.0
	if not shown:
		k["bubble_k"] = 0.0
		bub.visible = false
		return
	var grow := lerpf(float(k["bubble_k"]), BUBBLE_SCALE, 1.0 - exp(-9.0 * dt))
	k["bubble_k"] = grow
	bub.visible = true
	for nm in KinWants.ICONS:
		(bub.get_node(nm) as Node3D).visible = nm == ICON.get(String(k["mood"]), "")
	bub.position = BUBBLE_POS + Vector3(0.0, sin(now * 2.2) * 0.04, 0.0)
	bub.look_at(home.cam.global_position, Vector3.UP)
	bub.scale = Vector3.ONE * grow
