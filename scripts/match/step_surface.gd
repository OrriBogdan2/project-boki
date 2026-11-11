class_name StepSurface
extends RefCounted
## What a Hunter's footstep sounds like (Juice.footstep): the surface underfoot and the cue for it.
## Surfaces: grass, stone, wood, snow (every Hunter has its own steps on these) and water and metal
## (shared steps per weight class: step_<surface>_<light|medium|heavy>, made by tools/gen_sfx_steps.py).
## Metal is the sky train's car decks, wood a skiff dock's pier or a plank bridge; the Hollow Crown's
## stone bridges are painted paths (stone). Water is the farm's shallow ponds (HomeWater): match maps
## have none. A Hunter's own "<arch>_step_<surface>" wins when it has one. docs/AUDIO.md lists each region.

const SHARED := ["water", "metal"]     # surfaces with steps per weight class, not per Hunter
const WEIGHT_DB := {"light": -1.5, "medium": 0.0, "heavy": 1.5}     # dB on those steps: heavier boots carry more
const DOCK_HALF := Vector2(1.5, 2.6)   # m: half a skiff dock's pier deck, across and along (ExitModels.dock)
const DOCK_RISE := 0.6                 # m: how far above or below the berth you can be and still be on it

## The surface under `pos` in match `m`.
static func at(m: Match, pos: Vector3) -> String:
	if m.skytrain != null and m.skytrain.on_deck(pos):
		return "metal"
	if m.exits != null and _on_dock(m.exits, pos):
		return "wood"
	var w: World = m.world
	var ix := int(floorf(pos.x))
	var iz := int(floorf(pos.z))
	if not w.inb(ix, iz):
		return "grass"
	var i := w.idx(ix, iz)
	if w.bridge.has(i):
		return "wood"
	if w.stairs.has(i) or w.paint.has(i) or w.kind[i] != World.T_GROUND:
		return "stone"
	return "snow" if w.style_at(i) == "frost" else "grass"

## The sound for `surf` underfoot of `h`: its own set when it has one, else the shared one.
static func cue(h: Hunter, surf: String) -> String:
	var shared := "step_" + surf
	if surf in SHARED:
		shared += "_" + weight_of(h.arch)
	return HeroSfx.of(h, "step_" + surf, shared)

## The step's volume: `base` dB, plus the weight class's on the shared surfaces.
static func vol_db(h: Hunter, surf: String, base: float) -> float:
	return base + (float(WEIGHT_DB[weight_of(h.arch)]) if surf in SHARED else 0.0)

static func weight_of(arch: String) -> String:
	var wt := Arch.weight(arch)
	return wt if WEIGHT_DB.has(wt) else "medium"

## On a skiff dock's pier deck: within its plank rectangle round the berth, about level with it.
static func _on_dock(ex: Exits, pos: Vector3) -> bool:
	for x: Dictionary in ex.list:
		if x["kind"] != "dock":
			continue
		var b: Vector3 = x["berth"]
		if absf(pos.y - b.y) > DOCK_RISE:
			continue
		var out: Vector2 = x["out"]
		var d := Vector2(pos.x - b.x, pos.z - b.z)
		if absf(d.dot(out)) <= DOCK_HALF.y and absf(d.dot(Vector2(-out.y, out.x))) <= DOCK_HALF.x:
			return true
	return false
