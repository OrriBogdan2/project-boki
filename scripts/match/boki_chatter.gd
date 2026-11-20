class_name BokiChatter
extends RefCounted
## A Boki's lines in a match (BokiLines): its talking level, its element and any personal lines the
## AI wrote for it pick the words, and Match.kin_bark shows them over its head.

## Its line for a trigger ("" while it's on cooldown). A Boki that barely trusts you grumbles instead
## of reviving you; one with no save record (a bot's or a wild one) talks freely.
static func line(k: Kin, trigger_id: String) -> String:
	var t := trigger_id
	if t == "revive" and k.trust < 25.0:
		t = "revive_low"
	var stage := Care.speech(k.rec) if k.rec.size() > 0 else 3
	var id := String(k.rec.get("uid", "kin%d" % k.get_instance_id()))
	return BokiLines.line(id, t, k.species, stage, -1.0, k.lines.get(t, []))

## Says a trigger's line over the Boki, if it has one to say right now (inside a Fusion it's quiet).
## fill: placeholders in the line and what replaces them ("%H" -> "the lava").
static func say(m: Match, k: Kin, trigger_id: String, fill := {}) -> void:
	if k == null or k.dead or k.state == "downed":
		return
	if k.state == "fused" and k.owner_h != null and KinMerge.in_form(k.owner_h):
		return
	var txt := line(k, trigger_id)
	for key in fill:
		txt = txt.replace(key, fill[key])
	if txt != "":
		m.kin_bark(k, txt, trigger_id)

## Is the line over this Boki's head drawn? In a fight only your own Boki's are: the rest print over the fight.
static func heard(m: Match, k: Kin) -> bool:
	return k.owner_h == m.player or m.music_dir == null or not m.music_dir.fight_on(m)

## Tutorial hints in its own voice, by step (grown speech, then what a hatchling does instead).
const TUT_HINT := {
	"land": ["That meadow looks nice and quiet!", "(peeks over your shoulder at the ground below)"],
	"fight": ["Use your power on them!", "(watches your hands, tail going)"],
	"shoot": ["Get them!", "(growls at the monster)"],
	"dash": ["Dash across, like this!", "(zips off to the side and back, showing you)"],
	"exdash": ["Jump, then dash in the air!", "(leaps and darts forward in the air)"],
	"glide": ["Jump, then glide! Watch me!", "(hops high and spreads out, showing you)"],
	"gkey": ["Press %T and I'll charge in! Again and I'm back.", "(wiggles, waiting for the button)"],
	"kin": ["Line them up, then let it go!", "(bounces, ready for the group)"],
	"chest": ["A chest! Press the button and it opens!", "(sniffs at the chest and paws at the lid)"],
	"wayout": ["Follow me, the outpost is this way!", "(runs ahead toward the outpost and waits)"],
	"uplink": ["Stay in the circle till it's yours. Step out and it slips back!",
		"(sits in the circle, looking at you)"],
	"defend": ["Here they come! Stay inside the circle!", "(bristles at the walls)"],
	"extract": ["We did it! Into the light!", "(bounces toward the light)"],
}

## Its hint for a tutorial step.
static func tut_hint(k: Kin, id: String) -> String:
	if not TUT_HINT.has(id):
		return ""
	var stage := Care.speech(k.rec) if k.rec.size() > 0 else 3
	if stage >= int(BokiLines.tuning("grown_stage")):
		return TutorialText.fill(String(TUT_HINT[id][0]), k.owner_h)
	return KinSpeak.babble(k.species, "excited") + " " + TutorialText.fill(String(TUT_HINT[id][1]), k.owner_h)
