class_name StatGlint
extends Control
## The glint over a Boki at home when it gains Power, Guard, Speed or Focus (toys, the training post, snacks,
## items, the Dash): the heal motes (KinRegen.motes) in the stat's colour and its icon rising over the head.
## It watches each Boki's four stats rather than every place that raises them, so a new source needs no wiring.
## Gains on the same Boki within MERGE_S share one glint (one icon per stat); a capped stat doesn't move, so
## it shows nothing; a sleeping or hidden Boki shows nothing either (the card still has the number).
## Clicking an icon opens that Boki's Training tab with the risen stats marked old -> new for LIT_S.

const ICON := {"power": "haymaker", "guard": "fortify", "speed": "dash", "focus": "cloak"}   # Icons ids
const MERGE_S := 0.5     # s: a gain this soon after a glint starts joins it instead of starting another
const LIFE := 1.3        # s a glint lasts
const POP_S := 0.12      # s it takes to grow to full size
const FADE_FROM := 0.6   # share of LIFE after which it fades out
const HEAD_Y := 1.2      # m above the Boki's feet where it starts
const RISE_PX := 40.0    # px it climbs on screen over its life (on screen, so the top-down camera shows it too)
const ICON_PX := 13.0    # px: icon half-size on screen
const TOKEN := Color(0.06, 0.07, 0.12, 0.62)   # the dark disc behind each icon, readable on any ground
const GAP_PX := 40.0     # px between icons of a merged glint
const MOTE_Y := 0.9      # m: where the motes start (the heal motes' height)
const HIT_PX := 24.0     # px: how close a click must be to an icon to take it
const LIT_S := 2.0       # s the card keeps the old and new value of a clicked glint's stats marked

var h                    # the Home screen
var glints: Array = []   # {"k": Boki entry, "stats": [stat ids], "from": {stat: value before}, "t": s since start}
var _seen := {}          # uid -> {stat: value} last seen, so only rises fire
var _lit_uid := ""       # the Boki whose card marks its risen stats (set by a click)
var _lit_from := {}      # stat -> value before the rise
var _lit_until := 0      # Time.get_ticks_msec() when the marks end

func _init(home) -> void:
	h = home
	name = "StatGlint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(dt: float) -> void:
	for k in h.kins:
		_watch(k)
	if glints.is_empty():
		return
	for g in glints:
		g["t"] = float(g["t"]) + dt
	glints = glints.filter(func(g): return float(g["t"]) < LIFE and is_instance_valid(g["k"]["node"]))
	queue_redraw()      # (also the frame the last one ends, to clear it)

## Fires for each stat that rose since the last frame. The first sight of a Boki only takes note.
func _watch(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	if not rec.has("stats"):
		return
	var uid := String(rec["uid"])
	var stats: Dictionary = rec["stats"]
	if not _seen.has(uid):
		_seen[uid] = stats.duplicate()
		return
	var seen: Dictionary = _seen[uid]
	for s in ICON:
		var v := int(stats.get(s, 0))
		if v > int(seen.get(s, 0)) and _shows(k):
			_fire(k, s, int(seen.get(s, 0)))
		seen[s] = v

static func _shows(k: Dictionary) -> bool:
	if float(k.get("nap_t", 0.0)) > 0.0 or (k.has("life") and (k["life"] as Fsm).is_in(BaseLife.S.NAP)):
		return false
	return (k["node"] as Node3D).is_visible_in_tree()

func _fire(k: Dictionary, s: String, was: int) -> void:
	StatMeaning.rise(h, s)
	var g := _open(k)
	if g.is_empty():
		g = {"k": k, "stats": [], "from": {}, "t": 0.0}
		glints.append(g)
	if not (g["stats"] as Array).has(s):
		g["stats"].append(s)
		g["from"][s] = was
		KinRegen.motes(h.fx, (k["node"] as Node3D).global_position + Vector3(0, MOTE_Y, 0), Care.STATS[s]["col"])

## The glint this Boki still has open for merging, or {}.
func _open(k: Dictionary) -> Dictionary:
	for g in glints:
		if is_same(g["k"], k) and float(g["t"]) < MERGE_S:
			return g
	return {}

## Opens the Training tab of the Boki whose glint icon is at this screen point; false if none is there.
func open_card(pos: Vector2) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not h.visit.is_empty() or h.building_now or h.chat_open:
		return false
	for g in glints:
		for p in _spots(g, cam):
			if p.distance_to(pos) <= HIT_PX:
				_lit_uid = String(g["k"]["rec"]["uid"])
				_lit_from = g["from"].duplicate()
				_lit_until = Time.get_ticks_msec() + int(LIT_S * 1000.0)
				h.kin_tab = "Training"
				h._open_kin(g["k"]["rec"])
				return true
	return false

## {stat: value before} for the stats the card of this Boki still marks, with the seconds left in "left".
func lit_for(rec: Dictionary) -> Dictionary:
	var left := float(_lit_until - Time.get_ticks_msec()) / 1000.0
	if String(rec["uid"]) != _lit_uid or left <= 0.0:
		return {}
	return {"from": _lit_from, "left": left}

## Where each icon of this glint is on screen now (empty when the Boki is behind the camera).
func _spots(g: Dictionary, cam: Camera3D) -> Array:
	var at := (g["k"]["node"] as Node3D).global_position + Vector3(0, HEAD_Y, 0)
	if cam.is_position_behind(at):
		return []
	var n: int = g["stats"].size()
	var left := cam.unproject_position(at) - Vector2(GAP_PX * (n - 1) * 0.5, RISE_PX * ease(float(g["t"]) / LIFE, 0.4))
	return range(n).map(func(i): return left + Vector2(GAP_PX * i, 0))

func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	for g in glints:
		var u := float(g["t"]) / LIFE
		var alpha := 1.0 - clampf((u - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
		var px := ICON_PX * minf(1.0, float(g["t"]) / POP_S)
		var stats: Array = g["stats"]
		var spots := _spots(g, cam)
		for i in spots.size():
			var col: Color = Care.STATS[stats[i]]["col"]
			var p: Vector2 = spots[i]
			draw_circle(p, px * 1.45, Color(TOKEN, TOKEN.a * alpha))
			draw_arc(p, px * 1.45, 0.0, TAU, 24, Color(col, 0.85 * alpha), 2.0, true)
			Icons.draw(self, ICON[stats[i]], p, px, Color(col.lightened(0.25), alpha))
