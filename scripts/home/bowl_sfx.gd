class_name BowlSfx
extends RefCounted
## The Mixing Bowl's sounds (scripts/ui/mixing_bowl.gd, docs/AUDIO.md, tools/gen_sfx_bowl.py): each ingredient plops
## in by its kind, a spoon stirs, a chime rings by the recipe's tier, and a Boki tastes a bowl item it is fed
## (with a fizzle when two clashing Boki share a Twinbun). All through GardenSfx.cue, so the checks can count them.

const PLOP_GAP := 0.14                # s between two ingredients going in
const MAX_PLOPS := 4                  # ingredients sounded for one mix (a big batch is not a drum roll)
const STIR_S := 1.0                   # s the spoon goes round before the chime
const FIZZLE_DELAY := 0.55            # s after the taste until the fizzle (the munches have finished)
const SIZE_PITCH := {"small": 1.15, "medium": 1.0, "large": 0.87}   # a small Boki tastes higher, a large one lower
const STIR := "bowl_stir"

## How an ingredient sounds going in: a pantry snack, a bag treat (nut, pearl) or a bun.
static func kind(id: String) -> String:
	if Data.CROPS.has(id):
		return "snack"
	return "treat" if GardenItems.has(id) else "bun"

## A mix was made (call after GardenRecipes.mix): `take` is the plan's {ingredient: count}.
static func mixed(recipe: Dictionary, take: Dictionary) -> void:
	var t := 0.0
	var plops := 0
	for id in take:
		for _k in int(take[id]):
			if plops < MAX_PLOPS:
				_at(t, GardenSfx.cue.bind("bowl_plop_" + kind(id), null))
				t += PLOP_GAP
				plops += 1
	_at(t, _stir_on)
	_at(t + STIR_S, _stir_off)
	_at(t + STIR_S, GardenSfx.cue.bind("bowl_done_%d" % int(recipe["tier"]), null))

## A Boki was fed `res` (a GardenItems result): a bowl item is tasted, and a Twinbun between a clashing pair fizzles.
static func taste(rec: Dictionary, pos, res: Dictionary) -> void:
	if not res["ok"] or not bowl_item(String(res["id"])):
		return
	GardenSfx.cue("bowl_taste", pos, SIZE_PITCH[GardenSfx.SIZE[Unique.size_tag(rec)]])
	if res.get("unstable", false):
		_at(FIZZLE_DELAY, GardenSfx.cue.bind("bowl_fizzle", pos))

## What the bowl makes (a recipe's result), plus the three personality items it is the way to.
static func bowl_item(id: String) -> bool:
	return GardenRecipes.all().any(func(r): return r["gives"] == id) or GardenItems.item(id)["family"] == "personality"

static func _stir_on() -> void:
	if not Sfx.loop_on(STIR):
		GardenSfx.heard[STIR] = int(GardenSfx.heard.get(STIR, 0)) + 1
	Sfx.loop_start(STIR, STIR, null, GardenSfx.DB)

static func _stir_off() -> void:
	Sfx.loop_stop(STIR)

static func _at(secs: float, act: Callable) -> void:
	Sfx.get_tree().create_timer(secs).timeout.connect(act)
