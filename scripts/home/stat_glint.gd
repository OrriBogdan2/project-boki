class_name StatGlint
extends Control
## The glint over a Boki at home when it gains Power, Guard, Speed or Focus (toys, the training post, snacks,
## items, the Dash): the heal motes (KinRegen.motes) in the stat's colour and its icon rising over the head.
## It watches each Boki's four stats rather than every place that raises them, so a new source needs no wiring.
## Gains on the same Boki within MERGE_S share one glint (one icon per stat); a capped stat doesn't move, so
## it shows nothing; a sleeping or hidden Boki shows nothing either (the card still has the number).

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

var h                    # the Home screen
var glints: Array = []   # {"k": the Boki entry, "stats": [stat ids], "t": s since it started}
var _seen := {}          # uid -> {stat: value} last seen, so only rises fire

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
			_fire(k, s)
		seen[s] = v

static func _shows(k: Dictionary) -> bool:
	if float(k.get("nap_t", 0.0)) > 0.0 or (k.has("life") and (k["life"] as Fsm).is_in(BaseLife.S.NAP)):
		return false
	return (k["node"] as Node3D).is_visible_in_tree()

func _fire(k: Dictionary, s: String) -> void:
	var g := _open(k)
	if g.is_empty():
		g = {"k": k, "stats": [], "t": 0.0}
		glints.append(g)
	if not (g["stats"] as Array).has(s):
		g["stats"].append(s)
		KinRegen.motes(h.fx, (k["node"] as Node3D).global_position + Vector3(0, MOTE_Y, 0), Care.STATS[s]["col"])

## The glint this Boki still has open for merging, or {}.
func _open(k: Dictionary) -> Dictionary:
	for g in glints:
		if is_same(g["k"], k) and float(g["t"]) < MERGE_S:
			return g
	return {}

func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	for g in glints:
		var u := float(g["t"]) / LIFE
		var at := (g["k"]["node"] as Node3D).global_position + Vector3(0, HEAD_Y, 0)
		if cam.is_position_behind(at):
			continue
		var alpha := 1.0 - clampf((u - FADE_FROM) / (1.0 - FADE_FROM), 0.0, 1.0)
		var px := ICON_PX * minf(1.0, float(g["t"]) / POP_S)
		var stats: Array = g["stats"]
		var left := cam.unproject_position(at) - Vector2(GAP_PX * (stats.size() - 1) * 0.5, RISE_PX * ease(u, 0.4))
		for i in stats.size():
			var col: Color = Care.STATS[stats[i]]["col"]
			var p := left + Vector2(GAP_PX * i, 0)
			draw_circle(p, px * 1.45, Color(TOKEN, TOKEN.a * alpha))
			draw_arc(p, px * 1.45, 0.0, TAU, 24, Color(col, 0.85 * alpha), 2.0, true)
			Icons.draw(self, ICON[stats[i]], p, px, Color(col.lightened(0.25), alpha))
