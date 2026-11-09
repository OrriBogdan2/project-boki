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
