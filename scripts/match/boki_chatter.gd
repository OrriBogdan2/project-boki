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
static func say(m: Match, k: Kin, trigger_id: String) -> void:
	if k == null or k.dead or k.state == "downed":
		return
	if k.state == "fused" and k.owner_h != null and KinMerge.in_form(k.owner_h):
		return
	var txt := line(k, trigger_id)
	if txt != "":
		m.kin_bark(k, txt, trigger_id)

## Tutorial hints in its own voice, by step (grown speech, then what a hatchling does instead).
const TUT_HINT := {
	"land": ["That meadow looks nice and quiet!", "(peeks over your shoulder at the ground below)"],
	"move": ["Come on, let's look around!", "(runs a little circle and looks back at you)"],
	"dash": ["Dash across, like this!", "(zips off to the side and back, showing you)"],
	"glide": ["Jump, then glide! Watch me!", "(hops high and spreads out, showing you)"],
	"exdash": ["Jump, then dash in the air!", "(leaps and darts forward in the air)"],
	"shoot": ["A monster! Get it!", "(growls at the monster)"],
	"utility": ["Use your power! Right click!", "(watches your hands, tail going)"],
	"orders": ["Hold %T and tell me what to do!", "(sits up, ears forward, waiting for orders)"],
	"sig": ["Press %E for %N! Line them all up, then fire!", "(bounces, ready for the group)"],
	"gkey": ["Press %T and I'll charge in! Again and I'm back.", "(wiggles, waiting for the button)"],
	"rank": ["Level up! Hold Alt and press %E to make your power stronger!", "(bounces and points at the gold plus)"],
	"key": ["Oh look, there's a key! Grab it so you can open a chest.", "(points its nose at a shiny key)"],
	"fight": ["Together! Get them all!", "(bristles, ready to fight)"],
	"crouch": ["Get low and look far away!", "(flattens itself against the ground)"],
	"kin1": ["Watch this!", "(bounces, ready to use its power)"],
	"throw": ["Throw me! I'm ready!", "(crouches on your shoulder, ready to jump)"],
	"chest": ["A chest! It needs a key to open. Use the one you found!", "(runs to a chest and paws at the lock)"],
	"pickup": ["Something shiny! Grab it!", "(noses at the thing on the ground)"],
	"goexit": ["Follow me, the outpost is this way!", "(runs ahead toward the outpost and waits)"],
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
