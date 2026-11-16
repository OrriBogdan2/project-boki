class_name Mentor
extends RefCounted
## Legacy, not death (briefs/design/GARDEN.md section 3): an Elder retires to the Soul Shrine as a mentor.
## It stays on the base as a slow, calm presence (BaseLife S.MENTOR, no jobs) and passes ONE thing to the
## next egg laid in the Nesting Nook: a trait, a habit or a memory line. Nothing resets and the Boki is never
## lost. rec["mentor"] = {"gifted": bool}. The gift is chosen when the egg is laid (egg["gift"]) and lands on
## the baby when it hatches (baby["gift"], shown on the hatch card). Old saves have neither key: no migration.

const GIFTS := ["trait", "habit", "memory"]
const TRAIT_PULL := 0.7      # how far the baby's trait moves to the mentor's (0 = none, 1 = the same)
const PACE := 0.5            # share of its normal walking speed

static func is_mentor(rec: Dictionary) -> bool:
	return rec.has("mentor")

static func pace(rec: Dictionary) -> float:
	return PACE if is_mentor(rec) else 1.0

## "" if this Boki can retire now, else why not (also the button's tooltip).
static func why_not(rec: Dictionary) -> String:
	if is_mentor(rec): return "Already a mentor at the Soul Shrine"
	if Care.stage_name(rec) != "Elder": return "Only an Elder can retire as a mentor"
	if not Save.has_building("shrine"): return "Build the Soul Shrine first"
	if [Save.d.get("active", ""), Save.d.get("active2", "")].has(rec["uid"]): return "Swap your partner out first"
	return ""

static func retire(rec: Dictionary) -> void:
	rec["mentor"] = {"gifted": false}
	Save.remember(rec, "mentor", "retired to the Soul Shrine to mentor the young", 2.0)
	Save.log_event("retired", rec)

## The next egg is laid: the first mentor with a gift left gives it. {} if none (the gift goes on the egg).
static func take_gift() -> Dictionary:
	for rec in Save.d["roster"]:
		var m: Dictionary = rec.get("mentor", {})
		if m.is_empty() or m.get("gifted", false):
			continue
		m["gifted"] = true
		var gift := {"from": String(rec["name"]), "kind": GIFTS[randi() % GIFTS.size()]}
		var tr: Dictionary = rec.get("traits", {})
		var memories: Array = rec.get("memory", [])
		if gift["kind"] == "trait" and not tr.is_empty():
			var keys: Array = tr.keys()
			keys.sort_custom(func(a, b): return float(tr[a]) > float(tr[b]))
			gift["key"] = keys[0]
			gift["val"] = float(tr[keys[0]])
		elif gift["kind"] == "habit" and String(Unique.of(rec).get("quirk", "")) != "":
			gift["quirk"] = String(Unique.of(rec)["quirk"])
		else:
			gift["kind"] = "memory"
			var tale := String(memories[randi() % memories.size()]["text"])
			gift["text"] = "A memory from %s, who %s." % [gift["from"], tale]
		return gift
	return {}

## The baby hatches wearing the gift.
static func apply(baby: Dictionary, gift: Dictionary) -> void:
	if gift.is_empty():
		return
	match String(gift["kind"]):
		"trait":
			var now := float(baby["traits"][gift["key"]])
			baby["traits"][gift["key"]] = lerpf(now, float(gift["val"]), TRAIT_PULL)
		"habit": baby["dna"]["quirk"] = gift["quirk"]
		"memory": Save.remember(baby, "mentor", String(gift["text"]))
	baby["gift"] = gift

## What the hatch card says.
static func line(gift: Dictionary) -> String:
	match String(gift["kind"]):
		"trait": return "%s passed on a steadier %s." % [gift["from"], gift["key"]]
		"habit":
			var habit := String(Unique.QUIRK_NAMES.get(gift["quirk"], "a quirk")).to_lower()
			return "%s passed on a habit: %s." % [gift["from"], habit]
	return String(gift["text"])
