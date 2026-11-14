class_name HomeChimes
extends RefCounted
## A Boki's own chime at home when it gains a stat, a level (garden_xp.json pays it in the garden), crosses its
## evolve level (a brighter chime) or a new form or part (docs/AUDIO.md). It watches each Boki's record rather
## than every place that raises them, so a new source needs no wiring. Events on one Boki that land within
## MERGE_S share one chime: the biggest one. A sleeping Boki makes no sound (the card and the evolution scene
## still show it). Watched the same way, a Boki dozing off (its nap starting, wherever it lies down) gives a
## yawn (BokiLifeSfx "nap"; BokiNapSfx then breathes while it sleeps).

const KINDS := ["stat", "level", "ready", "evolve"]     # smallest first: a merged chime plays the last one here
const MERGE_S := 0.5     # s: an event this soon after a Boki's chime joins it instead of playing again
const JOY_RISE := 8.0    # joy points gained between two looks that make a Boki happy enough for its Chimegrass to sing
const AURA_PITCH := 1.6  # x pitch of the Chimegrass note over the Boki's own chime
const PITCH := {"small": 1.3, "medium": 1.0, "large": 0.78}   # x pitch by species size (GardenSfx.SIZE)

var h                    # the Home screen
var now := 0.0           # s since the home opened
var _seen := {}          # uid -> [stat total, level, evolve due, forms and parts, joy] last seen: only rises fire
var _last := {}          # uid -> now at its last chime
var _napping := {}       # uid -> it was napping at the last look, so only dozing off sounds

func _init(home) -> void:
	h = home

func tick(dt: float) -> void:
	now += dt
	for k in h.kins:
		_watch(k)
		_doze(k)

## The first sight of a Boki only takes note.
func _watch(k: Dictionary) -> void:
	var rec: Dictionary = k["rec"]
	var uid := String(rec["uid"])
	var vals := _values(rec)
	var was: Array = _seen.get(uid, vals)
	_seen[uid] = vals
	if rec.get("aura", "") == "chimegrass" and float(vals.back()) - float(was.back()) >= JOY_RISE and not _asleep(k):
		GardenAura.chime(k["node"])
		GardenSfx.cue("garden_chime_level", k["pos"], AURA_PITCH * PITCH[GardenSfx.SIZE[Unique.size_tag(rec)]])
	var top := -1
	for i in KINDS.size():
		if int(vals[i]) > int(was[i]):
			top = i
	if top < 0 or _asleep(k) or now - float(_last.get(uid, -MERGE_S)) < MERGE_S:
		return
	_last[uid] = now
	GardenSfx.cue("garden_chime_" + KINDS[top], k["pos"], PITCH[GardenSfx.SIZE[Unique.size_tag(rec)]])

## A Boki whose nap just started voices it; the first sight of one already asleep only takes note.
func _doze(k: Dictionary) -> void:
	var uid := String(k["rec"]["uid"])
	var napping := float(k.get("nap_t", 0.0)) > 0.0
	if napping and not bool(_napping.get(uid, true)):
		BokiLifeSfx.at_home(k, "nap")
	_napping[uid] = napping

static func _values(rec: Dictionary) -> Array:
	var stats := 0
	for s in Care.STATS:
		stats += int(rec.get("stats", {}).get(s, 0))
	var change: int = rec.get("forms", []).size()
	for m in rec.get("muts", []):
		change += int(m["lv"])
	return [stats, int(rec.get("level", 1)), _due(rec), change, Care.need(rec, "joy")]

## 1 once its level has reached its line's evolve level (evolve.json) and no Stayleaf holds it: a branching final
## can be picked (Evolve now), a level form changes at once (its evolve chime wins) or waits for its art.
static func _due(rec: Dictionary) -> int:
	var line: Dictionary = Evo.rules()["lines"].get(String(rec.get("species", "")), {})
	var reached := line.has("level") and int(rec.get("level", 1)) >= int(line["level"])
	return int(reached and not rec.get("stay", false))

static func _asleep(k: Dictionary) -> bool:
	return float(k.get("nap_t", 0.0)) > 0.0 or (k.has("life") and (k["life"] as Fsm).is_in(BaseLife.S.NAP))
