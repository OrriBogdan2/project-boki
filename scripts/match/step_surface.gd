class_name StepSurface
extends RefCounted
## What a Hunter's footstep sounds like (Juice.footstep): the surface underfoot and the cue for it.
## Surfaces: grass, stone, wood, snow (every Hunter has its own steps on these) and sand, water and
## metal (shared steps per weight class: step_<surface>_<light|medium|heavy>, made by
## tools/gen_sfx_steps.py). Sand, water and metal come from the map's "surfaces" tile rects
## (content/maps/<id>.json, "kind" and "rect" [x0, z0, x1, z1]; a later rect wins) and, on the sky
## train, from the car's deck (metal). The map's "bridges" (from, to, half-width r) and the farm's
## opened bridges are wood. A Hunter's own "<arch>_step_<surface>" wins when it has one.

const SHARED := ["sand", "water", "metal"]     # surfaces with steps per weight class, not per Hunter
const WEIGHT_DB := {"light": -1.5, "medium": 0.0, "heavy": 1.5}     # dB on those steps: heavier boots carry more

static var _layouts := {}    # layout id -> {surfaces: [{kind, rect}], bridges: [{from, to, r}]}, read once per map

## The surface under `pos` on world `w` (`train` is the sky train, or null).
static func at(w: World, train: SkyTrain, pos: Vector3) -> String:
	if train != null and train.on_deck(pos):
		return "metal"
	var ix := int(floorf(pos.x))
	var iz := int(floorf(pos.z))
	if not w.inb(ix, iz):
		return "grass"
	var i := w.idx(ix, iz)
	if w.bridge.has(i):
		return "wood"
	var L := _layout(w.layout_id)
	var tags: Array = L["surfaces"]
	for k in range(tags.size() - 1, -1, -1):
		var b: Array = tags[k]["rect"]
		if ix >= int(b[0]) and iz >= int(b[1]) and ix <= int(b[2]) and iz <= int(b[3]):
			return String(tags[k]["kind"])
	var q := Vector2(pos.x, pos.z)
	for br: Dictionary in L["bridges"]:
		var a: Array = br["from"]
		var z: Array = br["to"]
		var on := Geometry2D.get_closest_point_to_segment(q, Vector2(a[0], a[1]), Vector2(z[0], z[1]))
		if on.distance_to(q) <= float(br["r"]):
			return "wood"
	if w.stairs.has(i) or w.paint.has(i) or w.kind[i] != World.T_GROUND:
		return "stone"
	return "snow" if w.style_at(i) == "frost" else "grass"

## The sound for `surf` underfoot of `h`: its own set when it has one, else the shared one.
static func cue(h: Hunter, surf: String) -> String:
	var shared := "step_" + surf
	if surf in SHARED:
		shared += "_" + weight_of(h)
	return HeroSfx.of(h, "step_" + surf, shared)

## The step's volume: `base` dB, plus the weight class's on the shared surfaces.
static func vol_db(h: Hunter, surf: String, base: float) -> float:
	return base + (float(WEIGHT_DB[weight_of(h)]) if surf in SHARED else 0.0)

static func weight_of(h: Hunter) -> String:
	var wt := Arch.weight(h.arch)
	return wt if WEIGHT_DB.has(wt) else "medium"

static func _layout(id: String) -> Dictionary:
	if not _layouts.has(id):
		var d := World.load_layout(id) if id != "" else {}
		_layouts[id] = {"surfaces": d.get("surfaces", []), "bridges": d.get("bridges", [])}
	return _layouts[id]
