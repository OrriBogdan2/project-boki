class_name LeaveMatch
extends RefCounted
## Leaving a match from the Esc menu. What it costs depends on the match, and the warning says exactly that:
##   PRACTICE  the Training Area, Arena, duel room and tutorial: nothing is at stake.
##   EARLY     an expedition below KinLoss's loss_min_tier (The Meadow, Dusk Isles): your Boki come home with you
##             but lose trust in you (boki_system.json "loss"."leave_trust_loss").
##   DEEP      the Hollow and up: the Boki you brought are left behind, like going down (KinLoss, then Ransom).
## You lose what you carry in both expedition kinds (the run counts as not extracted).

enum Kind { PRACTICE, EARLY, DEEP }

static func kind(m: Match) -> Kind:
	if m.opts.get("training", false) or m.opts.get("tutorial", false):
		return Kind.PRACTICE
	return Kind.DEEP if KinLoss.risky_match(m) else Kind.EARLY

## The Boki the player took in with them.
static func brought(m: Match) -> Array:
	var out: Array = []
	for kk in [m.player.kin, m.player.kin2]:
		if kk != null and is_instance_valid(kk) and not (kk as Kin).dead:
			out.append(kk)
	return out

## {"head", "body"} for the confirm dialog. has_kin: the player brought a Boki.
static func warning(k: Kind, has_kin: bool) -> Dictionary:
	if k == Kind.PRACTICE:
		return {"head": "Leave?", "body": "Nothing is lost here."}
	var body := "You lose everything you carry."
	if has_kin:
		body += (" Your Boki come home with you, but they lose trust in you." if k == Kind.EARLY
			else " Any Boki you brought is left behind.")
	return {"head": "Leave the match?", "body": body}

## Does what warning() said (a player who already went down has had it done to them).
static func apply(m: Match) -> void:
	var k := kind(m)
	if k == Kind.PRACTICE or m.player == null or m.player.out:
		return
	for kin in brought(m):
		if k == Kind.DEEP:
			KinLoss.on_owner_out(m, m.player, kin, Vector3.INF)
		else:
			var cut := float(KinLoss.rules()["leave_trust_loss"])
			kin.note("left", "lost some faith in you when you quit a match", -cut)

## The confirm dialog; `leave` runs after the penalty is applied.
static func ask(host: Control, m: Match, leave: Callable) -> void:
	var k := kind(m)
	var w := warning(k, not brought(m).is_empty())
	UI.confirm(host, w["head"], w["body"], "Leave", func():
		apply(m)
		leave.call(), k != Kind.PRACTICE)
